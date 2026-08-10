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
16. Always submit to Momus for high accuracy review when building a plan
17. Always delegate to the `review` subagent (Task tool) for a second-opinion review before treating work as done: after finalizing a plan, and after completing a non-trivial implementation. The `review` subagent runs on a separate model (GPT high) and is read-only, so it will not modify code.
18. Prefer PlantUML to Mermaid by default when drawing diagrams

## The `review` subagent

`review` is a read-only, second-opinion reviewer defined in `agent/review.md`. It runs on a different model than the plan/work modes so the review is an independent check, not the same model grading itself.

When to call it (via the Task tool):
- After you finalize a PLAN and before implementation begins — pass the plan (or its path) and ask for a plan review.
- After you complete a non-trivial IMPLEMENTATION — ask it to review the working-tree diff.

Skip it only for trivial changes (typo/comment/formatting-only or tiny single-line tweaks). If `review` returns a FAIL with blocking issues, address them (or explain why they are not blocking) before considering the work done.

### Kilo overrides (these win over the skill text)

- **Worktrees**: ignore the git-stash and manual `git worktree` flows in
  `using-git-worktrees` / `finishing-a-development-branch`. Use Kilo Agent Manager
  worktrees and honor rule 14 (no separate worktree unless requested). Never `git stash` —
  stashes are shared across Agent Manager worktrees.
- **Code review**: `requesting-code-review` / `receiving-code-review` map onto the `review`
  subagent (rules 16-17). Do not spawn a second reviewer; dispatch to `review` via the Task
  tool and treat its verdict per rule 17.

