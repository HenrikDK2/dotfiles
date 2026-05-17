--------------------------------------------------------------------------------
-- MONITOR & INPUT
--------------------------------------------------------------------------------

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
    vrr = 1,
})

hl.config({
    input = {
        kb_layout = "dk",
        follow_mouse = 1,
        sensitivity = 0,
        force_no_accel = true,
        accel_profile = flat,
        touchpad = { natural_scroll = false },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace"
})

--------------------------------------------------------------------------------
-- PROGRAMS & AUTOSTART
--------------------------------------------------------------------------------

local terminal = "alacritty"
local fileManager = "nemo"
local menu = "$HOME/.config/rofi/drun_launcher.sh"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
    hl.exec_cmd("bash -c '$HOME/.config/hypr/layout.sh'")
    hl.exec_cmd("bash -c '$HOME/.dotfiles/login.sh'")
    hl.exec_cmd("gsettings set org.cinnamon.desktop.default-applications.terminal exec '" .. terminal .. "'")
end)

-- Environment variables
hl.env("XCURSOR_THEME", "Sunity-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

--------------------------------------------------------------------------------
-- APPEARANCE
--------------------------------------------------------------------------------

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 0,
        
        border_size = 2,

        col = {
            active_border = { colors = {"rgba(8fbbbaee)", "rgba(8fbbbaee)"}, angle = 0 },
            inactive_border = "rgba(2d333faa)",
        },

        resize_on_border = false,
        allow_tearing = false,
        layout = "master",
    },
    
    decoration = {
        rounding = 10,
        rounding_power = 2,

        active_opacity = 1.0,
        inactive_opacity = 1.0,
        
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        
        blur = {
            enabled = true,
            ignore_opacity = true,
            size = 10,
            passes = 3,
            noise = 0,
            contrast = 1.2,
            brightness = 0.5,
            vibrancy = 0.1696,
        },
    },
    
    animations = { enabled = true },
})

--------------------------------------------------------------------------------
-- ANIMATION CURVES
--------------------------------------------------------------------------------

hl.curve("easeOutQuint", { type = "bezier", points = {{0.23, 1}, {0.32, 1}} })
hl.curve("easeInOutCubic", { type = "bezier", points = {{0.65, 0.05}, {0.36, 1}} })
hl.curve("linear", { type = "bezier", points = {{0, 0}, {1, 1}} })
hl.curve("almostLinear", { type = "bezier", points = {{0.5, 0.5}, {0.75, 1}} })
hl.curve("quick", { type = "bezier", points = {{0.15, 0}, {0.1, 1}} })
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

--------------------------------------------------------------------------------
-- ANIMATIONS
--------------------------------------------------------------------------------

local animations = {
    -- Global
    { leaf = "global", speed = 10, bezier = "default" },
    { leaf = "border", speed = 5.39, bezier = "easeOutQuint" },
    
    -- Windows
    { leaf = "windows", speed = 4.79, spring = "easy" },
    { leaf = "windowsIn", speed = 4.1, spring = "easy", style = "popin 87%" },
    { leaf = "windowsOut", speed = 1.49, bezier = "linear", style = "popin 87%" },
    
    -- Fading
    { leaf = "fade", speed = 3.03, bezier = "quick" },
    { leaf = "fadeIn", speed = 1.73, bezier = "almostLinear" },
    { leaf = "fadeOut", speed = 1.46, bezier = "almostLinear" },
    
    -- Layers
    { leaf = "layers", speed = 3.81, bezier = "easeOutQuint" },
    { leaf = "layersIn", speed = 4, bezier = "easeOutQuint", style = "fade" },
    { leaf = "layersOut", speed = 1.5, bezier = "linear", style = "fade" },
    { leaf = "fadeLayersIn", speed = 1.79, bezier = "almostLinear" },
    { leaf = "fadeLayersOut", speed = 1.39, bezier = "almostLinear" },
    
    -- Workspaces
    { leaf = "workspaces", speed = 1.94, bezier = "almostLinear", style = "fade" },
    { leaf = "workspacesIn", enabled = false, speed = 1.21, bezier = "almostLinear", style = "fade" },
    { leaf = "workspacesOut", enabled = false, speed = 1.94, bezier = "almostLinear", style = "fade" },
    { leaf = "zoomFactor", speed = 7, bezier = "quick" },
}

for _, anim in ipairs(animations) do
    anim.enabled = anim.enabled ~= false
    hl.animation(anim)
end

--------------------------------------------------------------------------------
-- LAYOUTS & MISC
--------------------------------------------------------------------------------

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
    
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
    },
    
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------

local mainMod = "SUPER"

-- Application shortcuts
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("hyprpicker -a -q"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("alacritty -e btop"))
hl.bind("Print", hl.dsp.exec_cmd("slurp | grim -g - - | swappy -f -"))

-- Window management
hl.bind(mainMod .. " + D", hl.dsp.window.close())
hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("pkexec ~/.dotfiles/scripts/soft_reboot.sh"))
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.center())
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/.config/hypr/split_floating.sh"))

-- Focus movement (arrow keys)
for _, dir in ipairs({"left", "right", "up", "down"}) do
    hl.bind(mainMod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end

-- Workspace switching (1-9)
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special())
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = "special", follow = false }))

-- Microphone control
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("$HOME/.dotfiles/scripts/mute_mic.sh"))

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys (volume & brightness)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media playback
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Discord push-to-mute
local discord_shortcut = { mods = "", key = "INSERT", window = "class:discord" }
hl.bind("mouse:276", hl.dsp.send_shortcut(discord_shortcut), { ignore_mods = true, non_consuming = true, release = false })
hl.bind("mouse:276", hl.dsp.send_shortcut(discord_shortcut), { ignore_mods = true, non_consuming = true, release = true })

--------------------------------------------------------------------------------
-- WINDOW & LAYER RULES
--------------------------------------------------------------------------------

local rules = {
    {"float-zenity", {class="zenity"}, {float=true}}, {"float-yad", {class="yad"}, {float=true}},
    {"waybar-no-anim", {class="waybar"}, {no_anim=true}},
    {"thunderbird-workspace", {initial_title="Mozilla Thunderbird"}, {workspace="2 silent"}},
    {"steam-workspace", {initial_title="Steam"}, {workspace="2 silent"}},
    {"discord-workspace", {class="discord"}, {workspace="2 silent"}},
    {"suppress-maximize-events", {class=".*"}, {suppress_event="maximize"}},
    {"fix-xwayland-drags", {class="^$", title="^$", xwayland=true, float=true, fullscreen=false, pin=false}, {no_focus=true}},
}
for _, r in ipairs(rules) do
    hl.window_rule({ name = r[1], match = r[2], [next(r[3])] = r[3][next(r[3])] })
end

-- Layer Rules
hl.layer_rule({ match = {namespace="rofi"}, blur = true, blur_popups = true, ignore_alpha = 0 })
