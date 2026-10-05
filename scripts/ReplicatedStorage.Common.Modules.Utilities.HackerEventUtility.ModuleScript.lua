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
local HackerEventUtility

HackerEventUtility = {
	getTimeLeft = function(client)
		local joinTime = AttributeUtility.get(client.player, "join_time")
		return Constants.HACKER_EVENT_TIME - (os.time() - joinTime)
	end,

	canClaim = function(client)
		local timeLeft = HackerEventUtility.getTimeLeft(client)
		return timeLeft <= 0 and client.data:Get({"stats", "Hacker_Event_Kills"}) >= Constants.HACKER_EVENT_KILLS
	end,

	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return HackerEventUtility