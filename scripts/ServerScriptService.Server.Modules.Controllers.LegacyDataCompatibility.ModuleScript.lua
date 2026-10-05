-- // VARIABLES // --
local _L = _G._L

local Players = game:GetService("Players")

local Network
local TableUtility

local LegacyDataCompatibility = {}

-- // FUNCTIONS // --

--[[
Releases Fruits that were stored by the retired Daycare system.
The legacy daycare field and slot records stay intact for profile compatibility.
Fruits in the V1.1 Daycare (fruit_daycare.entries) are NOT released: they really are in Daycare.
@param player Player -- Profile owner.
]]
local function releaseDaycareFruits(player)
    task.spawn(function()
        local client
        for _ = 1, 120 do
            if not player.Parent then
                return
            end
            local ok, result = pcall(Network.Bindable.Invoke, "S_Client_Get", player)
            if ok and result and result.player_controller then
                client = result
                break
            end
            task.wait(0.5)
        end
        if not client then
            return
        end

        local data = client.player_controller._data
        local savedFruits = data:Get("fruits")
        if typeof(savedFruits) ~= "table" then
            return
        end

        local daycareUids = {}
        local daycare = data:Get("daycare")
        if typeof(daycare) == "table" and typeof(daycare.slots) == "table" then
            for _, slot in pairs(daycare.slots) do
                if typeof(slot) == "table" and typeof(slot.fruit_uid) == "string" then
                    daycareUids[slot.fruit_uid] = true
                end
            end
        end

        local activeDaycare = {}
        local fruitDaycare = data:Get("fruit_daycare")
        if typeof(fruitDaycare) == "table" and typeof(fruitDaycare.entries) == "table" then
            for uid in pairs(fruitDaycare.entries) do
                activeDaycare[uid] = true
            end
        end

        local fruits = TableUtility.deep.clone(savedFruits)
        local changed = false
        for _, fruit in ipairs(fruits) do
            if typeof(fruit) == "table" and not activeDaycare[fruit.uid] and (fruit.daycare == true or daycareUids[fruit.uid]) then
                fruit.daycare = nil
                changed = true
            end
        end
        if changed then
            data:Set("fruits", fruits)
        end
    end)
end

-- // INITIALIZATION // --

function LegacyDataCompatibility._init()
    Network = _L.Get {"Common", "Library", "Network"}
    TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

function LegacyDataCompatibility._start()
    for _, player in ipairs(Players:GetPlayers()) do
        releaseDaycareFruits(player)
    end
    Players.PlayerAdded:Connect(releaseDaycareFruits)
end

return LegacyDataCompatibility
