local Settings = {}

-- Valeurs par défaut
Settings.volume     = 0.8
Settings.sfxVolume  = 0.7
Settings.fullscreen = false

function Settings.save()
    local data = ""
    data = data .. "volume="     .. tostring(Settings.volume)     .. "\n"
    data = data .. "sfxVolume="  .. tostring(Settings.sfxVolume)  .. "\n"
    data = data .. "fullscreen=" .. tostring(Settings.fullscreen) .. "\n"

    local ok, err = love.filesystem.write("settings.txt", data)
    if not ok then
        print("[Settings] Échec de la sauvegarde : " .. err)
    end
end

function Settings.load()
    if not love.filesystem.getInfo("settings.txt") then
        return  -- pas encore de fichier, on garde les défauts
    end

    for line in love.filesystem.lines("settings.txt") do
        local key, value = line:match("([^=]+)=([^=]+)")
        if key and value then
            if key == "volume" then
                Settings.volume = tonumber(value) or Settings.volume
            elseif key == "sfxVolume" then
                Settings.sfxVolume = tonumber(value) or Settings.sfxVolume
            elseif key == "fullscreen" then
                Settings.fullscreen = (value == "true")
            end
        end
    end
end

return Settings
