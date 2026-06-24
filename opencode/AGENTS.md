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
      "output": <max_output_tokens>
    }
  }
}
```

### 3. Current Model Specs (as of June 2026)
| Model | Context | Output |
|-------|---------|--------|
| claude-opus-4.8 | 1,000,000 | 128,000 |
| gpt-5.5 | 1,050,000 | 128,000 |
| gemini-3-pro-preview | 1,000,000 | 65,536 |

### 4. Verification
After updating, verify specs at:
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
   `neovim ripgrep ctags gtags python tmux git curl fontconfig terminator`.
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
