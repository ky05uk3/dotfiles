local wezterm = require("wezterm")
local config = {}

-- Roots scanned recursively for git repositories (leader + Ctrl-w).
-- Every directory containing .git becomes a selectable project.
local PROJECT_ROOTS = {
	wezterm.home_dir .. "/dev",
}
-- Standalone project directories (added as-is, no .git required).
-- Machine-specific entries belong in projects.local.lua, not here.
local PROJECT_DIRS = {
	wezterm.home_dir .. "/dotfiles",
}
-- Max depth of the .git entry relative to a root (root/a/b/repo/.git is 4).
local SCAN_MAX_DEPTH = 5
-- Path components that exclude a repo from the launcher (hidden dirs too).
local SKIP_DIRS = { node_modules = true, trash = true, tmp = true }

-- Find git repositories under `root`. Descent stops at the first directory
-- that has .git, so repos nested inside another repo are dropped.
-- Returns a sorted list of absolute repo paths.
local function find_repos(root)
	local success, stdout = wezterm.run_child_process({
		"find", root, "-maxdepth", tostring(SCAN_MAX_DEPTH),
		"-name", "node_modules", "-prune", "-o",
		"-name", ".git", "-print",
	})
	if not success then
		return {}
	end

	local repos = {}
	for line in stdout:gmatch("[^\n]+") do
		local repo = line:gsub("/%.git$", "")
		local rel = repo:sub(#root + 2)
		local skip = rel == ""
		for part in rel:gmatch("[^/]+") do
			if part:sub(1, 1) == "." or SKIP_DIRS[part] then
				skip = true
				break
			end
		end
		if not skip then
			table.insert(repos, repo)
		end
	end

	-- A parent path always sorts before its children, so one pass is enough
	-- to drop repos nested under an already-kept repo.
	table.sort(repos)
	local result = {}
	for _, repo in ipairs(repos) do
		local nested = false
		for _, kept in ipairs(result) do
			if repo:sub(1, #kept + 1) == kept .. "/" then
				nested = true
				break
			end
		end
		if not nested then
			table.insert(result, repo)
		end
	end
	return result
end

-- Machine-specific extra project dirs, kept out of the shared dotfiles.
-- Optional git-ignored file <config_dir>/projects.local.lua that returns a
-- list of paths; a leading "~" expands to the home directory. It is read on
-- every launcher open, so edits apply without reloading the config.
local function load_local_project_dirs()
	local path = wezterm.config_dir .. "/projects.local.lua"
	local fh = io.open(path, "r")
	if not fh then
		return {}
	end
	fh:close()

	local dirs = {}
	for _, dir in ipairs(dofile(path) or {}) do
		dir = dir:gsub("^~", wezterm.home_dir):gsub("/+$", "")
		table.insert(dirs, dir)
	end
	return dirs
end

-- Build the choice list for the workspace launcher: currently open
-- workspaces first, then discovered project directories.
local function build_workspace_choices()
	local choices = {}
	local seen = {}

	-- Section: open workspaces
	local active = wezterm.mux.get_active_workspace()
	for _, name in ipairs(wezterm.mux.get_workspace_names()) do
		seen[name] = true
		local marker = (name == active) and "" or ""
		table.insert(choices, {
			id = name,
			label = wezterm.format({
				{ Foreground = { AnsiColor = "Green" } },
				{ Text = "  " .. marker .. "  " },
				{ Foreground = { AnsiColor = "White" } },
				{ Text = name },
			}),
		})
	end

	-- Section: project directories (deduplicated by path)
	local projects = {}
	local listed = {}
	local function add_project(dir)
		if not listed[dir] then
			listed[dir] = true
			table.insert(projects, dir)
		end
	end
	for _, root in ipairs(PROJECT_ROOTS) do
		for _, dir in ipairs(find_repos(root)) do
			add_project(dir)
		end
	end
	for _, dir in ipairs(PROJECT_DIRS) do
		add_project(dir)
	end
	for _, dir in ipairs(load_local_project_dirs()) do
		add_project(dir)
	end

	for _, dir in ipairs(projects) do
		local name = dir:match("([^/]+)$") or dir
		if not seen[name] then
			local rel = dir:gsub("^" .. wezterm.home_dir, "~")
			table.insert(choices, {
				id = dir,
				label = wezterm.format({
					{ Foreground = { AnsiColor = "Blue" } },
					{ Text = "    " },
					{ Foreground = { AnsiColor = "White" } },
					{ Text = name },
					{ Foreground = { AnsiColor = "Grey" } },
					{ Text = "  " .. rel },
				}),
			})
		end
	end

	return choices
end

-- Switch to (or create) a workspace from a launcher selection.
-- `id` is either an existing workspace name or an absolute project path.
local function switch_to_selection(win, pane, id)
	if not id then
		return
	end
	if id:sub(1, 1) == "/" then
		-- Project path: workspace name is the basename, cwd is the path.
		local name = id:match("([^/]+)$") or id
		win:perform_action(
			wezterm.action.SwitchToWorkspace({ name = name, spawn = { cwd = id } }),
			pane
		)
	else
		win:perform_action(wezterm.action.SwitchToWorkspace({ name = id }), pane)
	end
end

config.adjust_window_size_when_changing_font_size = false
config.check_for_updates = false
config.front_end = "WebGpu"
config.audible_bell = "Disabled"
config.scrollback_lines = 10000
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
}
config.mouse_wheel_scrolls_tabs = false
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
		key = "w",
		mods = "LEADER|CTRL",
		action = wezterm.action_callback(function(win, pane)
			win:perform_action(
				wezterm.action.InputSelector({
					action = wezterm.action_callback(function(_, _, id, label)
						if not id and not label then
							wezterm.log_info("Workspace selection canceled")
						else
							switch_to_selection(win, pane, id)
						end
					end),
					title = "  Workspaces & Projects",
					choices = build_workspace_choices(),
					fuzzy = true,
					fuzzy_description = wezterm.format({
						{ Foreground = { AnsiColor = "Fuchsia" } },
						{ Text = "  Fuzzy find workspace/project: " },
					}),
				}),
				pane
			)
		end),
	},
	-- without leader key
	-- Shift+Enter: send ESC+CR so AI agent CLIs (Claude Code, Codex, Kiro CLI)
	-- insert a newline instead of submitting the prompt.
	{ key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\x1b\r") },
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
	"JetBrainsMono Nerd Font Mono",
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
config.window_background_opacity = 0.95
config.macos_window_background_blur = 20

return config
