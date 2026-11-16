-- Field visuals for the local player: dims zones they haven't unlocked, updates zone signs,
-- and draws a "max throw distance" line in front of their farm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Util = require(Shared.Util)
local Zones = require(Shared.Config.Zones)
local Foods = require(Shared.Config.Foods)
local Trajectory = require(Shared.Trajectory)
local State = require(script.Parent.State)

local ZoneController = {}
local player = Players.LocalPlayer
local overlays: { [number]: BasePart } = {}
local rangeLine: BasePart
local folder: Folder

local function refresh()
	local d = State.data
	if not d then
		return
	end
	for i, z in Zones.List do
		local locked = i > d.MaxZone
		overlays[i].Transparency = locked and 0.45 or 1
		local map = workspace:FindFirstChild("TFFD_Map")
		local sign = map and map.Signs:FindFirstChild("Sign" .. i)
		local text = sign and sign:FindFirstChild("Label") and sign.Label:FindFirstChild("Text")
		if text then
			if not locked then
				text.Text = z.icon .. " " .. z.name .. "  x" .. z.mult
				text.TextColor3 = Color3.new(1, 1, 1)
			elseif i == d.MaxZone + 1 then
				text.Text = "🔒 " .. z.name .. " — " .. Util.fmt(z.cost) .. " (Zones menu)"
				text.TextColor3 = Color3.fromRGB(255, 220, 90)
			else
				text.Text = "🔒 " .. z.name
				text.TextColor3 = Color3.fromRGB(200, 200, 210)
			end
		end
	end
end

local function updateRangeLine()
	local d = State.data
	local plot = player:GetAttribute("Plot")
	if not d or not plot then
		return
	end
	local food = Foods.ById[d.EquippedFood] or Foods.List[1]
	local reach = -7 + Trajectory.range(d.Computed.range, Trajectory.gravity(food))
	local c = Zones.plotCenter(plot)
	rangeLine.CFrame = CFrame.new(c.X, 0.25, reach)
end

function ZoneController.current(): number
	local d = State.data
	return d and d.MaxZone or 1
end

function ZoneController.start()
	folder = Instance.new("Folder")
	folder.Name = "TFFD_Field"
	folder.Parent = workspace
	for i = 1, #Zones.List do
		local z0, z1 = Zones.band(i)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(20, 15, 35)
		p.Size = Vector3.new(Zones.FIELD_W, 0.2, z1 - z0)
		p.CFrame = CFrame.new(0, 0.2 + i * 0.01, (z0 + z1) / 2)
		p.Transparency = 1
		p.Parent = folder
		overlays[i] = p
	end
	rangeLine = Instance.new("Part")
	rangeLine.Name = "RangeLine"
	rangeLine.Anchored = true
	rangeLine.CanCollide = false
	rangeLine.CanQuery = false
	rangeLine.CanTouch = false
	rangeLine.Material = Enum.Material.Neon
	rangeLine.Color = Color3.fromRGB(255, 220, 60)
	rangeLine.Transparency = 0.35
	rangeLine.Size = Vector3.new(Zones.PLOT_W - 4, 0.15, 0.6)
	rangeLine.CFrame = CFrame.new(0, -50, 0)
	rangeLine.Parent = folder
	State.Changed:Connect(function()
		refresh()
		updateRangeLine()
	end)
	player:GetAttributeChangedSignal("Plot"):Connect(updateRangeLine)
end

return ZoneController
