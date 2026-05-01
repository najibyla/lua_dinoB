-- solo_rules.lua
-- Core solo game rules for Dinoblivion: activation, RAGE, scoring.

local engine = require("engine")
local config = require("game_config")
local card_powers = require("card_powers")

local solo = {}

-- All possible actions a clan card can perform when activated
solo.ACTIONS = {
    USE_POWER    = "use_power",
    SUPPORT      = "support_action",
    HUNT_LEFT    = "hunt_left",
    HUNT_RIGHT   = "hunt_right",
    ATTACK_DINO  = "attack_dino",
    FORM_AMI     = "form_ami",
    --ATTACK_ENEMY = "attack_enemy",
    --BUY_CARD = " buy_card",
}

function solo.get_available_actions(card, state)
    local actions = {}
    local db_entry = config.get_card(card.id)
    if not db_entry then return actions end

    -- Use Power: only if card has a card_power and is type clan
    if db_entry.card_power and db_entry.card_type == "clan" then
        table.insert(actions, { key = solo.ACTIONS.USE_POWER, label = "Pouvoir" })
    end

    -- Support Action: only if player has action cards in hand
    local has_action_in_hand = false
    for _, c in ipairs(state.zones.hand.cards) do
        if c.id ~= card.id then
            local cdb = config.get_card(c.id)
            if cdb and cdb.card_type == "action" then
                has_action_in_hand = true
                break
            end
        end
    end
    if has_action_in_hand then
        table.insert(actions, { key = solo.ACTIONS.SUPPORT, label = "Activer Action" })
    end

    -- Hunt: only if card has strength and jungle is not empty
    if (db_entry.strength or 0) > 0 and #state.zones.jungle.cards > 0 then
        table.insert(actions, { key = solo.ACTIONS.HUNT_LEFT, label = "Chasser Gauche" })
        table.insert(actions, { key = solo.ACTIONS.HUNT_RIGHT, label = "Chasser Droite" })
    end

    -- Attack Dino: available if force accumulated or dino tokens in reserve
    if state.strength > 0 or state.resources.dino_tokens.current > 0 then
        table.insert(actions, { key = solo.ACTIONS.ATTACK_DINO, label = "Attaquer" })
    end

    -- Form Ami pair: card must have ami_side, and a compatible partner must exist in hand
    if db_entry.ami_side then
        local a = db_entry.ami_side
        for _, c in ipairs(state.zones.hand.cards) do
            if c ~= card then
                local cdb = config.get_card(c.id)
                if cdb and cdb.ami_side then
                    local b = cdb.ami_side
                    local compatible = (a == "both" or b == "both" or a ~= b)
                    if compatible then
                        table.insert(actions, { key = solo.ACTIONS.FORM_AMI, label = "Former Paire (+1 Ami)" })
                        break
                    end
                end
            end
        end
    end

    return actions
end

function solo.activate_clan_card(card, state)
    -- Mark card as activated and move it from hand to tableau
    card.activated = true
    engine.removeCard(state.zones.hand, card)
    engine.addCard(state.zones.tableau, card)
    -- Add this card's strength to the player's accumulated force
    state.strength = state.strength + (card.strength or 0)
end

-- ─── Form Ami Pair ────────────────────────────────────────────────────────────

-- Returns compatible partner candidates from hand for a given initiator card
function solo.get_ami_partners(initiator, state)
    local db_a = config.get_card(initiator.id)
    if not db_a or not db_a.ami_side then return {} end
    local partners = {}
    for _, c in ipairs(state.zones.hand.cards) do
        if c ~= initiator then
            local db_b = config.get_card(c.id)
            if db_b and db_b.ami_side then
                local a, b = db_a.ami_side, db_b.ami_side
                if a == "both" or b == "both" or a ~= b then
                    table.insert(partners, c)
                end
            end
        end
    end
    return partners
end

-- Applies the pairing: activates both cards, +1 ami, bonuses for "both" cards
function solo.form_ami_pair(card1, card2, state)
    solo.activate_clan_card(card1, state)
    solo.activate_clan_card(card2, state)

    -- +1 Pion Ami (base reward)
    local ami = state.resources.ami
    ami.current = math.min(ami.current + 1, ami.max)

    local msg = "Paire formee ! +1 Ami"

    local db1 = config.get_card(card1.id)
    local db2 = config.get_card(card2.id)

    -- Bonus Gogo (both): +2 cartes piochées. 2 Gogo = +4.
    local gogo_count = 0
    if db1 and db1.id == "gogo" then gogo_count = gogo_count + 1 end
    if db2 and db2.id == "gogo" then gogo_count = gogo_count + 1 end
    if gogo_count > 0 then
        engine.dealCards(state.zones.deck, state.zones.hand, gogo_count * 2)
        msg = msg .. " +piochez " .. (gogo_count * 2) .. " (Gogo)"
    end

    -- Bonus Ayla (both): partenaire gauche → +1 oeuf, partenaire droite → +1 ami
    local function apply_ayla(ayla_card, partner_card)
        local pdb = config.get_card(partner_card.id)
        if not pdb then return end
        local ps = pdb.ami_side
        if ps == "left" then
            solo.gain_egg(state, 1)
            msg = msg .. " +1 oeuf (Ayla)"
        elseif ps == "right" then
            ami.current = math.min(ami.current + 1, ami.max)
            msg = msg .. " +1 Ami (Ayla)"
        end
    end

    if db1 and db1.id == "ayla" then apply_ayla(card1, card2) end
    if db2 and db2.id == "ayla" then apply_ayla(card2, card1) end

    return msg
end

-- ─── Hunt Logic ───────────────────────────────────────────────────────────────

function solo.hunt(card, territory, state)
    local db_entry = config.get_card(card.id)
    local force = db_entry and db_entry.strength or card.strength or 0
    if force <= 0 then return 0, "Pas de Force pour chasser." end

    local jungle = state.zones.jungle
    local food_gained = 0
    local revealed = 0

    -- Reveal N cards from jungle (N = card strength)
    for _ = 1, force do
        if #jungle.cards == 0 then break end
        local c = table.remove(jungle.cards, #jungle.cards)
        c.face_up = true

        local c_db = config.get_card(c.id)
        if c_db and c_db.type == "enemy" then
            -- Enemy during hunt: return to bottom of jungle, no effect
            c.face_up = false
            table.insert(jungle.cards, 1, c)
        else
            -- Normal card: place on the chosen territory
            engine.addCard(territory, c)
            food_gained = food_gained + (c_db and c_db.food_reward or 0)
            revealed = revealed + 1
        end
    end

    engine.layoutZone(jungle)
    -- Add any food gained to player resources
    if food_gained > 0 then
        local res = state.resources.food
        res.current = math.min(res.current + food_gained, res.max)
    end

    return revealed, food_gained
end

-- ─── RAGE Mechanic ────────────────────────────────────────────────────────────

function solo.check_rage(state)
    return #state.zones.deck.cards == 0
end

function solo.trigger_rage(state)
    local jungle = state.zones.jungle
    local results = { cards_revealed = 0, enemies_placed = 0, defeat = false }

    local sides = {
        { territory = state.zones.territory_left,  pile = state.dino_piles[1],
          enemies = state.enemies_left },
        { territory = state.zones.territory_right, pile = state.dino_piles[2],
          enemies = state.enemies_right },
    }

    for _, side in ipairs(sides) do
        local level = 3 -- default if pile is empty (volcano)
        if #side.pile.zone.cards > 0 then
            level = side.pile.level
        end

        local extra_for_enemies = #side.enemies
        local total_to_reveal = level + extra_for_enemies

        for _ = 1, total_to_reveal do
            if #jungle.cards == 0 then
                results.defeat = true
                return results
            end

            local c = table.remove(jungle.cards, #jungle.cards)
            c.face_up = true

            local c_db = config.get_card(c.id)
            if c_db and c_db.type == "enemy" then
                -- Enemy during RAGE: place on this side, reveal 1 more
                table.insert(side.enemies, c)
                results.enemies_placed = results.enemies_placed + 1

                -- Reveal 1 additional card for this enemy
                if #jungle.cards > 0 then
                    local extra = table.remove(jungle.cards, #jungle.cards)
                    extra.face_up = true
                    engine.addCard(side.territory, extra)
                    results.cards_revealed = results.cards_revealed + 1
                else
                    results.defeat = true
                    return results
                end
            else
                engine.addCard(side.territory, c)
                results.cards_revealed = results.cards_revealed + 1
            end
        end
    end

    engine.layoutZone(jungle)
    return results
end

function solo.recycle_discard(state)
    engine.moveAllCards(state.zones.discard, state.zones.deck)
    for _, c in ipairs(state.zones.deck.cards) do
        c.face_up = false
        c.activated = false
    end
    engine.shuffle(state.zones.deck)
end



-- ─── Egg Bank ─────────────────────────────────────────────────────────────────

function solo.init_egg_bank(state)
    state.egg_bank = {}
    -- Build pool: 12 vert (1pt), 8 rouge (2pt), 4 bleu (2pt indestructible)
    local pool = {}
    for _ = 1, 12 do table.insert(pool, { value = 1, color = "vert", indestructible = false }) end
    for _ = 1, 8 do table.insert(pool, { value = 2, color = "rouge", indestructible = false }) end
    for _ = 1, 4 do table.insert(pool, { value = 2, color = "bleu", indestructible = true }) end

    -- Shuffle
    for i = #pool, 2, -1 do
        local j = love.math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    -- Take 12 for solo
    for i = 1, math.min(12, #pool) do
        table.insert(state.egg_bank, pool[i])
    end

    state.eggs_collected = {}
end

function solo.gain_egg(state, count)
    count = count or 1
    for _ = 1, count do
        if #state.egg_bank == 0 then break end
        local egg = table.remove(state.egg_bank, 1)
        egg.revealed = true
        table.insert(state.eggs_collected, egg)

        -- Solo mechanic: egg value = cards to add under jungle from reserve
        if state.jungle_reserve then
            for _ = 1, egg.value do
                if #state.jungle_reserve > 0 then
                    local card_id = table.remove(state.jungle_reserve, 1)
                    local db_entry = config.get_card(card_id)
                    if db_entry then
                        local card = engine.newCard(card_id, config.make_card(db_entry))
                        card.face_up = false
                        table.insert(state.zones.jungle.cards, 1, card)
                    end
                end
            end
            engine.layoutZone(state.zones.jungle)
        end
    end
end

-- ─── Totem Activation ─────────────────────────────────────────────────────────

function solo.activate_totems_start_of_turn(state)
    for _, card in ipairs(state.zones.totem.cards) do
        card.activated = false
    end
end

function solo.activate_single_totem(card, state)
    if card.activated then return false, "Deja active ce tour." end
    card.activated = true

    local db_entry = config.get_card(card.id)
    if db_entry and db_entry.card_power then
        local power_fn = card_powers[db_entry.card_power]
        if power_fn then
            local gs = solo.build_power_state(state)
            local ok = power_fn(gs, card)
            solo.apply_power_state(gs, state)
            return ok, gs.message or ""
        end
    end
    return false, "Pas de pouvoir."
end


-- ─── Cave ─────────────────────────────────────────────────────────────────────

function solo.swap_cave(card_from_hand, state)
    -- Save existing cave card (if any)
    local old_cave = nil
    if #state.zones.cave.cards > 0 then
        old_cave = table.remove(state.zones.cave.cards, 1)
    end

    -- Move selected hand card into cave
    engine.removeCard(state.zones.hand, card_from_hand)
    engine.addCard(state.zones.cave, card_from_hand)

    -- Return old cave card to hand (if there was one)
    if old_cave then
        engine.addCard(state.zones.hand, old_cave)
    end

    engine.layoutZone(state.zones.cave)
    engine.layoutZone(state.zones.hand)
    return old_cave
end

-- ─── End-of-Game Scoring ──────────────────────────────────────────────────────

function solo.calculate_final_score(state)
    local score = { families = 0, totems = 0, dinos = 0, eggs = 0, total = 0 }

    -- 1. Collect all player cards from every zone
    local all_cards = {}
    local zones_to_check = { state.zones.deck, state.zones.discard, state.zones.hand,
                             state.zones.tableau, state.zones.totem, state.zones.cave }
    for _, zone in ipairs(zones_to_check) do
        for _, card in ipairs(zone.cards) do
            table.insert(all_cards, card)
        end
    end

    -- 2. Count ami families (pairs)
    local lefts = {}
    local rights = {}
    for _, card in ipairs(all_cards) do
        local db = config.get_card(card.id)
        if db then
            local side = db.ami_side
            if side == "left" or side == "both" then
                table.insert(lefts, card)
            end
            if side == "right" or side == "both" then
                table.insert(rights, card)
            end
        end
    end

    -- Match pairs (greedy): each left pairs with one right (no self-pairing for both)
    local used_rights = {}
    for _, l in ipairs(lefts) do
        for ri, r in ipairs(rights) do
            if not used_rights[ri] and l ~= r then
                used_rights[ri] = true
                score.families = score.families + 1
                break
            end
        end
    end

    -- 3. Count totem symbols (totem zone only)
    for _, card in ipairs(state.zones.totem.cards) do
        local db = config.get_card(card.id)
        if db and db.has_totem then
            score.totems = score.totems + (db.totem_count or 1)
        end
    end

    -- 4. Count defeated dinosaurs
    score.dinos = #state.zones.trophies.cards

    -- 5. Sum egg values
    for _, egg in ipairs(state.eggs_collected or {}) do
        score.eggs = score.eggs + egg.value
    end

    -- Total
    score.total = (score.families * 2) + (score.totems * 1) + (score.dinos * 1) + score.eggs

    return score
end

-- ─── Power State Bridge ───────────────────────────────────────────────────────
-- Translates between main.lua state and card_powers.lua gs format

function solo.build_power_state(state)
    return {
        food = state.resources.food.current,
        ami = state.resources.ami.current,
        dino_tokens = state.resources.dino_tokens.current,
        attack_force = state.strength,
        message = "",
        pending_draw = 0,
        pending_choice = nil,
        pending_destroy = nil,
        pending_egg_gain = 0,
        extra_actions = 0,
        in_play = {},
        totems = state.zones.totem.cards,
    }
end

function solo.apply_power_state(gs, state)
    state.resources.food.current = math.min(gs.food, state.resources.food.max)
    state.resources.ami.current = math.min(gs.ami, state.resources.ami.max)
    state.resources.dino_tokens.current = math.min(gs.dino_tokens, state.resources.dino_tokens.max)
    state.strength = gs.attack_force
    state.message = gs.message or state.message

    if (gs.pending_draw or 0) > 0 then
        engine.dealCards(state.zones.deck, state.zones.hand, gs.pending_draw)
    end

    if (gs.pending_egg_gain or 0) > 0 then
        solo.gain_egg(state, gs.pending_egg_gain)
    end
end



-- ─── End Turn (partial) ───────────────────────────────────────────────────────

--[[ function solo.end_turn(state)
    -- Move remaining hand cards to discard
    engine.moveAllCards(state.zones.hand, state.zones.discard)

    -- Tableau cards go to discard (totems already in totem zone)
    for _, card in ipairs(state.zones.tableau.cards) do
        card.activated = false
        table.insert(state.zones.discard.cards, card)
    end
    state.zones.tableau.cards = {}
    engine.layoutZone(state.zones.tableau)
    engine.layoutZone(state.zones.discard)

    -- Reset totem activation for next turn (cards stay in zone)
    for _, card in ipairs(state.zones.totem.cards) do
        card.activated = false
    end

    state.strength = 0
    state.turn = state.turn + 1
end --]]

-- ─── End Turn ─────────────────────────────────────────────────────────────────

function solo.end_turn(state)
    -- Move hand to discard
    engine.moveAllCards(state.zones.hand, state.zones.discard)

    -- Tableau: all cards go to discard (totems already in totem zone)
    for _, card in ipairs(state.zones.tableau.cards) do
        card.activated = false
        table.insert(state.zones.discard.cards, card)
    end
    state.zones.tableau.cards = {}
    engine.layoutZone(state.zones.tableau)
    engine.layoutZone(state.zones.discard)

    -- Reset totem activation for next turn
    for _, card in ipairs(state.zones.totem.cards) do
        card.activated = false
    end

    state.strength = 0
    state.turn = state.turn + 1

    -- Check victory: all dino piles empty
    local all_clear = true
    for _, p in ipairs(state.dino_piles) do
        if #p.zone.cards > 0 then all_clear = false; break end
    end

--[[     if all_clear then
        state.game_over = true
        state.victory = true
        state.message = "Victoire !"
        return
    end --]]
    
    if all_clear then
        state.game_over = true
        state.victory = true
        state.final_score = solo.calculate_final_score(state)
        state.message = "Victoire ! Score : " .. state.final_score.total
        return
    end
    
    
    solo.start_new_turn(state)
end

--[[ function solo.start_new_turn(state)
    -- Check RAGE before drawing
    if solo.check_rage(state) then
        state.rage_active = true
        local results = solo.trigger_rage(state)

--[[         if results.defeat then
            state.game_over = true
            state.victory = false
            state.message = "Defaite ! Le volcan entre en eruption !"
            return
        end 
--[[ 
        if results.defeat then
            state.game_over = true
            state.victory = false
            state.final_score = solo.calculate_final_score(state)
            state.message = "Defaite ! Le volcan entre en eruption !"
            return
        end

        state.message = "RAGE ! " .. results.cards_revealed .. " carte(s) revelees"
        if results.enemies_placed > 0 then
            state.message = state.message .. ", " .. results.enemies_placed .. " ennemi(s) !"
        end
        state.rage_timer = 1.0
        -- Recycle discard into deck APRÈS la RAGE
        solo.recycle_discard(state)  
    end

    -- Recycle seulement si le deck est vide (après RAGE ou en cas d'urgence)
    
    if #state.zones.deck.cards == 0 then
        solo .recycle_discard(state)
    end 
    
    -- Draw up to 4 (PAS de recycle ici !)
    local hand = state.zones.hand
    local deck = state.zones.deck
    local needed = config.hand_size - #hand.cards
--[[     if needed > 0 then
        if #deck.cards < needed then
            solo.recycle_discard(state)
        end
        engine.dealCards(deck, hand, needed)
    end 
    --]]--[[ 
     if needed > 0 then
         engine.dealCards(deck, hand , math.min(needed, # deck.cards)) 
     end
    
    -- Activate totems
    solo.activate_totems_start_of_turn(state)

    state.rage_active = false
    if not (state.message and state.message:find("RAGE")) then
        state.message = "Tour " .. state.turn .. " — Cliquez une carte Clan pour agir"
    end
end
--]]

function solo.start_new_turn(state)
    local deck = state.zones.deck
    local hand = state.zones.hand
    local needed = config.hand_size

    -- Check RAGE: not enough cards in deck for a full hand
    if #deck.cards < needed then
        state.rage_active = true
        local results = solo.trigger_rage(state)

        if results.defeat then
            state.game_over = true
            state.victory = false
            state.message = "Defaite ! Le volcan entre en eruption !"
            return
        end

        state.message = "RAGE ! " .. results.cards_revealed .. " carte(s) revelees"
        if results.enemies_placed > 0 then
            state.message = state.message .. ", " .. results.enemies_placed .. " ennemi(s) !"
        end

        state.rage_timer = 1.0

        state.shake_timer = 1.0
        state.shake_intensity = 8

    end
--[[ 
    -- Step 1: Take whatever remains in the deck into hand
    local remaining = #deck.cards
    if remaining > 0 then
        engine.dealCards(deck, hand, remaining)
    end

    -- Step 2: Recycle discard into deck
    if #deck.cards == 0 then
        solo.recycle_discard(state)
    end

    -- Step 3: Deal remaining cards to reach hand_size
    local still_needed = needed - #hand.cards
    if still_needed > 0 then
        engine.dealCards(deck, hand, math.min(still_needed, #deck.cards))
    end --]]

    -- Deal from deck (only up to what we need)
    local to_deal = math.min(needed, #deck.cards)
    if to_deal > 0 then
        engine.dealCards(deck, hand, to_deal)
    end

    -- If hand still not full and deck is empty, recycle and deal more
    local still_needed = needed - #hand.cards
    if still_needed > 0 and #deck.cards == 0 then
        solo.recycle_discard(state)
        engine.dealCards(deck, hand, math.min(still_needed, #deck.cards))
    end

    -- Activate totems
    solo.activate_totems_start_of_turn(state)

    state.rage_active = false
    if not (state.message and state.message:find("RAGE")) then
        state.message = "Tour " .. state.turn .. " — Cliquez une carte Clan pour agir"
    end
end


function solo.defeat_enemy(enemy_card, side, state)
    local db = config.get_card(enemy_card.id)
    if not db then return false, "Ennemi inconnu." end

    local cost = config.enemy_costs[enemy_card.id]
    if not cost then return false, "Pas de cout defini." end

    -- Check force requirement
    if state.strength < cost.force then
        return false, "Force insuffisante (" .. state.strength .. "/" .. cost.force .. ")."
    end

    -- Check and spend the specific resource cost
    if cost.resource == "dino_tokens" then
        if state.resources.dino_tokens.current < cost.amount then
            return false, "Pas assez de jetons Dino."
        end
        state.resources.dino_tokens.current = state.resources.dino_tokens.current - cost.amount
    elseif cost.resource == "food" then
        if state.resources.food.current < cost.amount then
            return false, "Pas assez de Nourriture."
        end
        state.resources.food.current = state.resources.food.current - cost.amount
    elseif cost.resource == "ami" then
        if state.resources.ami.current < cost.amount then
            return false, "Pas assez d Ami."
        end
        state.resources.ami.current = state.resources.ami.current - cost.amount
    elseif cost.resource == "destroy_card" then
        -- Cultist: must destroy a card currently in play
        if #state.zones.tableau.cards == 0 then
            return false, "Aucune carte en jeu a detruire."
        end
        table.remove(state.zones.tableau.cards)
        engine.layoutZone(state.zones.tableau)
    end

    -- Spend force
    state.strength = state.strength - cost.force

    -- Return enemy to bottom of jungle and reshuffle
    enemy_card.face_up = false
    table.insert(state.zones.jungle.cards, 1, enemy_card)
    engine.shuffle(state.zones.jungle)
    engine.layoutZone(state.zones.jungle)

    -- Remove from the correct side's enemy array
    local enemies = (side == "left") and state.enemies_left or state.enemies_right
    for i, e in ipairs(enemies) do
        if e == enemy_card then
            table.remove(enemies, i)
            break
        end
    end
    
    -- Reward: gain an egg
    solo.gain_egg(state, 1)
    
    return true, "Ennemi vaincu ! +1 oeuf"
end


---
--[[ function solo.defeat_enemy(enemy, side, state)
    -- Check if player has enough strength to defeat this enemy
    local db = config.get_card(enemy.id)
    local enemy_hp = db and db.hp or enemy.hp or 1

    if state.strength < enemy_hp then
        return "Pas assez de force ! (" .. state.strength .. "/" .. enemy_hp .. ")"
    end

    -- Spend strength
    state.strength = state.strength - enemy_hp

    -- Remove enemy from the side's array
    local enemies = (side == "left") and state.enemies_left or state.enemies_right
    for i, e in ipairs(enemies) do
        if e == enemy then
            table.remove(enemies, i)
            break
        end
    end

    -- Reward: gain an egg
    solo.gain_egg(state, 1)

    return "Ennemi vaincu ! -" .. enemy_hp .. " force, +1 oeuf"
end
 --]]


 

return solo