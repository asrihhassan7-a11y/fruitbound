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
	harvests = function(data) return stat(data, "Crops_Harvested") end, -- real crops harvested (1 per finished plant)
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
		"crop_legacy",
		"discovered_gardens",
		"farm",
	},

	_init = function() end,
}

-- ============================================================
-- CROP PROGRESSION MIGRATION (server only, called by the Data class on the raw save right after
-- it loads, before anything else reads it). Old harvests counted 6 crop items per crop in
-- stats.Kills; the new counter stats.Crops_Harvested counts real crops (1 per finished plant).
-- One time per save (crop_progression_version), in one synchronous pass (saved together):
--   * stats.Crops_Harvested += floor(Kills / 6)          (Kills itself is never changed)
--   * crop_legacy.rank = rank index from the OLD Kills thresholds (Ranks.legacy_required), so no
--     player's rank ever drops because of the conversion
--   * crop_legacy.achievements[id] = true for unclaimed harvest achievements already completed
--     with the old goal (Achievements.legacy_goal), so nothing claimable is lost
--   * active daily / weekly "Harvest N Fruits" quests (id HARVEST_QUEST_ID, never the tutorial
--     list): required and progress / 6 (completion state and reward kept)
-- ============================================================
ProgressUtility.CROP_PROGRESSION_VERSION = 1
ProgressUtility.LEGACY_ITEMS_PER_CROP = 6
ProgressUtility.HARVEST_QUEST_ID = "1"

local function count(n)
	if typeof(n) ~= "number" or n ~= n or math.abs(n) == math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

--[[
@param save table -- Raw profile data table (not the Data wrapper).
@param ranks table -- Databases.Ranks.
@param achievements table -- Databases.Achievements.
@return boolean -- Whether the save was migrated now (false: already migrated / not a save).
]]
function ProgressUtility.migrateCropProgress(save, ranks, achievements)
	if typeof(save) ~= "table" or typeof(save.stats) ~= "table" then
		return false
	end
	if count(save.crop_progression_version) >= ProgressUtility.CROP_PROGRESSION_VERSION then
		return false
	end
	local per = ProgressUtility.LEGACY_ITEMS_PER_CROP
	local kills = count(save.stats.Kills)
	save.stats.Crops_Harvested = count(save.stats.Crops_Harvested) + kills // per

	local legacy = if typeof(save.crop_legacy) == "table" then save.crop_legacy else {}
	local rank = 1
	for index, info in ipairs(ranks or {}) do
		if typeof(info) == "table" and count(info.legacy_required or info.required) <= kills then
			rank = math.max(rank, index)
		end
	end
	legacy.rank = math.max(count(legacy.rank), rank)
	legacy.achievements = if typeof(legacy.achievements) == "table" then legacy.achievements else {}
	local claimed = if typeof(save.achievements) == "table" then save.achievements else {}
	for _, info in ipairs(achievements or {}) do
		if typeof(info) == "table" and info.progress == "harvests" and typeof(info.legacy_goal) == "number"
			and kills >= info.legacy_goal and claimed[info.id] ~= true then
			legacy.achievements[info.id] = true
		end
	end
	save.crop_legacy = legacy

	if typeof(save.quests) == "table" then
		for kind, list in pairs(save.quests) do
			if kind ~= "tutorial" and typeof(list) == "table" and typeof(list.v) == "table" then
				for _, quest in pairs(list.v) do
					if typeof(quest) == "table" and quest.id == ProgressUtility.HARVEST_QUEST_ID then
						local required = math.max(1, math.round(count(quest.required) / per))
						quest.required = required
						quest.progress = math.min(math.round(count(quest.progress) / per), required)
					end
				end
			end
		end
	end

	save.crop_progression_version = ProgressUtility.CROP_PROGRESSION_VERSION
	return true
end

return ProgressUtility
