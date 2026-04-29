local HighScore = {}

local MAX_ENTRIES = 10
local entries = {}

function HighScore.formatTime(t)
    return string.format("%02d:%05.2f", math.floor(t / 60), t % 60)
end

function HighScore.load()
    entries = {}
    if not love.filesystem.getInfo("highscores.txt") then return end
    for line in love.filesystem.lines("highscores.txt") do
        local name, time = line:match("^([A-Z][A-Z][A-Z]),([%d%.]+)$")
        if name and time then
            table.insert(entries, { name = name, time = tonumber(time) })
        end
    end
end

function HighScore.save()
    local data = ""
    for _, e in ipairs(entries) do
        data = data .. e.name .. "," .. string.format("%.2f", e.time) .. "\n"
    end
    love.filesystem.write("highscores.txt", data)
end

-- Insère l'entrée, trie par temps ASC, écrête à MAX_ENTRIES.
-- Retourne le rang obtenu (nil si hors top).
function HighScore.add(name, time)
    table.insert(entries, { name = name, time = time })
    table.sort(entries, function(a, b) return a.time < b.time end)
    while #entries > MAX_ENTRIES do table.remove(entries) end
    HighScore.save()
    for i, e in ipairs(entries) do
        if e.name == name and math.abs(e.time - time) < 0.001 then
            return i
        end
    end
    return nil
end

function HighScore.getAll()
    return entries
end

-- Vrai si time se qualifie dans le top MAX_ENTRIES actuel
function HighScore.qualifies(time)
    return #entries < MAX_ENTRIES or time < entries[#entries].time
end

return HighScore
