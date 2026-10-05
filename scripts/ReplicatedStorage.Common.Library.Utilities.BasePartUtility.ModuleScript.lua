--> Variables
local _L = _G._L

local Services

--> Constants

---------->
local BasePartUtility

BasePartUtility = {
	closestPoint = function(part, position)
		local transform = part.CFrame:pointToObjectSpace(position)
		local hs = part.Size * 0.5
		return part.CFrame * Vector3.new(
			math.clamp(transform.x, -hs.x, hs.x),
			math.clamp(transform.y, -hs.y, hs.y),
			math.clamp(transform.z, -hs.z, hs.z)
		)
	end,
	
	
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
	end,
}

return BasePartUtility