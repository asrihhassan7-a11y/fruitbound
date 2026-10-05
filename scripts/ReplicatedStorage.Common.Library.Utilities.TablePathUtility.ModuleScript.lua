--> Variables
local _L = _G._L

--> Constants

---------->
local TablePathUtility

TablePathUtility = {
	format = function(path)
		return if typeof(path) == "table" then path elseif path then {path} else {}
	end,
	
	
}

return TablePathUtility