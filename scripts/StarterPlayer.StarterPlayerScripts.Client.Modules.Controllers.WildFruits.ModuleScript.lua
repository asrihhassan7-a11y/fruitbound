--> WildFruits (client)
-- V1.1: small, subtle feedback for Wild Fruits. The server spawns, moves and awards them
-- (Server.Controllers.WildFruits); the client only plays a soft chime when one appears nearby
-- and announces the rarer ones. The Catch prompt itself is a normal ProximityPrompt.
local _L = _G._L

local Network
local Audio
local UI

local NEAR = 90 -- studs: a soft chime when a Wild Fruit appears this close

local WildFruits = {}

function WildFruits._init()
    Network = _L.Get {"Common", "Library", "Network"}
    Audio = _L.Get {"Common", "Library", "Audio"}
    UI = _L.Get {"Client", "Modules", "UI"}
end

function WildFruits._start()
    Network.Remote.Fired("C_WildFruit_Spawned", function(info)
        if typeof(info) ~= "table" then
            return
        end
        local character = _L.Player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and typeof(info.position) == "Vector3" and (root.Position - info.position).Magnitude <= NEAR then
            pcall(Audio.Play, {name = "Ding1", volume = 0.35})
        end
        if typeof(info.region) == "string" then
            local what = if info.rarity ~= "Common" then "wild " .. tostring(info.rarity) .. " Fruit" else "Wild Fruit"
            pcall(function()
                UI.Get("Notifications"):add({text = "✨ A " .. what .. " appeared at " .. info.region .. "! Hold to catch it.", color = Color3.fromRGB(255, 225, 120)})
            end)
        end
    end)
    Network.Remote.Fired("C_WildFruit_Result", function(result)
        if typeof(result) == "table" then
            pcall(Audio.Play, {name = if result.caught then "Reward1" else "Fail1"})
        end
    end)
end

return WildFruits
