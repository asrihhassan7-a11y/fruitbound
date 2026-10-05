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
local ArrayUtility
local UI
local Network
local PlayerRewardUtility
local WheelRewardUtility
local Purchases

--> Constants

------------->
local Wheel = {
	name = script.Name
}

function Wheel:_init()
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
	WheelRewards = _L.Get {"Common", "Modules", "Databases", "WheelRewards"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	WheelRewardUtility = _L.Get {"Common", "Modules", "Utilities", "WheelRewardUtility"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
	self._is_spinning = Tracker.new(false)
end

function Wheel:_start()
	self.object = _L.PlayerGui.Wheel
	local function applyLayout()
		local viewport = workspace.CurrentCamera.ViewportSize
		local width = math.min(820, viewport.X - 32)
		local height = math.min(650, viewport.Y - 24)
		self.object.Main.Size = UDim2.fromOffset(width, height)
		local diameter = math.min(height - 100, width * 0.5)
		self.object.Main.Background.Size = UDim2.fromOffset(diameter, diameter)
	end
	applyLayout()
	self.trove:Add(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout))
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local function spinBtn()
		if self._is_spinning:Get() then
			return
		end
		-- lock BEFORE asking the server, so a double click can't use two spins
		self._is_spinning:Set(true)

		local callSuccess, success, err, spinReward, spinId = pcall(Network.Remote.Invoke, "S_Wheel_Spin_Request")
		if not callSuccess then
			success = false
			err = "connection"
		end

		if success and spinReward then
			self:_spin({reward = spinReward, id = spinId})
			return
		end
		self._is_spinning:Set(false)

		if err == "notenough" then
			local left = WheelRewardUtility.getTimeLeft(_L.Player)
			pcall(function()
				UI.Get("Notifications"):add({
					text = if left and left > 0 then "⏳ No spins left - next free spin in " .. NumberUtility.timer.colon.minutes(left) else "⏳ No spins left",
					color = Color3.fromRGB(255, 190, 70),
					duration = 2,
				})
			end)
		end
	end
	
	self.object.Main.Background.SpinBtn.MouseButton1Down:Connect(spinBtn)
	self.object.Main.SpinBtn.MouseButton1Down:Connect(spinBtn)

	for _, wheelRewardInfo in pairs(WheelRewards) do
		local wheelRewardId = wheelRewardInfo.id
		
		local wheelRewardInstance = self.object.Main.Background.Inner:FindFirstChild(wheelRewardId)
		local playerRewardInfo = PlayerRewardUtility.getInfo(wheelRewardInfo.reward_name).getInfo(wheelRewardInfo.name)
		
		if playerRewardInfo then
			wheelRewardInstance.ImageLabel.Image = playerRewardInfo.image or ""
			if wheelRewardInstance.ImageLabel.Image == "" then
				-- rewards without an icon (Seeds, Seed Packs, Eggs) show an emoji on the slice
				local emoji = Instance.new("TextLabel")
				emoji.Name = "RewardEmoji"
				emoji.BackgroundTransparency = 1
				emoji.Size = UDim2.fromScale(1, 1)
				emoji.TextScaled = true
				emoji.Font = Enum.Font.FredokaOne
				emoji.Text = ({Seed = "\u{1F331}", SeedPack = "\u{1F4E6}", Egg = "\u{1F95A}"})[wheelRewardInfo.reward_name] or "\u{1F381}"
				emoji.Parent = wheelRewardInstance.ImageLabel
			end
			wheelRewardInstance.Chance.Text = wheelRewardInfo.chance.."%"
			local oldName = wheelRewardInstance:FindFirstChild("TextLabel")
			if oldName then
				oldName.Visible = false
			end
			local row = Instance.new("TextLabel")
			row.Name = "Reward_" .. wheelRewardId
			row.LayoutOrder = wheelRewardId
			row.Size = UDim2.new(1, -8, 0, 38)
			row.BorderSizePixel = 0
			row.BackgroundColor3 = if wheelRewardId % 2 == 0 then Color3.fromRGB(234, 244, 218) else Color3.fromRGB(255, 246, 226)
			row.TextColor3 = Color3.fromRGB(90, 65, 35)
			row.Font = Enum.Font.FredokaOne
			row.TextScaled = true
			row.Text = NumberUtility.short(wheelRewardInfo.value) .. " " .. (wheelRewardInfo.display_name or playerRewardInfo.display_name or playerRewardInfo.name) .. " · " .. wheelRewardInfo.chance .. "%"
			row.Parent = self.object.Main.RewardList
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = 18
			limit.Parent = row
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 8)
			padding.PaddingRight = UDim.new(0, 8)
			padding.Parent = row
		end
	end
	
	local data = Data.Await()
	
	if data then
		data:Bind({"stats", "Wheel_Spin"}, function(value)
			self:_render(data)
		end)
		
		Timer.Simple(0.5, function()
			self:_render(data)
		end)
		
		AttributeUtility.waitFor(_L.Player, "last_wheel_time")
		
		TrackerUtility.fromAttributeSignal(_L.Player, "last_wheel_time"):Bind(function(value)
			self:_render(data)
		end)
	end
	
	for _, v in pairs(self.object.Main.Products:GetChildren()) do
		v.MouseButton1Down:Connect(function()
			UI.Open({name = "Store", props = {
				subject = "WheelSpins",
				subject_callback = function()
					Purchases.PromptProduct(v.Name)
				end,
			}})
		end)
	end
end

function Wheel:_render(data)
	local currentWheelSpins = data:Get({"stats", "Wheel_Spin"})
	self.object.Main.Available.Text = tostring(currentWheelSpins) .. " spins available"
	self.object.Main.SpinBtn.ImageColor3 = if self._is_spinning:Get() then Color3.fromRGB(150, 169, 131) elseif currentWheelSpins > 0 then Color3.fromRGB(130, 190, 90) else Color3.fromRGB(181, 169, 141)
	
	self.object.Main.SpinBtn.Quantity.Text = if currentWheelSpins <= 0 then "" else "x"..currentWheelSpins
	-- clear state: "SPIN" when you have spins, "⏳ 05:42" countdown when you don't
	local tl = _L.Player:GetAttribute("last_wheel_time") and WheelRewardUtility.getTimeLeft(_L.Player)
	if currentWheelSpins > 0 then
		self.object.Main.SpinBtn.TextLabel.Text = if self._is_spinning:Get() then "SPINNING..." else "🎡 SPIN!"
	else
		self.object.Main.SpinBtn.TextLabel.Text = if tl then "⏳ " .. NumberUtility.timer.colon.minutes(math.max(tl, 0)) else "⏳"
	end
	_L.PlayerGui.Main.Top.Wheel.Counter.Number.Text = if currentWheelSpins > 0 then "x" .. currentWheelSpins elseif tl then NumberUtility.timer.colon.minutes(math.max(tl, 0)) else "x0"
	do return end
	_L.PlayerGui.Main.Top.Wheel.Counter.Number.Text = "x"..currentWheelSpins
	
	local wheelTimeLeft
	
	if _L.Player:GetAttribute("last_wheel_time") then
		wheelTimeLeft = WheelRewardUtility.getTimeLeft(_L.Player)
	end
	
	if wheelTimeLeft then
		self.object.Main.SpinBtn.TextLabel.Text = "SPIN ".."("..NumberUtility.timer.colon.minutes(wheelTimeLeft)..")"
		
		if currentWheelSpins <= 0 then
			_L.PlayerGui.Main.Top.Wheel.Counter.Number.Text = NumberUtility.timer.colon.minutes(wheelTimeLeft)
		end
	else
		self.object.Main.SpinBtn.TextLabel.Text = "SPIN"
		_L.PlayerGui.Main.Top.Wheel.Counter.Number.Text = "x"..currentWheelSpins
	end
end

function Wheel:_spin(props)
	task.spawn(function()
		local spinReward = props.reward
		local spinId = props.id

		local wheelRewardId = spinReward.id

		local wheelRewardInfo = WheelRewardUtility.getInfo(wheelRewardId)

		self._is_spinning:Set(true)
		
		local inner = self.object.Main.Background.Inner
		local offset = (8 - wheelRewardId + 1) * 45
		-- small random landing inside the slice so it doesn't always stop dead-centre (stays well inside it)
		local jitter = (math.random() - 0.5) * 20
		inner.Rotation = inner.Rotation % 360
		pcall(Audio.Play, {name = "UI_Open"})
		
		-- soft tick each time a slice passes the pointer (throttled so it's never noisy)
		local ticking = true
		task.spawn(function()
			local lastSlice = math.floor(inner.Rotation / 45)
			local lastTick = 0
			while ticking do
				local slice = math.floor(inner.Rotation / 45)
				if slice ~= lastSlice and os.clock() - lastTick > 0.07 then
					lastSlice = slice
					lastTick = os.clock()
					pcall(Audio.Play, {name = "UI_Hover"})
				end
				task.wait()
			end
		end)
		FastTween(inner, {
			Rotation = (360 * 5) + offset + jitter
		}, {5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out}).Completed:Wait()
		ticking = false
		inner.Rotation = offset + jitter
		
		-- winner: gold outline + little pop on the slice that won
		local slice = inner:FindFirstChild(tostring(wheelRewardId))
		if slice then
			local glow = Instance.new("UIStroke")
			glow.Color = Color3.fromRGB(255, 215, 80)
			glow.Thickness = 4
			glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			glow.Parent = slice
			local sc = slice:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			sc.Parent = slice
			sc.Scale = 1
			game:GetService("TweenService"):Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 1, true), {Scale = 1.18}):Play()
			task.delay(1.6, function()
				glow:Destroy()
			end)
		end
		pcall(Audio.Play, {name = "Coin"})
		task.wait(0.45)
		
		local confirmed, success, given = pcall(Network.Remote.Invoke, "S_Wheel_Spin_Confirm", spinId)
		
		if confirmed and success then
			if UI._current:Get() == self.name then
				UI.Open({
					name = "Reward", 
					props = {
						-- the server sends what was really given (rolled Seeds, hatched Fruit...)
						data = if typeof(given) == "table" and #given > 0 then given else {
							{
								reward_name = wheelRewardInfo.reward_name,
								name = wheelRewardInfo.name,
								value = wheelRewardInfo.value
							}
						}
					}
				})
			end
		end
		
		self._is_spinning:Set(false)
	end)
end

function Wheel:Open()
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

function Wheel:Close()
	self.object.Main.Visible = false
	
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})
	
	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Wheel