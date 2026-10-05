--> Variables
local _L = _G._L

local Network
local Services
local NumberUtility

--> Constants

---------->
local SpecialEvents

SpecialEvents = {
	{
		id = "harvest_frenzy",
		icon = "rbxassetid://107803545719047", 
		
		start_description = [[<stroke color= "rgb(0, 0, 0)" joins="round" thickness="2" transparency="0"><font color= "rgb(255, 255, 255)"><font color= "rgb(0, 255, 0)">Harvest Frenzy!</font>: Every harvest gives double Coins for 5 minutes!</font></stroke>]],
		end_description = [[<stroke color= "rgb(0, 0, 0)" joins="round" thickness="2" transparency="0"><font color= "rgb(255, 255, 255)"><font color= "rgb(0, 255, 0)">Harvest Frenzy!</font>: The frenzy is over, the next one will start soon!</font></stroke>]],
		
		duration = 5 * 60,
		
		-- Runs on the server: doubles the global coin multiplier while the event lasts
		callback = function()
			local multiplier = workspace:FindFirstChild("GlobalStrengthMultiplier")
			local before = multiplier and multiplier.Value or 1
			if multiplier then
				multiplier.Value = before * 2
			end
			return function()
				if multiplier then
					multiplier.Value = before
				end
			end
		end,
	},
	
	_init = function()
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
}

return SpecialEvents