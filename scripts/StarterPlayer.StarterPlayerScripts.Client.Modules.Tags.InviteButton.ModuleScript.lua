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
local InviteButton = {}
InviteButton.__index = InviteButton

function InviteButton.new(instance)
	local self = setmetatable({}, InviteButton)
	
	self._instance = instance
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function InviteButton:_construct()
	self._trove:Connect(self._instance.MouseButton1Down, function()
		Services.SocialService:PromptGameInvite(_L.Player)
	end)
end

function InviteButton:Destroy()
	self._trove:Destroy()
end

function InviteButton._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
end

function InviteButton._start()
end

return InviteButton