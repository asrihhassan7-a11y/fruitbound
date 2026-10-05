--> Variables
local _L = _G._L

local Services
local Network
local Create
local Trove
local Promise

--> Constants

---------->
local Audio = {}

function Audio._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Create = _L.Get {"Common", "Library", "Functions", "Create"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
end

function Audio._start()
	if not Services.RunService:IsServer() then
		Network.Remote.Fired("C_Audio_Play", function(...)
			Audio._play(...)
		end)
	end
end

function Audio.Play(props)
	if Services.RunService:IsServer() then
		Network.Remote.FireAll("C_Audio_Play", props)
	else
		return Audio._play(props)
	end
end

function Audio._play(props)
	local data = _G.Data
	
	if data and not data:Get({"settings", "SFX"}) then
		return
	end
	
	local name = props.name
	local position = props.position
	local speed = props.speed
	local volume = props.volume
	local looped = props.looped
	local pitch = props.pitch
	
	if typeof(name) == "table" then
		name = name[math.random(1, #name)]
	end
	
	local instance = _L.Assets.Sounds:FindFirstChild(name, true)
	local newInstance = nil
	
	if instance then
		newInstance = instance:Clone()
	else
		return warn('Failed to retrieve sound "'..name..'"')
	end
	
	local newTrove = Trove.new()
	
	newTrove:Add(newInstance)
	
	if pitch then
		local newPitch = Instance.new("PitchShiftSoundEffect", newInstance)
		newPitch.Octave = pitch
		newPitch.Parent = newInstance
	end
	
	local positionInstance = if typeof(position) == "Instance" then position elseif typeof(position) == "CFrame" or typeof(position) == "Vector3" then newTrove:Add(Create("Part", {
		Transparency = 1,
		CanCollide = false,
		Anchored = true,
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = if typeof(position) == "CFrame" then position.CFrame elseif typeof(position) == "Vector3" then position elseif typeof(position) == "Instance" then position.Position else nil,
		Parent = _L.Debris
	})) else _L.Debris
	
	newInstance.Name = name
	newInstance.PlaybackSpeed = speed or instance.PlaybackSpeed
	newInstance.Volume = volume or instance.Volume

	-- small random pitch variation so repeated sounds never feel identical (PitchMin / PitchMax attributes)
	local pMin, pMax = instance:GetAttribute("PitchMin"), instance:GetAttribute("PitchMax")
	if not speed and pMin and pMax then
		newInstance.PlaybackSpeed = instance.PlaybackSpeed * (pMin + math.random() * (pMax - pMin))
	end
	-- volume sliders: every sound goes through a SoundGroup (SFX by default, Ambient / Music by attribute)
	local group = Services.SoundService:FindFirstChild((instance:GetAttribute("Group") or "SFX") .. "Group")
	if group then
		newInstance.SoundGroup = group
	end
	
	newInstance.Parent = positionInstance
	
	return Promise.new(function(resolve, reject)
		newInstance:Play()
		newInstance.Ended:Wait()
		resolve()
	end):finally(function()
		newTrove:Destroy()
	end)
end

return Audio