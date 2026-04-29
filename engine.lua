local engine = {}

-- Standard card dimensions used for rendering and hit detection
engine.CARD_W   = 90
engine.CARD_H   = 130
engine.CARD_PAD = 8    -- padding horizontal intérieur des cartes

-- Fonts — initialisés depuis love.load via engine.initFonts()
engine.fontDefault = nil
engine.fontEmoji   = nil

function engine.initFonts(defaultSize, emojiSize)
    engine.fontDefault = love.graphics.newFont(
        "assets/fonts/NotoSans-Regular.ttf", defaultSize or 14)
    engine.fontBold    = love.graphics.newFont(
        "assets/fonts/NotoSans-Bold.ttf", defaultSize or 14)
    engine.fontEmoji   = love.graphics.newFont(
        "assets/fonts/NotoEmoji-Regular.ttf", emojiSize or 14)
    love.graphics.setFont(engine.fontDefault)
end

function engine.useEmoji()   if engine.fontEmoji   then love.graphics.setFont(engine.fontEmoji)   end end
function engine.useDefault() if engine.fontDefault then love.graphics.setFont(engine.fontDefault) end end

-- Create a card instance from a definition table
function engine.newCard(id, def)
    return {
        id = id,
        name = def.name or id,
        type = def.type or "tribe",
        strength = def.strength or 0,
        cost = def.cost or 0,
        cost_type = def.cost_type or "",
        food_gain = def.food_gain or 0,
        meeple_gain = def.meeple_gain or 0,
        power_gain = def.power_gain or 0,
        persistent = def.persistent or false,
        description = def.description or "",
        color = def.color or {0.5, 0.5, 0.5},
        x = 0, y = 0,
        face_up = true,
    }
end

-- Create a creature instance from a creature definition
function engine.newCreature(def)
    return {
        id = def.id,
        name = def.name,
        type = "creature",
        hp = def.hp,
        points = def.points,
        reward_food = def.reward_food or 0,
        color = def.color or {0.5, 0.5, 0.5},
        x = 0, y = 0,
        defeated = false,
    }
end

-- Create a zone that holds and arranges cards
function engine.newZone(x, y, w, h, layout, label)
    return {
        x = x, y = y, w = w, h = h,
        layout = layout or "row",
        label = label or "",
        cards = {},
    }
end

-- Insert a card into a zone and recalculate positions
function engine.addCard(zone, card)
    table.insert(zone.cards, card)
    engine.layoutZone(zone)
end

-- Remove a specific card from a zone
function engine.removeCard(zone, card)
    for i, c in ipairs(zone.cards) do
        if c == card then
            table.remove(zone.cards, i)
            engine.layoutZone(zone)
            return true
        end
    end
    return false
end

-- Position all cards in a zone based on its layout type
function engine.layoutZone(zone)
    local count = #zone.cards
    if count == 0 then return end
    local W, H = engine.CARD_W, engine.CARD_H
    if zone.layout == "stack" then
        -- Stack: center all cards on the same spot
        for _, card in ipairs(zone.cards) do
            card.x = zone.x + (zone.w - W) / 2
            card.y = zone.y + (zone.h - H) / 2
        end
    else
        -- Fan/Row: spread cards evenly with smart spacing
        local max_spacing = W + 10
        local spacing = math.min(max_spacing, (zone.w - W) / math.max(count - 1, 1))
        local total = (count - 1) * spacing + W
        local sx = zone.x + (zone.w - total) / 2
        for i, card in ipairs(zone.cards) do
            card.x = sx + (i - 1) * spacing
            card.y = zone.y + (zone.h - H) / 2
        end
    end
end

-- Fisher-Yates shuffle to randomize cards in a zone
function engine.shuffle(zone)
    local cards = zone.cards
    for i = #cards, 2, -1 do
        local j = love.math.random(1, i)
        cards[i], cards[j] = cards[j], cards[i]
    end
    engine.layoutZone(zone)
end

-- Deal a number of cards from one zone to another
function engine.dealCards(from, to, count)
    local dealt = 0
    for i = 1, count do
        if #from.cards == 0 then break end
        local card = table.remove(from.cards, #from.cards)
        card.face_up = true
        table.insert(to.cards, card)
        dealt = dealt + 1
    end
    engine.layoutZone(from)
    engine.layoutZone(to)
    return dealt
end

-- Move every card from one zone to another
function engine.moveAllCards(from, to)
    for _, card in ipairs(from.cards) do
        table.insert(to.cards, card)
    end
    from.cards = {}
    engine.layoutZone(from)
    engine.layoutZone(to)
end

-- Check if a point is inside a rectangle
function engine.pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Find the topmost card at a point in a zone (iterates in reverse for z-order)
function engine.findCardInZone(zone, px, py)
    local W, H = engine.CARD_W, engine.CARD_H
    for i = #zone.cards, 1, -1 do
        local c = zone.cards[i]
        if engine.pointInRect(px, py, c.x, c.y, W, H) then
            return c, i
        end
    end
    return nil, nil
end

-- Render a single card as a rounded rectangle with text overlays
function engine.drawCard(card, dragging)
    local W, H = engine.CARD_W, engine.CARD_H
    local P    = engine.CARD_PAD
    local cx, cy = card.x, card.y
    local iw = W - P * 2    -- largeur intérieure disponible

    -- Draw a shadow behind dragged cards
    if dragging then
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", cx + 4, cy + 4, W, H, 6, 6)
    end

    -- Card background
    love.graphics.setColor(card.color[1], card.color[2], card.color[3])
    love.graphics.rectangle("fill", cx, cy, W, H, 6, 6)

    -- Card border
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("line", cx, cy, W, H, 6, 6)

    if card.face_up ~= false then
        if card.type == "creature" then
            -- Creature card layout: name, HP, points, food reward
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(card.name,                    cx + P, cy + 10,      iw, "center")
            love.graphics.setColor(1, 0.9, 0.2)
            love.graphics.printf("HP: " .. card.hp,           cx + P, cy + 44,      iw, "center")
            love.graphics.setColor(0.6, 1, 0.6)
            love.graphics.printf(card.points .. " pts",        cx + P, cy + 66,      iw, "center")
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.printf("+" .. card.reward_food .. " Food", cx + P, cy + 90, iw, "center")
            -- Red X overlay for defeated creatures
            if card.defeated then
                love.graphics.setColor(1, 0, 0, 0.6)
                love.graphics.setLineWidth(3)
                love.graphics.line(cx + 10, cy + 10, cx + W - 10, cy + H - 10)
                love.graphics.line(cx + W - 10, cy + 10, cx + 10, cy + H - 10)
                love.graphics.setLineWidth(1)
            end
        else
            -- Regular card layout: name, type, strength, description, cost
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(card.name,        cx + P, cy + 10,      iw, "center")
            love.graphics.setColor(0.85, 0.85, 0.9, 0.7)
            love.graphics.printf(card.type,        cx + P, cy + 30,      iw, "center")
            if card.strength > 0 then
                love.graphics.setColor(1, 0.85, 0.2)
                love.graphics.printf("Str " .. card.strength, cx + P, cy + 54, iw, "center")
            end
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf(card.description, cx + P, cy + H - 46, iw, "center")
            if card.cost > 0 and card.cost_type ~= "" then
                love.graphics.setColor(1, 0.8, 0.2)
                local ct = card.cost_type:sub(1, 1):upper()
                love.graphics.printf(card.cost .. ct, cx + P, cy + H - 20, iw, "right")
            end
        end
    else
        -- Face-down card: patterned back
        love.graphics.setColor(0.25, 0.25, 0.4)
        love.graphics.rectangle("fill", cx + 8, cy + 8, W - 16, H - 16, 4, 4)
        love.graphics.setColor(0.35, 0.35, 0.55)
        love.graphics.rectangle("line", cx + 8, cy + 8, W - 16, H - 16, 4, 4)
    end
end


-- Render a zone background, label, and all contained cards
function engine.drawZone(zone, skip_card)
    -- Zone background
    love.graphics.setColor(0.12, 0.12, 0.18, 0.6)
    love.graphics.rectangle("fill", zone.x, zone.y, zone.w, zone.h, 8, 8)

    -- Zone border
    love.graphics.setColor(0.35, 0.35, 0.45, 0.8)
    love.graphics.rectangle("line", zone.x, zone.y, zone.w, zone.h, 8, 8)

    -- Zone label above the box
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.print(zone.label, zone.x + 5, zone.y - 16)

    if zone.layout == "stack" then
        -- Only render the top card plus a count indicator
        if #zone.cards > 0 then
            local top = zone.cards[#zone.cards]
            if top ~= skip_card then
                engine.drawCard(top, false)
            end
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.printf(tostring(#zone.cards), zone.x, zone.y + zone.h - 22, zone.w, "center")
        end
    else
        -- Render all cards in the zone
        for _, card in ipairs(zone.cards) do
            if card ~= skip_card then
                engine.drawCard(card, false)
            end
        end
    end
end

function engine.drawResources(resources, x, y)
    for i, res in ipairs(resources) do
        local rx = x + (i - 1) * 150
        love.graphics.setColor(0.1, 0.1, 0.15, 0.85)
        love.graphics.rectangle("fill", rx, y, 140, 36, 6, 6)
        love.graphics.setColor(res.color[1], res.color[2], res.color[3])
        -- Icône emoji
        if engine.fontEmoji then love.graphics.setFont(engine.fontEmoji) end
        love.graphics.print(res.icon, rx + 8, y + 2)
        -- Nom en police normale
        if engine.fontDefault then love.graphics.setFont(engine.fontDefault) end
        love.graphics.print(res.name, rx + 30, y + 2)
        -- Compteur
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(res.current .. " / " .. res.max, rx + 30, y + 18)
    end
end


function engine.drawButton(text, x, y, w, h, hover)
    -- Highlight on hover, darker when idle
    if hover then
        love.graphics.setColor(0.3, 0.55, 0.85)
    else
        love.graphics.setColor(0.2, 0.35, 0.55)
    end
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(text, x, y + h / 2 - 8, w, "center")
end


return engine