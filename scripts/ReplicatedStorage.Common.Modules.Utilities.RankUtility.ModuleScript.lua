--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local Ranks
local AttributeUtility
local Constants

--> Constants

---------->
local RankUtility

RankUtility = {
	getNextInfoFromKills = function(kills)
		local v = RankUtility.getInfoFromKills(kills)
		local i, vv = TableUtility.match(Ranks, function(i, vv)
			return vv.name == v.name
		end)
		return Ranks[i+1]
	end,
	
	getTimeLeft = function(data)
		local value = data:Get("rank_reward")
		return Constants.RANK_REWARD_INTERVAL - (os.time() - value)
	end,

	canClaim = function(data, dailyGiftId)
		local timeLeft = RankUtility.getTimeLeft(data)
		return timeLeft <= 0
	end,
	
	getInfo = function(rankName)
		local _, rankInfo = TableUtility.match(Ranks, function(i, v)
			return typeof(v) == "table" and v.name == rankName
		end)

		return rankInfo
	end,
	
	getInfoFromKills = function(kills)
		local i, v = TableUtility.max(ArrayUtility.filter(Ranks, function(i, v)
			return v.required <= kills
		end), function(i, v)
			return v.required
		end)

		return v, i
	end,
	
	
	has = function(data, rankName, r)
		local rankInfo = RankUtility.getInfo(rankName)
		return data:Get({"stats", if r then "Rebirths" else "Kills"}) >= rankInfo.required
	end,
	
	_init = function()
		Ranks = _L.Get {"Common", "Modules", "Databases", "Ranks"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return RankUtility