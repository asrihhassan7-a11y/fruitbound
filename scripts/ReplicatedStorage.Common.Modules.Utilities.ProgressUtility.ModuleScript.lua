--> ProgressUtility
-- One place that knows how to read a player's progress for achievements (and anything else).
-- To track something new: add a key here, then use it in Databases.Achievements.

local _L = _G._L

---------->
local ProgressUtility

local function stat(data, name)
	return data:Get({"stats", name}) or 0
end

local READERS = {
	fruits = function(data) return stat(data, "Fruits_Collected") end, -- fruits collected
	harvests = function(data) return stat(data, "Kills") end, -- plants harvested ("Kills" stat reused)
	food = function(data) return stat(data, "Food_Collected") end, -- food collected
	gardens = function(data) return #(data:Get("discovered_gardens") or {}) end, -- gardens discovered
	rebirths = function(data) return stat(data, "Rebirths") end,
	stage = function(data) return stat(data, "Best_Fruit_Stage") end, -- best evolution stage (1 Golden ... 5 Divine)
	coins_earned = function(data) return stat(data, "Total_Strength") end, -- all coins ever earned
	farm_upgrades = function(data) -- farm upgrades bought (the free starter farm doesn't count)
		local n = 0
		for id, owned in pairs(data:Get({"farm", "upgrades"}) or {}) do
			if owned and id ~= "starter" then
				n += 1
			end
		end
		return n
	end,
}

ProgressUtility = {
	get = function(data, key)
		local reader = READERS[key]
		if not reader or not data then
			return 0
		end
		local ok, value = pcall(reader, data)
		return if ok then value else 0
	end,

	-- Data paths to watch so UIs update when progress changes
	trackPaths = {
		{"stats"},
		"discovered_gardens",
		"farm",
	},

	_init = function() end,
}

return ProgressUtility
