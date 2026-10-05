--> AnimationPack (client) - the FruitBound keyframe clips for Fruits and Mounts
-- Fruits (one MeshPart) and the Forest Deer (Root -> Body, Motor6D "BodyJoint") are rigid single meshes,
-- so every clip is ONE track: an offset CFrame for the whole body. Nothing is scaled or deformed and
-- there is no root motion: Roblox (Humanoid / follow code) moves the character, clips only add the offset.
--   Fruits: FruitGroup / FruitPen multiply the pose onto the fruit's CFrame.
--   Mounts: Mounts (client) writes the pose into BodyJoint.Transform. The rider is welded to Root, so the
--           saddle never shakes; offsets stay small so the body never pushes into the rider.
--
--   AnimationPack.sample(name, t, halfHeight) -> CFrame   (looped clips wrap, one-shots clamp)
--   AnimationPack.resolve(set, action)        -> clip name ("Deer", "Jump" -> "Deer_Jump", else "Mount_Jump")
--   AnimationPack.play(state, name, delay)    -- start a one-shot on a state table (any table)
--   AnimationPack.shot(state, dt, pose, halfHeight) -> CFrame  (blends the running one-shot over pose)
--
-- Keys: {time, x, y, z, pitch, yaw, roll, ease} in studs / degrees. The clip's pivot is where rotation
-- happens ("bottom" = the fruit's base, or a Vector3 in the part's space, e.g. the deer's saddle).
-- Ease is how the motion arrives INTO that key: "sine" (default), "linear", "out", "in", "back".
-- Looped clips end on exactly their first key, so they loop seamlessly. Models face -Z:
-- pitch < 0 leans forward (nose / top toward -Z), +Z is backwards, roll tilts sideways.

local AnimationPack = {}

local FADE_IN = 0.08
local FADE_OUT = 0.14

-- Forest Deer (Body 2.5 x 7.3 x 6.4, pivot at its centre, 3.6 above the ground): every mount clip rotates
-- around the SADDLE, so the rider's seat barely moves while the head / hind end do the acting.
local SADDLE = {0, 1.2, 0.6}

local CLIPS = {
	------------------------------------------------------------ FRUITS (pivot = the fruit's base)
	Fruit_Idle = {
		duration = 2.4, looped = true, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.6, 0, 0.12, 0, 0, 0, 2.5},
			{1.2, 0, 0, 0, 0, 0, 0},
			{1.55, 0, 0.06, 0, 2, 5, -3.5},
			{1.95, 0, 0.09, 0, 3, 8, -5}, -- tiny curious head tilt
			{2.4, 0, 0, 0, 0, 0, 0},
		},
	},
	Fruit_Walk = { -- two bouncy steps per loop
		duration = 0.6, looped = true, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, -3, 0, 0},
			{0.15, 0, 0.55, 0, -8, 0, 7, "out"},
			{0.3, 0, 0, 0, -3, 0, 0, "in"},
			{0.45, 0, 0.55, 0, -8, 0, -7, "out"},
			{0.6, 0, 0, 0, -3, 0, 0, "in"},
		},
	},
	Fruit_Run = { -- quicker, lower hops than a frantic sprint (followers stay readable at mount speed)
		duration = 0.56, looped = true, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, -7, 0, 0},
			{0.14, 0, 0.6, 0, -12, 0, 8, "out"},
			{0.28, 0, 0, 0, -7, 0, 0, "in"},
			{0.42, 0, 0.6, 0, -12, 0, -8, "out"},
			{0.56, 0, 0, 0, -7, 0, 0, "in"},
		},
	},
	Fruit_Happy = { -- hatch / level-up / evolve: lean back, joyful spin-jump, double bounce, wiggle
		duration = 1.3, looped = false, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.12, 0, 0, 0, 5, 0, 0, "out"}, -- anticipation lean (stays on the ground)
			{0.42, 0, 1.6, 0, -4, 180, 0, "out"},
			{0.7, 0, 0, 0, 0, 360, 0, "in"},
			{0.85, 0, 0.35, 0, 0, 360, 0, "out"},
			{1.0, 0, 0, 0, 0, 360, 0, "in"},
			{1.1, 0, 0.05, 0, 0, 360, 7},
			{1.2, 0, 0, 0, 0, 360, -6},
			{1.3, 0, 0, 0, 0, 360, 0},
		},
	},
	Fruit_Interact = { -- petted: little hop, lean in toward you (its front), happy wiggle
		duration = 1.2, looped = false, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.15, 0, 0.35, 0, -4, 0, 0, "out"},
			{0.3, 0, 0, -0.15, -10, 0, 0, "in"},
			{0.45, 0, 0.04, -0.15, -10, 0, 8},
			{0.6, 0, 0, -0.15, -10, 0, -8},
			{0.75, 0, 0.04, -0.15, -9, 0, 6},
			{0.9, 0, 0.15, -0.08, -6, 0, 0},
			{1.2, 0, 0, 0, 0, 0, 0},
		},
	},
	Fruit_Sleep = { -- slumped a little to the side, very slow breathing (stays on the ground)
		duration = 4.0, looped = true, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, 6, 0, 4},
			{2.0, 0, 0.05, 0, 4.5, 0, 3.5},
			{4.0, 0, 0, 0, 6, 0, 4},
		},
	},
	Fruit_Surprised = { -- quick recoil back + short bounce
		duration = 0.7, looped = false, pivot = "bottom",
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.08, 0, 0.25, 0.35, 14, 0, 0, "out"},
			{0.25, 0, 0.5, 0.4, 10, 0, 0, "out"},
			{0.45, 0, 0, 0.2, 2, 0, 0, "in"},
			{0.58, 0, 0.12, 0.1, 0, 0, 0, "out"},
			{0.7, 0, 0, 0, 0, 0, 0, "in"},
		},
	},

	------------------------------------------------------------ MOUNTS (generic; Body joint offsets)
	Mount_Idle = { -- breathing + slow weight shift, hooves stay planted
		duration = 4.0, looped = true, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{1.0, 0, 0.04, 0, 0.6, 0, 0.8},
			{2.0, 0, 0.015, 0, 0, 0, 1.2},
			{3.0, 0, 0.04, 0, -0.6, 0, -0.4},
			{4.0, 0, 0, 0, 0, 0, 0},
		},
	},
	Mount_Walk = { -- two steps per loop, tiny bob (rider comfort)
		duration = 1.0, looped = true, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.25, 0, 0.06, 0, 1.0, 0, 0.6},
			{0.5, 0, 0, 0, 0, 0, 0},
			{0.75, 0, 0.06, 0, -0.8, 0, -0.6},
			{1.0, 0, 0, 0, 0, 0, 0},
		},
	},
	Mount_Run = { -- rocking gallop, two bounds per loop
		duration = 0.8, looped = true, pivot = SADDLE,
		keys = {
			{0.0, 0, 0.07, 0, -1.2, 0, 0},
			{0.2, 0, 0.17, 0, 2, 0, 0.5, "out"},
			{0.4, 0, 0.07, 0, -1.2, 0, 0, "in"},
			{0.6, 0, 0.17, 0, 2, 0, -0.5, "out"},
			{0.8, 0, 0.07, 0, -1.2, 0, 0, "in"},
		},
	},
	Mount_Start = { -- lean into the first step
		duration = 0.6, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.15, 0, 0.085, -0.15, -1.5, 0, 0, "out"},
			{0.4, 0, 0.035, -0.05, -0.5, 0, 0},
			{0.6, 0, 0, 0, 0, 0, 0},
		},
	},
	Mount_Stop = { -- weight back, settle forward, rest (never a hard freeze)
		duration = 0.7, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.15, 0, 0.07, 0.15, 2, 0, 0, "out"},
			{0.35, 0, 0.045, 0.05, -0.8, 0, 0},
			{0.55, 0, 0.02, 0, 0.4, 0, 0},
			{0.7, 0, 0, 0, 0, 0, 0},
		},
	},
	Mount_Jump = { -- the jump is already airborne: tiny gather, push up, level out ready to land
		duration = 0.6, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.08, 0, -0.06, 0, -1, 0, 0, "out"},
			{0.28, 0, 0.18, 0, 5, 0, 0, "out"},
			{0.45, 0, 0.1, 0, 2, 0, 0},
			{0.6, 0, 0.06, 0, -1, 0, 0},
		},
	},
	Mount_Land = { -- front touches down, quick settle (rigid body: no sinking into the ground)
		duration = 0.5, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0.05, 0, -1, 0, 0},
			{0.08, 0, 0.065, 0, -1.2, 0, 0, "out"},
			{0.22, 0, 0.03, 0, 0.5, 0, 0},
			{0.35, 0, 0.005, 0, 0, 0, 0},
			{0.5, 0, 0, 0, 0, 0, 0},
		},
	},
	Mount_Celebrate = { -- proud, gentle front lift (body rises just enough that the hind hooves stay down) + a little head turn
		duration = 1.6, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.3, 0, 0.09, 0, 3, 0, 0, "out"},
			{0.55, 0, 0.16, 0, 5.5, 3, 0},
			{0.8, 0, 0.15, 0, 5, -3, 0},
			{1.05, 0, 0.075, 0, 2.5, 0, 0},
			{1.25, 0, 0.045, 0, -0.8, 0, 0, "in"},
			{1.45, 0, 0.02, 0, 0.5, 0, 0},
			{1.6, 0, 0, 0, 0, 0, 0},
		},
	},

	------------------------------------------------------------ DEER / REINDEER (Forest Deer)
	Deer_Idle = { -- proud breathing, hoof weight shift, a quick little head flick now and then
		duration = 4.5, looped = true, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{1.1, 0, 0.04, 0, 0.8, 0, 0.6},
			{2.2, 0, 0.02, 0, 0.3, 0, 1.0},
			{2.45, 0, 0.05, 0, 1.2, 1.5, 0.9, "out"}, -- head flick (ears up)
			{2.7, 0, 0.02, 0, 0.4, 0, 0.8},
			{3.5, 0, 0.04, 0, -0.5, 0, -0.5},
			{4.5, 0, 0, 0, 0, 0, 0},
		},
	},
	Deer_Walk = { -- alternating steps with a mild head bob, saddle stays calm
		duration = 1.0, looped = true, pivot = SADDLE,
		keys = {
			{0.0, 0, 0.025, 0, -0.4, 0, 0},
			{0.25, 0, 0.07, 0, 1.2, 0, 0.6},
			{0.5, 0, 0.025, 0, -0.4, 0, 0},
			{0.75, 0, 0.07, 0, 1.2, 0, -0.6},
			{1.0, 0, 0.025, 0, -0.4, 0, 0},
		},
	},
	Deer_Run = { -- stylized bounding gallop: smooth rise / fall and a soft rock
		duration = 0.8, looped = true, pivot = SADDLE,
		keys = {
			{0.0, 0, 0.085, 0, -1.5, 0, 0},
			{0.2, 0, 0.2, 0, 2.5, 0, 0.4, "out"},
			{0.4, 0, 0.085, 0, -1.5, 0, 0, "in"},
			{0.6, 0, 0.2, 0, 2.5, 0, -0.4, "out"},
			{0.8, 0, 0.085, 0, -1.5, 0, 0, "in"},
		},
	},
	Deer_Jump = { -- light leap (already airborne): small gather, spring up nose-first, glide level
		duration = 0.65, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0, 0, 0, 0, 0},
			{0.08, 0, -0.06, 0, -1, 0, 0, "out"},
			{0.3, 0, 0.22, 0, 6, 0, 0, "out"},
			{0.5, 0, 0.08, 0, 1, 0, 0},
			{0.65, 0, 0.06, 0, -1, 0, 0}, -- front hooves reach for the ground
		},
	},
	Deer_Land = { -- front-first touchdown, soft settle (rigid body: no sinking into the ground)
		duration = 0.5, looped = false, pivot = SADDLE,
		keys = {
			{0.0, 0, 0.05, 0, -1, 0, 0},
			{0.1, 0, 0.065, 0, -1.2, 0, 0, "out"},
			{0.25, 0, 0.03, 0, 0.6, 0, 0},
			{0.38, 0, 0.005, 0, 0, 0, 0},
			{0.5, 0, 0, 0, 0, 0, 0},
		},
	},
}

------------------------------------------------------------ sampling
local rad = math.rad

local EASE = {
	sine = function(a)
		return 0.5 - 0.5 * math.cos(a * math.pi)
	end,
	linear = function(a)
		return a
	end,
	out = function(a)
		return 1 - (1 - a) * (1 - a)
	end,
	["in"] = function(a)
		return a * a
	end,
	back = function(a)
		local s = 1.4
		a -= 1
		return a * a * ((s + 1) * a + s) + 1
	end,
}

local function lerp(a, b, k)
	return a + (b - a) * k
end

-- the pose (offset CFrame around the pivot) at time t of a clip table
local function poseAt(clip, t, halfHeight)
	local keys = clip.keys
	local x, y, z, p, yw, r
	if t <= keys[1][1] then
		local k = keys[1]
		x, y, z, p, yw, r = k[2], k[3], k[4], k[5], k[6], k[7]
	elseif t >= keys[#keys][1] then
		local k = keys[#keys]
		x, y, z, p, yw, r = k[2], k[3], k[4], k[5], k[6], k[7]
	else
		for i = 2, #keys do
			local b = keys[i]
			if t <= b[1] then
				local a = keys[i - 1]
				local e = (EASE[b[8] or "sine"] or EASE.sine)((t - a[1]) / (b[1] - a[1]))
				x, y, z = lerp(a[2], b[2], e), lerp(a[3], b[3], e), lerp(a[4], b[4], e)
				p, yw, r = lerp(a[5], b[5], e), lerp(a[6], b[6], e), lerp(a[7], b[7], e)
				break
			end
		end
	end
	local rot = CFrame.Angles(rad(p), rad(yw), rad(r))
	local pivot = clip.pivot
	if pivot == "bottom" then
		local h = halfHeight or 0
		return CFrame.new(x, y - h, z) * rot * CFrame.new(0, h, 0)
	elseif pivot then
		local px, py, pz = pivot[1], pivot[2], pivot[3]
		return CFrame.new(x + px, y + py, z + pz) * rot * CFrame.new(-px, -py, -pz)
	end
	return CFrame.new(x, y, z) * rot
end

AnimationPack.Clips = CLIPS

function AnimationPack.get(name)
	return CLIPS[name]
end

function AnimationPack.sample(name, t, halfHeight)
	local clip = CLIPS[name]
	if not clip then
		return CFrame.identity
	end
	if clip.looped then
		t %= clip.duration
	end
	return poseAt(clip, t, halfHeight)
end

-- "Deer" + "Jump" -> "Deer_Jump" when the set has it, else the generic "Mount_Jump"
function AnimationPack.resolve(set, action)
	local name = (set or "Mount") .. "_" .. action
	if CLIPS[name] then
		return name
	end
	return "Mount_" .. action
end

------------------------------------------------------------ one-shots (Happy, Jump, Land, ...)
-- state can be any table (a fruit's anim table, a mount's anim state). A new one-shot replaces the current one.
function AnimationPack.play(state, name, delay)
	if state and CLIPS[name] then
		state.shotName = name
		state.shotT = -(delay or 0)
	end
end

function AnimationPack.playing(state)
	return state ~= nil and state.shotName ~= nil
end

-- advances the running one-shot and blends it over `pose` (fades in / out, so it never pops)
function AnimationPack.shot(state, dt, pose, halfHeight)
	local name = state and state.shotName
	if not name then
		return pose
	end
	state.shotT += dt
	local t = state.shotT
	if t < 0 then
		return pose
	end
	local clip = CLIPS[name]
	if t >= clip.duration then
		state.shotName = nil
		return pose
	end
	local w = math.min(1, t / FADE_IN, (clip.duration - t) / FADE_OUT)
	return pose:Lerp(poseAt(clip, t, halfHeight), w)
end

------------------------------------------------------------ your own Roblox animations (optional)
-- Databases.AnimationIds holds published Animation IDs. An action with an ID that has LOADED plays
-- that AnimationTrack; an empty ID, or one that fails to load, keeps the procedural clip above.
--   local set = AnimationPack.trackSet(model, "Deer", "Mount")  -- nil when no IDs are set
--   AnimationPack.trackLoop(set, "Walk", speed)  -> true while that uploaded loop drives the rig
--   AnimationPack.trackShot(set, "Jump")         -> true when the uploaded one-shot played
--   AnimationPack.trackBusy(set)                 -> an uploaded one-shot is still playing
--   AnimationPack.trackStop(set)                 -- stop + remove everything (despawn / unequip)
-- Rigs: Deer / mounts = Root -> Body (existing Motor6D "BodyJoint");
--       Fruits = Root -> Handle (Motor6D "RootJoint", added by FruitGroup only when a Fruit ID is set).

local LOOPS = {Idle = true, Walk = true, Run = true, Sleep = true}
local ACTIONS = {"Idle", "Walk", "Run", "Sleep", "Start", "Stop", "Jump", "Land", "Celebrate", "Happy", "Surprised"}
local FADE = 0.25

local function normalizeId(id)
	if typeof(id) == "number" then
		id = tostring(math.floor(id))
	end
	if typeof(id) ~= "string" then
		return nil
	end
	id = id:gsub("%s", "")
	if id:match("^%d+$") then
		return "rbxassetid://" .. id
	end
	if id:match("^rbxassetid://%d+$") then
		return id
	end
	return nil -- "" or anything that is not an asset id
end

-- the configured ID for prefix .. action ("Deer" + "Jump" -> DeerJumpAnimationId), else fallbackPrefix's
function AnimationPack.customId(prefix, action, fallbackPrefix)
	local ok, ids = pcall(function()
		return _G._L.Get({"Common", "Modules", "Databases", "AnimationIds"})
	end)
	if not ok or typeof(ids) ~= "table" then
		return nil
	end
	return normalizeId(ids[prefix .. action .. "AnimationId"])
		or (fallbackPrefix and normalizeId(ids[fallbackPrefix .. action .. "AnimationId"]))
		or nil
end

-- any uploaded animation configured for this prefix?
function AnimationPack.hasCustom(prefix, fallbackPrefix)
	for _, action in ipairs(ACTIONS) do
		if AnimationPack.customId(prefix, action, fallbackPrefix) then
			return true
		end
	end
	return false
end

-- Loads the configured tracks on a rigged model (one AnimationController + Animator, created once).
function AnimationPack.trackSet(model, prefix, fallbackPrefix)
	local ids = {}
	for _, action in ipairs(ACTIONS) do
		ids[action] = AnimationPack.customId(prefix, action, fallbackPrefix)
	end
	if next(ids) == nil or not model then
		return nil
	end
	local controller = model:FindFirstChild("FruitBoundAnimator")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "FruitBoundAnimator"
		controller.Parent = model
	end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = controller
	local set = {controller = controller, tracks = {}, loop = nil, speed = 1, busyUntil = 0}
	for action, id in pairs(ids) do
		local ok, track = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = LOOPS[action] == true
			track.Priority = if action == "Idle" or action == "Sleep" then Enum.AnimationPriority.Idle
				elseif LOOPS[action] then Enum.AnimationPriority.Movement
				else Enum.AnimationPriority.Action
			set.tracks[action] = track
		else
			warn("[AnimationPack] could not load " .. prefix .. action .. " (" .. id .. "), using the built-in animation")
		end
	end
	return set
end

-- loaded = the asset really arrived (a failed / not-allowed ID never gets a length)
local function ready(set, action)
	local track = set and action and set.tracks[action]
	return track ~= nil and track.Length > 0, track
end

-- Plays the uploaded loop for `action` (crossfades only when the action changes, never restarts it).
-- Returns false (and stops the uploaded loop) when that action has no loaded track -> use the clip.
function AnimationPack.trackLoop(set, action, speed)
	if not set then
		return false
	end
	local isReady, track = ready(set, action)
	if not isReady then
		if set.loop then
			set.tracks[set.loop]:Stop(FADE)
			set.loop = nil
		end
		return false
	end
	if set.loop ~= action then
		if set.loop then
			set.tracks[set.loop]:Stop(FADE)
		end
		track:Play(FADE, 1, speed or 1)
		set.loop = action
		set.speed = speed or 1
	elseif speed and math.abs(speed - set.speed) > 0.05 then
		track:AdjustSpeed(speed)
		set.speed = speed
	end
	return true
end

-- an uploaded track for this action has loaded
function AnimationPack.trackReady(set, action)
	return (ready(set, action))
end

-- Plays an uploaded one-shot; false = none loaded for that action (play the procedural clip instead)
function AnimationPack.trackShot(set, action)
	local isReady, track = ready(set, action)
	if not isReady then
		return false
	end
	track:Play(0.1)
	set.busyUntil = os.clock() + track.Length
	return true
end

function AnimationPack.trackBusy(set)
	return set ~= nil and os.clock() < set.busyUntil
end

function AnimationPack.trackStop(set)
	if not set then
		return
	end
	for _, track in pairs(set.tracks) do
		pcall(function()
			track:Stop(0)
			track:Destroy()
		end)
	end
	table.clear(set.tracks)
	set.loop = nil
	if set.controller then
		set.controller:Destroy()
		set.controller = nil
	end
end

return AnimationPack
