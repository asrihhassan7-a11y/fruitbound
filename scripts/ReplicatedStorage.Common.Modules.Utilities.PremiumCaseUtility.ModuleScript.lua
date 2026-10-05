--> Variables
local _L = _G._L

local PlayerRewards
local TableUtility
local Constants

--> Constants

---------->
local PremiumCaseUtility

PremiumCaseUtility = {
	getTimeLeft = function(data)
		local value = data:Get("last_premium_case")
		return Constants.PREMIUM_CASE_TIME_INTERVAL - (os.time() - value)
	end,
	
	canClaim = function(data)
		local value = data:Get("last_premium_case")
		local timeLeft = PremiumCaseUtility.getTimeLeft(data)
		return timeLeft <= 0
	end,

	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return PremiumCaseUtility