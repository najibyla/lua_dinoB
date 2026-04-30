-- zones.lua
-- Source de vérité des constantes de layout et des factories de zones Dinoblivion.
-- Canvas virtuel : 1280×800

local engine = require("engine")
local config = require("game_config")

local layout = {}

-- ── Constantes de layout ──────────────────────────────────────
layout.UPPER_Y = 220    -- y zones territoire / jungle
layout.UPPER_H = 155
layout.DINO_Y  = 50     -- y piles dinos et trophées
layout.DINO_H  = 145
layout.SEP_X   = 530    -- séparateur visuel L1 / L2
layout.RES_Y   = 382    -- y ligne ressources
layout.MSG_Y   = 424    -- y message tour
layout.TAB_Y   = 472    -- y zone Tableau
layout.TAB_H   = 132
layout.HAND_Y  = 472 + 132 + 18  -- TAB_Y + TAB_H + 18 = 622
layout.HAND_H  = 140
layout.SIDE_X  = 1020   -- x colonne droite
layout.ATK_Y   = 472 + 4         -- TAB_Y + 4 = 476
layout.BTN_Y   = 622 + 22        -- HAND_Y + 22 = 644
layout.BTN_W   = 130
layout.BTN_H   = 50

-- New zone positions
layout.CAVE_X = 1020
layout.CAVE_Y = 220
layout.CAVE_W = 110
layout.CAVE_H = 155

layout.TOTEM_X = 1140
layout.TOTEM_Y = 50
layout.TOTEM_W = 130
layout.TOTEM_H = 320

layout.EGG_X = 1020
layout.EGG_Y = 50
layout.EGG_W = 110
layout.EGG_H = 60

-- Zones ennemis RAGE — partent du centre (jungle) vers l'extérieur
layout.ENEMY_LEFT_X  = 10   -- bord gauche des ennemis côté gauche
layout.ENEMY_LEFT_W  = 310  -- largeur (10→320, juste avant territory_left)
layout.ENEMY_RIGHT_X = 720  -- bord gauche des ennemis côté droit
layout.ENEMY_RIGHT_W = 290  -- largeur (720→1010, juste après territory_right)

-- ── Factory zones de jeu ──────────────────────────────────────
-- Retourne la table state.zones complète avec toutes les zones engine.
function layout.createGameZones()
    local L = layout
    return {
        deck            = engine.newZone(30,      L.HAND_Y,  100, L.HAND_H,  "stack", "Deck"),
        hand            = engine.newZone(150,     L.HAND_Y,  700, L.HAND_H,  "fan",   "Main"),
        discard         = engine.newZone(870,     L.HAND_Y,  100, L.HAND_H,  "stack", "Défausse"),
        tableau         = engine.newZone(30,      L.TAB_Y,   940, L.TAB_H,   "row",   "Tableau"),
        territory_left  = engine.newZone(330, L.UPPER_Y, 120, L.UPPER_H, "stack", "Territoire"),
        jungle          = engine.newZone(460, L.UPPER_Y, 120, L.UPPER_H, "stack", "Jungle"),
        territory_right = engine.newZone(590, L.UPPER_Y, 120, L.UPPER_H, "stack", "Territoire"),
        --trophies        = engine.newZone(L.SIDE_X, L.DINO_Y, 230, 160,       "row",   "Trophées"),
        -- trophies        = engine.newZone(L.SIDE_X   , 410, 250, 60, "row", "Trophees"),
        trophies = engine.newZone(380, L.DINO_Y, 250, L.DINO_H, "row", "Trophees"),

        cave            = engine.newZone(L.CAVE_X, L.CAVE_Y, L.CAVE_W, L.CAVE_H, "stack", "Grotte"),
        totem           = engine.newZone(L.TOTEM_X, L.TOTEM_Y, L.TOTEM_W, L.TOTEM_H, "stack", "Totems"),
        egg_bank        = engine.newZone(L.EGG_X, L.EGG_Y, L.EGG_W, L.EGG_H, "stack", "Oeufs"),
    }
end

-- ── Factory piles dinos ───────────────────────────────────────
local function shuffle(pool)
    for i = #pool, 2, -1 do
        local j = love.math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
end

local function buildPile(pool, count, x, y, w, h, level)
    local zone = engine.newZone(x, y, w, h, "stack", "")
    for i = count, 1, -1 do
        local card = engine.newCreature(config.make_creature(pool[i]))
        card.face_up = false
        engine.addCard(zone, card)
    end
    if #zone.cards > 0 then
        zone.cards[#zone.cards].face_up = true
    end
    return { zone = zone, level = level }
end

-- Retourne state.dino_piles : { {zone, level=1}, {zone, level=2} }
function layout.createDinoPiles()
    local L = layout
    local l1_pool, l2_pool = {}, {}
    for _, db in ipairs(config.get_cards_of_type("dino_l1")) do
        for _ = 1, (db.qty or 1) do table.insert(l1_pool, db) end
    end
    for _, db in ipairs(config.get_cards_of_type("dino_l2")) do
        for _ = 1, (db.qty or 1) do table.insert(l2_pool, db) end
    end
    shuffle(l1_pool)
    shuffle(l2_pool)
    return {
        buildPile(l1_pool, config.solo_dino_left_count,  150, L.DINO_Y, 160, L.DINO_H, 1),
        buildPile(l2_pool, config.solo_dino_right_count, 700, L.DINO_Y, 160, L.DINO_H, 2),
    }
end

return layout
