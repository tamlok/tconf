#!/usr/bin/env bash
# Install utilities and configs on Linux/macOS for development.
# Le Tan (tamlokveer at gmail.com)
# https://github.com/tamlok/tnvim
#
# Usage:
#   ./setup.sh           Install packages + tools + configs
#   ./setup.sh config    Only (re)deploy config files
#
# Linux distro support is pluggable: each platform provides a
# "<platform>_bootstrap" and "<platform>_pkg_install" function plus a
# generic->native package name mapping. To add a new distro, implement
# those two functions (see the "ubuntu" driver below) and you are done.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --------------------------------------------------------------------------
# Logging helpers
# --------------------------------------------------------------------------
log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; }

# --------------------------------------------------------------------------
# Platform detection
#   OS        -> "linux" | "macos"
#   PLATFORM  -> distro id on Linux (e.g. "ubuntu") or "macos" on macOS.
# PLATFORM is the key used to dispatch package-manager drivers.
# --------------------------------------------------------------------------
OS=""
PLATFORM=""

detect_platform() {
    case "$(uname -s)" in
        Darwin)
            OS="macos"
            PLATFORM="macos"
            ;;
        Linux)
            OS="linux"
            detect_distro
            ;;
        *)
            err "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

detect_distro() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        PLATFORM="${ID:-}"
    fi
    if [ -z "$PLATFORM" ]; then
        err "Cannot detect Linux distribution (missing /etc/os-release)."
        exit 1
    fi
}

# --------------------------------------------------------------------------
# Package-manager abstraction
#
# Dispatches "pkg_<action>" to "<PLATFORM>_<action>". If the current
# platform has no driver, we fail with a helpful message pointing at the
# extension point.
# --------------------------------------------------------------------------
pkg_dispatch() {
    local action="$1"; shift
    local fn="${PLATFORM}_${action}"
    if ! declare -F "$fn" >/dev/null 2>&1; then
        err "Platform '$PLATFORM' is not supported yet."
        err "Add a '${PLATFORM}_bootstrap' and '${PLATFORM}_pkg_install' driver to support it."
        exit 1
    fi
    "$fn" "$@"
}

pkg_bootstrap()    { pkg_dispatch bootstrap; }
pkg_install()      { pkg_dispatch pkg_install "$@"; }
# Install tools that are not in the default repos, using each platform's
# recommended method (see <platform>_install_tools below).
pkg_install_tools() { pkg_dispatch install_tools; }

# ----- Ubuntu driver ------------------------------------------------------
ubuntu_bootstrap() {
    log "Updating apt package index"
    sudo apt-get update -y
    # Prerequisites for adding 3rd-party apt repos (e.g. Nushell).
    sudo apt-get install -y ca-certificates curl gnupg
}

# Map a generic package name to native package(s). Empty output = skip.
ubuntu_pkg_name() {
    case "$1" in
        # neovim from apt is too old; installed from the official release instead.
        neovim)     echo "" ;;
        ripgrep)    echo "ripgrep" ;;
        ctags)      echo "universal-ctags" ;;
        gtags)      echo "global" ;;
        python)     echo "python3 python3-pip python3-venv" ;;
        node)       echo "nodejs npm" ;;
        git)        echo "git" ;;
        curl)       echo "curl" ;;
        fontconfig) echo "fontconfig" ;;
        *)          echo "$1" ;;
    esac
}

ubuntu_pkg_install() {
    local g native pkgs=""
    for g in "$@"; do
        native="$(ubuntu_pkg_name "$g")"
        [ -n "$native" ] && pkgs="$pkgs $native"
    done
    [ -z "$pkgs" ] && return 0
    log "Installing via apt:$pkgs"
    # shellcheck disable=SC2086
    sudo apt-get install -y $pkgs
}

# Tools not in Ubuntu's default repos, installed via their documented methods.
ubuntu_install_tools() {
    install_neovim            # official prebuilt release (apt's is too old)
    # install_opencode          # official install script (disabled)
    install_kilo              # kilo CLI via npm (@kilocode/cli)
    ubuntu_install_nushell    # official apt.fury.io repository
    install_zellij            # cargo (recommended) or prebuilt binary
}

# https://www.nushell.sh/book/installation.html (Debian & Ubuntu)
ubuntu_install_nushell() {
    if command -v nu >/dev/null 2>&1; then
        log "nushell already installed"
        return 0
    fi
    log "Adding Nushell apt repository (apt.fury.io)"
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://apt.fury.io/nushell/gpg.key \
        | sudo gpg --dearmor -o /etc/apt/keyrings/fury-nushell.gpg
    echo "deb [signed-by=/etc/apt/keyrings/fury-nushell.gpg] https://apt.fury.io/nushell/ /" \
        | sudo tee /etc/apt/sources.list.d/fury-nushell.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y nushell
}

# ----- macOS driver (Homebrew) -------------------------------------------
macos_bootstrap() {
    if ! command -v brew >/dev/null 2>&1; then
        log "Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    log "Updating Homebrew"
    brew update
}

macos_pkg_name() {
    case "$1" in
        neovim)     echo "neovim" ;;
        ripgrep)    echo "ripgrep" ;;
        ctags)      echo "universal-ctags" ;;
        gtags)      echo "global" ;;
        python)     echo "python" ;;
        node)       echo "node" ;;
        git)        echo "git" ;;
        # curl/fontconfig ship with macOS.
        curl|fontconfig) echo "" ;;
        *)          echo "$1" ;;
    esac
}

macos_pkg_install() {
    local g native pkgs=""
    for g in "$@"; do
        native="$(macos_pkg_name "$g")"
        [ -n "$native" ] && pkgs="$pkgs $native"
    done
    [ -z "$pkgs" ] && return 0
    log "Installing via brew:$pkgs"
    # shellcheck disable=SC2086
    brew install $pkgs
}

# On macOS everything is available via Homebrew (the documented method).
macos_install_tools() {
    # opencode installation disabled (using kilo instead)
    # if ! command -v opencode >/dev/null 2>&1; then
    #     log "Installing opencode via Homebrew"
    #     brew install anomalyco/tap/opencode || warn "opencode install failed"
    # else
    #     log "opencode already installed"
    # fi
    if ! command -v nu >/dev/null 2>&1; then
        log "Installing nushell via Homebrew"
        brew install nushell || warn "nushell install failed"
    else
        log "nushell already installed"
    fi
    if ! command -v zellij >/dev/null 2>&1; then
        log "Installing zellij via Homebrew"
        brew install zellij || warn "zellij install failed"
    else
        log "zellij already installed"
    fi
    install_kilo    # kilo CLI via npm (@kilocode/cli)
}

# --------------------------------------------------------------------------
# Shared tool installers used by the platform drivers above.
# Each is idempotent: skips if the command already exists.
# --------------------------------------------------------------------------
LOCAL_BIN="$HOME/.local/bin"

# https://opencode.ai/docs  (official install script, cross-platform)
# Always lands on the latest release: upgrades in place if already present,
# otherwise installs fresh via the official website script.
install_opencode() {
    if command -v opencode >/dev/null 2>&1; then
        log "Upgrading opencode to the latest version"
        opencode upgrade || warn "opencode upgrade failed"
        return 0
    fi
    log "Installing latest opencode"
    curl -fsSL https://opencode.ai/install | bash || warn "opencode install failed"
}

# https://kilo.ai/docs/getting-started/installing (CLI)
# Installs/updates the Kilo CLI globally via npm. Requires node/npm, which is
# installed by pkg_install (generic name "node"). Idempotent: npm -g reinstall
# lands on the latest published version.
install_kilo() {
    if ! command -v npm >/dev/null 2>&1; then
        warn "npm not found; skipping kilo CLI install"
        return 0
    fi
    log "Installing/upgrading kilo CLI (@kilocode/cli)"
    npm install -g @kilocode/cli || warn "kilo CLI install failed"
}

# https://zellij.dev/documentation/installation
# Recommended when no OS package exists: cargo install --locked zellij.
# Falls back to the prebuilt binary from the GitHub release page.
install_zellij() {
    if command -v zellij >/dev/null 2>&1; then
        log "zellij already installed"
        return 0
    fi
    if command -v cargo >/dev/null 2>&1; then
        log "Installing zellij via cargo"
        cargo install --locked zellij && return 0
        warn "cargo install zellij failed, falling back to prebuilt binary"
    fi
    local cpu plat arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)  cpu="x86_64" ;;
        aarch64|arm64) cpu="aarch64" ;;
        *) warn "zellij: unsupported arch '$arch', skipping"; return 0 ;;
    esac
    case "$OS" in
        linux) plat="unknown-linux-musl" ;;
        macos) plat="apple-darwin" ;;
    esac
    local url="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${cpu}-${plat}.tar.gz"
    log "Installing zellij prebuilt binary from $url"
    mkdir -p "$LOCAL_BIN"
    if curl -fsSL "$url" | tar -xz -C "$LOCAL_BIN" zellij; then
        chmod +x "$LOCAL_BIN/zellij"
    else
        warn "zellij install failed"
    fi
}

# https://github.com/neovim/neovim/blob/master/INSTALL.md (prebuilt release)
# Distro packages lag badly, so Linux pulls the official tarball into
# ~/.local/opt and symlinks the binary onto PATH (~/.local/bin wins over /usr/bin).
NVIM_OPT="$HOME/.local/opt"
install_neovim() {
    local cpu arch dir
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)  cpu="x86_64" ;;
        aarch64|arm64) cpu="arm64" ;;
        *) warn "neovim: unsupported arch '$arch', skipping"; return 0 ;;
    esac
    dir="nvim-linux-${cpu}"
    if [ -x "$NVIM_OPT/$dir/bin/nvim" ]; then
        log "neovim (official) already installed"
        return 0
    fi
    local url="https://github.com/neovim/neovim/releases/latest/download/${dir}.tar.gz"
    log "Installing neovim prebuilt binary from $url"
    mkdir -p "$NVIM_OPT" "$LOCAL_BIN"
    rm -rf "$NVIM_OPT/$dir"
    if curl -fsSL "$url" | tar -xz -C "$NVIM_OPT"; then
        ln -sf "$NVIM_OPT/$dir/bin/nvim" "$LOCAL_BIN/nvim"
    else
        warn "neovim install failed"
    fi
}

# --------------------------------------------------------------------------
# Config deployment
# --------------------------------------------------------------------------
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# install_config <source-relative> <destination-absolute>
install_config() {
    local src="$SCRIPT_DIR/$1" dest="$2"
    if [ ! -e "$src" ]; then
        warn "Missing source config: $src"
        return 0
    fi
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
    log "Installed config: $dest"
}

nushell_config_dir() {
    if [ "$OS" = "macos" ]; then
        echo "$HOME/Library/Application Support/nushell"
    else
        echo "$CONFIG_HOME/nushell"
    fi
}

setup_config() {
    # wezterm
    install_config "wezterm.lua" "$CONFIG_HOME/wezterm/wezterm.lua"

    # kilo
    install_config "kilo/kilo.jsonc" "$CONFIG_HOME/kilo/kilo.jsonc"
    install_config "kilo/AGENTS.md" "$CONFIG_HOME/kilo/AGENTS.md"

    # nushell
    local nu_dir
    nu_dir="$(nushell_config_dir)"
    install_config "nushell/env.nu" "$nu_dir/env.nu"
    install_config "nushell/config.nu" "$nu_dir/config.nu"

    # claude
    install_config "claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    install_config "claude/settings.json" "$HOME/.claude/settings.json"

    # opencode
    install_config "opencode/AGENTS.md" "$CONFIG_HOME/opencode/AGENTS.md"
    install_config "opencode/oh-my-openagent.json" "$CONFIG_HOME/opencode/oh-my-openagent.json"
    install_config "opencode/opencode.json" "$CONFIG_HOME/opencode/opencode.json"

    # zellij
    install_config "zellij/config.kdl" "$CONFIG_HOME/zellij/config.kdl"
    local layout
    for layout in "$SCRIPT_DIR"/zellij/l_*.kdl; do
        [ -e "$layout" ] || continue
        install_config "zellij/$(basename "$layout")" "$CONFIG_HOME/zellij/layouts/$(basename "$layout")"
    done

    git config --global user.name "Le Tan"
    git config --global user.email "tamlokveer@gmail.com"
}

# --------------------------------------------------------------------------
# Fonts
# --------------------------------------------------------------------------
install_fonts() {
    local dest
    case "$OS" in
        linux) dest="$HOME/.local/share/fonts" ;;
        macos) dest="$HOME/Library/Fonts" ;;
    esac
    log "Installing fonts to $dest"
    mkdir -p "$dest"
    cp -f "$SCRIPT_DIR"/fonts/*.ttf "$dest"/
    if [ "$OS" = "linux" ] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$dest" >/dev/null 2>&1 || true
    fi
}

# --------------------------------------------------------------------------
# Environment
# --------------------------------------------------------------------------
ensure_line_in_file() {
    local line="$1" file="$2"
    touch "$file"
    if ! grep -qsF -- "$line" "$file"; then
        printf '%s\n' "$line" >> "$file"
        log "Updated $file"
    fi
}

setup_env() {
    local rc="$HOME/.bashrc"
    # opencode uses EDITOR to detect the editor.
    ensure_line_in_file 'export EDITOR=nvim' "$rc"
    # Make ~/.local/bin and neovim mason binaries available.
    ensure_line_in_file 'export PATH="$HOME/.local/bin:$HOME/.local/share/nvim/mason/bin:$PATH"' "$rc"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
main() {
    local action="${1:-}"

    detect_platform
    log "Detected platform: $OS ($PLATFORM)"

    if [ "$action" = "config" ]; then
        setup_config
        return 0
    fi

    pkg_bootstrap
    pkg_install neovim ripgrep ctags gtags python node git fontconfig

    # Tools not in the default repos (opencode, nushell, zellij),
    # installed via each platform's recommended method.
    pkg_install_tools

    install_fonts

    # pynvim for neovim's python provider.
    python3 -m pip install --user --upgrade pynvim 2>/dev/null \
        || warn "Could not install pynvim (try: pipx install pynvim)"

    setup_config
    setup_env

    log "Done. Restart your shell to pick up environment changes."
}

main "$@"
