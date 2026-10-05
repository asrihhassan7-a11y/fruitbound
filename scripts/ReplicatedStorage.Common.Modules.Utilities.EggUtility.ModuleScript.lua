--> Variables
local _L = _G._L

local Eggs
local TableUtility
local Services
local PlayerRewardUtility
local BoostUtility
local FruitEggRewards
local FruitUtility

--> Constants

---------->
local EggUtility

EggUtility = {
	getInfo = function(eggName)
		local _, eggInfo = TableUtility.match(Eggs, function(i, v)
			return v.name == eggName
		end)

		return eggInfo
	end,

	-- Look up the fruit reward distribution for a given egg name
	isContentApproved = function(eggName)
		if eggName == nil then
			for _, pool in ipairs(FruitEggRewards) do
				if EggUtility.isContentApproved(pool.egg_name) then
					return true
				end
			end
			return false
		end

		local eggInfo = EggUtility.getInfo(eggName)
		local _, pool = TableUtility.match(FruitEggRewards, function(_, entry)
			return entry.egg_name == eggName
		end)
		if not eggInfo or eggInfo.is_exclusive or not pool or pool.currency ~= "Gems"
			or pool.price ~= eggInfo.price or pool.price <= 0 or typeof(pool.fruits) ~= "table" or #pool.fruits == 0 then
			return false
		end

		local fruitModels = game:GetService("ReplicatedStorage").Assets.Models.Fruits
		local totalChance = 0
		local seen = {}
		for _, reward in ipairs(pool.fruits) do
			local info = typeof(reward.name) == "string" and FruitUtility.getInfo(reward.name) or nil
			local model = info and fruitModels:FindFirstChild(info.model or info.name)
			local chance = reward.chance
			if not info or info.admin_only or seen[reward.name] or info.rarity ~= reward.rarity
				or not model or not model:IsA("Model") or not model.PrimaryPart
				or typeof(info.boost) ~= "number" or info.boost <= 0
				or typeof(info.max_level) ~= "number" or info.max_level < 1
				or typeof(info.base_exp) ~= "number" or info.base_exp <= 0
				or typeof(info.exp_curve) ~= "number" or info.exp_curve < 1
				or typeof(chance) ~= "number" or chance ~= chance or math.abs(chance) == math.huge or chance <= 0 then
				return false
			end
			seen[reward.name] = true
			totalChance += chance
		end
		return math.abs(totalChance - 100) <= 0.001
	end,

	-- Guaranteed (no RNG) order used for accounts where paid random items are restricted.
	-- Built once per Egg from the same chances: over every 100 hatches each Fruit appears exactly
	-- `chance` times (smooth weighted round robin, so rarer Fruits are spread out, not bunched).
	getGuaranteedSequence = function(eggName)
		EggUtility._guaranteed = EggUtility._guaranteed or {}
		local cached = EggUtility._guaranteed[eggName]
		if cached then
			return cached
		end
		local rewards = EggUtility.getFruitRewards(eggName)
		if typeof(rewards) ~= "table" or #rewards == 0 then
			return nil
		end
		local total, current, sequence = 0, {}, {}
		for i, reward in ipairs(rewards) do
			total += reward.chance
			current[i] = 0
		end
		local length = math.max(1, math.floor(total + 0.5))
		for _ = 1, length do
			local best = 1
			for i, reward in ipairs(rewards) do
				current[i] += reward.chance
				if current[i] > current[best] then
					best = i
				end
			end
			current[best] -= total
			table.insert(sequence, rewards[best].name)
		end
		EggUtility._guaranteed[eggName] = sequence
		return sequence
	end,

	-- The Fruit the next guaranteed hatch gives (offset 0 = next, 1 = the one after...)
	getGuaranteedNext = function(data, eggName, offset)
		local sequence = EggUtility.getGuaranteedSequence(eggName)
		if not sequence then
			return nil
		end
		local done = data and data:Get({"restricted_hatch", eggName}) or 0
		if typeof(done) ~= "number" or done ~= done or done < 0 then
			done = 0
		end
		return sequence[((math.floor(done) + (offset or 0)) % #sequence) + 1]
	end,

	getFruitRewards = function(eggName)
		local _, rewardInfo = TableUtility.match(FruitEggRewards, function(i, v)
			return v.egg_name == eggName
		end)

		return rewardInfo and rewardInfo.fruits or nil
	end,

	give = function(client, eggProps)
		if typeof(eggProps) ~= "table" or not EggUtility.isContentApproved(eggProps.name) then
			return false
		end

		local clientData = client.data
		local clientPlayerController = client.player_controller
		
		local eggName = eggProps.name
		local eggValue = eggProps.value or 1
		local eggInfo = EggUtility.getInfo(eggName)
		
		if clientPlayerController then
			local clan = clientPlayerController:get_clan()

			if clan then
				clan:increment("eggs_opened", eggValue)
			end
			clientPlayerController:_quests_progress("3", eggValue)
			clientPlayerController:_tutorial_quests_progress("1", eggValue)
		end
		
		if clientData and eggName and eggValue then
			local gen = {}
			
			-- Fruit hatching never falls back to legacy Pet pools.
			local fruitRewards = EggUtility.getFruitRewards(eggName)
			if not eggInfo or typeof(fruitRewards) ~= "table" or #fruitRewards == 0 then
				return false
			end
			local fruitModels = game:GetService("ReplicatedStorage").Assets.Models.Fruits
			for _, reward in ipairs(fruitRewards) do
				local chance = reward.chance
				local fruitInfo = typeof(reward.name) == "string" and FruitUtility.getInfo(reward.name) or nil
				local modelName = fruitInfo and (fruitInfo.model or fruitInfo.name) or nil
				if typeof(chance) ~= "number" or chance ~= chance or math.abs(chance) == math.huge or chance <= 0 or not modelName or not fruitModels:FindFirstChild(modelName) then
					return false
				end
			end
			local rewardPool = fruitRewards
			local rewardType = "Fruit"
			-- restricted accounts: the server already picked the exact Fruits (no roll, no luck)
			local guaranteed = eggProps.guaranteed
			if guaranteed ~= nil and (typeof(guaranteed) ~= "table" or #guaranteed ~= eggValue) then
				return false
			end
			
			-- Upgrade Tree luck: rare rewards (chance under 10) get a bigger weight
			local treeLuck = _L.Get({"Common", "Modules", "Utilities", "UpgradeTreeUtility"}).getLuckMultiplier(clientData)
				* _L.Get({"Common", "Modules", "Utilities", "TitleUtility"}).getMultiplier(clientData, "luck")
			
			for d = 1, eggValue do
				if guaranteed then
					local n = guaranteed[d]
					if not clientData:Get({"auto_delete", n}) then
						table.insert(gen, n)
					end
					continue
				end
				local bestLuckInfo = LuckPassUtility.getBestInfo(clientData)
				local n = RandomUtility.chance(TableUtility.map(rewardPool, function(i, v)
					local weight = v.chance + (if BoostUtility.has(client.data, "Lucky_Potion") then eggInfo.luck else 0)
					if v.chance < 10 then
						weight *= treeLuck
					end
					return v.name, weight
				end))
				
				if not clientData:Get({"auto_delete", n}) then
					table.insert(gen, n)
				end
			end
			
			local rew = TableUtility.map(gen, function(i, v)
				return i, {name = rewardType, props = {name = v, value = 1, tier = if v ~= "Apple" and client.purchases:OwnsGamepass("Rainbow_Eggs") then "Rainbow" else nil}} -- the starter Apple always hatches normal
			end)
			
			local rewardsGiven = PlayerRewardUtility.give(client, rew)
			if not rewardsGiven then
				return false
			end

			-- server only: announce extremely rare fruits to the whole server (one line per fruit actually hatched)
			if game:GetService("RunService"):IsServer() and client.player_controller then
				local ok, HatchAnnounce = pcall(_L.Get, {"Server", "Modules", "Controllers", "HatchAnnounce"})
				if ok and HatchAnnounce then
					local player = client.player_controller._instance
					task.spawn(HatchAnnounce.announce, player, table.clone(gen))
				end
			end
			
			local f = TableUtility.map(rew, function(i, v)
				return i, {
					reward_name = rewardType,
					name = v.props.name,
					value = v.props.value,
					tier = v.props.tier
				}
			end)
			
			return true, f
		end

		return false
	end,

	_init = function()
		Eggs = _L.Get {"Common", "Modules", "Databases", "Eggs"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"} 
		BoostUtility = _L.Get {"Common", "Modules", "Utilities", "BoostUtility"}
		LuckPassUtility = _L.Get {"Common", "Modules", "Utilities", "LuckPassUtility"}
		FruitEggRewards = _L.Get {"Common", "Modules", "Databases", "Fruits", "FruitEggRewards"}
		FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	end
}

return EggUtility