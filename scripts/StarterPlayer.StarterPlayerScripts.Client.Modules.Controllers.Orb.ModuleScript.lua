--> Variables
local _L = _G._L

local Services
local Maid
local Network
local Audio
local TableUtility

local newRandom = Random.new()

--> Constants
local BLAST_RADIUS = 2

------------->
local Orb = {_objects = {}}
Orb.__index = Orb

function Orb._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"} 
	Network = _L.Get {"Common", "Library", "Network"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
end

function Orb._start()
	Network.Remote.Fired("C_Orb_Bulk", function(props)
		for _, a in pairs(props) do
			Orb.new(a)
		end
	end)
	
	Services.RunService.Heartbeat:Connect(function()
		local character = _L.Player.Character
		
		if not character then
			return
		end
		
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		
		if not humanoidRootPart then
			return
		end
		
		local v35 = os.clock()
		local v37 = TableUtility.length(Orb._objects)

		for orbuid, orb in pairs(Orb._objects) do
			local v39 = orb.instance
			local v42 = v39:FindFirstChildOfClass("BodyPosition")

			if v39 and v42 and 0.33 <= v35 - orb._last_check then
				local v43 = _L.Player:DistanceFromCharacter(v39.Position)

				v42.P = 1250 - 1250 * math.clamp(v43 / 12, 0, 1)
				v42.MaxForce = Vector3.new(v42.P, v42.P, v42.P)
				v42.Position = humanoidRootPart.Position + humanoidRootPart.CFrame.LookVector - Vector3.new(0, 2, 0)

				if 17 <= v43 then
					orb._last_check = v35

					if newRandom:NextNumber() < 0.03 then
						v39.Velocity = v39.Velocity + Vector3.new(0, 30, 0)
					end

					if 1.5 <= v35 - orb._spawn_tick and 150 <= v37 then
						if orb._last_combine_check and 5 <= v35 - orb._last_combine_check then
							orb._last_combine_check = os.clock()
							orb:_try_to_combine()
						else
							orb._last_combine_check = os.clock()
							orb:_try_to_combine()
						end
					end
				elseif v43 <= 4 then
					orb:collect()
				end
			end
		end
	end)
end

function Orb.new(props)
	local self = setmetatable({}, Orb)

	self.position = props.position
	self.image = props.image
	self.uid = props.uid
	
	self.instance = nil
	
	self._uids = {props.uid}

	self._last_check = os.clock()
	self._last_combine_check = nil
	self._spawn_tick = os.clock()

	self._maid = Maid.new()

	self:_construct()

	return self
end

function Orb:_construct()
	local newOrbAdornee = Instance.new("Part")
	local newOrbBillboard = _L.Assets.UI.Orb:Clone()
	local newBodyPosition = Instance.new("BodyPosition")
	
	self.instance = newOrbAdornee
	
	self._maid:GiveTask(newOrbAdornee)
	
	newOrbAdornee.CollisionGroup = "Orbs"

	newOrbAdornee.Transparency = 1
	newOrbAdornee.Size = Vector3.new(0.5, 0.5, 0.5)
	newOrbAdornee.CFrame = CFrame.new(self.position)
	newOrbAdornee.Anchored = false;
	newOrbAdornee.CanCollide = true;
	newOrbAdornee.Name = self.uid
		
	newOrbBillboard.Main.ObjectImg.Image = self.image
		
	newOrbBillboard.Parent = newOrbAdornee
	newOrbAdornee.Parent = _L.Debris.Orbs
	
	newOrbAdornee.Velocity = Vector3.new(newRandom:NextNumber(-20, 20) * BLAST_RADIUS, 50, newRandom:NextNumber(-20, 20))
	newOrbAdornee.RotVelocity = Vector3.new(newRandom:NextNumber(-20, 20) * BLAST_RADIUS, newRandom:NextNumber(-20, 20) * BLAST_RADIUS, newRandom:NextNumber(-20, 20) * BLAST_RADIUS)
	
	newBodyPosition.D = 50
	newBodyPosition.P = 0
	newBodyPosition.MaxForce = Vector3.new()
	newBodyPosition.Parent = newOrbAdornee
	
	--Audio.Play({
	--	name = {"OrbSpawn1", "OrbSpawn2", "OrbSpawn3", "OrbSpawn4"},
	--	speed = newRandom:NextNumber(0.95, 1.05),
	--	volume = 0.4
	--})
	
	Orb._objects[self.uid] = self

	self._maid:GiveTask(function()
		Orb._objects[self.uid] = nil
	end)
end

function Orb:collect()
	--Audio.Play({
	--	name = {"OrbCollect1", "OrbCollect2"},
	--	speed = newRandom:NextNumber(0.95, 1.05),
	--	volume = 0.4
	--})
	
	local success = Network.Remote.Invoke("S_Orb_Collect", self._uids)
	
	if success then
		self:Destroy()
	end
end

function Orb:_try_to_combine()
	for orbuid, orb in pairs(Orb._objects) do
		if orbuid ~= self.uid then
			if self.image == orb.image and (self.instance.Position - orb.instance.Position).Magnitude <= 5 then
				self:Combine(orb)
				return
			end
		end
	end
end

function Orb:Combine(orb)
	for _, orbuid in pairs(orb._uids) do
		table.insert(self._uids, orbuid)
	end

	orb:Destroy()
end

function Orb:Destroy()
	self._maid:Destroy()
end

return Orb