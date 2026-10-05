--> Variables
local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

--> Constants

---------->
local Loader = {
	Common = {}, Server = {}, Client = {}
}

TableUtility = {
	deep = {
		get = function(t, p)
			local n = 0

			if TableUtility.length(p) == 0 then
				return t
			end

			for i = 1, TableUtility.length(p) do
				if i == TableUtility.length(p) then 
					return t[p[i]]
				end

				if t[p[i]] and typeof(t[p[i]]) == "table" then
					t = t[p[i]] 
				else
					break
				end
			end
		end,
	},

	length = function(t)
		local n = 0
		for k, v in pairs(t) do
			n += 1
		end
		return n
	end,
}

function Loader._start(props)
	local instance = props.instance

	local _script = getfenv(2).script
	local modules = {}

	local function translate(tbl, parent)
		for _, child in pairs(parent:GetChildren()) do
			if child:IsA("ModuleScript") then
				local moduleName = child.Name

				table.insert(modules, {
					parentTbl = tbl,
					instance = child,
					name = moduleName,
					content = nil
				})
			elseif child:IsA("Folder") then
				tbl[child.Name] = {}
				translate(tbl[child.Name], child)
			end
		end
	end

	translate(Loader[_script.Name], instance)

	for _, module in pairs(modules) do
		task.spawn(function()
			module.content = require(module.instance)
			module.parentTbl[module.name] = module.content
		end)
	end

	for _, module in pairs(modules) do
		if typeof(module.content) == "table" and typeof(rawget(module.content, "_init")) == "function" then
			local p = tick()
			local completed = false
			local warned = false
			
			task.spawn(function()
				while not completed do
					if tick() - p >= 5 and not warned then
						warned = true
						warn('Infinite yield possible while initializing "'..module.name..'"')
					end
					
					task.wait()
				end
			end)
			
			module.content._init()
			
			completed = true
			
			print("["..module.name.."]: *initialized*")
		end
	end

	for _, module in pairs(modules) do
		if typeof(module.content) == "table" and typeof(rawget(module.content, "_start")) == "function" then
			task.spawn(function()
				module.content._start()
			end)
		end
	end
end

function Loader.Get(path)
	local result = TableUtility.deep.get(Loader, path)
	
	if not result then
		warn('Failed to retrieve "'..path[#path]..'"')
	end
	
	return result
end


return Loader

