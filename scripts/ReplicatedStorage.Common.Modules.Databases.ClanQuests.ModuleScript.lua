--> Variables
local _L = _G._L

local Network
local Services
local NumberUtility

--> Constants

---------->
local ClanQuests

ClanQuests = {
	-- counts REAL crops (clan crops_harvested, 1 per finished plant): was 2,500 on the legacy 6-item "kills"
	{id = "1", icon = "rbxassetid://14304116782", description = "Harvest 420 Fruits", server_predicate = function(clan, client)
		return (clan._data:Get("crops_harvested") or 0) >= 420
	end, client_predicate = function(clanData, playerData)
		return (clanData:Get("crops_harvested") or 0) >= 420
	end, reward = {{
		name = "Stat",
		props = {
			name = "Crowns",
			value = 2500
		}
	}}, fetch_progress = function(clanData, playerData)
		return (clanData:Get("crops_harvested") or 0) / 420
	end, fetch_format = function(clanData, playerData)
		return NumberUtility.commas((clanData:Get("crops_harvested") or 0)).."/"..NumberUtility.commas(420)
	end,},

	{id = "2", icon = "rbxassetid://14304120449", description = "Collect 500 Food", server_predicate = function(clan, client)
		return clan._data:Get("deaths") >= 500
	end, client_predicate = function(clanData, playerData)
		return clanData:Get("deaths") >= 500
	end, reward = {{
		name = "Stat",
		props = {
			name = "Crowns",
			value = 1500
		}
	}}, fetch_progress = function(clanData, playerData)
		return clanData:Get("deaths") / 500
	end, fetch_format = function(clanData, playerData)
		return NumberUtility.commas(clanData:Get("deaths")).."/"..NumberUtility.commas(500)
	end,},

	{id = "3", icon = "rbxassetid://14356582980", description = "Open 5000 Eggs", server_predicate = function(clan, client)
		return clan._data:Get("eggs_opened") >= 5000
	end, client_predicate = function(clanData, playerData)
		return clanData:Get("eggs_opened") >= 5000
	end, reward = {{
		name = "Stat",
		props = {
			name = "Crowns",
			value = 2000
		}
	}}, fetch_progress = function(clanData, playerData)
		return clanData:Get("eggs_opened") / 5000
	end, fetch_format = function(clanData, playerData)
		return NumberUtility.commas(clanData:Get("eggs_opened")).."/"..NumberUtility.commas(5000)
	end,},

	{id = "4", icon = "rbxassetid://107803545719047", description = "Reach 50TDD Coins", server_predicate = function(clan, client)
		return clan._data:Get("strength") >= 50000000000000000000000000000000000000000000
	end, client_predicate = function(clanData, playerData)
		return clanData:Get("strength") >= 50000000000000000000000000000000000000000000
	end, reward = {{
		name = "Stat",
		props = {
			name = "Crowns",
			value = 2500
		}
	}}, fetch_progress = function(clanData, playerData)
		return clanData:Get("strength") / 50000000000000000000000000000000000000000000
	end, fetch_format = function(clanData, playerData)
		return NumberUtility.short(clanData:Get("strength")).."/"..NumberUtility.short(50000000000000000000000000000000000000000000)
	end,},

	{id = "5", icon = "rbxassetid://14366828073", description = "Rebirth 1,000 Times", server_predicate = function(clan, client)
		return clan._data:Get("rebirths") >= 1000
	end, client_predicate = function(clanData, playerData)
		return clanData:Get("rebirths") >= 1000
	end, reward = {{
		name = "Stat",
		props = {
			name = "Crowns",
			value = 2000
		}
	}}, fetch_progress = function(clanData, playerData)
		return clanData:Get("rebirths") / 1000
	end, fetch_format = function(clanData, playerData)
		return NumberUtility.commas(clanData:Get("rebirths")).."/"..NumberUtility.commas(1000)
	end,},
	
	{id = "6", icon = "rbxassetid://14213404254", description = "Feed Fruits 750 Times", server_predicate = function(clan, client)
		return clan._data:Get("kings") >= 750
	end, client_predicate = function(clanData, playerData)
		return clanData:Get("kings") >= 750
	end, reward = {{
		name = "Stat",
		props = {
			name = "Crowns",
			value = 3000
		}
	}}, fetch_progress = function(clanData, playerData)
		return clanData:Get("kings") / 750
	end, fetch_format = function(clanData, playerData)
		return NumberUtility.commas(clanData:Get("kings")).."/"..NumberUtility.commas(750)
	end,},

	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
}

return ClanQuests