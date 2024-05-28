local wezterm = require "wezterm"

local is_linux = function()
 return wezterm.target_triple:find("linux") ~= nil
end

local is_win = function()
 return wezterm.target_triple:find("windows") ~= nil
end

local is_macos = function()
 return wezterm.target_triple:find("darwin") ~= nil
end

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
  config = wezterm.config_builder()
end

wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local background = '#624f82'
    local foreground = '#d6e4e5'

    if tab.is_active then
      background = '#c47aff'
      foreground = '#ffffff'
    elseif hover then
      background = '#8d72e1'
      foreground = '#ffffff'
    end

    -- ensure that the titles fit in the available space
    local title = tab.active_pane.title
    space_start, _ = string.find(title, " ")
    if space_start ~= nil then
      title = title:sub(0, space_start)
    end
    title = wezterm.truncate_left(title, max_width)

    return {
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = title },
    }
  end
)

-- use NuShell by default
if is_win() then
  config.default_prog = {"nu"}
end

config.front_end = "WebGpu"

config.window_close_confirmation = "NeverPrompt"
config.check_for_updates = false
config.hide_tab_bar_if_only_one_tab = false

config.color_scheme = "One Light (base16)"

config.font = wezterm.font("SauceCodePro NFM")
config.font_size = 13

config.harfbuzz_features = {'calt=0', 'clig=0', 'liga=0'}
config.enable_csi_u_key_encoding = true

config.use_fancy_tab_bar = true

config.window_frame = {
    font_size = 12.0,
    active_titlebar_bg = "#888888",
    inactive_titlebar_bg = "#888888",
}

config.colors = {
    tab_bar = {
        -- The color of the inactive tab bar edge/divider
        inactive_tab_edge = "#aaaaaa",
    },
}

config.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.85,
}

config.launch_menu = {
    {
        label = "CEdgeTool",
        args = {"cmd", "/k", "C:\\Edge\\depot_tools\\scripts\\setup\\initEdgeEnv.cmd", "C:\\Edge"},
        cwd = "C:\\Edge\\src",
    },
    {
        label = "QEdgeTool",
        args = {"cmd", "/k", "Q:\\Edge\\depot_tools\\scripts\\setup\\initEdgeEnv.cmd", "Q:\\Edge"},
        cwd = "Q:\\Edge\\src",
    },
}

config.automatically_reload_config = false

config.disable_default_key_bindings = true
config.leader = {key="a", mods="CTRL", timeout_milliseconds=1000}
config.keys = {
    {key="e", mods="LEADER", action=wezterm.action.ShowLauncher},
    -- Send "CTRL-A" to the terminal when pressing CTRL-A, CTRL-A
    {key="a", mods="LEADER|CTRL", action=wezterm.action.SendString("\x01")},
    {key="|", mods="LEADER|SHIFT", action=wezterm.action.SplitHorizontal{domain="CurrentPaneDomain"}},
    {key="-", mods="LEADER", action=wezterm.action.SplitVertical{domain="CurrentPaneDomain"}},
    {key="h", mods="LEADER", action=wezterm.action.ActivatePaneDirection("Left")},
    {key="l", mods="LEADER", action=wezterm.action.ActivatePaneDirection("Right")},
    {key="z", mods="LEADER", action=wezterm.action.TogglePaneZoomState},
    {key='{', mods='LEADER|SHIFT', action=wezterm.action.MoveTabRelative(-1)},
    {key='}', mods='LEADER|SHIFT', action=wezterm.action.MoveTabRelative(1)},
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
    -- CTRL-SHIFT-l activates the debug overlay
    {key='l', mods='CTRL|SHIFT', action=wezterm.action.ShowDebugOverlay},
}

config.mouse_bindings = {
    {
        event = {Down={streak=1, button="Right"}},
        mods = '',
        action = wezterm.action.PasteFrom("Clipboard"),
    }
}

return config
