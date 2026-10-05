-- // VARIABLES // --
-- V1.1 Fishing (overhaul). Everything that decides an outcome happens here:
--   zone + water + rod checks, Bait use (one per VALID cast), which fish / treasure bites,
--   bite timing, the reel result (the server re-runs the deterministic reel simulation from the
--   player's hold / release inputs), weight, value, Fishing Bag, selling, shop, rods, XP,
--   quests, collections, treasure and records.
-- The client only sends: an aim point, "hook" on the bite, hold/release, and menu requests.
-- Save: everything lives in data.fishing (see FishingUtility.normalize). Nothing else is touched.
local _L = _G._L

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local Network
local Config
local U
local PlayerRewardUtility
local NumberUtility

local ROD_ATTRIBUTE = "FishingRod"
local REQUEST_COOLDOWN = 0.25
local INPUTS_PER_SECOND = 30
local SETTLE_STEPS = 12 -- the server judges the reel 0.6 s behind real time (lag allowance)
local LEAD_STEPS = 4

local Fishing = {}
local states = {} -- [player] = {phase = "waiting"|"bite"|"reel", ...}
local lastEnd = {}
local lastRequest = {}
local inputBudget = {}
local rng = Random.new()
local tokenCounter = 0
local trophies = {} -- best Rare+ catches this server {name, fish, weight, rarity}

-- // FUNCTIONS // --

local function getClient(player)
    return Network.Bindable.Invoke("S_Client_Get", player)
end

local function notify(player, text, color)
    local client = getClient(player)
    if client and client.player_controller then
        pcall(function()
            client.player_controller:_notify({text = text, color = color or Color3.fromRGB(150, 210, 255)})
        end)
    end
end

local function passRateLimit(player, cooldown)
    local now = os.clock()
    if lastRequest[player] and now - lastRequest[player] < (cooldown or REQUEST_COOLDOWN) then
        return false
    end
    lastRequest[player] = now
    return true
end

-- the player's fishing save (a normalized copy) + the data wrapper to save it back
local function load(player)
    local client = getClient(player)
    if not client or not client.data then
        return nil
    end
    return U.normalize(client.data:Get("fishing")), client
end

local function save(client, f)
    f.level = (U.levelFromXp(f.xp))
    client.data:Set("fishing", f)
end

local function world()
    local map = workspace:FindFirstChild("__MAP")
    return map and map:FindFirstChild("V11World")
end

local function npcRoot()
    local w = world()
    local hub = w and w:FindFirstChild("FishingHub")
    local npc = hub and hub:FindFirstChild("FisherFinn")
    return npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart"))
end

local function aliveRoot(player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if humanoid and humanoid.Health > 0 and root then
        return root
    end
    return nil
end

local function nearNpc(player)
    local root = aliveRoot(player)
    local npc = npcRoot()
    return root ~= nil and npc ~= nil and (root.Position - npc.Position).Magnitude <= Config.NPC_DISTANCE
end

local function zoneAt(position)
    local w = world()
    local folder = w and w:FindFirstChild("FishingZones")
    for _, zone in ipairs(folder and folder:GetChildren() or {}) do
        if zone:IsA("BasePart") then
            local rel = zone.CFrame:PointToObjectSpace(position)
            if math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Y) <= zone.Size.Y / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 then
                return zone
            end
        end
    end
    return nil
end

local function equippedRod(player)
    local character = player.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    return tool and tool:GetAttribute(ROD_ATTRIBUTE) == true and tool or nil
end

local function isNight()
    local ok, WorldEvents = pcall(_L.Get, {"Server", "Modules", "Controllers", "WorldEvents"})
    if ok and WorldEvents and WorldEvents.isNight then
        local ok2, night = pcall(WorldEvents.isNight)
        return ok2 and night == true
    end
    return false
end

local function isRaining()
    local e = workspace:GetAttribute("Event")
    return e == "Rain" or e == "Storm"
end

local function pickWeighted(list)
    local total = 0
    for _, e in ipairs(list) do
        total += e.weight
    end
    if total <= 0 then
        return nil
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

------------------------------------------------------------ rods (Tools)
local function part(parent, name, size, color, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Color = color
    p.Material = material or Enum.Material.SmoothPlastic
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Massless = true
    p.Parent = parent
    return p
end

local function buildRod(rod, skinId)
    local skin = skinId and Config.cosmetic(skinId)
    local tool = Instance.new("Tool")
    tool.Name = rod.name
    tool.ToolTip = "Tap the water to cast"
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    tool:SetAttribute(ROD_ATTRIBUTE, true)
    tool:SetAttribute("RodId", rod.id)
    local color = if skin and skin.color and not skin.rainbow then skin.color else rod.color
    local handle = part(tool, "Handle", Vector3.new(0.25, 0.25, 6), color, rod.material)
    -- grip wrap, reel and tip ring: each tier looks different (accent colour / metal / neon)
    local wrap = part(tool, "Grip", Vector3.new(0.34, 0.34, 1.4), Color3.fromRGB(60, 45, 35), Enum.Material.Fabric)
    wrap.CFrame = handle.CFrame * CFrame.new(0, 0, 2.2)
    local reel = part(tool, "Reel", Vector3.new(0.35, 0.65, 0.65), rod.accent, Enum.Material.Metal)
    reel.Shape = Enum.PartType.Cylinder
    reel.CFrame = handle.CFrame * CFrame.new(0.3, 0, 1.4)
    local ring = part(tool, "TipRing", Vector3.new(0.12, 0.42, 0.42), rod.accent, if rod.neon then Enum.Material.Neon else Enum.Material.Metal)
    ring.Shape = Enum.PartType.Cylinder
    ring.CFrame = handle.CFrame * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, math.rad(90), 0)
    if rod.rank >= 2 then
        for i = 1, rod.rank - 1 do
            local band = part(tool, "Band", Vector3.new(0.3, 0.3, 0.12), rod.accent, Enum.Material.Neon)
            band.CFrame = handle.CFrame * CFrame.new(0, 0, -0.6 * i)
        end
    end
    if skin and skin.rainbow then
        local hue = 0
        for _, d in ipairs(tool:GetChildren()) do
            if d:IsA("BasePart") and d.Name ~= "Grip" then
                d.Color = Color3.fromHSV(hue % 1, 0.7, 1)
                hue += 0.17
            end
        end
    end
    for _, p in ipairs(tool:GetChildren()) do
        if p:IsA("BasePart") and p ~= handle then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = handle
            weld.Part1 = p
            weld.Parent = p
        end
    end
    local tip = Instance.new("Attachment")
    tip.Name = "Tip"
    tip.Position = Vector3.new(0, 0, -3)
    tip.Parent = handle
    tool.Grip = CFrame.new(0, 0, 2.2) * CFrame.Angles(math.rad(-35), 0, 0)
    return tool
end

local function removeRods(container)
    for _, child in ipairs(container and container:GetChildren() or {}) do
        if child:IsA("Tool") and child:GetAttribute(ROD_ATTRIBUTE) == true then
            child:Destroy()
        end
    end
end

-- exactly one rod tool of the player's current rod (Backpack now + StarterGear for respawns)
local function giveRod(player, f)
    local rod = U.getRod(f)
    if not rod then
        return
    end
    local skin = f.cosmetics and f.cosmetics.skin
    local character = player.Character
    local wasEquipped = equippedRod(player) ~= nil
    removeRods(player:FindFirstChild("StarterGear"))
    removeRods(player:FindFirstChildOfClass("Backpack"))
    removeRods(character)
    local starterGear = player:FindFirstChild("StarterGear")
    if starterGear then
        buildRod(rod, skin).Parent = starterGear
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        local tool = buildRod(rod, skin)
        tool.Parent = backpack
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if wasEquipped and humanoid then
            humanoid:EquipTool(tool)
        end
    end
end

------------------------------------------------------------ progression helpers
local function questProgress(f, stat, amount)
    local q = f.quests
    for _, entry in ipairs(q.list or {}) do
        local info = Config.quest(entry.id)
        if info and info.stat == stat and not entry.claimed then
            entry.p = math.min(info.goal, (entry.p or 0) + (amount or 1))
        end
    end
end

local function ensureQuests(player, f)
    local day = U.questDay()
    if f.quests.day ~= day or typeof(f.quests.list) ~= "table" then
        local list = {}
        for _, id in ipairs(U.pickQuests(player.UserId, day)) do
            table.insert(list, {id = id, p = 0, claimed = false})
        end
        f.quests = {day = day, list = list}
        return true
    end
    return false
end

local function addXp(f, amount)
    local before = U.levelFromXp(f.xp)
    f.xp += math.max(0, math.floor(amount))
    local after = U.levelFromXp(f.xp)
    f.level = after
    return after > before and after or nil
end

-- grants a reward table; returns a short list of what was given (for the popup / notice)
local function grant(player, client, f, reward)
    local lines = {}
    if reward.coins and reward.coins > 0 then
        pcall(function()
            client.player_controller:_add_coins(reward.coins)
        end)
        table.insert(lines, "+" .. NumberUtility.short(reward.coins) .. " Coins")
    end
    if reward.gems and reward.gems > 0 then
        pcall(PlayerRewardUtility.give, client, {{name = "Stat", props = {name = "Gems", value = reward.gems}}})
        table.insert(lines, "+" .. reward.gems .. " Gems")
    end
    if reward.bait and reward.count then
        f.bait[reward.bait] = (f.bait[reward.bait] or 0) + reward.count
        local b = Config.bait(reward.bait)
        table.insert(lines, "+" .. reward.count .. " " .. (b and b.name or reward.bait))
    end
    if reward.material and reward.count then
        f.materials[reward.material] = (f.materials[reward.material] or 0) + reward.count
        local mt = Config.material(reward.material)
        table.insert(lines, "+" .. reward.count .. " " .. (mt and mt.name or reward.material))
    end
    if reward.cosmetic then
        local c = Config.cosmetic(reward.cosmetic)
        if c and not f.cosmetics.owned[reward.cosmetic] then
            f.cosmetics.owned[reward.cosmetic] = true
            table.insert(lines, "New cosmetic: " .. c.name)
        elseif c then
            -- already owned: a duplicate cosmetic turns into Coins (never lost)
            pcall(function()
                client.player_controller:_add_coins(1000)
            end)
            table.insert(lines, "+1K Coins (duplicate " .. c.name .. ")")
        end
    end
    if reward.seedpack then
        local ok, given = pcall(PlayerRewardUtility.give, client, {{name = "SeedPack", props = {name = reward.seedpack, value = 1}}})
        if ok and given then
            table.insert(lines, "+1 Seed Pack")
        end
    end
    if reward.xp then
        local up = addXp(f, reward.xp)
        table.insert(lines, "+" .. reward.xp .. " Fishing XP")
        if up then
            notify(player, "🎣 Fishing Level " .. up .. "!", Color3.fromRGB(120, 220, 255))
        end
    end
    return lines
end

------------------------------------------------------------ catch choice
local function difficultyOf(info)
    return info.difficulty or Config.RARITIES[info.rarity].difficulty
end

local function canBite(fish, zoneId, baitId, rod, night)
    return table.find(fish.zones, zoneId) ~= nil and difficultyOf(fish) <= rod.max
        and (not fish.needs or fish.needs == baitId)
        and (baitId ~= "none" or fish.nobait == true)
        and not (fish.time == "night" and not night) and not (fish.time == "day" and night)
end

-- is there at least one FISH that can bite here with this bait / rod right now?
local function anyFish(zoneId, baitId, rod)
    local night = isNight()
    for _, fish in ipairs(Config.FISH) do
        if canBite(fish, zoneId, baitId, rod, night) then
            return true
        end
    end
    return false
end

local function chooseCatch(zoneId, baitId, rod)
    local night, raining = isNight(), isRaining()
    local pool = {}
    for _, fish in ipairs(Config.FISH) do
        if canBite(fish, zoneId, baitId, rod, night) then
            local w = Config.RARITIES[fish.rarity].weight * U.likeMultiplier(fish, baitId)
            if fish.nightBoost and night then
                w *= fish.nightBoost
            end
            if fish.rain and raining then
                w *= fish.rain
            end
            if fish.boost then
                w *= fish.boost
            end
            table.insert(pool, {weight = w, info = fish})
        end
    end
    -- treasure: a fixed share of all bites, wherever you fish
    local fishTotal = 0
    for _, e in ipairs(pool) do
        fishTotal += e.weight
    end
    for _, t in ipairs(Config.TREASURES) do
        if fishTotal > 0 and difficultyOf(t) <= rod.max then
            local share = t.share
            if baitId == "none" then
                share *= 0.3
            elseif t.chest and baitId == "golden" then
                share *= 2
            end
            table.insert(pool, {weight = fishTotal * share / math.max(1 - share, 0.5), info = t})
        end
    end
    local pick = pickWeighted(pool)
    return pick and pick.info or nil
end

------------------------------------------------------------ cast / bite / reel
local function finish(player, reason, extra)
    local state = states[player]
    if not state then
        return
    end
    states[player] = nil
    lastEnd[player] = os.clock()
    local payload = {token = state.token, reason = reason}
    for k, v in pairs(extra or {}) do
        payload[k] = v
    end
    Network.Remote.Fire("C_Fishing_End", player, payload)
end

-- a valid water point for this cast: the player's aim if it is real water in reach and inside the
-- same zone, otherwise the nearest water in front of the player (river line / pool centre)
local function bobberPoint(player, root, zone, rod, aim)
    -- the FIRST thing under the point must be water (no water hidden under ground or a dock)
    local ignore = {}
    for _, other in ipairs(Players:GetPlayers()) do
        if other.Character then
            table.insert(ignore, other.Character)
        end
    end
    local wildFolder = workspace:FindFirstChild("WildFruits")
    if wildFolder then
        table.insert(ignore, wildFolder)
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = false
    local function water(x, z)
        local hit = workspace:Raycast(Vector3.new(x, root.Position.Y + 15, z), Vector3.new(0, -40, 0), params)
        local isWater = hit and ((hit.Instance == workspace.Terrain and hit.Material == Enum.Material.Water) or hit.Instance:GetAttribute("FishingWater") == true)
        return if isWater then hit.Position else nil
    end
    if typeof(aim) == "Vector3" and aim == aim and aim.Magnitude < 1e6 then
        local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z).Magnitude
        if flat <= rod.cast and zoneAt(Vector3.new(aim.X, zone.Position.Y, aim.Z)) == zone then
            local p = water(aim.X, aim.Z)
            if p then
                return p
            end
        end
    end
    local waterX = tonumber(zone:GetAttribute("WaterX"))
    local pool = zone:GetAttribute("PoolCenter")
    if waterX then
        local side = if root.Position.X >= waterX then 1 else -1
        local halfWidth = tonumber(zone:GetAttribute("WaterHalfWidth")) or 6
        local x = waterX + side * rng:NextNumber(0, halfWidth * 0.6)
        local half = zone.Size.Z / 2 - 2
        local z = math.clamp(root.Position.Z + rng:NextNumber(-2, 2), zone.Position.Z - half, zone.Position.Z + half)
        return water(x, z)
    elseif typeof(pool) == "Vector3" then
        local radius = tonumber(zone:GetAttribute("PoolRadius")) or 4
        local dir = Vector3.new(root.Position.X - pool.X, 0, root.Position.Z - pool.Z)
        dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(1, 0, 0)
        local p = pool + dir * radius * rng:NextNumber(0.1, 0.5)
        return water(p.X, p.Z)
    end
    return nil
end

function Fishing.cast(player, aim)
    if not passRateLimit(player) then
        return false, "busy"
    end
    if states[player] then
        return false, "busy"
    end
    if lastEnd[player] and os.clock() - lastEnd[player] < Config.RECAST_COOLDOWN then
        return false, "cooldown"
    end
    local root = aliveRoot(player)
    if not root or not equippedRod(player) then
        return false, "rod"
    end
    local f, client = load(player)
    local rod = f and U.getRod(f)
    if not f or not rod then
        return false, "rod"
    end
    local zone = zoneAt(root.Position)
    local zoneInfo = zone and Config.zone(zone:GetAttribute("ZoneId") or "")
    if not zone or not zoneInfo then
        return false, "zone"
    end
    if rod.rank < zoneInfo.rod then
        return false, "zonelocked", Config.RODS[zoneInfo.rod].name
    end
    if #f.bag >= U.bagCapacity(f) then
        return false, "bagfull"
    end
    local baitId = f.selected_bait
    if baitId ~= "none" and (f.bait[baitId] or 0) < 1 then
        f.selected_bait = "none"
        save(client, f)
        return false, "nobait"
    end
    -- nothing can bite here with this bait: refuse BEFORE any Bait is used (and never hand out
    -- treasure-only casts, e.g. the Mystic Pool without bait)
    if not anyFish(zoneInfo.id, baitId, rod) then
        return false, "needbait"
    end
    local bobber = bobberPoint(player, root, zone, rod, aim)
    if not bobber or (bobber - root.Position).Magnitude > rod.cast + 8 then
        return false, "nowater"
    end
    -- the cast is valid: spend exactly one Bait now (a miss later still uses it)
    ensureQuests(player, f)
    if baitId ~= "none" then
        f.bait[baitId] -= 1
        questProgress(f, "bait", 1)
        if f.bait[baitId] <= 0 then
            f.bait[baitId] = nil
        end
    end
    f.casts += 1
    save(client, f)
    local catch = chooseCatch(zoneInfo.id, baitId, rod)
    if not catch then
        return false, "nowater"
    end
    tokenCounter += 1
    local token = tokenCounter
    local state = {phase = "waiting", token = token, bobber = bobber, catch = catch, bait = baitId, zone = zoneInfo.id, rod = rod}
    states[player] = state
    local liked = catch.likes and catch.likes[baitId] == "preferred"
    local delayTime = rng:NextNumber(Config.BITE_DELAY[1], Config.BITE_DELAY[2]) * rod.bite * (if liked then 0.85 else 1)
    task.delay(delayTime, function()
        if states[player] ~= state or state.phase ~= "waiting" then
            return
        end
        local window = Config.RARITIES[catch.rarity].window
        state.phase = "bite"
        state.biteEnd = os.clock() + window + Config.REACTION_EXTRA
        Network.Remote.Fire("C_Fishing_Bite", player, {token = token, window = window, rarity = catch.rarity})
        task.delay(window + Config.REACTION_EXTRA + 0.1, function()
            if states[player] == state and state.phase == "bite" then
                finish(player, "missed")
            end
        end)
    end)
    task.delay(30, function()
        if states[player] == state and state.phase ~= "reel" then
            finish(player, "timeout")
        end
    end)
    return true, {token = token, bobber = bobber, bait = baitId}
end

local function awardFish(player, state, perfect)
    local f, client = load(player)
    if not f then
        return {kind = "error"}
    end
    ensureQuests(player, f)
    local info = state.catch
    local r = rng:NextNumber() ^ 1.6
    local weight = math.floor((info.w[1] + (info.w[2] - info.w[1]) * r) * 10 + 0.5) / 10
    local value = U.value(info, weight, perfect)
    local uid = string.sub(HttpService:GenerateGUID(false), 1, 12)
    table.insert(f.bag, {u = uid, f = info.id, w = weight, v = value, q = if perfect then "perfect" else nil, t = os.time()})
    local j = f.journal[info.id] or {n = 0, best = 0}
    local newSpecies = (j.n or 0) == 0
    local record = not newSpecies and weight > (j.best or 0)
    local previousBest = j.best
    j.n = (j.n or 0) + 1
    j.best = math.max(j.best or 0, weight)
    f.journal[info.id] = j
    f.catches += 1
    -- materials
    local drops = {}
    for _, drop in ipairs({info.drop, Config.ZONE_DROPS[state.zone]}) do
        if drop and rng:NextNumber() < drop[2] then
            f.materials[drop[1]] = (f.materials[drop[1]] or 0) + 1
            local mt = Config.material(drop[1])
            table.insert(drops, mt and mt.name or drop[1])
        end
    end
    -- XP, quests
    local rarity = Config.RARITIES[info.rarity]
    local levelUp = addXp(f, rarity.xp * (if perfect then 1.25 else 1))
    questProgress(f, "catch", 1)
    if rarity.order >= 3 then
        questProgress(f, "rare", 1)
    end
    if weight >= 5 then
        questProgress(f, "heavy", 1)
    end
    if perfect then
        questProgress(f, "perfect", 1)
    end
    if isNight() then
        questProgress(f, "night", 1)
    end
    save(client, f)
    -- the server's biggest Rare+ catches (trophy board) + very rare announcements
    if rarity.order >= 3 then
        table.insert(trophies, {name = player.DisplayName, fish = info.name, weight = weight, order = rarity.order})
        table.sort(trophies, function(a, b)
            if a.order ~= b.order then
                return a.order > b.order
            end
            return a.weight > b.weight
        end)
        while #trophies > 5 do
            table.remove(trophies)
        end
        Fishing._updateTrophyBoard()
    end
    if rarity.order >= 5 then
        Network.Remote.FireAll("C_Notifications_Add", {text = "🎣 " .. player.DisplayName .. " caught a " .. weight .. "kg " .. info.name .. "!", color = rarity.color})
    end
    return {
        kind = "fish", id = info.id, name = info.name, rarity = info.rarity, weight = weight,
        tier = U.weightTier(info, weight), value = value, perfect = perfect, newSpecies = newSpecies,
        record = record, previousBest = previousBest, drops = drops, levelUp = levelUp,
        bag = #f.bag, bagSize = U.bagCapacity(f),
    }
end

local function awardTreasure(player, state, perfect)
    local f, client = load(player)
    if not f then
        return {kind = "error"}
    end
    ensureQuests(player, f)
    local info = state.catch
    local reward = {}
    if info.chest then
        reward.coins = rng:NextInteger(Config.CHEST.coins[1], Config.CHEST.coins[2])
        reward.gems = rng:NextInteger(Config.CHEST.gems[1], Config.CHEST.gems[2])
        local extra = pickWeighted(Config.CHEST.extra)
        for k, v in pairs(extra) do
            if k ~= "weight" then
                reward[k] = v
            end
        end
    else
        local loot = pickWeighted(Config.BAG_LOOT)
        for k, v in pairs(loot) do
            if k == "coins" then
                reward.coins = rng:NextInteger(v[1], v[2])
            elseif k ~= "weight" then
                reward[k] = v
            end
        end
    end
    reward.xp = Config.RARITIES[info.rarity].xp
    local lines = grant(player, client, f, reward)
    f.treasures += 1
    questProgress(f, "treasure", 1)
    save(client, f)
    if info.chest then
        Network.Remote.FireAll("C_Notifications_Add", {text = "🎁 " .. player.DisplayName .. " fished up a Treasure Chest!", color = Color3.fromRGB(255, 200, 80)})
    end
    return {kind = "treasure", id = info.id, name = info.name, chest = info.chest == true, rarity = info.rarity, lines = lines, perfect = perfect}
end

local function runReel(player, state)
    local reel = state.reel
    while states[player] == state and state.phase == "reel" do
        task.wait(0.1)
        if states[player] ~= state then
            return
        end
        if not aliveRoot(player) or not equippedRod(player) then
            finish(player, "cancel")
            return
        end
        local serverStep = math.floor((os.clock() - state.reelStart) / U.DT)
        local settled = serverStep - SETTLE_STEPS
        local sim = reel.sim
        while sim.step < settled and not sim.done do
            local nextStep = sim.step + 1
            while reel.inputs[reel.cursor] and reel.inputs[reel.cursor].step <= nextStep do
                reel.holding = reel.inputs[reel.cursor].holding
                reel.cursor += 1
            end
            U.stepReel(sim, reel.holding)
        end
        if sim.done then
            state.phase = "done"
            local result
            if sim.done == "caught" then
                local perfect = U.isPerfect(sim)
                local isTreasure = Config.get(Config.TREASURES, state.catch.id) ~= nil
                local ok, res = pcall(if isTreasure then awardTreasure else awardFish, player, state, perfect)
                result = if ok then res else {kind = "error"}
                if not ok then
                    warn("[Fishing] award failed:", res)
                end
            else
                result = {kind = "escaped"}
            end
            finish(player, if sim.done == "caught" then "caught" else "escaped", {result = result})
            return
        end
    end
end

function Fishing.hook(player)
    local state = states[player]
    if not state then
        return false, "idle"
    end
    if state.phase == "waiting" then
        finish(player, "early")
        return false, "early"
    end
    if state.phase ~= "bite" then
        return false, "busy"
    end
    if os.clock() > state.biteEnd then
        finish(player, "missed")
        return false, "missed"
    end
    local root = aliveRoot(player)
    if not root or not equippedRod(player) or (root.Position - state.bobber).Magnitude > state.rod.cast + 12 then
        finish(player, "cancel")
        return false, "cancel"
    end
    local seed = rng:NextInteger(1, 2 ^ 30)
    local rod = state.rod
    local params = {seed = seed, difficulty = difficultyOf(state.catch), zone = rod.zone, lift = rod.lift, stability = rod.stability}
    state.phase = "reel"
    state.reelStart = os.clock()
    state.reel = {sim = U.newReel(params), inputs = {}, cursor = 1, holding = false, lastStep = 0}
    task.spawn(runReel, player, state)
    return true, {token = state.token, params = params, settle = SETTLE_STEPS}
end

-- hold / release during the reel: {step, holding}. Steps are clamped to what the server can
-- still accept (never rewrites steps it already judged, never more than LEAD_STEPS ahead).
function Fishing.input(player, token, step, holding)
    local state = states[player]
    if not state or state.phase ~= "reel" or state.token ~= token or typeof(step) ~= "number" or typeof(holding) ~= "boolean" then
        return
    end
    local now = os.clock()
    local budget = inputBudget[player]
    if not budget or now - budget.t >= 1 then
        budget = {t = now, n = 0}
        inputBudget[player] = budget
    end
    budget.n += 1
    if budget.n > INPUTS_PER_SECOND then
        return
    end
    local reel = state.reel
    local serverStep = math.floor((now - state.reelStart) / U.DT)
    step = math.floor(step)
    step = math.clamp(step, math.max(reel.sim.step + 1, reel.lastStep, serverStep - SETTLE_STEPS + 1), serverStep + LEAD_STEPS)
    reel.lastStep = step
    table.insert(reel.inputs, {step = step, holding = holding})
end

function Fishing.cancel(player)
    finish(player, "cancel")
    return true
end

------------------------------------------------------------ menus / shop (server checked)
function Fishing.claimRod(player)
    if not passRateLimit(player) then
        return false
    end
    local f, client = load(player)
    if not f then
        return false
    end
    local first = not f.rods.starter
    if first then
        f.rods.starter = true
        f.rod = true
        f.rod_id = f.rod_id or "starter"
        f.bait.worm = (f.bait.worm or 0) + Config.STARTER_WORMS
        ensureQuests(player, f)
        save(client, f)
        notify(player, "🎣 You got a Starter Rod and " .. Config.STARTER_WORMS .. " Worms! Equip it and tap the water.", Color3.fromRGB(150, 210, 255))
    end
    giveRod(player, f)
    Network.Remote.Fire("C_Fishing_RodClaimed", player, {first = first})
    return true
end

local function selectBait(player, baitId)
    if typeof(baitId) ~= "string" or not Config.bait(baitId) or not passRateLimit(player, 0.15) then
        return false
    end
    local f, client = load(player)
    if not f then
        return false
    end
    if baitId ~= "none" and (f.bait[baitId] or 0) < 1 then
        return false, "none_left"
    end
    f.selected_bait = baitId
    save(client, f)
    return true
end

local function buyBait(player, index)
    local offer = typeof(index) == "number" and Config.BAIT_SHOP[index]
    if not offer or not passRateLimit(player) then
        return false, "invalid"
    end
    if not nearNpc(player) then
        return false, "distance"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    if f.level < offer.level then
        return false, "level"
    end
    local coins = client.data:Get({"stats", "Strength"})
    if typeof(coins) ~= "number" or coins < offer.price then
        return false, "afford"
    end
    client.data:Set({"stats", "Strength"}, coins - offer.price)
    f.bait[offer.bait] = (f.bait[offer.bait] or 0) + offer.count
    save(client, f)
    return true
end

local function craft(player, recipeId)
    local recipe = typeof(recipeId) == "string" and Config.recipe(recipeId)
    if not recipe or not passRateLimit(player) then
        return false, "invalid"
    end
    if not nearNpc(player) then
        return false, "distance"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    for mat, n in pairs(recipe.cost) do
        if (f.materials[mat] or 0) < n then
            return false, "materials"
        end
    end
    local coins = client.data:Get({"stats", "Strength"})
    if recipe.coins and (typeof(coins) ~= "number" or coins < recipe.coins) then
        return false, "afford"
    end
    if recipe.coins then
        client.data:Set({"stats", "Strength"}, coins - recipe.coins)
    end
    for mat, n in pairs(recipe.cost) do
        f.materials[mat] -= n
    end
    f.bait[recipe.gives.bait] = (f.bait[recipe.gives.bait] or 0) + recipe.gives.count
    save(client, f)
    return true
end

local function buyRod(player, rodId)
    local rod = typeof(rodId) == "string" and Config.rod(rodId)
    if not rod or not passRateLimit(player) then
        return false, "invalid"
    end
    if not nearNpc(player) then
        return false, "distance"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    if f.rods[rod.id] then
        return false, "owned"
    end
    if U.rodRank(f) ~= rod.rank - 1 then
        return false, "order"
    end
    if f.level < rod.level then
        return false, "level"
    end
    for mat, n in pairs(rod.materials or {}) do
        if (f.materials[mat] or 0) < n then
            return false, "materials"
        end
    end
    local coins = client.data:Get({"stats", "Strength"})
    if typeof(coins) ~= "number" or coins < rod.price then
        return false, "afford"
    end
    client.data:Set({"stats", "Strength"}, coins - rod.price)
    for mat, n in pairs(rod.materials or {}) do
        f.materials[mat] -= n
    end
    f.rods[rod.id] = true
    f.rod_id = rod.id
    save(client, f)
    giveRod(player, f)
    notify(player, "🎣 " .. rod.name .. " unlocked!", Color3.fromRGB(255, 215, 80))
    return true
end

local function sell(player, which)
    if not passRateLimit(player) then
        return false, "busy"
    end
    if not nearNpc(player) then
        return false, "distance"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    ensureQuests(player, f)
    local wanted = nil
    if which ~= "all" then
        if typeof(which) ~= "table" or #which == 0 or #which > 60 then
            return false, "invalid"
        end
        wanted = {}
        for _, uid in ipairs(which) do
            if typeof(uid) == "string" then
                wanted[uid] = true
            end
        end
    end
    local keep, total, sold = {}, 0, 0
    for _, entry in ipairs(f.bag) do
        if typeof(entry) == "table" and (wanted == nil or wanted[entry.u]) then
            if wanted then
                wanted[entry.u] = nil -- each uid sells at most once
            end
            total += math.max(0, math.floor(tonumber(entry.v) or 0))
            sold += 1
        else
            table.insert(keep, entry)
        end
    end
    if sold == 0 then
        return false, "empty"
    end
    f.bag = keep
    questProgress(f, "sell", sold)
    save(client, f)
    pcall(function()
        client.player_controller:_add_coins(total)
    end)
    return true, total, sold
end

local function claimCollection(player, id)
    local col = typeof(id) == "string" and Config.collection(id)
    if not col or not passRateLimit(player) then
        return false, "invalid"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    if f.claimed[col.id] then
        return false, "claimed"
    end
    local done = if col.need == "all" then U.discoveredCount(f) >= #Config.FISH else U.collectionDone(f, col)
    if not done then
        return false, "incomplete"
    end
    f.claimed[col.id] = true -- mark first: a reward can only ever be given once
    local lines = grant(player, client, f, col.reward)
    save(client, f)
    return true, lines
end

local function claimQuest(player, index)
    if typeof(index) ~= "number" or not passRateLimit(player) then
        return false, "invalid"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    if ensureQuests(player, f) then
        save(client, f)
        return false, "expired"
    end
    local entry = f.quests.list[index]
    local info = entry and Config.quest(entry.id)
    if not info or entry.claimed or (entry.p or 0) < info.goal then
        return false, "incomplete"
    end
    entry.claimed = true
    local lines = grant(player, client, f, info.reward)
    save(client, f)
    return true, lines
end

local function buyCosmetic(player, id)
    local c = typeof(id) == "string" and Config.cosmetic(id)
    if not c or not c.price or not passRateLimit(player) then
        return false, "invalid"
    end
    if not nearNpc(player) then
        return false, "distance"
    end
    local f, client = load(player)
    if not f then
        return false, "invalid"
    end
    if f.cosmetics.owned[c.id] then
        return false, "owned"
    end
    if (c.level and f.level < c.level) or (c.catches and f.catches < c.catches) then
        return false, "locked"
    end
    local coins = client.data:Get({"stats", "Strength"})
    if typeof(coins) ~= "number" or coins < c.price then
        return false, "afford"
    end
    client.data:Set({"stats", "Strength"}, coins - c.price)
    f.cosmetics.owned[c.id] = true
    save(client, f)
    return true
end

local function equipCosmetic(player, id)
    local c = typeof(id) == "string" and Config.cosmetic(id)
    if not c or not passRateLimit(player, 0.15) then
        return false
    end
    local f, client = load(player)
    if not f or not f.cosmetics.owned[c.id] then
        return false
    end
    f.cosmetics[c.slot] = c.id
    save(client, f)
    if c.slot == "skin" then
        giveRod(player, f)
    end
    return true
end

function Fishing._updateTrophyBoard()
    local w = world()
    local hub = w and w:FindFirstChild("FishingHub")
    local board = hub and hub:FindFirstChild("TrophyBoard", true)
    local gui = board and board:FindFirstChildOfClass("SurfaceGui")
    if not gui then
        return
    end
    for i = 1, 5 do
        local line = gui:FindFirstChild("Line" .. i, true)
        if line then
            local t = trophies[i]
            line.Text = if t then (i .. ". " .. t.fish .. " " .. t.weight .. "kg - " .. t.name) else (i .. ". ---")
        end
    end
end

local function connectRodGivers()
    local w = world()
    for _, d in ipairs(w and w:GetDescendants() or {}) do
        if d:IsA("BasePart") and d:GetAttribute("FishingRodGiver") and not d:FindFirstChildOfClass("ProximityPrompt") then
            local prompt = Instance.new("ProximityPrompt")
            prompt.ActionText = "Get Fishing Rod"
            prompt.ObjectText = "Free Fishing Rod"
            prompt.MaxActivationDistance = 10
            prompt.RequiresLineOfSight = false
            prompt.KeyboardKeyCode = Enum.KeyCode.E
            prompt.Parent = d
            prompt.Triggered:Connect(function(player)
                Fishing.claimRod(player)
            end)
        end
    end
end

local function syncPlayer(player)
    for _ = 1, 60 do
        local f, client = load(player)
        if f then
            local changed = ensureQuests(player, f)
            if f.rod_id then
                giveRod(player, f)
            end
            -- write the normalized shape once so clients always read the full structure
            if changed or typeof(client.data:Get("fishing")) ~= "table" or client.data:Get({"fishing", "cosmetics"}) == nil then
                save(client, f)
            end
            return
        end
        task.wait(0.5)
        if not player.Parent then
            return
        end
    end
end

function Fishing._init()
    Network = _L.Get {"Common", "Library", "Network"}
    Config = _L.Get {"Common", "Modules", "Databases", "Fishing"}
    U = _L.Get {"Common", "Modules", "Utilities", "FishingUtility"}
    PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
    NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
end

function Fishing._start()
    Network.Remote.Invoked("S_Fishing_Cast", Fishing.cast)
    Network.Remote.Invoked("S_Fishing_Hook", Fishing.hook)
    Network.Remote.Invoked("S_Fishing_Cancel", Fishing.cancel)
    Network.Remote.Fired("S_Fishing_Input", Fishing.input)
    Network.Remote.Invoked("S_Fishing_SelectBait", selectBait)
    Network.Remote.Invoked("S_Fishing_BuyBait", buyBait)
    Network.Remote.Invoked("S_Fishing_Craft", craft)
    Network.Remote.Invoked("S_Fishing_BuyRod", buyRod)
    Network.Remote.Invoked("S_Fishing_Sell", sell)
    Network.Remote.Invoked("S_Fishing_ClaimCollection", claimCollection)
    Network.Remote.Invoked("S_Fishing_ClaimQuest", claimQuest)
    Network.Remote.Invoked("S_Fishing_BuyCosmetic", buyCosmetic)
    Network.Remote.Invoked("S_Fishing_EquipCosmetic", equipCosmetic)
    Network.Remote.Invoked("S_Fishing_TutorialDone", function(player)
        local f, client = load(player)
        if f and not f.tutorial then
            f.tutorial = true
            save(client, f)
        end
        return true
    end)
    Network.Remote.Invoked("S_Fishing_Refresh", function(player)
        -- makes sure today's quests exist (the menu calls this when it opens)
        local f, client = load(player)
        if f and ensureQuests(player, f) then
            save(client, f)
        end
        return true
    end)
    connectRodGivers()
    Fishing._updateTrophyBoard()
    local function onPlayer(player)
        task.spawn(syncPlayer, player)
        player.CharacterAdded:Connect(function(character)
            finish(player, "cancel")
            local humanoid = character:WaitForChild("Humanoid", 10)
            if humanoid then
                humanoid.Died:Connect(function()
                    finish(player, "cancel")
                end)
            end
        end)
        player.CharacterRemoving:Connect(function()
            finish(player, "cancel")
        end)
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayer(player)
    end
    Players.PlayerRemoving:Connect(function(player)
        states[player] = nil
        lastEnd[player] = nil
        lastRequest[player] = nil
        inputBudget[player] = nil
    end)
end

return Fishing
