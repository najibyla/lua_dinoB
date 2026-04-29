function love.conf(t)
    -- Window
    t.window.title   = "My Awesome Game"
    -- TODO: ajouter assets/icon.png (32x32 ou 64x64 pixels, format PNG) puis décommenter la ligne suivante
    -- t.window.icon = "assets/icon.png"
    t.window.width   = 1280
    t.window.height  = 800
    t.window.resizable = true
    t.window.minwidth  = 640
    t.window.minheight = 360
    t.window.vsync   = 1
    t.window.msaa    = 2
    t.window.highdpi = true

    -- Identité (dossier de sauvegarde dans %AppData%)
    t.identity = "my_awesome_game_2026"
    t.version  = "11.5"
    t.console  = true   -- mettre false en release

    -- Modules inutilisés désactivés pour accélérer le boot
    t.modules.joystick = true
    t.modules.physics  = false
    t.modules.touch    = false
end
