local Settings      = require("scripts/settings")
local Audio         = require("scripts/audio")
local Controls      = require("scripts/controls")
local HighScore     = require("scripts/highscore")
local engine        = require("engine")
local config        = require("game_config")
local L             = require("zones")   -- constantes layout + factories zones/dinos
local solo          = require("solo_rules")
local card_powers   = require("card_powers")

-- ============================================================
-- Résolution virtuelle
-- ============================================================
local VIRTUAL_W, VIRTUAL_H = 1280, 800
local canvas

-- ============================================================
-- Alias locaux des constantes de layout (définies dans zones.lua)
-- ============================================================
local LAYOUT_UPPER_Y = L.UPPER_Y
local LAYOUT_UPPER_H = L.UPPER_H
local LAYOUT_DINO_Y  = L.DINO_Y
local LAYOUT_DINO_H  = L.DINO_H
local LAYOUT_SEP_X   = L.SEP_X
local LAYOUT_RES_Y   = L.RES_Y
local LAYOUT_MSG_Y   = L.MSG_Y
local LAYOUT_TAB_Y   = L.TAB_Y
local LAYOUT_TAB_H   = L.TAB_H
local LAYOUT_HAND_Y  = L.HAND_Y
local LAYOUT_HAND_H  = L.HAND_H
local LAYOUT_SIDE_X  = L.SIDE_X
local LAYOUT_ATK_Y   = L.ATK_Y
local LAYOUT_BTN_Y   = L.BTN_Y
local LAYOUT_BTN_W   = L.BTN_W
local LAYOUT_BTN_H   = L.BTN_H

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
    rageFont = love.graphics.newFont("assets/fonts/NotoSans-Bold.ttf", 72)

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
        -- Decrement RAGE animation timer
        if state.rage_timer > 0 then
            state.rage_timer = state.rage_timer - dt
        end
       -- Decrement shake timer
        if state.shake_timer > 0 then
            state.shake_timer = state.shake_timer - dt
        end
        updateGame(dt)
    end
end


-- ── Rendu des ennemis RAGE ───────────────────────────────────
local ENEMY_CW      = 65
local ENEMY_CH      = 95
local ENEMY_SPACING = 70
local ENEMY_MAX     = 4

-- Position x du i-ème ennemi : gauche = du centre vers la gauche, droite = du centre vers la droite
local function enemyPosX(side, i)
    if side == "left" then
        return L.ENEMY_LEFT_X + L.ENEMY_LEFT_W - i * ENEMY_SPACING   -- 250, 180, 110, 40
    else
        return L.ENEMY_RIGHT_X + (i - 1) * ENEMY_SPACING             -- 720, 790, 860, 930
    end
end

-- Dessine les ennemis du centre vers l'extérieur
function drawEnemies(enemies, side, y)
    for i, enemy in ipairs(enemies) do
        if i > ENEMY_MAX then break end
        local ex = enemyPosX(side, i)
        love.graphics.setColor(0.7, 0.05, 0.05, 0.95)
        love.graphics.rectangle("fill", ex, y, ENEMY_CW, ENEMY_CH, 6)
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", ex, y, ENEMY_CW, ENEMY_CH, 6)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(enemy.name or "?", ex + 2, y + 8,  ENEMY_CW - 4, "center")
        love.graphics.setColor(1, 0.6, 0.6)
        love.graphics.printf("ENNEMI",           ex + 2, y + 28, ENEMY_CW - 4, "center")
        local cost = config.enemy_costs[enemy.id]
        if cost then
            love.graphics.setColor(1, 1, 0.6)
            love.graphics.printf("F:" .. cost.force, ex + 2, y + 52, ENEMY_CW - 4, "center")
            if cost.resource and cost.amount then
                love.graphics.printf(cost.resource:sub(1,4) .. ":" .. cost.amount,
                                     ex + 2, y + 68, ENEMY_CW - 4, "center")
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
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
    --love.graphics.draw(canvas, ox, oy, 0, scale, scale)
    
    -- Apply screen shake offset
    local shake_x, shake_y = 0, 0
    if state and state.shake_timer and state.shake_timer > 0 then
        shake_x = love.math.random(-state.shake_intensity, state.shake_intensity)
        shake_y = love.math.random(-state.shake_intensity, state.shake_intensity)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, ox + shake_x, oy + shake_y, 0, scale, scale)


    -- RAGE visual overlay: red border flash + text
    --if state.rage_timer > 0 then
--[[     if state and state.rage_timer and state.rage_timer > 0 then 
        love.graphics.setColor(1, 0, 0, 0.6)
        love.graphics.setLineWidth(6)
        love.graphics.rectangle("line", 3, 3, 1274, 794)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.printf("RAGE!", 0, 350, 1280, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end --]]

     -- RAGE visual overlay (drawn on screen, after canvas ) 
         if state and state.rage_timer and state.rage_timer > 0 then 
            love.graphics.push() 
            love.graphics.translate(ox, oy)
            love.graphics.scale(scale , scale)
             
            -- Red semi-transparent overlay 
            love.graphics.setColor(1 , 0, 0, 0.15) 
            love.graphics.rectangle("fill", 0, 0, 1280 , 800)
            -- Red border 
            love.graphics.setColor(1, 0, 0 , 0.8)
            love.graphics.setLineWidth(8)
            love.graphics.rectangle("line", 4, 4, 1272, 792) 
            love.graphics.setLineWidth(1) 
              
            -- Big "RAGE!" text 
            love.graphics.setFont(rageFont ) 
            
            -- Shadow
            love.graphics.setColor(0, 0, 0, 0.8) 
            love.graphics.printf("RAGE !", 3, 353, 1280 , "center") 
            
            -- Main text 
            love.graphics.setColor(1, 0.2, 0, 1) 
            love.graphics.printf("RAGE !", 0, 350, 1280, "center") 
            engine.useDefault() 
            love.graphics.setColor(1, 1, 1, 1 ) 
            love.graphics.pop()
        end 

    -- Score breakdown overlay
--[[     if state.game_over and state.final_score then
        -- Dim the game board behind the overlay
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, 1280, 800)

        -- Header: victory or defeat
        love.graphics.setColor(1, 1, 1)
        local header = state.victory and "VICTOIRE !" or "DEFAITE !"
        love.graphics.printf(header, 0, 120, 1280, "center")

        -- Score breakdown by category
        local s = state.final_score
        local y = 260
        local gap = 40

        love.graphics.printf("Familles : " .. s.families .. " x 2VP = " .. (s.families * 2) .. " VP", 0, y, 1280, "center")
        y = y + gap
        love.graphics.printf("Totems : " .. s.totems .. " x 1VP = " .. (s.totems * 1) .. " VP", 0, y, 1280, "center")
        y = y + gap
        love.graphics.printf("Dinosaures : " .. s.dinos .. " x 1VP = " .. (s.dinos * 1) .. " VP", 0, y, 1280, "center")
        y = y + gap
        love.graphics.printf("Oeufs : " .. s.eggs .. " VP", 0, y, 1280, "center")
        y = y + gap * 2

        -- Total score
        love.graphics.printf("TOTAL : " .. s.total .. " VP", 0, y, 1280, "center")
        y = y + gap * 2

        -- Restart/menu prompt
        love.graphics.printf("R = Recommencer | Echap = Menu", 0, y, 1280, "center")
    end --]]
    -- Score breakdown overlay 
        if state and state.game_over and state.final_score then
            love.graphics.push()
            love.graphics.translate( ox, oy)
            love.graphics.scale(scale, scale) 
            love.graphics.setColor(0 , 0, 0, 0.85) 
            love.graphics.rectangle("fill", 0, 0, 1280 , 800) 
            love.graphics.setColor(1, 1, 1 ) 
                
            local header = state.victory and "VICTOIRE !" or "DEFAITE !" 
            love .graphics.printf(header, 0 , 120, 1280, "center") 
            local s = state.final_score 
            local y = 260 
            local gap = 40 
            love.graphics.printf("Familles : " .. s.families .. " x 2VP = " .. (s.families * 2) .. " VP", 0, y, 1280, "center")
            y = y + gap 
            love.graphics.printf("Totems : " .. s.totems .. " x 1VP = " .. (s. totems * 1) .. " VP ", 0, y, 1280, " center")
            y = y + gap 
            love.graphics.printf("Dinosaures : " .. s.dinos .. " x 1VP = " .. (s.dinos * 1) .. " VP", 0, y, 1280, "center") 
            y = y + gap 
            love.graphics.printf("Oeufs : " .. s.eggs .. " VP", 0, y, 1280 , "center") 
            y = y + gap * 2 
            love .graphics.printf("TOTAL : " .. s.total .. " VP ", 0, y, 1280, " center")
            y = y + gap * 2
            love .graphics.printf("R = Recommencer | Echap = Menu", 0 , y, 1280, "center") love.graphics.pop() 
        end
end

-- ============================================================
-- love.keypressed
-- ============================================================
function love.keypressed(key)
    -- Game-over screen: R to restart, Escape to menu
    if state.game_over then
        if key == "r" then
            initGame()
        elseif key == "escape" then
            gameState = "menu"
        end
        return
    end

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

        -- Popup : sélection de carte à détruire (pouvoir chef)
        if state.pending_destroy then
            local popup_x, popup_y = 300, 250
            local btn_w, btn_h     = 260, 36
            for i, entry in ipairs(state.pending_destroy.choices) do
                local btn_y = popup_y + (i - 1) * (btn_h + 6)
                if vx >= popup_x and vx <= popup_x + btn_w
                and vy >= btn_y and vy <= btn_y + btn_h then
                    engine.removeCard(entry.zone, entry.card)
                    local r = state.pending_destroy.reward
                    if r.food        > 0 then addResource("food",        r.food)        end
                    if r.ami         > 0 then addResource("ami",         r.ami)         end
                    if r.dino_tokens > 0 then addResource("dino_tokens", r.dino_tokens) end
                    if r.force       > 0 then state.strength = state.strength + r.force end
                    state.message        = state.pending_destroy.msg
                    state.pending_destroy = nil
                    return
                end
            end
            return  -- clic hors popup → garder ouverte (sélection obligatoire)
        end

        -- Handle clicks on the action selection popup
        if state.pending_activation and state.pending_actions then
            local popup_x, popup_y = 500, 250
            local btn_w, btn_h = 200, 36
            local clicked_action = nil

            for i, action in ipairs(state.pending_actions) do
                local btn_y = popup_y + (i - 1) * (btn_h + 6)
                --[[ if mx >= popup_x and mx <= popup_x + btn_w
                and my >= btn_y and my <= btn_y + btn_h then --]]
                if vx >= popup_x and vx <= popup_x + btn_w
                and vy >= btn_y and vy <= btn_y + btn_h then
                    clicked_action = action
                    break
                end
            end



            --[[if clicked_action then
                -- Dispatch the selected action (wired in the next substep)
                solo.activate_clan_card(state.pending_activation, state)
                state.pending_activation = nil
                state.pending_actions = nil
                return
            else
                -- Clicked outside popup: dismiss it
                state.pending_activation = nil
                state.pending_actions = nil
                return
            end --]]
            
            if clicked_action then
                local card = state.pending_activation
                local action_key = clicked_action.key

                if action_key == solo.ACTIONS.USE_POWER then
                    solo.activate_clan_card(card, state)
                    local db_entry = config.get_card(card.id)
                    if db_entry and db_entry.card_power then
                        local power_fn = card_powers[db_entry.card_power]
                        if power_fn then
                            local gs = {
                                food = state.resources.food.current,
                                ami = state.resources.ami.current,
                                dino_tokens = state.resources.dino_tokens.current,
                                attack_force = state.strength,
                                message = "",
                                pending_draw = 0,
                            }
                            power_fn(gs, card)
                            if gs.pending_destroy then
                                -- Chef power : montrer popup de sélection de carte à détruire
                                local choices = {}
                                for _, c in ipairs(state.zones.hand.cards) do
                                    table.insert(choices, { card = c, zone = state.zones.hand })
                                end
                                for _, c in ipairs(state.zones.tableau.cards) do
                                    if c ~= card then
                                        table.insert(choices, { card = c, zone = state.zones.tableau })
                                    end
                                end
                                if #state.zones.cave.cards > 0 then
                                    local cv = state.zones.cave.cards[#state.zones.cave.cards]
                                    table.insert(choices, { card = cv, zone = state.zones.cave })
                                end
                                state.pending_destroy = {
                                    choices = choices,
                                    reward  = gs.pending_destroy.reward,
                                    msg     = gs.pending_destroy.msg,
                                }
                                state.message = gs.message
                            else
                                state.resources.food.current = math.min(gs.food, state.resources.food.max)
                                state.resources.ami.current = math.min(gs.ami, state.resources.ami.max)
                                state.resources.dino_tokens.current = math.min(gs.dino_tokens, state.resources.dino_tokens.max)
                                state.strength = gs.attack_force
                                state.message = gs.message or state.message
                                if (gs.pending_draw or 0) > 0 then
                                    engine.dealCards(state.zones.deck, state.zones.hand, gs.pending_draw)
                                end
                            end
                        end
                    end
                elseif action_key == solo.ACTIONS.SUPPORT then
                    -- Don't activate yet — show secondary popup to pick an action card
                    state.selecting_action_card = true
                    -- Build list of action cards in hand
                    state.action_card_choices = {}
                    for _, c in ipairs(state.zones.hand.cards) do
                        local cdb = config.get_card(c.id)
                        if cdb and cdb.card_type == "action" then
                            table.insert(state.action_card_choices, c)
                        end
                    end
                    -- Don't clear pending_activation yet — we still need it
                    state.pending_actions = nil
                    return

                elseif action_key == solo.ACTIONS.HUNT_LEFT then
                    local revealed, food = solo.hunt(card, state.zones.territory_left, state)
                    solo.activate_clan_card(card, state)
                    state.message = revealed .. " carte(s) chassees a gauche, +" .. food .. " nourriture"

                elseif action_key == solo.ACTIONS.HUNT_RIGHT then
                    local revealed, food = solo.hunt(card, state.zones.territory_right, state)
                    solo.activate_clan_card(card, state)
                    state.message = revealed .. " carte(s) chassees a droite, +" .. food .. " nourriture"

                elseif action_key == solo.ACTIONS.FORM_AMI then
                    state.ami_initiator       = card
                    state.ami_partner_choices = solo.get_ami_partners(card, state)
                    state.selecting_ami_partner = true
                    state.pending_actions = nil
                    return  -- keep pending_activation for form_ami_pair

                else
                    solo.activate_clan_card(card, state)
                    state.message = "Action en cours: " .. (clicked_action.label or "?")
                end

                state.pending_activation = nil
                state.pending_actions = nil
                return
            else
                -- Clicked outside popup: dismiss it (KEEP THIS!)
                state.pending_activation = nil
                state.pending_actions = nil
                return
            end

        end

        -- Handle clicks on the action card selection popup
        if state.selecting_action_card and state.action_card_choices then
            local popup_x, popup_y = 500, 250
            local btn_w, btn_h = 200, 36
            local clicked_card = nil

            for i, c in ipairs(state.action_card_choices) do
                local btn_y = popup_y + (i - 1) * (btn_h + 6)
                if vx >= popup_x and vx <= popup_x + btn_w
                and vy >= btn_y and vy <= btn_y + btn_h then
                    clicked_card = c
                    break
                end
            end

            if clicked_card then
                -- Activate the clan card (no power fired)
                solo.activate_clan_card(state.pending_activation, state)

                -- Remove action card from hand
                engine.removeCard(state.zones.hand, clicked_card)

                -- Route to totem zone or tableau
                local db = config.get_card(clicked_card.id)
                if db and db.has_totem then
                    engine.addCard(state.zones.totem, clicked_card)
                else
                    engine.addCard(state.zones.tableau, clicked_card)
                end

                -- Fire the action card's power
                if db and db.card_power then
                    local power_fn = card_powers[db.card_power]
                    if power_fn then
                        local gs = solo.build_power_state(state)
                        power_fn(gs, clicked_card)
                        solo.apply_power_state(gs, state)
                    end
                end

                state.message = "Action activee: " .. (clicked_card.name or "?")
            else
                -- Clicked outside: cancel
                state.message = "Support annule."
            end

            state.pending_activation = nil
            state.selecting_action_card = false
            state.action_card_choices = nil
            return
        end

        -- Handle FORM_AMI partner selection popup
        if state.selecting_ami_partner and state.ami_partner_choices then
            local popup_x, popup_y = 500, 250
            local btn_w, btn_h = 200, 36
            local chosen = nil

            for i, c in ipairs(state.ami_partner_choices) do
                local btn_y = popup_y + (i - 1) * (btn_h + 6)
                if vx >= popup_x and vx <= popup_x + btn_w
                and vy >= btn_y and vy <= btn_y + btn_h then
                    chosen = c
                    break
                end
            end

            if chosen then
                state.message = solo.form_ami_pair(state.ami_initiator, chosen, state)
            else
                state.message = "Paire annulee."
            end

            state.pending_activation       = nil
            state.selecting_ami_partner    = false
            state.ami_partner_choices      = nil
            state.ami_initiator            = nil
            return
        end

        -- Handle clicks on totem zone cards
        local totem_zone = state.zones.totem
        for i, card in ipairs(totem_zone.cards) do
            local btn_x = totem_zone.x
            local btn_y = totem_zone.y + (i - 1) * 40
            local btn_w = totem_zone.w
            local btn_h = 32

            if vx >= btn_x and vx <= btn_x + btn_w
            and vy >= btn_y and vy <= btn_y + btn_h then
                local ok, msg = solo.activate_single_totem(card, state)
                state.message = msg or "Totem active."
                return
            end
        end

        -- Clic sur ennemis RAGE (zones latérales, centre → extérieur)
        if checkEnemyClick(vx, vy, state.enemies_left,  "left",  LAYOUT_UPPER_Y) then return end
        if checkEnemyClick(vx, vy, state.enemies_right, "right", LAYOUT_UPPER_Y) then return end


        -- Handle cave zone clicks
        local cave_zone = state.zones.cave
        if engine.pointInRect(vx, vy, cave_zone.x, cave_zone.y, cave_zone.w, cave_zone.h) then
            if state.pending_cave_card then
                -- A hand card was selected — swap it with cave
                local old = solo.swap_cave(state.pending_cave_card, state)
                if old then
                    state.message = "Grotte: echange " .. state.pending_cave_card.name .. " <-> " .. old.name
                else
                    state.message = "Grotte: " .. state.pending_cave_card.name .. " stockee."
                end
                state.pending_cave_card = nil
            else
                state.message = "Selectionnez d'abord une carte en main."
            end
            return
        end


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
            if #tzone.cards > 0 then
                local top = tzone.cards[#tzone.cards]
                if engine.pointInRect(vx, vy, top.x, top.y, engine.CARD_W, engine.CARD_H) then
                    buyCard(top, tzone)
                    return
                end
            end
        end

        
--[[         -- Handle hand card click for cave selection
        -- (Add this BEFORE your existing hand card / drag logic)
        for _, card in ipairs(state.zones.hand.cards) do
            local W, H = engine.CARD_W, engine.CARD_H
            if engine.pointInRect(vx, vy, card.x, card.y, W, H) then
                -- Right-click or modifier could be used, but simple toggle works too
                if state.pending_cave_card == card then
                    -- Deselect
                    state.pending_cave_card = nil
                    state.message = "Selection annulee."
                    return
                end
            end
        end --]]


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
        local tz  = state.zones.tableau
        local tzl = state.zones.territory_left
        local tzr = state.zones.territory_right
        --[[ if engine.pointInRect(vx, vy, tz.x, tz.y, tz.w, tz.h) then
            engine.addCard(tz, card)
            playCard(card)
            dropped = true
        elseif engine.pointInRect(vx, vy, tzl.x, tzl.y, tzl.w, tzl.h) then
            huntTerritory(card, tzl)
            dropped = true
        elseif engine.pointInRect(vx, vy, tzr.x, tzr.y, tzr.w, tzr.h) then
            huntTerritory(card, tzr)
            dropped = true
        end --]]



        -- Cave swap via drag-and-drop 
        if engine.pointInRect(vx, vy, state.zones.cave.x, state.zones.cave.y,
                            state.zones.cave.w, state.zones.cave.h) then
            local old = solo.swap_cave(card, state)
            if old then
                state.message = "Grotte: echange " .. card.name .. " <-> " .. old.name
            else
                state.message = "Grotte: " .. card.name .. " stockee."
            end
            dropped = true
        


        -- Tableau drop with activation
        elseif engine.pointInRect(vx, vy, tz.x, tz.y, tz.w, tz.h) then
            local db_entry = config.get_card(card.id)
            if db_entry and db_entry.card_type == "clan" then
                -- Return card to hand, then open action popup
                engine.addCard(state.drag.origin, card)
                -- Set this card as pending activation and build the action list
                state.pending_activation = card
                state.pending_actions = solo.get_available_actions(card, state)
            else
                -- Non-clan cards can't be activated directly
                state.message = "Seules les cartes Clan peuvent etre activees."
                engine.addCard(state.drag.origin, card)
            end
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

    -- Build the egg pool: 12 green (1pt), 8 red (2pt), 4 blue (2pt indestructible)
    local egg_pool = {}
    for _ = 1, 12 do table.insert(egg_pool, { value = 1, color = "vert" }) end
    for _ = 1, 8 do table.insert(egg_pool, { value = 2, color = "rouge" }) end
    for _ = 1, 4 do table.insert(egg_pool, { value = 2, color = "bleu", indestructible = true }) end

    -- Shuffle the full pool using Fisher-Yates
    for i = #egg_pool, 2, -1 do
        local j = love.math.random(i)
        egg_pool[i], egg_pool[j] = egg_pool[j], egg_pool[i]
    end

    -- Take the first 12 eggs for solo mode
    state.egg_bank = {}
    for i = 1, 12 do
        table.insert(state.egg_bank, egg_pool[i])
    end

    -- Track eggs the player has collected (starts empty)
    state.eggs_collected = {}

    state.zones  = L.createGameZones()
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
    state.dino_piles = L.createDinoPiles()

    state.turn      = 1
    state.phase     = "action"
    state.strength  = 0
    state.score     = 0
    state.message   = "Tour 1 — Glisse des cartes sur le Tableau, clique les créatures pour attaquer"
    state.game_over = false
    state.drag      = { card = nil, origin = nil, ox = 0, oy = 0 }
    state.mx, state.my = 0, 0
    
    -- Track which clan card is waiting for action selection (nil = no popup)
    state.pending_activation = nil
    -- Accumulated force from activated clan cards this turn
    state.strength = 0
    state.selecting_action_card = false
    state.action_card_choices = nil
    -- Track which hand card is selected for cave swap (nil = none)
    state.pending_cave_card = nil
    -- FORM_AMI partner selection popup
    state.selecting_ami_partner = false
    state.ami_partner_choices   = nil
    state.ami_initiator         = nil
    -- Destroy card selection popup (chef powers)
    state.pending_destroy = nil
    -- Enemy tracking for RAGE (one array per territory side)
    state.enemies_left = {}
    state.enemies_right = {}

    -- RAGE animation state
    state.rage_active = false
    state.rage_timer = 0

    -- Screen shake state
    state.shake_timer = 0
    state.shake_intensity = 0


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


---
-- Check if click lands on this enemy card
--[[ function checkEnemyClick(mx, my, enemies, x, y, side)
    for i, enemy in ipairs(enemies) do
        local ex = x + (i - 1) * 70
        if engine.pointInRect(mx, my, ex, y, 60, 90) then
            local msg = solo.defeat_enemy(enemy, side, state)
            state.message = msg or "Ennemi vaincu !"
            return true
        end
    end
    return false
end --]]

-- Détection de clic sur les ennemis RAGE (même logique que drawEnemies)
function checkEnemyClick(mx, my, enemies, side, y)
    for i, enemy in ipairs(enemies) do
        if i > ENEMY_MAX then break end
        local ex = enemyPosX(side, i)
        if engine.pointInRect(mx, my, ex, y, ENEMY_CW, ENEMY_CH) then
            local ok, msg = solo.defeat_enemy(enemy, side, state)
            state.message = msg
            return true
        end
    end
    return false
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
    --love.graphics.line(LAYOUT_SEP_X, LAYOUT_DINO_Y - 15, LAYOUT_SEP_X, LAYOUT_UPPER_Y - 5)

    -- Territoires (stacks étroits) + Jungle centrale
    engine.drawZone(state.zones.territory_left,  dragged)
    engine.drawZone(state.zones.jungle, dragged)
    engine.drawZone(state.zones.territory_right, dragged)
    -- Ennemis RAGE du centre vers l'extérieur
    drawEnemies(state.enemies_left,  "left",  LAYOUT_UPPER_Y)
    drawEnemies(state.enemies_right, "right", LAYOUT_UPPER_Y)
    -- Compteur ennemis (uniquement si ennemis présents)
    if #state.enemies_left > 0 then
        love.graphics.setColor(0.9, 0.4, 0.4)
        love.graphics.printf("Ennemis " .. #state.enemies_left,
            L.ENEMY_LEFT_X, LAYOUT_UPPER_Y + LAYOUT_UPPER_H + 2, L.ENEMY_LEFT_W, "left")
    end
    if #state.enemies_right > 0 then
        love.graphics.setColor(0.9, 0.4, 0.4)
        love.graphics.printf("Ennemis " .. #state.enemies_right,
            L.ENEMY_RIGHT_X, LAYOUT_UPPER_Y + LAYOUT_UPPER_H + 2, L.ENEMY_RIGHT_W, "right")
    end
    love.graphics.setColor(1, 1, 1)

    for _, name in ipairs({ "trophies", "tableau", "deck", "discard", "hand" }) do
        engine.drawZone(state.zones[name], dragged)
    end

    -- Draw cave zone with status label
    engine.drawZone(state.zones.cave)
    local cave = state.zones.cave
    local cave_label = #cave.cards > 0 and "1 carte" or "Vide"
    love.graphics.printf("Grotte: " .. cave_label, cave.x, cave.y + cave.h + 4, cave.w, "center")

    -- Draw totem zone with count
    engine.drawZone(state.zones.totem)
    local totem = state.zones.totem
    love.graphics.printf("Totems: " .. #totem.cards, totem.x, totem.y + totem.h + 4, totem.w, "center")


    -- Draw clickable activate buttons for each totem card
    for i, card in ipairs(state.zones.totem.cards) do
        local btn_x = totem.x
        local btn_y = totem.y + (i - 1) * 40
        local btn_w = totem.w
        local btn_h = 32

        if card.activated then
            -- Greyed out
            love.graphics.setColor(0.4, 0.4, 0.4, 0.6)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(card.name .. " (used)", btn_x, btn_y + 6, btn_w, "center")
        else
            -- Active / clickable
            love.graphics.setColor(0.2, 0.4, 0.2)
            love.graphics.rectangle("fill", btn_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(1, 1, 0.8)
            love.graphics.printf(card.name .. " [Activer]", btn_x, btn_y + 6, btn_w, "center")
        end
    end
    love.graphics.setColor(1, 1, 1)



    -- Draw egg bank with remaining count
    engine.drawZone(state.zones.egg_bank)
    local egg_zone = state.zones.egg_bank
    love.graphics.printf("Oeufs: " .. #state.egg_bank, egg_zone.x, egg_zone.y + egg_zone.h + 4, egg_zone.w, "center")



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

    -- Draw action selection popup when a clan card is pending activation
    if state.pending_activation and state.pending_actions then
        local popup_x, popup_y = 500, 250
        local btn_w, btn_h = 200, 36

        -- Semi-transparent background overlay
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", popup_x - 10, popup_y - 40,
                                btn_w + 20, #state.pending_actions * (btn_h + 6) + 50)

        -- Popup title showing the selected card's name
        love.graphics.setColor(1, 1, 0.6)
        love.graphics.printf("Activer: " .. (state.pending_activation.name or "?"),
                            popup_x, popup_y - 30, btn_w, "center")

        -- Draw one button per available action
        for i, action in ipairs(state.pending_actions) do
            local btn_y = popup_y + (i - 1) * (btn_h + 6)
            love.graphics.setColor(0.25, 0.35, 0.25)
            love.graphics.rectangle("fill", popup_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(action.label, popup_x, btn_y + 8, btn_w, "center")
        end
    end


    -- Draw action card selection popup (for Support)
    if state.selecting_action_card and state.action_card_choices then
        local popup_x, popup_y = 500, 250
        local btn_w, btn_h = 200, 36

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", popup_x - 10, popup_y - 40,
                                btn_w + 20, #state.action_card_choices * (btn_h + 6) + 50)

        love.graphics.setColor(1, 1, 0.6)
        love.graphics.printf("Choisir une carte Action:",
                            popup_x, popup_y - 30, btn_w, "center")

        for i, c in ipairs(state.action_card_choices) do
            local btn_y = popup_y + (i - 1) * (btn_h + 6)
            love.graphics.setColor(0.25, 0.25, 0.4)
            love.graphics.rectangle("fill", popup_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(c.name or "?", popup_x, btn_y + 8, btn_w, "center")
        end
    end

    -- Draw FORM_AMI partner selection popup
    if state.selecting_ami_partner and state.ami_partner_choices then
        local popup_x, popup_y = 500, 250
        local btn_w, btn_h = 200, 36

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", popup_x - 10, popup_y - 40,
                                btn_w + 20, #state.ami_partner_choices * (btn_h + 6) + 50)

        love.graphics.setColor(0.6, 1, 0.7)
        local init_name = state.ami_initiator and state.ami_initiator.name or "?"
        love.graphics.printf("Paire avec " .. init_name .. ":",
                            popup_x, popup_y - 30, btn_w, "center")

        for i, c in ipairs(state.ami_partner_choices) do
            local btn_y = popup_y + (i - 1) * (btn_h + 6)
            local cdb = config.get_card(c.id)
            love.graphics.setColor(0.15, 0.35, 0.2)
            love.graphics.rectangle("fill", popup_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(1, 1, 1)
            local side_label = cdb and ("[" .. (cdb.ami_side or "?") .. "] ") or ""
            love.graphics.printf(side_label .. (c.name or "?"), popup_x, btn_y + 8, btn_w, "center")
        end
    end

    -- Popup : sélection de carte à détruire (pouvoir chef)
    if state.pending_destroy and #state.pending_destroy.choices > 0 then
        local popup_x, popup_y = 300, 250
        local btn_w, btn_h     = 260, 36
        local n = #state.pending_destroy.choices
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", popup_x - 12, popup_y - 46,
                                btn_w + 24, n * (btn_h + 6) + 56, 6, 6)
        love.graphics.setColor(1, 0.5, 0.2)
        love.graphics.printf("Choisir une carte à détruire :", popup_x, popup_y - 34, btn_w, "center")
        for i, entry in ipairs(state.pending_destroy.choices) do
            local btn_y = popup_y + (i - 1) * (btn_h + 6)
            love.graphics.setColor(0.38, 0.10, 0.10)
            love.graphics.rectangle("fill", popup_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(0.9, 0.4, 0.4)
            love.graphics.rectangle("line", popup_x, btn_y, btn_w, btn_h, 4)
            love.graphics.setColor(1, 0.85, 0.85)
            local zone_label = (entry.zone == state.zones.hand)    and "[Main] "    or
                               (entry.zone == state.zones.cave)    and "[Grotte] "  or
                                                                        "[Tableau] "
            love.graphics.printf(zone_label .. (entry.card.name or "?"),
                                 popup_x, btn_y + 10, btn_w, "center")
        end
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

    -- Reset totem activation for the new turn
    solo.activate_totems_start_of_turn(state)

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
    if card.food_gain > 0 then addResource("food", card.food_gain) end
    state.strength = state.strength + card.strength
    state.message  = "Joué : " .. card.name .. " | Force totale : " .. state.strength
end

function huntTerritory(card, territory)
    local force = card.strength
    if force <= 0 then
        engine.addCard(state.zones.hand, card)
        engine.layoutZone(state.zones.hand)
        state.message = card.name .. " n'a pas de Force pour chasser"
        return
    end

    -- La carte est activée (placée dans le tableau, utilisée)
    engine.addCard(state.zones.tableau, card)
    engine.layoutZone(state.zones.tableau)

    local jungle       = state.zones.jungle
    local food_gained  = 0
    local revealed     = 0

    for _ = 1, force do
        if #jungle.cards == 0 then break end
        local c = table.remove(jungle.cards, #jungle.cards)
        c.face_up = true
        if c.type == "enemy" then
            -- Ennemi pendant une chasse : remis sous la Jungle sans effet
            table.insert(jungle.cards, 1, c)
            c.face_up = false
        else
            engine.addCard(territory, c)
            food_gained = food_gained + (c.food_gain or 0)
            revealed    = revealed + 1
        end
    end

    engine.layoutZone(territory)
    engine.layoutZone(jungle)

    if food_gained > 0 then addResource("food", food_gained) end

    local side = (territory == state.zones.territory_left) and "gauche" or "droite"
    state.message = "Chasse " .. side .. " : " .. revealed .. " carte(s) revelee(s)"
        .. (food_gained > 0 and " | +" .. food_gained .. " Nourriture" or "")
end

function attackCreature(creature, pile)
    local total = state.strength + state.resources.dino_tokens.current
    if total >= creature.hp then
        state.score = state.score + creature.points
        state.resources.dino_tokens.current = 0
        state.strength = 0

        local db = config.get_card(creature.id)
        local parts = { creature.name .. " vaincu !" }

        -- Nourriture
        local food = creature.reward_food or 0
        if food > 0 then addResource("food", food); table.insert(parts, "+" .. food .. " Nourrit.") end

        -- Pions Ami
        local ami = db and (db.reward_ami or 0) or 0
        if ami > 0 then addResource("ami", ami); table.insert(parts, "+" .. ami .. " Ami") end

        -- Jetons Dino
        local dino_tok = db and (db.reward_dino_tokens or 0) or 0
        if dino_tok > 0 then addResource("dino_tokens", dino_tok); table.insert(parts, "+" .. dino_tok .. " Dino") end

        -- Œufs
        local eggs = db and (db.reward_eggs or 0) or 0
        if eggs > 0 then solo.gain_egg(state, eggs); table.insert(parts, "+" .. eggs .. " oeuf(s)") end

        -- Détruire des cartes (obligatoire)
        local to_destroy = db and (db.reward_destroy_cards or 0) or 0
        local destroyed = 0
        for _ = 1, to_destroy do
            if #state.zones.tableau.cards > 0 then
                table.remove(state.zones.tableau.cards)
                engine.layoutZone(state.zones.tableau)
                destroyed = destroyed + 1
            elseif #state.zones.hand.cards > 0 then
                table.remove(state.zones.hand.cards)
                engine.layoutZone(state.zones.hand)
                destroyed = destroyed + 1
            end
        end
        if destroyed > 0 then table.insert(parts, "-" .. destroyed .. " carte(s)") end

        -- Cartes du territoire adjacent
        local hunt = db and (db.reward_hunt_cards or 0) or 0
        if hunt > 0 and pile then
            local adj = (pile == state.dino_piles[1]) and state.zones.territory_left or state.zones.territory_right
            local taken = 0
            for _ = 1, hunt do
                if #adj.cards > 0 then
                    local c = table.remove(adj.cards, #adj.cards)
                    c.face_up = false
                    engine.addCard(state.zones.discard, c)
                    taken = taken + 1
                end
            end
            engine.layoutZone(adj)
            if taken > 0 then table.insert(parts, "+" .. taken .. " carte(s) chasse") end
        end

        -- Déplacer le dino vaincu vers Trophées
        if pile then
            engine.removeCard(pile.zone, creature)
            creature.face_up = true
            engine.addCard(state.zones.trophies, creature)
            local new_top = #pile.zone.cards > 0 and pile.zone.cards[#pile.zone.cards] or nil
            if new_top then new_top.face_up = true end
        end

        -- Vérifier victoire
        local all_clear = true
        for _, p in ipairs(state.dino_piles) do
            if #p.zone.cards > 0 then all_clear = false; break end
        end
        if all_clear then
            state.game_over = true
            state.message   = "Tous les dinos vaincus ! Score : " .. state.score
        else
            state.message = table.concat(parts, " | ")
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

    -- End the turn
    solo.end_turn(state)

    -- Trigger RAGE animation if RAGE just fired
    if state.rage_active or (state.message and state.message:find("RAGE")) then
        state.rage_timer = 1.0
    end

    -- Reset cave selection
    state.pending_cave_card = nil


        --[[
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


    -- Victory check: are all dinos defeated?
    local all_defeated = true
    for _, pile in ipairs(state.dino_piles) do
        for _, card in ipairs(pile.zone.cards) do
            if not card.defeated then
                all_defeated = false
                break
            end
        end
        if not all_defeated then break end
    end

    if all_defeated then
        state.game_over = true
        state.message = "Toutes les creatures vaincues ! Score : " .. state.score
        return
    end
     --]]

     --[[ drawHand()
    state.message = "Tour " .. state.turn .. " — Glisse des cartes sur le Tableau, clique les créatures pour attaquer" 

    -- Deal a new hand
    engine.dealCards(state.zones.deck, state.zones.hand, config.hand_size)

    -- Reset totem activation for the new turn
    solo.activate_totems_start_of_turn(state)

    state.message = "Tour " .. state.turn .. " — Nouvelle main distribuee."
    --]]
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
