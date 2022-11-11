local wezterm = require "wezterm"

-- The filled in variant of the < symbol
local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
-- The filled in variant of the > symbol
local SOLID_RIGHT_ARROW = utf8.char(0xe0b0)
wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local edge_background = '#3b3486'
    local background = '#624f82'
    local foreground = '#d6e4e5'

    if tab.is_active then
      background = '#6c4ab6'
      foreground = '#ffffff'
    elseif hover then
      background = '#8d72e1'
      foreground = '#ffffff'
    end

    local edge_foreground = background

    -- ensure that the titles fit in the available space,
    -- and that we have room for the edges.
    local title = wezterm.truncate_left(tab.active_pane.title, max_width - 2)

    return {
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = SOLID_LEFT_ARROW },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = title },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = SOLID_RIGHT_ARROW },
    }
  end
)

return {
    default_prog = {"powershell"},
    default_cwd = "",

    window_close_confirmation = "NeverPrompt",
    check_for_updates = false,
    hide_tab_bar_if_only_one_tab = false,

    color_scheme = "OneHalfLight",

    font = wezterm.font("SauceCodePro Nerd Font"),
    font_size = 13,

    harfbuzz_features = {'calt=0', 'clig=0', 'liga=0'},
    enable_csi_u_key_encoding = true,

    use_fancy_tab_bar = true,

    window_frame = {
        font_size = 12.0,
        active_titlebar_bg = "#888888",
        inactive_titlebar_bg = "#888888",
    },

    colors = {
        tab_bar = {
            -- The color of the inactive tab bar edge/divider
            inactive_tab_edge = "#aaaaaa",
        },
    },

    automatically_reload_config = false,

    disable_default_key_bindings = true,
    leader = {key="a", mods="CTRL", timeout_milliseconds=1000},
    keys = {
        {key="e", mods="LEADER", action=wezterm.action.ShowLauncher},
        -- Send "CTRL-A" to the terminal when pressing CTRL-A, CTRL-A
        {key="a", mods="LEADER|CTRL", action=wezterm.action.SendString("\x01")},
        {key="|", mods="LEADER|SHIFT", action=wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}},
        {key="-", mods="LEADER", action=wezterm.action.SplitVertical{domain="CurrentPaneDomain"}},
        {key="h", mods="LEADER", action=wezterm.action.ActivatePaneDirection("Left")},
        {key="l", mods="LEADER", action=wezterm.action.ActivatePaneDirection("Right")},
        {key="z", mods="LEADER", action=wezterm.action.TogglePaneZoomState},
        {key="c", mods="LEADER", action=wezterm.action.CopyTo("Clipboard")},
        {key="v", mods="LEADER", action=wezterm.action.PasteFrom("Clipboard")},
        {key="Insert", mods="SHIFT", action=wezterm.action.PasteFrom("Clipboard")},
        {key="t", mods="LEADER", action=wezterm.action.SpawnTab("CurrentPaneDomain")},
        {key="t", mods="CTRL|SHIFT", action=wezterm.action.SpawnTab("CurrentPaneDomain")},
        {key="x", mods="LEADER", action=wezterm.action.CloseCurrentTab{confirm=true}},
        {key="n", mods="LEADER", action=wezterm.action.ActivateTabRelative(1)},
        {key="Tab", mods="CTRL", action=wezterm.action.ActivateTabRelative(1)},
        {key="p", mods="LEADER", action=wezterm.action.ActivateTabRelative(-1)},
        {key="Tab", mods="CTRL|SHIFT", action=wezterm.action.ActivateTabRelative(-1)},
        {key="1", mods="LEADER", action=wezterm.action.ActivateTab(0)},
        {key="2", mods="LEADER", action=wezterm.action.ActivateTab(1)},
        {key="3", mods="LEADER", action=wezterm.action.ActivateTab(2)},
        {key="4", mods="LEADER", action=wezterm.action.ActivateTab(3)},
        {key="5", mods="LEADER", action=wezterm.action.ActivateTab(4)},
        {key="6", mods="LEADER", action=wezterm.action.ActivateTab(5)},
        {key="7", mods="LEADER", action=wezterm.action.ActivateTab(6)},
        {key="8", mods="LEADER", action=wezterm.action.ActivateTab(7)},
        {key="9", mods="LEADER", action=wezterm.action.ActivateTab(8)},
        {key="0", mods="LEADER", action=wezterm.action.ActivateLastTab},
        {key="f", mods="LEADER", action=wezterm.action.Search{CaseSensitiveString=""}},
        {key="r", mods="LEADER", action=wezterm.action.ReloadConfiguration},
    },

    mouse_bindings = {
        {
            event = {Down={streak=1, button="Right"}},
            mods = '',
            action = wezterm.action.PasteFrom("Clipboard"),
        }
    },
}
