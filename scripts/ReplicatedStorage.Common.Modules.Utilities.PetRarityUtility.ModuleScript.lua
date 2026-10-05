--> Variables
local _L = _G._L

local Pets
local TableUtility
local Services

--> Constants

---------->
local PetRarityUtility

PetRarityUtility = {
	getInfo = function(rarityName)
		local _, petRarity = TableUtility.match(PetRarities, function(i, v)
			return v.name == rarityName
		end)

		return petRarity
	end,
	
	_init = function()
		Pets = _L.Get {"Common", "Modules", "Databases", "Pets", "Pets"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		PetRarities = _L.Get {"Common", "Modules", "Databases", "Pets", "Rarities"}
	end
}

return PetRarityUtility