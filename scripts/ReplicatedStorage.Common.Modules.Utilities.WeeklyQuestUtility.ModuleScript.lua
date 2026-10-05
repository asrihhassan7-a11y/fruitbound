--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local ClanQuests
local AttributeUtility
local Constants
local Quests

--> Constants

---------->
local WeeklyQuestUtility

local newRandom = Random.new()

WeeklyQuestUtility = {
	getCurrentRound = function()
		return math.floor(os.time()/(24*60*60*7))
	end,
	
	getNextRound = function(n)
		return (n or WeeklyQuestUtility.getCurrentRound()) + 1
	end,
	
	getTimeLeft = function(n)
		local nextRound = WeeklyQuestUtility.getNextRound(n)
		return (nextRound*24*60*60*7) - os.time()
	end,
	
	generateList = function(client)
		local new = {}
		for i = 1, 3 do
			new[i] = WeeklyQuestUtility.generate(client)
		end
		return new
	end,	

	generate = function(client)
		local i, v = ArrayUtility.random(Quests)

		local required = newRandom:NextInteger(v.weekly_value_range[1], v.weekly_value_range[2])
		local reward = newRandom:NextInteger(v.weekly_reward_range[1], v.weekly_reward_range[2])
		return {
			id = v.id,
			required = required,
			completed = false,
			reward = reward,
			progress = 0
		}
	end,
	
	_init = function()
		Quests = _L.Get {"Common", "Modules", "Databases", "Quests"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return WeeklyQuestUtility