--> TravelEffects (client)
-- Small leaf burst when a player uses the Travel menu. The server (Farm S_Farm_Teleport) does the
-- teleport and fires C_Travel_Leaves with a world position and a phase ("depart" / "arrive");
-- this module only draws leaves there, so it can never pick or change a destination.
-- To use a different leaf image, change LEAF_TEXTURE (a white image is tinted by LEAF_COLORS).

local _L = _G._L

local Debris = game:GetService("Debris")

local Network

local LEAF_TEXTURE = "rbxassetid://107356626064723"
local FALLBACK_TEXTURE = "rbxasset://textures/particles/SquareParticle.png" -- built into Roblox
local LEAF_COLORS = {
	-- {color, leaves per burst}
	{Color3.fromRGB(120, 205, 85), 11},
	{Color3.fromRGB(80, 170, 70), 5},
	{Color3.fromRGB(245, 190, 70), 3},
	{Color3.fromRGB(235, 130, 60), 2},
}
local MAX_BURSTS = 6 -- never more than this many bursts alive at once
local VIEW_DISTANCE = 220 -- skip bursts far from the camera

local TravelEffects = {}
local active = 0
-- if the leaf image can't be loaded (e.g. still in Roblox moderation) the bursts fall back to
-- small tinted squares (FALLBACK_TEXTURE) instead of showing nothing
local texture = LEAF_TEXTURE

local function emitter(parent, color, phase)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Rate = 0
	e.Enabled = false
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.6, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Rotation = NumberRange.new(-180, 180)
	e.RotSpeed = NumberRange.new(-220, 220)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Cylinder
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Drag = 3
	e.LightInfluence = 0.4
	e.LightEmission = 0
	e.ZOffset = 0.5
	if phase == "depart" then
		-- swirl up and away
		e.Speed = NumberRange.new(5, 8)
		e.Acceleration = Vector3.new(0, 7, 0)
	else
		-- puff out, then flutter down
		e.Speed = NumberRange.new(6, 9)
		e.Acceleration = Vector3.new(0, -5, 0)
	end
	e.Parent = parent
	return e
end

function TravelEffects.play(position, phase, traveller)
	if typeof(position) ~= "Vector3" or active >= MAX_BURSTS then
		return
	end
	-- other players' bursts only when they're near; your own arrival always plays (the camera
	-- hasn't caught up with the teleport yet when this arrives)
	local camera = workspace.CurrentCamera
	if traveller ~= _L.Player and camera and (camera.CFrame.Position - position).Magnitude > VIEW_DISTANCE then
		return
	end
	active += 1
	-- one invisible anchor per burst: a 3x4x3 cylinder around the body
	local anchor = Instance.new("Part")
	anchor.Name = "TravelLeaves"
	anchor.Shape = Enum.PartType.Cylinder
	anchor.Size = Vector3.new(4, 3, 3)
	anchor.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Parent = _L.Debris or workspace
	for _, entry in ipairs(LEAF_COLORS) do
		emitter(anchor, entry[1], phase):Emit(entry[2])
	end
	Debris:AddItem(anchor, 1.6)
	task.delay(1.6, function()
		active -= 1
	end)
end

function TravelEffects._init()
	Network = _L.Get {"Common", "Library", "Network"}
end

function TravelEffects._start()
	task.spawn(function()
		local ok = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({LEAF_TEXTURE}, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					texture = FALLBACK_TEXTURE
				end
			end)
		end)
		if not ok then
			texture = FALLBACK_TEXTURE
		end
	end)
	Network.Remote.Fired("C_Travel_Leaves", function(position, phase, traveller)
		TravelEffects.play(position, phase, traveller)
	end)
end

return TravelEffects
