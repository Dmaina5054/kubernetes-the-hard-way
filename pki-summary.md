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

## 5. PKI Debugging Skills (Critical for SRE Work)

**The Reality**: In production, you'll spend more time debugging certificates than creating them. Most companies use automated tools (cert-manager, cloud PKI), but when things break at 3 AM, you need to know how to diagnose the issue.

### Essential Debugging Commands

**Inspect Certificate Details:**
```bash
# View full certificate information
openssl x509 -in cert.crt -text -noout

# Check expiry dates only
openssl x509 -in cert.crt -noout -dates

# Check Subject and Issuer
openssl x509 -in cert.crt -noout -subject -issuer
```

**Verify Certificate Chain:**
```bash
# Verify cert is signed by CA
openssl verify -CAfile ca.crt server.crt

# Check if cert matches private key
openssl x509 -noout -modulus -in cert.crt | openssl md5
openssl rsa -noout -modulus -in cert.key | openssl md5
# (Hashes should match)
```

### Common Certificate Errors & Solutions

| Error | Cause | Fix |
|-------|-------|-----|
| `x509: certificate has expired` | Certificate past expiry date | Rotate/renew certificate |
| `x509: certificate is valid for X, not Y` | SAN mismatch (wrong IP/DNS) | Regenerate cert with correct SANs |
| `x509: certificate signed by unknown authority` | CA not trusted | Add CA to trust store |
| `tls: bad certificate` | Wrong cert presented or CN mismatch | Verify correct cert file is being used |

### What You DON'T Need to Memorize

- **OpenSSL generation flags**: You'll rarely create certs manually in production
- **Exact certificate field syntax**: Tools handle this
- **Every possible openssl command**: Focus on inspection/verification

### What You DO Need to Know

1. **Where Kubernetes stores certificates:**
   - Control Plane: `/etc/kubernetes/pki/`
   - Kubelet: `/var/lib/kubelet/pki/`
   - User configs: `~/.kube/config`

2. **How to read certificate errors** in logs (API server, kubelet logs)

3. **The relationship between certificates and RBAC** (CN → User, O → Group)

4. **Certificate lifecycle** (creation → distribution → rotation → expiry)

**For CKA**: Understand the concepts and flow. The exam allows access to kubernetes.io docs.

**For SRE Interviews**: Be ready to explain how you'd debug "kubectl suddenly stopped working" or "new node won't join cluster" - both are usually certificate issues.
