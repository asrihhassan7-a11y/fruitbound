--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local Ranks
local AttributeUtility
local Constants

--> Constants

---------->
local ClanEmblemUtility

ClanEmblemUtility = {
	getInfo = function(emblemId)
		local _, clanEmblemInfo = TableUtility.match(ClanEmblems, function(i, v)
			return typeof(v) == "table" and v.id == emblemId
		end)

		return clanEmblemInfo
	end,
	
	_init = function()
		ClanEmblems = _L.Get {"Common", "Modules", "Databases", "ClanEmblems"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return ClanEmblemUtility