---> CropTimer (client)
-- Visual-only growth timers above the local player's planted crops.
-- ALL authoritative growth math stays on the server (os.time timestamps in
-- FarmingV2). This display mirrors it using the server clock (S_Server_Now)
-- and the replicated Fruit data, so the countdown and the shown Growth Speed
-- always match the real growth result -- and update live when Fruits change.

local _L = _G._L

local CollectionService = game:GetService("CollectionService")

local Network
local Data
local FruitUtility
local SeedPacks
local NumberUtility

local NEAR_STUDS = 28 -- show the timer only when the player is close to their crop
local TICK = 0.15

local CropTimer = {}

local clockOffset = nil -- server os.time() - client os.time()
local playerData = nil -- local player's replicated profile data

-- trims trailing zeros: 1.25 -> "1.25", 2 -> "2"
local function boostText(n)
	local s = string.format("%.2f", n):gsub("%.?0+$", "")
	if s == "" then
		s = "0"
	end
	return "x" .. s
end

local function timeText(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

local function syncClock()
	local ok, serverNow = pcall(Network.Remote.Invoke, "S_Server_Now")
	if ok and typeof(serverNow) == "number" and serverNow > 0 then
		clockOffset = serverNow - os.time()
		return true
	end
	return false
end

-- The real growth boost (Fruits x Growth potion x Sprinklers), from the same shared calculation the server uses.
local function currentBoost()
	local boost = 1
	if playerData then
		local ok, result = pcall(SeedPacks.getGrowthMultiplier, playerData)
		if ok and typeof(result) == "number" and result == result and result >= 1 then
			boost = result -- already soft-capped by SeedPacks
		end
	end
	return boost
end

-- Builds one warm cream billboard for a crop model.
local function buildBillboard(model)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CropTimer"
	billboard.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") or model
	billboard.MaxDistance = 90
	billboard.Size = UDim2.new(4.6, 0, 1.7, 0)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0) -- raised every tick
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Enabled = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 246, 228) -- warm cream
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(139, 96, 60) -- wood brown
	stroke.Thickness = 2
	stroke.Transparency = 0.15
	stroke.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	local main = Instance.new("TextLabel")
	main.Name = "Main"
	main.LayoutOrder = 1
	main.Size = UDim2.fromScale(1, 0.62)
	main.BackgroundTransparency = 1
	main.Font = Enum.Font.FredokaOne
	main.TextScaled = true
	main.Text = "..."
	main.TextColor3 = Color3.fromRGB(94, 63, 36) -- deep brown
	main.Parent = frame

	local speed = Instance.new("TextLabel")
	speed.Name = "Speed"
	speed.LayoutOrder = 2
	speed.Size = UDim2.fromScale(1, 0.38)
	speed.BackgroundTransparency = 1
	speed.Font = Enum.Font.FredokaOne
	speed.TextScaled = true
	speed.Text = ""
	speed.TextColor3 = Color3.fromRGB(94, 63, 36)
	speed.Parent = frame

	billboard.Parent = model
	return billboard
end

local timers = {} -- [model] = BillboardGui

local function watchCrop(model)
	if not model:IsA("Model") or timers[model] then
		return
	end
	-- only the local player's crops carry a timer; empty slots have no model at all
	if model:GetAttribute("Owner") ~= _L.Player.UserId then
		return
	end
	timers[model] = buildBillboard(model)
end

local function unwatchCrop(model)
	local billboard = timers[model]
	if billboard then
		timers[model] = nil
		billboard:Destroy()
	end
end

function CropTimer._init()
	Network = _L.Get {"Common", "Library", "Network"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	SeedPacks = _L.Get {"Common", "Modules", "Databases", "SeedPacks"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
end

function CropTimer._start()
	-- server clock: fetch on join, keep refreshed (client system time is never trusted)
	task.spawn(function()
		for _ = 1, 60 do
			if syncClock() then
				break
			end
			task.wait(1)
		end
		while true do
			task.wait(120)
			syncClock()
		end
	end)

	-- replicated profile data -> live Growth Speed updates when Fruits change
	task.spawn(function()
		playerData = Data.Await()
	end)

	-- watch the local player's crops (server tags every planted/restored crop)
	for _, model in ipairs(CollectionService:GetTagged("SeedCrop")) do
		watchCrop(model)
	end
	CollectionService:GetInstanceAddedSignal("SeedCrop"):Connect(watchCrop)
	CollectionService:GetInstanceRemovedSignal("SeedCrop"):Connect(unwatchCrop)

	-- display heartbeat
	task.spawn(function()
		while true do
			task.wait(TICK)

			local character = _L.Player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end

			local boost = currentBoost()
			local speedText = "\u{26A1} Growth Speed: " .. boostText(boost)
			local serverNow = clockOffset and (os.time() + clockOffset) or nil

			for model, billboard in pairs(timers) do
				if not model.Parent or not billboard.Parent then
					unwatchCrop(model)
					continue
				end

				-- only show when the player is near their crop (no clutter, mobile friendly)
				local position = model:GetPivot().Position
				if (position - root.Position).Magnitude > NEAR_STUDS then
					billboard.Enabled = false
					continue
				end

				billboard.Enabled = true

				-- hover above the crop's real (scaled) height
				local _, bboxSize = model:GetBoundingBox()
				billboard.StudsOffsetWorldSpace = Vector3.new(0, bboxSize.Y / 2 + 1.3, 0)

				local main = billboard.Frame.Main
				local speed = billboard.Frame.Speed
				speed.Text = speedText
				speed.TextColor3 = if boost > 1 then Color3.fromRGB(46, 125, 50) else Color3.fromRGB(94, 63, 36)

				local plantedAt = model:GetAttribute("PlantedAt")
				local growthTime = model:GetAttribute("GrowthTime")
				local regrowing = model:GetAttribute("CropState") == "regrowing"
				-- same ready-time math as the server (SeedPacks.getReadyAt), incl. Watering Can time
				local readyAt = SeedPacks.getReadyAt({
					planted_at = plantedAt,
					water_credit = model:GetAttribute("WaterCredit"),
					state = model:GetAttribute("CropState"),
					regrow_ready_at = model:GetAttribute("RegrowReadyAt"),
					quick = model:GetAttribute("QuickGrow"),
				}, {growth_time = growthTime}, boost)

				if model:GetAttribute("Mature") then
					main.Text = "READY! Tap to Harvest"
					main.TextColor3 = Color3.fromRGB(46, 125, 50)
				elseif readyAt and typeof(growthTime) == "number" and serverNow then
					local remaining = readyAt - serverNow
					if remaining <= 0 then
						main.Text = "READY! Tap to Harvest"
						main.TextColor3 = Color3.fromRGB(46, 125, 50)
					else
						main.Text = (if regrowing then "\u{1F34E} Regrows in " else "\u{1F331} Ready in ") .. timeText(remaining)
						main.TextColor3 = Color3.fromRGB(94, 63, 36)
					end
				else
					main.Text = "\u{1F331} Growing..."
					main.TextColor3 = Color3.fromRGB(94, 63, 36)
				end
			end
		end
	end)
end

return CropTimer