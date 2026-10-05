--> Variables
local _L = _G._L

local Services
local Tracker
local TableUtility
local ArrayUtility
local Codes
local AttributeUtility
local Constants

--> Constants

---------->
local CodesUtility

CodesUtility = {
	getInfo = function(code)
		local _, codeInfo = TableUtility.match(Codes, function(i, v)
			return typeof(v) == "table" and v.value == code
		end)

		return codeInfo
	end,
	
	isValid = function(code)
		return CodesUtility.getInfo(code) ~= nil
	end,
	
	_init = function()
		Codes = _L.Get {"Server", "Modules", "Databases", "Codes"}
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
		AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return CodesUtility