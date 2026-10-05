--> Variables
local _L = _G._L

local Services
local Signal
local Tracker

--> Constants

------------->
local Tags = {_loaded = false, _objects = {}, _current = nil}

function Tags.Await()
	if not Tags._loaded then
		Tags.Loaded:Wait()
	end
end

function Tags.Get(tagName)
	local tags = Tags._objects[tagName]
	
	if tags then
		return tags.content
	end
end

function Tags._add(tagInstance, tagName)
	local tag = Tags._objects[tagName]
	
	if tag then
		if tag.objects[tagInstance] then
			return
		else
			local newTagObject = tag.content.new(tagInstance)
			tag.objects[tagInstance] = newTagObject
		end
	end
end

function Tags._remove(tagInstance, tagName)
	local tag = Tags._objects[tagName]

	if tag then
		local tagObject = tag.objects[tagInstance]
		
		if tagObject then
			tagObject:Destroy()
		end
	end
end

function Tags._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	
	Tags.Loaded = Signal.new()
end

function Tags._start()
	for _, tagModule in pairs(script:GetChildren()) do
		if tagModule:IsA("ModuleScript") then
			local tagContent = require(tagModule)
			local tagName = tagModule.name
			
			Tags._objects[tagName] = {
				name = tagName,
				content = tagContent,
				objects = {}
			}
		end
	end
	
	for tagName, tag in pairs(Tags._objects) do
		if typeof(tag.content) == "table" and typeof(rawget(tag.content, "_init")) == "function" then
			tag.content._init()
		end
	end

	for tagName, tag in pairs(Tags._objects) do
		if typeof(tag.content) == "table" and typeof(rawget(tag.content, "_start")) == "function" then
			task.spawn(function()
				tag.content._start()
			end)
		end
		
		for _, tagInstance in pairs(Services.CollectionService:GetTagged(tagName)) do
			task.spawn(function()
				Tags._add(tagInstance, tagName)
			end)
		end
		
		Services.CollectionService:GetInstanceAddedSignal(tagName):Connect(function(tagInstance)
			Tags._add(tagInstance, tagName)
		end)

		Services.CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(tagInstance)
			Tags._remove(tagInstance, tagName)
		end)
	end
	
	Tags._loaded = true
	Tags.Loaded:Fire()
end

return Tags