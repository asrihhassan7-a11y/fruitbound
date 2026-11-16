-- Renders every player's farm dragons (from the "Farm" attribute) and handles placing a dragon
-- from the backpack: equip its tool, then click/tap a spot on your farm.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Zones = require(Shared.Config.Zones)
local DragonDefs = require(Shared.Config.Dragons)
local DragonBuilder = require(Shared.DragonBuilder)
local State = require(script.Parent.State)
local FX = require(script.Parent.FX)
local Audio = require(script.Parent.Audio)

local FarmController = {}
local localPlayer = Players.LocalPlayer
local farms: { [Player]: { any } } = {}
local folder: Folder
local lowGfx = false
local SCALE = 0.62

local function parse(attr: any)
	local out = {}
	if type(attr) ~= "string" then
		return out
	end
	for entry in string.gmatch(attr, "[^;]+") do
		local d, x, z = string.match(entry, "^([^:]+):([^:]+):([^:]+)$")
		if d and DragonDefs.ById[d] then
			table.insert(out, { d = d, x = tonumber(x) or 0, z = tonumber(z) or 0 })
		end
	end
	return out
end

local function newFarmDragon(p: Player, e)
	local def = DragonDefs.ById[e.d]
	local rig = DragonBuilder.build(def, { scale = SCALE, lowGfx = lowGfx or p ~= localPlayer, nameTag = p == localPlayer })
	local tag = rig.head:FindFirstChild("Tag")
	if tag then
		tag.MaxDistance = 45
	end
	rig.model.Parent = folder
	return { key = e.d .. ":" .. e.x .. ":" .. e.z, rig = rig, def = def, home = Vector3.new(e.x, 0, e.z), pos = Vector3.new(e.x, 0, e.z), goal = Vector3.new(e.x, 0, e.z), yaw = math.random() * 6, next = 0, phase = math.random() * 10 }
end

local function rebuild(p: Player)
	local list = farms[p] or {}
	local wanted = parse(p:GetAttribute("Farm"))
	-- keep matching entries, build new ones, drop removed ones
	local pool = {}
	for _, f in list do
		pool[f.key] = pool[f.key] or {}
		table.insert(pool[f.key], f)
	end
	local result = {}
	for _, e in wanted do
		local key = e.d .. ":" .. e.x .. ":" .. e.z
		local bucket = pool[key]
		if bucket and #bucket > 0 then
			table.insert(result, table.remove(bucket))
		else
			local f = newFarmDragon(p, e)
			if p == localPlayer and #list > 0 then
				f.pop = os.clock()
			end
			table.insert(result, f)
		end
	end
	for _, bucket in pool do
		for _, f in bucket do
			f.rig.model:Destroy()
		end
	end
	farms[p] = result
end

local function track(p: Player)
	p:GetAttributeChangedSignal("Farm"):Connect(function()
		rebuild(p)
	end)
	rebuild(p)
end

function FarmController.setLowGfx(v: boolean)
	lowGfx = v
end

local function step(dt: number)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local now = os.clock()
	for p, list in farms do
		local plot = p:GetAttribute("Plot")
		if not plot then
			continue
		end
		local center = Zones.plotCenter(plot)
		if (center - camPos).Magnitude > 260 then
			continue
		end
		for _, f in list do
			-- wander around its home spot
			if now > f.next then
				f.next = now + math.random(30, 70) / 10
				f.goal = f.home + Vector3.new(math.random(-50, 50) / 10, 0, math.random(-50, 50) / 10)
			end
			local delta = f.goal - f.pos
			local moving = delta.Magnitude > 0.3
			if moving then
				local stepLen = math.min(delta.Magnitude, dt * 5)
				f.pos += delta.Unit * stepLen
				f.yaw = math.atan2(-delta.X, -delta.Z)
			end
			local t = now + f.phase
			local s = f.rig.scale
			local y = f.def.move == "fly" and (1.8 + math.sin(t * 2) * 0.4) * s or (moving and math.abs(math.sin(t * 8)) * 0.4 * s or 0)
			if f.pop then
				local a = (now - f.pop) / 0.5
				if a >= 1 then
					f.pop = nil
				else
					y += (1 - a) * 10
				end
			end
			local flap = f.def.move == "fly" and (0.45 + math.sin(t * 8) * 0.6) or (0.45 + math.sin(t * 1.5) * 0.1)
			local wp = center + f.pos
			DragonBuilder.pose(f.rig, CFrame.new(wp.X, y, wp.Z) * CFrame.Angles(0, f.yaw, 0), {
				head = CFrame.Angles(math.rad(math.sin(t * 2) * 6), math.rad(math.sin(t * 0.7) * 12), 0),
				wingL = CFrame.Angles(0, 0, -flap),
				wingR = CFrame.Angles(0, 0, flap),
				tail = CFrame.Angles(0, math.rad(math.sin(t * 2.5) * 18), 0),
			})
		end
	end
end

-- Placement: equipping a dragon tool shows a marker; clicking places it at that spot on your farm.
local function hookTool(tool: Tool)
	local defId = tool:GetAttribute("DefId")
	if not defId then
		return
	end
	tool.Activated:Connect(function()
		local plot = localPlayer:GetAttribute("Plot")
		if not plot then
			return
		end
		local hit = localPlayer:GetMouse().Hit.Position
		local c = Zones.plotCenter(plot)
		local r = State.action("PlaceDragon", { d = defId, x = hit.X - c.X, z = hit.Z - c.Z })
		if r.ok then
			Audio.play("Unlock")
			FX.burst(Vector3.new(hit.X, 2, hit.Z), DragonDefs.ById[defId].accent, 20)
		end
	end)
end

function FarmController.start()
	folder = Instance.new("Folder")
	folder.Name = "TFFD_Farms"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(p)
		for _, f in farms[p] or {} do
			f.rig.model:Destroy()
		end
		farms[p] = nil
	end)
	for _, p in Players:GetPlayers() do
		track(p)
	end
	local function watch(container: Instance)
		container.ChildAdded:Connect(function(c)
			if c:IsA("Tool") and not c:GetAttribute("Hooked") then
				c:SetAttribute("Hooked", true)
				hookTool(c)
			end
		end)
		for _, c in container:GetChildren() do
			if c:IsA("Tool") and not c:GetAttribute("Hooked") then
				c:SetAttribute("Hooked", true)
				hookTool(c)
			end
		end
	end
	watch(localPlayer:WaitForChild("Backpack"))
	localPlayer.CharacterAdded:Connect(function()
		watch(localPlayer:WaitForChild("Backpack"))
	end)
	RunService.RenderStepped:Connect(step)
end

-- Does the local player currently hold a dragon tool? (throwing is paused while placing)
function FarmController.holdingDragon(): boolean
	local char = localPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("DefId") ~= nil
end

return FarmController
