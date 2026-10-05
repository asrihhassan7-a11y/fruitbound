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
local ClanEmblems
local DailyQuestUtility
local TableTracker
local WeeklyQuestUtility
local QuestUtility
local TutorialQuestUtility

--> Constants

------------->
local Quests = {
	name = script.Name
}

function Quests:_init()
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
	TableTracker = _L.Get {"Common", "Library", "Classes", "Tracker", "TableTracker"}
	WeeklyQuestUtility = _L.Get {"Common", "Modules", "Utilities", "WeeklyQuestUtility"}
	DailyQuestUtility = _L.Get {"Common", "Modules", "Utilities", "DailyQuestUtility"}
	QuestUtility = _L.Get {"Common", "Modules", "Utilities", "QuestUtility"}
	TutorialQuestUtility = _L.Get {"Common", "Modules", "Utilities", "TutorialQuestUtility"}
	
	self.is_open = Tracker.new(false)
	
	self._view = {tracker = Tracker.new("DailyView"), trove = Trove.new()}
end

function Quests:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.Quests
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	self._daily_instances = {}
	self._weekly_instances = {}
	
	local data = Data.Await()
	
	self._data = data
	
	if data then
		self:build("daily", self._daily_instances, "DailyView", "Daily")
		self:build("weekly", self._weekly_instances, "WeeklyView", "Weekly")
		
		self.object.Main.Daily.MouseButton1Down:Connect(function()
			self._view.tracker:Set("DailyView")
		end)
		
		self.object.Main.Weekly.MouseButton1Down:Connect(function()
			self._view.tracker:Set("WeeklyView")
		end)
		
		Tracker.Subscribe({self._view.tracker, data:Track({"quests", "daily", "t"}), data:Track({"quests", "weekly", "t"})}, function(value)
			self._view.trove:Clean()
			
			local viewValue = self._view.tracker:Get()
			local dailyQuestTimeLeft = data:Get({"quests", "daily", "t"})
			local weeklyQuestTimeLeft = data:Get({"quests", "weekly", "t"})

			local pageInstance = self.object.Main.Pages:FindFirstChild(viewValue)

			if pageInstance then
				self.object.Main.Pages.UIPageLayout:JumpTo(pageInstance)
			end
			
			self.object.Main.Weekly.Deselected.Enabled = viewValue ~= "WeeklyView"
			self.object.Main.Daily.Deselected.Enabled = viewValue ~= "DailyView"
			
			self.object.Main.Weekly.Select.Enabled = viewValue == "WeeklyView"
			self.object.Main.Daily.Select.Enabled = viewValue == "DailyView"
			
			self:_render()
		end)
		
		Timer.Simple(0.5, function()
			self:_render()
		end)
	end
end

function Quests:_render()
	local data = self._data
	
	local viewValue = self._view.tracker:Get()
	local dailyQuestTimeLeft = data:Get({"quests", "daily", "t"})
	local weeklyQuestTimeLeft = data:Get({"quests", "weekly", "t"})
	
	local timeLeft
	
	if viewValue == "DailyView" and dailyQuestTimeLeft then
		timeLeft = math.max(DailyQuestUtility.getTimeLeft(dailyQuestTimeLeft), 0)
	elseif viewValue == "WeeklyView" and weeklyQuestTimeLeft then
		timeLeft = math.max(WeeklyQuestUtility.getTimeLeft(weeklyQuestTimeLeft), 0)
	end

	self.object.Main.Background.Background.Time.Text = if timeLeft then "Resets in "..NumberUtility.timer.short.auto(timeLeft) else "Loading..."
end

function Quests:build(a1, a2, a3, a4, a5)
	Tracker.Subscribe({self._data:Track("tutorial_marker"), self._data:Track({"quests", a1})}, function()
		local value = self._data:Get({"quests", a1})
		local cc = self._data:Get("tutorial_marker") == 4
		
		if value.t or cc == false then
			for questIndex, questInstance in pairs(a2) do
				if questInstance.t ~= value.t or cc == true then
					a2[questIndex] = nil
					questInstance.trove:Destroy()
				end
			end

			for i, v in pairs(value.v) do
				local av = a2[i]

				if not av then
					local newTrove = Trove.new()
					local newInstance = newTrove:Add(_L.Assets.UI[if a4 == "Tutorial" then a4 else "Quests"].Quest:Clone())
					local questInfo = (if a4 == "Tutorial" then TutorialQuestUtility else QuestUtility).getInfo(v.id)

					newTrove:Add(newInstance.Main.ClaimBtn.MouseButton1Down:Connect(function()
						local success = Network.Remote.Invoke("S_Quests_Claim", a4, i)

						if success then
							Notifications:add({text = "✅ Quest completed!", color = Color3.fromRGB(0, 255, 0), audio = {name = "Success1"}})
						end
					end))

					newInstance.Parent = (a5 or self.object.Main.Pages[a3].Content.Main.Container).Main

					a2[i] = {
						t = value.t,
						instance = newInstance,
						info = questInfo,
						trove = newTrove
					}

					av = a2[i]
				end

				local progress = v.progress

				if v.completed then
					av.instance.Main.Checkmark.Visible = true
					av.instance.Main.ClaimBtn.Visible = false
				else
					av.instance.Main.Checkmark.Visible = false
					av.instance.Main.ClaimBtn.Visible = true
				end

				av.instance.Main.TextLabel.Text = av.info.description(v.required)

				av.instance.Main.Number.Text = av.info.reward_format(v.reward)
				av.instance.Main.Number.Number.Text = av.info.reward_format(v.reward)

				local p = progress/v.required
				local s = p > 0

				av.instance.Main.Progress.Main.Visible = s
				av.instance.Main.Icon.Icon.Image = av.info.icon
				av.instance.Main.Progress.TextLabel.Text = av.info.fetch_format(progress, v.required)
				av.instance.Main.Progress.Main.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
				av.instance.Main.ImageLabel.Image = av.info.reward_image or av.instance.Main.ImageLabel.Image
				
				local canClaim = progress >= v.required and not v.completed

				av.instance.Main.ClaimBtn.Image = if canClaim then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_GRAY

				if v.completed then
					av.instance.LayoutOrder = 2
					av.instance.Main.ClaimBtn.Visible = false
					av.instance.Main.Checkmark.Visible = true
				else
					av.instance.LayoutOrder = 1
					av.instance.Main.Checkmark.Visible = false
					av.instance.Main.ClaimBtn.Visible = true
				end
			end
		end
	end)
end

function Quests:Open()
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

function Quests:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Quests