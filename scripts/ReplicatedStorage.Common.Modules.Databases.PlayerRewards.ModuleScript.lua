--> Variables
local _L = _G._L

local PlayerRewardUtility
local StatUtility
local PetUtility
local BoostUtility
local EggUtility
local _Stats
local PowerUtility

--> Constants

---------->
local c

PlayerRewards = {
	{
		name = "Stat",

		callback = function(client, statProps)
			return StatUtility.give(client, statProps)
		end,
		
		getInfo = function(statName)
			return StatUtility.getInfo(statName)
		end,
	},
	
	{
		name = "Title",

		callback = function(client, titleProps)
			return TitleUtility.give(client, titleProps)
		end,

		getInfo = function(titleName)
			return TitleUtility.getInfo(titleName)
		end,
	},
	
	{
		name = "Power",

		callback = function(client, powerProps)
			return PowerUtility.give(client, powerProps)
		end,

		getInfo = function(powerName)
			return PowerUtility.getInfo(powerName)
		end,
	},
	
	{
		name = "Pet",

		callback = function(client, petProps)
			return PetUtility.give(client, petProps)
		end,

		getInfo = function(petName)
			return PetUtility.getInfo(petName)
		end,
	},
	
	{
		name = "Boost",

		callback = function(client, boostProps)
			return BoostUtility.give(client, boostProps)
		end,

		getInfo = function(boostName)
			return BoostUtility.getInfo(boostName)
		end,
	},
	
	{
		name = "Egg",

		callback = function(client, eggProps, i)
			return EggUtility.give(client, eggProps, i)
		end,

		getInfo = function(eggName)
			return EggUtility.getInfo(eggName)
		end,
	},
	
	{
		name = "Fruit",

		callback = function(client, fruitProps)
			return FruitUtility.give(client, fruitProps)
		end,

		getInfo = function(fruitName)
			return FruitUtility.getInfo(fruitName)
		end,
	},
	
	{
		name = "Plant",

		callback = function(client, plantProps)
			return PlantUtility.give(client, plantProps)
		end,

		getInfo = function(plantName)
			return PlantUtility.getInfo(plantName)
		end,
	},

	-- Seeds straight into seed_inventory (they appear as Seed Tools): props = {name = seedId, value = count}
	{
		name = "Seed",

		callback = function(client, seedProps)
			return _L.Get({"Server", "Modules", "Controllers", "FarmingV2"}).giveSeeds(client.player, seedProps.name, seedProps.value)
		end,

		getInfo = function(seedId)
			local seed = _L.Get({"Common", "Modules", "Databases", "SeedPacks"}).getSeed(seedId)
			return seed and {name = seedId, display_name = seed.display_name, image = "", visual = seed.visual} or nil
		end,
	},

	-- A whole Seed Pack rolled with the server pack odds: props = {name = packId, value = count}
	{
		name = "SeedPack",

		callback = function(client, packProps)
			return _L.Get({"Server", "Modules", "Controllers", "FarmingV2"}).givePack(client.player, packProps.name, packProps.value)
		end,

		getInfo = function(packId)
			local pack = _L.Get({"Common", "Modules", "Databases", "SeedPacks"}).getPack(packId)
			return pack and {name = packId, display_name = pack.display_name, image = "", visual = pack.visual} or nil
		end,
	},

	{
		name = "Mount",

		callback = function(client, mountProps)
			return _L.Get {"Common", "Modules", "Utilities", "MountUtility"}.give(client, mountProps)
		end,

		getInfo = function(mountId)
			return _L.Get {"Common", "Modules", "Utilities", "MountUtility"}.getInfo(mountId)
		end,
	},

	_init = function()
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
		StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
		PetUtility = _L.Get {"Common", "Modules", "Utilities", "PetUtility"}
		BoostUtility = _L.Get {"Common", "Modules", "Utilities", "BoostUtility"}
		EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
		FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
		PlantUtility = _L.Get {"Common", "Modules", "Utilities", "PlantUtility"}
		PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
		TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
	end
}

return PlayerRewards