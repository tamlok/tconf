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
13. Always commit at a random time at night (both authord and commit date, and if it is not reached yet today, use that of yesterday)
14. Do NOT create a separate worktree unless requested to
15. After listing files and confirming existence, then and only then generate the patch
16. Always submit to Momus for high accuracy review when building a plan
17. Always delegate to the `review` subagent (Task tool) for a second-opinion review before treating work as done: after finalizing a plan, and after completing a non-trivial implementation. The `review` subagent runs on a separate model (GPT high) and is read-only, so it will not modify code.

## The `review` subagent

`review` is a read-only, second-opinion reviewer defined in `agent/review.md`. It runs on a different model than the plan/work modes so the review is an independent check, not the same model grading itself.

When to call it (via the Task tool):
- After you finalize a PLAN and before implementation begins — pass the plan (or its path) and ask for a plan review.
- After you complete a non-trivial IMPLEMENTATION — ask it to review the working-tree diff.

Skip it only for trivial changes (typo/comment/formatting-only or tiny single-line tweaks). If `review` returns a FAIL with blocking issues, address them (or explain why they are not blocking) before considering the work done.

## Superpowers skills integration

The `superpowers` plugin (declared in `kilo.json` `plugin`) exposes its skills to every
agent through the `skill` tool. Availability is not activation — reach for them explicitly.

At the start of any non-trivial dev task, load `using-superpowers` first, then load the
skill that matches the current phase:

- Brainstorm / design (plan mode): `brainstorming`, then `writing-plans`.
- Implement a feature or bugfix: `test-driven-development`; for a written plan use
  `executing-plans` (separate session) or `subagent-driven-development` (current session);
  fan out independent work with `dispatching-parallel-agents`.
- Any bug, test failure, or surprise: `systematic-debugging` before proposing a fix.
- Before claiming done: `verification-before-completion` (run the checks, show the output),
  then the mandatory `review` subagent gate (rule 17).
- Authoring or editing skills themselves: `writing-skills`.

### Kilo overrides (these win over the skill text)

- **Worktrees**: ignore the git-stash and manual `git worktree` flows in
  `using-git-worktrees` / `finishing-a-development-branch`. Use Kilo Agent Manager
  worktrees and honor rule 14 (no separate worktree unless requested). Never `git stash` —
  stashes are shared across Agent Manager worktrees.
- **Code review**: `requesting-code-review` / `receiving-code-review` map onto the `review`
  subagent (rules 16-17). Do not spawn a second reviewer; dispatch to `review` via the Task
  tool and treat its verdict per rule 17.
- **Commits**: TDD's "commit after green" does NOT apply. Only commit when explicitly asked,
  and follow rule 13 (night-time author/commit date). Never auto-commit inside a skill loop.

## Updating GitHub Copilot Models

When adding or updating models for the GitHub Copilot provider:

### 1. Headers (in `opencode.json`)
The `copilot-developer-cli` integration ID unlocks extended models. Required headers:
```json
"headers": {
  "Copilot-Integration-Id": "copilot-developer-cli",
  "X-GitHub-Api-Version": "2026-06-01",
  "User-Agent": "copilot/1.0.64"
}
```
These values are verified against the official Copilot CLI bundle (`@github/copilot`
`package/app.js`): `Copilot-Integration-Id` defaults to `copilot-developer-cli`,
`X-GitHub-Api-Version` is the constant `2026-06-01`, and `User-Agent` is
`copilot/<cli-version>` (the bundle's `aS()` builds `${name-without-scope}/${version}`).
Do NOT statically set `X-Initiator` or `Openai-Intent` here — opencode sets those
per-request, and a static `X-Initiator` is rejected as "invalid initiator". The CLI does
NOT send `Editor-Version`/`Editor-Plugin-Version`. Run `update_copilot_headers.ps1` to
refresh these from the installed CLI and deploy to `%USERPROFILE%\.config\opencode`.

### 2. Custom Model Registration
opencode's model discovery doesn't send user headers, so extended models must be registered manually in `provider.github-copilot.models`:
```json
"models": {
  "model-id": {
    "id": "model-id",
    "name": "Display Name",
    "reasoning": true,
    "attachment": true,
    "tool_call": true,
    "limit": {
      "context": <context_window_tokens>,
      "input": <max_prompt_tokens>,
      "output": <max_output_tokens>
    }
  }
}
```

### 3. Current Model Specs (as of July 2026)
| Model | Context | Input | Output |
|-------|---------|-------|--------|
| claude-opus-4.8 | 1,000,000 | 936,000 | 64,000 |
| gpt-5.5 | 1,050,000 | 922,000 | 128,000 |
| gemini-3.1-pro-preview | 1,000,000 | 936,000 | 64,000 |

### 4. Establishing ground truth and verifying the config

Do NOT trust the models.dev base catalog (`~/.cache/kilo/models.json`) for
Copilot limits — it lags the live provider and is the source of stale values
(e.g. opus inheriting a 200K/168000 context/input). This is a known upstream
class of bug (opencode #31064, #28543, #20317). The **live Copilot API is the
source of truth**; the doc pages below are only a secondary sanity check.

#### Step 1 — Query the live Copilot models API (ground truth)
The bearer token lives in the CLI auth file; use it against the models endpoint.
Use `curl.exe` on Windows — `Invoke-RestMethod` mangles the JSON output.
```pwsh
$tok = (Get-Content -Raw "$env:USERPROFILE\.local\share\kilo\auth.json" |
  ConvertFrom-Json).'github-copilot'.access   # a usable gho_ bearer token
curl.exe -s https://api.githubcopilot.com/models -H "Authorization: Bearer $tok" |
  ConvertFrom-Json | Select-Object -Expand data |
  Select-Object id, @{n='context';e={$_.capabilities.limits.max_context_window_tokens}},
    @{n='input';e={$_.capabilities.limits.max_prompt_tokens}},
    @{n='output';e={$_.capabilities.limits.max_output_tokens}}
```
Map the fields to Kilo's `limit` schema: `context` = `max_context_window_tokens`,
`input` = `max_prompt_tokens`, `output` = `max_output_tokens`. The
`Copilot-Integration-Id` does not change these values (billing tiers like
`default`/`long_context` are pricing-only, not request caps). Confirm the exact
served model id here too — e.g. `gemini-3.1-pro-preview` is served while
`gemini-3-pro-preview` is not.

#### Step 2 — Update and deploy the config
Edit all three keys in `kilo/kilo.json` (`limit.context`/`input`/`output`, and
the model `id`/`name`/key if it was renamed). `input` is NOT cosmetic: when it is
absent Kilo inherits the stale models.dev value. Then deploy to the live config
location (`setup.sh` maps `kilo/kilo.json` -> `$CONFIG_HOME/kilo/kilo.json`; on
Windows there is no `setup.ps1`, so copy manually):
```pwsh
Copy-Item "kilo\kilo.json" "$env:USERPROFILE\.config\kilo\kilo.json" -Force
```

#### Step 3 — Verify the resolved values
A running Kilo caches the resolved model, so **fully restart** first, then read
back what Kilo actually resolves (not just what the file says):
```pwsh
kilo serve --port 8787   # in a separate process
curl.exe -s http://127.0.0.1:8787/config/providers |
  ConvertFrom-Json | ForEach-Object {
    ($_.providers | Where-Object id -eq 'github-copilot').models
  }
```
Confirm each model's `limit.context/input/output` matches Step 1, the renamed id
is present, and any old id is gone.

#### Secondary cross-check (docs)
- Anthropic: https://platform.claude.com/docs/en/about-claude/models
- OpenAI: https://developers.openai.com/api/docs/models
- Google: https://ai.google.dev/gemini-api/docs

## Adding a New Linux Distro to `setup.sh`

`setup.sh` (Linux/macOS) uses a pluggable package-manager abstraction. Platform
selection happens in `detect_platform`, which sets:
- `OS` -> `linux` or `macos`
- `PLATFORM` -> the dispatch key: the distro `ID` from `/etc/os-release` on Linux
  (e.g. `ubuntu`, `fedora`, `arch`), or `macos` on macOS.

Driver functions are dispatched by name via `pkg_dispatch`, which calls
`<PLATFORM>_<action>`. So to support a new distro, add functions prefixed with
that distro's `/etc/os-release` `ID`. No other code changes are required; an
unsupported `PLATFORM` fails fast with a message naming the functions to add.

### Required functions for a new distro `<id>`
1. `<id>_bootstrap` — refresh the package index and install any prerequisites
   needed to add 3rd-party repos (e.g. `ca-certificates curl gnupg`).
2. `<id>_pkg_name <generic>` — map a generic name to native package(s); echo an
   empty string to skip. Generic names currently used by `main`:
   `neovim ripgrep ctags gtags python git fontconfig`.
3. `<id>_pkg_install <generic>...` — translate generics via `<id>_pkg_name` and
   install them with the distro's package manager.
4. `<id>_install_tools` — install tools not in the default repos
   (`opencode`, `nushell`, `zellij`) using each project's documented method.

### Guidelines
- Reuse the shared helpers `install_opencode` (official install script) and
  `install_zellij` (cargo `--locked`, then prebuilt-binary fallback) where the
  distro has no native package.
- Prefer the upstream project's officially documented install command; verify it
  against the project docs before committing.
- Keep every installer idempotent: check `command -v <bin>` and skip if present.
- Use `sudo` only for the privileged package-manager steps.
- Model the new driver on the existing `ubuntu_*` functions, and test with
  `./setup.sh` (full) and `./setup.sh config` (config-only).
