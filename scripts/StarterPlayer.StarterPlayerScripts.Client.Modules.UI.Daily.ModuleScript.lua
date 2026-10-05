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
local DailyGiftUtility
local DailyGifts

--> Constants

------------->
local Daily = {
	name = script.Name
}

function Daily:_init()
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
	DailyGifts = _L.Get {"Common", "Modules", "Databases", "DailyGifts"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	DailyGiftUtility = _L.Get {"Common", "Modules", "Utilities", "DailyGiftUtility"}
	Icon = _L.Get {"Client", "Modules", "Icon"}

	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Daily:_start()
	self.object = _L.PlayerGui.Daily
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()
	
	if data then
		_L.PlayerGui.Main.Left.Content.Daily.MouseButton1Down:Connect(function()
			Audio.Play({name = "Plop1"})
			UI.Toggle({name = self.name})
			UI.Close({name = "Settings"})
		end)
		
		self._instances = {}
		
		for _, dailyGiftInfo in pairs(DailyGifts) do
			local dailyGiftId = dailyGiftInfo.id

			local dailyGiftInstance = self.object.Main:FindFirstChild(dailyGiftId) or self.object.Main.Rewards:FindFirstChild(dailyGiftId)
			
			if dailyGiftId == 7 then
				dailyGiftInstance = dailyGiftInstance.Main
			end
			
			self._instances[dailyGiftId] = dailyGiftInstance
			
			local playerRewardInfo = PlayerRewardUtility.getInfo(dailyGiftInfo.reward_name).getInfo(dailyGiftInfo.name)
			
			dailyGiftInstance.LayoutOrder = dailyGiftId
			
			if playerRewardInfo then
				dailyGiftInstance.Reward.Image = playerRewardInfo.image or playerRewardInfo.icon
				
				if dailyGiftInstance.Reward:FindFirstChild("Amount") then
					dailyGiftInstance.Reward.Amount.Text = "x"..NumberUtility.short(dailyGiftInfo.value)
				end
			end
			
			dailyGiftInstance.ClaimBtn.MouseButton1Down:Connect(function()
				local success, dailyGiftReward = Network.Remote.Invoke("S_Daily_Gifts_Claim", dailyGiftId)
				
				if success then
					UI.Open({name = "Reward", props = {
						data = dailyGiftReward
					}})
				end
			end)
			
			data:Bind("last_daily_gift", function(value)
				self:_render(data)
			end)
		end
		
		Timer.Simple(0.5, function()
			self:_render(data)
		end)
		
		UI.Open({name = self.name})
	end
end

function Daily:_render(data)
	local value = data:Get("last_daily_gift")
	
	for dailyGiftId, dailyGiftInstance in pairs(self._instances) do
		local nextDailyGiftId = DailyGiftUtility.getNextId(data)

		if value.i and value.i >= dailyGiftId then
			dailyGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(160, 0, 160)
			dailyGiftInstance.ClaimBtn.TextLabel.Text = "CLAIMED"
		elseif dailyGiftId == nextDailyGiftId then
			local canClaim = DailyGiftUtility.canClaim(data, dailyGiftId)
			
			if canClaim then
				dailyGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(203, 0, 246)
				dailyGiftInstance.ClaimBtn.TextLabel.Text = "REDEEM"
			else
				local timeLeft = DailyGiftUtility.getTimeLeft(data)
				
				dailyGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(20, 175, 0)
				dailyGiftInstance.ClaimBtn.TextLabel.Text = NumberUtility.timer.colon.hours(timeLeft)
			end
		else
			dailyGiftInstance.ClaimBtn.ImageColor3 = Color3.fromRGB(20, 175, 0)
			dailyGiftInstance.ClaimBtn.TextLabel.Text = "DAY "..dailyGiftId
		end
	end
end
	
function Daily:Open()
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

function Daily:Close()
	self.object.Main.Visible = false
	

	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Daily