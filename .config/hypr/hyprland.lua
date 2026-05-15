hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
    vrr      = 1,
})

---------------------
------- INPUT -------
---------------------

hl.config({
    input = {
        kb_layout  = "dk",
        follow_mouse = 1,
        sensitivity = 0, 
		force_no_accel = true,
		accel_profile = flat,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "alacritty"
local fileManager = "nemo"
local menu        = "$HOME/.config/rofi/drun_launcher.sh"

-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function () 
	hl.exec_cmd(terminal)
	hl.exec_cmd("bash -c '$HOME/.config/hypr/layout.sh'")
	hl.exec_cmd("bash -c '$HOME/.dotfiles/login.sh'")
	hl.exec_cmd("gsettings set org.cinnamon.desktop.default-applications.terminal exec '" 
	    .. terminal ..
	    "'"
	)
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_THEME", "Sunity-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 0,
        
        border_size = 2,

        col = {
            active_border   = { colors = {"rgba(8fbbbaee)", "rgba(8fbbbaee)"}, angle = 0 },
            inactive_border = "rgba(2d333faa)",
        },

        resize_on_border = false,
        allow_tearing = false,
        layout = "master",
    },
    
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled         = true,
            ignore_opacity  = true,
            size            = 10,
            passes          = 3,
            noise           = 0,
            contrast 	    = 1.2,
            brightness 		= 0.5,
            vibrancy  		= 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })
hl.animation({ leaf = "workspacesIn",  enabled = false,  speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = false,  speed = 1.94, bezier = "almostLinear", style = "fade" })

---------------------
----- WM LAYOUT -----
---------------------
hl.config({
    dwindle = {
        preserve_split = true,
    },
    
    master = {
    	orientation = "center",
    	slave_count_for_center_master = 0,
    	always_keep_position = true,
    	mfact = 0.5,
    },

    scrolling = {
    	fullscreen_on_one_column = true,
    },
})

---------------------
---- CONFIG MISC ----
---------------------
hl.config({
    misc = {
         force_default_wallpaper = 0,
         disable_hyprland_logo   = true, 
    },

    ecosystem = {
    	no_update_news = true,
    	no_donation_nag = true,
    },
})
---------------------
---- KEYBINDINGS ----
---------------------
local mainMod = "SUPER" -- Sets "Windows" key as main modifier
-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more

-- Application shortcuts
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprpicker -a -q"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("alacritty -e btop"))
hl.bind("Print", hl.dsp.exec_cmd("slurp | grim -g - - | swappy -f -"))

-- Window management
hl.bind(mainMod .. " + D", hl.dsp.window.close())
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exit())
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.center())
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/split_floating.sh"))

-- Focus movement
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Window movement
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Switch workspaces with mainMod + [1-9, 0]
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
end
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special())

-- Move active window to workspace silently with mainMod + SHIFT + [1-9, 0]
for i = 1, 9 do
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "special", follow = false }))

-- Microphone control
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("$HOME/.dotfiles/scripts/mute_mic.sh"))
hl.bind("ALT + mouse:276", hl.dsp.exec_cmd("$HOME/.dotfiles/scripts/mute_mic.sh"))

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys (volume)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })

-- Media keys (brightness)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media keys (playback)
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Push to mute on Discord
local shortcut = { mods = "", key = "INSERT", window = "class:discord" }
hl.bind("mouse:276", hl.dsp.send_shortcut(shortcut), { release = false } )
hl.bind("mouse:276", hl.dsp.send_shortcut(shortcut), { release = true } )
hl.bind("SHIFT + mouse:276", hl.dsp.send_shortcut(shortcut), { release = false } )
hl.bind("SHIFT + mouse:276", hl.dsp.send_shortcut(shortcut), { release = true } )

---------------------------------------
---- WINDOWS & LAYERS & WORKSPACES ----
---------------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

-- Float dialogs
hl.window_rule({
    name  = "float-zenity",
    match = { class = "zenity" },
    float = true,
})

hl.window_rule({
    name  = "float-yad",
    match = { class = "yad" },
    float = true,
})

-- Disable animations for waybar
hl.window_rule({
    name  = "waybar-no-anim",
    match = { class = "waybar" },
    no_anim = true,
})

-- Workspace assignments with silent launch
hl.window_rule({
    name  = "thunderbird-workspace",
    match = { initial_title = "Mozilla Thunderbird" },
    workspace = "2 silent",
})

hl.window_rule({
    name  = "steam-workspace",
    match = { initial_title = "Steam" },
    workspace = "2 silent",
})

hl.window_rule({
    name  = "discord-workspace",
    match = { class = "discord" },
    workspace = "2 silent",
})

-- Ignore maximize requests from all apps
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Layer rules for rofi
hl.layer_rule({
    match = { namespace = "rofi" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0,
})
