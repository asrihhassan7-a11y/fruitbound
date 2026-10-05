--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Trove
local Spr
local Audio

--> Constants

------------->
local GamepassButton = {}
GamepassButton.__index = GamepassButton

function GamepassButton.new(instance)
	local self = setmetatable({}, GamepassButton)
	
	self._instance = instance
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function GamepassButton:_construct()
	self._trove:Connect(self._instance.MouseButton1Down, function()
		self._name = self._instance.Name
		Purchases.PromptGamepass(self._name)
	end)
end

function GamepassButton:Destroy()
	self._trove:Destroy()
end

function GamepassButton._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
end

function GamepassButton._start()
end

return GamepassButton