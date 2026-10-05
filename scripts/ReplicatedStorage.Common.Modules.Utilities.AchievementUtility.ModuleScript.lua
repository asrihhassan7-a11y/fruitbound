--> AchievementUtility (shared by server and client)

local _L = _G._L

local Achievements
local ProgressUtility

---------->
local AchievementUtility

AchievementUtility = {
	getAll = function()
		return Achievements
	end,

	getInfo = function(id)
		for _, a in ipairs(Achievements) do
			if a.id == id then
				return a
			end
		end
		return nil
	end,

	-- current progress, clamped to the goal
	getProgress = function(data, id)
		local info = AchievementUtility.getInfo(id)
		if not info then
			return 0, 1
		end
		return math.min(ProgressUtility.get(data, info.progress), info.goal), info.goal
	end,

	isClaimed = function(data, id)
		local claimed = data:Get("achievements") or {}
		return claimed[id] == true
	end,

	isComplete = function(data, id)
		local progress, goal = AchievementUtility.getProgress(data, id)
		return progress >= goal
	end,

	-- "Locked", "Claimable" or "Claimed"
	getState = function(data, id)
		if AchievementUtility.isClaimed(data, id) then
			return "Claimed"
		elseif AchievementUtility.isComplete(data, id) then
			return "Claimable"
		end
		return "Locked"
	end,

	countClaimable = function(data)
		local n = 0
		for _, a in ipairs(Achievements) do
			if AchievementUtility.getState(data, a.id) == "Claimable" then
				n += 1
			end
		end
		return n
	end,

	_init = function()
		Achievements = _L.Get {"Common", "Modules", "Databases", "Achievements"}
		ProgressUtility = _L.Get {"Common", "Modules", "Utilities", "ProgressUtility"}
	end,
}

return AchievementUtility
