-- =========================================================
-- WezTerm — Modern Green Minimal Config (2026)
-- Optimized for:
-- - macOS Apple Silicon
-- - Neovim + tmux workflow
-- - Smooth GPU rendering
-- - Dark green aesthetic
-- - Image support inside Neovim
-- - Safe window management
-- =========================================================

local wezterm = require("wezterm")

local config = wezterm.config_builder()

-- =========================================================
-- PERFORMANCE
-- =========================================================

config.front_end = "WebGpu"

config.max_fps = 120
config.animation_fps = 60

config.scrollback_lines = 50000

-- Disable cursor blinking for lower latency feel
config.cursor_blink_rate = 0

-- =========================================================
-- FONT
-- =========================================================

config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font",
	"Symbols Nerd Font Mono",
})

config.font_size = 15.5
config.line_height = 1.0

config.freetype_load_target = "Light"
config.freetype_render_target = "HorizontalLcd"

-- =========================================================
-- THEME
-- =========================================================

-- Beautiful dark green base
config.colors = {
	background = "#0b1411",

	foreground = "#d8e2dc",

	cursor_bg = "#78c2ad",
	cursor_border = "#78c2ad",

	selection_bg = "#244b3d",
	selection_fg = "#ffffff",

	split = "#1d3b31",

	ansi = {
		"#0b1411",
		"#c94f6d",
		"#7bd88f",
		"#f2c14e",
		"#5fb3b3",
		"#c792ea",
		"#5fb3b3",
		"#d8dee9",
	},

	brights = {
		"#465964",
		"#ef6f8f",
		"#8cf7a3",
		"#f4d35e",
		"#6cb6ff",
		"#d4a5ff",
		"#7fdbca",
		"#ffffff",
	},
}

-- Slight transparency
config.window_background_opacity = 0.94

-- Smooth macOS blur
config.macos_window_background_blur = 12

config.window_padding = {
	left = 8,
	right = 8,
	top = 8,
	bottom = 6,
}

-- Dim inactive panes slightly
config.inactive_pane_hsb = {
	saturation = 0.85,
	brightness = 0.60,
}

-- =========================================================
-- WINDOW
-- =========================================================

config.initial_cols = 180
config.initial_rows = 46

config.window_decorations = "RESIZE"

config.enable_tab_bar = false
config.use_fancy_tab_bar = false

config.hide_mouse_cursor_when_typing = true

-- IMPORTANT:
-- prevent accidental close
config.window_close_confirmation = "AlwaysPrompt"

config.native_macos_fullscreen_mode = true

config.automatically_reload_config = true

-- Open maximized automatically
wezterm.on("gui-startup", function(cmd)
	local _, _, window = wezterm.mux.spawn_window(cmd or {})

	window:gui_window():maximize()
end)

-- =========================================================
-- IMAGE SUPPORT
-- =========================================================

config.enable_kitty_graphics = true

config.unicode_version = 15

-- =========================================================
-- CURSOR
-- =========================================================

config.default_cursor_style = "BlinkingBar"

config.cursor_thickness = "2px"

-- =========================================================
-- STARTUP
-- =========================================================

config.default_prog = {
	"/bin/zsh",
	"-l",
	"-c",
	"tmux new-session -A -s main",
}

-- =========================================================
-- KEYBINDINGS
-- Minimal to avoid tmux/neovim conflicts
-- =========================================================

config.disable_default_key_bindings = true

config.keys = {
	-- =====================================================
	-- Clipboard
	-- =====================================================

	{
		key = "c",
		mods = "CMD",
		action = wezterm.action.CopyTo("Clipboard"),
	},

	{
		key = "v",
		mods = "CMD",
		action = wezterm.action.PasteFrom("Clipboard"),
	},

	-- =====================================================
	-- Font Size
	-- =====================================================

	{
		key = "=",
		mods = "CMD",
		action = wezterm.action.IncreaseFontSize,
	},

	{
		key = "-",
		mods = "CMD",
		action = wezterm.action.DecreaseFontSize,
	},

	{
		key = "0",
		mods = "CMD",
		action = wezterm.action.ResetFontSize,
	},

	-- =====================================================
	-- Window Management
	-- =====================================================

	{
		key = "n",
		mods = "CMD|SHIFT",
		action = wezterm.action.SpawnWindow,
	},

	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentTab({
			confirm = true,
		}),
	},

	{
		key = "q",
		mods = "CMD",
		action = wezterm.action.QuitApplication,
	},

	-- =====================================================
	-- Reload Config
	-- =====================================================

	{
		key = "r",
		mods = "CMD|SHIFT",
		action = wezterm.action.ReloadConfiguration,
	},
}

-- =========================================================
-- WINDOW TITLE
-- =========================================================

wezterm.on("format-window-title", function(_, pane)
	local process = pane:get_foreground_process_name()

	if process then
		process = process:gsub("^.*/", "")

		if process == "nvim" then
			return "Neovim"
		end

		if process == "tmux" then
			return "tmux"
		end

		if process == "ssh" then
			return "SSH Session"
		end

		return process
	end

	return "WezTerm"
end)

-- =========================================================
-- FINAL
-- =========================================================

return config
