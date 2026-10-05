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
local AttributeUtility
local PetUtility
local EggUtility
local Eggs
local Notifications
local Purchases
local StatUtility
local Spr

--> Constants

------------->
local Portal = {_objects = {}}
Portal.__index = Portal

function Portal._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"} 
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	Character = _L.Get {"Client", "Modules", "Controllers", "Character"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	DictionaryUtility = _L.Get {"Common", "Library", "Utilities", "DictionaryUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	PetUtility = _L.Get {"Common", "Modules", "Utilities", "PetUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	UI = _L.Get {"Client", "Modules", "UI"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
	EggUtility = _L.Get {"Common", "Modules", "Utilities", "EggUtility"}
	PortalUtility = _L.Get {"Common", "Modules", "Utilities", "PortalUtility"}
end

function Portal._start()
	Notifications = UI.Get("Notifications")
end

function Portal.new(props)
	local self = setmetatable({}, Portal)
	
	self._instance = props.instance
	self._player_controller = props.player_controller
	
	self._from = self._instance.Parent.Parent.Name
	self._to = self._instance.name
	
	self._last_use = nil
	
	self._info = PortalUtility.getInfo(self._to)
	
	self._trove = Trove.new()

	self:_construct()

	return self
end

function Portal:_construct()
	self:_setup()

	Portal._objects[self._instance] = self

	self._trove:Add(function()
		Portal._objects[self._instance] = nil
	end)
end

function Portal:_setup()
	local nextt = _L.Map.Areas:FindFirstChild(self._to).Portals:FindFirstChild(self._from)
	
	self._trove:Add(self._instance.World.Touched:Connect(function(hit)
		local c = hit.Parent
		if c then
			local p = Services.Players:GetPlayerFromCharacter(c)
			if p == _L.Player then
				if (tick() - (self._last_use or 0)) >= 1 then
					self._last_use = tick()
					
					local f, l = self:is_unlocked(self._player_controller._data:Get({"stats", "Strength"}))

					if f then
						local characterController = self._player_controller._character_controller

						if characterController then
							self._last_use = tick()
							c:PivotTo(nextt.Spawn.CFrame - Vector3.new(0, nextt.Spawn.Size.Y / 2 - characterController:get_height() * characterController:get_ratio(), 0))
						end
					elseif l then
						Notifications:add({
							text = "❌ "..NumberUtility.short(l).." Coins left to unlock the portal!",
							color = Color3.fromRGB(255, 0, 0),
							audio = {name = "Fail1"}
						})
					end
				end
			end
		end
	end))
	
	local lockInstance = self._instance:FindFirstChild("Lock")
	
	if lockInstance then
		self._trove:Add(self._player_controller._data:Bind({"stats", "Strength"}, function(value)
			lockInstance.Parent = if self:is_unlocked(value) then nil else self._instance 
		end))
	end
end

function Portal:is_unlocked(value)
	local unlocked = true
	if self._info.required then
		local left = self._info.required - value
		if left <= 0 then
			return true
		else
			return false, left
		end
	end
	return true
end

function Portal:Destroy()
	self._trove:Destroy()
end

return Portal