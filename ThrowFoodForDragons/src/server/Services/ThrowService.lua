-- Validates throws, computes authoritative arcs and hands landings to DragonService.
-- Also runs the server-side Auto Throw for game pass owners.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Net = require(Shared.Net)
local Util = require(Shared.Util)
local Foods = require(Shared.Config.Foods)
local Trajectory = require(Shared.Trajectory)
local DataService = require(script.Parent.DataService)
local PlayerService = require(script.Parent.PlayerService)
local DragonService = require(script.Parent.DragonService)
local PlotService = require(script.Parent.PlotService)
local Zones = require(Shared.Config.Zones)

local ThrowRemote = Net.get("Throw")
local FoodThrown = Net.get("FoodThrown")

local ThrowService = {}
local lastThrow: { [Player]: number } = {}
local throwListeners = {}

function ThrowService.onThrow(fn)
	table.insert(throwListeners, fn)
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and hum.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Returns true if the throw happened.
function ThrowService.throw(player: Player, target: Vector3, auto: boolean?): boolean
	local profile = DataService.get(player)
	local stats = PlayerService.stats(player)
	local root = rootOf(player)
	if not profile or not stats or not root then
		return false
	end
	local now = os.clock()
	-- 15% tolerance for network jitter; still caps the real rate at the upgrade value
	if now - (lastThrow[player] or 0) < stats.cooldown * 0.85 then
		return false
	end
	if (target - root.Position).Magnitude > 700 or not PlotService.isOnPlot(player, root.Position) then
		return false -- you can only throw from your own farm
	end
	lastThrow[player] = now
	local food = Foods.ById[profile.EquippedFood] or Foods.ById[Foods.Default]
	local origin = root.Position + Vector3.new(0, 2, 0)
	local g = Trajectory.gravity(food)
	for _, t in Trajectory.spread(origin, target, stats.multi) do
		local vel = Trajectory.solve(origin, t, stats.range, g)
		local land, flight, hit = Trajectory.simulate(origin, vel, g)
		FoodThrown:FireAllClients(player, food.id, origin, vel, g, flight, auto == true)
		local zone = hit and hit:GetAttribute("Zone")
		task.delay(flight, DragonService.landFood, player, food, land, zone, origin)
	end
	profile.Stats.Throws += 1
	for _, fn in throwListeners do
		task.spawn(fn, player)
	end
	return true
end

-- Auto Throw / aim assist target: straight out into the furthest unlocked zone you can reach.
function ThrowService.autoTarget(from: Vector3, speed: number, food, maxZone: number): Vector3
	local reach = from.Z + Trajectory.range(speed, Trajectory.gravity(food)) * 0.92
	local _, zEnd = Zones.band(maxZone)
	local z = math.min(reach, zEnd - 3)
	local x = math.clamp(from.X + math.random(-16, 16), -Zones.FIELD_W / 2 + 4, Zones.FIELD_W / 2 - 4)
	return Vector3.new(x, 0, math.max(z, Zones.FIELD_START + 3))
end

function ThrowService.start()
	ThrowRemote.OnServerEvent:Connect(function(player, target)
		if not Util.finiteVector(target) then
			return
		end
		local profile = DataService.get(player)
		if profile and profile.AutoThrow then
			return -- auto throw is running on the server
		end
		ThrowService.throw(player, target, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
	-- Auto Throw loop (server-side so it can't be abused from the client)
	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if profile and profile.AutoThrow and PlayerService.hasPass(player, "AutoThrow") then
					local stats = PlayerService.stats(player)
					local root = rootOf(player)
					if stats and root and os.clock() - (lastThrow[player] or 0) >= stats.cooldown then
						local food = Foods.ById[profile.EquippedFood] or Foods.ById[Foods.Default]
						ThrowService.throw(player, ThrowService.autoTarget(root.Position, stats.range, food, profile.MaxZone), true)
					end
				end
			end
		end
	end)
	-- fall recovery: anyone below the islands is put back at their zone entrance
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				if root and root.Position.Y < -18 then
					root.AssemblyLinearVelocity = Vector3.zero
					player.Character:PivotTo(PlotService.spawnCFrame(player))
				end
			end
		end
	end)
end

return ThrowService
