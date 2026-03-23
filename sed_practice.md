# `sed` Mastery: SRE Practice Lab 🛠️

This lab is designed to take you from "randomly copy-pasting sed commands" to "architectural surgical precision." 

## 🏗️ Setup your Sandbox
Before starting, create your practice file:
```bash
cat <<EOF > practice.txt
# Cluster Configuration
# Version: 1.29
server: localhost
port: 6443
nodes:
  - name: worker-0
    ip: 10.240.0.12
  - name: worker-0
    ip: 10.240.0.13
EOF
```

---

## 🟢 Level 1: Basic Substitution
**Goal**: Learn the fundamental `s/old/new/` syntax.

### Exercise 1.1: The Dry Run
Replace "localhost" with "10.240.0.11" but **do not save the file**.
> **Command**: `sed 's/localhost/10.240.0.11/' practice.txt`

### Exercise 1.2: The Global Stamp
Notice that `worker-0` appears twice. Replace BOTH with `worker-1`.
> **Command**: `sed 's/worker-0/worker-1/g' practice.txt`
> **Check**: Did it change both or just the first one?

---

## 🟡 Level 2: Precision Engineering
**Goal**: Target specific lines or patterns to avoid "collateral damage."

### Exercise 2.1: Line Number Targeting
Change "worker-0" to "worker-1" ONLY on line 8.
> **Command**: `sed '8s/worker-0/worker-1/' practice.txt`

### Exercise 2.2: Pattern Matching
Change the IP `10.240.0.12` to `10.250.0.12` but only on the line where `worker-0` was mentioned right above it (Line 7/8). Or simpler: only replace on lines containing "12".
> **Command**: `sed '/.12/s/10.240/10.250/' practice.txt`

---

## 🔴 Level 3: The SRE Janitor
**Goal**: Scripted cleanup of configuration files.

### Exercise 3.1: Strip Comments
View the file without any lines starting with `#`.
> **Command**: `sed '/^#/d' practice.txt`

### Exercise 3.2: Delete Empty Lines
Add some empty lines to your file and then remove them.
> **Command**: `sed '/^$/d' practice.txt`

---

## 🔥 Level 4: The 10x Engineer Challenge
**Goal**: Template Grafting.

### Exercise 4.1: Environment Injection
Use double quotes to replace `worker-0` with your current machine's hostname.
> **Command**: `sed "s/worker-0/$(hostname)/g" practice.txt`

---

## 🚨 SRE Safety Rules
1. **Always use a Backup**: `sed -i.bak 's/old/new/' file`
2. **Double Quotes for Variables**: Use `"..."` if you have a `$` inside the command.
3. **Use alternate delimiters**: If you are editing a URL (which has `/`), you can use pipe `|` or hash `#`:
   `sed 's|http://localhost|https://server.local|' file`

---

## 🧠 Socratic Graduation Question
If you have a variable `NEW_IP="10.240.0.50"`, which of these will work and why?
1. `sed 's/localhost/$NEW_IP/' config`
2. `sed "s/localhost/$NEW_IP/" config`

*Ref: Check your identity expansion rules in GEMINI.md!*
