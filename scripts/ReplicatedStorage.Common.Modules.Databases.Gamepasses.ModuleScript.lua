--> Variables
local _L = _G._L

local Network

--> Constants

---------->
return {
	{
		id = 1976589002,
		name = "x2_Damage",
		price = 150,
		icon = "", -- pass is off sale on Roblox (old PvP damage pass); hidden in the Store
		display_name = "x2 Harvest",
		
		callback = function(user)
			return true
		end,
	},
	
	{
		id = 1979540754,
		name = "Triple_Eggs",
		price = 175,
		icon = "rbxassetid://92633806783966",
		display_name = "Triple Hatch",
		
		callback = function(user)
			return true
		end,
	},
	
	{
		id = 1980080480,
		name = "x2_Strength",
		price = 150,
		icon = "rbxassetid://106284743529734",
		display_name = "x2 Coins",
		
		callback = function(user)
			return true
		end,
	},
	
	{
		id = 1979258778,
		name = "VIP",
		price = 200,
		icon = "rbxassetid://112259130229908",
		
		callback = function(user)
			return true
		end,
	},	
	
	{
		id = 1979630745,
		name = "x2_Rebirths",
		price = 150,
		icon = "rbxassetid://105901932551160",
		display_name = "x2 Rebirths",
		
		callback = function(user)
			return true
		end,
	},
	
	{
		id = 1975592984,
		name = "Fast_Hatch",
		price = 75,
		icon = "rbxassetid://97229261651336",
		display_name = "Fast Hatch",
		
		callback = function(user)
			return true
		end,
	},
	
	{
		id = 1975875010,
		name = "5_Pets_Equipped",
		price = 200,
		icon = "rbxassetid://116265341074617",
		display_name = "+5 Fruits Equip",
		
		callback = function(user)
			--user._data:Set({"stats", "Pet_Equip_Space"}, 5)
			return true
		end,
	},
	
	{
		id = 1976306971,
		name = "8_Pets_Equipped",
		price = 350,
		icon = "rbxassetid://135892745073068",
		display_name = "+8 Fruits Equip",
		
		callback = function(user)
			--user._data:Set({"stats", "Pet_Equip_Space"}, 8)
			return true
		end,
	},
	
	{
		id = 1978778780,
		name = "Auto_Rebirth",
		price = 150,
		icon = "rbxassetid://116965724905848",
		display_name = "Auto Rebirth",

		callback = function(user)
			return true
		end,
	},
	
	{
		id = 1977116978, -- if its not working try 0
		name = "Rainbow_Eggs",
		price = 749,
		icon = "rbxassetid://109336828102330",
		display_name = "Rainbow Eggs",

		callback = function(user)
			return true
		end,
	},
	
	_init = function()
		Network = _L.Get {"Common", "Library", "Network"}
	end,
}