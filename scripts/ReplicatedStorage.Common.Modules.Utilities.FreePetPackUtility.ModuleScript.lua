--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local FreeGifts
local Constants

--> Constants

---------->
local FreePetPackUtility

FreePetPackUtility = {
	getTimeLeft = function(player)
		player = player or _L.Player
		local joinTime = AttributeUtility.get(player, "join_time")
		return Constants.FREE_PET_PACK_TIME - (os.time() - joinTime)
	end,

	canClaim = function(player)
		player = player or _L.Player
		local timeLeft = FreePetPackUtility.getTimeLeft(player)
		return timeLeft <= 0
	end,

	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return FreePetPackUtility