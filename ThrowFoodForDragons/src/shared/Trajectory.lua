-- Deterministic throw arc shared by server (authoritative landing) and client (instant visuals).
local Trajectory = {}

Trajectory.ANGLE = math.rad(30)
Trajectory.MAX_TIME = 4
Trajectory.MAP_NAME = "TFFD_Map"

-- Floaty arcs feel better than full Roblox gravity.
function Trajectory.gravity(food): number
	return workspace.Gravity * 0.5 * (food.gravity or 1)
end

-- Max flat distance reachable with launch speed v.
function Trajectory.range(v: number, g: number): number
	return v * v * math.sin(2 * Trajectory.ANGLE) / g
end

local params: RaycastParams? = nil
function Trajectory.params(): RaycastParams?
	if params then
		return params
	end
	local map = workspace:FindFirstChild(Trajectory.MAP_NAME)
	if not map then
		return nil
	end
	local list = {}
	for _, n in { "Ground", "Water" } do
		local f = map:FindFirstChild(n)
		if f then
			table.insert(list, f)
		end
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	p.FilterDescendantsInstances = list
	params = p
	return p
end

-- Launch velocity at a fixed angle that lands on `target`, capped by `maxSpeed`.
function Trajectory.solve(origin: Vector3, target: Vector3, maxSpeed: number, g: number): Vector3
	local delta = target - origin
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local d = flat.Magnitude
	local dir = d > 0.5 and flat.Unit or Vector3.new(0, 0, -1)
	d = math.max(d, 0.5)
	local th = Trajectory.ANGLE
	local c = math.cos(th)
	local denom = 2 * c * c * (d * math.tan(th) - delta.Y)
	local speed = maxSpeed
	if denom > 0 then
		local s = math.sqrt(g * d * d / denom)
		if s == s then
			speed = math.min(s, maxSpeed)
		end
	end
	speed = math.max(speed, 12)
	return (dir * c + Vector3.yAxis * math.sin(th)) * speed
end

function Trajectory.at(origin: Vector3, vel: Vector3, g: number, t: number): Vector3
	return origin + vel * t - Vector3.yAxis * (0.5 * g * t * t)
end

-- Steps the arc and raycasts against the map. Returns landing position, flight time, hit part (or nil).
function Trajectory.simulate(origin: Vector3, vel: Vector3, g: number): (Vector3, number, BasePart?)
	local p = Trajectory.params()
	local dt = 1 / 15
	local t = 0
	local pos = origin
	while t < Trajectory.MAX_TIME do
		local nextPos = Trajectory.at(origin, vel, g, t + dt)
		local step = nextPos - pos
		if p then
			local hit = workspace:Raycast(pos, step, p)
			if hit then
				local frac = (hit.Position - pos).Magnitude / math.max(step.Magnitude, 1e-3)
				return hit.Position, t + dt * frac, hit.Instance :: BasePart
			end
		end
		pos = nextPos
		t += dt
	end
	return pos, t, nil
end

-- Spread pattern for multi-throw: targets fanned out sideways (same on server and client).
function Trajectory.spread(origin: Vector3, target: Vector3, count: number): { Vector3 }
	local out = { target }
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	if flat.Magnitude < 0.5 then
		flat = Vector3.new(0, 0, -1)
	end
	for i = 2, count do
		local k = (i // 2) * ((i % 2 == 0) and -1 or 1)
		local rot = CFrame.Angles(0, math.rad(9 * k), 0)
		local v = rot:VectorToWorldSpace(flat) * (1 - 0.06 * math.abs(k))
		table.insert(out, Vector3.new(origin.X + v.X, target.Y, origin.Z + v.Z))
	end
	return out
end

return Trajectory
