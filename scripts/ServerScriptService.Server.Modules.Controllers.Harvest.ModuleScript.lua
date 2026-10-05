--> Harvest (server)
-- Plants (built by ServerStorage.PlantBuilder) are models tagged "HarvestBush" with attributes:
--   BushId (string, set here), Garden (number, Databases.Gardens id), Fruits (number of blooms on it)
-- Every player has their OWN bloom count per plant, so players never steal each other's harvest.
-- Each harvest click picks one bloom and gives Coins (done by Player:_power_click).
-- When a plant is fully harvested it drops food (Databases.Plants) and regrows after REGROW_TIME seconds.

local _L = _G._L

local CollectionService = game:GetService("CollectionService")

local Services
local Network
local Gardens
local Plants
local PlantUtility
local UpgradeTreeUtility
local TableUtility

--> Constants
local RANGE = 13 -- studs from the player to the bush
local AUTO_COLLECT_RANGE = 30 -- Auto Collect reaches every plant this close
-- Seed crops (FarmingV2) are only harvested by a tap ON the crop (mature hitbox is 6x6)
local SEED_CROP_TAP_RADIUS = 4.5
-- a tap must also be at the crop's height (the Second Garden Floor is 16 studs up)
local SEED_CROP_TAP_HEIGHT = 8
-- Grow time (seconds before an emptied plant is ready again). Better gardens pay more, so they grow slower:
--   Starter Patch 10s ... Cosmic Orchard 48s. Farm plants set their own "Regrow" attribute (Farm controller).
local BASE_GROW = 10
local GROW_PER_GARDEN = 2
local function gardenGrowTime(gardenId)
	return BASE_GROW + (tonumber(gardenId) or 0) * GROW_PER_GARDEN
end
local RARITY_ORDER = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Huge", "Secret", "Divine"}
local UPGRADE_CHANCE = 0.05 -- base chance to get food of the next rarity (boosted by Luck)

---------->
local Harvest = {
	_bushes = {}, -- [bushId] = {model, position, garden, max}
	_state = {}, -- [player][bushId] = {left, regrow_at}
}

local nextId = 0

local function register(model)
	if not model:IsA("Model") or not model.PrimaryPart then
		return
	end
	if model:GetAttribute("BushId") and Harvest._bushes[model:GetAttribute("BushId")] then
		return
	end
	nextId += 1
	local id = tostring(nextId)
	model:SetAttribute("BushId", id)
	Harvest._bushes[id] = {
		id = id,
		model = model,
		position = model.PrimaryPart.Position,
		garden = model:GetAttribute("Garden") or 0,
		max = model:GetAttribute("Fruits") or 6,
	}
end

local function getGarden(gardenId)
	for _, g in ipairs(Gardens) do
		if g.id == gardenId then
			return g
		end
	end
	return Gardens[1]
end

local function plantsOfRarity(rarity)
	local list = {}
	for _, p in ipairs(Plants) do
		if p.rarity == rarity and not p.fixed_only then
			table.insert(list, p)
		end
	end
	return list
end

-- Pick the food a bush drops (can roll one rarity higher thanks to Luck)
local function rollFood(data, rarity)
	local index = table.find(RARITY_ORDER, rarity) or 1
	local TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
	local luck = if data then UpgradeTreeUtility.getLuckMultiplier(data) * TitleUtility.getMultiplier(data, "luck") else 1
	if index < #RARITY_ORDER and math.random() < UPGRADE_CHANCE * luck then
		index += 1
	end
	local list = plantsOfRarity(RARITY_ORDER[index])
	if #list == 0 then
		list = plantsOfRarity("Common")
	end
	return list[math.random(#list)]
end

local function getState(player, bush)
	local playerState = Harvest._state[player]
	if not playerState then
		playerState = {}
		Harvest._state[player] = playerState
	end
	local s = playerState[bush.id]
	if not s then
		s = {left = bush.max, regrow_at = 0}
		playerState[bush.id] = s
	end
	if s.left <= 0 and os.clock() >= s.regrow_at then
		s.left = bush.max
	end
	return s
end

-- Garden 0 is always open; the others use the old training area requirement (Coins owned)
local function isGardenOpen(data, gardenId)
	if gardenId == 0 or not data then
		return true
	end
	local TrainingAreaUtility = _L.Get {"Common", "Modules", "Utilities", "TrainingAreaUtility"}
	local ok, result = pcall(TrainingAreaUtility.canUse, data, gardenId)
	return ok and result
end

-- Seed crop the player tapped (closest to the tapped point), or nil.
local function tappedSeedCrop(player, clickPosition)
	if typeof(clickPosition) ~= "Vector3" then
		return nil
	end
	local best, bestDist = nil, SEED_CROP_TAP_RADIUS
	for _, bush in pairs(Harvest._bushes) do
		if bush.model.Parent and bush.model:GetAttribute("SeedCropSlot") and bush.model:GetAttribute("Owner") == player.UserId then
			local flat = Vector3.new(bush.position.X - clickPosition.X, 0, bush.position.Z - clickPosition.Z).Magnitude
			if flat <= bestDist and math.abs(bush.position.Y - clickPosition.Y) <= SEED_CROP_TAP_HEIGHT then
				best, bestDist = bush, flat
			end
		end
	end
	return best
end

-- V1.1 Auto Collect may pick a Seed crop only when it is the player's own, mature (the
-- growth heartbeat set Mature), not the tutorial starter crop, and inside their own farm plot.
local function autoCollectable(player, bush)
	local model = bush.model
	if model:GetAttribute("Owner") ~= player.UserId or model:GetAttribute("Mature") ~= true or model:GetAttribute("TutorialCrop") then
		return false
	end
	local Farm = _L.Get {"Server", "Modules", "Controllers", "Farm"}
	local state = Farm and Farm._farms and Farm._farms[player]
	return state ~= nil and state.plot ~= nil and model:IsDescendantOf(state.plot.model)
end

-- Find the closest bush with fruit left for this player.
-- Returns bush, or nil + "locked" when the only bush in range is in a locked garden.
-- clickPosition: the tapped world point (nil for Auto Collect / auto punch). Manual: Seed crops
-- are only harvested when tapped directly (exact target). auto = true (Auto Collect): the
-- nearest of the player's own mature Seed crops (one whole crop per pick, see Player).
function Harvest.findNearest(player, position, data, range, clickPosition, auto)
	local best, bestDist = nil, range or RANGE
	local sawLocked = false
	local tappedSeed = if auto then nil else tappedSeedCrop(player, clickPosition)
	for _, bush in pairs(Harvest._bushes) do
		if bush.model.Parent then
			if bush.model:GetAttribute("SeedCropSlot") then
				if auto then
					if not autoCollectable(player, bush) then
						continue
					end
				elseif bush ~= tappedSeed then
					continue
				end
			end
			local flat = Vector3.new(bush.position.X - position.X, 0, bush.position.Z - position.Z).Magnitude
			local dy = math.abs(bush.position.Y - position.Y)
			-- farm plants can only be harvested by their owner
			local owner = bush.model:GetAttribute("Owner")
			if owner and owner ~= player.UserId then
				continue
			end
			if flat < bestDist and dy < 15 then
				if not isGardenOpen(data, bush.garden) then
					sawLocked = true
				elseif getState(player, bush).left > 0 then
					best, bestDist = bush, flat
				end
			end
		end
	end
	if not best and sawLocked then
		return nil, "locked"
	end
	return best
end

-- Called by Player:_power_click. Returns the bush harvested, or nil if none in range.
Harvest.AUTO_COLLECT_RANGE = AUTO_COLLECT_RANGE

function Harvest.tryHarvest(playerController, range, clickPosition, auto)
	local player = playerController._instance
	local root = playerController._character_controller and playerController._character_controller._root
	if not root then
		return nil
	end

	local BackpackUtility = _L.Get {"Common", "Modules", "Utilities", "BackpackUtility"}
	if BackpackUtility.isFull(playerController._data) then
		return nil, "full"
	end

	local bush, reason = Harvest.findNearest(player, root.Position, playerController._data, range, clickPosition, auto)
	if not bush then
		return nil, reason
	end
	-- a Seed crop's ONE harvest gives all its items at once: it needs room for the whole yield
	local yield = bush.model:GetAttribute("SeedCropSlot") and bush.model:GetAttribute("Yield")
	if typeof(yield) == "number" and yield > 1
		and BackpackUtility.getCount(playerController._data) + yield > BackpackUtility.getCapacity(playerController._data) then
		return nil, "full"
	end

	local s = getState(player, bush)
	s.left -= 1

	local foodName
	local regrowTime = bush.model:GetAttribute("Regrow") or gardenGrowTime(bush.garden)
	-- Apply friend growth boost (+10% per friend, max +50%)
	local friendBoost = playerController._instance:GetAttribute("friend_growth_boost") or 0
	if friendBoost > 0 then
		regrowTime = regrowTime / (1 + friendBoost)
	end
	-- World event (e.g. Sunny Skies) can make everything grow faster
	regrowTime = regrowTime / Harvest.getEventGrowth()
	-- every picked bloom is one plant item for the backpack (the Player controller stores it with its coin worth)
	local garden = getGarden(bush.garden)
	local fixedFoodName = bush.model:GetAttribute("FixedFood")
	local food
	if fixedFoodName then
		for _, plantInfo in ipairs(Plants) do
			if plantInfo.name == fixedFoodName then
				food = plantInfo
				break
			end
		end
	else
		food = rollFood(playerController._data, bush.model:GetAttribute("FoodRarity") or garden.rarity)
	end
	foodName = food and food.name

	-- MUTATIONS: a mutated crop gives mutated items ("Wet Carrot") worth more
	local mutationId = bush.model:GetAttribute("Mutation")
	local valueMult = 1
	if foodName and mutationId and bush.model:GetAttribute("Owner") == player.UserId then
		local MutationUtility = _L.Get {"Common", "Modules", "Utilities", "MutationUtility"}
		local info = MutationUtility.getInfo(mutationId)
		if info then
			foodName = MutationUtility.makeName(foodName, mutationId)
			valueMult = info.value
		end
	end

	if s.left <= 0 then
		s.regrow_at = os.clock() + regrowTime
		-- fully harvested: the crop that grows back is a normal one again
		if mutationId then
			Harvest.setMutation(player, playerController._data, bush, nil)
		end

		if food then
			local data = playerController._data
			data:Set({"stats", "Food_Collected"}, (data:Get({"stats", "Food_Collected"}) or 0) + 1)

			-- quest "2" / clan "deaths" are reused as "collect food"
			pcall(function()
				playerController:_quests_progress("2", 1)
				local clan = playerController:get_clan()
				if clan then
					clan:increment("deaths", 1)
				end
			end)
		end
	end

	Network.Remote.Fire("C_Harvest_Update", player, bush.id, s.left, if s.left <= 0 then regrowTime else 0, foodName)

	local seedSlot = bush.model:GetAttribute("SeedCropSlot")
	local harvestedSeedId = nil
	if seedSlot and s.left <= 0 then
		-- the saved crop says which Seed it grew from (only a mature crop of this owner counts);
		-- FarmingV2 removes a normal crop or puts a regrowable one into REGROWING
		local FarmingV2 = _L.Get {"Server", "Modules", "Controllers", "FarmingV2"}
		harvestedSeedId = FarmingV2.completeHarvest(player, tostring(seedSlot), bush.model)
	end

	return bush, nil, foodName, valueMult, harvestedSeedId
end

-- ============================================================
-- MUTATIONS (used by the WorldEvents controller)
-- A mutation belongs to one crop in YOUR farm garden. It is saved in data "farm_mutations"
-- under the crop's path inside the plot, so it survives rejoining.
-- ============================================================
Harvest._event_growth = 1

function Harvest.getEventGrowth()
	return math.max(Harvest._event_growth or 1, 0.1)
end

function Harvest.setEventGrowth(mult)
	Harvest._event_growth = mult or 1
end

-- unique key of a crop inside its farm plot: "<section>@x,z" (position relative to the plot base,
-- so it is the same on every plot and after the farm is rebuilt)
function Harvest.plantKey(model)
	local node = model
	local section
	while node and node.Parent do
		if node.Parent.Name == "Built" then
			section = node.Name
		end
		if node.Parent.Name == "Plots" then
			local base = node:FindFirstChild("Base")
			local root = model.PrimaryPart
			if not base or not root then
				return nil
			end
			local rel = base.CFrame:PointToObjectSpace(root.Position)
			return string.format("%s@%d,%d", section or model.Name, math.round(rel.X), math.round(rel.Z))
		end
		node = node.Parent
	end
	return nil
end

-- crops currently growing in this player's farm garden
function Harvest.getOwnedBushes(player)
	local list = {}
	for _, bush in pairs(Harvest._bushes) do
		if bush.model.Parent and bush.model:GetAttribute("Owner") == player.UserId then
			table.insert(list, bush)
		end
	end
	return list
end

-- is this crop growing right now (not already picked empty)?
function Harvest.isGrowing(player, bush)
	local s = getState(player, bush)
	return s.left > 0 or os.clock() < s.regrow_at
end

function Harvest.setMutation(player, data, bush, mutationId)
	local key = Harvest.plantKey(bush.model)
	bush.model:SetAttribute("Mutation", mutationId)
	if data and key then
		local saved = table.clone(data:Get("farm_mutations") or {})
		saved[key] = mutationId
		data:Set("farm_mutations", saved)
	end
end

-- put saved mutations back on the crops (after joining / farm rebuilt)
function Harvest.syncMutations(player, data)
	local saved = data and data:Get("farm_mutations") or {}
	for _, bush in ipairs(Harvest.getOwnedBushes(player)) do
		local key = Harvest.plantKey(bush.model)
		local want = key and saved[key] or nil
		if bush.model:GetAttribute("Mutation") ~= want then
			bush.model:SetAttribute("Mutation", want)
		end
	end
end

function Harvest._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Gardens = _L.Get {"Common", "Modules", "Databases", "Gardens"}
	Plants = _L.Get {"Common", "Modules", "Databases", "Plants"}
	PlantUtility = _L.Get {"Common", "Modules", "Utilities", "PlantUtility"}
	UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

function Harvest._start()

	for _, model in ipairs(CollectionService:GetTagged("HarvestBush")) do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal("HarvestBush"):Connect(register)
	CollectionService:GetInstanceRemovedSignal("HarvestBush"):Connect(function(model)
		local id = model:GetAttribute("BushId")
		if id then
			Harvest._bushes[id] = nil
		end
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		Harvest._state[player] = nil
	end)
end

return Harvest
