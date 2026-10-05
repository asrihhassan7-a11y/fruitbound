--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local ClanQuests
local AttributeUtility
local Constants

--> Constants

---------->
local ClanShopItemUtility

ClanShopItemUtility = {
	getInfo = function(clanShopItemId)
		local _, clanShopItemInfo = TableUtility.match(ClanShopItems, function(i, v)
			return typeof(v) == "table" and v.id == clanShopItemId
		end)

		return clanShopItemInfo
	end,
	
	_init = function()
		ClanShopItems = _L.Get {"Common", "Modules", "Databases", "ClanShopItems"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return ClanShopItemUtility