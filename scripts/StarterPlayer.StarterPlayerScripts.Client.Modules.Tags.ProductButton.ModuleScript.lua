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
local ProductButton = {}
ProductButton.__index = ProductButton

function ProductButton.new(instance)
	local self = setmetatable({}, ProductButton)
	
	self._instance = instance
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function ProductButton:_construct()
	self._trove:Connect(self._instance.MouseButton1Down, function()
		self._name = self._instance.Name
		Purchases.PromptProduct(self._name)
	end)
end

function ProductButton:Destroy()
	self._trove:Destroy()
end

function ProductButton._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
end

function ProductButton._start()
end

return ProductButton