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
local Notifications
local Purchases
local StatUtility
local ProgressBar

--> Constants

------------->
local Cases = {
	name = script.Name
}

function Cases:_init()
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
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	StatUtility = _L.Get {"Common", "Modules", "Utilities", "StatUtility"}
	Purchases = _L.Get {"Client", "Library", "Classes", "Purchases"}
	CaseUtility = _L.Get {"Common", "Modules", "Utilities", "CaseUtility"}
	PlayerRewardUtility = _L.Get {"Common", "Modules", "Utilities", "PlayerRewardUtility"}
	RandomUtility = _L.Get {"Common", "Library", "Utilities", "RandomUtility"}
	DailyCaseUtility = _L.Get {"Common", "Modules", "Utilities", "DailyCaseUtility"}
	PremiumCaseUtility = _L.Get {"Common", "Modules", "Utilities", "PremiumCaseUtility"}
	self.is_open = Tracker.new(false)
	self._content_trove = Trove.new()
	self._is_spinning = {tracker = Tracker.new(false), trove = Trove.new()}
end

function Cases:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.InviteRewards
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	self._instances = {}
	
	local data = Data.Await()
	
	if data then
		for _, caseInstance in pairs(self.object.Main.Container:GetChildren()) do
			if caseInstance:IsA("Frame") then
				local caseId = tonumber(caseInstance.Name)
				local caseInfo = CaseUtility.getInfo(caseId)
				
				self._instances[caseId] = {
					id = caseId,
					info = caseInfo,
					instance = caseInstance
				}
				
				caseInstance.Main.Button.MouseButton1Down:Connect(function()
					if self._is_spinning.tracker:Get() then
						return
					end
					
					local success, rewardId, spinId = Network.Remote.Invoke("S_Cases_Open", caseId)
					
					if success and rewardId and spinId then
						self:_spin({
							case_id = caseId,
							reward_id = rewardId,
							spin_id = spinId
						})
					end
				end)
				
				caseInstance.Main.Icon.MouseButton1Down:Connect(function()
					self:_content(caseId)
				end)
				
				caseInstance.Main.Icon.MouseEnter:Connect(function()
					caseInstance.Main.Icon.Dark.Visible = true
				end)
				
				caseInstance.Main.Icon.MouseLeave:Connect(function()
					caseInstance.Main.Icon.Dark.Visible = false
				end)
			end
		end
	end
	
	self._is_spinning.tracker:Bind(function(value)
		self._is_spinning.trove:Clean()
		
		self.object.Main.Dark.Visible = value
		self.object.Main.Opening.Visible = value
	end)
	
	self.object.Main.Content.Back.MouseButton1Down:Connect(function()
		self:_content(nil)
	end)
	
	Timer.Simple(0.5, function()
		self:_render(data)
	end)
end

function Cases:_render(data)
	for caseId, case in pairs(self._instances) do
		if caseId == 1 then
			case.instance.Main.Button.TextLabel.Text = if DailyCaseUtility.canClaim(data) then "FREE" else NumberUtility.timer.colon.hours(math.max(DailyCaseUtility.getTimeLeft(data), 0))
		elseif caseId == 2 then
			case.instance.Main.Button.TextLabel.Text = if PremiumCaseUtility.canClaim(data) then " FREE" else NumberUtility.timer.colon.hours(math.max(PremiumCaseUtility.getTimeLeft(data), 0))
		end
	end
end

local rnd = Random.new()

function Cases:_content(value)
	if self._is_spinning.tracker:Get() then
		return
	end
	
	if not value then
		self.object.Main.Time.Text = "OPEN CASES"
		self.object.Main.Time.Time.Text = "OPEN CASES"
		self.object.Main.Container.Visible = true
		self.object.Main.Content.Visible = false
		self._content_trove:Clean()
		return
	end
	
	self.object.Main.Container.Visible = false
	self.object.Main.Content.Visible = true
	
	local caseInfo = CaseUtility.getInfo(value)
	
	self.object.Main.Time.Text = caseInfo.name
	self.object.Main.Time.Time.Text = caseInfo.name
	self.object.Main.Content.Icon.Image = caseInfo.image
	
	for i, reward in pairs(caseInfo.rewards) do
		local n = reward[1][1]
		
		local newReward = _L.Assets.UI.Reward.Reward:Clone()
		
		self._content_trove:Add(newReward)
		
		local playerRewardInfo = PlayerRewardUtility.getInfo(n.name).getInfo(n.props.name)
		
		newReward.ImageLabel.Chance.Visible = true
		newReward.ImageLabel.Chance.Text = reward[2].."%"
		newReward.ImageLabel.Quantity.Text = (if n.name ~= "Stat" and n.props.value then ("x"..NumberUtility.short(n.props.value).." ") else "")
		newReward.ImageLabel.TextLabel.Text = (if n.name == "Stat" and n.props.value then ("+"..NumberUtility.short(n.props.value).." ") else "")..(playerRewardInfo.display_name or playerRewardInfo.name)
		newReward.ImageLabel.ImageLabel.Image = playerRewardInfo.image or playerRewardInfo.icon
		newReward.LayoutOrder = i
		
		newReward.Parent = self.object.Main.Content.Rewards
	end
end

function Cases:_spin(result)
	task.spawn(function()
		self:_content(nil)
		self._is_spinning.tracker:Set(true)
		
		local caseId = result.case_id
		local rewardId = result.reward_id
		local spinId = result.spin_id
		
		local caseInfo = CaseUtility.getInfo(caseId)
		
		local numItems = 100
		local chosenPosition = rnd:NextInteger(45, numItems-45)
		
		local mainReward
		
		for i = 1, numItems do
			local reward
			
			if i ~= chosenPosition then
				local randomRewardId = RandomUtility.chance(TableUtility.map(caseInfo.rewards, function(i, v)
					return i, v[2]
				end))
				
				local randomReward = caseInfo.rewards[randomRewardId]
				
				reward = randomReward[1][1]
			else
				mainReward = caseInfo.rewards[rewardId][1][1]
				reward = mainReward
			end

			local newReward = _L.Assets.UI.Reward.Reward:Clone()
			
			local playerRewardInfo = PlayerRewardUtility.getInfo(reward.name).getInfo(reward.props.name)
			
			newReward.ImageLabel.Quantity.Text = (if reward.name ~= "Stat" and reward.props.value then ("x"..NumberUtility.short(reward.props.value).." ") else "")
			newReward.ImageLabel.TextLabel.Text = (if reward.name == "Stat" and reward.props.value then ("+"..NumberUtility.short(reward.props.value).." ") else "")..(playerRewardInfo.display_name or playerRewardInfo.name)
			newReward.ImageLabel.ImageLabel.Image = playerRewardInfo.image or playerRewardInfo.icon
			newReward.LayoutOrder = i
			
			self._is_spinning.trove:Add(newReward)
			
			newReward.Parent = self.object.Main.Opening.Container
		end
		
		local old = 1 - ((0.2 * 5 - 0.1)) - 0.01 * (5 - 1)
		
		self.object.Main.Opening.Container.Position = UDim2.new(old, 0, 0.5, 0)
		
		task.wait(1)
		
		local new = 1 - ((0.2 * (chosenPosition) - 0.1)) - 0.01 * (chosenPosition - 1)
		
		local newTween = Services.TweenService:Create(self.object.Main.Opening.Container, TweenInfo.new(chosenPosition / 10, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(new, 0.5)
		})
		
		newTween:Play()
		
		newTween.Completed:Wait()
		
		local success = Network.Remote.Invoke("S_Cases_Confirm", spinId)

		if success then
			UI.Open({
				name = "Reward", 
				props = {
					data = {
						{
							reward_name = mainReward.name,
							name = mainReward.props.name,
							value = mainReward.props.value
						}
					}
				}
			})
		end
		
		self._is_spinning.tracker:Set(false)
	end)
end

function Cases:Open()
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

function Cases:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Cases