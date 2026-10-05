-- // VARIABLES // --
local _L = _G._L

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Farm
local FarmUpgrades
local Network
local SeedPacks
local TableUtility
local TitleUtility
local UpgradeTreeUtility

local PlantBuilder
local FruitUtility
local GardenFloor

local PACK_DISTANCE = 16
-- Free planting: Seeds go anywhere on the player's OWN unlocked soil (FarmUpgrades.soil)
local PLANT_DISTANCE = 30 -- studs (flat) between the character and the spot it plants on
local MIN_SPACING = 4.5 -- studs between crop centres (a mature crop's soil disc is ~5 wide)
local EDGE_MARGIN = 2 -- keep crop centres this far inside the soil bed edges
local SOIL_HEIGHT = 0.4 -- soil surface above the plot ground
local GROUND = 0.5 -- plot ground above the plot base centre (FarmBuilder.GROUND; was 1 before the V1.1 cleanup)
local MAX_CROPS = 250 -- hard cap per player (spoofed requests can never spawn unlimited models)
local REQUEST_COOLDOWN = 0.35
local LEGACY_SLOTS = 6 -- old saves: seed_crops["1".."6"] were the 6 starter slots
-- chance per successful manual harvest of a mature crop to also find +1 Seed of that crop
local HARVEST_SEED_DROP_CHANCE = 0.005
local harvestRandom = Random.new()
local sizeRandom = Random.new()
-- seconds between overgrowth updates of mature crops (size / weight / value)
local OVERGROW_TICK = 5
local FarmingV2 = {}
local lastRequest = {}
local models = {}

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
Allows a bounded rate of farming requests.
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
Returns a safe clone of a saved dictionary.
@param value any -- Potential legacy profile value.
@return table -- Independent dictionary.
]]
local function cloneTableOrEmpty(value)
    if typeof(value) ~= "table" then
        return {}
    end
    return TableUtility.deep.clone(value)
end

--[[
Normalizes a saved count without accepting NaN or infinity.
@param value any -- Potential saved number.
@return number -- Nonnegative integer.
]]
local function nonnegativeInteger(value)
    if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
        return 0
    end
    return math.max(0, math.floor(value))
end

--[[
Returns the Seed Shop interaction point.
@return BasePart? -- NPC root part.
]]
local function seedShopRoot()
    local map = workspace:FindFirstChild("__MAP")
    local village = map and map:FindFirstChild("Village")
    local shops = village and village:FindFirstChild("Shops")
    local shop = shops and shops:FindFirstChild("Seed Shop")
    local npc = shop and shop:FindFirstChild("Gardener_Seed")
    return (npc and (npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Torso") or npc:FindFirstChildWhichIsA("BasePart"))) or (shop and shop:FindFirstChildWhichIsA("BasePart", true)) or nil
end

--[[
Checks a living character against a world interaction point.
@param player Player -- Requesting player.
@param point Vector3 -- Interaction position.
@param maximum number -- Maximum distance.
@return boolean -- Whether the player is eligible.
]]
local function isNear(player, point, maximum)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and humanoid.Health > 0 and root ~= nil and (root.Position - point).Magnitude <= maximum
end

--[[
Every land plot's soil in PLOT space (x / z relative to the player's plot base).
@param upgrades table -- data farm.upgrades ([id] = true when owned); nil = every plot.
@return table -- {id, cx, cz, hx, hz, top}
]]
local function soilRects(upgrades, floor2)
    local list = {}
    for _, info in ipairs(FarmUpgrades) do
        if info.soil and (upgrades == nil or upgrades[info.id] == true) then
            table.insert(list, {
                id = info.id,
                cx = info.at.X,
                cz = info.at.Z,
                hx = info.soil.X / 2,
                hz = info.soil.Z / 2,
                top = info.at.Y + GROUND + SOIL_HEIGHT,
            })
        end
    end
    -- Second Garden Floor beds: every bed when listing all land (upgrades == nil), otherwise
    -- only when this player bought the floor (floor2 == true). Its x / z never overlap ground soil.
    if upgrades == nil or floor2 == true then
        for _, bed in ipairs(GardenFloor.beds) do
            table.insert(list, {
                id = bed.id,
                floor = 2,
                cx = bed.at.X,
                cz = bed.at.Z,
                hx = bed.soil.X / 2,
                hz = bed.soil.Z / 2,
                top = bed.at.Y + 1 + SOIL_HEIGHT,
            })
        end
    end
    return list
end

--[[
Finds the soil bed containing a plot-space point.
@param list table -- soilRects result.
@param x number -- Plot-space X.
@param z number -- Plot-space Z.
@param margin number -- Distance the point must keep from the bed edges.
@return table? -- Soil rect.
]]
local function soilAt(list, x, z, margin)
    for _, soil in ipairs(list) do
        if math.abs(x - soil.cx) <= soil.hx - margin and math.abs(z - soil.cz) <= soil.hz - margin then
            return soil
        end
    end
    return nil
end

--[[
Returns the player's farm state and the soil they own.
@param player Player -- Plot owner.
@return table? -- Farm state.
@return table -- Owned soil rects.
]]
local function ownedSoil(player)
    local state = Farm._farms[player]
    if not state then
        return nil, {}
    end
    return state, soilRects(state.data:Get({"farm", "upgrades"}) or {}, state.data:Get("garden_floor2") == true)
end

--[[
Plot-space position of an old slot-based crop (the 6 starter slots, before free planting).
@param index number -- Slot 1..6.
@return number, number -- x, z.
]]
local function legacySlotPosition(index)
    local starterAt = Vector3.new(0, 0, 42)
    for _, info in ipairs(FarmUpgrades) do
        if info.id == "starter" then
            starterAt = info.at
        end
    end
    local column = (index - 1) % 3
    local row = math.floor((index - 1) / 3)
    return starterAt.X + (column - 1) * 6, starterAt.Z + (row - 0.5) * 5
end

--[[
World position of a saved crop's spot on the soil surface.
@param state table -- Farm state.
@param entry table -- Saved crop ({x, z} in plot space).
@return Vector3 -- Soil surface point.
]]
local function cropSurface(state, entry)
    local soil = soilAt(soilRects(nil), entry.x, entry.z, 0)
    local top = if soil then soil.top else GROUND + SOIL_HEIGHT
    return state.plot.cf * Vector3.new(entry.x, top, entry.z)
end

--[[
Folder holding the player's planted crops on their plot.
@param state table -- Farm state.
@return Folder -- Crops folder.
]]
local function cropsFolder(state)
    local built = state.plot.model:FindFirstChild("Built")
    local folder = built:FindFirstChild("SeedCrops")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "SeedCrops"
        folder.Parent = built
    end
    return folder
end

--[[
A finite plot coordinate (saved crop position).
@param value any -- Potential saved number.
@return boolean -- Whether it is usable.
]]
local function isCoordinate(value)
    return typeof(value) == "number" and value == value and math.abs(value) < 1e4
end

--[[
Rolls one Seed from a server-owned pack distribution.
@param data table -- Existing profile data wrapper.
@param pack table -- Seed Pack configuration.
@return string -- Rolled Seed identifier.
]]
local function rollSeed(data, pack)
    local luck = UpgradeTreeUtility.getLuckMultiplier(data) * TitleUtility.getMultiplier(data, "luck")
    if typeof(luck) ~= "number" or luck ~= luck or math.abs(luck) == math.huge then
        luck = 1
    end
    luck = math.clamp(luck, 1, 3)
    local weights = {}
    local total = 0
    for _, entry in ipairs(pack.entries) do
        local weight = entry.chance
        if entry.chance < 20 then
            weight *= luck
        end
        total += weight
        table.insert(weights, {seed_id = entry.seed_id, weight = weight})
    end
    local cursor = Random.new():NextNumber(0, total)
    for _, entry in ipairs(weights) do
        cursor -= entry.weight
        if cursor <= 0 then
            return entry.seed_id
        end
    end
    return weights[#weights].seed_id
end

--[[
Returns serializable Seed and garden state for the client.
@param player Player -- Profile owner.
@return table? -- Seed state.
]]
local function getState(player)
    local controller = getController(player)
    if not controller then
        return nil
    end
    local data = controller._data
    local packs = {}
    for _, pack in pairs(SeedPacks.Packs) do
        table.insert(packs, {
            id = pack.id,
            visual = pack.visual,
            display_name = pack.display_name,
            price = pack.price,
            rolls = pack.rolls,
        })
    end
    table.sort(packs, function(a, b)
        return a.price < b.price
    end)
    return {
        packs = packs,
        inventory = cloneTableOrEmpty(data:Get("seed_inventory")),
        crops = cloneTableOrEmpty(data:Get("seed_crops")),
        now = os.time(),
    }
end

--[[
Returns the live crop growth multiplier: equipped Fruits x Growth potion x Sprinklers.
SeedPacks.getGrowthMultiplier is shared with the client crop timer, so the countdown
can never disagree with the real growth result.
@param player Player -- Crop owner.
@return number -- Multiplier >= 1.
]]
local function growthMultiplier(player)
    local controller = getController(player)
    if not controller then
        return 1
    end
    local ok, mult = pcall(SeedPacks.getGrowthMultiplier, controller._data)
    if not ok or typeof(mult) ~= "number" or mult ~= mult or math.abs(mult) == math.huge or mult < 1 then
        return 1
    end
    return mult
end

--[[
Places a crop model so its visual bottom rests exactly on the soil surface point,
keeping X/Z centred. Measures the model's REAL (already scaled) bounding box instead
of a hardcoded Y offset, so every crop size, growth stage and restored crop sits flush.
@param model Model -- Crop model.
@param slotTop Vector3 -- Soil surface point under the crop.
@param scale number -- Growth scale (0.28 immature, 1 mature).
]]
local function placeCrop(model, slotTop, scale)
    model:ScaleTo(scale)
    local bboxCF, bboxSize = model:GetBoundingBox()
    -- exact lowest point of the (possibly tilted) bounding box
    local half = bboxSize / 2
    local minY = math.huge
    for sx = -1, 1, 2 do
        for sy = -1, 1, 2 do
            for sz = -1, 1, 2 do
                local cornerY = (bboxCF * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)).Y
                if cornerY < minY then
                    minY = cornerY
                end
            end
        end
    end
    -- translate the pivot by the same delta: bbox bottom-centre lands on the
    -- soil surface and the crop stays centred over its spot
    local delta = Vector3.new(slotTop.X - bboxCF.Position.X, slotTop.Y - minY, slotTop.Z - bboxCF.Position.Z)
    if delta.X ~= delta.X or delta.Y ~= delta.Y or delta.Z ~= delta.Z or delta.Magnitude == math.huge then
        -- invalid bounding box: fall back to the PlantBuilder pivot height (2.75 above the ground)
        warn("[FarmingV2] invalid crop bounding box, using fallback placement", model:GetFullName())
        model:PivotTo(CFrame.new(slotTop + Vector3.new(0, 2.75 * scale, 0)))
        return
    end
    model:PivotTo(model:GetPivot() + delta)
end

--[[
Optional authored crop model: ReplicatedStorage.Assets.Crops.<folder>.<stage> (see SeedPacks.CROP_ASSETS).
@param seed table -- Seed configuration.
@param stage string -- "Stage1".."Stage3", "Mature" or "Harvested".
@return Model? -- Fresh clone ready to parent, or nil when that model does not exist.
]]
local function assetModel(seed, stage)
    local folderName = SeedPacks.CROP_ASSETS and SeedPacks.CROP_ASSETS[seed.id]
    local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
    local crops = assets and assets:FindFirstChild("Crops")
    local folder = crops and folderName and crops:FindFirstChild(folderName)
    local template = folder and folder:FindFirstChild(stage)
    if not template or not template:IsA("Model") or not template.PrimaryPart then
        return nil
    end
    local model = template:Clone()
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false -- crops never block walking; the PrimaryPart is the tap target
        elseif part:IsA("Script") or part:IsA("LocalScript") then
            part:Destroy() -- crop models never carry their own scripts
        end
    end
    return model
end

--[[
Which visual stage a saved crop shows right now.
@return string -- "Stage1".."Stage3", "Mature" or "Harvested".
]]
local function cropStage(entry, seed, readyAt, now)
    if now >= readyAt then
        return "Mature"
    end
    if entry.state == "regrowing" then
        return "Harvested"
    end
    local total = math.max(readyAt - entry.planted_at, 1)
    local progress = math.clamp((now - entry.planted_at) / total, 0, 0.999)
    local stages = SeedPacks.CROP_STAGES
    return stages[math.floor(progress * #stages) + 1]
end

--[[
Ready timestamp of a saved crop with this player's live growth boost.
]]
local function readyAtFor(player, entry, seed)
    return SeedPacks.getReadyAt(entry, seed, growthMultiplier(player))
end

--[[
Marks a planted crop ready for the existing harvest system (re-checks the save first).
@param player Player -- Crop owner.
@param key string -- seed_crops key.
]]
local function mature(player, key)
    local controller = getController(player)
    local state = Farm._farms[player]
    local model = models[player] and models[player][key]
    if not controller or not state or not model or not model.Parent then
        return
    end
    local entry = (controller._data:Get("seed_crops") or {})[key]
    local seed = typeof(entry) == "table" and typeof(entry.seed_id) == "string" and SeedPacks.getSeed(entry.seed_id) or nil
    if not seed or not isCoordinate(entry.x) or not isCoordinate(entry.z) then
        return
    end
    local readyAt = readyAtFor(player, entry, seed)
    if not readyAt or os.time() < readyAt then
        return
    end
    if model:GetAttribute("Stage") ~= "Mature" then
        -- swap to the mature model (buildCrop builds it mature now and calls mature again)
        FarmingV2._rebuild(player, key)
        return
    end
    entry = FarmingV2._saveMaturity(player, key, readyAt) or entry
    model:SetAttribute("Stage", "Mature")
    model:SetAttribute("Mature", true)
    -- a mature Glow Mushroom softly glows (one small light, nicest at night)
    if seed.id == "glow_mushroom" and model.PrimaryPart and not model.PrimaryPart:FindFirstChild("MushroomGlow") then
        local glow = Instance.new("PointLight")
        glow.Name = "MushroomGlow"
        glow.Color = seed.fruit
        glow.Brightness = 0.7
        glow.Range = 7
        glow.Shadows = false
        glow.Parent = model.PrimaryPart
    end
    -- size / weight / value right now, re-seated on the soil so it never floats or sinks
    FarmingV2._overgrow(player, key, model, entry, seed, os.time(), true)
    CollectionService:AddTag(model, "HarvestBush")
end

--[[
Builds one saved crop at its saved spot on the player's plot.
@param player Player -- Crop owner.
@param key string -- seed_crops key (legacy "1".."6" or a generated id).
@param entry table -- Saved crop state {seed_id, planted_at, x, z, floor?, state?, ...}.
]]
local function buildCrop(player, key, entry)
    local state = Farm._farms[player]
    local seed = typeof(entry.seed_id) == "string" and SeedPacks.getSeed(entry.seed_id) or nil
    local plantedAt = entry.planted_at
    if not state or not seed or typeof(plantedAt) ~= "number" or plantedAt ~= plantedAt or math.abs(plantedAt) == math.huge
        or not isCoordinate(entry.x) or not isCoordinate(entry.z) then
        return
    end
    local readyAt = readyAtFor(player, entry, seed)
    if not readyAt then
        return
    end
    models[player] = models[player] or {}
    if models[player][key] then
        models[player][key]:Destroy()
    end
    local now = os.time()
    local stage = cropStage(entry, seed, readyAt, now)
    local model = assetModel(seed, stage)
    local authored = model ~= nil
    if not model then
        -- one single plant per crop, with its own model for every growth stage
        model = PlantBuilder.buildCrop(seed, stage)
    end
    local roll = SeedPacks.getSizeRoll(entry)
    model.Name = "SeedCrop_" .. key
    model:SetAttribute("Owner", player.UserId)
    model:SetAttribute("Garden", 0)
    -- 1 Seed = 1 Plant = 1 Harvest: one pick empties the crop and gives Yield crop items
    model:SetAttribute("Fruits", 1)
    model:SetAttribute("Yield", SeedPacks.HARVEST_UNITS)
    -- size / weight / value of THIS crop (overgrowth keeps them growing once it is mature)
    model:SetAttribute("SizeRoll", roll)
    model:SetAttribute("SizeLabel", SeedPacks.getSizeLabel(roll))
    model:SetAttribute("Weight", SeedPacks.getWeight(seed, roll))
    model:SetAttribute("SellValue", SeedPacks.getSellValue(seed, SeedPacks.getWeight(seed, roll)))
    model:SetAttribute("FoodRarity", "Common")
    model:SetAttribute("FixedFood", seed.plant_name)
    -- farm bonuses (Market Stand, Golden Fountain...): Farm.applyEffects keeps this current
    model:SetAttribute("CoinMultiplier", 1 + (Farm.getEffects(state).farm_value or 0))
    model:SetAttribute("SeedCropSlot", key)
    model:SetAttribute("SeedId", seed.id)
    model:SetAttribute("Authored", authored or nil)
    -- every crop model changes with its growth stage (the heartbeat rebuilds it)
    model:SetAttribute("Staged", true)
    model:SetAttribute("Stage", stage)
    -- the free starter Clover: tutorial step 5 waits for the player's OWN planted crop instead
    model:SetAttribute("TutorialCrop", entry.tutorial == true or nil)
    -- server growth timestamps for the client's visual-only timer (SeedPacks.getReadyAt)
    model:SetAttribute("PlantedAt", plantedAt)
    model:SetAttribute("GrowthTime", seed.growth_time)
    model:SetAttribute("WaterCredit", entry.water_credit)
    model:SetAttribute("WaterCount", entry.water_count)
    model:SetAttribute("CropState", entry.state)
    model:SetAttribute("QuickGrow", entry.quick == true or nil)
    model:SetAttribute("RegrowReadyAt", entry.regrow_ready_at)
    model:SetAttribute("Regrowable", seed.is_regrowable == true or nil)
    CollectionService:AddTag(model, "SeedCrop")
    model.Parent = cropsFolder(state)
    models[player][key] = model
    -- Live growth: Fruits / potion / Sprinklers / Watering Can speed crops up. The shared
    -- heartbeat in _start matures them when SeedPacks.getReadyAt passes -- online, after Fruit
    -- swaps, or across rejoin (offline time is credited by os.time).
    if now >= readyAt then
        mature(player, key)
    else
        -- growing: the stage model shows how far it is, the size roll how big it will be
        placeCrop(model, cropSurface(state, entry), roll)
    end
end

--[[
Saves when a crop became mature (the start of its overgrowth), once per growth cycle. Saved
instead of recomputed, so swapping Fruits (growth speed) later never shrinks a mature crop.
Old saves (crops planted before sizes existed, the tutorial Clover) start at normal size and
overgrow from now, so nobody gets a giant crop just from an old save.
@param player Player -- Crop owner.
@param key string -- seed_crops key.
@param readyAt number -- Ready timestamp.
@return table? -- The saved entry.
]]
function FarmingV2._saveMaturity(player, key, readyAt)
    local controller = getController(player)
    if not controller then
        return nil
    end
    local data = controller._data
    local crops = cloneTableOrEmpty(data:Get("seed_crops"))
    local entry = crops[key]
    if typeof(entry) ~= "table" then
        return nil
    end
    local now = os.time()
    local changed = false
    local legacy = entry.size == nil or entry.tutorial == true
    if entry.size == nil then
        entry.size = 1
        changed = true
    end
    local matured = entry.matured_at
    if typeof(matured) ~= "number" or matured ~= matured or math.abs(matured) == math.huge or matured > now then
        entry.matured_at = if legacy then now else math.clamp(math.floor(readyAt), 0, now)
        changed = true
    end
    if changed then
        crops[key] = entry
        data:Set("seed_crops", crops)
    end
    return entry
end

--[[
Records a crop weight as the player's heaviest crop if it beats it ("Heaviest Crop" leaderboard).
@param player Player -- Crop owner.
@param weight number -- Crop weight in kg.
@param seedId string -- Seed of that crop.
@return boolean -- Whether it is a new record.
]]
function FarmingV2.recordWeight(player, weight, seedId)
    local controller = getController(player)
    if not controller or typeof(weight) ~= "number" or weight ~= weight or weight <= 0 or weight > 1e6 then
        return false
    end
    local data = controller._data
    local best = data:Get("heaviest_crop")
    local bestWeight = typeof(best) == "table" and tonumber(best.weight) or 0
    if weight <= bestWeight then
        return false
    end
    data:Set("heaviest_crop", {weight = weight, seed_id = seedId, at = os.time()})
    return true
end

--[[
Overgrowth of a mature crop: updates its size, weight and sell value from the server clock and
rescales the model (up to VISUAL_SCALE_MAX). Mature crops keep growing until they are harvested.
@param player Player -- Crop owner.
@param key string -- seed_crops key.
@param model Model -- Crop model.
@param entry table -- Saved crop.
@param seed table -- Seed configuration.
@param now number -- os.time().
@param force boolean? -- Re-seat the model even when its scale did not change.
]]
function FarmingV2._overgrow(player, key, model, entry, seed, now, force)
    local state = Farm._farms[player]
    if not state or not model.Parent then
        return
    end
    local roll = SeedPacks.getSizeRoll(entry)
    local size = SeedPacks.getSize(roll, entry.matured_at, now)
    local weight = SeedPacks.getWeight(seed, size)
    if model:GetAttribute("Weight") ~= weight then
        model:SetAttribute("Weight", weight)
        model:SetAttribute("SellValue", SeedPacks.getSellValue(seed, weight))
    end
    model:SetAttribute("MaturedAt", entry.matured_at)
    local scale = math.min(size, SeedPacks.VISUAL_SCALE_MAX)
    if force or math.abs(model:GetScale() - scale) >= 0.01 then
        placeCrop(model, cropSurface(state, entry), scale)
    end
    -- the tutorial crop never counts for the leaderboard
    if not entry.tutorial then
        FarmingV2.recordWeight(player, weight, seed.id)
    end
end

--[[
Rebuilds one crop from its save (visual stage change / after a harvest of a regrowable crop).
]]
function FarmingV2._rebuild(player, key)
    local controller = getController(player)
    local entry = controller and (controller._data:Get("seed_crops") or {})[key]
    if typeof(entry) == "table" then
        buildCrop(player, key, entry)
    end
end

--[[
Rebuilds persisted crops after the farm is assigned.
@param player Player -- Profile owner.
]]
local function syncPlayer(player)
    for _ = 1, 60 do
        if Farm._farms[player] and getController(player) then
            break
        end
        task.wait(0.5)
        if not player.Parent then
            return
        end
    end
    local controller = getController(player)
    if not controller or not Farm._farms[player] then
        return
    end
    local data = controller._data
    local crops = cloneTableOrEmpty(data:Get("seed_crops"))
    local changed = false
    if next(crops) == nil and nonnegativeInteger(data:Get({"stats", "Food_Collected"})) <= 0 and nonnegativeInteger(data:Get("seed_planted_count")) <= 0 then
        crops["1"] = {seed_id = "clover", planted_at = 0, tutorial = true, size = 1}
        changed = true
    end
    -- Legacy saves: crops in the old 6 starter slots ("1".."6") get their slot's plot position.
    -- Same key, same entry, nothing removed: the crop stays exactly where it was (no duplicates).
    for key, entry in pairs(crops) do
        local index = tonumber(key)
        if typeof(entry) == "table" and (not isCoordinate(entry.x) or not isCoordinate(entry.z))
            and index and index % 1 == 0 and index >= 1 and index <= LEGACY_SLOTS then
            entry.x, entry.z = legacySlotPosition(index)
            changed = true
        end
    end
    if changed then
        data:Set("seed_crops", crops)
    end
    for key, entry in pairs(crops) do
        if typeof(key) == "string" and typeof(entry) == "table" then
            buildCrop(player, key, entry)
        end
    end
    -- tutorial fallback: where this player's starter soil is, for clients that have not
    -- streamed the farm in yet (phones stream a smaller radius)
    local state = Farm._farms[player]
    local starterSoil = state and soilRects({starter = true})[1]
    if starterSoil then
        player:SetAttribute("GuideFarm", state.plot.cf * Vector3.new(starterSoil.cx, starterSoil.top, starterSoil.cz))
    end
end

--[[
Publishes the fixed tutorial target positions (Crop Seller, Seed Shop, Farm Egg) so the
client Guide can point at them even while they are outside its streaming radius.
]]
local function publishGuideTargets()
    local shop = seedShopRoot()
    if shop then
        workspace:SetAttribute("GuideSeedShop", shop.Position)
    end
    for _, npc in ipairs(CollectionService:GetTagged("Gardener")) do
        local ok, pivot = pcall(npc.GetPivot, npc)
        if ok and npc:IsDescendantOf(workspace) then
            workspace:SetAttribute("GuideSell", pivot.Position)
            break
        end
    end
    local map = workspace:FindFirstChild("__MAP")
    local eggs = map and map:FindFirstChild("Eggs")
    local EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
    for _, egg in ipairs(eggs and eggs:GetChildren() or {}) do
        local ok, approved = pcall(EggUtility.isContentApproved, egg.Name)
        if ok and approved then
            local okPivot, pivot = pcall(egg.GetPivot, egg)
            if okPivot then
                workspace:SetAttribute("GuideEgg", pivot.Position)
                break
            end
        end
    end
end

--[[
Purchases and opens a Seed Pack using server-owned odds.
@param player Player -- Requesting player.
@param packId string -- Pack identifier.
@return boolean -- Whether the purchase succeeded.
@return any -- Result list or error code.
]]
local function buyPack(player, packId)
    if typeof(packId) ~= "string" or #packId > 40 or not passRateLimit(player) then
        return false, "invalid"
    end
    local pack = SeedPacks.getPack(packId)
    if not pack then
        return false, "invalid"
    end
    local shop = seedShopRoot()
    local controller = getController(player)
    if not shop or not controller or not isNear(player, shop.Position, PACK_DISTANCE) then
        return false, "distance"
    end
    local data = controller._data
    local balance = data:Get({"stats", pack.currency})
    if typeof(balance) ~= "number" or balance ~= balance or math.abs(balance) == math.huge or balance < pack.price then
        return false, "afford"
    end
    local results = {}
    local inventory = cloneTableOrEmpty(data:Get("seed_inventory"))
    for _ = 1, pack.rolls do
        local seedId = rollSeed(data, pack)
        inventory[seedId] = nonnegativeInteger(inventory[seedId]) + 1
        table.insert(results, seedId)
    end
    data:Set({"stats", pack.currency}, balance - pack.price)
    data:Set("seed_inventory", inventory)
    if packId == "starter" and data:Get("tutorial_marker") == 3 then
        data:Set("tutorial_marker", 4)
    end
    return true, results
end

--[[
Plants an owned Seed at a requested spot on the player's own unlocked soil.
The client only suggests the spot; every rule is checked here before a Seed is spent.
@param player Player -- Requesting player.
@param seedId string -- Owned Seed identifier.
@param position Vector3 -- World point the player aimed / tapped at.
@return boolean -- Whether planting succeeded.
@return string? -- Error code.
]]
local function plantSeed(player, seedId, position)
    if typeof(seedId) ~= "string" or #seedId > 40 or typeof(position) ~= "Vector3" or not passRateLimit(player) then
        return false, "invalid"
    end
    if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z or position.Magnitude > 1e6 then
        return false, "invalid"
    end
    local seed = SeedPacks.getSeed(seedId)
    local controller = getController(player)
    local state, owned = ownedSoil(player)
    if not seed or seed.available == false or not controller or not state then
        return false, "invalid"
    end
    -- the character must be alive and standing near the spot
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0 or not root then
        return false, "invalid"
    end
    if Vector3.new(root.Position.X - position.X, 0, root.Position.Z - position.Z).Magnitude > PLANT_DISTANCE then
        return false, "distance"
    end
    -- inside one of the player's OWN unlocked soil beds (plot space), on its surface
    local rel = state.plot.cf:PointToObjectSpace(position)
    local soil = soilAt(owned, rel.X, rel.Z, EDGE_MARGIN)
    if not soil then
        -- the edge of your own bed = "soil"; land you have not unlocked yet = "locked"
        local onLand = soilAt(soilRects(nil), rel.X, rel.Z, 0) ~= nil
        local onOwned = soilAt(owned, rel.X, rel.Z, 0) ~= nil
        return false, if onLand and not onOwned then "locked" else "soil"
    end
    if math.abs(rel.Y - soil.top) > 3 then
        return false, "soil"
    end
    local data = controller._data
    local inventory = cloneTableOrEmpty(data:Get("seed_inventory"))
    local crops = cloneTableOrEmpty(data:Get("seed_crops"))
    if typeof(inventory[seedId]) ~= "number" or inventory[seedId] < 1 then
        return false, "ownership"
    end
    local count = 0
    for _, entry in pairs(crops) do
        count += 1
        if typeof(entry) == "table" and isCoordinate(entry.x) and isCoordinate(entry.z)
            and (entry.x - rel.X) ^ 2 + (entry.z - rel.Z) ^ 2 < MIN_SPACING * MIN_SPACING then
            return false, "occupied"
        end
    end
    if count >= MAX_CROPS then
        return false, "full"
    end
    local key
    repeat
        key = "c" .. string.lower(HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 10))
    until crops[key] == nil
    -- accepted: spend exactly one Seed, save the crop, then build it
    inventory[seedId] = math.floor(inventory[seedId]) - 1
    if inventory[seedId] <= 0 then
        inventory[seedId] = nil
    end
    local entry = {
        seed_id = seedId,
        planted_at = os.time(),
        x = math.round(rel.X * 100) / 100,
        z = math.round(rel.Z * 100) / 100,
        floor = if soil.floor == 2 then 2 else nil, -- Second Garden Floor crop
        size = SeedPacks.rollSize(sizeRandom), -- this crop's own size (SeedPacks.SIZE_ROLLS)
        -- planted during the tutorial "Plant" step: quick first crop (SeedPacks.TUTORIAL_GROWTH)
        quick = if data:Get("tutorial_marker") == 4 then true else nil,
    }
    crops[key] = entry
    data:Set("seed_inventory", inventory)
    data:Set("seed_crops", crops)
    data:Set("seed_planted_count", nonnegativeInteger(data:Get("seed_planted_count")) + 1)
    buildCrop(player, key, entry)
    if data:Get("tutorial_marker") == 4 then
        data:Set("tutorial_marker", 5)
    end
    return true
end

--[[
Gives Seeds straight to a player's seed_inventory (rewards: Garden Spins...).
@param player Player -- Receiver.
@param seedId string -- Seed identifier.
@param count number? -- How many (1..100).
@return boolean -- Whether they were given.
@return table? -- Reward data for the reward popup.
]]
function FarmingV2.giveSeeds(player, seedId, count)
    count = math.clamp(math.floor(tonumber(count) or 1), 1, 100)
    local controller = getController(player)
    if typeof(seedId) ~= "string" or not SeedPacks.getSeed(seedId) or not controller then
        return false
    end
    local data = controller._data
    local inventory = cloneTableOrEmpty(data:Get("seed_inventory"))
    inventory[seedId] = nonnegativeInteger(inventory[seedId]) + count
    data:Set("seed_inventory", inventory)
    return true, {{reward_name = "Seed", name = seedId, value = count}}
end

--[[
Opens Seed Packs for free with the normal server odds (rewards: Garden Spins...).
@param player Player -- Receiver.
@param packId string -- Pack identifier.
@param count number? -- How many packs (1..10).
@return boolean -- Whether they were given.
@return table? -- The Seeds rolled, for the reward popup.
]]
function FarmingV2.givePack(player, packId, count)
    count = math.clamp(math.floor(tonumber(count) or 1), 1, 10)
    local pack = typeof(packId) == "string" and SeedPacks.getPack(packId) or nil
    local controller = getController(player)
    if not pack or not controller then
        return false
    end
    local data = controller._data
    local inventory = cloneTableOrEmpty(data:Get("seed_inventory"))
    local rolled = {}
    for _ = 1, count * pack.rolls do
        local seedId = rollSeed(data, pack)
        inventory[seedId] = nonnegativeInteger(inventory[seedId]) + 1
        rolled[seedId] = (rolled[seedId] or 0) + 1
    end
    data:Set("seed_inventory", inventory)
    local rewards = {}
    for seedId, n in pairs(rolled) do
        table.insert(rewards, {reward_name = "Seed", name = seedId, value = n})
    end
    return true, rewards
end

--[[
Rare bonus Seed on a successful manual harvest of a mature crop: +1 Seed of the same kind.
Called by the Player controller only after the harvest was validated and its normal reward
granted. Server RNG only; the client never chooses anything.
@param player Player -- Harvester (crop owner).
@param seedId string -- Seed the harvested crop was planted from (read from the save).
@return string? -- Seed id that dropped, or nil.
]]
function FarmingV2.rollHarvestSeedDrop(player, seedId)
    if typeof(seedId) ~= "string" or not SeedPacks.getSeed(seedId) then
        return nil
    end
    if harvestRandom:NextNumber() >= HARVEST_SEED_DROP_CHANCE then
        return nil
    end
    local controller = getController(player)
    if not controller or not controller._data then
        return nil
    end
    local data = controller._data
    local inventory = cloneTableOrEmpty(data:Get("seed_inventory"))
    inventory[seedId] = nonnegativeInteger(inventory[seedId]) + 1
    data:Set("seed_inventory", inventory)
    return seedId
end

--[[
Finishes the ONE harvest of a mature Seed crop (called by Harvest after the pick was validated).
Normal crop: the save entry is removed and the model goes away (1 Seed = 1 Plant = 1 Harvest).
Regrowable crop: the plant stays and enters REGROWING until regrow_ready_at (server timestamps,
offline time counts); its Watering Can count resets for the new cycle.
@param player Player -- Crop owner (already checked by Harvest).
@param key string -- seed_crops key (model attribute SeedCropSlot).
@param model Model -- Harvested crop model.
@return string? -- Seed id the crop grew from (nil if it was not a valid mature crop of this player).
]]
function FarmingV2.completeHarvest(player, key, model)
    local controller = getController(player)
    if not controller or typeof(key) ~= "string" then
        return nil
    end
    local data = controller._data
    local crops = cloneTableOrEmpty(data:Get("seed_crops"))
    local entry = crops[key]
    local seed = typeof(entry) == "table" and typeof(entry.seed_id) == "string" and SeedPacks.getSeed(entry.seed_id) or nil
    local valid = seed ~= nil and model and model:GetAttribute("Mature") == true and model:GetAttribute("Owner") == player.UserId
    local harvestedSeedId = if valid then entry.seed_id else nil
    CollectionService:RemoveTag(model, "HarvestBush")
    if valid and not entry.tutorial then
        FarmingV2.recordWeight(player, model:GetAttribute("Weight"), entry.seed_id)
    end
    if valid and seed.is_regrowable and typeof(seed.regrow_time) == "number" then
        local now = os.time()
        entry.state = "regrowing"
        entry.last_harvested_at = now
        entry.regrow_ready_at = now + math.floor(seed.regrow_time / growthMultiplier(player))
        entry.water_credit = nil
        entry.water_count = nil
        entry.last_watered_at = nil
        entry.matured_at = nil -- overgrowth starts again after the regrow (the size roll stays)
        crops[key] = entry
        data:Set("seed_crops", crops)
        model:SetAttribute("Mature", false)
        task.delay(1.5, function()
            if model.Parent then
                FarmingV2._rebuild(player, key)
            end
        end)
        return harvestedSeedId
    end
    crops[key] = nil
    data:Set("seed_crops", crops)
    task.delay(1.5, function()
        if model.Parent then
            model:Destroy()
        end
    end)
    return harvestedSeedId
end

--[[
Watering Can: takes WATER_SHARE of the CURRENT remaining grow (or regrow) time off one of the
player's own growing crops. Every rule is checked here; the client only names the crop key.
@param player Player -- Waterer (must own the crop).
@param key string -- seed_crops key.
@return boolean, (string | number) -- success, error code or seconds removed.
]]
local WATER_DISTANCE = 18 -- studs from the character to the crop
function FarmingV2.waterCrop(player, key)
    if typeof(key) ~= "string" or #key > 40 then
        return false, "invalid"
    end
    local controller = getController(player)
    local model = models[player] and models[player][key]
    if not controller or not model or not model.Parent or model:GetAttribute("Owner") ~= player.UserId then
        return false, "invalid"
    end
    local data = controller._data
    local crops = cloneTableOrEmpty(data:Get("seed_crops"))
    local entry = crops[key]
    local seed = typeof(entry) == "table" and typeof(entry.seed_id) == "string" and SeedPacks.getSeed(entry.seed_id) or nil
    if not seed then
        return false, "invalid"
    end
    local okNear, pivot = pcall(model.GetPivot, model)
    if not okNear or not isNear(player, pivot.Position, WATER_DISTANCE) then
        return false, "distance"
    end
    local now = os.time()
    local readyAt = readyAtFor(player, entry, seed)
    if not readyAt or now >= readyAt or model:GetAttribute("Mature") then
        return false, "mature"
    end
    local count = nonnegativeInteger(entry.water_count)
    if count >= SeedPacks.WATER_MAX_PER_CYCLE then
        return false, "max"
    end
    local last = entry.last_watered_at
    if typeof(last) == "number" and last == last and now - last < SeedPacks.WATER_COOLDOWN then
        return false, "cooldown", math.ceil(SeedPacks.WATER_COOLDOWN - (now - last))
    end
    local removed = math.max(1, math.floor((readyAt - now) * SeedPacks.WATER_SHARE))
    local credit = if typeof(entry.water_credit) == "number" and entry.water_credit == entry.water_credit then math.max(entry.water_credit, 0) else 0
    entry.water_credit = credit + removed
    entry.water_count = count + 1
    entry.last_watered_at = now
    crops[key] = entry
    data:Set("seed_crops", crops)
    model:SetAttribute("WaterCredit", entry.water_credit)
    model:SetAttribute("WaterCount", entry.water_count)
    return true, removed
end

--[[
Loads dependencies for Seed farming.
]]
function FarmingV2._init()
    Network = _L.Get {"Common", "Library", "Network"}
    Farm = _L.Get {"Server", "Modules", "Controllers", "Farm"}
    FarmUpgrades = _L.Get {"Common", "Modules", "Databases", "FarmUpgrades"}
    SeedPacks = _L.Get {"Common", "Modules", "Databases", "SeedPacks"}
    TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
    TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
    UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
    FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
    GardenFloor = _L.Get {"Common", "Modules", "Databases", "GardenFloor"}
    PlantBuilder = require(ServerStorage:WaitForChild("PlantBuilder"))
end

--[[
Starts Seed Shop, planting, and crop restoration services.
]]
function FarmingV2._start()
    Network.Remote.Invoked("S_Seeds_Get", getState)
    Network.Remote.Invoked("S_SeedPack_Buy", buyPack)
    Network.Remote.Invoked("S_Seed_Plant", plantSeed)
    -- server clock for the client's visual-only crop timers (client os.time is never trusted)
    Network.Remote.Invoked("S_Server_Now", function()
        return os.time()
    end)
    -- Growth heartbeat (ONE loop for every crop on the server): recomputes ready times with the
    -- LIVE growth boost every second, so swapping equipped Fruits changes growth speed at once.
    -- Matured crops are only flagged for harvest -- they are NEVER auto-harvested. Authored crop
    -- models also switch growth stage here (no loop or timer per crop).
    task.spawn(function()
        local lastOvergrow = 0
        while true do
            task.wait(1)
            local now = os.time()
            local overgrowNow = os.clock() - lastOvergrow >= OVERGROW_TICK
            if overgrowNow then
                lastOvergrow = os.clock()
            end
            for player, crops in pairs(models) do
                if player.Parent then
                    local controller
                    local mult
                    local saved
                    for key, model in pairs(crops) do
                        if not model.Parent then
                            crops[key] = nil -- harvested (or the farm was cleared): forget the model
                        elseif model:GetAttribute("Mature") then
                            -- overgrowth: mature crops keep getting bigger and heavier (every few seconds)
                            if overgrowNow then
                                controller = controller or getController(player)
                                saved = saved or (controller and controller._data:Get("seed_crops") or {})
                                local entry = saved[key]
                                local seed = typeof(entry) == "table" and typeof(entry.seed_id) == "string" and SeedPacks.getSeed(entry.seed_id) or nil
                                if seed then
                                    local ok, err = pcall(FarmingV2._overgrow, player, key, model, entry, seed, now)
                                    if not ok then
                                        warn("[FarmingV2] overgrowth failed:", err)
                                    end
                                end
                            end
                        else
                            controller = controller or getController(player)
                            saved = saved or (controller and controller._data:Get("seed_crops") or {})
                            local entry = saved[key]
                            local seed = typeof(entry) == "table" and typeof(entry.seed_id) == "string" and SeedPacks.getSeed(entry.seed_id) or nil
                            if seed then
                                mult = mult or growthMultiplier(player)
                                local readyAt = SeedPacks.getReadyAt(entry, seed, mult)
                                -- one bad crop must never stop the heartbeat for everyone
                                if readyAt and now >= readyAt then
                                    local ok, err = pcall(mature, player, key)
                                    if not ok then
                                        warn("[FarmingV2] mature failed:", err)
                                    end
                                elseif readyAt and model:GetAttribute("Staged") and cropStage(entry, seed, readyAt, now) ~= model:GetAttribute("Stage") then
                                    local ok, err = pcall(buildCrop, player, key, entry)
                                    if not ok then
                                        warn("[FarmingV2] stage change failed:", err)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    task.spawn(function()
        local ok, err = pcall(publishGuideTargets)
        if not ok then
            warn("[FarmingV2] guide targets:", err)
        end
    end)
    local root = seedShopRoot()
    if root then
        local prompt = root:FindFirstChild("SeedShopPrompt") or Instance.new("ProximityPrompt")
        prompt.Name = "SeedShopPrompt"
        prompt.ActionText = "Buy Seed Packs"
        prompt.ObjectText = "Seed Shop"
        prompt.MaxActivationDistance = 12
        prompt.RequiresLineOfSight = false
        prompt.Parent = root
        prompt.Triggered:Connect(function(player)
            Network.Remote.Fire("C_SeedShop_Open", player)
        end)
    end
    Players.PlayerAdded:Connect(function(player)
        task.spawn(syncPlayer, player)
    end)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(syncPlayer, player)
    end
    Players.PlayerRemoving:Connect(function(player)
        lastRequest[player] = nil
        models[player] = nil
    end)
end

-- // INITIALIZATION // --
return FarmingV2

