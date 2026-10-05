--> Variables
local _L = _G._L

local Maid
local Network
local Services

--> Constants

------------->
local Orb = {_objects = {}}
Orb.__index = Orb

function Orb._init()
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
	Network = _L.Get {"Common", "Library", "Network"}
	Services = _L.Get {"Common", "Library", "Services"}
end

function Orb._start()
	Network.Remote.Invoked("S_Orb_Collect", function(player, orbUids)
		if typeof(orbUids) ~= "table" then
			return false
		end
		for _, orbUid in pairs(orbUids) do
			local orb = Orb._objects[orbUid]

			-- only your own drops can be collected by you
			if orb and orb.client and orb.client.player == player then
				orb:collect()
			end
		end
		
		return true
	end)
	
	Network.Bindable.Invoked("S_Orb_Collect_All", function(client)
		warn("COLLECTED ALL ORBS")
		
		for _, orb in pairs(Orb._objects) do
			task.spawn(function()
				if orb.client == client then
					orb:collect()
				end
			end)
		end
	end)
end

function Orb.new(props)
	local self = setmetatable({}, Orb)
	
	self.client = props.client
	self.position = props.position
	self.image = props.image or ""
	self.callback = props.callback
	
	self.uid = Services.HttpService:GenerateGUID(false)

	self._maid = Maid.new()
	
	self:_construct()
	
	return self
end

function Orb:_construct()
	Orb._objects[self.uid] = self

	self._maid:GiveTask(function()
		Orb._objects[self.uid] = nil
	end)
end

function Orb:package()
	return {
		position = self.position,
		image = self.image,
		uid = self.uid
	}
end

function Orb:collect()
	self.callback()
	self:Destroy()
end

function Orb:Destroy()
	self._maid:Destroy()
end

return Orb