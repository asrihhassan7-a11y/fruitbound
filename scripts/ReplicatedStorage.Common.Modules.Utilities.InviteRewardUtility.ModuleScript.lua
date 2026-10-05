--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local ClanQuests
local AttributeUtility
local Constants
local InviteRewards

--> Constants

---------->
local InviteRewardUtility

InviteRewardUtility = {
	_init = function()
		InviteRewards = _L.Get {"Common", "Modules", "Databases", "InviteRewards"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end,
	
	getInfo = function(inviteRewardId)
		local _, inviteRewardInfo = TableUtility.match(InviteRewards, function(i, v)
			return v.id == inviteRewardId
		end)

		return inviteRewardInfo
	end,
	
	canClaim = function(data, inviteRewardId)
		if data:Get({"invite_rewards", inviteRewardId}) then
			return false
		end
		
		local inviteRewardInfo = InviteRewardUtility.getInfo(inviteRewardId)
		
		if inviteRewardInfo and inviteRewardInfo.required <= #data:Get({"friends_invited"}) then
			return true
		end
		
		return false
	end,
}

return InviteRewardUtility