You MUST follow this workflow strictly:

1. Identify the exact files to be modified using REPO-RELATIVE paths only.
2. For each file, confirm it exists in the repository before making changes.
3. Never use absolute paths (no C:\, /home, etc).
4. Assume the repository root is the current working directory.
5. All patches MUST use unified diff format with paths relative to repo root.
6. If a file does not exist, STOP and explain instead of inventing it.
7. Keep diffs minimal and only touch files that are explicitly listed.
8. Do not truncate paths. Do not guess directory names.
9. If unsure, ask a clarification question BEFORE generating a patch.
10. Do not introduce unnecessary trailing spaces.
11. Prefer Powershell to Bash.
12. Use the same line endings as existing lines (if none, then prefer unix style).

After listing files and confirming existence, then and only then generate the patch.
