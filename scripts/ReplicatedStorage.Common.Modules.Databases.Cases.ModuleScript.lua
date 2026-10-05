--> Variables
local _L = _G._L

local Network
local Services
local DailyCaseUtility
local PremiumCaseUtility

--> Constants

---------->
local Cases

Cases = {
	{
		name = "Daily Case",
		id = 1,
		rewards = {
			{{{name = "Stat", props = {name = "Gems", value = 10000*10}}}, 1},
			{{{name = "Stat", props = {name = "Gems", value = 7500*10}}}, 1.5},
			{{{name = "Stat", props = {name = "Gems", value = 5000*10}}}, 7.5},
			{{{name = "Stat", props = {name = "Gems", value = 2500*10}}}, 20},
			{{{name = "Stat", props = {name = "Gems", value = 1000*10}}}, 30},
			{{{name = "Stat", props = {name = "Gems", value = 500*10}}}, 40},
		},
		predicate = function()
			return true
		end,
		callback = function(client)
			return DailyCaseUtility.canClaim(client.data)
		end,
		image = "rbxassetid://14315885660"
	},
	
	{
		name = "Premium Case",
		id = 2,
		rewards = {
			{{{name = "Stat", props = {name = "Gems", value = 10000*5*10}}}, 1},
			{{{name = "Stat", props = {name = "Gems", value = 7500*5*10}}}, 1.5},
			{{{name = "Stat", props = {name = "Gems", value = 5000*5*10}}}, 7.5},
			{{{name = "Stat", props = {name = "Gems", value = 2500*5*10}}}, 20},
			{{{name = "Stat", props = {name = "Gems", value = 1000*5*10}}}, 30},
			{{{name = "Stat", props = {name = "Gems", value = 500*5*10}}}, 40},
		},
		predicate = function(client)
			if not client then
				return false
			end
			
			if client.player.MembershipType == Enum.MembershipType.Premium then
				return true
			end
			
			Services.MarketplaceService:PromptPremiumPurchase(client.player)
			
			return false
		end,
		callback = function(client)
			return PremiumCaseUtility.canClaim(client.data)
		end,
		image = "rbxassetid://14315883607"
	},
	
	{
		name = "Wooden Case",
		id = 3,
		rewards = {
			{{{name = "Stat", props = {name = "Gems", value = 2000*5*10}}}, 1},
			{{{name = "Stat", props = {name = "Gems", value = 1500*5*10}}}, 1.5},
			{{{name = "Stat", props = {name = "Gems", value = 1000*5*10}}}, 7.5},
			{{{name = "Stat", props = {name = "Gems", value = 500*5*10}}}, 20},
			{{{name = "Stat", props = {name = "Gems", value = 200*5*10}}}, 30},
			{{{name = "Stat", props = {name = "Gems", value = 100*5*10}}}, 40},
		},
		cost = 1000*10,
		predicate = function(client)
			return client.data:Get({"stats", "Gems"}) >= 1000*10
		end,
		callback = function(client)
			client.data:Set({"stats", "Gems"}, client.data:Get({"stats", "Gems"}) - 1000*10)
			return true
		end,
		image = "rbxassetid://14315882488"
	},
	
	{
		name = "Magical Case",
		id = 4,
		rewards = {
			{{{name = "Boost", props = {name = "Protection_Potion", value = 1}}}, 5},
			{{{name = "Boost", props = {name = "x2_Strength", value = 1}}}, 10},
			{{{name = "Boost", props = {name = "x2_Damage", value = 1}}}, 35},
			{{{name = "Boost", props = {name = "Lucky_Potion", value = 1}}}, 50},
		},
		cost = 5000,
		predicate = function(client)
			return client.data:Get({"stats", "Gems"}) >= 5000*10
		end,
		callback = function(client)
			client.data:Set({"stats", "Gems"}, client.data:Get({"stats", "Gems"}) - 5000*10)
			return true
		end,
		image = "rbxassetid://14315880940"
	},
	
	_init = function()
		Network = _L.Get {"Common", "Library", "Network"}
		Services = _L.Get {"Common", "Library", "Services"}
		DailyCaseUtility = _L.Get {"Common", "Modules", "Utilities", "DailyCaseUtility"}
		PremiumCaseUtility = _L.Get {"Common", "Modules", "Utilities", "PremiumCaseUtility"}
	end,
}

return Cases