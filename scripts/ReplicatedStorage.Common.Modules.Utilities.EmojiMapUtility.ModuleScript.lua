--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local EmojiMap
local AttributeUtility
local Constants

--> Constants

---------->
local EmojiMapUtility

EmojiMapUtility = {
	getInfo = function(strength)
		local i, v = TableUtility.max(ArrayUtility.filter(EmojiMap, function(i, v)
			return v[1] <= strength
		end), function(i, v)
			return v[1]
		end)
		
		return v
	end,
	
	_init = function()
		EmojiMap = _L.Get {"Common", "Modules", "Databases", "EmojiMap"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return EmojiMapUtility