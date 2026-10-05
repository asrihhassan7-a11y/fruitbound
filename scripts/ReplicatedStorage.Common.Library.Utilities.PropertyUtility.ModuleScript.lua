--> Variables
local _L = _G._L

local Services

--> Constants

---------->
local PropertyUtility

PropertyUtility = {
	has = function(instance, propertyName)
		if not instance then
			return false
		end
		
		local success, result = pcall(function()
			return instance[propertyName]
		end)
		
		return if success then true else false
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
	end,
}

return PropertyUtility