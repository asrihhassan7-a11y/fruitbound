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
local Purchases
local Icon
local Notifications
local SeasonUtility
local Reward
local PlayerRewardUtility

--> Constants

------------->
local Season = {
	name = script.Name
}

function Season:_init()
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
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
	Icon = _L.Get {"Client", "Modules", "Icon"}
	SeasonUtility = _L.Get {"Common", "Modules", "Utilities", "SeasonUtility"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Season:_start()
	Notifications = UI.Get("Notifications")
	Reward = UI.Get("Reward")
	
	self.object = _L.PlayerGui.Season
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()
	
	self._instances = {}
	
	if data then
		local nextTierInfo
		
		local newProgressBar = ProgressBar.new({instance = self.object.Main.Bottom.ProgressBar, format = function(n1, n2)
			return if nextTierInfo then NumberUtility.short(math.floor(n1)).." / "..NumberUtility.short(math.floor(n2)).." Coins" else "MAX TIER"
		end})
		
		local currentSeasonInfo = SeasonUtility.getCurrentInfo()
		local currentSeasonId = currentSeasonInfo.id
		
		for tierIndex, tierInfo in pairs(currentSeasonInfo.tiers) do
			local newTierCell = _L.Assets.UI.Season.Cell:Clone()
			
			local freeReward = unpack(tierInfo.free)
			local premiumReward = unpack(tierInfo.premium)
			
			self:project(newTierCell.Free, freeReward)
			self:project(newTierCell.Premium, premiumReward)
			
			newTierCell.Free.Claim.MouseButton1Down:Connect(function()
				Network.Remote.Fire("S_Season_Claim", "Free", tierInfo.id)
			end)
			
			newTierCell.Premium.Claim.MouseButton1Down:Connect(function()
				Network.Remote.Fire("S_Season_Claim", "Premium", tierInfo.id)
			end)
			
			newTierCell.Number.TextLabel.Text = tierIndex
			newTierCell.LayoutOrder = tierIndex
			newTierCell.Parent = self.object.Main.Main.Container
			
			self._instances[tierIndex] = {
				instance = newTierCell,
				info = tierInfo,
				index = tierIndex
			}
		end
		
		Tracker.Subscribe({data:Track({"seasons", currentSeasonId})}, function()
			local currentSeasonData = data:Get({"seasons", currentSeasonId})
			local currentStrength = currentSeasonData.total_strength_gained
			
			local ownsPremium = currentSeasonData.owns_premium
			local premium = currentSeasonData.premium
			local free = currentSeasonData.free
			
			local _, highestTier = TableUtility.max(ArrayUtility.filter(currentSeasonInfo.tiers, function(i, v) return v.required <= currentStrength or table.find(currentSeasonData.skipped, v.id) end), function(i, v)
				return v.required
			end)
			
			for tierIndex, tier in pairs(self._instances) do
				local tierInfo = currentSeasonInfo.tiers[tierIndex]
				
				local claimedFree = table.find(free, tierIndex)
				local claimedPremium = table.find(premium, tierIndex)
				
				if ownsPremium then
					if tierInfo.required <= currentStrength or table.find(currentSeasonData.skipped, tierInfo.id) then
						if claimedPremium then
							tier.instance.Premium.Skip_Tier.Visible = false
							tier.instance.Premium.Claim.Visible = false
							tier.instance.Premium.ImageLabel.Locked.Checkmark.Visible = true
							tier.instance.Premium.ImageLabel.Locked.Lock.Visible = false
							tier.instance.Premium.ImageLabel.Locked.Visible = true
						else
							tier.instance.Premium.Skip_Tier.Visible = false
							tier.instance.Premium.Claim.Visible = true
							tier.instance.Premium.ImageLabel.Locked.Checkmark.Visible = false
							tier.instance.Premium.ImageLabel.Locked.Lock.Visible = false
							tier.instance.Premium.ImageLabel.Locked.Visible = false
						end
					else
						tier.instance.Premium.Claim.Visible = false
						tier.instance.Premium.Skip_Tier.Visible = tier.info.id == (if highestTier then highestTier.id else 0) + 1
						tier.instance.Premium.ImageLabel.Locked.Checkmark.Visible = false
						tier.instance.Premium.ImageLabel.Locked.Lock.Visible = true
						tier.instance.Premium.ImageLabel.Locked.Visible = true
					end
				else
					tier.instance.Premium.Skip_Tier.Visible = false
					if tierInfo.required <= currentStrength or table.find(currentSeasonData.skipped, tierInfo.id) then
						tier.instance.Premium.Claim.Visible = true
					else
						tier.instance.Premium.Claim.Visible = false
					end
					tier.instance.Premium.ImageLabel.Locked.Checkmark.Visible = false
					tier.instance.Premium.ImageLabel.Locked.Lock.Visible = false
					tier.instance.Premium.ImageLabel.Locked.Visible = false
				end
				
				if tierInfo.required <= currentStrength or table.find(currentSeasonData.skipped, tierInfo.id) then
					if claimedFree then
						tier.instance.Free.Skip_Tier.Visible = false
						tier.instance.Free.Claim.Visible = false
						tier.instance.Free.ImageLabel.Locked.Checkmark.Visible = true
						tier.instance.Free.ImageLabel.Locked.Lock.Visible = false
						tier.instance.Free.ImageLabel.Locked.Visible = true
					else
						tier.instance.Free.Skip_Tier.Visible = false
						tier.instance.Free.Claim.Visible = true
						tier.instance.Free.ImageLabel.Locked.Checkmark.Visible = false
						tier.instance.Free.ImageLabel.Locked.Lock.Visible = false
						tier.instance.Free.ImageLabel.Locked.Visible = false
					end
				else
					tier.instance.Free.Claim.Visible = false
					tier.instance.Free.Skip_Tier.Visible = tier.info.id == ((if highestTier then highestTier.id else 0)) + 1
					tier.instance.Free.ImageLabel.Locked.Checkmark.Visible = false
					tier.instance.Free.ImageLabel.Locked.Lock.Visible = true
					tier.instance.Free.ImageLabel.Locked.Visible = true
				end
			end
			
			nextTierInfo = currentSeasonInfo.tiers[(if highestTier then highestTier.id else 0) + 1]
			
			self.object.Main.Bottom.ProgressBar.Current.TextLabel.Text = (if highestTier then highestTier.id else 0)

			if nextTierInfo then
				newProgressBar:Set({currentStrength, nextTierInfo.required})
				self.object.Main.Bottom.Season_Unlock_All_Tiers.Visible = true
				self.object.Main.Bottom.ProgressBar.Size = UDim2.fromScale(0.566, 0.741)
				self.object.Main.Bottom.ProgressBar.Next.TextLabel.Text = nextTierInfo.id
				self.object.Main.Bottom.ProgressBar.Next.Visible = true
			else
				newProgressBar:Set({1, 1})
				self.object.Main.Bottom.Season_Unlock_All_Tiers.Visible = false
				self.object.Main.Bottom.ProgressBar.Size = UDim2.fromScale(0.898, 0.741)
				self.object.Main.Bottom.ProgressBar.Next.Visible = false
			end
			
			self.object.Main.PremiumRequired.Visible = not ownsPremium
			
			if ownsPremium then
				self.object.Main.Season_Premium.Visible = false
				self.object.Main.PremiumIcon.Position = UDim2.fromScale(0.095, 0.3)
			else
				self.object.Main.Season_Premium.Visible = true
				self.object.Main.PremiumIcon.Position = UDim2.fromScale(0.095, 0.262)
			end
		end)
		
		TrackerUtility.fromPropertySignal(self.object.Main.PremiumRequired.Time.T, "Value"):Bind(function(value)
			self.object.Main.PremiumRequired.Time.Text = [[<stroke color= "rgb(0, 0, 0)" joins="round" thickness="2" transparency="]]..value..[[">Activate <font color= "rgb(255, 255, 0)">PREMIUM</font> to unlock more rewards! </stroke>]]
		end)
		
		self.object.Main.PremiumRequired.MouseEnter:Connect(function()
			Spr.Target(self.object.Main.PremiumRequired.Time, 1, 5, {
				TextTransparency = 1
			})
			
			Spr.Target(self.object.Main.PremiumRequired.Time.T, 1, 5, {
				Value = 1
			})
			
			Spr.Target(self.object.Main.PremiumRequired, 1, 5, {
				BackgroundTransparency = 1
			})
		end)
		
		self.object.Main.PremiumRequired.MouseLeave:Connect(function()
			Spr.Target(self.object.Main.PremiumRequired.Time, 1, 5, {
				TextTransparency = 0
			})
			
			Spr.Target(self.object.Main.PremiumRequired.Time.T, 1, 5, {
				Value = 0
			})
			
			Spr.Target(self.object.Main.PremiumRequired, 1, 5, {
				BackgroundTransparency = 0.4
			})
		end)
		
		self.object.Main.PremiumRequired.MouseButton1Down:Connect(function()
			Purchases.PromptProduct("Season_Premium")
		end)
		
		Timer.Simple(0.5, function()
			self.object.Main.Time.Text = [[<stroke color= "rgb(0, 0, 0)" joins="round" thickness="2" transparency="0">Season ends in <font color= "rgb(0, 255, 0)">]]..NumberUtility.timer.short.auto(math.max(Constants.SEASON_DURATION - (os.time() - Constants.SEASON_START_TIME), 0))..[[</font> </stroke>]]
		end)
	end
end

function Season:project(instance, reward)
	local playerRewardInfo = PlayerRewardUtility.getInfo(reward.name).getInfo(reward.props.name)

	instance.ImageLabel.Quantity.Text = (if reward.name ~= "Stat" and reward.props.value then ("x"..NumberUtility.short(reward.props.value).." ") else "")
	instance.ImageLabel.TextLabel.Text = (if reward.name == "Stat" and reward.props.value then ("+"..NumberUtility.short(reward.props.value).." ") else "")..(playerRewardInfo.display_name or playerRewardInfo.name)
	instance.ImageLabel.ImageLabel.Image = playerRewardInfo.image or playerRewardInfo.icon
end

function Season:Open()
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

function Season:Close()
	
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Season