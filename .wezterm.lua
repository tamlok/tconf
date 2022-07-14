local wezterm = require "wezterm"
return {
    default_prog = {"powershell"},
    default_cwd = "",

    window_close_confirmation = "NeverPrompt",
    check_for_updates = false,
    hide_tab_bar_if_only_one_tab = false,

    -- disable_default_key_bindings = true,

    color_scheme = "OneHalfLight",

    font = wezterm.font("SauceCodePro Nerd Font"),
    font_size = 13,

    harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' },
    enable_csi_u_key_encoding = true,

    keys = {
        {key="l", mods="ALT", action=wezterm.action.ShowLauncher},
    }
}
