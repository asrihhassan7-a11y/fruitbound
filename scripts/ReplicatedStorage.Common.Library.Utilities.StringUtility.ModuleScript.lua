--> Variables
local _L = _G._L

local Services

--> Constants

---------->
local StringUtility

StringUtility = {
	esc = function(x)
		return (x:gsub('%%', '%%%%')
			:gsub('^%^', '%%^')
			:gsub('%$$', '%%$')
			:gsub('%(', '%%(')
			:gsub('%)', '%%)')
			:gsub('%.', '%%.')
			:gsub('%[', '%%[')
			:gsub('%]', '%%]')
			:gsub('%*', '%%*')
			:gsub('%+', '%%+')
			:gsub('%-', '%%-')
			:gsub('%?', '%%?'))
	end,
	
	_init = function()
		Services = _L.Get {"Common", "Library", "Services"}
	end,
}

return StringUtility