--> Variables
local _L = _G._L

local Services

--> Constants

---------->
local AttributeUtility

AttributeUtility = {
	waitFor = function(instance, attributeName)
		if not instance or not attributeName then
			return nil
		end
		
		if AttributeUtility.get(instance, attributeName) == nil then
			instance:GetAttributeChangedSignal(attributeName):Wait()
		end
		
		return AttributeUtility.get(instance, attributeName)
	end,
	
	set = function(instance, attributeName, value)
		instance:SetAttribute(attributeName, if typeof(value) == "table" then Services.HttpService:JSONEncode(value) else value)
	end,
	
	get = function(instance, attributeName)
		local value = instance:GetAttribute(attributeName)
		if typeof(value) ~= "string" then
			return value -- only strings can hold encoded tables
		end
		
		local isTable, result = pcall(function()
			return Services.HttpService:JSONDecode(value)
		end)
		
		return if isTable then result else value
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
	end,
}

return AttributeUtility