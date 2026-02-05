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
