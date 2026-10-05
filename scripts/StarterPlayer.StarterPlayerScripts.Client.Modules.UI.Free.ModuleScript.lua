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
local FreeGiftUtility
local FreeGifts

--> Constants

------------->
local Free = {
	name = script.Name
}

function Free:_init()
	Services = _L.Get {"Common", "Library", "Services"}
	Network = _L.Get {"Common", "Library", "Network"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Data = _L.Get {"Client", "Library", "Classes", "Data"}
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
	FreeGifts = _L.Get {"Common", "Modules", "Databases", "FreeGifts"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	FreeGiftUtility = _L.Get {"Common", "Modules", "Utilities", "FreeGiftUtility"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Free:_start()
	self.object = _L.PlayerGui.Free
	self._available = Tracker.new(0)
	
	self._available:Bind(function()
		Audio.Play({name = "Ding1"})
	end)
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	AttributeUtility.waitFor(_L.Player, "free_gifts")
	
	self._instances = {}

	for _, freeGiftInfo in pairs(FreeGifts) do
		local freeGiftId = freeGiftInfo.id

		local freeGiftInstance = self.object.Main.Rewards:FindFirstChild(freeGiftId)

		self._instances[freeGiftId] = freeGiftInstance

		local playerRewardInfo = PlayerRewardUtility.getInfo(freeGiftInfo.reward_name).getInfo(freeGiftInfo.name)

		freeGiftInstance.LayoutOrder = freeGiftId

		if playerRewardInfo then
			freeGiftInstance.Reward.Image = playerRewardInfo.image
			freeGiftInstance.Reward.Amount.Text = "x"..NumberUtility.short(freeGiftInfo.value)

			freeGiftInstance.ClaimBtn.MouseButton1Down:Connect(function()
				local success, freeGiftReward = Network.Remote.Invoke("S_Free_Gifts_Claim", freeGiftId)

				if success then
					UI.Open({name = "Reward", props = {
						data = freeGiftReward
					}})
				end
			end)
		end

		TrackerUtility.fromAttributeSignal(_L.Player, "last_free_gift"):Bind(function(value)
			self:_render()
		end)
	end

	Timer.Simple(0.5, function()
		self:_render()
	end)
end

function Free:_render()
	local value = AttributeUtility.get(_L.Player, "free_gifts")
	local i = 0
	local t = {}
	
	for freeGiftId, freeGiftInstance in pairs(self._instances) do
		if value[freeGiftId] then
			freeGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(160, 0, 160)
			freeGiftInstance.ClaimBtn.TextLabel.Text = "CLAIMED"
		else
			local canClaim = FreeGiftUtility.canClaim(_L.Player, freeGiftId)
			
			if canClaim then
				freeGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(203, 0, 246)
				freeGiftInstance.ClaimBtn.TextLabel.Text = "REDEEM"
				
				i += 1
			else
				local timeLeft = FreeGiftUtility.getTimeLeft(_L.Player, freeGiftId)
				
				table.insert(t, timeLeft)
				
				freeGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(20, 175, 0)
				freeGiftInstance.ClaimBtn.TextLabel.Text = NumberUtility.timer.short.auto(timeLeft)
			end
		end
	end
	
	local _, tt = TableUtility.min(t, function(i, v)
		return v
	end)
	
	self._available:Set(i)
	
	if tt then
		_L.PlayerGui.Main.Top.Free.Visible = true
		_L.PlayerGui.Main.Top.Free.Counter.Number.Text = if i > 0 then "x"..i else NumberUtility.timer.colon.minutes(tt)
	else
		_L.PlayerGui.Main.Top.Free.Visible = false
	end
end
	
function Free:Open()
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
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = false end
end

function Free:Close()
	self.object.Main.Visible = false
	

	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = true end
end

return Free