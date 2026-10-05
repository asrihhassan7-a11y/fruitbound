--> Variables
local _L = _G._L

local Gamepasses
local TableUtility
local Services
local PlayerRewardUtility
local BoostUtility
local LuckPassUtility

--> Constants

---------->
local GamepassUtility

GamepassUtility = {
	getInfo = function(gamepassName)
		local _, gamepassInfo = TableUtility.match(Gamepasses, function(i, v)
			return v.name == gamepassName
		end)

		return gamepassInfo
	end,

	_init = function()
		Gamepasses = _L.Get {"Common", "Modules", "Databases", "Gamepasses"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"} 
	end
}

return GamepassUtility