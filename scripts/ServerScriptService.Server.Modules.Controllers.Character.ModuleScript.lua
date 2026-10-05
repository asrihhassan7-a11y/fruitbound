--> Variables
local _L = _G._L

local Services
local Maid
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
local Promise
local AttributeUtility
local TrackerUtility
local Constants
local Pool
local EmojiMapUtility
local RankUtility
local PowerUtility
local PowerComponentUtility
local Eggs
local UI

--> Constants

------------->
local Character = {_objects = {}}
Character.__index = Character

function Character._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Pool = _L.Get {"Common", "Library", "Classes", "Pool"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Character = _L.Get {"Server", "Modules", "Controllers", "Character"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Tags = _L.Get {"Server", "Modules", "Tags"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	EmojiMapUtility = _L.Get {"Common", "Modules", "Utilities", "EmojiMapUtility"}
	RankUtility = _L.Get {"Common", "Modules", "Utilities", "RankUtility"}
	PowerComponentUtility = _L.Get {"Common", "Modules", "Utilities", "PowerComponentUtility"}
	PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
end

function Character._start()
end

function Character.new(props)
	local self = setmetatable({}, Character)
	
	self._player_controller = props.player_controller
	self._instance = props.instance
	
	self._client = self._player_controller._client
	self._data = self._client.data
	
	self._humanoid = nil
	self._root = nil
	
	self._health = nil
	
	self._animations = {}
	
	self._trove = Trove.new()

	self:_construct()

	return self
end

function Character:_construct()
	Character._objects[self._instance] = self
	
	self._trove:Add(function()
		Character._objects[self._instance] = nil
	end)
	
	self._trove:AddPromise(Promise.new(function(resolve)
		self._humanoid = self._instance:WaitForChild("Humanoid")
		self._root = self._instance:WaitForChild("HumanoidRootPart")
		
		-- Walk speed = old speed upgrade + Upgrade Tree "speed" bonus
		local function updateWalkSpeed()
			local UpgradeTreeUtility = _L.Get {"Common", "Modules", "Utilities", "UpgradeTreeUtility"}
			local value = self._data:Get({"upgrades", "1"}) or 1
			local base = if self._player_controller._instance.MembershipType == Enum.MembershipType.Premium then 24 else 20
			local TitleUtility = _L.Get {"Common", "Modules", "Utilities", "TitleUtility"}
			local speed = value * 2 + base + UpgradeTreeUtility.getBonus(self._data, "speed")
			self._humanoid.WalkSpeed = speed * TitleUtility.getMultiplier(self._data, "walk_speed")
		end
		self._trove:Add(self._data:Bind({"upgrades", "1"}, updateWalkSpeed))
		self._trove:Add(self._data:Bind("tree", updateWalkSpeed))
		self._trove:Add(self._data:Bind("titles", updateWalkSpeed))
		
		self._humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		
		self._trove:Add(self._humanoid.Died:Connect(function()
			self:set_health(0)
		end))
		
		self._trove:Add(self._player_controller._main_power:Bind(function(value)
			local currentPowerInfo = Shared.GetCurrentPowerInfoFromStrength(self._data:Get({"stats", "Strength"}))
			local powerHealth = PowerUtility.getHealth(currentPowerInfo.name)
			
			local health, maxHealth = powerHealth, powerHealth

			if not self._health then
				self._health = Tracker.new({health, maxHealth})
			else
				self._health:Set({health, maxHealth})
			end
		end))
		
		self._trove:Add(self._health:Bind(function(value)
			if value[1] > 0 then
				return
			end
			self._humanoid.Health = 0
		end))
		
		self:_create_billboard()
		
		local zones = Network.Bindable.Invoke("S_Safe_Zones_Get_All")
		
		for a, zone in pairs(zones or {}) do
			if zone:findPlayer(self._player_controller._instance) then
				self._player_controller._safezone:Set(a)
			end
		end
		
		resolve()
	end)):catch(warn):expect()
end

function Character:_create_billboard()
	self._health:Bind(function(value)
		AttributeUtility.set(self._player_controller._instance, "health", value)
	end)
end

function Character:set_health(n)
	if self._health then
		local maxHealth = self._health:Get()[2]
		n = math.clamp(0, n, maxHealth)
		self._health:Set({n, maxHealth})
	end
end

function Character:get_health()
	if self._health then
		return self._health:Get()[1]
	end
end

function Character:get_height()
	local b1 = self._left_foot.Position - Vector3.new(0, self._left_foot.Size.Y / 2, 0)
	local b2 = self._head.Position + Vector3.new(0, self._head.Size.Y / 2, 0)
	return b2.Y - b1.Y
end

function Character:get_ratio()
	local b1 = self._left_foot.Position - Vector3.new(0, self._left_foot.Size.Y / 2, 0)
	local b2 = self._root.Position
	local height = self:get_height()
	return ((b2.Y - b1.Y) / height)
end

function Character:_get_animation_track(animationName)
	local animationTrack = self._animations[animationName]

	if not animationTrack then
		local animationInstance = _L.Assets.Animations:FindFirstChild(animationName, true)

		if not animationInstance then
			return
		end

		animationTrack = self._humanoid:LoadAnimation(animationInstance)
		self._animations[animationName] = animationTrack
	end

	return animationTrack
end

function Character:play_animation(props)
	pcall(function()
		if not props.name then
			return
		end

		local fadeTime = props.fade_time or 0
		local speed = props.speed or 1

		local animationTrack = self:_get_animation_track(props.name)

		if animationTrack then
			animationTrack:Play(fadeTime)

			animationTrack:AdjustSpeed(speed)
		end

		return animationTrack
	end)
end

function Character:stop_animation(props)
	local animationTrack = self:_get_animation_track(props.name)

	animationTrack:Stop()

	return animationTrack
end

function Character:Destroy()
	self._trove:Destroy()
end

return Character