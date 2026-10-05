repeat task.wait() until _G._L

--> Variables
local _L = _G._L

local Network = _L.Get {"Common", "Library", "Network"}
local UI = _L.Get {"Client", "Modules", "UI"}
local Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
local Services = _L.Get {"Common", "Library", "Services"}
local Audio = _L.Get {"Common", "Library", "Audio"}
local NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
local Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
local Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
local Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
local ColourUtility = _L.Get {"Common", "Library", "Utilities", "ColourUtility"}
local cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
local Products = _L.Get {"Common", "Modules", "Databases", "Products"}
local TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
local Shared = _L.Get {"Common", "Modules", "Shared"}
local Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
local RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
local Platform = _L.Get {"Client", "Modules", "Platform"}
local Create = _L.Get {"Common", "Library", "Functions", "Create"}
local TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
local AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
local Pool = _L.Get {"Common", "Library", "Classes", "Pool"}
local PowerEffects = _L.Get {"Common", "Modules", "Databases", "Powers", "Effects"}
local Data = _L.Get {"Client", "Library", "Classes", "Data"}
local Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
local PowerEffectUtility = _L.Get {"Common", "Modules", "Utilities", "PowerEffectUtility"}
local PowerUtility = _L.Get {"Common", "Modules", "Utilities", "PowerUtility"}
local Promise = _L.Get {"Common", "Library", "Classes", "Promise"}
local PowerComponentUtility = _L.Get {"Common", "Modules", "Utilities", "PowerComponentUtility"}
local FruitGroup = _L.Get {"Client", "Modules", "Classes", "FruitGroup"}
local Player = _L.Get {"Client", "Modules", "Controllers", "Player"}
local TrainingAreas = _L.Get {"Common", "Modules", "Databases", "TrainingAreas"}
local TrainingAreaUtility = _L.Get {"Common", "Modules", "Utilities", "TrainingAreaUtility"}
local Ranks = _L.Get {"Common", "Modules", "Databases", "Ranks"} 
local Beam = _L.Get {"Client", "Modules", "Beam"}
local ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
local Zone = _L.Get {"Common", "Library", "Physics", "Zone"}
local Compress = _L.Get {"Common", "Library", "Functions", "Compress"}
local DiscordUtility = _L.Get {"Common", "Modules", "Utilities", "DiscordUtility"}

--> Constants

---------->
UI.Await()
Platform.Await()

local data = Data.Await()

_G.Data = data

local purchases = Purchases.Await()

_G.Purchases = purchases

local Notifications = UI.Get("Notifications")

--
task.spawn(function()
	local raycastParams = RaycastParams.new()

	raycastParams.FilterDescendantsInstances = {_L.Map:FindFirstChild("Safezones"), _L.Debris.Fruits, _L.Map:FindFirstChild("TrainingAreas")}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude 

	-- Harvest click: the server harvests the closest bush next to you
	local lastHint = 0

	local function click(position)
		local unitRay = workspace.CurrentCamera:ScreenPointToRay(position.X, position.Y)

		local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, raycastParams) -- 500 is how far to raycast

		local resultPosition = result and result.Position or _L.Player:GetMouse().Hit.Position

		-- holding a Seed Tool: a tap on the soil plants (SeedTools); only a tap ON a crop harvests
		local SeedTools = _L.Get {"Client", "Modules", "Controllers", "SeedTools"}
		if SeedTools and SeedTools.isHoldingSeed() then
			local node = result and result.Instance
			while node and node ~= workspace and not (node:IsA("Model") and Services.CollectionService:HasTag(node, "HarvestBush")) do
				node = node.Parent
			end
			if not node or node == workspace then
				return
			end
		end

		if resultPosition then
			local success, reason = Network.Remote.Invoke("S_Power_Click", resultPosition)

			if not success and os.clock() - lastHint > 10 then
				if reason == "no_bush" then
					lastHint = os.clock()
					Notifications:add({text = "🌿 Get closer to a plant", color = Color3.fromRGB(120, 230, 120), duration = 1.5})
				elseif reason == "full" then
					lastHint = os.clock()
					Notifications:add({text = "🎒 Backpack full!", color = Color3.fromRGB(255, 170, 60), duration = 2})
				elseif reason == "locked" then
					lastHint = os.clock()
					Notifications:add({text = "🔒 Garden locked", color = Color3.fromRGB(255, 120, 60), duration = 1.5})
				end
			end
		end
	end

	Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			click(input.Position)
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			-- controller: harvest the plant in front of you (the server picks the closest bush anyway)
			local vp = workspace.CurrentCamera.ViewportSize
			click(Vector2.new(vp.X / 2, vp.Y / 2))
		end
	end)

	Services.UserInputService.TouchTapInWorld:Connect(function(position, processedByUI)
		if processedByUI then
			return
		end

		click(position)
	end)
end)

--

Network.Remote.Fired("C_Power_Play", function(powerProps)
	local powerName = powerProps.name
	local powerPlayer = powerProps.player
	local powerPosition = powerProps.position
	
	local powerInfo = PowerUtility.getInfo(powerName)
	
	local powerComponentInfo = PowerComponentUtility.getInfo(powerInfo.component)
	local powerEffectInfo = PowerEffectUtility.getInfo(powerComponentInfo.effect)
	
	if not powerInfo or not powerComponentInfo or not powerEffectInfo then
		return
	end
	
	if powerProps.player == _L.Player and powerProps.strength_given then
		Network.Bindable.Fire("C_Character_Strength_Popup", powerProps.strength_given)
		
		UI.Get("HUD"):StatPopup({
			stat_name = "Strength",
			stat_value = powerProps.strength_given
		})
	end
	
	powerEffectInfo.callback({
		name = powerName,
		player = powerPlayer,
		position = powerPosition,
		info = powerInfo,
	})
end)

for _, player in pairs(Services.Players:GetPlayers()) do
	task.spawn(function()
		Player.new({instance = player})
	end)
end

Services.Players.PlayerAdded:Connect(function(player)
	Player.new({instance = player})
end)


if data then
	local fruitGroups = {}

	Services.RunService:BindToRenderStep("RenderFruits", Enum.RenderPriority.Camera.Value, function(dt)
		for player, fruitGroup in pairs(fruitGroups) do
			if fruitGroup._player.Parent ~= Services.Players or (not data:Get({"settings", "Other_Fruits"}) and player ~= _L.Player) or (not data:Get({"settings", "Your_Fruits"}) and player == _L.Player) then
				fruitGroups[player] = nil
				fruitGroup:Destroy()
			end
		end
		
		for _, player in pairs(Services.Players:GetPlayers()) do
			if not data:Get({"settings", "Other_Fruits"}) and player ~= _L.Player then
				continue
			end
			
			if not data:Get({"settings", "Your_Fruits"}) and player == _L.Player then
				continue
			end
			
			local playerData = Data.Await(player, true)

			if playerData then
				local fruitGroup = fruitGroups[player]

				if not fruitGroup then
					local newFruitGroup = FruitGroup.new({
						player = player,
						data = playerData
					})

					fruitGroup = newFruitGroup
					fruitGroups[player] = newFruitGroup
				end

				fruitGroup:render(dt)
			end
		end
	end)
	
	local total = Tracker.new(TrainingAreaUtility.getTotalCount(data))
	
	total:Bind(function(value)
		local oldValue = total:GetLast()
		
		if oldValue and value and value > oldValue then
			Notifications:add({text = "🎉 You unlocked a new Garden!", color = Color3.fromRGB(0, 255, 0), audio = {name = "Unlock1"}})
		end
	end)
	
	task.spawn(function()
		local extraBindings = {}
		
		for _, trainingAreaInfo in pairs(TrainingAreas) do
			if typeof(trainingAreaInfo.required) == "table" then
				for _, binding in pairs(trainingAreaInfo.required.bindings) do
					table.insert(extraBindings, data:Track(binding))
				end
			end
		end
		
		Tracker.Subscribe({data:Track({"stats", "Strength"}), unpack(extraBindings), UI._current}, function()
			total:Set(TrainingAreaUtility.getTotalCount(data))

			for _, trainingAreaInfo in pairs(TrainingAreas) do
				local trainingAreaId = trainingAreaInfo.id

				local canUse = TrainingAreaUtility.canUse(data, trainingAreaId)

				local trainingAreaInstance = _L.Map.TrainingAreas:FindFirstChild(trainingAreaInfo.id)
				
				if trainingAreaInstance then
					trainingAreaInstance.BB.BillboardGui.Enabled = UI._current:Get() == nil
					trainingAreaInstance.BB.BillboardGui.Main.Icon.Lock.Visible = not canUse
					trainingAreaInstance.BB.BillboardGui.Main.Icon.ImageColor3 = if canUse then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(150, 150, 150)
				end
			end
		end)
	end)
	
	data:Bind("settings", function(value)
		Services.SoundService.Music.Playing = value.Music
	end)
end

Network.Remote.Fired("C_Kill", function(pl)
	Notifications:add({
		text = "💀 Killed "..pl.Name.."!",
		color = Color3.fromRGB(255, 0, 0),
		audio = {name = "Kill1"}
	})
end)

Network.Remote.Fired("king", function(pl)
	Notifications:add({
		text = "👑 You are now the King!",
		color = Color3.fromRGB(255, 255, 0),
		audio = {name = "King1"}
	})
end)

local t

_L.PlayerGui.Pulse.Enabled = true

Network.Remote.Fired("hit", function()
	if t then
		t()
	end
	
	Spr.Stop(_L.PlayerGui.Pulse.Main.UIScale)
	
	_L.PlayerGui.Pulse.Main.UIScale.Scale = 2
	
	Spr.Target(_L.PlayerGui.Pulse.Main.UIScale, 1, 4, {
		Scale = 1
	})
	
	t = cancellableDelay(0.1, function()
		Spr.Target(_L.PlayerGui.Pulse.Main.UIScale, 1, 4, {
			Scale = 2
		})
	end)
	
	Audio.Play({name = "Damage1"})
end)

Network.Remote.Fired("heyyyy", function(...)
	Audio.Play(...)
end)

-->
task.spawn(function()
	repeat task.wait() until _G.persistent_loaded

	for _, interactiveInstance in pairs(_L.Map.Interactives:GetChildren()) do
		local uiName = interactiveInstance.Name

		task.spawn(function()
			if uiName == "DiscordVerification" then
				local m = _L.Map.Interactives.DiscordVerification
				m.Parent = nil
				local isAllowed = DiscordUtility.isAllowed(_L.Player)
				m.Parent = if isAllowed then _L.Map.Interactives else nil
			end
		end)

		local zonePart = interactiveInstance:FindFirstChild("Zone")
		if not zonePart then continue end
		local interactiveZone = Zone.new(zonePart)

		interactiveZone.localPlayerEntered:Connect(function()
			if uiName == "Electro_Spirit" then
				Purchases.PromptProduct(uiName)
			else
				UI.Open({name = uiName})
			end
			
		end)

		interactiveZone.localPlayerExited:Connect(function()
			if uiName ~= "Electro_Spirit" then
				if UI._current:Get() == uiName then
					UI.Close({name = uiName})
				end
			end
			
		end)
	end
end)
-->

--repeat task.wait() until _G.persistent_loaded

--local h = {Color3.fromRGB(0, 171, 221), Color3.fromRGB(223, 47, 42), Color3.fromRGB(24, 214, 3), Color3.fromRGB(213, 12, 206)}

--local x = 0

--for _, rankInfo in pairs(Ranks) do
--	if x == #h then
--		x = 1
--	else
--		x += 1
--	end
	
--	local newCellTemplate = _L.Assets.UI.RankCellTemplate:Clone()
	
--	newCellTemplate.Rank.TextLabel.Text = rankInfo.name.." - "..(NumberUtility.short(rankInfo.required).." Rebirths")
--	newCellTemplate.Rank.ImageColor3 = h[x]
	
--	newCellTemplate.Parent = _L.Map:WaitForChild("Ranks").Screen.SurfaceGui.ScrollingFrame
--end