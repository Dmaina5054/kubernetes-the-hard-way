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
