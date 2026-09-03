You MUST follow this workflow strictly:

1. Identify the exact files to be modified using REPO-RELATIVE paths only
2. For each file, confirm it exists in the repository before making changes
3. Never use absolute paths (no C:\, /home, etc)
4. Assume the repository root is the current working directory
5. All patches MUST use unified diff format with paths relative to repo root
6. If a file does not exist, STOP and explain instead of inventing it
7. Keep diffs minimal and only touch files that are explicitly listed
8. Do not truncate paths. Do not guess directory names
9. If unsure, ask a clarification question BEFORE generating a patch
10. Do not introduce unnecessary trailing spaces
11. Prefer Powershell to Bash
12. Use the same line endings as existing lines (if none, then prefer unix style)
13. Always commit at a random time at night (both authord and commit date, and if it is not reached yet today, use that of yesterday) which must not be earlier than the most recent commit
14. Do NOT create a separate worktree unless requested to
15. After listing files and confirming existence, then and only then generate the patch
16. Keep the continuous OMP advisor enabled for an independent second opinion while planning and implementing non-trivial changes
17. Address advisor concerns and blockers before treating a plan or non-trivial implementation as complete
18. Prefer PlantUML to Mermaid by default when drawing diagrams

## The OMP advisor

The continuous advisor runs on a different model from the primary agent and follows the review priorities in `WATCHDOG.md`. It is read-only and reviews plans, tool activity, implementation changes, and final responses as the work progresses.

Treat advisor guidance according to its severity:
- A `blocker` must be resolved before continuing or completing the work.
- A `concern` must be investigated and either addressed or explicitly shown not to apply.
- A `nit` is non-blocking and should be applied only when worthwhile.

The advisor is the sole second-opinion mechanism. Do not spawn a separate review agent for the same review unless the user explicitly requests one.

### OMP overrides

- **Worktrees**: ignore the git-stash and manual `git worktree` flows in
  `using-git-worktrees` / `finishing-a-development-branch`. Use OMP-managed worktrees
  and honor rule 14 (no separate worktree unless requested). Never `git stash` because
  stashes are shared across worktrees.
- **Code review**: `requesting-code-review` / `receiving-code-review` map onto the continuous
  advisor (rules 16-17). Do not spawn a second reviewer; act on the advisor's guidance.
