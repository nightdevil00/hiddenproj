-- ╭──────────────────────────────────────────────────────────────────────────╮
-- │                                                                          │
-- │   U N I V E R S A L   C L I P B O A R D                                  │
-- │   copy, cut, paste and select all, from the same keys everywhere         │
-- │                                                                          │
-- │   github.com/andreumassanet/impasto                                      │
-- │                                                                          │
-- ╰──────────────────────────────────────────────────────────────────────────╯

-- Sends the application's own shortcut to the focused window, so one set of
-- keys copies and pastes in every program: a browser, an editor, a terminal
-- and a toolkit that binds nothing globally all answer to the same press.
--
-- A terminal is the exception. CTRL + C there is SIGINT — it interrupts the
-- running command, not a copy — so a terminal gets CTRL + SHIFT + C and
-- CTRL + SHIFT + V instead. `window.class` is the compositor's name for the
-- program, matched against the patterns below.

local M = {}

-- The compositor's classes, as `hyprctl clients` reports them. kitty is
-- impasto's own terminal (modules/programs.lua); the rest are the common
-- emulators, so a machine that opens one of those is still covered.
M.terminal_classes = {
    "^kitty$",
    "^Alacritty$",
    "^com%.mitchellh%.ghostty$",
    "^foot$",
    "^org%.codeberg%.dnkl%.foot$",
    "^wezterm$",
}

local function is_terminal(class)
    for _, pattern in ipairs(M.terminal_classes) do
        if class and class:match(pattern) then
            return true
        end
    end
    return false
end

-- A press and its release, 50 ms apart. The release is sent on a timer
-- because `send_key_state` is one half of a press; sending only the down
-- leaves the modifier held in the application.
local function send_shortcut(mods, key)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))

        hl.timer(function()
            hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
        end, { timeout = 50, type = "oneshot" })
    end
end

-- The shortcut that differs between an application and a terminal.
local function universal(default_mods, default_key, terminal_mods, terminal_key)
    local default  = send_shortcut(default_mods, default_key)
    local terminal = send_shortcut(terminal_mods, terminal_key)
    return function()
        local window = hl.get_active_window()
        if window and is_terminal(window.class) then
            terminal()
        else
            default()
        end
    end
end

-- The compositor takes the key before the window does, so the modifier
-- reaches the application only if it is sent again from here. SUPER + C is
-- held by Hyprland, which is why these are binds at all.
M.select_all = send_shortcut("CTRL", "A")
M.cut        = send_shortcut("CTRL", "X")
M.copy       = universal("CTRL", "C", "CTRL SHIFT", "C")
M.paste      = universal("CTRL", "V", "CTRL SHIFT", "V")

return M
