--> Variables
local _L = _G._L

--> Constants

---------->
local Boosts

Boosts = {
	{
		active = true,
		name = "x2_Strength",
		display_name = "x2 Coins (30 min)",
		image = "rbxassetid://13815157449"
	},

	{
		active = true,
		name = "Lucky_Potion",
		display_name = "Lucky Potion (30 min)",
		image = "rbxassetid://13815192926"
	},
	
	{
		active = true,
		name = "Protection_Potion",
		display_name = "Protection Potion",
		image = "rbxassetid://13880084933"
	},
	
	{
		active = true,
		name = "Growth_Speed",
		display_name = "Growth Potion x1.25 (30 min)",
		auto_use = true, -- activates as soon as it is given (crops grow x1.25 faster for 30 min)
		image = "rbxassetid://13880084933"
	},

	{
		active = true,
		name = "x2_Damage",
		display_name = "x2 Damage",
		image = "rbxassetid://13815215971"
	},
}

return Boosts