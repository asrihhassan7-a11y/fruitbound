--> Variables
local _L = _G._L

local Fruits
local TableUtility
local Services
local FruitRarities

--> Constants

---------->
local FruitRarityUtility

FruitRarityUtility = {
	getInfo = function(rarityName)
		local _, fruitRarity = TableUtility.match(FruitRarities, function(i, v)
			return v.name == rarityName
		end)

		return fruitRarity
	end,
	
	_init = function()
		Fruits = _L.Get {"Common", "Modules", "Databases", "Fruits", "Fruits"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		FruitRarities = _L.Get {"Common", "Modules", "Databases", "Fruits", "Rarities"}
	end
}

return FruitRarityUtility