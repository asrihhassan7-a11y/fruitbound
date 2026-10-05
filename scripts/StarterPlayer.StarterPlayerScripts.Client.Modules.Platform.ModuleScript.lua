--> Variables
local _L = _G._L

local Tracker
local Services
local Signal

--> Constants


------------->
local Platform = {_current = nil, _loaded = false}

function Platform._init()
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	
	Platform.Loaded = Signal.new()
end

function Platform._start()
	Platform._current = Tracker.new(Platform._get())
	
	Services.UserInputService.LastInputTypeChanged:Connect(function()
		Platform._update()
	end)
	
	Platform._loaded = true
	Platform.Loaded:Fire()
end

function Platform.Await()
	if not Platform._loaded then
		Platform.Loaded:Wait()
	end
end

function Platform.Get()
	return Platform._current:Get()
end

function Platform.Bind(...)
	return Platform._current:Bind(...)
end

function Platform._update()
	Platform._current:Set(Platform._get())
end

function Platform._get()
	if Services.GuiService:IsTenFootInterface() then
		return "Console"
	elseif Services.UserInputService.TouchEnabled and not Services.UserInputService.MouseEnabled then
		return "Mobile"
	else
		return "Desktop"
	end
end

return Platform