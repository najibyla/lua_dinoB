local Controls = {}

-- Touches par défaut (modifiables par le joueur)
Controls.bindings = {
    up     = "w",
    down   = "s",
    left   = "a",
    right  = "d",
    jump   = "space",
    attack = "lctrl",
}

-- Correspondance manette Xbox / standard
local gamepadMap = {
    jump   = "a",
    attack = "x",
    up     = "dpup",
    down   = "dpdown",
    left   = "dpleft",
    right  = "dpright",
}

-- Valeurs par défaut (pour le reset)
local DEFAULTS = {
    up     = "w",
    down   = "s",
    left   = "a",
    right  = "d",
    jump   = "space",
    attack = "lctrl",
}

local isRemapping    = false
local actionToRemap  = nil
local onRemapDone    = nil

-- Vérifie clavier ET manette pour une action donnée
function Controls.isDown(action)
    local key = Controls.bindings[action]
    if key and love.keyboard.isDown(key) then return true end

    local joysticks = love.joystick.getJoysticks()
    if joysticks[1] and gamepadMap[action] then
        if joysticks[1]:isGamepadDown(gamepadMap[action]) then
            return true
        end
    end

    return false
end

-- Lance l'écoute d'une nouvelle touche pour "action"
-- callback() sera appelé une fois le remapping terminé
function Controls.startRemap(action, callback)
    isRemapping   = true
    actionToRemap = action
    onRemapDone   = callback
end

-- Appeler depuis love.keypressed quand on est dans l'état "playing"
-- Retourne true si la touche a été consommée par le remapping
function Controls.keypressed(key)
    if isRemapping then
        Controls.bindings[actionToRemap] = key
        isRemapping  = false
        if onRemapDone then onRemapDone() end
        actionToRemap = nil
        onRemapDone   = nil
        return true
    end
    return false
end

function Controls.isWaitingForKey()
    return isRemapping
end

function Controls.getRemapTarget()
    return actionToRemap
end

function Controls.cancelRemap()
    isRemapping   = false
    actionToRemap = nil
    onRemapDone   = nil
end

function Controls.resetToDefaults()
    for action, key in pairs(DEFAULTS) do
        Controls.bindings[action] = key
    end
end

function Controls.save()
    local ok, err = love.filesystem.write("controls.txt", Controls.serialize())
    if not ok then print("[Controls] Échec sauvegarde : " .. err) end
end

function Controls.load()
    if not love.filesystem.getInfo("controls.txt") then return end
    for line in love.filesystem.lines("controls.txt") do
        local key, value = line:match("([^=]+)=([^=]+)")
        if key and value then Controls.deserialize(key, value) end
    end
end

-- Sauvegarde les bindings dans les settings (à appeler depuis Settings.save)
function Controls.serialize()
    local out = ""
    for action, key in pairs(Controls.bindings) do
        out = out .. "ctrl_" .. action .. "=" .. key .. "\n"
    end
    return out
end

function Controls.deserialize(key, value)
    local action = key:match("^ctrl_(.+)$")
    if action then
        Controls.bindings[action] = value
    end
end

return Controls
