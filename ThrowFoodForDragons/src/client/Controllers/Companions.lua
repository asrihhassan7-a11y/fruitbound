-- Renders every player's equipped companion dragons following them (client-side, no replication cost).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("TFFD")
local Companions = require(Shared.Config.Companions)
local DragonDefs = require(Shared.Config.Dragons)
local DragonBuilder = require(Shared.DragonBuilder)

local CompanionController = {}
local byPlayer: { [Player]: { any } } = {}
local folder: Folder
local lowGfx = false

local function clear(p: Player)
	for _, c in byPlayer[p] or {} do
		c.rig.model:Destroy()
	end
	byPlayer[p] = nil
end

local function rebuild(p: Player)
	clear(p)
	local attr = p:GetAttribute("Companions")
	if type(attr) ~= "string" or attr == "" then
		return
	end
	local list = {}
	for petId in string.gmatch(attr, "[^,]+") do
		local pet = Companions.Pets[petId]
		local def = pet and DragonDefs.ById[pet.look]
		if def then
			-- companions use the pet's rarity, not the wild dragon's, for size/effects
			local petDef = table.clone(def)
			petDef.rarity = pet.rarity
			local rig = DragonBuilder.build(petDef, { scale = 0.32, lowGfx = lowGfx })
			rig.model.Parent = folder
			table.insert(list, { rig = rig, pos = nil, yaw = 0, phase = math.random() * 6 })
		end
	end
	byPlayer[p] = list
end

local function track(p: Player)
	p:GetAttributeChangedSignal("Companions"):Connect(function()
		rebuild(p)
	end)
	rebuild(p)
end

function CompanionController.setLowGfx(v: boolean)
	if v ~= lowGfx then
		lowGfx = v
		for p in byPlayer do
			rebuild(p)
		end
	end
end

local function step(dt: number)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local now = os.clock()
	for p, list in byPlayer do
		local char = p.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			continue
		end
		if (hrp.Position - camPos).Magnitude > 220 then
			continue
		end
		local base = hrp.CFrame
		local n = #list
		for i, c in list do
			local angle = (n == 1) and 0 or ((i - 1) / (n - 1) - 0.5) * math.rad(110)
			local offset = CFrame.Angles(0, angle, 0) * Vector3.new(0, 0, 6.5)
			local goal = base.Position + base:VectorToWorldSpace(offset) + Vector3.new(0, 0.5 + math.sin(now * 2.5 + c.phase) * 0.6, 0)
			c.pos = c.pos and c.pos:Lerp(goal, math.min(1, dt * 7)) or goal
			local _, yaw = base:ToOrientation()
			c.yaw = yaw
			local flap = 0.5 + math.sin(now * 11 + c.phase) * 0.6
			DragonBuilder.pose(c.rig, CFrame.new(c.pos) * CFrame.Angles(0, c.yaw, 0), {
				wingL = CFrame.Angles(0, 0, -flap),
				wingR = CFrame.Angles(0, 0, flap),
				tail = CFrame.Angles(0, math.rad(math.sin(now * 3 + c.phase) * 20), 0),
			})
		end
	end
end

function CompanionController.start()
	folder = Instance.new("Folder")
	folder.Name = "TFFD_Companions"
	folder.Parent = workspace
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(clear)
	for _, p in Players:GetPlayers() do
		track(p)
	end
	RunService.RenderStepped:Connect(step)
end

return CompanionController
