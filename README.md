# tconf
Configuration files for Linux/Windows.

## OMP

`omp/config.yml` uses `github-copilot/gpt-6-astra-1m:high` for the `default`,
`slow`, and `plan` roles. The `smol` and `advisor` selections are unchanged;
the continuous advisor remains disabled.

Verified on 2026-10-13 with `omp models refresh`,
`omp models find gpt-6-astra --json`, and successful live prompts.
