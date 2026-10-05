-- // VARIABLES // --
-- V1.1 Wild Fruits: one shared spawn manager for the whole server (one 1 s loop, no loop per
-- Fruit or per decoration). Fruits appear at the fixed spawn points of each region, wander a
-- little, and leave after a while. A player catches one by holding the "Catch" prompt; the
-- server re-checks the Fruit, distance, cooldowns and inventory space, then rolls the catch.
-- Nothing is decided by the client and nothing involves Robux.
local _L = _G._L

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network
local Config
local FruitUtility
local PlayerRewardUtility

local WildFruits = {_active = {}} -- [id] = fruit state
local rng = Random.new()
local nextId = 0
local regionNext = {} -- [regionName] = os.clock() of the next allowed spawn
WildFruits._next = regionNext -- read-only view for debugging / tests
local lastAttempt = {} -- [player] = os.clock()
local restUntil = {} -- [UserId] = os.clock() (net rests after a catch; kept if they rejoin this server)
local folder

-- // FUNCTIONS // --

local function getClient(player)
    return Network.Bindable.Invoke("S_Client_Get", player)
end

local function notify(player, text, color)
    local client = getClient(player)
    if client and client.player_controller then
        pcall(function()
            client.player_controller:_notify({text = text, color = color or Color3.fromRGB(150, 230, 150)})
        end)
    end
end

local function spawnRoot()
    local map = workspace:FindFirstChild("__MAP")
    local world = map and map:FindFirstChild("V11World")
    return world and world:FindFirstChild("WildFruitSpawns")
end

local function pickWeighted(list)
    local total = 0
    for _, e in ipairs(list) do
        total += e.weight
    end
    local roll = rng:NextNumber(0, total)
    for _, e in ipairs(list) do
        roll -= e.weight
        if roll <= 0 then
            return e
        end
    end
    return list[#list]
end

local function countActive(region)
    local n = 0
    for _, f in pairs(WildFruits._active) do
        if region == nil or f.region == region then
            n += 1
        end
    end
    return n
end

local function remove(fruit, reason)
    if not WildFruits._active[fruit.id] then
        return
    end
    WildFruits._active[fruit.id] = nil
    local regionInfo = Config.regions[fruit.region]
    local range = regionInfo and regionInfo.respawn or {240, 420}
    regionNext[fruit.region] = os.clock() + rng:NextNumber(range[1], range[2])
    if fruit.part and fruit.part.Parent then
        local part = fruit.part
        local prompt = part:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            prompt.Enabled = false
        end
        part:SetAttribute("Leaving", reason or "gone")
        -- small hop + shrink, then gone
        local tween = TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = part.Size * 0.05, CFrame = part.CFrame + Vector3.new(0, 2, 0)})
        tween:Play()
        task.delay(0.5, function()
            part:Destroy()
        end)
    end
end

local function buildVisual(fruitName, position)
    local info = FruitUtility.getInfo(fruitName)
    local models = ReplicatedStorage.Assets.Models.Fruits
    local template = info and models:FindFirstChild(info.model or info.name)
    local source = template and (template.PrimaryPart or template:FindFirstChildWhichIsA("BasePart"))
    if not source then
        return nil
    end
    local part = source:Clone()
    part.Name = "WildFruit"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = true
    part.Size = part.Size * 0.75
    part.CFrame = CFrame.new(position + Vector3.new(0, part.Size.Y / 2 + 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
    -- subtle sparkle + glow (one emitter, low rate)
    local sparkle = Instance.new("ParticleEmitter")
    sparkle.Name = "Sparkle"
    sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkle.Rate = 3
    sparkle.Lifetime = NumberRange.new(0.8, 1.4)
    sparkle.Speed = NumberRange.new(0.5, 1.5)
    sparkle.SpreadAngle = Vector2.new(180, 180)
    sparkle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
    sparkle.LightEmission = 0.8
    sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 245, 190))
    sparkle.Parent = part
    local light = Instance.new("PointLight")
    light.Brightness = 0.8
    light.Range = 7
    light.Color = Color3.fromRGB(255, 240, 200)
    light.Shadows = false
    light.Parent = part
    return part, info
end

local function spawnIn(regionName, regionFolder)
    local points = regionFolder:GetChildren()
    if #points == 0 then
        return false
    end
    local regionInfo = Config.regions[regionName]
    local entry = pickWeighted(regionInfo.fruits)
    local point = points[rng:NextInteger(1, #points)]
    local part, info = buildVisual(entry.name, point.Position - Vector3.new(0, 0.5, 0))
    if not part then
        warn("[WildFruits] no model for", entry.name)
        return false
    end
    nextId += 1
    local id = "wf" .. nextId
    local rarity = info.rarity or "Common"
    part:SetAttribute("WildFruitId", id)
    part:SetAttribute("FruitName", entry.name)
    part:SetAttribute("Rarity", rarity)
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Catch"
    prompt.ObjectText = "Wild " .. (info.display_name or entry.name) .. " (" .. rarity .. ")"
    prompt.HoldDuration = Config.CATCH_HOLD
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.F
    prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
    prompt.Parent = part
    local fruit = {
        id = id,
        region = regionName,
        name = entry.name,
        rarity = rarity,
        part = part,
        home = point.Position - Vector3.new(0, 0.5, 0),
        expires = os.clock() + rng:NextNumber(Config.LIFETIME[1], Config.LIFETIME[2]),
        nextWander = os.clock() + rng:NextNumber(2, 4),
        busy = false,
    }
    WildFruits._active[id] = fruit
    prompt.Triggered:Connect(function(player)
        WildFruits.catch(player, id)
    end)
    part.Parent = folder
    Network.Remote.FireAll("C_WildFruit_Spawned", {region = regionInfo.display, rarity = rarity, position = part.Position})
    return true
end

local function wander(fruit, now)
    if fruit.busy or now < fruit.nextWander or not fruit.part.Parent then
        return
    end
    fruit.nextWander = now + rng:NextNumber(3, 6)
    local angle = rng:NextNumber(0, math.pi * 2)
    local dist = rng:NextNumber(0, Config.WANDER_RADIUS)
    local target = fruit.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
    -- stay on the ground of the region (never walk into water / off the map)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {folder}
    params.IgnoreWater = false
    local hit = workspace:Raycast(target + Vector3.new(0, 8, 0), Vector3.new(0, -16, 0), params)
    if not hit or hit.Material == Enum.Material.Water then
        return
    end
    local half = fruit.part.Size.Y / 2 + 0.2
    local goal = CFrame.lookAt(Vector3.new(target.X, hit.Position.Y + half, target.Z), Vector3.new(fruit.part.Position.X, hit.Position.Y + half, fruit.part.Position.Z)) * CFrame.Angles(0, math.pi, 0)
    TweenService:Create(fruit.part, TweenInfo.new(2, Enum.EasingStyle.Sine), {CFrame = goal}):Play()
end

--[[
A player tries to catch a Wild Fruit (called by the prompt, after the hold finished).
Every rule is checked here; the client only shows the prompt.
@return boolean, string? -- caught?, reason
]]
function WildFruits.catch(player, id)
    local fruit = typeof(id) == "string" and WildFruits._active[id] or nil
    if not fruit or fruit.busy or not fruit.part.Parent then
        return false, "gone"
    end
    local now = os.clock()
    if lastAttempt[player] and now - lastAttempt[player] < Config.ATTEMPT_COOLDOWN then
        notify(player, "⏳ Catch again in " .. math.ceil(Config.ATTEMPT_COOLDOWN - (now - lastAttempt[player])) .. "s", Color3.fromRGB(255, 200, 90))
        return false, "cooldown"
    end
    if restUntil[player.UserId] and now < restUntil[player.UserId] then
        notify(player, "🧺 Your basket is full of Wild Fruit luck! Try again in " .. math.ceil((restUntil[player.UserId] - now) / 60) .. " min", Color3.fromRGB(255, 200, 90))
        return false, "rest"
    end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root or (root.Position - fruit.part.Position).Magnitude > Config.CATCH_DISTANCE then
        return false, "distance"
    end
    local client = getClient(player)
    if not client or not client.data then
        return false, "error"
    end
    if not FruitUtility.hasInventorySpace(client.data, 1) then
        notify(player, "🎒 Your Fruit inventory is full!", Color3.fromRGB(255, 120, 90))
        return false, "space"
    end
    -- lock: only one catch roll per Fruit at a time (two players can never both get it).
    -- Re-checked here because getClient above can yield while another player's catch runs.
    if fruit.busy or WildFruits._active[id] ~= fruit or not fruit.part.Parent then
        return false, "gone"
    end
    fruit.busy = true
    lastAttempt[player] = now
    local chance = Config.CATCH_CHANCE[fruit.rarity] or 0.3
    local fruitInfo = FruitUtility.getInfo(fruit.name)
    local displayName = fruitInfo and fruitInfo.display_name or fruit.name
    if rng:NextNumber() < chance then
        -- remove first, then reward: the Fruit can never be given twice
        remove(fruit, "caught")
        local ok, given = pcall(PlayerRewardUtility.give, client, {{name = "Fruit", props = {name = fruit.name, value = 1}}})
        if not ok or not given then
            warn("[WildFruits] reward failed", player.Name, fruit.name, given)
            notify(player, "Something went wrong, the Fruit got away!", Color3.fromRGB(255, 120, 90))
            return false, "error"
        end
        restUntil[player.UserId] = os.clock() + Config.CATCH_REST
        pcall(function()
            client.data:Set("wild_captures", (tonumber(client.data:Get("wild_captures")) or 0) + 1)
        end)
        notify(player, "🎉 You caught a wild " .. displayName .. "!", Color3.fromRGB(255, 215, 80))
        Network.Remote.Fire("C_WildFruit_Result", player, {caught = true, name = fruit.name, rarity = fruit.rarity})
        return true
    end
    fruit.busy = false
    if rng:NextNumber() < Config.ESCAPE_CHANCE then
        remove(fruit, "escaped")
        notify(player, "💨 The wild " .. displayName .. " escaped!", Color3.fromRGB(255, 160, 90))
        Network.Remote.Fire("C_WildFruit_Result", player, {caught = false, escaped = true, name = fruit.name})
    else
        fruit.expires = math.min(fruit.expires, os.clock() + Config.AFTER_FAIL_LIFETIME)
        notify(player, "😮 The " .. displayName .. " wiggled free! Try again!", Color3.fromRGB(255, 200, 90))
        Network.Remote.Fire("C_WildFruit_Result", player, {caught = false, escaped = false, name = fruit.name})
    end
    return false, "failed"
end

function WildFruits._init()
    Network = _L.Get {"Common", "Library", "Network"}
    Config = _L.Get {"Common", "Modules", "Databases", "WildFruits"}
    FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
    PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
end

function WildFruits._start()
    folder = Instance.new("Folder")
    folder.Name = "WildFruits"
    folder.Parent = workspace
    local roots = spawnRoot()
    if not roots then
        warn("[WildFruits] no spawn points")
        return
    end
    -- first spawns come soon after the server starts (players should meet one early),
    -- staggered per region; after that each region uses its normal respawn timer
    for _, regionFolder in ipairs(roots:GetChildren()) do
        local info = Config.regions[regionFolder.Name]
        if info then
            regionNext[regionFolder.Name] = os.clock() + rng:NextNumber(10, 60)
        end
    end
    task.spawn(function()
        while true do
            task.wait(1)
            local now = os.clock()
            for _, fruit in pairs(WildFruits._active) do
                if not fruit.busy and (now >= fruit.expires or not fruit.part.Parent) then
                    remove(fruit, "left")
                else
                    wander(fruit, now)
                end
            end
            if countActive() < Config.MAX_ACTIVE and #Players:GetPlayers() > 0 then
                for _, regionFolder in ipairs(roots:GetChildren()) do
                    local name = regionFolder.Name
                    if Config.regions[name] and countActive(name) == 0 and now >= (regionNext[name] or math.huge) and countActive() < Config.MAX_ACTIVE then
                        local ok, err = pcall(spawnIn, name, regionFolder)
                        if not ok or err ~= true then
                            warn("[WildFruits] spawn failed:", err)
                            regionNext[name] = now + 60
                        else
                            regionNext[name] = math.huge -- set again when this Fruit leaves
                        end
                    end
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        lastAttempt[player] = nil
    end)
end

return WildFruits
