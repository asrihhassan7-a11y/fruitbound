--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local WheelRewards
local AttributeUtility
local Constants

--> Constants

---------->
local WheelRewardUtility

WheelRewardUtility = {
	getInfo = function(wheelRewardId)
		local _, wheelRewardInfo = TableUtility.match(WheelRewards, function(i, v)
			return typeof(v) == "table" and v.id == wheelRewardId
		end)

		return wheelRewardInfo
	end,
	
	getTimeLeft = function(player)
		player = player or _L.Player
		local lastWheelTime = AttributeUtility.get(player, "last_wheel_time")
		return if lastWheelTime then Constants.WHEEL_TIME_INTERVAL - (os.time() - lastWheelTime) else nil
	end,
	
	canClaim = function(player, freeGiftId)
		player = player or _L.Player
		local timeLeft = WheelRewardUtility.getTimeLeft(player)
		return if timeLeft <= 0 then true else false
	end,
	
	_init = function()
		WheelRewards = _L.Get {"Common", "Modules", "Databases", "WheelRewards"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return WheelRewardUtility