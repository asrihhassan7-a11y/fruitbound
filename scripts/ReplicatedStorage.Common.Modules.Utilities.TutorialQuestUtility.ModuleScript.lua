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
local TutorialQuestUtility

TutorialQuestUtility = {
	getInfo = function(tutorialQuestId)
		local _, tutorialQuestInfo = TableUtility.match(TutorialQuests, function(i, v)
			return v.id == tutorialQuestId
		end)

		return tutorialQuestInfo
	end,
	
	getList = function(client)
		return {
			{id = "1", required = 1, completed = false, reward = 1000, progress = 0},
			{id = "2", required = 1, completed = false, reward = 1000, progress = 0},
			{id = "3", required = 50, completed = false, reward = 1000, progress = 0}
		}
	end,	
	
	_init = function()
		TutorialQuests = _L.Get {"Common", "Modules", "Databases", "TutorialQuests"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return TutorialQuestUtility