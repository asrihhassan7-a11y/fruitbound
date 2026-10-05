-- // VARIABLES // --
local SeedPacks = {}

SeedPacks.Seeds = {
    clover = {
        id = "clover",
        visual = "clover",
        display_name = "Clover Seed",
        plant_name = "Clover",
        style = "Clover",
        fruit = Color3.fromRGB(105, 205, 95),
        leaf = Color3.fromRGB(75, 175, 75),
        growth_time = 90, -- 1m30s
        coin_multiplier = 16,
        sell_value = 8, -- Coins per crop item; one harvest gives HARVEST_UNITS items
        base_weight = 0.25, -- kg of a normal-size crop the moment it is ready (see getWeight)
    },
    mint = {
        id = "mint",
        visual = "mint",
        display_name = "Mint Seed",
        plant_name = "Mint Leaf",
        style = "Leaf",
        fruit = Color3.fromRGB(95, 220, 155),
        leaf = Color3.fromRGB(55, 165, 105),
        growth_time = 240, -- 4m
        coin_multiplier = 24,
        sell_value = 14, -- Coins per crop item; one harvest gives HARVEST_UNITS items
        base_weight = 0.35, -- kg of a normal-size crop the moment it is ready (see getWeight)
    },
    carrot = {
        id = "carrot",
        visual = "carrot",
        display_name = "Carrot Seed",
        plant_name = "Carrot",
        style = "Veggie",
        fruit = Color3.fromRGB(255, 145, 55),
        leaf = Color3.fromRGB(95, 195, 85),
        growth_time = 480, -- 8m
        coin_multiplier = 40,
        sell_value = 24, -- Coins per crop item; one harvest gives HARVEST_UNITS items
        base_weight = 0.6, -- kg of a normal-size crop the moment it is ready (see getWeight)
    },
    sunflower = {
        id = "sunflower",
        visual = "sunflower",
        display_name = "Sunflower Seed",
        plant_name = "Sunflower Seed",
        style = "Flower",
        fruit = Color3.fromRGB(255, 215, 65),
        leaf = Color3.fromRGB(80, 180, 80),
        growth_time = 1080, -- 18m
        coin_multiplier = 64,
        sell_value = 42, -- Coins per crop item; one harvest gives HARVEST_UNITS items
        base_weight = 1.8, -- kg of a normal-size crop the moment it is ready (see getWeight)
    },
    glow_mushroom = {
        id = "glow_mushroom",
        visual = "glow_mushroom",
        display_name = "Glow Mushroom Seed",
        plant_name = "Glow Mushroom",
        style = "Mushroom",
        fruit = Color3.fromRGB(120, 225, 255),
        leaf = Color3.fromRGB(80, 175, 145),
        growth_time = 2400, -- 40m
        coin_multiplier = 120,
        sell_value = 75, -- Coins per crop item; one harvest gives HARVEST_UNITS items
        base_weight = 3.2, -- kg of a normal-size crop the moment it is ready (see getWeight)
    },
    -- REGROWABLE crop (future): harvesting keeps the tree, it regrows its fruit after regrow_time.
    -- available = false: not sold in any pack and cannot be planted until its models are added
    -- (ReplicatedStorage.Assets.Crops.AppleTree, see CROP_ASSETS below).
    apple_tree = {
        id = "apple_tree",
        visual = "AppleTree",
        display_name = "Apple Seed",
        plant_name = "Apple",
        style = "Veggie",
        fruit = Color3.fromRGB(220, 50, 45),
        leaf = Color3.fromRGB(70, 160, 70),
        growth_time = 5400, -- 90m first growth
        is_regrowable = true,
        regrow_time = 1500, -- 25m between harvests
        sell_value = 60, -- per item (harvest reward = sell_value x HARVEST_UNITS per regrow)
        base_weight = 5, -- kg of a normal-size crop the moment it is ready (see getWeight)
        available = false,
    },
}

SeedPacks.Packs = {
    starter = {
        id = "starter",
        visual = "starter_pack",
        display_name = "Starter Seed Pack",
        tier = "Starter",
        price = 180,
        currency = "Strength",
        rolls = 3,
        entries = {
            {seed_id = "clover", chance = 40},
            {seed_id = "mint", chance = 30},
            {seed_id = "carrot", chance = 20},
            {seed_id = "sunflower", chance = 10},
        },
    },
    garden = {
        id = "garden",
        visual = "starter_pack",
        display_name = "Garden Seed Pack",
        tier = "Garden",
        price = 425,
        currency = "Strength",
        rolls = 3,
        entries = {
            {seed_id = "mint", chance = 35},
            {seed_id = "carrot", chance = 35},
            {seed_id = "sunflower", chance = 24},
            {seed_id = "glow_mushroom", chance = 6},
        },
    },
    flower = {
        id = "flower",
        visual = "starter_pack",
        display_name = "Flower Seed Pack",
        tier = "Bloom",
        price = 455,
        currency = "Strength",
        rolls = 3,
        entries = {
            {seed_id = "clover", chance = 10},
            {seed_id = "mint", chance = 15},
            {seed_id = "carrot", chance = 25},
            {seed_id = "sunflower", chance = 50},
        },
    },
    woodland = {
        id = "woodland",
        visual = "starter_pack",
        display_name = "Woodland Seed Pack",
        tier = "Woodland",
        price = 755,
        currency = "Strength",
        rolls = 3,
        entries = {
            {seed_id = "clover", chance = 10},
            {seed_id = "carrot", chance = 20},
            {seed_id = "sunflower", chance = 30},
            {seed_id = "glow_mushroom", chance = 40},
        },
    },
    golden_grove = {
        id = "golden_grove",
        visual = "starter_pack",
        display_name = "Golden Grove Seed Pack",
        tier = "Golden Grove",
        price = 830,
        currency = "Strength",
        rolls = 3,
        entries = {
            {seed_id = "carrot", chance = 15},
            {seed_id = "sunflower", chance = 45},
            {seed_id = "glow_mushroom", chance = 40},
        },
    },
    enchanted_garden = {
        id = "enchanted_garden",
        visual = "starter_pack",
        display_name = "Enchanted Garden Seed Pack",
        tier = "Enchanted",
        price = 1040,
        currency = "Strength",
        rolls = 3,
        entries = {
            {seed_id = "sunflower", chance = 30},
            {seed_id = "glow_mushroom", chance = 70},
        },
    },
}

-- V1.1: 1 Seed = 1 Plant = 1 Harvest. The ONE harvest of a mature crop gives HARVEST_UNITS crop
-- items at once (same total value per Seed as the old 6-pick crops: Clover 6 x 8 = 48 base Coins).
SeedPacks.HARVEST_UNITS = 6

-- Fruit Harvest Luck bonus: extra crop items on a lucky harvest (small, never a doubled crop)
SeedPacks.HARVEST_LUCK_BONUS = 1

-- Growth boosts stack with diminishing returns so a 40m crop can never take seconds:
-- effective = 1 + GROWTH_MAX_EXTRA * extra / (extra + GROWTH_SOFTNESS), extra = raw boost - 1.
-- raw x1.25 -> x1.24, x2 -> x1.8, x3 -> x2.33, x7 -> x3.4, x20 -> x4.2, never above x5.
SeedPacks.GROWTH_MAX_EXTRA = 4
SeedPacks.GROWTH_SOFTNESS = 4

-- Watering Can (Gear): each watering removes this share of the CURRENT remaining time
SeedPacks.WATER_SHARE = 0.12
-- tutorial: the first crop a new player plants (tutorial step "Plant") is ready within this many seconds
SeedPacks.TUTORIAL_GROWTH = 60
SeedPacks.WATER_COOLDOWN = 180 -- seconds between waterings of the same crop
SeedPacks.WATER_MAX_PER_CYCLE = 3 -- successful waterings per growth (or regrow) cycle

-- Optional real crop models per Seed (else the procedural PlantBuilder crop is used):
--   ReplicatedStorage.Assets.Crops.<folder>.<Stage1 | Stage2 | Stage3 | Mature | Harvested>
SeedPacks.CROP_ASSETS = {
    clover = "Clover",
    mint = "Mint",
    carrot = "Carrot",
    sunflower = "Sunflower",
    glow_mushroom = "GlowMushroom",
    apple_tree = "AppleTree",
}
SeedPacks.CROP_STAGES = {"Stage1", "Stage2", "Stage3"} -- growing stages, chosen by growth progress

-- ============================================================
-- SIZE & WEIGHT (competition): every crop is its own plant with its own size
-- ============================================================
-- 1) Size roll: when a Seed is planted it rolls a size (saved as seed_crops[key].size), so two
--    crops of the same Seed are never identical. Server RNG only.
SeedPacks.SIZE_ROLLS = {
    {label = nil, chance = 70, min = 0.85, max = 1.1},
    {label = "Big", chance = 22, min = 1.1, max = 1.3},
    {label = "Huge", chance = 6, min = 1.3, max = 1.6},
    {label = "Giant", chance = 2, min = 1.6, max = 2},
}
SeedPacks.SIZE_MIN = 0.5 -- saved size rolls outside this range are treated as invalid
SeedPacks.SIZE_MAX = 2
-- 2) Overgrowth: a MATURE crop that is not harvested keeps growing, forever, with no timer.
--    It grows fast at first and slower and slower (logarithmic), counted from its ready time with
--    server timestamps, so it also grows while you are offline:
--    size = roll x (1 + OVERGROW_RATE x ln(1 + seconds since ready / OVERGROW_PERIOD))
--    15m -> x1.21, 1h -> x1.48, 8h -> x2.05, 1 day -> x2.37, 1 week -> x2.95 (and still growing)
SeedPacks.OVERGROW_RATE = 0.3
SeedPacks.OVERGROW_PERIOD = 900
-- 3) Weight = base_weight x size^2 (kg). Sell value per crop item = sell_value x weight / base_weight,
--    so a crop twice as heavy sells for twice as much.
-- 4) Models stop getting visibly bigger at this scale (they would cover the whole farm); the weight
--    and value keep growing.
SeedPacks.VISUAL_SCALE_MAX = 3

--[[
Rolls the size of a newly planted crop (server only).
@param rng Random -- Server random generator.
@return number -- Size roll (SIZE_MIN..SIZE_MAX).
]]
function SeedPacks.rollSize(rng)
    local total = 0
    for _, roll in ipairs(SeedPacks.SIZE_ROLLS) do
        total += roll.chance
    end
    local cursor = rng:NextNumber(0, total)
    for _, roll in ipairs(SeedPacks.SIZE_ROLLS) do
        cursor -= roll.chance
        if cursor <= 0 then
            return math.round(rng:NextNumber(roll.min, roll.max) * 1000) / 1000
        end
    end
    return 1
end

--[[
Label of a size roll ("Big", "Huge", "Giant") or nil for a normal crop.
@param roll number -- Saved size roll.
@return string?
]]
function SeedPacks.getSizeLabel(roll)
    local label = nil
    if typeof(roll) == "number" then
        for _, info in ipairs(SeedPacks.SIZE_ROLLS) do
            if roll >= info.min then
                label = info.label
            end
        end
    end
    return label
end

--[[
The saved size roll of a crop (1 for old saves without one / invalid values).
@param entry table -- Saved crop (seed_crops value).
@return number
]]
function SeedPacks.getSizeRoll(entry)
    local roll = typeof(entry) == "table" and entry.size or nil
    if typeof(roll) ~= "number" or roll ~= roll or roll < SeedPacks.SIZE_MIN or roll > SeedPacks.SIZE_MAX then
        return 1
    end
    return roll
end

--[[
Current size of a crop: its roll while growing, then roll x overgrowth once it is ready.
Shared by the server (authoritative) and the client (display only).
@param roll number -- Size roll (getSizeRoll).
@param readyAt number? -- Ready timestamp (getReadyAt).
@param now number -- Server os.time().
@return number -- Size (>= roll).
]]
function SeedPacks.getSize(roll, readyAt, now)
    if typeof(readyAt) ~= "number" or readyAt ~= readyAt or typeof(now) ~= "number" or now <= readyAt then
        return roll
    end
    local over = math.min(now - readyAt, 1e9)
    return roll * (1 + SeedPacks.OVERGROW_RATE * math.log(1 + over / SeedPacks.OVERGROW_PERIOD))
end

--[[
Weight in kg of a crop of this Seed at this size (rounded to 0.01 kg).
@param seed table -- Seed configuration.
@param size number -- getSize result.
@return number
]]
function SeedPacks.getWeight(seed, size)
    local base = typeof(seed) == "table" and tonumber(seed.base_weight) or 1
    return math.round(base * size * size * 100) / 100
end

--[[
Coins one crop item of this weight sells for (never below 1).
@param seed table -- Seed configuration.
@param weight number -- getWeight result.
@return number
]]
function SeedPacks.getSellValue(seed, weight)
    local base = tonumber(seed.base_weight) or 1
    return math.max(1, math.round(seed.sell_value * weight / base))
end

--[[
"1.23 kg" / "12.3 kg" / "123 kg" display text.
@param weight number
@return string
]]
function SeedPacks.formatWeight(weight)
    weight = tonumber(weight) or 0
    if weight >= 100 then
        return string.format("%d kg", math.floor(weight))
    elseif weight >= 10 then
        return string.format("%.1f kg", weight)
    end
    return string.format("%.2f kg", weight)
end

-- Reserved for future teaser packs; all current packs are purchasable in Packs.
SeedPacks.PreviewPacks = {}

-- // FUNCTIONS // --

--[[
Returns a configured Seed definition.
@param seedId string -- Stable Seed identifier.
@return table? -- Seed configuration.
]]
function SeedPacks.getSeed(seedId)
    return SeedPacks.Seeds[seedId]
end

--[[
Crop growth speed for a player's data (shared by the server growth and the client timer):
equipped Fruits (FruitUtility total boost) x Growth Speed potion x Sprinklers farm upgrade.
@param data table -- Player data wrapper (server or replicated client data).
@return number -- Multiplier >= 1 (capped at 100).
]]
function SeedPacks.getGrowthMultiplier(data)
    local _L = _G._L
    local mult = 1
    local ok, boost = pcall(_L.Get({"Common", "Modules", "Utilities", "FruitUtility"}).getTotalBoost, data)
    if ok and typeof(boost) == "number" and boost == boost and boost >= 1 and boost ~= math.huge then
        mult = boost
    end
    local okPotion, potion = pcall(_L.Get({"Common", "Modules", "Utilities", "BoostUtility"}).has, data, "Growth_Speed")
    if okPotion and potion then
        mult *= SeedPacks.GROWTH_POTION
    end
    local upgrades = data:Get({"farm", "upgrades"})
    if typeof(upgrades) == "table" then
        for _, info in ipairs(_L.Get({"Common", "Modules", "Databases", "FarmUpgrades"})) do
            if upgrades[info.id] == true and info.effect and typeof(info.effect.growth) == "number" then
                mult *= 1 + info.effect.growth
            end
        end
    end
    if typeof(mult) ~= "number" or mult ~= mult or mult < 1 then
        return 1
    end
    local extra = math.min(mult, 1e6) - 1
    return 1 + SeedPacks.GROWTH_MAX_EXTRA * extra / (extra + SeedPacks.GROWTH_SOFTNESS)
end

--[[
Server timestamp when a saved crop is (or was) ready to harvest. Shared by the server growth
heartbeat and the client timer. Growing: planted_at + growth_time / boost - watering.
Regrowing (regrowable crops after a harvest): regrow_ready_at - watering of this cycle.
@param entry table -- Saved crop (seed_crops value).
@param seed table -- Seed configuration.
@param mult number -- Growth multiplier (getGrowthMultiplier).
@return number? -- os.time() value, or nil for an invalid entry.
]]
function SeedPacks.getReadyAt(entry, seed, mult)
    local function finite(n)
        return typeof(n) == "number" and n == n and math.abs(n) ~= math.huge
    end
    if typeof(entry) ~= "table" or typeof(seed) ~= "table" then
        return nil
    end
    local credit = if finite(entry.water_credit) then math.max(entry.water_credit, 0) else 0
    if entry.state == "regrowing" then
        if not finite(entry.regrow_ready_at) then
            return nil
        end
        return entry.regrow_ready_at - credit
    end
    if not finite(entry.planted_at) or not finite(seed.growth_time) then
        return nil
    end
    mult = if finite(mult) and mult >= 1 then mult else 1
    -- the crop planted during the tutorial grows in at most TUTORIAL_GROWTH seconds
    local growth = if entry.quick then math.min(seed.growth_time, SeedPacks.TUTORIAL_GROWTH) else seed.growth_time
    return entry.planted_at + growth / mult - credit
end

-- Growth Speed potion (Boost "Growth_Speed") multiplier
SeedPacks.GROWTH_POTION = 1.25

--[[
Returns a configured Seed Pack definition.
@param packId string -- Stable pack identifier.
@return table? -- Pack configuration.
]]
function SeedPacks.getPack(packId)
    return SeedPacks.Packs[packId]
end

-- // INITIALIZATION // --
return SeedPacks

