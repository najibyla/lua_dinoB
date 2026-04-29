local Settings  = require("scripts/settings")
local Audio     = require("scripts/audio")
local Controls  = require("scripts/controls")
local HighScore = require("scripts/highscore")
local engine    = require("engine")
local config    = require("game_config")

-- ============================================================
-- Résolution virtuelle
-- ============================================================
local VIRTUAL_W, VIRTUAL_H = 1280, 800
local canvas

-- ============================================================
-- Layout zones de jeu (canvas 1280×800)
-- ============================================================
local LAYOUT_UPPER_Y = 220    -- y des zones territoire / jungle
local LAYOUT_UPPER_H = 155    -- hauteur des zones supérieures
local LAYOUT_DINO_Y  = 50     -- y des piles dinos (et trophées)
local LAYOUT_DINO_H  = 145    -- hauteur des piles dinos
local LAYOUT_SEP_X   = 530    -- séparateur visuel L1 / L2
local LAYOUT_RES_Y   = 382    -- y ligne ressources
local LAYOUT_MSG_Y   = 424    -- y ligne message tour
local LAYOUT_TAB_Y   = 472    -- y zone Tableau (ventilé sous le message)
local LAYOUT_TAB_H   = 132    -- hauteur zone Tableau
local LAYOUT_HAND_Y  = LAYOUT_TAB_Y + LAYOUT_TAB_H + 18  -- y main / deck / défausse
local LAYOUT_HAND_H  = 140    -- hauteur zones du bas
local LAYOUT_SIDE_X  = 1020   -- x colonne droite (trophées, ATK, EndTurn)
local LAYOUT_ATK_Y   = LAYOUT_TAB_Y + 4   -- y panel ATK
local LAYOUT_BTN_Y   = LAYOUT_HAND_Y + 22 -- y bouton Fin de Tour
local LAYOUT_BTN_W   = 130
local LAYOUT_BTN_H   = 50

-- ============================================================
-- Machine à états
-- ============================================================
local STATE = {
    splash     = "splash",
    menu       = "menu",
    settings   = "settings",
    controls   = "controls",
    setup      = "setup",
    playing    = "playing",
    name_entry = "name_entry",
    highscores = "highscores",
}

-- ============================================================
-- Écran Setup (sélection difficulté + clan)
-- ============================================================
-- section : 1=difficulté  2=clan  3=lancer
local setupChoice = { difficulty = 1, clan = "sun", section = 1 }
local currentState = STATE.splash

-- ============================================================
-- Splash screen
-- ============================================================
local SPLASH_DURATION = 3
local splashTimer     = 0

-- ============================================================
-- Menu principal
-- ============================================================
local menuOptions    = { "Jouer", "Paramètres", "Quitter" }
local selectedOption = 1
local MENU_START_Y   = 280
local MENU_ROW_H     = 70

-- ============================================================
-- Écran Settings
-- ============================================================
local SETTING_ITEMS   = { "volume", "sfxVolume", "fullscreen", "controls", "back" }
local selectedSetting = 1
local SLIDERS = {
    { key = "volume",    rowIndex = 1, x = 520, y = 205, width = 400 },
    { key = "sfxVolume", rowIndex = 2, x = 520, y = 275, width = 400 },
}
local SETTING_ROWS = {
    [3] = { yMin = 325, yMax = 362 },
    [4] = { yMin = 385, yMax = 422 },
    [5] = { yMin = 445, yMax = 482 },
}

-- ============================================================
-- Écran Contrôles
-- ============================================================
local CONTROL_ACTIONS = {
    { action = "up",     label = "Haut" },
    { action = "down",   label = "Bas" },
    { action = "left",   label = "Gauche" },
    { action = "right",  label = "Droite" },
    { action = "jump",   label = "Saut" },
    { action = "attack", label = "Attaque" },
}
local CTRL_START_Y    = 140
local CTRL_ROW_H      = 55
local selectedControl = 1
local draggingSlider  = nil

-- ============================================================
-- Deck building — état global
-- ============================================================
local state = {}

-- Données pour l'écran name_entry (branché sur le score du jeu)
local nameChars    = { "A", "A", "A" }
local nameSlot     = 1
local newEntryRank = nil
local finalScore   = 0
local finalTurns   = 0

-- ============================================================
-- love.load
-- ============================================================
function love.load()
    Settings.load()
    Controls.load()
    HighScore.load()

    canvas = love.graphics.newCanvas(VIRTUAL_W, VIRTUAL_H)
    canvas:setFilter("nearest", "nearest")
    engine.initFonts(14, 14)

    Audio.init(Settings)
    love.audio.setVolume(Settings.volume)

    if Settings.fullscreen then
        love.window.setFullscreen(true, "desktop")
    end

    love.graphics.setBackgroundColor(0.05, 0.05, 0.05)
    math.randomseed(os.time())
end

-- ============================================================
-- love.update
-- ============================================================
function love.update(dt)
    Audio.update(dt)

    if currentState == STATE.splash then
        splashTimer = splashTimer + dt
        if splashTimer >= SPLASH_DURATION then
            currentState = STATE.menu
            Audio.playMusic()
        end
    elseif currentState == STATE.playing then
        updateGame(dt)
    end
end

-- ============================================================
-- love.draw
-- ============================================================
function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)

    if     currentState == STATE.splash     then drawSplash()
    elseif currentState == STATE.menu       then drawMenu()
    elseif currentState == STATE.settings   then drawSettings()
    elseif currentState == STATE.controls   then drawControls()
    elseif currentState == STATE.setup      then drawSetup()
    elseif currentState == STATE.playing    then drawGame()
    elseif currentState == STATE.name_entry then drawNameEntry()
    elseif currentState == STATE.highscores then drawHighScores()
    end

    love.graphics.setCanvas()

    local ww, wh = love.graphics.getDimensions()
    local scale  = math.min(ww / VIRTUAL_W, wh / VIRTUAL_H)
    local ox     = (ww - VIRTUAL_W * scale) / 2
    local oy     = (wh - VIRTUAL_H * scale) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

-- ============================================================
-- love.keypressed
-- ============================================================
function love.keypressed(key)
    if currentState == STATE.splash then
        if key == "return" or key == "space" or key == "escape" then
            splashTimer = SPLASH_DURATION
        end

    elseif currentState == STATE.menu then
        handleMenuInput(key)

    elseif currentState == STATE.setup then
        handleSetupInput(key)

    elseif currentState == STATE.settings then
        handleSettingsInput(key)

    elseif currentState == STATE.controls then
        handleControlsInput(key)

    elseif currentState == STATE.playing then
        if key == "escape" then
            currentState = STATE.menu
            return
        end
        if key == "r" then
            initGame()
        end

    elseif currentState == STATE.name_entry then
        handleNameEntryInput(key)

    elseif currentState == STATE.highscores then
        if key ~= nil then
            currentState = STATE.menu
        end
    end
end

function love.textinput(text)
    if currentState ~= STATE.name_entry then return end
    local upper = text:upper()
    if upper:match("[A-Z]") then
        nameChars[nameSlot] = upper
        if nameSlot < 3 then nameSlot = nameSlot + 1 end
    end
end

-- ============================================================
-- Settings — helpers souris (locaux, avant love.mousepressed)
-- ============================================================
local function applySliderValue(sliderKey, value)
    Settings[sliderKey] = math.max(0, math.min(1, value))
    if sliderKey == "volume" then
        love.audio.setVolume(Settings.volume)
        Audio.setMusicVolume(Settings.volume)
    end
end

local function sliderValueFromX(slider, vx)
    return (vx - slider.x) / slider.width
end

local function findSliderAt(vx, vy)
    for _, s in ipairs(SLIDERS) do
        if vx >= s.x - 220 and vx <= s.x + s.width and vy >= s.y - 14 and vy <= s.y + 24 then
            return s
        end
    end
    return nil
end

-- ============================================================
-- love.mousepressed (boilerplate + deck building fusionnés)
-- ============================================================
function love.mousepressed(mx, my, button)
    if button ~= 1 then return end
    local vx, vy = getVirtualMousePos()

    if currentState == STATE.menu then
        for i = 1, #menuOptions do
            local y = MENU_START_Y + i * MENU_ROW_H
            if vy >= y - 8 and vy <= y + MENU_ROW_H - 8 then
                selectedOption = i
                applyMenuSelection()
                return
            end
        end

    elseif currentState == STATE.setup then
        handleSetupClick(vx, vy)
        return

    elseif currentState == STATE.highscores then
        currentState = STATE.menu

    elseif currentState == STATE.settings then
        local slider = findSliderAt(vx, vy)
        if slider then
            draggingSlider  = slider.key
            selectedSetting = slider.rowIndex
            if vx >= slider.x and vx <= slider.x + slider.width then
                applySliderValue(slider.key, sliderValueFromX(slider, vx))
            end
            return
        end
        for index, zone in pairs(SETTING_ROWS) do
            if vy >= zone.yMin and vy <= zone.yMax then
                selectedSetting = index
                if index == 3 then
                    Settings.fullscreen = not Settings.fullscreen
                    love.window.setFullscreen(Settings.fullscreen, "desktop")
                elseif index == 4 then
                    currentState = STATE.controls
                elseif index == 5 then
                    Settings.save()
                    currentState = STATE.menu
                end
                return
            end
        end

    elseif currentState == STATE.controls then
        if Controls.isWaitingForKey() then return end
        local totalActions = #CONTROL_ACTIONS
        for i, entry in ipairs(CONTROL_ACTIONS) do
            local rowY = CTRL_START_Y + (i - 1) * CTRL_ROW_H
            if vy >= rowY - 8 and vy <= rowY + CTRL_ROW_H - 8 then
                selectedControl = i
                Controls.startRemap(entry.action)
                return
            end
        end
        local resetY = CTRL_START_Y + totalActions * CTRL_ROW_H + 20
        if vy >= resetY - 8 and vy <= resetY + 30 then
            selectedControl = totalActions + 1
            Controls.resetToDefaults()
            return
        end
        local backY = resetY + 60
        if vy >= backY - 8 and vy <= backY + 30 then
            selectedControl = totalActions + 2
            Controls.save()
            currentState = STATE.settings
        end

    elseif currentState == STATE.playing then
        if engine.pointInRect(vx, vy, LAYOUT_SIDE_X, LAYOUT_BTN_Y, LAYOUT_BTN_W, LAYOUT_BTN_H) then
            endTurn()
            return
        end
        for _, pile in ipairs(state.dino_piles) do
            local top = #pile.zone.cards > 0 and pile.zone.cards[#pile.zone.cards] or nil
            if top and engine.pointInRect(vx, vy, top.x, top.y, engine.CARD_W, engine.CARD_H) then
                attackCreature(top, pile)
                return
            end
        end
        for _, tzone in ipairs({ state.zones.territory_left, state.zones.territory_right }) do
            local market_card = engine.findCardInZone(tzone, vx, vy)
            if market_card then
                buyCard(market_card, tzone)
                return
            end
        end
        local card = engine.findCardInZone(state.zones.hand, vx, vy)
        if card then
            state.drag.card   = card
            state.drag.origin = state.zones.hand
            state.drag.ox     = vx - card.x
            state.drag.oy     = vy - card.y
            engine.removeCard(state.zones.hand, card)
            return
        end
    end
end

-- ============================================================
-- love.mousereleased (slider drag + lâcher de carte fusionnés)
-- ============================================================
function love.mousereleased(mx, my, button)
    if button ~= 1 then return end
    draggingSlider = nil

    if currentState == STATE.playing and state.drag.card then
        local vx, vy = getVirtualMousePos()
        local card    = state.drag.card
        local dropped = false
        local tz      = state.zones.tableau
        if engine.pointInRect(vx, vy, tz.x, tz.y, tz.w, tz.h) then
            engine.addCard(tz, card)
            playCard(card)
            dropped = true
        end
        if not dropped then
            engine.addCard(state.drag.origin, card)
        end
        state.drag.card   = nil
        state.drag.origin = nil
    end
end

-- ============================================================
-- love.mousemoved (hover menu + drag slider)
-- ============================================================
function love.mousemoved(mx, my)
    local vx, vy = getVirtualMousePos()

    if currentState == STATE.menu then
        for i = 1, #menuOptions do
            local y = MENU_START_Y + i * MENU_ROW_H
            if vy >= y - 8 and vy <= y + MENU_ROW_H - 8 then
                selectedOption = i
                return
            end
        end

    elseif currentState == STATE.settings then
        if draggingSlider then
            for _, s in ipairs(SLIDERS) do
                if s.key == draggingSlider then
                    applySliderValue(s.key, sliderValueFromX(s, vx))
                    break
                end
            end
            return
        end
        local slider = findSliderAt(vx, vy)
        if slider then
            selectedSetting = slider.rowIndex
            return
        end
        for index, zone in pairs(SETTING_ROWS) do
            if vy >= zone.yMin and vy <= zone.yMax then
                selectedSetting = index
                return
            end
        end

    elseif currentState == STATE.controls and not Controls.isWaitingForKey() then
        local totalActions = #CONTROL_ACTIONS
        for i = 1, totalActions do
            local rowY = CTRL_START_Y + (i - 1) * CTRL_ROW_H
            if vy >= rowY - 8 and vy <= rowY + CTRL_ROW_H - 8 then
                selectedControl = i
                return
            end
        end
        local resetY = CTRL_START_Y + totalActions * CTRL_ROW_H + 20
        if vy >= resetY - 8 and vy <= resetY + 30 then
            selectedControl = totalActions + 1
            return
        end
        local backY = resetY + 60
        if vy >= backY - 8 and vy <= backY + 30 then
            selectedControl = totalActions + 2
        end
    end
end

-- ============================================================
-- Splash screen
-- ============================================================
function drawSplash()
    love.graphics.clear(0.05, 0.05, 0.05, 1)
    local alpha
    if splashTimer < 1 then
        alpha = splashTimer
    elseif splashTimer > 2 then
        alpha = math.max(0, 3 - splashTimer)
    else
        alpha = 1
    end
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.printf("DINO HUNT", 0, VIRTUAL_H / 2 - 16, VIRTUAL_W, "center")
    love.graphics.setColor(0.5, 0.5, 0.5, alpha * 0.7)
    love.graphics.printf("Appuie sur Espace pour passer", 0, VIRTUAL_H - 50, VIRTUAL_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Menu principal
-- ============================================================
function drawMenu()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("DINO HUNT", 0, 100, VIRTUAL_W, "center")

    for i, option in ipairs(menuOptions) do
        local selected = (i == selectedOption)
        local y = MENU_START_Y + i * MENU_ROW_H
        if selected then
            love.graphics.setColor(1, 0.9, 0, 0.07)
            love.graphics.rectangle("fill", 320, y - 8, VIRTUAL_W - 640, 44, 8, 8)
        end
        love.graphics.setColor(selected and { 1, 0.9, 0, 1 } or { 0.85, 0.85, 0.85, 1 })
        local label = (selected and "> " or "  ") .. option .. (selected and " <" or "")
        love.graphics.printf(label, 0, y, VIRTUAL_W, "center")
    end

    love.graphics.setColor(0.45, 0.45, 0.45, 1)
    love.graphics.printf("HAUT/BAS : Naviguer   ENTRÉE : Sélectionner   Cliquer", 0, VIRTUAL_H - 40, VIRTUAL_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function handleMenuInput(key)
    if key == "up" then
        selectedOption = selectedOption > 1 and selectedOption - 1 or #menuOptions
        Audio.playSfx("click")
    elseif key == "down" then
        selectedOption = selectedOption < #menuOptions and selectedOption + 1 or 1
        Audio.playSfx("click")
    elseif key == "return" then
        applyMenuSelection()
    end
end

function applyMenuSelection()
    if selectedOption == 1 then
        setupChoice = { difficulty = 1, clan = "sun", section = 1 }
        currentState = STATE.setup
    elseif selectedOption == 2 then
        currentState = STATE.settings
    elseif selectedOption == 3 then
        Settings.save()
        love.event.quit()
    end
end

-- ============================================================
-- Écran Settings
-- ============================================================
function drawSettings()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("PARAMÈTRES", 0, 80, VIRTUAL_W, "center")
    drawSettingRow(1, "Volume musique", 200)
    drawVolumeSlider(520, 205, 400, Settings.volume, "volume")
    drawSettingRow(2, "Volume effets", 270)
    drawVolumeSlider(520, 275, 400, Settings.sfxVolume, "sfxVolume")
    drawSettingRow(3, "Plein écran : " .. (Settings.fullscreen and "ON" or "OFF"), 340)
    drawSettingRow(4, "Contrôles", 400)
    drawSettingRow(5, "Retour", 460)
    love.graphics.setColor(0.45, 0.45, 0.45, 1)
    love.graphics.printf("GAUCHE/DROITE : Ajuster   ENTRÉE : Confirmer   ÉCHAP : Retour   Cliquer-glisser les sliders", 0, VIRTUAL_H - 40, VIRTUAL_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function drawSettingRow(index, label, y)
    local selected = (index == selectedSetting)
    love.graphics.setColor(selected and { 1, 0.9, 0, 1 } or { 0.85, 0.85, 0.85, 1 })
    love.graphics.print((selected and "> " or "  ") .. label, 200, y)
end

function drawVolumeSlider(x, y, width, value, sliderKey)
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.rectangle("fill", x, y, width, 10)
    love.graphics.setColor(1, 0.85, 0, 1)
    love.graphics.rectangle("fill", x, y, width * value, 10)
    local knobR = (draggingSlider == sliderKey) and 12 or 8
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", x + width * value, y + 5, knobR)
end

function handleSettingsInput(key)
    if key == "up" then
        selectedSetting = selectedSetting > 1 and selectedSetting - 1 or #SETTING_ITEMS
    elseif key == "down" then
        selectedSetting = selectedSetting < #SETTING_ITEMS and selectedSetting + 1 or 1
    elseif key == "left" then
        if selectedSetting == 1 then
            Settings.volume = math.max(0, Settings.volume - 0.05)
            love.audio.setVolume(Settings.volume)
            Audio.setMusicVolume(Settings.volume)
        elseif selectedSetting == 2 then
            Settings.sfxVolume = math.max(0, Settings.sfxVolume - 0.05)
        end
    elseif key == "right" then
        if selectedSetting == 1 then
            Settings.volume = math.min(1, Settings.volume + 0.05)
            love.audio.setVolume(Settings.volume)
            Audio.setMusicVolume(Settings.volume)
        elseif selectedSetting == 2 then
            Settings.sfxVolume = math.min(1, Settings.sfxVolume + 0.05)
        end
    elseif key == "return" then
        if selectedSetting == 3 then
            Settings.fullscreen = not Settings.fullscreen
            love.window.setFullscreen(Settings.fullscreen, "desktop")
        elseif selectedSetting == 4 then
            currentState = STATE.controls
        elseif selectedSetting == 5 then
            Settings.save()
            currentState = STATE.menu
        end
    elseif key == "escape" then
        Settings.save()
        currentState = STATE.menu
    end
end

-- ============================================================
-- Écran Contrôles
-- ============================================================
function drawControls()
    local totalActions = #CONTROL_ACTIONS
    local waiting      = Controls.isWaitingForKey()
    local remapTarget  = Controls.getRemapTarget()

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("CONTRÔLES", 0, 60, VIRTUAL_W, "center")
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.print("ACTION", 220, CTRL_START_Y - 30)
    love.graphics.print("TOUCHE", 650, CTRL_START_Y - 30)
    love.graphics.setColor(0.25, 0.25, 0.25, 1)
    love.graphics.line(200, CTRL_START_Y - 12, 900, CTRL_START_Y - 12)

    for i, entry in ipairs(CONTROL_ACTIONS) do
        local y           = CTRL_START_Y + (i - 1) * CTRL_ROW_H
        local isSelected  = (selectedControl == i)
        local isRemapping = waiting and (remapTarget == entry.action)
        if isSelected then
            love.graphics.setColor(1, 0.9, 0, 0.08)
            love.graphics.rectangle("fill", 195, y - 10, 710, CTRL_ROW_H - 4)
        end
        local col = isRemapping and {1, 0.5, 0, 1} or (isSelected and {1, 0.9, 0, 1} or {0.85, 0.85, 0.85, 1})
        love.graphics.setColor(col)
        love.graphics.print((isSelected and "> " or "  ") .. entry.label, 220, y)
        local keyName = isRemapping and "???" or Controls.bindings[entry.action]
        local capW    = 120
        love.graphics.setColor(isRemapping and {0.5, 0.25, 0, 1} or (isSelected and {0.3, 0.28, 0, 1} or {0.2, 0.2, 0.2, 1}))
        love.graphics.rectangle("fill", 645, y - 4, capW, 26, 5, 5)
        love.graphics.setColor(col)
        love.graphics.printf(keyName, 645, y, capW, "center")
    end

    local sepY = CTRL_START_Y + totalActions * CTRL_ROW_H + 4
    love.graphics.setColor(0.25, 0.25, 0.25, 1)
    love.graphics.line(200, sepY, 900, sepY)

    local resetIdx = totalActions + 1
    local resetY   = sepY + 20
    local resetSel = (selectedControl == resetIdx)
    love.graphics.setColor(resetSel and {1, 0.5, 0.1, 1} or {0.7, 0.7, 0.7, 1})
    love.graphics.printf((resetSel and "> " or "  ") .. "Réinitialiser", 0, resetY, VIRTUAL_W, "center")

    local backIdx = totalActions + 2
    local backY   = resetY + 55
    local backSel = (selectedControl == backIdx)
    love.graphics.setColor(backSel and {1, 0.9, 0, 1} or {0.85, 0.85, 0.85, 1})
    love.graphics.printf((backSel and "> " or "  ") .. "Retour", 0, backY, VIRTUAL_W, "center")

    if waiting then
        love.graphics.setColor(1, 0.5, 0, 1)
        love.graphics.printf("Appuie sur une touche...   ÉCHAP = annuler", 0, VIRTUAL_H - 40, VIRTUAL_W, "center")
    else
        love.graphics.setColor(0.45, 0.45, 0.45, 1)
        love.graphics.printf("HAUT/BAS : Naviguer   ENTRÉE : Assigner   ÉCHAP : Retour   Cliquer pour assigner", 0, VIRTUAL_H - 40, VIRTUAL_W, "center")
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function handleControlsInput(key)
    local totalActions = #CONTROL_ACTIONS
    if Controls.isWaitingForKey() then
        if key == "escape" then
            Controls.cancelRemap()
        else
            Controls.keypressed(key)
        end
        return
    end
    local totalItems = totalActions + 2
    if key == "up" then
        selectedControl = selectedControl > 1 and selectedControl - 1 or totalItems
    elseif key == "down" then
        selectedControl = selectedControl < totalItems and selectedControl + 1 or 1
    elseif key == "return" then
        applyControlSelection()
    elseif key == "escape" then
        Controls.save()
        currentState = STATE.settings
    end
end

function applyControlSelection()
    local totalActions = #CONTROL_ACTIONS
    if selectedControl <= totalActions then
        Controls.startRemap(CONTROL_ACTIONS[selectedControl].action)
    elseif selectedControl == totalActions + 1 then
        Controls.resetToDefaults()
    elseif selectedControl == totalActions + 2 then
        Controls.save()
        currentState = STATE.settings
    end
end

-- ============================================================
-- Écran Setup — dessin
-- ============================================================
local SETUP_DIFF_Y   = 260
local SETUP_CLAN_Y   = 430
local SETUP_LAUNCH_Y = 570
local SETUP_BOX_W    = 240
local SETUP_BOX_H    = 80

local function setupDiffBoxes()
    local diffs = config.difficulties
    local totalW = #diffs * SETUP_BOX_W + (#diffs - 1) * 20
    local startX = (VIRTUAL_W - totalW) / 2
    local boxes = {}
    for i = 1, #diffs do
        boxes[i] = { x = startX + (i-1) * (SETUP_BOX_W + 20), y = SETUP_DIFF_Y,
                     w = SETUP_BOX_W, h = SETUP_BOX_H }
    end
    return boxes
end

local function setupClanBoxes()
    local cx = VIRTUAL_W / 2
    return {
        sun  = { x = cx - SETUP_BOX_W - 20, y = SETUP_CLAN_Y, w = SETUP_BOX_W, h = SETUP_BOX_H },
        moon = { x = cx + 20,               y = SETUP_CLAN_Y, w = SETUP_BOX_W, h = SETUP_BOX_H },
    }
end

function drawSetup()
    love.graphics.setColor(0.08, 0.08, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)

    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.printf("NOUVELLE PARTIE", 0, 80, VIRTUAL_W, "center")

    -- Section difficulté
    local secCol = function(n)
        return (setupChoice.section == n) and {1,0.9,0,1} or {0.6,0.6,0.6,1}
    end
    love.graphics.setColor(secCol(1))
    love.graphics.printf("DIFFICULTÉ", 0, SETUP_DIFF_Y - 36, VIRTUAL_W, "center")

    local dboxes = setupDiffBoxes()
    for i, box in ipairs(dboxes) do
        local diff    = config.difficulties[i]
        local sel     = (setupChoice.difficulty == i)
        love.graphics.setColor(sel and {0.25,0.45,0.85,1} or {0.12,0.12,0.18,1})
        love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 8, 8)
        love.graphics.setColor(sel and {1,0.85,0,1} or {0.4,0.4,0.5,1})
        love.graphics.setLineWidth(sel and 2 or 1)
        love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 8, 8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(sel and {1,1,1,1} or {0.7,0.7,0.7,1})
        love.graphics.printf(diff.name, box.x, box.y + 14, box.w, "center")
        love.graphics.setColor(sel and {1,0.85,0.2,1} or {0.5,0.5,0.5,1})
        love.graphics.printf(diff.jungle_size .. " cartes", box.x, box.y + 46, box.w, "center")
    end

    -- Section clan
    love.graphics.setColor(secCol(2))
    love.graphics.printf("CLAN", 0, SETUP_CLAN_Y - 36, VIRTUAL_W, "center")

    local clans = { { key="sun", icon="🌞", label="SOLEIL" }, { key="moon", icon="🌙", label="LUNE" } }
    local cboxes = setupClanBoxes()
    for _, clan in ipairs(clans) do
        local box = cboxes[clan.key]
        local sel = (setupChoice.clan == clan.key)
        love.graphics.setColor(sel and {0.25,0.45,0.85,1} or {0.12,0.12,0.18,1})
        love.graphics.rectangle("fill", box.x, box.y, box.w, box.h, 8, 8)
        love.graphics.setColor(sel and {1,0.85,0,1} or {0.4,0.4,0.5,1})
        love.graphics.setLineWidth(sel and 2 or 1)
        love.graphics.rectangle("line", box.x, box.y, box.w, box.h, 8, 8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(sel and {1,1,1,1} or {0.7,0.7,0.7,1})
        local cx = box.x + box.w / 2
        engine.useEmoji()
        love.graphics.printf(clan.icon, cx - 40, box.y + 26, 30, "center")
        engine.useDefault()
        love.graphics.printf(clan.label, cx - 10, box.y + 26, 80, "left")
    end

    -- Bouton Lancer
    local sel    = (setupChoice.section == 3)
    local lbx    = (VIRTUAL_W - 280) / 2
    love.graphics.setColor(sel and {0.2,0.65,0.3,1} or {0.12,0.25,0.15,1})
    love.graphics.rectangle("fill", lbx, SETUP_LAUNCH_Y, 280, 52, 10, 10)
    love.graphics.setColor(sel and {1,1,1,1} or {0.5,0.8,0.55,1})
    love.graphics.printf("LANCER LA PARTIE", lbx, SETUP_LAUNCH_Y + 16, 280, "center")

    -- Aide
    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.printf(
        "HAUT/BAS : naviguer   GAUCHE/DROITE : choisir   ENTRÉE : confirmer   ÉCHAP : retour",
        0, VIRTUAL_H - 36, VIRTUAL_W, "center")
    love.graphics.setColor(1,1,1,1)
end

function handleSetupInput(key)
    if key == "escape" then
        currentState = STATE.menu
        return
    end
    local ndiffs = #config.difficulties
    if key == "up" then
        setupChoice.section = setupChoice.section > 1 and setupChoice.section - 1 or 3
    elseif key == "down" then
        setupChoice.section = setupChoice.section < 3 and setupChoice.section + 1 or 1
    elseif key == "left" then
        if setupChoice.section == 1 then
            setupChoice.difficulty = setupChoice.difficulty > 1 and setupChoice.difficulty - 1 or ndiffs
        elseif setupChoice.section == 2 then
            setupChoice.clan = (setupChoice.clan == "sun") and "moon" or "sun"
        end
    elseif key == "right" then
        if setupChoice.section == 1 then
            setupChoice.difficulty = setupChoice.difficulty < ndiffs and setupChoice.difficulty + 1 or 1
        elseif setupChoice.section == 2 then
            setupChoice.clan = (setupChoice.clan == "sun") and "moon" or "sun"
        end
    elseif key == "return" then
        if setupChoice.section == 3 then
            launchGame()
        end
    end
end

function handleSetupClick(vx, vy)
    local dboxes = setupDiffBoxes()
    for i, box in ipairs(dboxes) do
        if engine.pointInRect(vx, vy, box.x, box.y, box.w, box.h) then
            setupChoice.difficulty = i
            setupChoice.section    = 1
            return
        end
    end
    local cboxes = setupClanBoxes()
    for _, clan in ipairs({ "sun", "moon" }) do
        local box = cboxes[clan]
        if engine.pointInRect(vx, vy, box.x, box.y, box.w, box.h) then
            setupChoice.clan    = clan
            setupChoice.section = 2
            return
        end
    end
    local lbx = (VIRTUAL_W - 280) / 2
    if engine.pointInRect(vx, vy, lbx, SETUP_LAUNCH_Y, 280, 52) then
        launchGame()
    end
end

function launchGame()
    initGame(setupChoice.difficulty, setupChoice.clan)
    currentState = STATE.playing
end

-- ============================================================
-- Deck building — initialisation
-- ============================================================
function initGame(difficultyIndex, clan)
    difficultyIndex = difficultyIndex or 1
    clan            = clan or "sun"
    state.difficulty = config.difficulties[difficultyIndex]
    state.clan       = clan
    state.resources = {}
    for _, def in ipairs(config.resources) do
        state.resources[def.key] = {
            name    = def.name,
            key     = def.key,
            icon    = def.icon,
            color   = def.color,
            current = def.start,
            max     = def.max,
        }
    end

    state.zones = {
        deck        = engine.newZone(30,          LAYOUT_HAND_Y, 100, LAYOUT_HAND_H, "stack", "Deck"),
        hand        = engine.newZone(150,         LAYOUT_HAND_Y, 700, LAYOUT_HAND_H, "fan",   "Main"),
        discard     = engine.newZone(870,         LAYOUT_HAND_Y, 100, LAYOUT_HAND_H, "stack", "Défausse"),
        tableau     = engine.newZone(30,          LAYOUT_TAB_Y,  940, LAYOUT_TAB_H,  "row",   "Tableau"),
        territory_left  = engine.newZone(10,  LAYOUT_UPPER_Y, 420, LAYOUT_UPPER_H, "row",   "Territoire"),
        jungle          = engine.newZone(440, LAYOUT_UPPER_Y, 130, LAYOUT_UPPER_H, "stack", "Jungle"),
        territory_right = engine.newZone(580, LAYOUT_UPPER_Y, 420, LAYOUT_UPPER_H, "row",   "Territoire"),
        trophies    = engine.newZone(LAYOUT_SIDE_X, LAYOUT_DINO_Y, 230, 160, "row", "Trophées"),
    }
    state.volcan = false

    -- Deck de départ : clan choisi + 1 chef aléatoire
    for _, card_id in ipairs(config.starter_deck[clan]) do
        local card = engine.newCard(card_id, config.make_card(config.get_card(card_id)))
        card.face_up = false
        engine.addCard(state.zones.deck, card)
    end
    local chief_id = config.chiefs[love.math.random(#config.chiefs)]
    local chief    = engine.newCard(chief_id, config.make_card(config.get_card(chief_id)))
    chief.face_up  = false
    engine.addCard(state.zones.deck, chief)
    engine.shuffle(state.zones.deck)

    -- Jungle : N cartes tirées au hasard (selon difficulté) + 4 Ennemis
    local all_ids = config.deck_ids("jungle")
    for i = #all_ids, 2, -1 do                          -- Fisher-Yates sur liste brute
        local j = love.math.random(i)
        all_ids[i], all_ids[j] = all_ids[j], all_ids[i]
    end
    local jungle_size = state.difficulty.jungle_size
    local jungle_ids  = {}
    state.jungle_reserve = {}                            -- réserve pour la mécanique Œufs
    for i, id in ipairs(all_ids) do
        if i <= jungle_size then
            table.insert(jungle_ids, id)
        else
            table.insert(state.jungle_reserve, id)
        end
    end
    for _, eid in ipairs(config.enemy_ids) do            -- ajouter les 4 Ennemis
        table.insert(jungle_ids, eid)
    end
    for i = #jungle_ids, 2, -1 do                       -- mélanger le tout
        local j = love.math.random(i)
        jungle_ids[i], jungle_ids[j] = jungle_ids[j], jungle_ids[i]
    end
    for _, card_id in ipairs(jungle_ids) do
        local card = engine.newCard(card_id, config.make_card(config.get_card(card_id)))
        card.face_up = false
        engine.addCard(state.zones.jungle, card)
    end
    -- Les territoires de chasse démarrent vides (remplis par l'action Chasse)

    -- 2 piles Dinos : 1 pile L1 (gauche, 4 cartes) + 1 pile L2 (droite, 3 cartes)
    local function shuffle_pool(pool)
        for i = #pool, 2, -1 do
            local j = love.math.random(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
    end

    local l1_pool, l2_pool = {}, {}
    for _, db in ipairs(config.get_cards_of_type("dino_l1")) do
        for _ = 1, (db.qty or 1) do table.insert(l1_pool, db) end
    end
    for _, db in ipairs(config.get_cards_of_type("dino_l2")) do
        for _ = 1, (db.qty or 1) do table.insert(l2_pool, db) end
    end
    shuffle_pool(l1_pool)
    shuffle_pool(l2_pool)

    local function build_dino_pile(pool, count, x, y, w, h, level)
        local zone = engine.newZone(x, y, w, h, "stack", "")
        -- Empiler face cachée du bas vers le haut
        for i = count, 1, -1 do
            local card = engine.newCreature(config.make_creature(pool[i]))
            card.face_up = false
            engine.addCard(zone, card)
        end
        -- Révéler uniquement la carte du dessus
        if #zone.cards > 0 then
            zone.cards[#zone.cards].face_up = true
        end
        return { zone = zone, level = level }
    end

    state.dino_piles = {
        build_dino_pile(l1_pool, config.solo_dino_left_count,  150, LAYOUT_DINO_Y, 160, LAYOUT_DINO_H, 1),
        build_dino_pile(l2_pool, config.solo_dino_right_count, 700, LAYOUT_DINO_Y, 160, LAYOUT_DINO_H, 2),
    }

    state.turn      = 1
    state.phase     = "action"
    state.strength  = 0
    state.score     = 0
    state.message   = "Tour 1 — Glisse des cartes sur le Tableau, clique les créatures pour attaquer"
    state.game_over = false
    state.drag      = { card = nil, origin = nil, ox = 0, oy = 0 }
    state.mx, state.my = 0, 0

    drawHand()
end

-- ============================================================
-- Deck building — update
-- ============================================================
function updateGame(dt)
    state.mx, state.my = getVirtualMousePos()
    if state.drag.card then
        state.drag.card.x = state.mx - state.drag.ox
        state.drag.card.y = state.my - state.drag.oy
    end
end

-- ============================================================
-- Deck building — draw
-- ============================================================
function drawGame()
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)

    -- Barre de titre (zone dédiée, fond légèrement distinct)
    love.graphics.setColor(0.05, 0.05, 0.10)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, 30)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.line(0, 30, VIRTUAL_W, 30)

    love.graphics.setColor(0.75, 0.75, 0.85)
    love.graphics.print(
        config.title .. "  |  Tour : " .. state.turn ..
        "  |  Score : " .. state.score ..
        "  |  Force : " .. state.strength .. " + " .. state.resources.dino_tokens.current .. "D",
        10, 8
    )

    local res_list = {}
    for _, def in ipairs(config.resources) do
        table.insert(res_list, state.resources[def.key])
    end
    engine.drawResources(res_list, 30, LAYOUT_RES_Y)

    local dragged = state.drag.card

    -- 2 piles dinos
    local pile_labels = { { "Dinos L1", 0.4, 0.8, 0.4 }, { "Dinos L2", 0.9, 0.35, 0.35 } }
    for i, pile in ipairs(state.dino_piles) do
        local z   = pile.zone
        local lbl = pile_labels[i]
        -- Label au-dessus
        love.graphics.setColor(lbl[2], lbl[3], lbl[4], 0.9)
        love.graphics.printf(lbl[1], z.x, z.y - 18, z.w, "center")
        -- Zone + cartes
        engine.drawZone(pile.zone, dragged)
        -- Compteur de cartes restantes
        local count = #pile.zone.cards
        if count > 0 then
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.printf(count .. " restant" .. (count > 1 and "s" or ""),
                z.x, z.y + z.h + 4, z.w, "center")
        end
    end
    -- Séparateur visuel L1/L2
    love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(LAYOUT_SEP_X, LAYOUT_DINO_Y - 15, LAYOUT_SEP_X, LAYOUT_UPPER_Y - 5)

    -- Territoires de chasse + Jungle centrale
    engine.drawZone(state.zones.territory_left,  dragged)
    engine.drawZone(state.zones.jungle,           dragged)
    engine.drawZone(state.zones.territory_right,  dragged)

    for _, name in ipairs({ "trophies", "tableau", "deck", "discard", "hand" }) do
        engine.drawZone(state.zones[name], dragged)
    end

    local btn_x, btn_y, btn_w, btn_h = LAYOUT_SIDE_X, LAYOUT_BTN_Y, LAYOUT_BTN_W, LAYOUT_BTN_H
    engine.drawButton("Fin de Tour", btn_x, btn_y, btn_w, btn_h,
        engine.pointInRect(state.mx, state.my, btn_x, btn_y, btn_w, btn_h))

    local atk_x, atk_y, atk_w, atk_h = LAYOUT_SIDE_X, LAYOUT_ATK_Y, LAYOUT_BTN_W, LAYOUT_BTN_H
    love.graphics.setColor(0.15, 0.15, 0.2, 0.8)
    love.graphics.rectangle("fill", atk_x, atk_y, atk_w, atk_h, 6, 6)
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.printf("ATK : " .. (state.strength + state.resources.dino_tokens.current),
        atk_x, atk_y + atk_h / 2 - 8, atk_w, "center")

    love.graphics.setColor(1, 1, 0.7)
    love.graphics.print(state.message, 30, LAYOUT_MSG_Y)

    if state.game_over then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)
        love.graphics.setColor(1, 1, 0.5)
        love.graphics.printf("VICTOIRE !", 0, 280, VIRTUAL_W, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Score final : " .. state.score .. " pts en " .. state.turn .. " tours",
            0, 330, VIRTUAL_W, "center")
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("R — Rejouer   |   ÉCHAP — Menu", 0, 380, VIRTUAL_W, "center")
    end

    if dragged then
        engine.drawCard(dragged, true)
    end
end

-- ============================================================
-- Deck building — logique
-- ============================================================
function drawHand()
    local deck    = state.zones.deck
    local hand    = state.zones.hand
    local discard = state.zones.discard

    if #deck.cards < config.hand_size then
        engine.moveAllCards(discard, deck)
        for _, c in ipairs(deck.cards) do c.face_up = false end
        engine.shuffle(deck)
    end

    engine.dealCards(deck, hand, config.hand_size)

    state.strength = 0
end

function addResource(key, amount)
    local res = state.resources[key]
    if res then
        res.current = math.min(res.current + amount, res.max)
    end
end

function spendResource(key, amount)
    local res = state.resources[key]
    if res and res.current >= amount then
        res.current = res.current - amount
        return true
    end
    return false
end

function playCard(card)
    if card.food_gain   > 0 then addResource("food", card.food_gain) end
    state.strength = state.strength + card.strength
    state.message  = "Joué : " .. card.name .. " | Force totale : " .. state.strength
end

function attackCreature(creature, pile)
    local total = state.strength + state.resources.dino_tokens.current
    if total >= creature.hp then
        state.score    = state.score + creature.points
        addResource("food", creature.reward_food)
        state.resources.dino_tokens.current = 0
        state.strength = 0
        -- Déplacer le dino vaincu vers la zone Trophées
        if pile then
            engine.removeCard(pile.zone, creature)
            creature.face_up = true
            engine.addCard(state.zones.trophies, creature)
            -- Révéler le prochain dino de la pile
            local new_top = #pile.zone.cards > 0 and pile.zone.cards[#pile.zone.cards] or nil
            if new_top then new_top.face_up = true end
        end
        -- Vérifier victoire (toutes les piles vides)
        local all_clear = true
        for _, p in ipairs(state.dino_piles) do
            if #p.zone.cards > 0 then all_clear = false; break end
        end
        if all_clear then
            state.game_over = true
            state.message   = "Tous les dinos vaincus ! Score : " .. state.score
        else
            state.message = creature.name .. " vaincu ! +" .. creature.points .. " pts"
        end
    else
        state.message = creature.name .. " : il faut " .. creature.hp .. " ATK. Vous avez " .. total
    end
end

function buyCard(card, from_zone)
    if card.cost <= 0 or card.cost_type == "" then
        state.message = card.name .. " n'est pas à vendre"
        return
    end
    if spendResource(card.cost_type, card.cost) then
        engine.removeCard(from_zone, card)
        card.face_up = false
        engine.addCard(state.zones.discard, card)
        state.message = card.name .. " acheté ! Ajouté à la défausse."
    else
        state.message = "Il faut " .. card.cost .. " " .. card.cost_type .. " pour acheter " .. card.name
    end
end

function endTurn()
    if state.game_over then return end

    engine.moveAllCards(state.zones.hand, state.zones.discard)

    local keep = {}
    for _, card in ipairs(state.zones.tableau.cards) do
        if card.persistent then
            table.insert(keep, card)
        else
            table.insert(state.zones.discard.cards, card)
        end
    end
    state.zones.tableau.cards = keep
    engine.layoutZone(state.zones.tableau)
    engine.layoutZone(state.zones.discard)

    state.strength = 0
    state.turn     = state.turn + 1

    local all_defeated = true
    for _, c in ipairs(state.zones.creatures.cards) do
        if not c.defeated then all_defeated = false end
    end
    if all_defeated then
        state.game_over = true
        state.message   = "Toutes les créatures vaincues ! Score : " .. state.score
        return
    end

    drawHand()
    state.message = "Tour " .. state.turn .. " — Glisse des cartes sur le Tableau, clique les créatures pour attaquer"
end

-- ============================================================
-- Saisie du nom (pour les high scores — prêt à être branché)
-- ============================================================
function drawNameEntry()
    love.graphics.setColor(0, 0.05, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)
    love.graphics.setColor(0.2, 1, 0.45, 1)
    love.graphics.printf("FÉLICITATIONS !", 0, 80, VIRTUAL_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Score : " .. finalScore .. "   Tours : " .. finalTurns, 0, 145, VIRTUAL_W, "center")
    love.graphics.setColor(0.75, 0.75, 0.75, 1)
    love.graphics.printf("Entrez vos initiales :", 0, 230, VIRTUAL_W, "center")

    local boxW, boxH = 80, 90
    local gap        = 20
    local totalW     = 3 * boxW + 2 * gap
    local startX     = (VIRTUAL_W - totalW) / 2
    local boxY       = 280

    for i = 1, 3 do
        local bx      = startX + (i - 1) * (boxW + gap)
        local active  = (i == nameSlot)
        local flashOn = active and (math.floor(love.timer.getTime() * 2) % 2 == 0)
        love.graphics.setColor(active and {0.18, 0.18, 0.28, 1} or {0.1, 0.1, 0.15, 1})
        love.graphics.rectangle("fill", bx, boxY, boxW, boxH, 8, 8)
        love.graphics.setColor(active and {1, 0.9, 0, 1} or {0.4, 0.4, 0.4, 1})
        love.graphics.setLineWidth(active and 3 or 1)
        love.graphics.rectangle("line", bx, boxY, boxW, boxH, 8, 8)
        love.graphics.setLineWidth(1)
        if not (active and flashOn) then
            love.graphics.setColor(active and {1, 0.9, 0, 1} or {1, 1, 1, 1})
            love.graphics.printf(nameChars[i], bx, boxY + 22, boxW, "center")
        end
    end

    love.graphics.setColor(0.45, 0.45, 0.45, 1)
    love.graphics.printf("GAUCHE/DROITE : case   HAUT/BAS : lettre   Taper A-Z   ENTRÉE : confirmer",
        0, VIRTUAL_H - 40, VIRTUAL_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

function handleNameEntryInput(key)
    if key == "left" then
        nameSlot = math.max(1, nameSlot - 1)
    elseif key == "right" then
        nameSlot = math.min(3, nameSlot + 1)
    elseif key == "up" then
        local c = string.byte(nameChars[nameSlot])
        nameChars[nameSlot] = string.char(c < string.byte("Z") and c + 1 or string.byte("A"))
    elseif key == "down" then
        local c = string.byte(nameChars[nameSlot])
        nameChars[nameSlot] = string.char(c > string.byte("A") and c - 1 or string.byte("Z"))
    elseif key == "backspace" then
        nameChars[nameSlot] = "A"
        if nameSlot > 1 then nameSlot = nameSlot - 1 end
    elseif key == "return" then
        confirmName()
    end
end

function confirmName()
    local name = nameChars[1] .. nameChars[2] .. nameChars[3]
    newEntryRank = HighScore.add(name, finalScore)
    currentState = STATE.highscores
end

-- ============================================================
-- Leaderboard
-- ============================================================
function drawHighScores()
    love.graphics.setColor(0, 0.04, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, VIRTUAL_W, VIRTUAL_H)
    love.graphics.setColor(1, 0.85, 0.1, 1)
    love.graphics.printf("MEILLEURS SCORES", 0, 55, VIRTUAL_W, "center")

    local col1, col2, col3 = 380, 580, 750
    local headerY = 130
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.print("#",     col1, headerY)
    love.graphics.print("NOM",   col2, headerY)
    love.graphics.print("SCORE", col3, headerY)
    love.graphics.line(360, headerY + 24, 900, headerY + 24)

    local entries = HighScore.getAll()
    local rowH    = 48
    local startY  = headerY + 36

    for i, e in ipairs(entries) do
        local y     = startY + (i - 1) * rowH
        local isNew = (i == newEntryRank)
        if isNew then
            love.graphics.setColor(1, 0.9, 0, 0.12)
            love.graphics.rectangle("fill", 355, y - 6, 555, rowH - 4, 6, 6)
        end
        local rankColor = isNew             and {1, 0.9, 0, 1}
            or (i == 1  and {1, 0.84, 0.1, 1})
            or (i == 2  and {0.75, 0.75, 0.8, 1})
            or (i == 3  and {0.8, 0.5, 0.2, 1})
            or {0.7, 0.7, 0.7, 1}
        love.graphics.setColor(rankColor)
        love.graphics.print(i .. ".",       col1, y)
        love.graphics.print(e.name,         col2, y)
        love.graphics.print(tostring(e.time), col3, y)
    end

    if #entries == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.printf("Aucun score enregistré", 0, startY + 20, VIRTUAL_W, "center")
    end

    love.graphics.setColor(0.45, 0.45, 0.45, 1)
    love.graphics.printf("Appuie sur une touche ou clique pour continuer", 0, VIRTUAL_H - 40, VIRTUAL_W, "center")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- Utilitaire : position souris dans l'espace virtuel
-- ============================================================
function getVirtualMousePos()
    local mx, my = love.mouse.getPosition()
    local ww, wh = love.graphics.getDimensions()
    local scale  = math.min(ww / VIRTUAL_W, wh / VIRTUAL_H)
    local ox     = (ww - VIRTUAL_W * scale) / 2
    local oy     = (wh - VIRTUAL_H * scale) / 2
    return (mx - ox) / scale, (my - oy) / scale
end
