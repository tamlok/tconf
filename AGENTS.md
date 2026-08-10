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
| claude-opus-5 | 1,000,000 | 936,000 | 64,000 |
| gpt-5.6-sol | 1,050,000 | 922,000 | 128,000 |
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
Edit all three keys in `kilo/kilo.jsonc` (`limit.context`/`input`/`output`, and
the model `id`/`name`/key if it was renamed). `input` is NOT cosmetic: when it is
absent Kilo inherits the stale models.dev value. Then deploy to the live config
location (`setup.sh` maps `kilo/kilo.jsonc` -> `$CONFIG_HOME/kilo/kilo.jsonc`; on
Windows run the config-only action of `setup.ps1`, which copies `kilo\kilo.jsonc`
plus `AGENTS.md` and `agent\*.md` into `%USERPROFILE%\.config\kilo`):
```pwsh
.\setup.ps1 -Action config
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

## GitHub Copilot CLI (`copilot`) Configuration

This is the standalone `@github/copilot` binary, **not** the `github-copilot`
provider in `kilo/kilo.jsonc` / `opencode/opencode.json`. The two are unrelated
and gated differently.

### Which files are ours

| Path | Role |
|---|---|
| `~/.copilot/settings.json` | User-editable settings. Tracked here as `copilot/settings.json`. |
| `~/.copilot/config.json` | CLI-managed app state (`trustedFolders`, first-launch flags). Do **not** track or delete. |
| `~/.copilot/permissions-config.json` | Saved per-project tool approvals. Do **not** track or delete. |

Auth is **not** stored under `~/.copilot` — the CLI inherits it from the `gh`
CLI credential store (`GitHub CLI authenticated with valid token` in the debug
log), which is why the temp-`COPILOT_HOME` probe below still authenticates.

`COPILOT_HOME` overrides the whole directory; the path is `~/.copilot` on every
OS (it is not XDG-based), so `setup.sh` targets `$HOME/.copilot`, not
`$CONFIG_HOME`. Deploy with `.\setup.ps1 -Action config` (or `./setup.sh config`).
Both scripts replace **only** `settings.json` — never junction/clear `~/.copilot`,
which holds `session-state/`, `session-store.db`, `logs/` and the files above.
Note the CLI itself rewrites `settings.json` when `/model`, `/settings`, `/theme`
or a persisted URL approval changes a setting, so re-deploying clobbers those.

### Model availability is gated by billing plan, not by CLI version

The CLI filters the CAPI catalog by `billing.restricted_to` against the account's
plan. Both `copilot help config`'s model list and the `/models` REST response
**over-report** — REST reports e.g. `claude-opus-5` as `model_picker_enabled:
true` while the CLI rejects it with `Model "..." is not available`. A mis-pinned
model does not hard-fail: the CLI logs a warning and silently falls back to its
default, so always confirm via the CLI's own debug log.

The probe below is the authoritative check. It costs no AI credits **only when
the candidate is rejected** (resolution fails before any model call) — if the
candidate *is* available the CLI runs a real turn and bills for it. It **must**
set `COPILOT_CACHE_HOME`: the catalog is cached outside `COPILOT_HOME`, so
without a cold cache the `fetched models from CAPI /models` line is never
emitted.

```pwsh
$candidate = 'claude-opus-5'
$h = Join-Path $env:TEMP ("cp-probe-h-" + [guid]::NewGuid())
$c = Join-Path $env:TEMP ("cp-probe-c-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $h, $c | Out-Null
$oldHome = $env:COPILOT_HOME; $oldCache = $env:COPILOT_CACHE_HOME
try {
    $env:COPILOT_HOME = $h; $env:COPILOT_CACHE_HOME = $c
    & copilot -p "hi" --model $candidate --log-level all --no-color
} finally {
    $env:COPILOT_HOME = $oldHome; $env:COPILOT_CACHE_HOME = $oldCache
}
$log = (Get-ChildItem "$h\logs" -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime | Select-Object -Last 1).FullName
# Guard first: with $log unset, PowerShell drops the argument and rg silently
# searches the CWD instead, so the negative assertion below would read as a
# false "selectable".
if (-not $log) { throw "probe produced no log - result is meaningless" }
rg -q 'fetched models from CAPI /models' $log
if ($LASTEXITCODE -ne 0) { throw "no catalog fetch in log - result is meaningless" }
# Authoritative result: absence of this warning means $candidate is selectable.
rg -o "Model '$candidate' from CLI argument is not available" $log
# Full catalog incl. billing.restricted_to (single JSON-in-string line):
rg -o 'fetched models from CAPI /models .*' $log
```

The current pin is `claude-sonnet-5` (individual Pro plan: every Opus SKU,
`claude-fable-5`, `gpt-5.5` and `gpt-5.6-sol` are restricted to
`pro_plus`/`business`/`enterprise`/`max`). Re-run the probe whenever the CLI
auto-updates or entitlements change — the pin goes stale silently.

### Effort and context tier

`effortLevel` (`low`/`medium`/`high`/`xhigh`) and `contextTier`
(`default`/`long_context`) are both observable in a `--log-level all` run:
`"model": "capi:claude-sonnet-5:defaultReasoningEffort=high"` and a resolved
`"max_context_window_tokens": 1000000` (the `default` tier resolves to
`264000`). Match the pretty-printed form *with* the space after the colon — the
raw catalog dump on the `fetched models from CAPI` line is compact and
JSON-escaped and carries every model's window size, so a bare-number grep
matches regardless of tier. Do not assert on `max_prompt_tokens` — `936000`
also appears inside the `billing.token_prices.long_context` block on a
`default`-tier run.

### Autopilot

There is **no** setting that starts a session in autopilot. `stayInAutopilot`
only keeps you there between tasks; the initial mode comes from `--autopilot`
(or `--mode autopilot`), which is supplied by the nushell alias in
`nushell/config.nu` together with `--allow-all-tools` (autopilot auto-denies
anything needing approval, and `--allow-all-tools` is the flag its help text
names as required). The alias deliberately does **not** use `--yolo`, which is
`--allow-all-tools --allow-all-paths --allow-all-urls` — that would disable file
path verification and make the `allowedUrls` list dead configuration. The alias
is nushell-only; `copilot` launched from pwsh starts interactive. Escape hatch:
`^copilot ...`.

Do not add `logLevel: "all"` to the tracked settings: it persists full prompts,
tool calls and verbatim file contents to unrotated plaintext under
`~/.copilot/logs/`. Pass `--log-level all` per invocation instead, as the probe
above does.

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
