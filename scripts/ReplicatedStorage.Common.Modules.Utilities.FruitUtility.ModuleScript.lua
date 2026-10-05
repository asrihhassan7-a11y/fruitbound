--> Variables
local _L = _G._L

local Fruits
local TableUtility
local Services
local FruitRarities
local ArrayUtility
local PlantUtility
local FruitStageUtility
local MasteryUtility

--> Constants

-- Boost scaling per level above 1 (10% per level)
local LEVEL_BOOST_MULTIPLIER = 0.1

-- Multiplier applied when a fruit is evolved (2x base boost)
local EVOLUTION_BOOST_MULTIPLIER = 2

-- Multiplier applied when a fruit is awakened (5x base boost)
local AWAKEN_BOOST_MULTIPLIER = 5

-- Multiplier applied for Rainbow tier fruits (2x, same as pet system)
local RAINBOW_BOOST_MULTIPLIER = 2

---------->
local FruitUtility

FruitUtility = {
	-- ============================================================
	-- BASIC LOOKUP & INFO
	-- ============================================================

	getInfo = function(fruitName)
		local _, fruitInfo = TableUtility.match(Fruits, function(i, v)
			return v.name == fruitName
		end)

		return fruitInfo
	end,

	-- ============================================================
	-- BOOST CALCULATION
	-- ============================================================

	-- Calculate the effective boost for a single fruit
	-- Takes into account: base boost, level scaling, evolution, awakening, and tier
	getEffectiveBoost = function(fruitInfo, fruitData, data)
		if not fruitInfo or not fruitData then
			return 0
		end

		local baseBoost = fruitInfo.boost
		local level = fruitData.level or 1
		local levelMultiplier = 1 + (level - 1) * LEVEL_BOOST_MULTIPLIER
		local evolutionMultiplier = fruitData.evolved and EVOLUTION_BOOST_MULTIPLIER or 1
		local awakeningMultiplier = fruitData.awakened and AWAKEN_BOOST_MULTIPLIER or 1
		local tierMultiplier = fruitData.tier == "Rainbow" and RAINBOW_BOOST_MULTIPLIER or 1
		local stageMultiplier = FruitStageUtility.getInfo(FruitStageUtility.getStage(fruitData)).boost

		local result = baseBoost * levelMultiplier * evolutionMultiplier * awakeningMultiplier * tierMultiplier * stageMultiplier

		-- Apply fruit mastery value multiplier if player data is provided
		if data then
			local masteryMultiplier = MasteryUtility.getFruitValueMultiplier(data, fruitData.name)
			result = result * masteryMultiplier
		end

		return result
	end,

	-- Get the boost for a specific fruit by UID
	getBoost = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)

		if fruitData then
			local fruitInfo = FruitUtility.getInfo(fruitData.name)
			if fruitInfo then
				return FruitUtility.getEffectiveBoost(fruitInfo, fruitData, data)
			end
		end

		return 0
	end,

	-- Calculate total boost from all equipped fruits
	getTotalBoost = function(data)
		local n = 1

		for _, a in pairs(FruitUtility.getEquipped(data)) do
			local i = FruitUtility.getInfo(a.name)
			if i then
				n += FruitUtility.getEffectiveBoost(i, a, data)
			end
		end

		return n
	end,

	-- ============================================================
	-- INVENTORY MANAGEMENT
	-- ============================================================

	hasInventorySpace = function(data, forr)
		forr = forr or 0
		return data:Get({"stats", "Fruit_Storage_Space"}) - (forr + TableUtility.length(data:Get("fruits"))) >= 0
	end,

	isEquipped = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)

		if fruitData then
			return fruitData.equipped
		else
			return false
		end
	end,

	-- a Fruit resting in Daycare never counts as equipped (no growth / harvest / Auto Collect bonus)
	getEquipped = function(data)
		return TableUtility.filter(data:Get("fruits"), function(i, v)
			return v.equipped and not v.daycare
		end)
	end,

	hasEquipSpace = function(data)
		return data:Get({"stats", "Fruit_Equip_Space"}) - (TableUtility.length(FruitUtility.getEquipped(data))) > 0
	end,

	setEquipped = function(data, fruitUids, newState)
		fruitUids = if typeof(fruitUids) == "table" then fruitUids else {fruitUids}

		data:Set("fruits", TableUtility.map(TableUtility.deep.clone(data:Get("fruits")), function(i, v)
			if table.find(fruitUids, v.uid) then
				if newState and not v.daycare and FruitUtility.hasEquipSpace(data) then
					v.equipped = true
				else
					v.equipped = false
				end
			end

			return i, v
		end))
	end,

	getData = function(data, fruitUid)
		local fruitsData = data:Get("fruits")

		local _, fruitData = TableUtility.match(fruitsData, function(i, v)
			return v.uid == fruitUid
		end)

		return fruitData
	end,

	-- Give fruit(s) to a player. fruitProps: { name, value, tier, uid }
	give = function(client, fruitProps)
		local clientData = client.data

		local fruitName = fruitProps.name
		local fruitValue = fruitProps.value or 1
		local fruitTier = fruitProps.tier

		-- ADMIN ONLY fruits can never be given to normal players (rewards, eggs, codes...)
		local giveInfo = FruitUtility.getInfo(fruitName)
		if giveInfo and giveInfo.admin_only then
			local AdminUtility = _L.Get {"Common", "Modules", "Utilities", "AdminUtility"}
			if not (client.player and AdminUtility.isAdmin(client.player)) then
				return false
			end
		end

		if clientData and fruitName then
			local currentFruitsData = TableUtility.deep.clone(clientData:Get("fruits"))

			for i = 1, fruitValue do
				local fruitUid = fruitProps.uid or Services.HttpService:GenerateGUID(false)

				local newFruitData = {
					name = fruitName,
					uid = fruitUid,
					level = 1,
					exp = 0,
					equipped = false,
					evolved = false,
					awakened = false,
					tier = fruitTier,
				}

				table.insert(currentFruitsData, newFruitData)
			end

			clientData:Set("fruits", currentFruitsData)

			-- achievements: count every fruit ever collected
			clientData:Set({"stats", "Fruits_Collected"}, (clientData:Get({"stats", "Fruits_Collected"}) or 0) + fruitValue)

			return true, {{
				name = fruitName,
				reward_name = "Fruit",
				value = fruitValue,
				tier = fruitTier,
			}}
		end

		return false
	end,

	remove = function(data, fruitUids)
		fruitUids = if typeof(fruitUids) == "table" then fruitUids else {fruitUids}

		local fruitsData = data:Get("fruits")
		local newFruitsData = TableUtility.deep.clone(fruitsData)

		newFruitsData = ArrayUtility.filter(newFruitsData, function(i, v)
			return v.daycare or not table.find(fruitUids, v.uid)
		end)

		data:Set("fruits", newFruitsData)
	end,

	-- ============================================================
	-- PROGRESSION: EXP & LEVELING
	-- ============================================================

	-- Calculate the EXP needed to go from 'level' to 'level + 1'
	getExpForLevel = function(fruitInfo, level)
		if not fruitInfo then return 0 end
		return math.floor((fruitInfo.base_exp or 100) * ((fruitInfo.exp_curve or 1.15) ^ (level - 1)))
	end,

	-- Get EXP progress info for a specific fruit
	getExpProgress = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return nil end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return nil end

		local level = fruitData.level or 1
		local currentExp = fruitData.exp or 0
		local isMaxLevel = level >= FruitUtility.getLevelCap(fruitInfo, fruitData)
		local expNeeded = 0

		if not isMaxLevel then
			expNeeded = FruitUtility.getExpForLevel(fruitInfo, level)
		end

		return {
			level = level,
			currentExp = currentExp,
			expNeeded = expNeeded,
			isMaxLevel = isMaxLevel,
			maxLevel = FruitUtility.getLevelCap(fruitInfo, fruitData),
		}
	end,

	-- Check if a fruit can level up (has enough EXP and is not at max level)
	canLevelUp = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return false end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return false end

		local level = fruitData.level or 1
		if level >= FruitUtility.getLevelCap(fruitInfo, fruitData) then return false end

		local expNeeded = FruitUtility.getExpForLevel(fruitInfo, level)
		return (fruitData.exp or 0) >= expNeeded
	end,

	-- Level up a fruit if it has enough EXP. Returns success and level gained.
	levelUp = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return false, "Fruit not found" end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return false, "Fruit info not found" end

		local fruits = TableUtility.deep.clone(data:Get("fruits"))
		local levelsGained = 0

		for i, v in ipairs(fruits) do
			if v.uid == fruitUid then
				local level = v.level or 1
				local exp = v.exp or 0

				while level < FruitUtility.getLevelCap(fruitInfo, fruitData) do
					local expNeeded = FruitUtility.getExpForLevel(fruitInfo, level)
					if exp >= expNeeded then
						exp = exp - expNeeded
						level = level + 1
						levelsGained = levelsGained + 1
					else
						break
					end
				end

				if level >= FruitUtility.getLevelCap(fruitInfo, fruitData) then
					exp = 0
				end

				v.level = level
				v.exp = exp
				break
			end
		end

		if levelsGained > 0 then
			data:Set("fruits", fruits)
			return true, { levelsGained = levelsGained, newLevel = fruitData.level + levelsGained }
		end

		return false, "Not enough EXP or already at max level"
	end,

	-- ============================================================
	-- PROGRESSION: FEEDING (PLANTS -> FRUIT EXP)
	-- ============================================================

	-- Feed plant(s) to a fruit, granting EXP. Auto-levels up if enough EXP.
	-- Returns success, info table
	feed = function(data, fruitUid, plantName, plantCount)
		plantCount = plantCount or 1

		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return false, "Fruit not found" end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return false, "Fruit info not found" end

		-- Check if fruit is at max level
		local level = fruitData.level or 1
		if level >= FruitUtility.getLevelCap(fruitInfo, fruitData) then
			return false, "Fruit is already at max level"
		end

		-- Check if player has enough plants
		local plants = data:Get("plants") or {}
		local currentCount = plants[plantName] or 0
		if currentCount < plantCount then
			return false, "Not enough plants"
		end

		-- Look up plant info
		local plantInfo = PlantUtility.getInfo(plantName)
		if not plantInfo then return false, "Plant not found" end

		-- Remove plants from inventory
		plants = TableUtility.deep.clone(plants)
		plants[plantName] = currentCount - plantCount
		if plants[plantName] <= 0 then
			plants[plantName] = nil
		end
		data:Set("plants", plants)

		-- Add EXP to the fruit and process level ups
		local fruits = TableUtility.deep.clone(data:Get("fruits"))
		local expGained = plantInfo.exp_value * plantCount
		local levelsGained = 0
		local newLevel = level
		local newExp = fruitData.exp or 0

		for i, v in ipairs(fruits) do
			if v.uid == fruitUid then
				newExp = (v.exp or 0) + expGained

				-- Process level ups
				while newLevel < FruitUtility.getLevelCap(fruitInfo, fruitData) do
					local expNeeded = FruitUtility.getExpForLevel(fruitInfo, newLevel)
					if newExp >= expNeeded then
						newExp = newExp - expNeeded
						newLevel = newLevel + 1
						levelsGained = levelsGained + 1
					else
						break
					end
				end

				-- Cap exp at 0 if max level
				if newLevel >= FruitUtility.getLevelCap(fruitInfo, fruitData) then
					newExp = 0
				end

				v.level = newLevel
				v.exp = newExp
				break
			end
		end

		data:Set("fruits", fruits)

		return true, {
			expGained = expGained,
			levelsGained = levelsGained,
			newLevel = newLevel,
			newExp = newExp,
			isMaxLevel = newLevel >= FruitUtility.getLevelCap(fruitInfo, fruitData),
		}
	end,

	-- ============================================================
	-- PROGRESSION: EVOLUTION
	-- ============================================================

	-- Check if a fruit can evolve (must be max level, have an evolution path, not already evolved)
	-- ============================================================
	-- EVOLUTION STAGES (Normal > Golden > Crystal > Magma > Galaxy > Divine)
	-- ============================================================

	getLevelCap = function(fruitInfo, fruitData)
		return FruitStageUtility.getLevelCap(fruitInfo, fruitData)
	end,

	-- Evolving needs: the level cap of the current stage reached, not Divine yet
	-- (the Coin cost is checked separately so the button can still show it)
	canEvolve = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return false end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return false end

		if FruitStageUtility.getStage(fruitData) >= FruitStageUtility.MAX_STAGE then return false end

		local level = fruitData.level or 1
		return level >= FruitUtility.getLevelCap(fruitInfo, fruitData)
	end,

	-- Evolve to the next stage. Level is kept, the cap goes up. Costs Coins (stat "Strength").
	evolve = function(data, fruitUid)
		if not FruitUtility.canEvolve(data, fruitUid) then
			return false, "not_ready"
		end

		local fruitData = FruitUtility.getData(data, fruitUid)
		local stage = FruitStageUtility.getStage(fruitData)
		local cost = FruitStageUtility.getEvolveCost(stage)
		local coins = data:Get({"stats", "Strength"}) or 0

		if coins < cost then
			return false, "afford"
		end

		data:Set({"stats", "Strength"}, coins - cost)

		local fruits = TableUtility.deep.clone(data:Get("fruits"))
		for i, v in ipairs(fruits) do
			if v.uid == fruitUid then
				v.stage = stage + 1
				v.exp = 0
				break
			end
		end
		data:Set("fruits", fruits)

		-- achievements: remember the best stage ever reached
		if (data:Get({"stats", "Best_Fruit_Stage"}) or 0) < stage + 1 then
			data:Set({"stats", "Best_Fruit_Stage"}, stage + 1)
		end

		return true, {
			stage = stage + 1,
			stageName = FruitStageUtility.getInfo(stage + 1).name,
			evolvedTo = FruitStageUtility.getDisplayName(fruitData.name, stage + 1),
		}
	end,

	-- ============================================================
	-- PROGRESSION: AWAKENING
	-- ============================================================

	-- Check if a fruit can be awakened (must be max level, can_awaken flag, not already awakened)
	canAwaken = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return false end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return false end

		-- Awakening is replaced by the evolution stages
		if true then return false end

		-- Already awakened?
		if fruitData.awakened then return false end

		-- Can be awakened?
		if not fruitInfo.can_awaken then return false end

		-- At max level?
		local level = fruitData.level or 1
		if level < FruitUtility.getLevelCap(fruitInfo, fruitData) then return false end

		return true
	end,

	-- Awaken a fruit, granting a permanent boost multiplier. Resets level to allow further leveling.
	awaken = function(data, fruitUid)
		if not FruitUtility.canAwaken(data, fruitUid) then
			return false, "Cannot awaken this fruit"
		end

		local fruits = TableUtility.deep.clone(data:Get("fruits"))

		for i, v in ipairs(fruits) do
			if v.uid == fruitUid then
				v.awakened = true
				break
			end
		end

		data:Set("fruits", fruits)

		return true, {
			awakened = true,
		}
	end,

	-- ============================================================
	-- UTILITY
	-- ============================================================

	-- Get a summary of a fruit for UI display
	getSummary = function(data, fruitUid)
		local fruitData = FruitUtility.getData(data, fruitUid)
		if not fruitData then return nil end

		local fruitInfo = FruitUtility.getInfo(fruitData.name)
		if not fruitInfo then return nil end

		local expProgress = FruitUtility.getExpProgress(data, fruitUid)

		return {
			uid = fruitUid,
			name = fruitData.name,
			rarity = fruitInfo.rarity,
			image = fruitInfo.image,
		model = fruitInfo.model,
			level = fruitData.level or 1,
			maxLevel = FruitUtility.getLevelCap(fruitInfo, fruitData),
			exp = fruitData.exp or 0,
			expNeeded = expProgress and expProgress.expNeeded or 0,
			isMaxLevel = expProgress and expProgress.isMaxLevel or false,
			evolved = fruitData.evolved or false,
			awakened = fruitData.awakened or false,
			equipped = fruitData.equipped or false,
			tier = fruitData.tier,
			boost = FruitUtility.getEffectiveBoost(fruitInfo, fruitData, data),
			baseBoost = fruitInfo.boost,
			canEvolve = FruitUtility.canEvolve(data, fruitUid),
			canAwaken = FruitUtility.canAwaken(data, fruitUid),
			evolution = fruitInfo.evolution,
			description = fruitInfo.description,
			stage = FruitStageUtility.getStage(fruitData),
			stageName = FruitStageUtility.getInfo(FruitStageUtility.getStage(fruitData)).name,
			displayName = FruitStageUtility.getDisplayName(fruitInfo.display_name or fruitData.name, FruitStageUtility.getStage(fruitData)),
			evolveCost = FruitStageUtility.getEvolveCost(FruitStageUtility.getStage(fruitData)),
			nextStageName = FruitStageUtility.getStage(fruitData) < FruitStageUtility.MAX_STAGE and FruitStageUtility.getInfo(FruitStageUtility.getStage(fruitData) + 1).name or nil,
		}
	end,

	-- Equip the best N fruits automatically (sorted by effective boost descending)
	equipBest = function(data)
		local fruits = TableUtility.deep.clone(data:Get("fruits"))

		-- Calculate effective boost for each fruit
		for _, v in ipairs(fruits) do
			local info = FruitUtility.getInfo(v.name)
			if info then
				v._effectiveBoost = FruitUtility.getEffectiveBoost(info, v, data)
			else
				v._effectiveBoost = 0
			end
		end

		-- Sort by boost descending
		table.sort(fruits, function(a, b)
			return (a._effectiveBoost or 0) > (b._effectiveBoost or 0)
		end)

		-- Unequip all, then equip the top N
		local equipSpace = data:Get({"stats", "Fruit_Equip_Space"})
		for _, v in ipairs(fruits) do
			v.equipped = false
			v._effectiveBoost = nil
		end

		local equipped = 0
		for _, fruit in ipairs(fruits) do
			if not fruit.daycare and equipped < equipSpace then
				fruit.equipped = true
				equipped += 1
			end
		end

		data:Set("fruits", fruits)
	end,

	_init = function()
		Fruits = _L.Get {"Common", "Modules", "Databases", "Fruits", "Fruits"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		FruitRarities = _L.Get {"Common", "Modules", "Databases", "Fruits", "Rarities"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		PlantUtility = _L.Get {"Common", "Modules", "Utilities", "PlantUtility"}
		FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
		MasteryUtility = _L.Get {"Common", "Modules", "Utilities", "MasteryUtility"}
	end
}

return FruitUtility