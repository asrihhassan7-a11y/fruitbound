--> Variables
local _L = _G._L

local Services
local Network
local Audio
local TableUtils
local Character
local Shared
local RandomUtility
local Timer
local Create
local NumberUtility
local TableUtility
local Tags
local DictionaryUtility
local cancellableDelay
local Tracker
local Powers
local PowerComponents
local AttributeUtility
local WheelRewards
local DailyGiftUtility
local FreeGiftUtility
local WheelRewardUtility
local PetUtility
local PowerComponentUtility
local Egg
local TableTracker
local TrackerUtility
local Portal

--> Constants

------------->
local Player = {_objects = {}}
Player.__index = Player

function Player._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Character = _L.Get {"Client", "Modules", "Controllers", "Character"}
	Egg = _L.Get {"Client", "Modules", "Controllers", "Egg"}
	Portal = _L.Get {"Client", "Modules", "Controllers", "Portal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	PetUtility = _L.Get {"Common", "Modules", "Utilities", "PetUtility"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AreaUtility = _L.Get {"Common", "Modules", "Utilities", "AreaUtility"}
end

function Player._start()
end

function Player.new(props)
	local self = setmetatable({}, Player)
	
	self._instance = props.instance
	
	self._data = Data.Await(self._instance)
	
	self._character_controller = nil
	
	self._trove = Trove.new()
	
	self._flags = self._trove:Add(TableTracker.new({}))
	
	self:_construct()

	return self
end

function Player:_construct()
	Player._objects[self._instance] = self

	self._trove:Add(function()
		if self._character_controller then
			self._character_controller:Destroy()
		end
		Player._objects[self._instance] = nil
	end)

	task.spawn(function()
		self:_setup()
	end)
end

function Player:_setup()
	self:_add_character(self._instance.Character or self._instance.CharacterAdded:Wait())

	self._instance.CharacterAdded:Connect(function(...)
		self:_add_character(...)
	end)
	
	if self._instance == _L.Player then
		task.spawn(function()
			repeat task.wait() until _G.persistent_loaded
			
			for _, eggInstance in pairs(_L.Map.Eggs:GetChildren()) do
				local newEgg = Egg.new({
					instance = eggInstance,
					player_controller = self
				})
			end
			
			-- old area portals (the Areas folder was removed with the old map)
			local areas = _L.Map:FindFirstChild("Areas")
			for _, areaInstance in pairs(if areas then areas:GetChildren() else {}) do
				local portals = areaInstance:FindFirstChild("Portals")
				
				for _, portalInstance in pairs(if portals then portals:GetChildren() else {}) do
					Portal.new({instance = portalInstance,
						player_controller = self})
				end
			end
		end)
	end
	
	task.spawn(function()
		AttributeUtility.waitFor(self._instance, "flags")
		
		self._trove:Add(self._trove:Add(TrackerUtility.fromAttributeSignal(self._instance, "flags")):Bind(function(value)
			self._flags:Set({}, value)
		end))
	end)
end

function Player:_add_character(character)
	repeat Services.RunService.Heartbeat:Wait() until workspace:IsAncestorOf(character)

	if self._character_controller then
		self._character_controller:Destroy()
	end

	self._character_controller = Character.new({
		instance = character,
		player_controller = self
	})
end

function Player:Destroy()
	self._trove:Destroy()
end

return Player