#!/bin/sh

install_fonts() {
    cp ./fonts/* /Users/checkoutadmin/Library/Fonts/
}

setup_config() {
    mkdir -p ~/.config/wezterm
    cp ./wezterm.lua ~/.config/wezterm/wezterm.lua
}

if [ "$1" = "config" ]; then
    setup_config
else
    install_fonts
    setup_config
fi
