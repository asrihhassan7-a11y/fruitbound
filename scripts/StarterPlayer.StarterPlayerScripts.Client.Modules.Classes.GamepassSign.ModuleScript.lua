--> Variables
local _L = _G._L

local Services
local Signal
local Tracker
local Data
local TableUtility
local AttributeUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Network
local TrackerUtility
local Gamepasses
local ArrayUtility

--> Constants
local RANDOM_DISPLAY_TIME = 20

------------->
local GamepassSign = {}
GamepassSign.__index = GamepassSign

function GamepassSign.new(props)
	local self = setmetatable({}, GamepassSign)
	
	self._instance = props.instance
	
	self._trove = Trove.new()
	
	self:_construct()
	
	return self
end

function GamepassSign:_construct()
	self._instance.Adornee = self._instance.Parent
	self._instance.Parent = _L.PlayerGui
	
	self._buy = self._instance:WaitForChild("Main"):WaitForChild("Buy")
	self._icon = self._instance:WaitForChild("Main"):WaitForChild("Icon")
	self._title = self._instance:WaitForChild("Main"):WaitForChild("Title")
	self._price = self._buy:WaitForChild("TextLabel")
	
	if self._instance.Name == "SurfaceGui" then
		self:display_random()
		self._trove:Add(Timer.Simple(RANDOM_DISPLAY_TIME, function()
			self:display_random()
		end))
	else
		self:display(self._instance.Name)
	end
end

function GamepassSign:display_random()
	local i, v = ArrayUtility.random(Gamepasses)
	self:display(v.name)
end

function GamepassSign:display(gamepassName)
	local gamepassInfo = GamepassUtility.getInfo(gamepassName)
	
	if gamepassInfo then
		self._icon.Image = gamepassInfo.icon
		self._buy.Name = gamepassInfo.name
		self._price.Text = " "..NumberUtility.commas(gamepassInfo.price)
		self._title.Text = gamepassInfo.display_name or gamepassInfo.name
	end
end

function GamepassSign:Destroy()
	self._trove:Destroy()
end

function GamepassSign._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Gamepasses = _L.Get {"Common", "Modules", "Databases", "Gamepasses"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	GamepassUtility = _L.Get {"Common", "Modules", "Utilities", "GamepassUtility"}
end

function GamepassSign._start()
	repeat task.wait() until _G.persistent_loaded

	--for _, v in pairs(_L.Map:WaitForChild("GamepassSigns"):GetChildren()) do
	--	for _, gamepassSignInstance in pairs(v:GetChildren()) do
	--		if gamepassSignInstance:IsA("SurfaceGui") then
	--			task.spawn(function()
	--				GamepassSign.new({instance = gamepassSignInstance})
	--			end)
	--		end
	--	end
	--end
end

return GamepassSign