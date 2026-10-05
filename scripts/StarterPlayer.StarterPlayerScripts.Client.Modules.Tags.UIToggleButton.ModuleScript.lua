--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Trove
local Spr
local UI

--> Constants

------------->
local UIToggleButton = {}
UIToggleButton.__index = UIToggleButton

function UIToggleButton.new(instance)
	local self = setmetatable({}, UIToggleButton)

	self._instance = instance

	self._name = instance.Name

	self._trove = Trove.new()

	self:_construct()

	return self
end

function UIToggleButton:_construct()
	self._trove:Connect(self._instance.MouseButton1Click, function()
		UI.Toggle({name = self._name})
	end)
end

function UIToggleButton:Destroy()
	self._trove:Destroy()
end

function UIToggleButton._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
end

function UIToggleButton._start()
end

return UIToggleButton