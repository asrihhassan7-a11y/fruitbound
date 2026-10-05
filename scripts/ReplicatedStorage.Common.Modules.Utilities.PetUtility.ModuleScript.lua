--> Variables
local _L = _G._L

local Pets
local TableUtility
local Services
local PetRarityUtility
local PetRarities
local ArrayUtility

--> Constants

---------->
local PetUtility

PetUtility = {
	getInfo = function(petName)
		local _, petInfo = TableUtility.match(Pets, function(i, v)
			return v.name == petName
		end)

		return petInfo
	end,
	
	getTotalBoost = function(data)
		local n = 1
		
		for _, a in pairs(PetUtility.getEquipped(data)) do
			local i = PetUtility.getInfo(a.name)
			n += i.boost * (if a.tier == "Rainbow" then 2 else 1)
		end
		
		return n
	end,
	
	hasInventorySpace = function(data, forr)
		forr = forr or 0
		return data:Get({"stats", "Pet_Storage_Space"}) - (forr + TableUtility.length(data:Get("pets"))) >= 0
	end,
	
	isEquipped = function(data, petUid)
		local petData = PetUtility.getData(data, petUid)
		
		if petData then
			return petData.equipped
		else
			return false
		end
	end,
	
	getCraftable = function(data, petUid)
		local petData = PetUtility.getData(data, petUid)

		if not petData then
			return {}
		end

		local petInfo = PetUtility.getInfo(petData.name)
		
		return ArrayUtility.filter(TableUtility.deep.clone(data:Get("pets")), function(i, v)
			return v.name == petInfo.name and not v.tier
		end)
	end,
	
	getEquipped = function(data)
		return TableUtility.filter(data:Get("pets"), function(i, v)
			return v.equipped
		end)
	end,
	
	hasEquipSpace = function(data)
		return data:Get({"stats", "Pet_Equip_Space"}) - (TableUtility.length(PetUtility.getEquipped(data))) > 0
	end,
	
	setEquipped = function(data, petUids, newState)
		petUids = if typeof(petUids) == "table" then petUids else {petUids}

		data:Set("pets", TableUtility.map(TableUtility.deep.clone(data:Get("pets")), function(i, v)
			if table.find(petUids, v.uid) then
				if newState and PetUtility.hasEquipSpace(data) then
					v.equipped = true
				else
					v.equipped = false
				end
			end
			
			return i, v
		end))
	end,
	
	getData = function(data, petUid)
		local petsData = data:Get("pets")
		
		local _, petData = TableUtility.match(petsData, function(i, v)
			return v.uid == petUid
		end)
		
		return petData
	end, 
	
	getBoost = function(data, petUid)
		local petData = PetUtility.getData(data, petUid)
		
		if petData then
			local petInfo = PetUtility.getInfo(petData.name)
			
			if petInfo then
				return petInfo.boost * (if petData.tier == "Rainbow" then 2 else 1)
			end
		end
	end,

	give = function(client, petProps)
		local clientData = client.data

		local petName = petProps.name
		local petValue = petProps.value or 1
		local petTier = petProps.tier
		
		if clientData and petName then
			local currentPetsData = TableUtility.deep.clone(clientData:Get("pets"))
			
			for i = 1, petValue do
				local petUid = petProps.uid or Services.HttpService:GenerateGUID(false)

				local newPetData = {
					name = petName,
					uid = petUid,
					tier = petTier
				}
				
				table.insert(currentPetsData, newPetData)
			end

			clientData:Set("pets", currentPetsData)

			return true, {{
				name = petName,
				reward_name = "Pet",
				value = petValue,
				tier = petTier
			}}
		end

		return false
	end,
	
	remove = function(data, petUids)
		petUids = if typeof(petUids) == "table" then petUids else {petUids}
		
		local petsData = data:Get("pets")
		local newPetsData = TableUtility.deep.clone(petsData)

		newPetsData = ArrayUtility.filter(newPetsData, function(i, v)
			return not table.find(petUids, v.uid) 
		end)
		
		data:Set("pets", newPetsData)
	end,

	_init = function()
		Pets = _L.Get {"Common", "Modules", "Databases", "Pets", "Pets"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		PetRarities = _L.Get {"Common", "Modules", "Databases", "Pets", "Rarities"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		PetRarityUtility = _L.Get {"Common", "Modules", "Utilities", "PetRarityUtility"}
	end
}

return PetUtility