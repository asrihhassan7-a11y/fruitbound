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
local QuestUtility

QuestUtility = {
	getInfo = function(questId)
		local _, questInfo = TableUtility.match(Quests, function(i, v)
			return v.id == questId
		end)

		return questInfo
	end,
	
	_init = function()
		Quests = _L.Get {"Common", "Modules", "Databases", "Quests"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return QuestUtility