-- Tracks which island the player is on (lighting mood + HUD banner) and opens unlocked gates locally.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Zones = require(Shared.Config.Zones)
local State = require(script.Parent.State)

local ZoneController = {}
local player = Players.LocalPlayer
local current = 0
local changed = Instance.new("BindableEvent")
ZoneController.Changed = changed.Event -- (zoneIndex)

function ZoneController.current(): number
	return current
end

local function applyMood(i: number)
	local z = Zones.List[i]
	local info = TweenInfo.new(1.5)
	local atm = Lighting:FindFirstChild("TFFD_Atmosphere")
	if atm then
		TweenService:Create(atm, info, { Color = z.fog }):Play()
	end
	local cc = Lighting:FindFirstChild("TFFD_Color")
	if cc then
		TweenService:Create(cc, info, { TintColor = z.tint }):Play()
	end
	local dark = z.decor == "shadow" or z.decor == "cosmic"
	TweenService:Create(Lighting, info, { ClockTime = dark and 0.5 or 14.5 }):Play()
end

local function refreshGates()
	local d = State.data
	local map = workspace:FindFirstChild("TFFD_Map")
	local gates = map and map:FindFirstChild("Gates")
	if not d or not gates then
		return
	end
	for _, gate in gates:GetChildren() do
		local zone = gate:GetAttribute("Zone")
		local open = zone and zone <= d.MaxZone
		gate.CanCollide = not open
		gate.Transparency = open and 1 or 0.2
		local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = not open and zone == d.MaxZone + 1
		end
		local bb = gate:FindFirstChildOfClass("BillboardGui")
		if bb then
			bb.Enabled = not open
		end
	end
end

function ZoneController.start()
	State.Changed:Connect(refreshGates)
	local map = workspace:WaitForChild("TFFD_Map")
	map:WaitForChild("Gates").ChildAdded:Connect(refreshGates)
	refreshGates()
	task.spawn(function()
		while true do
			task.wait(0.4)
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local z = Zones.fromPosition(r.Position)
				if z and z ~= current then
					current = z
					applyMood(z)
					changed:Fire(z)
				end
			end
		end
	end)
end

return ZoneController
