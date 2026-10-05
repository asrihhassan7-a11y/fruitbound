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
local UIOpenButton = {}
UIOpenButton.__index = UIOpenButton

function UIOpenButton.new(instance)
	local self = setmetatable({}, UIOpenButton)
	
	self._instance = instance
	
	self._name = instance.Name
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function UIOpenButton:_construct()
	self._trove:Connect(self._instance.MouseButton1Click, function()
		UI.Open({name = self._name})
	end)
end

function UIOpenButton:Destroy()
	self._trove:Destroy()
end

function UIOpenButton._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
end

function UIOpenButton._start()
end

return UIOpenButton