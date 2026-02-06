# PKI & Certificate Provisioning Summary

This document summarizes the workflow for setting up the Certificate Authority and ensuring all Kubernetes components have the correct credentials.

## 1. Configuration Analysis (`ca.conf`)
We started by auditing the OpenSSL configuration to match our Vagrant environment.

- **Trust Model**: The **CA** is the only certificate with `CA:TRUE`. All other components (API Server, Kubelet) rely on this single root of trust.
- **Identity (CN/O)**:
  - **Admin**: `O=system:masters` gives sudo-like powers.
  - **Kubelet**: `CN=system:node:<name>` and `O=system:nodes` are strictly required for the Node Authorizer.
- **Key Usage**:
  - **ClientAuth**: "I am knocking on the door" (e.g., Kubelet reporting status).
  - **ServerAuth**: "I am the building" (e.g., API Server taking requests, or Kubelet allowing `kubectl logs`).

## 2. Environment Alignment (The "Gotcha" Fix)
We discovered a discrepancy between our VM names (`worker-0` in Vagrantfile) and the tutorial's defaults (`node-0`).
- **Action**: Renamed all references in `ca.conf` and `machines.txt` to `worker-0`.
- **Reason**: Certificates bind identity to a name/IP. If `worker-0` tries to present a certificate saying "I am node-0", the handshake fails.
- **IPs**: Added specific LAN IPs (`10.240.0.12`) to the Subject Alternative Names (SANs) to allow IP-based verification within the cluster network.

## 3. Certificate Generation
We generated keys on the **Jumpbox** (acting as the secure administrative host).
- Created the **Root CA** key and cert.
- Signed certificates for:
  - `admin` (User)
  - `worker-0`, `worker-1` (Nodes)
  - `kube-proxy`, `kube-scheduler`, `kube-controller-manager` (Control Plane Components)
  - `kube-api-server`, `service-accounts` (Core Server)

## 4. Distribution Strategy
This was the final and most critical physical step.

### Worker Nodes
**Command:** `scp worker-0.crt root@worker-0:/var/lib/kubelet/kubelet.crt`
- **Source**: `worker-0.crt` (Unique to the machine)
- **Destination**: `/var/lib/kubelet/kubelet.crt` (Generic name)
- **Why?** This allows us to use one standard `kubelet.conf` configuration file for all nodes. The configuration simply points to `kubelet.crt`, and because we renamed the unique file during copy, it "just works" on every machine without custom config files per node.

### Server Node
**Command**: `scp ca.key ca.crt kube-api-server.* service-accounts.* root@server:~/`
- **Destination**: Home directory (for now).
- **Reason**: The Control Plane components will leverage these to bootstrap the cluster services in the next labs.
