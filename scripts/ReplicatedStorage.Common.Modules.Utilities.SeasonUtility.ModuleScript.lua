--> Variables
local _L = _G._L

local Eggs
local TableUtility
local Services
local PlayerRewardUtility
local BoostUtility
local Seasons
local Constants

--> Constants

---------->
local SeasonUtility

SeasonUtility = {
	getCurrentId = function()
		return Constants.CURRENT_SEASON_ID
	end,
	
	getInfo = function(seasonId)
		local _, seasonInfo = TableUtility.match(Seasons, function(i, v)
			return v.id == seasonId
		end)

		return seasonInfo
	end,
	
	getCurrentInfo = function()
		local currentSeasonId = SeasonUtility.getCurrentId()
		return SeasonUtility.getInfo(currentSeasonId)
	end,

	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"} 
		Seasons = _L.Get {"Common", "Modules", "Databases", "Seasons"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return SeasonUtility