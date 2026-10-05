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
local Quests

--> Constants

------------->
local Tutorial = {
	name = script.Name
}

function Tutorial:_init()
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
	
	self.is_open = Tracker.new(false)
	self._view = {tracker = Tracker.new(1), trove = Trove.new()}
end

function Tutorial:_start()
	Notifications = UI.Get("Notifications")
	Quests = UI.Get("Quests")
	
	self.object = _L.PlayerGui.Tutorial
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	self._tutorial_instances = {}
	
	local data = Data.Await()
	
	self._data = data
	
	if data then
		Quests:build("tutorial", self._tutorial_instances, "TutorialView", "Tutorial", self.object.Main.Pages["1"].Content.Main.Container)
	end
	
	Tracker.Subscribe({self._data:Track("tutorial_marker"), UI._current}, function()
		local value = self._data:Get("tutorial_marker")
		
		_L.PlayerGui.Main.Top.ProgressBar.HackerEvent.Visible = value == 4
		_L.PlayerGui.Main.Top.ProgressBar.InviteRewards.Visible = value == 4
		_L.PlayerGui.Main.Top.ProgressBar.Tutorial.Visible = value == 3
		
		if value == 4 and UI._current:Get() == self.name then
			UI.Close({name = self.name})
		end
	end)
	
	Tracker.Subscribe({self._data:Track({"quests", "tutorial", "v"}), self._view.tracker}, function()
		local v = self._data:Get({"quests", "tutorial", "v"})
		local isCompleted = self:is_completed()
		self.object.Main.Skip.Number.Text = if self._view.tracker:Get() == 1 then if isCompleted then "COMPLETE" else "SKIP TUTORIAL" else "NEXT >>"
		self.object.Main.Skip.Number.Number.Text = if self._view.tracker:Get() == 1 then if isCompleted then "COMPLETE" else "SKIP TUTORIAL" else "NEXT >>"
	end)
	
	self.object.Main.Skip.MouseButton1Down:Connect(function()
		if self._view.tracker:Get() <= 0 then
			self._view.tracker:Set(self._view.tracker:Get() + 1)
		else
			local isCompleted = self:is_completed()

			if isCompleted then
				Network.Remote.Fire("S_Tutorial_Complete")
			else
				UI.Open({name = "Confirm", props =  {
					text = "Are you sure you want to skip this tutorial? This action cannot be undone.",

					yes = function()
						Network.Remote.Fire("S_Tutorial_Complete")
					end,

					no = function()
					end
				}})
			end
		end
	end)
	
	Tracker.Subscribe({self._view.tracker}, function(value)
		self._view.trove:Clean()

		local viewValue = self._view.tracker:Get()

		local pageInstance = self.object.Main.Pages:FindFirstChild(viewValue)

		if pageInstance then
			self.object.Main.Pages.UIPageLayout:JumpTo(pageInstance)
		end
	end)
	
	local icon = _L.PlayerGui.Main.Top.ProgressBar.Tutorial.Icon

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
end

function Tutorial:is_completed()
	local v = self._data:Get({"quests", "tutorial", "v"})
	local isCompleted = true

	if not v then
		isCompleted = false
	end

	if v and TableUtility.length(v) ~= 3 then
		isCompleted = false
	end

	if v then
		for _, a in pairs(v) do
			if not a.completed then
				isCompleted = false
			end
		end
	end
	
	return isCompleted
end

function Tutorial:Open()
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

function Tutorial:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return Tutorial