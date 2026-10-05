--> Variables
local _L = _G._L

local Network
local Shared

--> Constants

---------->
return {
	{
		name = "Punch",
		component = "Punch",
		icon = "rbxassetid://13602409906",
		
		strength = function(playerController)
			local currentStrength = playerController._client.data:Get({"stats", "Strength"})

			--local currentPowerInfo = Shared.GetCurrentPowerInfoFromStrength(currentStrength)
			local bestPowerInfo = Shared.GetBestPowerInfo(playerController._client)
			
			return bestPowerInfo.strength
		end,
	},
	
	{
		name = "Fireball 1",
		required = 0,
		component = "Fireball",
		icon = "rbxassetid://13813496786",
		
		strength = 1,
		damage = 10
	},
	
	{
		name = "Fireball 2",
		required = 10,
		component = "Fireball",
		icon = "rbxassetid://13851536038",

		strength = 2,
		damage = 15
	},
	
	{
		name = "Fireball 3",
		required = 50,
		component = "Fireball",
		icon = "rbxassetid://13851535894",

		strength = 3,
		damage = 25
	},
	
	{
		name = "Fireball 4",
		required = 150,
		component = "Fireball",
		icon = "rbxassetid://13851535672",

		strength = 5,
		damage = 40
	},
	
	{
		name = "Fireball 5",
		required = 400,
		component = "Fireball",
		icon = "rbxassetid://13851535235",

		strength = 8,
		damage = 65
	},
	
	{
		name = "Fireball 6",
		required = 900,
		component = "Fireball",
		icon = "rbxassetid://13851534999",

		strength = 12,
		damage = 105
	},
	
	{
		name = "Fireball 7",
		required = 2200,
		component = "Fireball",
		icon = "rbxassetid://13851534793",

		strength = 20,
		damage = 170
	},
	
	{
		name = "Fireball 8",
		required = 4750,
		component = "Fireball",
		icon = "rbxassetid://13851534586",

		strength = 35,
		damage = 275
	},
	
	{
		name = "Fireball 9",
		required = 10000,
		component = "Fireball",
		icon = "rbxassetid://13851534397",

		strength = 60,
		damage = 445
	},
	
	{
		name = "Fireball 10",
		required = 22500,
		component = "Fireball",
		icon = "rbxassetid://13851534205",

		strength = 100,
		damage = 720
	},
	
	{
		name = "Fireball 11",
		required = 50000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 180,
		damage = 1165
	},
	
	{
		name = "Fireball 12",
		required = 115000,
		component = "Fireball",
		icon = "rbxassetid://13851534205",

		strength = 300,
		damage = 1885
	},

	{
		name = "Fireball 13",
		required = 250000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 550,
		damage = 3050
	},
	
	{
		name = "Fireball 14",
		required = 540000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 900,
		damage = 4935
	},
	
	{
		name = "Fireball 15",
		required = 1250000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 1600,
		damage = 7985
	},
	
	{
		name = "Fireball 16",
		required = 2850000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 2700,
		damage = 12920
	},
	
	{
		name = "Fireball 17",
		required = 6300000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 5000,
		damage = 20905
	},
	
	{
		name = "Fireball 18",
		required = 13500000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 85000,
		damage = 338250
	},
	
	{
		name = "Fireball 19",
		required = 300000000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 150000,
		damage = 547300
	},
	
	{
		name = "Fireball 20",
		required = 675000000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 2750000,
		damage = 885550
	},
	
	{
		name = "Fireball 21",
		required = 4050000000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 5000000,
		damage = 1432850
	},
	
	{
		name = "Fireball 22",
		required = 24300000000,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 8500000,
		damage = 2318400
	},
	
	{
		name = "Fireball 23",
		required = 145800000000 ,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 15000000,
		damage = 3751250
	},
	
	{
		name = "Fireball 24",
		required = 874800000000 ,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 27500000,
		damage = 6069650
	},
	
	{
		name = "Fireball 25",
		required = 5248800000000 ,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 500000000,
		damage = 9820900
	},
	
	{
		name = "Fireball 26",
		required = 31492800000000 ,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 850000000,
		damage = 158900550
	},
	
	{
		name = "Fireball 27",
		required = 188956800000000 ,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 1000000000,
		damage = 257101450
	},
	
	{
		name = "Fireball 28",
		required = 1133740800000000 ,
		component = "Fireball",
		icon = "rbxassetid://13851534074",

		strength = 5000000000,
		damage = 41602000000
	},
	{
		name = "Fireball 29",
		required = 250374080000000000 , 
		component = "Fireball",
		icon = "rbxassetid://13874677184",

		strength = 10000000000,
		damage = 500020000000
	},
	{
		name = "Fireball 30",
		required = 3203740800000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874676962",

		strength = 250000000000,
		damage = 9200200000000
	},
	{
		name = "Fireball 31",
		required = 56000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874676583",

		strength = 1500000000000,
		damage = 100020000000000
	},
	{
		name = "Fireball 32",
		required = 5500000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 50000000000000,
		damage = 1000200000000000
	},
	{
		name = "Fireball 33",
		required = 250000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength =  750000000000000,
		damage = 10002000000000000
	},
	{
		name = "Fireball 34",
		required = 9000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 900000000000000000,
		damage = 100020000000000000
	},
	{
		name = "Fireball 35",
		required =  1250000000000000000000000,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 50000000000000000000,
		damage = 10002000000000000
	},
	{
		name = "Fireball 36",
		required =  1500000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 60000000000000000000000,
		damage = 10002000000000000000
	},
	{
		name = "Fireball 37",
		required = 75000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 1000000000000000000000000,
		damage = 1000200000000000000
	},
	{
		name = "Fireball 38",
		required =  950000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 500000000000000000000000000,
		damage = 100020000000000000000
	},
	{
		name = "Fireball 39",
		required = 15000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 100000000000000000000000000000,
		damage = 100020000000000000000
	},
	{
		name = "Fireball 40",
		required = 950000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 10000000000000000000000000000000,
		damage = 1000200000000000000000000
	},
	{
		name = "Fireball 41",
		required = 95000000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 1000000000000000000000000000000000,
		damage = 1000200000000000000000000
	},
	{
		name = "Fireball 42",
		required = 1000000000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 100000000000000000000000000000000000,
		damage = 1000200000000000000000000
	},
	{
		name = "Fireball 43",
		required = 1000000000000000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 1000000000000000000000000000000000000,
		damage = 100020000000000000000000000
	},
	{
		name = "Fireball 44",
		required = 1000000000000000000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 10000000000000000000000000000000000000,
		damage = 1000200000000000000000000
	},
	{
		name = "Fireball 45",
		required = 10000000000000000000000000000000000000000000 ,
		component = "Fireball",
		icon = "rbxassetid://13874697709",

		strength = 10000000000000000000000000000000000000000000,
		damage = 1000200000000000000000000
	},
	{
		name = "Electro Power",
		component = "Fireball",
		icon = "rbxassetid://14263373398",

		strength = 10000000000000000000000000000000000000000000000,
		damage = 100020000000000000000000000000000000000
	},
	{
		name = "Dark Matter Power",
		component = "Fireball",
		icon = "rbxassetid://14386546433",

		strength = 10000000000000000000000000000000000000000000000,
		damage = 100020000000000000000000000000000000000
	},
	{
		name = "Super Power",
		component = "Fireball",
		icon = "rbxassetid://14458602135",
		
		required = 24300000000,
		
		strength = 8500000,
		damage = 2318400
	},	
	
	_init = function()
		Shared = _L.Get {"Common", "Modules", "Shared"}
	end,
}