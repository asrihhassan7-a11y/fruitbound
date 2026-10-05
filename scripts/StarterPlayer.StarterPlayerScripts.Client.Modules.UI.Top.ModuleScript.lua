--> Variables
local _L = _G._L

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
local _Stats
local ProgressBar
local Free
local Wheel
local Store
local Notifications
local Settings

--> Constants

------------->
local Top = {
	name = script.Name
}

function Top:_init()
	Network = _L.Get {"Common", "Library", "Network"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
	TableUtility = _L.Get {"Common", "Library", "Utilities", "TableUtility"}
	NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	TrackerUtility = _L.Get {"Common", "Library", "Utilities", "TrackerUtility"}
	AttributeUtility = _L.Get {"Common", "Library", "Utilities", "AttributeUtility"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Audio = _L.Get {"Common", "Library", "Audio"} 
	Shared = _L.Get {"Common", "Modules", "Shared"}
	FastTween = _L.Get {"Common", "Library", "Functions", "FastTween"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
	Constants = _L.Get {"Common", "Modules", "Constants"}
	_Stats = _L.Get {"Common", "Modules", "Databases", "Stats"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	UI = _L.Get {"Client", "Modules", "UI"}
end

function Top:_start()
	Free = UI.Get("Free")
	Wheel = UI.Get("Wheel")
	Store = UI.Get("Store")
	Notifications = UI.Get("Notifications")
	Settings = UI.Get("Settings")
	Season = UI.Get("Season")
	
	self.object = _L.PlayerGui.Main.Top

	local data = Data.Await()

	if data then
		local icon = self.object.Free.Free.Icon

		Timer.Simple(1.5, function()
			Spr.Target(icon, 0.3, 3, {
				Rotation = 15
			})

			task.wait(0.175)

			Spr.Target(icon, 0.3, 3, {
				Rotation = -10
			})

			task.wait(0.175)

			Spr.Target(icon, 0.3, 3, {
				Rotation = 7
			})

			task.wait(0.125)

			Spr.Target(icon, 0.3, 3, {
				Rotation = 0
			})
		end)
		
		for _, statFrame in pairs(self.object.Stats:GetChildren()) do
			if statFrame:IsA("ImageLabel") then
				local statName = statFrame.Name
				local trove = Trove.new()
				local onGain = self:_style_currency(statFrame)
				local lastValue

				data:Bind({"stats", statName}, function(value)
					trove:Clean()
					if onGain and lastValue and (value or 0) > lastValue then
						onGain()
					end
					lastValue = value or 0

					statFrame.Number.Text = NumberUtility.short(value or 0)

					Spr.Target(statFrame.UIScale, 0.4, 6, {
						Scale = 1.1
					})

					trove:Add(cancellableDelay(0.05, function()
						Spr.Target(statFrame.UIScale, 0.8, 12, {
							Scale = 1
						})
					end))
				end)
				
				statFrame.Buy.MouseButton1Down:Connect(function()
					UI.Open({name = "Store", props = {
						subject = statName
					}})
				end)
			end
		end
		
		-- compact harvest chip: "🌾 HARVEST 42%" (no extra lines of text under it)
		local bar = self.object.ProgressBar
		bar.Size = UDim2.fromScale(0.25, 0.17)
		bar.Position = UDim2.fromScale(0.5, 0.575)
		bar.ProgressText.Size = UDim2.fromScale(0.92, 0.86)
		local textLimit = bar.ProgressText:FindFirstChildOfClass("UITextSizeConstraint")
		if textLimit then
			textLimit.MaxTextSize = 20
		end
		self.object.ProgressLabelText.Visible = false
		bar.Visible = false
		local progressBar = ProgressBar.new({instance = bar, format = function(n1, n2)
			return "🌾 HARVEST  "..math.floor((n1 / n2) * 100).."%"
		end,})

		local lastWeaponInfo = nil

		data:Bind({"stats", "Strength"}, function(value)
			local currentPowerInfo = Shared.GetCurrentPowerInfoFromStrength(value)
			local nextPowerInfo = Shared.GetNextPowerInfoFromStrength(value)

			if lastWeaponInfo and currentPowerInfo and lastWeaponInfo.name ~= currentPowerInfo.name and lastWeaponInfo.strength <= currentPowerInfo.strength and data:Get({"settings", "Popups"}) then
				Notifications:add({text = "🌾 HARVEST MILESTONE! Your garden reached a new harvest level!", color = Color3.fromRGB(150, 255, 120), duration = 3, audio = {name = "Progress1"}})
				pcall(function()
					progressBar:Shine({})
				end)
				Network.Bindable.Fire("C_Character_LevelUp")
			end

			lastWeaponInfo = currentPowerInfo

			if nextPowerInfo then
				progressBar:Set({value, nextPowerInfo.required})
			else
				progressBar:Set({100, 100})
			end
		end)
	end
	
	local og = self.object.Position

	UI._current:Bind(function(value)
		-- the permanent HARVEST bar is retired: milestones are shown as notifications instead
		self.object.ProgressBar.Visible = false
		self.object.ProgressLabelText.Visible = false
	end)
end

--[[

<font color= "rgb(255, 255, 255)"><font color= "rgb(0, 255, 0)">Deathmatch!</font>: Killing people gives you some of their gems for 5 minutes.</font>
]]
-- ============================================================
-- CURRENCY HUD LOOK (presentation only; values and Store wiring untouched)
--   Strength chip = Coins: warm gold / cream.  Gems chip: cool cyan, soft glow.
-- ============================================================
local CURRENCY_STYLES = {
	Strength = {
		chip = Color3.fromRGB(255, 238, 196),
		icon = Color3.fromRGB(255, 203, 64),
		text = Color3.fromRGB(122, 74, 18),
		textStroke = Color3.fromRGB(255, 248, 228),
		shine = Color3.fromRGB(255, 250, 215),
	},
	Gems = {
		chip = Color3.fromRGB(214, 242, 255),
		icon = Color3.fromRGB(86, 206, 255),
		text = Color3.fromRGB(22, 82, 132),
		textStroke = Color3.fromRGB(240, 251, 255),
		shine = Color3.fromRGB(225, 250, 255),
		glow = Color3.fromRGB(120, 225, 255),
	},
}

-- styles one currency chip; returns the gain feedback function (icon pulse + one shine sweep)
function Top:_style_currency(statFrame)
	local style = CURRENCY_STYLES[statFrame.Name]
	local icon = statFrame:FindFirstChild("Icon")
	if not style or not icon then
		return nil
	end

	statFrame.ImageColor3 = style.chip
	local chipGradient = statFrame:FindFirstChild("ChipShade") or Instance.new("UIGradient")
	chipGradient.Name = "ChipShade"
	chipGradient.Rotation = 90
	chipGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(232, 222, 205))
	chipGradient.Parent = statFrame

	local number = statFrame:FindFirstChild("Number")
	if number then
		number.TextColor3 = style.text
		local st = number:FindFirstChildOfClass("UIStroke")
		if st then
			st.Color = style.textStroke
			st.Thickness = math.max(st.Thickness, 2)
		end
	end

	-- bigger, clearer icon
	icon.Size = UDim2.fromScale(icon.Size.X.Scale * 1.18, icon.Size.Y.Scale * 1.18)
	icon.ImageColor3 = style.icon
	icon.ZIndex = math.max(icon.ZIndex, 3)

	if style.glow then
		local glow = Instance.new("ImageLabel")
		glow.Name = "IconGlow"
		glow.BackgroundTransparency = 1
		glow.Image = icon.Image
		glow.ImageColor3 = style.glow
		glow.ImageTransparency = 0.55
		glow.ScaleType = icon.ScaleType
		glow.AnchorPoint = icon.AnchorPoint
		glow.Position = icon.Position
		glow.Size = UDim2.fromScale(icon.Size.X.Scale * 1.25, icon.Size.Y.Scale * 1.25)
		glow.ZIndex = icon.ZIndex - 1
		glow.Parent = statFrame
		-- keep the glow centered on the icon (icon is anchored at its right edge)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.new(icon.Position.X.Scale - icon.Size.X.Scale * (icon.AnchorPoint.X - 0.5), 0, icon.Position.Y.Scale, 0)
	end

	-- shine: a light band that sweeps across the icon once per gain
	local shine = Instance.new("UIGradient")
	shine.Name = "Shine"
	shine.Rotation = 25
	shine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.5, style.shine),
		ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	shine.Offset = Vector2.new(-1, 0)
	shine.Parent = icon

	local pulse = icon:FindFirstChild("PulseScale") or Instance.new("UIScale")
	pulse.Name = "PulseScale"
	pulse.Parent = icon

	local lastGain = 0
	return function()
		local now = os.clock()
		if now - lastGain < 0.35 then
			return -- no constant animation spam while values tick up fast
		end
		lastGain = now
		pulse.Scale = 1.22
		Spr.Target(pulse, 0.5, 5, {Scale = 1})
		shine.Offset = Vector2.new(-1, 0)
		Services.TweenService:Create(shine, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Offset = Vector2.new(1, 0)}):Play()
	end
end

return Top