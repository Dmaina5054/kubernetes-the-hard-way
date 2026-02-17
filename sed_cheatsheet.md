# The SRE's Sed & Shell Cheatsheet 🛠️

This file tracks the powerful shell commands we've used throughout the Kubernetes The Hard Way journey. Mastering these is a massive step toward CKA and Senior SRE roles.

## `sed` (Stream Editor)
Used for automated text transformations.

### 1. Simple Find and Replace
Used in Module 04/05 to update configuration templates.
```bash
sed -i "s/worker-0/$(hostname -s)/g" ca.conf
```
- `-i`: "In-place" (saves changes to the file).
- `s`: Substitute command.
- `/`: The standard delimiter.
- `g`: Global (replace all occurrences on the line).

### 2. Alternative Delimiters (The `|` Trick)
Used in Module 09 for subnets.
```bash
sed "s|SUBNET|$SUBNET|g" configs/10-bridge.conf > 10-bridge.conf
```
- **Why `|`?**: When the replacement text (like an IP range `10.200.0.0/24`) contains forward slashes, using `/` as a delimiter would break the command. `sed` allows you to use almost any character as a delimiter.
- `> filename`: Redirects the output to a new file instead of changing the original.

---

## `ip route` (The Kernel's Map)
Used to view and modify how packets travel between networks.

### 1. General Syntax
```bash
ip route add {NETWORK} via {GATEWAY} dev {INTERFACE}
```
- **`via {GATEWAY}`**: The "Next Hop". Use this when the destination is *behind* another machine (like our Pods).
- **`dev {INTERFACE}`**: Forces the packet out of a specific physical/virtual port.

### 2. The `scope` Attribute
The "Scope" tells the kernel how "near" the destination is.

| Scope | Meaning | Example |
| :--- | :--- | :--- |
| **`host`** | The IP belongs to this machine. | `127.0.0.1` |
| **`link`** | The IP is on the local wire (no router needed). | Your `10.240.0.x` neighbors. |
| **`global`** | The IP is somewhere else (needs a gateway). | Internet or Pod network. |

**CKA Pro-Tip**: You rarely add `scope link` manually. The Linux Kernel adds it automatically the moment you give an interface an IP address (e.g., `ip addr add 10.240.0.11/24`). It effectively says: *"I can see everyone in this range directly, I don't need a middle-man."*

---

## `cut` (Column Extraction)
Used to pull specific data out of patterned text files like `machines.txt`.

### 1. Extracting by Space
```bash
SUBNET=$(grep ${HOST} machines.txt | cut -d " " -f 4)
```
- `-d " "`: The delimiter is a space.
- `-f 4`: Field 4.
- **Note**: Unlike most programming languages where indexes start at 0, **`cut` starts at 1**.
  - `1`: IP Address
  - `2`: FQDN
  - `3`: Short Name
  - `4`: Pod Subnet

---

## `grep` (Search)
```bash
grep ${HOST} machines.txt
```
- Searches for the specific hostname (e.g., `worker-0`) within the machine database.

## Combined Power: The Distribution Loop
```bash
for HOST in worker-0 worker-1; do
  # Find the subnet for this host
  SUBNET=$(grep ${HOST} machines.txt | cut -d " " -f 4)
  
  # Inject it into the config
  sed "s|SUBNET|$SUBNET|g" configs/10-bridge.conf > 10-bridge.conf
  
  # Send it
  scp 10-bridge.conf root@${HOST}:~/
done
```
