--> Variables
local _L = _G._L

local PlayerRewards
local TableUtility
local Constants

--> Constants

---------->
local DailyGiftUtility

DailyGiftUtility = {
	getInfo = function(dailyGiftId)
		local _, dailyGiftInfo = TableUtility.match(DailyGifts, function(i, v)
			return typeof(v) == "table" and v.id == dailyGiftId
		end)

		return dailyGiftInfo
	end,
	
	getNextId = function(data)
		local value = data:Get("last_daily_gift")
		return if (value.i or 0) + 1 <= 7 then (value.i or 0) + 1 else 1
	end,
	
	getTimeLeft = function(data)
		local value = data:Get("last_daily_gift")
		return Constants.DAILY_GIFT_TIME_INTERVAL - (os.time() - value.t)
	end,
	
	canClaim = function(data, dailyGiftId)
		local nextDailyGiftId = DailyGiftUtility.getNextId(data)
		local value = data:Get("last_daily_gift")
		local timeLeft = DailyGiftUtility.getTimeLeft(data)
		return dailyGiftId == nextDailyGiftId and timeLeft <= 0
	end,

	_init = function()
		DailyGifts = _L.Get {"Common", "Modules", "Databases", "DailyGifts"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return DailyGiftUtility