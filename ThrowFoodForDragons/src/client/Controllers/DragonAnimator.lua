-- Builds wild dragon models locally and animates them from server events (spawn/move/eat/despawn).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)
local DragonDefs = require(Shared.Config.Dragons)
local Rarities = require(Shared.Config.Rarities)
local DragonBuilder = require(Shared.DragonBuilder)
local Zones = require(Shared.Config.Zones)
local Players = game:GetService("Players")
local FX = require(script.Parent.FX)

local DragonAnimator = {}
local dragons: { [number]: any } = {}
local folder: Folder
local lowGfx = false
local frame = 0

local function yawTo(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

local function lerpAngle(a: number, b: number, t: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * t
end

local function spawn(id: number, defId: string, pos: Vector3, yaw: number, to: Vector3?, remaining: number?)
	if dragons[id] then
		return
	end
	local def = DragonDefs.ById[defId]
	if not def then
		return
	end
	local rig = DragonBuilder.build(def, { nameTag = true, lowGfx = lowGfx })
	rig.model.Parent = folder
	local d = {
		id = id,
		def = def,
		rig = rig,
		pos = pos,
		yaw = yaw,
		targetYaw = yaw,
		phase = math.random() * 10,
		eatUntil = 0,
		rarity = Rarities.Info[def.rarity],
		posed = false,
	}
	if def.rarity == "Secret" or Rarities.Info[def.rarity].rainbow then
		d.rainbow = {}
		for _, e in rig.entries do
			if e.part.Color == def.body then
				table.insert(d.rainbow, e.part)
			end
		end
	end
	dragons[id] = d
	if to and remaining and remaining > 0 then
		d.from, d.to, d.t0, d.dur = pos, to, os.clock(), remaining
		d.targetYaw = yawTo(to.X - pos.X, to.Z - pos.Z)
	end
	-- pop in: drop from the sky with a puff
	d.spawnPop = os.clock()
	FX.burst(pos + Vector3.new(0, 2, 0), def.accent, d.rarity.rank >= 5 and 30 or 14, true)
	if d.rarity.rank >= 4 then
		FX.burst(pos + Vector3.new(0, 3, 0), d.rarity.color, 30)
	end
end

local function currentPos(d): Vector3
	if d.dur then
		local a = math.clamp((os.clock() - d.t0) / d.dur, 0, 1)
		return d.from:Lerp(d.to, a)
	end
	return d.pos
end

local handlers = {}
handlers.s = function(op)
	spawn(op[2], op[3], op[4], op[5])
end
handlers.x = function(op)
	local d = dragons[op[2]]
	if d then
		dragons[op[2]] = nil
		d.rig.model:Destroy()
	end
end
handlers.m = function(op)
	local d = dragons[op[2]]
	if not d then
		return
	end
	local from = currentPos(d)
	d.from, d.to, d.t0, d.dur = from, op[3], os.clock(), op[4]
	local dx, dz = op[3].X - from.X, op[3].Z - from.Z
	if dx * dx + dz * dz > 0.25 then
		d.targetYaw = yawTo(dx, dz)
	end
end
-- caught: fly back to the thrower's farm, then vanish into their backpack
handlers.c = function(op)
	local d = dragons[op[2]]
	if not d then
		return
	end
	local owner = Players:GetPlayerByUserId(op[3])
	local plot = owner and owner:GetAttribute("Plot")
	local target = plot and Zones.plotCenter(plot) + Vector3.new(0, 0, 10) or currentPos(d)
	d.catch = { t0 = os.clock(), from = currentPos(d), to = target }
	d.dur = nil
	d.targetYaw = yawTo(target.X - d.catch.from.X, target.Z - d.catch.from.Z)
	if owner == Players.LocalPlayer then
		FX.floating("CAUGHT!", d.rig.head.Position + Vector3.new(0, 3, 0), d.rarity.color, true)
	end
end
handlers.e = function(op)
	local d = dragons[op[2]]
	if d then
		d.eatUntil = os.clock() + 0.9
		d.targetYaw = op[3]
	end
end

function DragonAnimator.get(id: number)
	return dragons[id]
end

function DragonAnimator.headPosition(id: number): Vector3?
	local d = dragons[id]
	if not d then
		return nil
	end
	return d.rig.head.Position
end

-- Nearest dragon base position within `range` of `from` (used for the throw button aim assist).
function DragonAnimator.nearest(from: Vector3, range: number, maxZone: number, zoneOf): Vector3?
	local best, bestD = nil, range
	for _, d in dragons do
		local p = currentPos(d)
		local z = zoneOf(p)
		if z and z <= maxZone then
			local dist = (Vector3.new(from.X, 0, from.Z) - p).Magnitude
			if dist < bestD then
				best, bestD = p, dist
			end
		end
	end
	return best
end

function DragonAnimator.setLowGfx(v: boolean)
	lowGfx = v
end

local function animate(dt: number)
	frame += 1
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local camPos = cam.CFrame.Position
	local now = os.clock()
	for _, d in dragons do
		if d.catch then
			local a = (now - d.catch.t0) / 0.8
			if a >= 1 then
				FX.burst(d.catch.to + Vector3.new(0, 3, 0), d.rarity.color, 16)
				dragons[d.id] = nil
				d.rig.model:Destroy()
				continue
			end
			local p = d.catch.from:Lerp(d.catch.to, a * a)
			d.yaw = lerpAngle(d.yaw, d.targetYaw, math.min(1, dt * 10))
			local flap = 0.5 + math.sin(now * 20) * 0.7
			DragonBuilder.pose(d.rig, CFrame.new(p.X, math.sin(a * math.pi) * 22 + 2, p.Z) * CFrame.Angles(0, d.yaw, 0), {
				wingL = CFrame.Angles(0, 0, -flap),
				wingR = CFrame.Angles(0, 0, flap),
			})
			continue
		end
		local pos = currentPos(d)
		local moving = false
		if d.dur then
			if now - d.t0 >= d.dur then
				d.pos = d.to
				d.dur = nil
				pos = d.pos
			else
				moving = true
			end
		end
		local dist = (pos - camPos).Magnitude
		if d.posed and not moving and now > d.eatUntil and dist > 260 then
			continue -- far and static: keep last pose
		end
		if d.posed and dist > 160 and frame % 3 ~= 0 then
			continue -- mid distance: animate at 1/3 rate
		end
		d.posed = true
		d.yaw = lerpAngle(d.yaw, d.targetYaw, math.min(1, dt * 8))
		local t = now + d.phase
		local s = d.rig.scale
		local def = d.def
		local eating = now < d.eatUntil
		local y = 0
		local flap
		if def.move == "fly" then
			y = (2.5 + math.sin(t * 2) * 0.6) * s
			flap = 0.45 + math.sin(t * (moving and 12 or 7)) * 0.65
		elseif def.move == "hop" then
			y = moving and math.abs(math.sin(t * 9)) * 1.3 * s or math.abs(math.sin(t * 2)) * 0.15 * s
			flap = 0.5 + math.sin(t * 3) * 0.2
		else
			y = moving and math.abs(math.sin(t * 7)) * 0.25 * s or 0
			flap = moving and (0.55 + math.sin(t * 10) * 0.3) or (0.45 + math.sin(t * 1.5) * 0.1)
		end
		if eating and def.move == "fly" then
			y *= 0.4 -- swoop down to eat
		end
		local head
		if eating then
			head = CFrame.Angles(-math.rad(28 + math.sin(t * 26) * 12), 0, 0)
		elseif def.idle == "sway" then
			head = CFrame.Angles(math.rad(math.sin(t * 1.2) * 5), math.rad(math.sin(t * 0.8) * 16), 0)
		else
			head = CFrame.Angles(math.rad(math.sin(t * 2.2) * 6), math.rad(math.sin(t * 0.6) * 8), 0)
		end
		local extraYaw = 0
		if def.idle == "spin" and not moving then
			extraYaw = math.sin(t * 0.9) * 0.5
		end
		if d.spawnPop then
			local a = (now - d.spawnPop) / 0.45
			if a >= 1 then
				d.spawnPop = nil
			else
				y += (1 - a) * 12
			end
		end
		local root = CFrame.new(pos.X, pos.Y + y, pos.Z) * CFrame.Angles(0, d.yaw + extraYaw, 0)
		DragonBuilder.pose(d.rig, root, {
			head = head,
			wingL = CFrame.Angles(0, 0, -flap),
			wingR = CFrame.Angles(0, 0, flap),
			tail = CFrame.Angles(0, math.rad(math.sin(t * (moving and 6 or 2.4)) * 18), 0),
		})
		if d.rainbow then
			local c = Color3.fromHSV((t * 0.25) % 1, 0.75, 1)
			for _, p in d.rainbow do
				p.Color = c
			end
		end
	end
end

function DragonAnimator.start()
	folder = Instance.new("Folder")
	folder.Name = "TFFD_Dragons"
	folder.Parent = workspace
	local queue = {}
	local ready = false
	Net.get("Dragons").OnClientEvent:Connect(function(batch)
		if not ready then
			table.insert(queue, batch)
			return
		end
		for _, op in batch do
			local h = handlers[op[1]]
			if h then
				h(op)
			end
		end
	end)
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return Net.get("GetDragons"):InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			for _, e in snapshot do
				spawn(e[1], e[2], e[3], e[4], e[5], e[6])
			end
		end
		ready = true
		for _, batch in queue do
			for _, op in batch do
				local h = handlers[op[1]]
				if h then
					h(op)
				end
			end
		end
		queue = {}
	end)
	RunService.RenderStepped:Connect(animate)
end

return DragonAnimator
