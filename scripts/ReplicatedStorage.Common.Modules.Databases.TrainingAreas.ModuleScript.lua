--> Variables
local _L = _G._L

local Services
local Constants

--> Constants

---------->
local TrainingAreas

TrainingAreas = {
	{
		id = 1,
		required = 100,
		multiplier = 1.5
	},
	
	{
		id = 2,
		required = 100000,
		multiplier = 2.5
	},
	{
		id = 3,
		required = 500000000,
		multiplier = 3.5
	},
	
	{
		id = 4,
		required = 10000000000,
		multiplier = 30
	},
	
	{
		id = 5,
		required = 100000000000000,
		multiplier = 32
	},
	{
		id = 6,
		required = 15000000000000000,
		multiplier = 55
	},
	{
		id = 7,
		required = 850000000000000000,
		multiplier = 70
	},
	{
		id = 8,
		required = 25000000000000000000,
		multiplier = 110
	},
	{
		id = 9,
		required = 25000000000000000000000,
		multiplier = 140
	},
	{
		id = 10,
		required = 10000000000000000000000000000000,
		multiplier = 250
	},
	{
		id = 11,
		required = 25000000000000000000000000000000000,
		multiplier = 500
	},
	{
		id = 12,
		required = 500000000000000000000000000000000000000,
		multiplier = 750
	},
	{
		id = 13,
		required = 950000000000000000000000000000000000000000,
		multiplier = 1500
	},
	--{
	--	id = 11,
	--	required = {bindings = {{"stats", "Event_Eggs_1_Opened"}}, callback = function(data)
		--	return data:Get({"stats", "Event_Eggs_1_Opened"}) >= 5
		--end},
		--error_message = "❌ You need to open 5 Event Eggs to use this area!",
		--multiplier = 250
	--},
	{
		id = 14,
		required = 50000000000000000000000000000000000000000000, 
		multiplier = 2350
	},
	{
		id = 15,
		required = 100000000000000000000000000000000000000000000000000000,
		multiplier = 2950
	},
	{
		id = 16,
		required = 100000000000000000000000000000000000000000000000000000000000, 
		multiplier = 3675
	},
	{
		id = 17,
		required = 1000000000000000000000000000000000000000000000000000000000000000,
		multiplier = 4600
	},
	{
		id = 18,
		required = 50000000000000000000000000000000000000000000000000000000000000000000,
		multiplier = 5500
	},
	{
		id = 19,
		required = 100000000000000000000000000000000000000000000000000000000000000000000,
		multiplier = 6500
	},
}

return TrainingAreas