--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Trove
local Spr
local Audio
local UIAnimationController

--> Constants

------------->
local PopButton = {}
PopButton.__index = PopButton

function PopButton.new(instance)
	local self = setmetatable({}, PopButton)
	
	self._instance = instance
	
	self._ui_scale = nil
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function PopButton:_construct()
	self._ui_scale = self._instance:FindFirstChild("UIScale") or Create("UIScale", {
		Parent = self._instance
	})
	UIAnimationController.RegisterButton(self._instance, {force = true, hoverScale = 1.05, pressScale = 0.94})
	self._trove:Connect(self._instance.MouseButton1Down, function()
		Audio.Play {name = "ButtonDown1"}
	end)
end

function PopButton:Destroy()
	self._trove:Destroy()
end

function PopButton._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	UIAnimationController = _L.Get {"Client", "Modules", "Controllers", "UIAnimationController"}
end

function PopButton._start()
end

return PopButton