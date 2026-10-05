--> Variables
local _L = _G._L

local Cases
local TableUtility
local Services
local Constants

--> Constants

---------->
local CaseUtility

CaseUtility = {
	getInfo = function(caseId)
		local _, caseInfo = TableUtility.match(Cases, function(i, v)
			return typeof(v) == "table" and v.id == caseId
		end)

		return caseInfo
	end,
	
	_init = function()
		TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
		Services = _L.Get {"Common", "Library", "Services"}
		Cases = _L.Get {"Common", "Modules", "Databases", "Cases"}
		Constants = _L.Get {"Common", "Modules", "Constants"}
	end
}

return CaseUtility