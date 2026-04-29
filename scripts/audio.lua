local Audio = {}

local sounds      = {}
local musicFade   = 1.0
local fadingOut   = false
local musicVolume = 1.0  -- mis à jour depuis Settings

function Audio.init(settings)
    musicVolume = settings.volume

    -- TODO: charger la musique de fond (fichier .ogg recommandé pour les boucles sans coupure)
    -- sounds.music = love.audio.newSource("assets/music/bgm.ogg", "stream")
    -- sounds.music:setLooping(true)

    -- TODO: charger les effets sonores courts (format .wav recommandé)
    -- sounds.click  = love.audio.newSource("assets/sfx/click.wav",  "static")
    -- sounds.select = love.audio.newSource("assets/sfx/select.wav", "static")
    -- sounds.jump   = love.audio.newSource("assets/sfx/jump.wav",   "static")
    -- sounds.splash = love.audio.newSource("assets/sfx/splash_jingle.wav", "static")
end

function Audio.playMusic()
    if sounds.music and not sounds.music:isPlaying() then
        sounds.music:setVolume(musicVolume)
        sounds.music:play()
    end
end

function Audio.stopMusic()
    if sounds.music then sounds.music:stop() end
end

-- Clone pour permettre plusieurs instances simultanées du même son
function Audio.playSfx(name)
    if sounds[name] then
        local s = sounds[name]:clone()
        s:play()
    end
end

function Audio.setMusicVolume(v)
    musicVolume = v
    if sounds.music then sounds.music:setVolume(musicVolume) end
end

function Audio.fadeOutMusic()
    fadingOut = true
end

function Audio.update(dt)
    if fadingOut then
        musicFade = math.max(0, musicFade - dt / 2)
        if sounds.music then
            sounds.music:setVolume(musicFade * musicVolume)
        end
        if musicFade <= 0 then
            fadingOut   = false
            musicFade   = 1.0
            Audio.stopMusic()
        end
    end
end

return Audio
