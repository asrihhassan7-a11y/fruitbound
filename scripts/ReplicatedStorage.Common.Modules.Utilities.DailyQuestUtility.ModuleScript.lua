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
local DailyQuestUtility

local newRandom = Random.new()

DailyQuestUtility = {
	getCurrentRound = function()
		return math.floor(os.time()/(24*60*60))
	end,
	
	getNextRound = function(n)
		return (n or DailyQuestUtility.getCurrentRound()) + 1
	end,
	
	getTimeLeft = function(n)
		local nextRound = DailyQuestUtility.getNextRound(n)
		return (nextRound*24*60*60) - os.time()
	end,
	
	generateList = function(client)
		local new = {}
		for i = 1, 3 do
			new[i] = DailyQuestUtility.generate(client)
		end
		return new
	end,	
	
	generate = function(client)
		local i, v = ArrayUtility.random(Quests)
		local required = newRandom:NextInteger(v.daily_value_range[1], v.daily_value_range[2])
		local reward = newRandom:NextInteger(v.daily_reward_range[1], v.daily_reward_range[2])
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

return DailyQuestUtility