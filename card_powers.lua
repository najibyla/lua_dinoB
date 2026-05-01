-- card_powers.lua
-- Dispatch des pouvoirs de cartes pour le mode Solo Dinoblivion.
--
-- Chaque fonction reçoit (gs) = game state (solo_state) et (card) = la carte utilisée.
-- Les fonctions modifient gs directement.
-- Pour les effets complexes (pioche, choix), elles posent des flags sur gs :
--   gs.pending_draw   = N  → le moteur pioche N cartes en fin d'action
--   gs.pending_choice = {label, options={{label, fn}, ...}} → affiche un choix à l'écran
--   gs.pending_artis  = true → piocher 1 carte après la prochaine carte Action jouée
--   gs.extra_actions  = N  → cartes Action supplémentaires jouables ce tour

local powers = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Pouvoirs implémentés
-- ─────────────────────────────────────────────────────────────────────────────

-- Dinoblivion (clan de départ) : détruire X jetons Dino → X×2 Force (max 6 tokens = 12 Force)
powers["dinoblivion_dino_tokens"] = function(gs, card)
    if gs.dino_tokens <= 0 then
        gs.message = "Aucun jeton Dino à détruire."
        return false
    end
    local max_tokens = math.min(gs.dino_tokens, 6)
    gs.pending_choice = {
        label = "Dinoblivion : combien de jetons Dino détruire ? (max " .. max_tokens .. ")",
        options = {}
    }
    for n = 1, max_tokens do
        local tokens = n
        table.insert(gs.pending_choice.options, {
            label = "Détruire " .. tokens .. " → +" .. (tokens*2) .. " Force",
            fn    = function()
                gs.dino_tokens    = gs.dino_tokens - tokens
                gs.attack_force   = gs.attack_force + tokens * 2
                gs.message        = "Dinoblivion : -" .. tokens .. " Dino → +" .. (tokens*2) .. " Force !"
                gs.pending_choice = nil
            end
        })
    end
    return true
end

-- Artis : joue une carte Action, puis pioche 1 carte
powers["play_action_draw"] = function(gs, card)
    gs.extra_actions  = (gs.extra_actions or 0) + 1
    gs.pending_artis  = true
    gs.message        = "Artis : jouez une carte Action, vous piochez 1 carte ensuite."
    return true
end

-- Yak : +2 Nourriture
powers["yak_gain_food"] = function(gs, card)
    gs.food    = gs.food + 2
    gs.message = "Yak : +2 Nourriture."
    return true
end

-- Fiyar : piochez 2 cartes
powers["fiyar_draw"] = function(gs, card)
    gs.pending_draw = (gs.pending_draw or 0) + 2
    gs.message      = "Fiyar : piochez 2 cartes."
    return true
end

-- Mammotar : gagne Nourriture = Force de la carte
powers["mammotar_food_force"] = function(gs, card)
    gs.food    = gs.food + card.strength
    gs.message = "Mammotar : +" .. card.strength .. " Nourriture."
    return true
end

-- Mom : Force = nb de cartes Clan en jeu (elle-même incluse)
powers["mom_strength_equals_clans"] = function(gs, card)
    local count = 0
    for _, entry in ipairs(gs.in_play) do
        if entry.card and entry.card.card_type == "clan" then count = count + 1 end
    end
    gs.attack_force = gs.attack_force + count
    gs.message      = "Mom : +" .. count .. " Force (" .. count .. " Clan en jeu)."
    return true
end

-- Protectar : Force = nb de symboles Totem sur cartes brunes en jeu
powers["protectar_strength_totems"] = function(gs, card)
    local total = 0
    for _, t in ipairs(gs.totems) do
        total = total + (t.totem_count or 1)
    end
    for _, entry in ipairs(gs.in_play) do
        if entry.card and entry.card.has_totem then
            total = total + (entry.card.totem_count or 1)
        end
    end
    gs.attack_force = gs.attack_force + total
    gs.message      = "Protectar : +" .. total .. " Force (symboles Totem)."
    return true
end

-- Shaman : gagne 1 œuf si ≥ 4 symboles Totem en jeu
powers["shaman_egg_if_4_totems"] = function(gs, card)
    local total = 0
    for _, t in ipairs(gs.totems) do total = total + (t.totem_count or 1) end
    for _, entry in ipairs(gs.in_play) do
        if entry.card and entry.card.has_totem then
            total = total + (entry.card.totem_count or 1)
        end
    end
    if total >= 4 then
        gs.pending_egg_gain = (gs.pending_egg_gain or 0) + 1
        gs.message = "Shaman : vous gagnez 1 Œuf ! (" .. total .. " Totem(s) en jeu)"
    else
        gs.message = "Shaman : il faut 4 symboles Totem (vous en avez " .. total .. ")."
    end
    return true
end

-- Rotam : +5 Force pour ce combat
powers["rotam_force_5"] = function(gs, card)
    gs.attack_force = gs.attack_force + 5
    gs.message      = "Rotam : +5 Force !"
    return true
end

-- Workar : joue 2 cartes Action supplémentaires ce tour
powers["workar_play_2_actions"] = function(gs, card)
    gs.extra_actions = (gs.extra_actions or 0) + 2
    gs.message       = "Workar : +2 cartes Action jouables ce tour."
    return true
end

-- Hut (Totem) : se réactive chaque tour → +1 Pion Ami
powers["hut_gain_ami"] = function(gs, card)
    gs.ami     = gs.ami + 1
    gs.message = "Hut : +1 Pion Ami."
    return true
end

-- Dino Farm (Totem) : choix — +2 Nourriture OU piochez 2 cartes
powers["dino_farm_choice"] = function(gs, card)
    gs.pending_choice = {
        label = "Dino Farm : choisissez un bonus",
        options = {
            { label = "+2 Nourriture", fn = function()
                gs.food = gs.food + 2
                gs.message = "Dino Farm : +2 Nourriture."
                gs.pending_choice = nil
            end },
            { label = "Piochez 2 cartes", fn = function()
                gs.pending_draw = (gs.pending_draw or 0) + 2
                gs.message = "Dino Farm : piochez 2 cartes."
                gs.pending_choice = nil
            end },
        }
    }
    return true
end

-- Monki : joue 1 carte Action supplémentaire
powers["monki_play_action"] = function(gs, card)
    gs.extra_actions = (gs.extra_actions or 0) + 1
    gs.message       = "Monki : +1 carte Action jouable."
    return true
end

-- Banana Boost (unique) : +4 Nourriture
powers["banana_boost_gain_food"] = function(gs, card)
    gs.food    = gs.food + 4
    gs.message = "Banana Boost : +4 Nourriture !"
    return true
end

-- Capturar : +1 Jeton Dino
powers["capturar_gain_dino"] = function(gs, card)
    gs.dino_tokens = gs.dino_tokens + 1
    gs.message     = "Capturar : +1 Jeton Dino."
    return true
end

-- Gilir : +1 Jeton Dino
powers["gilir_gain_dino"] = function(gs, card)
    gs.dino_tokens = gs.dino_tokens + 1
    gs.message     = "Gilir : +1 Jeton Dino."
    return true
end

-- Krafdinar : +1 Jeton Dino
powers["krafdinar_gain_dino"] = function(gs, card)
    gs.dino_tokens = gs.dino_tokens + 1
    gs.message     = "Kraf Dinar : +1 Jeton Dino."
    return true
end

-- Zazza (unique) : détruire 2 Pions Ami → +8 Force
powers["zazza_destroy_ami_for_force"] = function(gs, card)
    if gs.ami < 2 then
        gs.message = "Zazza : il vous faut 2 Pions Ami (vous en avez " .. gs.ami .. ")."
        return false
    end
    gs.ami          = gs.ami - 2
    gs.attack_force = gs.attack_force + 8
    gs.message      = "Zazza : -2 Ami → +8 Force !"
    return true
end

-- Neandertar : sans effet en mode Solo
powers["destroy_opponent_egg"] = function(gs, card)
    gs.message = "Neandertar : sans effet en mode Solo."
    return true
end

-- Totem (carte) : ne lance pas d'action, vaut 3 VP
powers["totem_no_action"] = function(gs, card)
    gs.message = "Totem : posé en jeu permanent (3 VP en fin de partie)."
    return true
end

-- Tigar (Totem) : +1 Force pour chasse/attaque ce tour
powers["tigar_attack_bonus"] = function(gs, card)
    gs.attack_force = gs.attack_force + 1
    gs.message      = "Tigar : +1 Force."
    return true
end

-- Fructam : choix — +1 Nourriture OU +1 Jeton Dino
powers["fructam_choice"] = function(gs, card)
    gs.pending_choice = {
        label = "Fructam : choisissez un bonus",
        options = {
            { label = "+1 Nourriture", fn = function()
                gs.food = gs.food + 1
                gs.message = "Fructam : +1 Nourriture."
                gs.pending_choice = nil
            end },
            { label = "+1 Jeton Dino", fn = function()
                gs.dino_tokens = gs.dino_tokens + 1
                gs.message = "Fructam : +1 Jeton Dino."
                gs.pending_choice = nil
            end },
        }
    }
    return true
end

-- ── Chefs de clan ────────────────────────────────────────────────────────────

-- Bobor : détruire 1 carte → +2 Pions Ami
powers["bobor_destroy_for_ami"] = function(gs, card)
    gs.pending_destroy = { reward = { ami=2, food=0, dino_tokens=0, force=0 },
                           msg = "Bobor : -1 carte → +2 Pions Ami." }
    gs.message = "Bobor : choisissez une carte à détruire."
    return true
end

-- Cornio : détruire 1 carte → +3 Nourriture
powers["cornio_destroy_for_food"] = function(gs, card)
    gs.pending_destroy = { reward = { ami=0, food=3, dino_tokens=0, force=0 },
                           msg = "Cornio : -1 carte → +3 Nourriture." }
    gs.message = "Cornio : choisissez une carte à détruire."
    return true
end

-- Magda : détruire 1 carte → +2 Jetons Dino
powers["magda_destroy_for_dino"] = function(gs, card)
    gs.pending_destroy = { reward = { ami=0, food=0, dino_tokens=2, force=0 },
                           msg = "Magda : -1 carte → +2 Jetons Dino." }
    gs.message = "Magda : choisissez une carte à détruire."
    return true
end

-- Sillia : détruire 1 carte → +1 Jeton Dino +1 Nourriture
powers["sillia_destroy_for_dino_food"] = function(gs, card)
    gs.pending_destroy = { reward = { ami=0, food=1, dino_tokens=1, force=0 },
                           msg = "Sillia : -1 carte → +1 Dino +1 Nourriture." }
    gs.message = "Sillia : choisissez une carte à détruire."
    return true
end

-- Slayar : détruire 1 carte → +4 Force
powers["slayar_destroy_for_force"] = function(gs, card)
    gs.pending_destroy = { reward = { ami=0, food=0, dino_tokens=0, force=4 },
                           msg = "Slayar : -1 carte → +4 Force." }
    gs.message = "Slayar : choisissez une carte à détruire."
    return true
end

-- Ami : +1 Pion Ami
powers["ami_gain_ami"] = function(gs, card)
    gs.ami     = gs.ami + 1
    gs.message = "Ami : +1 Pion Ami."
    return true
end

-- Bananar : +1 Nourriture
powers["bananar_gain_food"] = function(gs, card)
    gs.food    = gs.food + 1
    gs.message = "Bananar : +1 Nourriture."
    return true
end

-- ── Pouvoirs non encore implémentés (stubs) ──────────────────────────────────

powers["amazar_dino_food"]           = function(gs) gs.message = "[Amazar] TODO: pouvoir à implémenter."; return false end
powers["ayla_ami_and_egg"]           = function(gs) gs.message = "[Ayla] TODO: pouvoir à implémenter."; return false end
powers["dino_ridar_force_eggs"]      = function(gs) gs.message = "[Dino Ridar] TODO: pouvoir à implémenter."; return false end
powers["dominatar_dino_force"]       = function(gs) gs.message = "[Dominatar] TODO: pouvoir à implémenter."; return false end
powers["patrak_food_force"]          = function(gs) gs.message = "[Patrak] TODO: pouvoir à implémenter."; return false end
powers["gogo_ami_draw"]              = function(gs) gs.message = "[Gogo] TODO: pouvoir à implémenter."; return false end
powers["dino_tool_destroy_dino_draw"]= function(gs) gs.message = "[Dino Tool] TODO: pouvoir à implémenter."; return false end
powers["stellar_resources"]          = function(gs) gs.message = "[Stellar] TODO: pouvoir à implémenter."; return false end
powers["yolo_dino_draw"]             = function(gs) gs.message = "[Yolo] TODO: pouvoir à implémenter."; return false end
powers["troc_exchange"]              = function(gs) gs.message = "[Troc] TODO: pouvoir à implémenter."; return false end

-- ── Ennemis (coûts vérifiés en dehors de ce fichier dans la logique d'attaque) ──

powers["enemy_piranar"]    = function(gs) return true end  -- 1 Force + 1 Dino
powers["enemy_coconar"]    = function(gs) return true end  -- 2 Force + 2 Food
powers["enemy_cannibalar"] = function(gs) return true end  -- 3 Force + 1 Ami
powers["enemy_cultist"]    = function(gs) return true end  -- 4 Force + destroy 1

-- ─────────────────────────────────────────────────────────────────────────────
-- Fallback pour les clés manquantes
-- ─────────────────────────────────────────────────────────────────────────────

setmetatable(powers, {
    __index = function(_, key)
        return function(gs, card)
            gs.message = "[" .. (card and card.name or key) .. "] Pouvoir non implémenté."
            return false
        end
    end
})

return powers
