--> Variables
local _L = _G._L

local Services

--> Constants

---------->
local MathUtility

MathUtility = {
	remainder = function(n, v)
		local res = n - math.floor(n / v) * v
		return if res == 0 then v else res
	end,
	
	fibonacci = function(n)
		local goldenRatio = (1 + math.sqrt(5)) / 2
		return math.floor((goldenRatio^n - (-goldenRatio)^(-n)) / math.sqrt(5))
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
	end,
}

return MathUtility