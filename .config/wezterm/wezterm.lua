local wezterm = require("wezterm")
local config = {}

local function prompt_workspace_name(window, pane)
	window:perform_action(
		wezterm.action.PromptInputLine({
			description = "(wezterm) Workspace name:",
			action = wezterm.action_callback(function(inner_window, inner_pane, line)
				if not line or line == "" then
					return
				end

				inner_window:perform_action(
					wezterm.action.SwitchToWorkspace({
						name = line,
					}),
					inner_pane
				)
			end),
		}),
		pane
	)
end

config.adjust_window_size_when_changing_font_size = false
config.check_for_updates = false
config.initial_cols = 155
config.initial_rows = 45
config.hyperlink_rules = {
	{
		regex = "\\b\\w+://[\\w.-]+:[0-9]{2,15}\\S*\\b",
		format = "$0",
	},
	{
		regex = "\\b\\w+://[\\w.-]+\\.[a-z]{2,15}\\S*\\b",
		format = "$0",
	},
	{
		regex = [[\b\w+@[\w-]+(\.[\w-]+)+\b]],
		format = "mailto:$0",
	},
	{
		regex = [[\bfile://\S*\b]],
		format = "$0",
	},
	{
		regex = [[\b\w+://(?:[\d]{1,3}\.){3}[\d]{1,3}\S*\b]],
		format = "$0",
	},
	{
		regex = [[\b[tT](\d+)\b]],
		format = "https://example.com/tasks/?t=$1",
	},
}
config.mouse_wheel_scrolls_tabs = false
config.warn_about_missing_glyphs = false
config.window_close_confirmation = "NeverPrompt"
config.color_scheme = "iceberg-dark"
config.use_fancy_tab_bar = false
config.colors = {
	split = "#3b4261",
	tab_bar = {
		background = "#161821",
		active_tab = {
			bg_color = "#3b4261",
			fg_color = "#c6c8d1",
		},
		inactive_tab = {
			bg_color = "#1e2132",
			fg_color = "#6b7089",
		},
		inactive_tab_hover = {
			bg_color = "#3b4261",
			fg_color = "#c6c8d1",
		},
	},
}

config.disable_default_key_bindings = true
config.leader = { key = "l", mods = "CTRL" }
config.keys = {
	-- with leader key
	{ key = "t", mods = "LEADER", action = wezterm.action({ SpawnTab = "CurrentPaneDomain" }) },
	{ key = "h", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Left" }) },
	{ key = "j", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Down" }) },
	{ key = "k", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Up" }) },
	{ key = "l", mods = "LEADER", action = wezterm.action({ ActivatePaneDirection = "Right" }) },
	{ key = "n", mods = "LEADER", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "m", mods = "LEADER", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "d", mods = "LEADER", action = wezterm.action({ CloseCurrentPane = { confirm = true } }) },
	{ key = "w", mods = "LEADER", action = wezterm.action({ CloseCurrentTab = { confirm = true } }) },
	{ key = "f", mods = "LEADER", action = wezterm.action.ToggleFullScreen },
	{ key = "q", mods = "LEADER", action = wezterm.action.QuitApplication },
	{ key = "p", mods = "LEADER", action = wezterm.action.ActivateCommandPalette },
	{ key = "=", mods = "LEADER", action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "LEADER", action = wezterm.action.DecreaseFontSize },
	{ key = "N", mods = "LEADER|SHIFT", action = wezterm.action.SpawnWindow },
	{
		key = "V",
		mods = "LEADER|SHIFT",
		action = wezterm.action({ SplitHorizontal = { domain = "CurrentPaneDomain" } }),
	},
	{ key = "H", mods = "LEADER|SHIFT", action = wezterm.action({ SplitVertical = { domain = "CurrentPaneDomain" } }) },
	{ key = "s", mods = "LEADER|CTRL", action = wezterm.action.QuickSelect },
	{ key = "c", mods = "LEADER|CTRL", action = wezterm.action.ActivateCopyMode },
	{ key = "v", mods = "LEADER|CTRL", action = wezterm.action.PasteFrom("Clipboard") },
	{
		key = "n",
		mods = "LEADER|CTRL",
		action = wezterm.action_callback(function(window, pane)
			prompt_workspace_name(window, pane)
		end),
	},
	{
		key = "w",
		mods = "LEADER|CTRL",
		action = wezterm.action_callback(function(win, pane)
			local workspaces = {}
			for i, name in ipairs(wezterm.mux.get_workspace_names()) do
				table.insert(workspaces, {
					id = name,
					label = string.format("%d. %s", i, name),
				})
			end
			win:perform_action(
				wezterm.action.InputSelector({
					action = wezterm.action_callback(function(_, _, id, label)
						if not id and not label then
							wezterm.log_info("Workspace selection canceled")
						else
							win:perform_action(wezterm.action.SwitchToWorkspace({ name = id }), pane)
						end
					end),
					title = "Select workspace",
					choices = workspaces,
					fuzzy = true,
				}),
				pane
			)
		end),
	},
	-- without leader key
	{ key = "n", mods = "ALT", action = wezterm.action.ActivateTabRelative(-1) },
	{ key = "m", mods = "ALT", action = wezterm.action.ActivateTabRelative(1) },
	{ key = "-", mods = "ALT", action = wezterm.action.DecreaseFontSize },
	{ key = "=", mods = "ALT", action = wezterm.action.IncreaseFontSize },
	{ key = "h", mods = "ALT", action = wezterm.action({ AdjustPaneSize = { "Left", 5 } }) },
	{ key = "j", mods = "ALT", action = wezterm.action({ AdjustPaneSize = { "Down", 5 } }) },
	{ key = "k", mods = "ALT", action = wezterm.action({ AdjustPaneSize = { "Up", 5 } }) },
	{ key = "l", mods = "ALT", action = wezterm.action({ AdjustPaneSize = { "Right", 5 } }) },
}

config.show_tabs_in_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.show_new_tab_button_in_tab_bar = false
config.show_tab_index_in_tab_bar = false
config.tab_max_width = 28

local function basename(path)
	return path:gsub("/+$", ""):match("([^/]+)$") or path
end

wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
	local cwd = tab.active_pane.current_working_dir
	local title = cwd and basename(tostring(cwd):gsub("^file://[^/]*", ""):gsub("%%20", " ")) or tab.active_pane.title
	title = wezterm.truncate_right(title, math.max(max_width - 4, 1))
	return "  " .. title .. "  "
end)

config.command_palette_rows = 24
config.enable_scroll_bar = false
config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	"Hiragino Sans",
})
config.font_size = 11.5
config.inactive_pane_hsb = {
	hue = 1.0,
	saturation = 0.9,
	brightness = 0.55,
}
config.integrated_title_button_alignment = "Right"
config.window_decorations = "RESIZE"
config.window_frame = {
	inactive_titlebar_bg = "none",
	active_titlebar_bg = "none",
	border_left_width = "1cell",
	border_right_width = "1cell",
	border_bottom_height = "0.75cell",
}
config.window_padding = {
	left = 23,
	right = 23,
	top = 23,
	bottom = 23,
}

return config
