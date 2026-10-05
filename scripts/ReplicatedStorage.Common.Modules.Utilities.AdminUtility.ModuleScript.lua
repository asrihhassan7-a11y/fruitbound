--> AdminUtility
-- The ADMIN list: add Roblox UserIds here to give someone admin (test) access.
-- The game owner is always an admin.

local AdminUtility = {}

AdminUtility.ADMIN_USER_IDS = {
	419938519, -- NotHexilo: the game owner (owns group 9910341, which owns this game; the owner rule below only covers user-owned games)
}

function AdminUtility.isAdmin(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if table.find(AdminUtility.ADMIN_USER_IDS, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId and game.CreatorId ~= 0 then
		return true
	end
	return false
end

return AdminUtility
