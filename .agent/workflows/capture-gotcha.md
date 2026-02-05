---
description: Capture a technical gotcha or learning point into a notes file
---

1. Identify the technical "gotcha", error, or learning point from the recent conversation.
2. Identify the current "Major Topic" (e.g., "SSH Configuration", "TLS Certificates").
3. Determine the current date (YYYY-MM-DD).
4. Check if the file `gotchas.md` exists in the project root.
5. Append the following format to `gotchas.md`:

   ```markdown
   ## [YYYY-MM-DD] Topic: <Major Topic>
   **The Gotcha:**
   <Description of the tricky error or trap we fell into>
   
   **The Solution:**
   <How we resolved it>
   
   ---
   ```
