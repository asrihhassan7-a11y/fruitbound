--> Variables
local _L = _G._L

--> Constants

---------->
local BindableFunction = {}
BindableFunction.__index = BindableFunction

function BindableFunction.new()
	local self = setmetatable({}, BindableFunction)
	
	self._listeners = {}
	
	return self
end

function BindableFunction:Connect(callback)
	table.insert(self._listeners, callback)
	return {
		Disconnect = function()
			for i, listener in ipairs(self._listeners) do
				if listener == callback then
					table.remove(self._listeners, i)
					break
				end
			end
		end
	}
end

function BindableFunction:Invoke(...)
	local results = {}

	for _, listener in ipairs(self._listeners) do
		local result = listener(...)

		if result then
			table.insert(results, result)
		end
	end

	return unpack(results)
end

return BindableFunction
