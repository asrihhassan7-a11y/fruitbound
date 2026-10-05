-- // VARIABLES // --
local _L = _G._L

local CollectionService = game:GetService("CollectionService")

local FruitUtility
local Network
local TableUtility

local MAX_SLOTS = 3
local MAX_OFFLINE_SECONDS = 8 * 60 * 60
local REWARD_INTERVAL = 10 * 60
local REQUEST_COOLDOWN = 0.35
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
Returns a safe clone of saved Daycare state.
@param value any -- Potential legacy profile value.
@return table -- Daycare state with a slots dictionary.
]]
local function cloneDaycare(value)
    local daycare = if typeof(value) == "table" then TableUtility.deep.clone(value) else {}
    if typeof(daycare.slots) ~= "table" then
        daycare.slots = {}
    end
    return daycare
end

--[[
Returns the saved Fruit list when structurally valid.
@param data table -- Profile data wrapper.
@return table -- Fruit records.
]]
local function getFruits(data)
    local fruits = data:Get("fruits")
    return if typeof(fruits) == "table" then fruits else {}
end

--[[
Returns one owned Fruit record by stable UID.
@param data table -- Existing profile data wrapper.
@param fruitUid string -- Fruit instance UID.
@return table? -- Fruit record.
@return number? -- Fruit list index.
]]
local function findFruit(data, fruitUid)
    for index, fruit in ipairs(getFruits(data)) do
        if fruit.uid == fruitUid then
            return fruit, index
        end
    end
    return nil
end

--[[
Returns the current reward for a saved Daycare slot.
@param slot table -- Saved slot.
@param now number -- Server timestamp.
@return number -- Claimable Coins.
@return number -- Bounded elapsed seconds.
]]
local function rewardFor(slot, now)
    local startedAt = tonumber(slot.started_at)
    if not startedAt or startedAt ~= startedAt or math.abs(startedAt) == math.huge then
        startedAt = now
    end
    local elapsed = math.clamp(now - startedAt, 0, MAX_OFFLINE_SECONDS)
    local info = FruitUtility.getInfo(slot.fruit_name)
    local factor = math.max(1, math.floor(math.sqrt(math.max(1, info and info.boost or 1))))
    return math.floor(elapsed / REWARD_INTERVAL) * factor, elapsed
end

--[[
Returns safe Daycare state for one player.
@param player Player -- Profile owner.
@return table? -- Daycare state.
]]
local function getState(player)
    local controller = getController(player)
    if not controller then
        return nil
    end
    local data = controller._data
    local now = os.time()
    local result = {slots = {}, available = {}, max_slots = MAX_SLOTS, now = now}
    local daycare = cloneDaycare(data:Get("daycare"))
    for slotIndex = 1, MAX_SLOTS do
        local slot = (daycare.slots or {})[tostring(slotIndex)]
        if slot then
            local fruit = findFruit(data, slot.fruit_uid)
            if fruit then
                local reward, elapsed = rewardFor(slot, now)
                result.slots[tostring(slotIndex)] = {
                    fruit_uid = slot.fruit_uid,
                    fruit_name = slot.fruit_name,
                    started_at = slot.started_at,
                    elapsed = elapsed,
                    reward = reward,
                }
            end
        end
    end
    for _, fruit in ipairs(getFruits(data)) do
        if not fruit.equipped and not fruit.daycare then
            table.insert(result.available, {uid = fruit.uid, name = fruit.name})
        end
    end
    return result
end

--[[
Places one eligible existing Fruit into Daycare.
@param player Player -- Requesting player.
@param fruitUid string -- Owned Fruit UID.
@return boolean -- Whether placement succeeded.
@return any -- Slot index or error code.
]]
local function putFruit(player, fruitUid)
    if typeof(fruitUid) ~= "string" or #fruitUid > 80 or not passRateLimit(player) then
        return false, "invalid"
    end
    local controller = getController(player)
    if not controller then
        return false, "profile"
    end
    local data = controller._data
    local fruit, fruitIndex = findFruit(data, fruitUid)
    if not fruit or fruit.equipped or fruit.daycare or not FruitUtility.getInfo(fruit.name) then
        return false, "ownership"
    end
    local daycare = cloneDaycare(data:Get("daycare"))
    local freeSlot
    for slotIndex = 1, MAX_SLOTS do
        if daycare.slots[tostring(slotIndex)] == nil then
            freeSlot = slotIndex
            break
        end
    end
    if not freeSlot then
        return false, "full"
    end
    local fruits = TableUtility.deep.clone(getFruits(data))
    fruits[fruitIndex].equipped = false
    fruits[fruitIndex].daycare = true
    daycare.slots[tostring(freeSlot)] = {
        fruit_uid = fruitUid,
        fruit_name = fruit.name,
        started_at = os.time(),
    }
    data:Set("fruits", fruits)
    data:Set("daycare", daycare)
    return true, freeSlot
end

--[[
Claims one matured Daycare reward exactly once.
@param player Player -- Requesting player.
@param slotIndex number -- Daycare slot.
@return boolean -- Whether a reward was claimed.
@return any -- Reward amount or error code.
]]
local function claim(player, slotIndex)
    if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > MAX_SLOTS or not passRateLimit(player) then
        return false, "invalid"
    end
    local controller = getController(player)
    if not controller then
        return false, "profile"
    end
    local data = controller._data
    local daycare = cloneDaycare(data:Get("daycare"))
    local slot = daycare.slots and daycare.slots[tostring(slotIndex)]
    local fruit = slot and findFruit(data, slot.fruit_uid)
    if not slot or not fruit or not fruit.daycare then
        return false, "ownership"
    end
    local now = os.time()
    local reward, elapsed = rewardFor(slot, now)
    if reward <= 0 then
        return false, "wait"
    end
    daycare.slots[tostring(slotIndex)].started_at = now - (elapsed % REWARD_INTERVAL)
    data:Set("daycare", daycare)
    controller:_add_coins(reward)
    return true, reward
end

--[[
Returns a Fruit from Daycare without duplicating its inventory record.
@param player Player -- Requesting player.
@param slotIndex number -- Daycare slot.
@return boolean -- Whether removal succeeded.
@return string? -- Error code.
]]
local function removeFruit(player, slotIndex)
    if typeof(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > MAX_SLOTS or not passRateLimit(player) then
        return false, "invalid"
    end
    local controller = getController(player)
    if not controller then
        return false, "profile"
    end
    local data = controller._data
    local daycare = cloneDaycare(data:Get("daycare"))
    local slot = daycare.slots and daycare.slots[tostring(slotIndex)]
    local fruit
    local fruitIndex
    if slot then
        fruit, fruitIndex = findFruit(data, slot.fruit_uid)
    end
    if not slot or not fruit then
        return false, "ownership"
    end
    local fruits = TableUtility.deep.clone(getFruits(data))
    fruits[fruitIndex].daycare = nil
    daycare.slots[tostring(slotIndex)] = nil
    data:Set("fruits", fruits)
    data:Set("daycare", daycare)
    return true
end

--[[
Adds Daycare interaction prompts to Fruit Pens.
]]
local function connectPens()
    local function connect(pen)
        local meadow = pen:FindFirstChild("Meadow")
        if not meadow or meadow:FindFirstChild("DaycarePrompt") then
            return
        end
        local prompt = Instance.new("ProximityPrompt")
        prompt.Name = "DaycarePrompt"
        prompt.ActionText = "Open Daycare"
        prompt.ObjectText = "Fruit Daycare"
        prompt.MaxActivationDistance = 12
        prompt.RequiresLineOfSight = false
        prompt.Parent = meadow
        prompt.Triggered:Connect(function(player)
            Network.Remote.Fire("C_Daycare_Open", player)
        end)
    end
    for _, pen in ipairs(CollectionService:GetTagged("FruitPen")) do
        connect(pen)
    end
    CollectionService:GetInstanceAddedSignal("FruitPen"):Connect(connect)
end

--[[
Loads dependencies for Daycare progression.
]]
function Daycare._init()
    Network = _L.Get {"Common", "Library", "Network"}
    FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
    TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

--[[
Starts Daycare requests and world interactions.
]]
function Daycare._start()
    Network.Remote.Invoked("S_Daycare_Get", getState)
    Network.Remote.Invoked("S_Daycare_Put", putFruit)
    Network.Remote.Invoked("S_Daycare_Claim", claim)
    Network.Remote.Invoked("S_Daycare_Remove", removeFruit)
    connectPens()
    game:GetService("Players").PlayerRemoving:Connect(function(player)
        lastRequest[player] = nil
    end)
end

-- // INITIALIZATION // --
return Daycare
