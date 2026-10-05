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
	-- RANK PROGRESS = real crops harvested (stats.Crops_Harvested), never below the rank the player had
	-- with the old Kills thresholds (crop_legacy.rank, written once by ProgressUtility.migrateCropProgress).
	getProgress = function(data)
		local value = data:Get({"stats", "Crops_Harvested"})
		return if typeof(value) == "number" and value == value then value else 0
	end,

	-- rank info + index (1 = Rookie) for this player's data
	getInfoFromData = function(data)
		local progress = RankUtility.getProgress(data)
		local index = 1
		for i, v in ipairs(Ranks) do
			if typeof(v) == "table" and v.required <= progress then
				index = math.max(index, i)
			end
		end
		local floor = data:Get({"crop_legacy", "rank"})
		if typeof(floor) == "number" and floor == floor then
			index = math.clamp(math.max(index, math.floor(floor)), 1, #Ranks)
		end
		return Ranks[index], index
	end,

	-- the next rank (nil at max rank)
	getNextInfoFromData = function(data)
		local _, index = RankUtility.getInfoFromData(data)
		return Ranks[index + 1]
	end,

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
		if r then
			-- unchanged rebirth check (the original thresholds)
			return data:Get({"stats", "Rebirths"}) >= (rankInfo.legacy_required or rankInfo.required)
		end
		local _, index = RankUtility.getInfoFromData(data)
		local wanted = rankInfo and table.find(Ranks, rankInfo)
		return wanted ~= nil and index >= wanted
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