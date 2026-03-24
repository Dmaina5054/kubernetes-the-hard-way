# 📔 SRE Lab Notes: Kubernetes Probes & Imperative Mastery

**Date:** March 24, 2026  
**Topic:** TCP Socket Probes & Advanced `kubectl` Filtering

---

## 🛠️ 1. Imperative Pod Creation

When you need to spin up a prototype quickly or generate a template for the CKA 2026:

- **The Base Command:**
    ```sh
    kubectl run tcp-tester --image=nginx --port=80
    ```

- **The "Dry-Run" (Best Practice):**  
    Always generate the YAML first to add complex fields like probes.
    ```sh
    kubectl run tcp-pod --image=nginx --port=80 --dry-run=client -o yaml > pod.yaml
    ```

---

## 🔍 2. TCP Socket Probes (The "Liveness" Check)

- Unlike HTTP probes (which check for `200 OK`), TCP probes check if the network port is open.
- **Use Case:** Databases, non-web apps, or basic connectivity checks.

**The "Negative Test" Logic:**  
If you point the probe to a port that isn't listening (e.g., Port 81), the Kubelet will receive a _Connection Refused_. After the `failureThreshold` (default 3) is hit, it will restart the container.

---

## ⚡ 3. Advanced Filtering with `--field-selector`

This is your "Search Engine" for the cluster. It allows you to ignore the noise and find specific "Reasons" for failure.

| Command Example | Purpose |
|-----------------|---------|
| `type=Warning` | Shows only errors/failures (ignores Normal events). |
| `reason=Unhealthy` | Specifically finds Liveness/Readiness probe failures. |
| `involvedObject.name=<name>` | Isolates events for one specific Pod. |
| `involvedObject.kind=Pod` | Filters out Node or Service events to focus on containers. |

**The "Power" Command:**
```sh
kubectl get events -A --field-selector type!=Normal --sort-by='.lastTimestamp'
```
_Displays a chronological stream of every error across the entire cluster._

---

## 💡 SRE "Aha!" Moments (Morning Session)

- **The Stop Signal (`--`):**  
    Anything after the double dash in `kubectl run` is treated as the container's command/args, protecting your script from being parsed as kubectl flags.

- **Events vs. Logs:**  
    Events are Control Plane messages (_why_ K8s killed the pod). Logs are Application messages (_what_ the app said before it died).

- **The 1-Hour Rule:**  
    Events are ephemeral. They disappear after 60 minutes, so catch them early with:
    ```sh
    kubectl get events -w
    ```