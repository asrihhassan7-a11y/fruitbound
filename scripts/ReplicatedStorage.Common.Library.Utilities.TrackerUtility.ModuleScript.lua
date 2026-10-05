--> Variables
local _L = _G._L

local Services
local Tracker
local AttributeUtility

--> Constants

---------->
local TrackerUtility

TrackerUtility = {
	fromPropertySignal = function(instance, propertyName)
		if not instance or not propertyName then
			return nil
		end
		
		local newTracker = Tracker.new(instance[propertyName])
		
		newTracker:GiveTask(instance:GetPropertyChangedSignal(propertyName):Connect(function()
			newTracker:Set(instance[propertyName])
		end))
		
		return newTracker
	end,
	
	fromAttributeSignal = function(instance, attributeName)
		if not instance or not attributeName then
			return nil
		end

		local newTracker = Tracker.new(AttributeUtility.get(instance, attributeName))

		newTracker:GiveTask(instance:GetAttributeChangedSignal(attributeName):Connect(function()
			newTracker:Set(AttributeUtility.get(instance, attributeName))
		end))

		return newTracker
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
		Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	end,
}

return TrackerUtility