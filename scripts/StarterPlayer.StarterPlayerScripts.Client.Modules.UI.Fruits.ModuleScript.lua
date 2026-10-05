--> Variables
local _L = _G._L

local FruitStageUtility

local Services
local Signal
local Tracker
local Data
local TableUtility
local NumberUtility
local Spr
local Trove
local Audio
local Shared
local Timer
local FastTween
local cancellableDelay
local Constants
local AttributeUtility
local TrackerUtility
local ArrayUtility
local UI
local Network
local FruitUtility
local PlantUtility
local FruitRarities
local FruitRarityUtility
local Notifications
local Purchases
local Module3D

--> Constants
local PREVIEW_FOV = 30
local PREVIEW_PADDING = 1.15 -- ~13% empty space around the fruit
local CELL_LABEL_SPACE = 0.26 -- inventory cells: the fruit name covers the bottom ~quarter
local PREVIEW_CLUTTER = {"ParticleEmitter", "Beam", "Trail", "PointLight", "SpotLight", "SurfaceLight", "BillboardGui", "Fire", "Smoke", "Sparkles", "Sound"}

-- Renders the real fruit model into `iconFrame` (a cell / detail Icon ImageLabel).
-- The Icon template ships with an old pet image, so it is always cleared first, and any
-- preview left over from an earlier render is removed so only this fruit is shown.
-- `labelSpace` (0-1) keeps the bottom of the frame free for a name label drawn over it.
-- Returns the ViewportFrame (or nil when the fruit has no model and an image is used).
local function renderFruitPreview(iconFrame, fruitInfo, stage, trove, labelSpace)
	for _, child in ipairs(iconFrame:GetChildren()) do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
	iconFrame.Image = ""

	local modelPath = fruitInfo.model
	local source = modelPath and modelPath ~= "" and _L.Assets.Models.Fruits:FindFirstChild(modelPath)
	if (fruitInfo.icon and fruitInfo.icon ~= "") or not source then
		iconFrame.Image = fruitInfo.icon or fruitInfo.image or ""
		return nil
	end

	local fruitModel = source:Clone()
	-- icons: ignore the asset's pivot offset so the fruit stands upright (same as the followers)
	for _, bp in ipairs(fruitModel:GetDescendants()) do if bp:IsA("BasePart") then bp.PivotOffset = CFrame.new() end end
	FruitStageUtility.applyVisuals(fruitModel, stage or 0)
	-- world-only effects (sparkles, lights, labels) don't belong in a thumbnail
	for _, d in ipairs(fruitModel:GetDescendants()) do
		if table.find(PREVIEW_CLUTTER, d.ClassName) then
			d:Destroy()
		end
	end
	-- fruits face -Z; turn them toward the viewport camera
	fruitModel:PivotTo(fruitModel:GetPivot() * CFrame.Angles(0, math.pi, 0))
	trove:Add(fruitModel)

	local model3D = Module3D:Attach3D(iconFrame, fruitModel)
	model3D.LightColor = Color3.fromRGB(255, 255, 255)
	model3D.Ambient = Color3.fromRGB(255, 255, 255)
	model3D.LightDirection = Vector3.new(1, 1, 1)

	-- fit the camera to the real bounding box: centered, same apparent size for every fruit
	local camera = model3D.CurrentCamera
	camera.FieldOfView = PREVIEW_FOV
	local boxCFrame, boxSize = fruitModel:GetBoundingBox()
	local center = boxCFrame.Position
	-- the camera looks along Z, so the visible extent is the larger of width / height; the
	-- front half of the depth is added so the nearest point of the model still fits
	local halfExtent = math.max(boxSize.X, boxSize.Y, 0.2) / 2
	local tanHalf = math.tan(math.rad(PREVIEW_FOV / 2))
	labelSpace = labelSpace or 0
	local distance = (halfExtent * PREVIEW_PADDING) / (tanHalf * (1 - labelSpace)) + boxSize.Z / 2
	-- slide the view down so the fruit sits in the space above the label
	local lift = Vector3.new(0, labelSpace * distance * tanHalf, 0)
	camera.CFrame = CFrame.lookAt(center - lift + Vector3.new(0, 0, distance), center - lift)
	camera.Focus = CFrame.new(center)

	model3D.Visible = true
	trove:Add(model3D)
	return model3D.AdornFrame
end

local LAST_FRUIT_TEXT = "You need at least 2 Fruits to delete one."

local function percent(fraction)
	local p = fraction * 100
	if p >= 10 or p == math.floor(p) then
		return tostring(math.floor(p + 0.5)) .. "%"
	end
	return string.format("%.1f%%", p)
end

-- V1.1 "FARM BONUSES" box in the Fruit details (real values from FruitFarmUtility, the same
-- module the server uses). Shows this Fruit's own bonuses + the combined total of all equipped Fruits.
local function renderFarmBonuses(focus, data, fruitData)
	local FruitFarmUtility = _L.Get {"Common", "Modules", "Utilities", "FruitFarmUtility"}
	local box = focus:FindFirstChild("FarmBonuses")
	if not box then
		box = Instance.new("Frame")
		box.Name = "FarmBonuses"
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.BackgroundColor3 = Color3.fromRGB(255, 248, 230)
		box.BackgroundTransparency = 0.1
		box.Parent = focus
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
		local s = Instance.new("UIStroke")
		s.Thickness = 2
		s.Color = Color3.fromRGB(110, 72, 38)
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = box
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.05, 0)
		pad.PaddingBottom = UDim.new(0.05, 0)
		pad.PaddingLeft = UDim.new(0.04, 0)
		pad.PaddingRight = UDim.new(0.04, 0)
		pad.Parent = box
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = box
		for i = 1, 5 do
			local l = Instance.new("TextLabel")
			l.Name = "Line" .. i
			l.LayoutOrder = i
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 0.2)
			l.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
			l.TextScaled = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextColor3 = Color3.fromRGB(90, 60, 30)
			-- same size on every line (TextScaled alone shrinks the long lines more than the short ones)
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = if i == 1 then 17 else 15
			cap.Parent = l
			l.Parent = box
		end
	end
	local mountBtn = focus:FindFirstChild("MountBtn")
	if mountBtn and mountBtn.Visible then
		box.Position = UDim2.fromScale(0.73, 0.745)
		box.Size = UDim2.fromScale(0.45, 0.14)
	else
		box.Position = UDim2.fromScale(0.73, 0.69)
		box.Size = UDim2.fromScale(0.45, 0.27)
	end
	local own = FruitFarmUtility.getFruitBonuses(fruitData, data)
	box.Line1.Text = "FARM BONUSES"
	box.Line1.TextColor3 = Color3.fromRGB(70, 140, 50)
	if fruitData.daycare then
		box.Line2.Text = "In Daycare: no farm bonus"
		box.Line3.Text = "💎 " .. FruitFarmUtility.getGemRate(fruitData) .. " Gems / hour"
		box.Line4.Text = ""
		box.Line5.Text = ""
		return
	end
	box.Line2.Text = "🌱 +" .. percent(own.growth) .. " Growth"
	box.Line3.Text = "🍀 +" .. percent(own.luck) .. " Luck"
	box.Line4.Text = "🧲 -" .. string.format("%.2g", own.assist) .. "s Auto"
	if fruitData.equipped then
		-- combined result of every equipped Fruit: growth, luck, Auto Collect seconds per pick
		box.Line5.Text = "All: +" .. percent(FruitFarmUtility.getGrowthBonus(data)) .. " · " .. percent(FruitFarmUtility.getHarvestLuck(data)) .. " · " .. string.format("%.1f", FruitFarmUtility.getAutoCollectCooldown(data)) .. "s"
		box.Line5.TextColor3 = Color3.fromRGB(70, 140, 50)
	else
		box.Line5.Text = "Equip to use it"
		box.Line5.TextColor3 = Color3.fromRGB(160, 110, 60)
	end
end

-- fruits the player can actually manage (legacy daycare fruits are never deletable)
local function getOwnedFruitCount(data)
	local count = 0
	for _, fruitData in pairs(data:Get("fruits") or {}) do
		if not fruitData.daycare then
			count += 1
		end
	end
	return count
end

------------->
local Fruits = {
	name = script.Name
}

function Fruits:_init()
	FruitStageUtility = _L.Get {"Common", "Modules", "Utilities", "FruitStageUtility"}
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	ArrayUtility = _L.Get {"Common", "Library", "Utilities", "ArrayUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"}
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	UI = _L.Get {"Client", "Modules", "UI"}
	FruitUtility = _L.Get {"Common", "Modules", "Utilities", "FruitUtility"}
	PlantUtility = _L.Get {"Common", "Modules", "Utilities", "PlantUtility"}
	FruitRarities = _L.Get {"Common", "Modules", "Databases", "Fruits", "Rarities"}
	FruitRarityUtility = _L.Get {"Common", "Modules", "Utilities", "FruitRarityUtility"}
	Rainbow = _L.Get {"Client", "Modules", "Classes", "Rainbow"}

	Module3D = _L.Get {"Common", "Library", "Classes", "Module3D"}
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
	self._focus = {tracker = Tracker.new(false), trove = Trove.new()}
	self._mode = {tracker = Tracker.new("Default"), trove = Trove.new()}
	self._selected_fruits = Tracker.new({})
end

function Fruits:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.Fruits
	self._instances = {}

	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
			-- opened from a fruit in a pen: show that fruit's details right away
			local focus = props and props.props and props.props.focus
			if focus and self._focus then
				task.defer(function()
					self._focus.tracker:Set(focus)
				end)
			end
		else
			self:Close()
		end
		end)

	local data = Data.Await()

	if data then
		Rainbow.new({
			speed = 3,
			callback = function(value)
				local function tint(icon, color)
					icon.ImageColor3 = color
					local vp = icon:FindFirstChildWhichIsA("ViewportFrame")
					if vp then
						-- softer on the 3D fruit so it stays recognisable
						vp.ImageColor3 = Color3.new(1, 1, 1):Lerp(color, 0.5)
					end
				end

				for _, v in pairs(self._instances) do
					local fruitData = FruitUtility.getData(data, v.uid)
					if fruitData then
						tint(v.instance.Icon, if fruitData.tier == "Rainbow" then value else Color3.fromRGB(255, 255, 255))
					end
				end

				local focusUid = self._focus.tracker:Get()

				if focusUid then
					local focusData = FruitUtility.getData(data, focusUid)

					if focusData and focusData.tier == "Rainbow" then
						tint(self.object.Main.Clip.Focus.Icon, value)
						return
					end
				end

				tint(self.object.Main.Clip.Focus.Icon, Color3.fromRGB(255, 255, 255))
			end,
		})

		local function update()
			local value = data:Get("fruits")

			-- Remove instances for fruits that no longer exist
			for fruitInstance, v in pairs(self._instances) do
				local fruitUid = v.uid
				local fruitData = FruitUtility.getData(data, fruitUid)

				-- also rebuild the cell when the fruit evolved (new look + name);
				-- V1.1: a Fruit that went to Daycare leaves the inventory grid
				if not fruitData or fruitData.daycare or (fruitData.stage or 0) ~= (v.stage or 0) then
					local i, vv = TableUtility.match(self._instances, function(i, v)
						return v.uid == fruitUid
					end)

					if i then
						table.remove(self._instances, i)
					end

					if vv then
						vv.trove:Destroy()
					end
				end
			end

			-- Create or update fruit cells
			for _, fruitData in pairs(value) do
				local fruitUid = fruitData.uid
				if fruitData.daycare then
					continue -- in Daycare (Fruit Pen): not usable from here
				end

				local _, v = TableUtility.match(self._instances, function(i, v)
					return v.uid == fruitUid
				end)

				local isEquipped = fruitData.equipped
				local fruitInstance = if v then v.instance else nil

				if not v then
					local fruitName = fruitData.name
					local fruitInfo = FruitUtility.getInfo(fruitName)
					if not fruitInfo then continue end

				local newTrove = Trove.new()

					fruitInstance = _L.Assets.UI.Fruits.Fruit:Clone()
					local gradientInstance = _L.Assets.Gradients.FruitRarities:FindFirstChild(fruitInfo.rarity)

					if gradientInstance then
						local newGradientInstance = gradientInstance:Clone()
						newGradientInstance.Parent = fruitInstance
					end

					newTrove:Add(self._mode.tracker:Bind(function(modeValue)
						-- Delete mode only dims the fruit; it must stay visible so the player sees what they pick
						local vp = fruitInstance.Icon:FindFirstChildWhichIsA("ViewportFrame")
						if vp then
							vp.ImageTransparency = if modeValue == "Delete" then 0.35 else 0
						end
						fruitInstance.Icon.ImageTransparency = if modeValue == "Delete" then 0.35 else 0
					end))

					local fruitText = fruitInstance:FindFirstChild("Fruit") or fruitInstance:FindFirstChild("Pet")
					if fruitText then
						fruitText.Text = FruitStageUtility.getDisplayName(fruitInfo.display_name or fruitInfo.name, fruitData.stage)
					end
					-- Real fruit model (falls back to the fruit's 2D icon when it has no model)
					renderFruitPreview(fruitInstance.Icon, fruitInfo, fruitData.stage or 0, newTrove, CELL_LABEL_SPACE)

					-- Show level on the cell
					local levelText = fruitInstance:FindFirstChild("Level")
					if not levelText then
						levelText = Instance.new("TextLabel")
						levelText.Name = "Level"
						levelText.Size = UDim2.new(0.4, 0, 0.15, 0)
						levelText.Position = UDim2.new(0.5, 0, 0.85, 0)
						levelText.AnchorPoint = Vector2.new(0.5, 0.5)
						levelText.BackgroundTransparency = 1
						levelText.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
						levelText.TextScaled = true
						levelText.TextColor3 = Color3.fromRGB(255, 255, 100)
						local ls = Instance.new("UIStroke")
						ls.Thickness = 1.5
						ls.Parent = levelText
						levelText.Parent = fruitInstance
					end
					levelText.Text = "Lv." .. (fruitData.level or 1)

					-- Show evolved/awakened indicators
					if fruitData.evolved then
						levelText.TextColor3 = Color3.fromRGB(180, 80, 255)
					end
					if fruitData.awakened then
						levelText.TextColor3 = Color3.fromRGB(255, 180, 50)
					end

					newTrove:Add(fruitInstance)

					fruitInstance.MouseButton1Down:Connect(function()
						if self._mode.tracker:Get() == "Default" then
							self._focus.tracker:Set(if self._focus.tracker:Get() == fruitUid then nil else fruitUid)
						elseif self._mode.tracker:Get() == "Delete" then
							local newSelected = TableUtility.deep.clone(self._selected_fruits:Get())

							local i = table.find(newSelected, fruitUid)

							if i then
								table.remove(newSelected, i)
							elseif #newSelected >= getOwnedFruitCount(data) - 1 then
								-- always leave at least one fruit
								Notifications:add({text = LAST_FRUIT_TEXT, color = Color3.fromRGB(255, 100, 100)})
								return
							else
								local selData = FruitUtility.getData(data, fruitUid)
								if selData and selData.daycare then
									return
								end
								table.insert(newSelected, fruitUid)
							end

							self._selected_fruits:Set(newSelected)
						end
					end)

					fruitInstance.Parent = self.object.Main.Middle

					table.insert(self._instances, {
						name = fruitName,
						info = fruitInfo,
						rarity_info = FruitRarityUtility.getInfo(fruitInfo.rarity),
						trove = newTrove,
						instance = fruitInstance,
						uid = fruitUid,
						stage = fruitData.stage or 0,
					})
				end

				-- Update equipped/delete indicators
				fruitInstance.Equip.Visible = if self._mode.tracker:Get() == "Default" then isEquipped else false
				local deleteInd = fruitInstance:FindFirstChild("Delete")
				if deleteInd then
					deleteInd.Visible = self._mode.tracker:Get() == "Delete" and table.find(self._selected_fruits:Get(), fruitUid) ~= nil
				end
			end

			-- Sort by rarity (highest first), then by boost, equipped first
			local mega = {}

			for i = #FruitRarities, 1, -1 do
				local rarityInfo = FruitRarities[i]

				local mini = ArrayUtility.filter(self._instances, function(i, v)
					return v.rarity_info and v.rarity_info.name == rarityInfo.name
				end)

				table.sort(mini, function(a, b)
					return (FruitUtility.getBoost(data, a.uid) or 0) > (FruitUtility.getBoost(data, b.uid) or 0)
				end)

				for _, v in pairs(mini) do
					table.insert(mega, v)
				end
			end

			-- Equipped first, then unequipped
			local mini1 = ArrayUtility.filter(mega, function(i, v)
				local d = FruitUtility.getData(data, v.uid)
				return d and d.equipped
			end)

			local mini2 = ArrayUtility.filter(mega, function(i, v)
				local d = FruitUtility.getData(data, v.uid)
				return d and not d.equipped
			end)

			table.clear(mega)

			for i, v in pairs(mini1) do
				table.insert(mega, v)
			end

			for i, v in pairs(mini2) do
				table.insert(mega, v)
			end

			for i, v in pairs(mega) do
				v.instance.LayoutOrder = i
			end

			-- Clear focus if fruit no longer exists (or went to Daycare)
			local _, v = TableUtility.match(value, function(i, v)
				return v.uid == self._focus.tracker:Get() and not v.daycare
			end)

			if not v then
				self._focus.tracker:Set(nil)
			end
		end

		Tracker.Subscribe({data:Track("fruits"), self._mode.tracker, self._selected_fruits, self._focus.tracker}, update)
		Timer.Simple(0.5, update)

		-- ============================================================
		-- FOCUS (DETAIL PANEL) HANDLER
		-- ============================================================
		self._focus.tracker:Bind(function(focusUid)
			self._focus.trove:Clean()

			local focus = self.object.Main.Clip.Focus

			if focusUid then
				local fruitData = FruitUtility.getData(data, focusUid)
				if not fruitData then return end

				local fruitName = fruitData.name
				local fruitInfo = FruitUtility.getInfo(fruitName)
				if not fruitInfo then return end
				local fruitRarityInfo = FruitRarityUtility.getInfo(fruitInfo.rarity)
				local summary = FruitUtility.getSummary(data, focusUid)

				-- Set basic info
				local fruitTextLabel = focus:FindFirstChild("Fruit")
				if fruitTextLabel then
					fruitTextLabel.Text = FruitStageUtility.getDisplayName(fruitInfo.display_name or fruitInfo.name, fruitData.stage)
				end
				-- Real fruit model (falls back to the fruit's 2D icon when it has no model)
				renderFruitPreview(focus.Icon, fruitInfo, fruitData.stage or 0, self._focus.trove)
				focus.Boost.Text = "🌱 +" .. percent(FruitUtility.getEffectiveBoost(fruitInfo, fruitData, data)) .. " Growth"

				-- Set rarity
				local rarityFrame = focus:FindFirstChild("Rarity")
				if rarityFrame then
					local rarityLabel = rarityFrame:FindFirstChild("Pet") or rarityFrame:FindFirstChild("Fruit")
					if rarityLabel then
						rarityLabel.Text = fruitRarityInfo and fruitRarityInfo.name or fruitInfo.rarity
					end

					-- Remove old gradients
					for _, child in ipairs(rarityFrame:GetChildren()) do
						if child:IsA("UIGradient") then
							child:Destroy()
						end
					end

					local rarityGradient = _L.Assets.Gradients.FruitRarities:FindFirstChild(fruitInfo.rarity)
					if rarityGradient then
						rarityGradient:Clone().Parent = rarityFrame
						end
				end

				-- Set level and EXP
				local levelLabel = focus:FindFirstChild("Level")
				if levelLabel and summary then
					levelLabel.Text = "Lv. " .. summary.level .. " / " .. summary.maxLevel
				end

				local expBar = focus:FindFirstChild("ExpBar")
				if expBar and summary then
					local fill = expBar:FindFirstChild("Fill")
					local expText = expBar:FindFirstChild("Text")
					if summary.isMaxLevel then
						if fill then fill.Size = UDim2.new(1, 0, 1, 0) end
						if expText then expText.Text = "MAX LEVEL" end
					else
						local ratio = summary.expNeeded > 0 and summary.exp / summary.expNeeded or 0
						ratio = math.clamp(ratio, 0, 1)
						if fill then fill.Size = UDim2.new(ratio, 0, 1, 0) end
						if expText then expText.Text = summary.exp .. " / " .. summary.expNeeded .. " EXP" end
					end
				end

				-- Set info text (evolution/awakening status)
				local infoLabel = focus:FindFirstChild("Info")
				if infoLabel and summary then
					-- Evolution stage, e.g. "✨ Golden stage (2/6)"
					infoLabel.Text = "✨ " .. summary.stageName .. " stage (" .. (summary.stage + 1) .. "/" .. (FruitStageUtility.MAX_STAGE + 1) .. ")"
				end

				-- Show/hide Evolve and Awaken buttons
				local evolveBtn = focus:FindFirstChild("EvolveBtn")
				local awakenBtn = focus:FindFirstChild("AwakenBtn")
				local oldBonuses = focus:FindFirstChild("FarmBonuses")
				if oldBonuses then
					oldBonuses.Visible = true
				end

				if evolveBtn then
					evolveBtn.Visible = summary and summary.canEvolve or false
					local evolveLabel = evolveBtn:FindFirstChildWhichIsA("TextLabel", true)
					if evolveLabel and summary and summary.nextStageName then
						evolveLabel.Text = "Evolve → " .. summary.nextStageName .. " (" .. NumberUtility.short(summary.evolveCost) .. " Coins)"
						evolveLabel.TextScaled = true
					end
				end
				if awakenBtn then
					awakenBtn.Visible = false -- replaced by evolution stages
				end

				-- Show/hide Feed button (only if not max level)
				local feedBtn = focus:FindFirstChild("FeedBtn")
				if feedBtn and summary then
					feedBtn.Visible = not summary.isMaxLevel
				end

				-- ============================================================
				-- BUTTON HANDLERS
				-- ============================================================

				-- Equip/Unequip
				self._focus.trove:Connect(focus.EquipBtn.MouseButton1Down, function()
					local hasEquipSpace = FruitUtility.hasEquipSpace(data)
					local success, newState = Network.Remote.Invoke("S_Fruits_Toggle_Equip", focusUid)

					Audio.Play({name = "Equip1", speed = if newState then 1.3 else 2.6})

					if newState and hasEquipSpace then
						Notifications:add({text = "Successfully equipped fruit!", color = Color3.fromRGB(0, 255, 0)})
					end
				end)

				-- Mount / Unmount (only fruits with CanMount = true; the server checks everything again)
				local mountBtn = focus:FindFirstChild("MountBtn")
				if mountBtn then
					local focusData = FruitUtility.getData(data, focusUid)
					local focusInfo = focusData and FruitUtility.getInfo(focusData.name)
					local AdminUtility = _L.Get {"Common", "Modules", "Utilities", "AdminUtility"}
					local canMount = focusInfo and focusInfo.CanMount == true and (not focusInfo.admin_only or AdminUtility.isAdmin(_L.Player))
					mountBtn.Visible = canMount and true or false

					local function refreshMount()
						local mounted = _L.Player:GetAttribute("MountedFruit") == focusUid
						local label = mountBtn:FindFirstChild("Text") or mountBtn:FindFirstChild("TextLabel")
						if label then
							label.Text = if mounted then "Unmount" else "Mount"
						end
						mountBtn.BackgroundColor3 = if mounted then Color3.fromRGB(220, 60, 60) else Color3.fromRGB(90, 170, 255)
					end
					refreshMount()
					self._focus.trove:Connect(_L.Player:GetAttributeChangedSignal("MountedFruit"), refreshMount)

					self._focus.trove:Connect(mountBtn.MouseButton1Down, function()
						local success, result = Network.Remote.Invoke("S_Fruits_Mount", focusUid)
						Audio.Play({name = "Equip1", speed = 1.3})
						if not success then
							local reasons = {cannot = "This fruit can't be ridden.", admin = "This fruit is admin only.", dead = "You can't mount right now.", missing = "You don't own this fruit."}
							Notifications:add({text = "❌ " .. (reasons[result] or "Can't mount."), color = Color3.fromRGB(255, 80, 80)})
						elseif result then
							Notifications:add({text = "🏇 Mounted! Walk around to ride your fruit.", color = Color3.fromRGB(120, 230, 120)})
						end
					end)
				end

				-- Delete
				self._focus.trove:Connect(focus.DeleteBtn.MouseButton1Down, function()
					if getOwnedFruitCount(data) <= 1 then
						Notifications:add({text = LAST_FRUIT_TEXT, color = Color3.fromRGB(255, 100, 100)})
						return
					end
					UI.Open({name = "Confirm", props = {
						text = "Are you sure you want to delete this fruit?",
						yes = function()
							local success, reason = Network.Remote.Invoke("S_Fruits_Delete", focusUid)

							if success then
								Notifications:add({text = "Successfully deleted fruit!", color = Color3.fromRGB(0, 255, 0), audio = {name = "Delete1"}})
							elseif reason == "last" then
								Notifications:add({text = LAST_FRUIT_TEXT, color = Color3.fromRGB(255, 100, 100)})
							end
						end,
						no = function() end,
					}})
				end)

				-- Feed: shows how much food you have, each click feeds up to 5 of your best food
				if feedBtn then
					local PlantUtility = _L.Get {"Common", "Modules", "Utilities", "PlantUtility"}
					local feedLabel = feedBtn:FindFirstChildWhichIsA("TextLabel", true)

					self._focus.trove:Add(data:Bind("plants", function(plantsValue)
						local total = 0
						for _, count in pairs(plantsValue or {}) do
							total += count
						end
						if feedLabel then
							feedLabel.Text = "Feed (" .. NumberUtility.commas(total) .. " 🌿)"
						end
					end))

					self._focus.trove:Connect(feedBtn.MouseButton1Down, function()
						local plants = PlantUtility.getOwnedPlants(data)
						if not plants or #plants == 0 then
							Notifications:add({text = "🌿 No food yet! Harvest plants to collect food.", color = Color3.fromRGB(255, 100, 100)})
							return
						end

						-- Find the food with the highest EXP value that the player owns
						local bestPlant = nil
						local bestExp = -1
						for _, plant in ipairs(plants) do
							if plant.count > 0 and plant.exp_value > bestExp then
								bestExp = plant.exp_value
								bestPlant = plant
							end
						end

						if bestPlant then
							local amount = math.min(bestPlant.count, 5)
							local success, info = Network.Remote.Invoke("S_Fruits_Feed", focusUid, bestPlant.name, amount)
							if success then
								local msg = "🍽️ Fed " .. amount .. "x " .. bestPlant.name .. " (+" .. NumberUtility.commas(bestPlant.exp_value * amount) .. " EXP)"
								if info and info.levelsGained and info.levelsGained > 0 then
									msg = msg .. " - Leveled up " .. info.levelsGained .. "x!"
								end
								Notifications:add({text = msg, color = Color3.fromRGB(100, 255, 100), audio = {name = "Equip1"}})
							else
							Notifications:add({text = "Could not feed this fruit!", color = Color3.fromRGB(255, 100, 100)})
						end
						end
					end)
				end

				-- Evolve
				if evolveBtn then
					self._focus.trove:Connect(evolveBtn.MouseButton1Down, function()
						local s = FruitUtility.getSummary(data, focusUid)
						if not s or not s.nextStageName then
							return
						end
						UI.Open({name = "Confirm", props = {
							text = "Evolve into " .. FruitStageUtility.getDisplayName(fruitInfo.display_name or fruitInfo.name, s.stage + 1) .. " for " .. NumberUtility.short(s.evolveCost) .. " Coins? It gets bigger, doubles its boost and can level higher!",
						yes = function()
								local success, info = Network.Remote.Invoke("S_Fruits_Evolve", focusUid)
								if success then
									Notifications:add({text = "✨ Your fruit evolved into " .. (info and info.evolvedTo or "a new form") .. "!", color = Color3.fromRGB(255, 210, 80), audio = {name = "Success2"}})
									-- refresh the detail panel so it shows the new look
									task.defer(function()
										self._focus.tracker:Set(nil)
										self._focus.tracker:Set(focusUid)
									end)
								elseif info == "afford" then
									Notifications:add({text = "❌ You need " .. NumberUtility.short(s.evolveCost - (data:Get({"stats", "Strength"}) or 0)) .. " more Coins to evolve!", color = Color3.fromRGB(255, 80, 80), audio = {name = "Fail1"}})
								else
									Notifications:add({text = "Feed your fruit to the max level first!", color = Color3.fromRGB(255, 100, 100)})
								end
							end,
							no = function() end,
					}})
					end)
				end

				-- Awaken
				if awakenBtn then
					self._focus.trove:Connect(awakenBtn.MouseButton1Down, function()
						UI.Open({name = "Confirm", props = {
							text = "Awaken this fruit? It will gain a massive permanent power boost!",
						yes = function()
								local success, info = Network.Remote.Invoke("S_Fruits_Awaken", focusUid)
								if success then
									Notifications:add({text = "Fruit awakened! Power surged dramatically!", color = Color3.fromRGB(255, 180, 50), audio = {name = "Equip1"}})
								else
									Notifications:add({text = "Cannot awaken this fruit yet!", color = Color3.fromRGB(255, 100, 100)})
								end
							end,
						no = function() end,
					}})
					end)
				end

				pcall(renderFarmBonuses, focus, data, fruitData)

				-- Animate detail panel in
				Spr.Target(focus, 0.8, 5, {
					Position = UDim2.fromScale(0.83, 0.55)
				})

				-- Update equip button text reactively
				self._focus.trove:Add(data:Bind("fruits", function(fruitsValue)
					local _, newFruitData = TableUtility.match(fruitsValue, function(i, v)
						return v.uid == focusUid
					end)

					if newFruitData then
						-- Update equip button
						local equipBtnText = focus.EquipBtn:FindFirstChild("Text") or focus.EquipBtn:FindFirstChild("TextLabel")
						if equipBtnText then
							equipBtnText.Text = if newFruitData.equipped then "Unequip" else "Equip"
						end
						focus.EquipBtn.BackgroundColor3 = if newFruitData.equipped then Color3.fromRGB(220, 60, 60) else Color3.fromRGB(80, 200, 110)

						-- Update level/exp display
						local updatedSummary = FruitUtility.getSummary(data, focusUid)
						if updatedSummary then
							local lvlLabel = focus:FindFirstChild("Level")
							if lvlLabel then
								lvlLabel.Text = "Lv. " .. updatedSummary.level .. " / " .. updatedSummary.maxLevel
							end

							local expBar = focus:FindFirstChild("ExpBar")
							if expBar then
								local fill = expBar:FindFirstChild("Fill")
								local expText = expBar:FindFirstChild("Text")
								if updatedSummary.isMaxLevel then
									if fill then fill.Size = UDim2.new(1, 0, 1, 0) end
									if expText then expText.Text = "MAX LEVEL" end
								else
									local ratio = updatedSummary.expNeeded > 0 and updatedSummary.exp / updatedSummary.expNeeded or 0
									ratio = math.clamp(ratio, 0, 1)
									if fill then fill.Size = UDim2.new(ratio, 0, 1, 0) end
									if expText then expText.Text = updatedSummary.exp .. " / " .. updatedSummary.expNeeded .. " EXP" end
								end
							end

							-- Update evolve/awaken button visibility
							local evBtn = focus:FindFirstChild("EvolveBtn")
							local awBtn = focus:FindFirstChild("AwakenBtn")
							local fdBtn = focus:FindFirstChild("FeedBtn")

							if evBtn then evBtn.Visible = updatedSummary.canEvolve end
							if awBtn then awBtn.Visible = updatedSummary.canAwaken end
							if fdBtn then fdBtn.Visible = not updatedSummary.isMaxLevel end

							-- Update boost text (same growth number the crops use)
							focus.Boost.Text = "🌱 +" .. percent(updatedSummary.boost) .. " Growth"
							pcall(renderFarmBonuses, focus, data, newFruitData)
						end
					end
				end))

				-- Animate grid to make room for detail panel
				Spr.Target(self.object.Main.Middle, 0.8, 5, {
					Position = UDim2.fromScale(0.338, 0.525),
					Size = UDim2.fromScale(0.65, 0.775)
				})

				Spr.Target(self.object.Main.Middle.UIGridLayout, 0.8, 5, {
					CellSize = UDim2.fromScale(0.194, 0.35)
				})
			else
				-- Animate detail panel out
				Spr.Target(focus, 0.8, 5, {
					Position = UDim2.fromScale(1.2, 0.55)
				})

				Spr.Target(self.object.Main.Middle, 0.8, 5, {
					Position = UDim2.fromScale(0.5, 0.525),
					Size = UDim2.fromScale(0.975, 0.775)
				})

				Spr.Target(self.object.Main.Middle.UIGridLayout, 0.8, 5, {
					CellSize = UDim2.fromScale(0.125, 0.35)
				})
			end
		end)

		-- ============================================================
		-- DELETE MODE HANDLERS
		-- ============================================================
		self.object.Main.DeleteBtn.MouseButton1Click:Connect(function()
			if self._mode.tracker:Get() ~= "Delete" and getOwnedFruitCount(data) <= 1 then
				Notifications:add({text = LAST_FRUIT_TEXT, color = Color3.fromRGB(255, 100, 100)})
				return
			end
			self._mode.tracker:Set(if self._mode.tracker:Get() == "Delete" then "Default" else "Delete")
		end)

		self._mode.tracker:Bind(function(modeValue)
			self.object.Main.CancelDeleteBtn.Visible = modeValue == "Delete"
			self.object.Main.ConfirmDeleteBtn.Visible = modeValue == "Delete"

			self.object.Main.DeleteBtn.Visible = modeValue == "Default"
			self.object.Main.EquipBestBtn.Visible = modeValue == "Default"

			if modeValue == "Delete" then
				self._focus.tracker:Set(nil)
				self._selected_fruits:Set({})
			end
		end)

		self._selected_fruits:Bind(function(selected)
			local confirmLabel = self.object.Main.ConfirmDeleteBtn:FindFirstChild("TextLabel")
			if confirmLabel then
				confirmLabel.Text = "Delete (" .. #selected .. ")"
			end
		end)

		self.object.Main.CancelDeleteBtn.MouseButton1Click:Connect(function()
			self._mode.tracker:Set("Default")
		end)

		self.object.Main.ConfirmDeleteBtn.MouseButton1Click:Connect(function()
			local fruitUids = self._selected_fruits:Get()

			if TableUtility.length(fruitUids) <= 0 then
				return
			end

			self._mode.tracker:Set("Default")
			self._selected_fruits:Set({})

			local success, reason = Network.Remote.Invoke("S_Fruits_Delete", fruitUids)

			if success then
				Notifications:add({text = "Successfully deleted all fruits!", color = Color3.fromRGB(0, 255, 0)})
				Audio.Play({name = "Delete1"})
			elseif reason == "last" then
				Notifications:add({text = LAST_FRUIT_TEXT, color = Color3.fromRGB(255, 100, 100)})
			end
		end)

		-- ============================================================
		-- EQUIP BEST HANDLER
		-- ============================================================
		self.object.Main.EquipBestBtn.MouseButton1Click:Connect(function()
			local success, fruitUids = Network.Remote.Invoke("S_Fruits_Equip_Best")

			if success then
				Notifications:add({text = "Successfully equipped best fruits!", color = Color3.fromRGB(0, 255, 0)})
				Audio.Play({name = "EquipBest1"})
			end
		end)

		-- ============================================================
		-- STORAGE/EQUIP SPACE DISPLAY
		-- ============================================================
		Tracker.Subscribe({data:Track({"stats", "Fruit_Storage_Space"}), data:Track("fruits")}, function()
			local fruitsData = data:Get("fruits")
			local storageSpace = data:Get({"stats", "Fruit_Storage_Space"})

			local storageLabel = self.object.Main.Space.Inner.Storage:FindFirstChild("TextLabel")
			if storageLabel then
				storageLabel.Text = TableUtility.length(fruitsData) .. "/" .. storageSpace
			end
		end)

		Tracker.Subscribe({data:Track({"stats", "Fruit_Equip_Space"}), data:Track("fruits")}, function()
			local equipped = TableUtility.filter(data:Get("fruits"), function(i, v)
				return v.equipped
			end)

			local equipSpace = data:Get({"stats", "Fruit_Equip_Space"})

			local equipLabel = self.object.Main.Space.Inner.Equip:FindFirstChild("TextLabel")
			if equipLabel then
				equipLabel.Text = TableUtility.length(equipped) .. "/" .. equipSpace
			end
		end)
	end
end

function Fruits:Open()
	Spr.Stop(self.object.Main)

	self.object.Main.Visible = true
	self.object.Main.Position = UDim2.fromScale(0.5, 0.55)

	Spr.Target(self.object.Main, 1, 4, {
		Position = UDim2.fromScale(0.5, 0.5)
	})

	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 80
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 20
	})
end

function Fruits:Close()
	self.object.Main.Visible = false

	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Fruits