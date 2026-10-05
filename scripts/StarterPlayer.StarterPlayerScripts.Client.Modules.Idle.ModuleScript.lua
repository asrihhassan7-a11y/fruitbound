--> Variables
local _L = _G._L

local Tracker
local Services
local Signal

--> Constants
local IDLE_TIME = 1000
local PLACE_ID = game.PlaceId

------------->
local Idle = {}

function Idle._init()
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
end

function Idle._start()
	_L.Player.Idled:Connect(function(t)
		if t > IDLE_TIME then
			Services.TeleportService:Teleport(PLACE_ID, _L.Player)
		end
	end)
end

return Idle