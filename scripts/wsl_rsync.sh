#!/usr/bin/env bash
# wsl_rsync.sh — sync a directory from WSL (Linux) into the matching path on Windows.
#
# Path mapping: a Linux dir under $HOME maps to the same relative path under the
# Windows user profile. e.g. ~/study/vnote -> C:\Users\<user>\study\vnote.
#
# Usage:
#   wsl_rsync.sh <linux-dir> [extra rsync args...]
#   wsl_rsync.sh .              # sync the current directory
#   wsl_rsync.sh ~/study/vnote  # sync ~/study/vnote
#   wsl_rsync.sh . --dry-run    # preview without copying
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <linux-dir> [extra rsync args...]" >&2
  exit 1
fi

src_input=$1
shift

# Absolute, symlink-resolved source dir.
if [[ ! -d $src_input ]]; then
  echo "error: not a directory: $src_input" >&2
  exit 1
fi
src=$(cd "$src_input" && pwd -P)

# Source must live under $HOME so it maps cleanly onto the Windows profile.
home=$(cd "$HOME" && pwd -P)
if [[ $src != "$home" && $src != "$home"/* ]]; then
  echo "error: $src is not under \$HOME ($home); cannot map to Windows profile" >&2
  exit 1
fi
rel=${src#"$home"}
rel=${rel#/}

# Windows user profile (e.g. C:\Users\tanle) -> WSL path (/mnt/c/Users/tanle).
win_profile=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
if [[ -z $win_profile ]]; then
  echo "error: could not resolve %USERPROFILE% (is this WSL?)" >&2
  exit 1
fi
win_home=$(wslpath -u "$win_profile")
dest="$win_home/$rel"

mkdir -p "$dest"

echo "rsync: $src/ -> $dest/"
# drvfs has no real unix perms/owners; skip them to avoid noise and errors.
# honor .gitignore, and skip .git + build*/ so Windows only gets compilable sources.
rsync -rlt --delete --no-perms --no-owner --no-group \
  --exclude='.git/' --exclude='build*/' --filter=':- .gitignore' "$@" "$src/" "$dest/"
