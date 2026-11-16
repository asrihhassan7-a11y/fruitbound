-- Input → throw. PC: click/hold on the world. Mobile: tap the world or the THROW button (aim assist).
-- Console: R2 / ButtonA-free throw with aim assist. Visuals are predicted locally for instant feedback.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)
local Foods = require(Shared.Config.Foods)
local Zones = require(Shared.Config.Zones)
local Trajectory = require(Shared.Trajectory)
local State = require(script.Parent.State)
local FX = require(script.Parent.FX)
local Audio = require(script.Parent.Audio)
local FarmController = require(script.Parent.FarmController)

local player = Players.LocalPlayer
local ThrowRemote = Net.get("Throw")

local ThrowController = {}
local lastThrow = 0
local holding = false
local touches = {}

local function root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if r and h and h.Health > 0 then
		return r :: BasePart
	end
	return nil
end

local function currentFood()
	local d = State.data
	return d and Foods.ById[d.EquippedFood] or Foods.ById[Foods.Default]
end

function ThrowController.lastThrowTime(): number
	return lastThrow
end

function ThrowController.maxRange(): number
	local d = State.data
	if not d then
		return 30
	end
	return Trajectory.range(d.Computed.range, Trajectory.gravity(currentFood()))
end

function ThrowController.throwAt(target: Vector3): boolean
	local d = State.data
	local r = root()
	if not d or not r or d.AutoThrow or FarmController.holdingDragon() then
		return false
	end
	local now = os.clock()
	if now - lastThrow < d.Computed.cooldown then
		return false
	end
	lastThrow = now
	ThrowRemote:FireServer(target)
	-- local prediction (server computes the same arc authoritatively)
	local food = currentFood()
	local origin = r.Position + Vector3.new(0, 2, 0)
	local g = Trajectory.gravity(food)
	for _, t in Trajectory.spread(origin, target, d.Computed.multi) do
		local vel = Trajectory.solve(origin, t, d.Computed.range, g)
		local _, flight = Trajectory.simulate(origin, vel, g)
		FX.projectile(food.id, origin, vel, g, flight)
	end
	Audio.play("Throw", 0.9 + math.random() * 0.25)
	-- face the throw direction for a satisfying wind-up
	local flat = Vector3.new(target.X - r.Position.X, 0, target.Z - r.Position.Z)
	if flat.Magnitude > 1 then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude < 0.1 then
			r.CFrame = CFrame.lookAt(r.Position, r.Position + flat)
		end
	end
	return true
end

local function worldPointFromScreen(pos: Vector2): Vector3?
	local cam = workspace.CurrentCamera
	local params = Trajectory.params()
	if not cam or not params then
		return nil
	end
	local ray = cam:ViewportPointToRay(pos.X, pos.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if hit then
		return hit.Position
	end
	return ray.Origin + ray.Direction * 200
end

-- Throw button / R2: straight out into the furthest unlocked zone you can reach (same rule as server Auto Throw).
function ThrowController.throwAssist()
	local r = root()
	local d = State.data
	if not r or not d then
		return
	end
	local reach = r.Position.Z + ThrowController.maxRange() * 0.92
	local _, zEnd = Zones.band(d.MaxZone)
	local z = math.max(math.min(reach, zEnd - 3), Zones.FIELD_START + 3)
	local x = math.clamp(r.Position.X + math.random(-16, 16), -Zones.FIELD_W / 2 + 4, Zones.FIELD_W / 2 - 4)
	ThrowController.throwAt(Vector3.new(x, 0, z))
end

function ThrowController.start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 then
			holding = true
			local p = worldPointFromScreen(Vector2.new(input.Position.X, input.Position.Y))
			if p then
				ThrowController.throwAt(p)
			end
		elseif t == Enum.UserInputType.Touch then
			-- throw on a quick tap only, so dragging the camera doesn't throw
			touches[input] = { pos = Vector2.new(input.Position.X, input.Position.Y), t = os.clock() }
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.F then
			ThrowController.throwAssist()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		elseif input.UserInputType == Enum.UserInputType.Touch then
			local start = touches[input]
			touches[input] = nil
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if start and os.clock() - start.t < 0.35 and (pos - start.pos).Magnitude < 14 then
				local p = worldPointFromScreen(pos)
				if p then
					ThrowController.throwAt(p)
				end
			end
		end
	end)
	-- hold to keep throwing (PC)
	RunService.Heartbeat:Connect(function()
		if holding then
			local m = UserInputService:GetMouseLocation()
			local p = worldPointFromScreen(m)
			if p then
				ThrowController.throwAt(p)
			end
		end
		if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then
			ThrowController.throwAssist()
		end
	end)
	Net.get("FoodThrown").OnClientEvent:Connect(function(thrower, foodId, origin, vel, g, flight, auto)
		if thrower == player and not auto then
			return -- already predicted locally
		end
		local d = State.data
		if thrower ~= player and d and d.Settings and d.Settings.ShowOthers == false then
			return
		end
		FX.projectile(foodId, origin, vel, g, flight)
		if thrower == player then
			Audio.play("Throw", 1)
		end
	end)
end

return ThrowController
