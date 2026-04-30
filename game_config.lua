local card_db = require("card_db")

local config = {}

config.title     = "Dinoblivion"
config.hand_size = 4   -- On pioche 4 cartes à la fin de chaque tour

-- ─────────────────────────────────────────────────────────────────────────────
-- Source de vérité des cartes
-- ─────────────────────────────────────────────────────────────────────────────
config.card_db = card_db

-- ─────────────────────────────────────────────────────────────────────────────
-- Ressources du joueur
-- ─────────────────────────────────────────────────────────────────────────────
config.resources = {
    { name = "Nourriture",  key = "food",        icon = "🍖", color = {0.85, 0.65, 0.13}, max = 12, start = 2 },
    { name = "Jetons Dino", key = "dino_tokens", icon = "🦕", color = {0.18, 0.80, 0.44}, max = 12, start = 6 },
    { name = "Pions Ami",   key = "ami",         icon = "🤝", color = {0.91, 0.30, 0.24}, max = 12, start = 2 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Decks de départ — IDs selon card_db (qty respectée à la main)
-- ─────────────────────────────────────────────────────────────────────────────
config.starter_deck = {
    sun  = {
        "ami_sun",
        "dinoblivion_sun",
        "fructam_sun",
        "bananar_sun",  "bananar_sun",  "bananar_sun",
        "explorar_sun", "explorar_sun", "explorar_sun",
    },
    moon = {
        "ami_moon",
        "dinoblivion_moon",
        "fructam_moon",
        "bananar_moon",  "bananar_moon",  "bananar_moon",
        "explorar_moon", "explorar_moon", "explorar_moon",
    },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Chefs de Clan (1 tiré au hasard en mode Solo)
-- ─────────────────────────────────────────────────────────────────────────────
config.chiefs = {
    "chief_bobor",
    "chief_cornio",
    "chief_magda",
    "chief_sillia",
    "chief_slayer",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Niveaux de difficulté (Solo) — nb de cartes Jungle tirées au hasard
-- Les 4 cartes Ennemi sont ajoutées par-dessus
-- ─────────────────────────────────────────────────────────────────────────────
config.difficulties = {
    { name = "Cueilleur", jungle_size = 40 },
    { name = "Chasseur",  jungle_size = 36 },
    { name = "Guerrier",  jungle_size = 32 },
    { name = "Chef",      jungle_size = 28 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Plateau Solo — disposition des dinos
-- ─────────────────────────────────────────────────────────────────────────────
config.solo_dino_left_count  = 4   -- cartes L1 à gauche (face cachée, on révèle le dessus)
config.solo_dino_right_count = 3   -- cartes L2 à droite

-- ─────────────────────────────────────────────────────────────────────────────
-- Œufs — banque Solo (12 oeufs face cachée, révélés à chaque gain)
-- En Solo : valeur de l'oeuf révélé = nb de cartes à ajouter SOUS la Jungle
-- ─────────────────────────────────────────────────────────────────────────────
config.eggs_bank_solo = 12

config.egg_pool = {
    { value = 1, qty = 12, color = {0.2, 0.8, 0.2},  label = "Vert (1pt)"          },
    { value = 2, qty = 8,  color = {0.9, 0.2, 0.2},  label = "Rouge (2pts)"         },
    { value = 2, qty = 4,  color = {0.2, 0.4, 0.9},  label = "Bleu indestructible"  },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Décompte final — Points de Victoire
-- ─────────────────────────────────────────────────────────────────────────────
config.vp = {
    complete_family = 2,   -- chaque paire de famille complète
    totem_symbol    = 1,   -- chaque symbole Totem en jeu (carte Totem = 3 symboles)
    dino_defeated   = 1,   -- chaque dinosaure vaincu
    -- célibitaires (cartes sans paire) = 0
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Cartes Ennemis (Solo uniquement, mélangées dans la Jungle au setup)
-- ─────────────────────────────────────────────────────────────────────────────
config.enemy_ids = { "piranar", "coconar", "cannibalar", "cultist" }

-- Coûts d'élimination par ennemi (Force requise + ressource supplémentaire)
config.enemy_costs = {
    piranar    = { force = 1, resource = "dino_tokens",  amount = 1 },
    coconar    = { force = 2, resource = "food",         amount = 2 },
    cannibalar = { force = 3, resource = "ami",          amount = 1 },
    cultist    = { force = 4, resource = "destroy_card", amount = 1 },
}

-- ─────────────────────────────────────────────────────────────────────────────
-- API d'accès aux cartes (card_db reste interne à ce module)
-- ─────────────────────────────────────────────────────────────────────────────
function config.get_card(id)          return card_db.by_id[id] end
function config.get_cards_of_type(t)  return card_db.by_type[t] or {} end
function config.deck_ids(t)           return card_db.expanded_list({ type = t }) end

-- Convertit une entrée card_db en définition compatible avec engine.newCard
function config.make_card(db_entry)
    local cost, cost_type = 0, ""
    if (db_entry.cost_food or 0) > 0 then
        cost, cost_type = db_entry.cost_food, "food"
    elseif (db_entry.cost_ami or 0) > 0 then
        cost, cost_type = db_entry.cost_ami, "ami"
    end
    return {
        name        = db_entry.name,
        type        = db_entry.card_type or "clan",
        strength    = db_entry.strength   or 0,
        cost        = cost,
        cost_type   = cost_type,
        food_gain   = db_entry.food_reward or 0,
        meeple_gain = 0,
        power_gain  = 0,
        persistent  = db_entry.has_totem  or false,
        description = (db_entry.card_power or ""):gsub("_", " "),
        color       = (db_entry.card_type == "action")
                      and {0.55, 0.36, 0.17}
                      or  {0.45, 0.45, 0.55},
    }
end

-- Convertit une entrée dino card_db en définition compatible avec engine.newCreature
function config.make_creature(db_entry)
    return {
        id          = db_entry.id,
        name        = db_entry.name,
        hp          = db_entry.strength   or 5,
        points      = config.vp.dino_defeated,
        reward_food = db_entry.reward_food or 0,
        color       = (db_entry.type == "dino_l2")
                      and {0.83, 0.18, 0.18}
                      or  {0.30, 0.69, 0.31},
    }
end

return config
