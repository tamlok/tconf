You MUST follow this workflow strictly:

1. Identify the exact files to be modified using REPO-RELATIVE paths only
2. For each file, confirm it exists in the repository before making changes
3. Never use absolute paths (no C:\, /home, etc)
4. Assume the repository root is the current working directory
5. All patches MUST use unified diff format with paths relative to repo root
6. If a file does not exist, STOP and explain instead of inventing it. New files explicitly listed in an approved implementation plan may be created.
7. Keep diffs minimal and only touch files that are explicitly listed
8. Do not truncate paths. Do not guess directory names
9. If unsure, ask a clarification question BEFORE generating a patch
10. Do not introduce unnecessary trailing spaces
11. Prefer Powershell to Bash
12. Use the same line endings as existing lines (if none, then prefer unix style)
13. Always commit at a random time at night (both authord and commit date, and if it is not reached yet today, use that of yesterday) which must not be earlier than the most recent commit
14. Do NOT create a separate worktree unless requested to
15. After listing files and confirming existence, then and only then generate the patch
16. For non-trivial changes, invoke `checkpoint-reviewer` after the plan is complete and again after implementation and verification are complete; wait for each review before proceeding
17. Resolve review blockers and investigate concerns before implementing the reviewed plan or delivering a completed implementation
18. Prefer PlantUML to Mermaid by default when drawing diagrams
19. Prefer rebase to merge when asked to push

## Checkpoint reviews

Use the read-only `checkpoint-reviewer` task agent for an independent second opinion. It uses the `advisor` model role, but the continuous OMP advisor must remain disabled. Do not run a duplicate continuous or bundled review for the same checkpoint.

This workflow applies to the primary implementer, not to the reviewer itself or to purely read-only investigations.

### Review checkpoints

1. **Plan ready, before edits:** finish the scope, approach, affected files, and verification plan, then invoke `task` with `agent: "checkpoint-reviewer"` and a PLAN assignment. Resolve material findings before starting implementation.
2. **Implementation ready, before delivery or commit:** finish the changes and run the relevant verification, then invoke the same agent with an IMPLEMENTATION assignment. Resolve material findings and rerun affected verification; request a targeted follow-up review when fixes materially change the reviewed result.

Each assignment must include the user requirements, checkpoint type, completed plan, exact file scope, and any relevant diff and verification evidence (or a readable artifact containing them). Subagents do not inherit the conversation. Tell the reviewer to skip formatters, linters, builds, and test suites; the primary owns verification.

The agent declares `blocking: true`. Stop all writers to the reviewed files and wait for its report; do not keep editing while it reviews. Invocation at these checkpoints is an instruction-level requirement, not an automatic runtime trigger. A failed or unavailable review is not approval: report the blocker rather than silently skipping it.

Treat review findings according to severity:
- A `blocker` must be resolved before proceeding past the checkpoint.
- A `concern` must be investigated and either addressed or explicitly shown not to apply.
- A `nit` is non-blocking and should be applied only when worthwhile.

### OMP overrides

- **Worktrees**: ignore the git-stash and manual `git worktree` flows in
  `using-git-worktrees` / `finishing-a-development-branch`. Use OMP-managed worktrees
  and honor rule 14 (no separate worktree unless requested). Never `git stash` because
  stashes are shared across worktrees.
- **Code review**: `requesting-code-review` / `receiving-code-review` map onto the
  checkpoint workflow above (rules 16-17). Use `checkpoint-reviewer`, not the continuous advisor.
