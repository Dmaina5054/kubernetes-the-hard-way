## [2026-02-05] Topic: SSH Loop & Configuration
**The Gotcha:**
1. **Empty Lines in Input Files:** Trailing empty lines in `machines.txt` caused the `read` loop to execute with empty variables, resulting in `ssh: Could not resolve hostname` or execution against the local machine.
2. **SSH Consuming Stdin:** Using `ssh` inside a `while read` loop without the `-n` flag caused the first SSH command to consume the rest of the loop's input (stdin), making the loop terminate after only one iteration.
3. **Variable Syntax Typos:** Writing `root@{HOST}` instead of `root@${HOST}` passes the literal string `root@{HOST}` to SSH, causing connection failures.

**The Solution:**
1. **Sanitize Inputs:** Use `sed -i '/^$/d' machines.txt` to remove empty lines before processing or add `[[ -z "$IP" ]] && continue` inside the loop.
2. **Prevent Stdin Consumption:** Always use `ssh -n` (or `ssh < /dev/null`) inside `while` loops to prevent SSH from reading the loop's input stream.
3. **Verify Variable Syntax:** Double-check variable expansion (`${VAR}`) in scripts, especially within quoted strings.

---

## [2026-02-06] Topic: PKI & Certificate Authority
**The Gotcha:**
1. **Hostname Mismatch:** `Vagrantfile` defined `worker-0`, but `ca.conf` and `machines.txt` used `node-0`. This would cause certificate validation failures (Subject Name doesn't match hostname) and SSH loop errors.
2. **Node Authorizer Requirements:** Kubelet certificates *must* use the specific CN format `system:node:<nodeName>` and Organization `system:nodes`. Without this, the API Server's Node Authorizer will reject the node's registration, even if the certificate is valid.
3. **Subject Alternative Names (SANs) in Vagrant:** In a Vagrant/Libvirt setup, nodes connect via their specific private network IPs (e.g., `10.240.0.12`). These IPs *must* be included in the SANs of the certificate, or connection attempts will fail with `x509: certificate is valid for 127.0.0.1, not 10.240.0.12`.
4. **Certificate Standardization:** When distributing certificates, keeping unique filenames (e.g., `worker-0.crt`) on the destination node complicates configuration. Renaming them to a generic `kubelet.crt` at the destination (`/var/lib/kubelet/`) allows for a standard Kubelet configuration file across all nodes.

**The Solution:**
1. **Align Hostnames:** We renamed sections in `ca.conf` and entries in `machines.txt` to `worker-0` / `worker-1` to match the `Vagrantfile`.
2. **Strict Identity Config:** Verified and preserved `CN=system:node:worker-0` in the `ca.conf`.
3. **Add IPs to SANs:** Manually added `IP:10.240.0.12` and `IP:10.240.0.13` to the `worker-0` and `worker-1` sections of `ca.conf`.
4. **Rename on Copy:** Used `scp worker-0.crt root@worker-0:/var/lib/kubelet/kubelet.crt` to enforce standardization.

---

## [2026-02-09] Topic: File Synchronization & Jumpbox Access
**The Gotcha:**
1. **Direct SCP Access Restricted:** Attempting to `scp` directly from the host to the jumpbox IP (`10.240.0.10`) may fail with `Permission denied` due to missing SSH keys or disabled password authentication in the lab environment.
2. **Synchronization State:** Generating files on the host instead of the jumpbox creates a "split brain" where tools (like `kubectl`) and certificates are in different environments.

**The Solution:**
1. **The "Tar Pipe" Trick:** Use a combination of `tar` and `vagrant ssh` to stream files to the jumpbox without needing root passwords: 
   `tar cz *.crt *.key *.csr ca.conf machines.txt | vagrant ssh jumpbox -- "tar xz -C ~"`
2. **Centralize Operations:** Always perform cluster-wide operations (kubeconfig generation, distribution) from the Jumpbox to ensure tool version consistency and network reachability.

3. **Bash Line Continuation (`\`):** When breaking a long command into multiple lines in the terminal, there must be **nothing** (including spaces) after the backslash. If omitted or if a space is present, Bash will execute the line as a partial command, leading to "command not found" errors for the arguments on the following lines.

4. **The "Documentation Backslash" Bug:** In the tutorial distribution loops, some lines end in a backslash (`\`) even though they are the "end" of an `scp` command. If you copy this exactly into a loop, Bash interprets the *next* command in the loop as an argument to the first one, leading to chaotic filenames like `scp` or `root@worker-0:` appearing in your home directory.

---

## [2026-02-14] Topic: Control Plane Troubleshooting
**The Gotcha:**
1. **Scheduler "Unhealthy" (Connection Refused):** `kubectl get cs` shows Scheduler as `Unhealthy` because the binary couldn't find its `.kubeconfig` file.
2. **The "Localhost" Trap:** Running `kubectl` from the Jumpbox fails with `localhost:8080` or `127.0.0.1:6443` because the `admin.kubeconfig` points to the loopback address.

**The Solution:**
1. **Check the Logs First:** `journalctl -u kube-scheduler` immediately revealed the missing file path. Always ensure the `.kubeconfig` is moved to the directory defined in the `--config` file (usually `/var/lib/kubernetes/`).
2. **Context Patching:** Use `kubectl config set-cluster ... --server=https://server.kubernetes.local:6443` to make the Jumpbox aware of the remote server.
---

## [2026-02-20] Topic: Cluster Chaos - Scenario 1 (The Dark Brain)
**The Sabotage (Controlled Break):**
1. **Service Disruption**: Stopping the `etcd` service on the control plane.
2. **Data Isolation**: Renaming `/var/lib/etcd` to simulate data loss or corruption.

**SRE Investigation Objectives:**
- Observe how `kube-apiserver` reacts when its backing store vanishes.
- Verify component health using `systemctl status` and `journalctl`.
- Use `ss -ntlp` to confirm if `2379` (etcd) is listening.

**The Fix:**
1. **Stop Services**: Gracefully stop `kube-apiserver` and `etcd` to prevent further panics or corruption.
2. **Data Restoration**: Replace the "amnesiac" `/var/lib/etcd` directory with the backup/original version.
3. **Restart & Verify**: Start the services and confirm that stateful resources (Pods, Deployments, Secrets) have returned.

---

## [2026-02-20] Topic: Port Identity (The 2379 vs 6379 Trap)
**The Gotcha:**
Misreading the `etcd` port (`2379`) as the `Redis` port (`6379`). In a high-pressure troubleshooting scenario, searching for the wrong socket leads to "false negatives" where you think a service is missing when you've simply looked in the wrong place.

**The Solution:**
Standardize your socket checks. In Kubernetes:
- **2379**: etcd (The Brain)
- **6443**: API Server (The Heart)
- **10250**: Kubelet (The Hands)
- **6379**: Redis (Not a core K8s component!)
---

## [2026-02-20] Topic: API Server Panic & Node Persistence
**The Gotcha:**
When `etcd` is wiped while `kube-apiserver` is running, the API server might **panic** (`runtime error: index out of range [0]`). This happens because the API server's "compactor" or cache expects a resource version history that no longer exists in the newly initialized etcd.

**The Observation:**
Nodes might "magically" reappear even after a database wipe. 
- **The Rationale**: Kubelets are persistent. If their certificates are still valid, they will continuously attempt to register themselves. In a blank cluster, the node objects are recreated, but any custom configurations, deployments, or secrets are **gone forever**.

**The SRE Lesson:**
A running node list does *not* mean your cluster data is safe. It just means your "workers" are reporting for duty to an empty office. Always verify `Deployments` and `Secrets` to confirm true data integrity.

---

## [2026-02-20] Topic: Node Authorizer & "NODE DENY" Errors
**The Gotcha:**
Observing `NODE DENY` errors like `unknown node 'worker-0' cannot get configmap` after a database wipe.

**The Rationale (SRE Deep Dive):**
The **Node Authorizer** is a special-purpose authorizer that specifically authorizes API requests made by Kubelets. Even if a Kubelet authenticates with a valid cert, the authorizer checks the `etcd` database to see if that node actually exists and if it's authorized to see the requested resource. 
- In a blank cluster, the node registration might not be fully established, or the global resources (like the `kube-root-ca.crt` ConfigMap) haven't been regenerated yet.
- The API server says: *"I see your certificate, but I have no record of you in my brain (etcd) as an authorized worker, so you get nothing!"*
- **The Result**: For 40 seconds, the node is a "Ghost." The API server *thinks* it's `Ready` based on the *last known good state*, even though the actual physical node process is broken. If you wait a minute, the state will transition to `NotReady`. 

---

## [2026-02-24] Topic: Kubeconfig `--embed-certs=true` (Identity Caching)
**The Observation:**
Replacing the `/var/lib/kubelet/kubelet.crt` file on disk and restarting the Kubelet did *not* break the node's authentication.

**The Rationale (SRE Deep Dive):**
During the "Kubernetes The Hard Way" setup, we used the `--embed-certs=true` flag when generating the `.kubeconfig` files. 
- This takes the raw certificate and key data, encodes it into Base64, and **bakes it directly into the kubeconfig YAML file**.
- When the Kubelet starts, it reads its identity from the `kubeconfig` (its client credentials) to talk to the API Server. It completely ignored the standalone `.crt` files we modified on disk!
- **SRE Lesson**: When hunting for an identity issue or rotating certificates, you must check *where* the service is configured to read its certs. If it's using a `kubeconfig`, replacing files around it won't do anything until you update the config file itself!

---

## [2026-02-20] Topic: IPAM & IP Persistence
**The Question:**
When etcd is wiped, does the Pod IP change?

**The Rationale (SRE Deep Dive):**
No. The IP is assigned by the **IPAM (IP Address Management)** plugin (e.g., `host-local`) on the **Worker Node** at the moment of creation. 
- **The Physical Reality**: The IP sits on the `veth` pair inside the worker node's kernel. As long as the container is running, that IP is "locked."
- **The API Role**: The API Server is just a registry. It records whatever IP the CNI plugin gave the pod. 
- **The Persistence**: Wiping etcd removes the *record* of the IP, but doesn't change the *physical* IP. Restoring etcd simply restores the record to match the reality.

---

## [2026-02-24] Topic: Role-Based Access Control (RBAC) & The Node Authorizer
**The Scenario:**
We forced the Kubelet on `worker-0` to use the `kube-proxy` certificate (embedded in its `kubeconfig`).

**The Diagnostics (Proving the Crime):**
Check the API server's reaction to the imposter.
```bash
journalctl -u kube-apiserver -f | grep 'Forbidden'
```
You will see something like: `User "system:kube-proxy" cannot patch resource "nodes/status"`. The API server knows *who* is asking (Authentication passed), but that user doesn't have the *permission* (RBAC Authorization failed) to update a Node object.

**The Fix:**
1. Put the correct `kubeconfig` back where it belongs. In our KTHW lab, we still have the original on the server.
   ```bash
   scp worker-0.kubeconfig root@worker-0:/var/lib/kubelet/kubeconfig
   ```
2. Restart the Kubelet on `worker-0`.
   ```bash
   systemctl restart kubelet
   ```
3. Watch the "Ghost" come back to life on the Jumpbox:
   ```bash
   kubectl get nodes --watch
   ```

---

## [2026-02-26] Topic: Static Route Persistence (The "Pre-Broken" Network)
**The Incident:**
Pings between Pods on different nodes were failing (`Destination Host Unreachable`). Inspecting `ip route` showed that the routes for the remote Pod subnets were missing.

**The Rationale (SRE Deep Dive):**
In "Kubernetes The Hard Way", we use **Static Routes** instead of a dynamic routing protocol (like BGP). 
- **The Issue**: Commands like `ip route add` are **ephemeral**. If the underlying VM reboots or the network service restarts, these routes are wiped from the kernel's memory unless they are added to a persistent configuration file (like Netplan or `/etc/network/interfaces`).
- **The Sign**: If `kubectl get nodes` is healthy but you can't ping Pod IPs from other nodes, the first check should always be the **Node's Routing Table**.

**The Fix:**
Re-apply the "Next Hop" routes to all relevant machines (Nodes and Jumpbox).

---

## [2026-02-26] Topic: CNI Binary Matching (`type` field)
**The Incident:**
Pod creation stuck in `ContainerCreating`. `kubectl describe pod` revealed: `failed to find plugin "broken-switch" in path [/opt/cni/bin]`.

**The Rationale (SRE Deep Dive):**
The Kubelet provides the "bridge" between Kubernetes and the Linux network stack. 
- **The Mapping**: When the Kubelet reads `/etc/cni/net.d/10-bridge.conf`, it looks at the `"type": "..."` field.
- **The Execution**: It then looks into the directory `/opt/cni/bin/` for a binary filing that exact name. 
- **SRE Lesson**: If you see "plugin not found" errors, it's either a typo in the JSON config or the CNI binaries were never installed/moved to the designated `/opt/cni/bin` directory.

**The Fix:**
Correct the `type` to match an existing binary (usually `bridge`, `loopback`, `ptp`, etc.) and the Pod will automatically recover on the next Kubelet retry.

---

## [2026-03-12] Topic: The Kubernetes API Evolution (`--generator`)
**The Gotcha:**
Running commands from older Kubernetes books (like KUAR 1st/2nd Edition) fails with `unknown flag: --generator`. For example:
`kubectl run kuard --generator=run-pod/v1 --image=gcr.io/kuar-demo/kuard-amd64:blue`

**The Rationale (SRE Historical Context):**
Kubernetes is a rapidly evolving API. In versions prior to v1.18, `kubectl run` was a "magic" command that could create Deployments, Jobs, or Pods depending on the `--generator` flag. 
- As of K8s v1.18, the developers radically simplified this to match the UNIX philosophy of doing one thing well.
- `kubectl run` **now ONLY creates Pods**. The `--generator` flag was completely removed because it's no longer needed to specify what you want to create.
- To create a Deployment, you now explicitly use `kubectl create deployment`.

**The Fix:**
Translate the older command to the modern syntax. To run a standalone pod, just drop the generator flag:
`kubectl run kuard --image=gcr.io/kuar-demo/kuard-amd64:blue`
