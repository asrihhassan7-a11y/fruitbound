--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local FreeGifts

--> Constants

---------->
local FreeGiftUtility

FreeGiftUtility = {
	getInfo = function(freeGiftId)
		local _, freeGiftInfo = TableUtility.match(FreeGifts, function(i, v)
			return typeof(v) == "table" and v.id == freeGiftId
		end)

		return freeGiftInfo
	end,

	getTimeLeft = function(player, freeGiftId)
		player = player or _L.Player
		local joinTime = AttributeUtility.get(player, "join_time")
		local freeGiftInfo = FreeGiftUtility.getInfo(freeGiftId)
		if not freeGiftInfo or not joinTime then
			return math.huge -- unknown gift id (or not joined yet): never claimable
		end
		return freeGiftInfo.time - (os.time() - joinTime)
	end,

	canClaim = function(player, freeGiftId)
		player = player or _L.Player
		local freeGifts = AttributeUtility.get(player, "free_gifts")
		local timeLeft = FreeGiftUtility.getTimeLeft(player, freeGiftId)
		return if freeGifts and not freeGifts[freeGiftId] and timeLeft <= 0 then true else false
	end,

	_init = function()
		FreeGifts = _L.Get {"Common", "Modules", "Databases", "FreeGifts"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	end
}

return FreeGiftUtility