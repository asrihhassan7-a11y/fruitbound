-- // VARIABLES // --
-- V1.1 Daycare in the Village Fruit Pen.
-- A deposited Fruit keeps its exact record in `fruits` (UID, level, stage, tier...) with
-- daycare = true, so every existing guard (equip, delete, feed, evolve, mount) already refuses it.
-- The Daycare timer lives in fruit_daycare.entries[uid]; Gems are computed from timestamps on
-- the server (offline time included). No loops per Fruit: everything happens on a request.
local _L = _G._L

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local FruitUtility
local FruitFarmUtility
local Network
local TableUtility

local REQUEST_COOLDOWN = 0.4
local Daycare = {}
local lastRequest = {}

-- // FUNCTIONS // --

--[[
Returns the loaded player profile controller.
@param player Player -- Requesting player.
@return table? -- Existing player controller.
]]
local function getController(player)
    local client = Network.Bindable.Invoke("S_Client_Get", player)
    return client and client.player_controller or nil
end

--[[
Allows a bounded rate of Daycare requests.
@param player Player -- Requesting player.
@return boolean -- Whether the request may continue.
]]
local function passRateLimit(player)
    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
        return false
    end
    lastRequest[player] = now
    return true
end

--[[
Returns a safe clone of the saved V1.1 Daycare.
@param value any -- Saved fruit_daycare value.
@return table -- {entries = {[uid] = entry}}
]]
local function cloneDaycare(value)
    local daycare = if typeof(value) == "table" then TableUtility.deep.clone(value) else {}
    if typeof(daycare.entries) ~= "table" then
        daycare.entries = {}
    end
    return daycare
end

local function countEntries(daycare)
    local n = 0
    for _ in pairs(daycare.entries) do
        n += 1
    end
    return n
end

--[[
Finds one owned Fruit by UID.
@return table? -- Fruit record.
@return number? -- Index in the cloned list.
]]
local function findFruit(fruits, fruitUid)
    for index, fruit in ipairs(fruits) do
        if typeof(fruit) == "table" and fruit.uid == fruitUid then
            return fruit, index
        end
    end
    return nil
end

local function notify(controller, text, color)
    pcall(function()
        controller:_notify({text = text, color = color or Color3.fromRGB(150, 220, 255)})
    end)
end

local function displayName(fruit)
    local info = FruitUtility.getInfo(fruit.name)
    local FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
    return FruitStageUtility.getDisplayName(info and (info.display_name or info.name) or fruit.name, fruit.stage)
end

--[[
Grants the pending Gems of the given entries once and moves their timers forward.
The caller passes a cloned daycare table and saves it afterwards.
@return number -- Gems granted.
]]
local function collectEntries(controller, daycare, fruits, uids, now)
    local total = 0
    for _, uid in ipairs(uids) do
        local entry = daycare.entries[uid]
        local fruit = entry and findFruit(fruits, uid)
        if entry and fruit then
            local gems, used = FruitFarmUtility.getPending(entry, fruit, now)
            if gems > 0 then
                total += gems
                entry.last_collected_at = math.min(entry.last_collected_at + used, now)
            end
        end
    end
    if total > 0 then
        local data = controller._data
        local balance = data:Get({"stats", "Gems"})
        if typeof(balance) ~= "number" or balance ~= balance then
            balance = 0
        end
        data:Set({"stats", "Gems"}, balance + total)
    end
    return total
end

--[[
Returns the Daycare state for the menu (the server clock is included for timers).
@param player Player -- Profile owner.
@return table? -- State.
]]
local function getState(player)
    local controller = getController(player)
    if not controller then
        return nil
    end
    local data = controller._data
    local now = os.time()
    local fruits = data:Get("fruits") or {}
    local daycare = cloneDaycare(data:Get("fruit_daycare"))
    local slots = {}
    for uid, entry in pairs(daycare.entries) do
        local fruit = findFruit(fruits, uid)
        if fruit then
            table.insert(slots, {
                fruit_uid = uid,
                fruit_id = fruit.name,
                deposited_at = entry.deposited_at,
                gems_ready = (FruitFarmUtility.getPending(entry, fruit, now)),
                gem_rate = FruitFarmUtility.getGemRate(fruit),
            })
        end
    end
    table.sort(slots, function(a, b)
        return (a.deposited_at or 0) < (b.deposited_at or 0)
    end)
    return {slots = slots, capacity = FruitFarmUtility.DAYCARE_CAPACITY, now = now}
end

--[[
Moves one owned, valid Fruit from the inventory into Daycare.
@return boolean, string? -- success, error code
]]
local function deposit(player, fruitUid)
    if typeof(fruitUid) ~= "string" or #fruitUid > 80 or not passRateLimit(player) then
        return false, "invalid"
    end
    local controller = getController(player)
    if not controller then
        return false, "profile"
    end
    local data = controller._data
    local fruits = TableUtility.deep.clone(data:Get("fruits") or {})
    local fruit = findFruit(fruits, fruitUid)
    if not fruit then
        return false, "ownership"
    end
    local daycare = cloneDaycare(data:Get("fruit_daycare"))
    if fruit.daycare or daycare.entries[fruitUid] then
        return false, "already"
    end
    local info = FruitUtility.getInfo(fruit.name)
    if not info or info.admin_only then
        return false, "invalid"
    end
    if countEntries(daycare) >= FruitFarmUtility.DAYCARE_CAPACITY then
        return false, "full"
    end
    -- riding it? get off first so nothing keeps using it
    if player:GetAttribute("MountedFruit") == fruitUid then
        pcall(function()
            _L.Get({"Server", "Modules", "Controllers", "Mount"}).unmount(player)
        end)
    end
    local now = os.time()
    fruit.equipped = false -- safely unequipped: the follower leaves, its boosts stop
    fruit.daycare = true
    daycare.entries[fruitUid] = {
        fruit_uid = fruitUid,
        fruit_id = fruit.name,
        deposited_at = now,
        last_collected_at = now,
    }
    data:Set("fruits", fruits)
    data:Set("fruit_daycare", daycare)
    notify(controller, "🍎 " .. displayName(fruit) .. " entered Daycare!", Color3.fromRGB(150, 230, 120))
    return true
end

--[[
Collects the Gems of one Daycare Fruit, or of all of them (fruitUid = nil).
@return boolean, any -- success, Gems granted or error code
]]
local function collect(player, fruitUid)
    if (fruitUid ~= nil and (typeof(fruitUid) ~= "string" or #fruitUid > 80)) or not passRateLimit(player) then
        return false, "invalid"
    end
    local controller = getController(player)
    if not controller then
        return false, "profile"
    end
    local data = controller._data
    local daycare = cloneDaycare(data:Get("fruit_daycare"))
    local uids = {}
    if fruitUid then
        if not daycare.entries[fruitUid] then
            return false, "ownership"
        end
        uids = {fruitUid}
    else
        for uid in pairs(daycare.entries) do
            table.insert(uids, uid)
        end
    end
    local total = collectEntries(controller, daycare, data:Get("fruits") or {}, uids, os.time())
    if total <= 0 then
        return false, "empty"
    end
    data:Set("fruit_daycare", daycare)
    notify(controller, "+" .. total .. " Gems", Color3.fromRGB(120, 220, 255))
    return true, total
end

--[[
Collects a Fruit's last Gems, then returns the SAME Fruit record to the inventory.
@return boolean, any -- success, Gems granted or error code
]]
local function withdraw(player, fruitUid)
    if typeof(fruitUid) ~= "string" or #fruitUid > 80 or not passRateLimit(player) then
        return false, "invalid"
    end
    local controller = getController(player)
    if not controller then
        return false, "profile"
    end
    local data = controller._data
    local daycare = cloneDaycare(data:Get("fruit_daycare"))
    if not daycare.entries[fruitUid] then
        return false, "ownership"
    end
    local fruits = TableUtility.deep.clone(data:Get("fruits") or {})
    local fruit = findFruit(fruits, fruitUid)
    local gems = 0
    if fruit then
        gems = collectEntries(controller, daycare, fruits, {fruitUid}, os.time())
        fruit.daycare = nil
        fruit.equipped = false
    end
    daycare.entries[fruitUid] = nil
    data:Set("fruit_daycare", daycare)
    if fruit then
        data:Set("fruits", fruits)
        local text = displayName(fruit) .. " returned to your Fruits!"
        if gems > 0 then
            text ..= " (+" .. gems .. " Gems)"
        end
        notify(controller, text, Color3.fromRGB(150, 230, 120))
    end
    return true, gems
end

--[[
On join: the Daycare entries are the truth. A Fruit with an entry is flagged daycare and
unequipped; an entry whose Fruit no longer exists is dropped (nothing to return).
@param player Player -- Profile owner.
]]
local function syncPlayer(player)
    local controller
    for _ = 1, 120 do
        if not player.Parent then
            return
        end
        controller = getController(player)
        if controller then
            break
        end
        task.wait(0.5)
    end
    if not controller then
        return
    end
    local data = controller._data
    local daycare = cloneDaycare(data:Get("fruit_daycare"))
    local fruits = TableUtility.deep.clone(data:Get("fruits") or {})
    local fruitsChanged, daycareChanged = false, false
    for uid, entry in pairs(daycare.entries) do
        local fruit = typeof(entry) == "table" and findFruit(fruits, uid)
        if not fruit then
            daycare.entries[uid] = nil
            daycareChanged = true
        else
            if typeof(entry.last_collected_at) ~= "number" or entry.last_collected_at ~= entry.last_collected_at then
                entry.last_collected_at = os.time()
                daycareChanged = true
            end
            if fruit.daycare ~= true or fruit.equipped then
                fruit.daycare = true
                fruit.equipped = false
                fruitsChanged = true
            end
        end
    end
    if fruitsChanged then
        data:Set("fruits", fruits)
    end
    if daycareChanged then
        data:Set("fruit_daycare", daycare)
    end
end

--[[
Adds the Daycare prompt to every Fruit Pen (the Village pen sign, or a pen's meadow).
The prompt opens the Daycare menu through VillagePrompts (OpenUI attribute).
]]
local function connectPens()
    local function connect(pen)
        local sign = pen:FindFirstChild("Sign")
        local host = (sign and sign:FindFirstChild("Board")) or pen:FindFirstChild("Meadow")
        if not host or not host:IsA("BasePart") or host:FindFirstChild("DaycarePrompt") then
            return
        end
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "DaycarePrompt"
        prompt.ActionText = "Open Daycare"
        prompt.ObjectText = "Fruit Daycare"
        prompt.KeyboardKeyCode = Enum.KeyCode.F
        prompt.MaxActivationDistance = 14
        prompt.RequiresLineOfSight = false
        prompt:SetAttribute("OpenUI", "Daycare")
        prompt.Parent = host
    end
    for _, pen in ipairs(CollectionService:GetTagged("FruitPen")) do
        connect(pen)
    end
    CollectionService:GetInstanceAddedSignal("FruitPen"):Connect(connect)
end

-- // INITIALIZATION // --

function Daycare._init()
    Network = _L.Get {"Common", "Library", "Network"}
    TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
    FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
    FruitFarmUtility = _L.Get {"Common", "Modules", "Utilities", "FruitFarmUtility"}
end

function Daycare._start()
    Network.Remote.Invoked("S_Daycare_Get", getState)
    Network.Remote.Invoked("S_Daycare_Deposit", deposit)
    Network.Remote.Invoked("S_Daycare_Collect", collect)
    Network.Remote.Invoked("S_Daycare_Withdraw", withdraw)
    connectPens()
    Players.PlayerAdded:Connect(function(player)
        task.spawn(syncPlayer, player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(syncPlayer, player)
    end
    Players.PlayerRemoving:Connect(function(player)
        lastRequest[player] = nil
    end)
end

return Daycare
