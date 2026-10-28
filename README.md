# tconf
Configuration files for Linux/Windows.

## Install configs

From the repository root:

```powershell
.\setup.ps1 -Action config
```

```sh
./setup.sh config
```

These deploy the tracked WezTerm, Nushell, OMP (including the checkpoint
reviewer), GitHub Copilot CLI, and Zellij configs. Re-running overwrites those
configs. Claude, Kilo, OpenCode, and Windows Terminal configs are no longer
managed; existing copies are left untouched.

Omit `-Action config` (Windows) or `config` (Linux/macOS) to also run the existing
package/tool and font installation steps. Package choices are unchanged.
The Linux/macOS config action also sets the global Git name and email.

## OMP

`omp/config.yml` uses `github-copilot/gpt-6-astra-1m:high` for the `default`,
`slow`, and `plan` roles. The `smol` and `advisor` selections are unchanged;
the continuous advisor remains disabled.

Verified on 2026-10-13 with `omp models refresh`,
`omp models find gpt-6-astra --json`, and successful live prompts.
