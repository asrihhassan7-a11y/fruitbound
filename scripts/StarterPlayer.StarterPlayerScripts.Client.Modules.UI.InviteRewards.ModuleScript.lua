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
local _InviteRewards

--> Constants

------------->
local InviteRewards = {
	name = script.Name
}

function InviteRewards:_init()
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
	_InviteRewards = TableUtility.filter(_L.Get {"Common", "Modules", "Databases", "InviteRewards"}, function(i, v)
		return typeof(v) == "table"
	end)
	
	self.is_open = Tracker.new(false)
end

function InviteRewards:_start()
	Notifications = UI.Get("Notifications")

	self.object = _L.PlayerGui.InviteRewards
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()
	
	self._data = data
	
	if data then
		for _, inviteRewardInfo in pairs(_InviteRewards) do
			local newInviteRewardInstance = _L.Assets.UI.InviteRewards.InviteReward:Clone()
			
			newInviteRewardInstance.Main.TextLabel.Text = "Invite "..NumberUtility.commas(inviteRewardInfo.required).." friend"..(if inviteRewardInfo.required > 1 then "s" else "").."!"
			newInviteRewardInstance.Parent = self.object.Main.Pages.Friends.Content.Main.Container.Main
			
			Tracker.Subscribe({data:Track("friends_invited"), data:Track({"invite_rewards", inviteRewardInfo.id})}, function()
				local completed = data:Get({"invite_rewards", inviteRewardInfo.id}) ~= nil
				local value = data:Get("friends_invited")
				local reward = unpack(inviteRewardInfo.reward)
				
				newInviteRewardInstance.Main.Number.Text = inviteRewardInfo.reward_format(reward.props.value)
				newInviteRewardInstance.Main.Number.Number.Text = inviteRewardInfo.reward_format(reward.props.value)

				local p = #value/inviteRewardInfo.required
				local s = p > 0

				newInviteRewardInstance.Main.Progress.Main.Visible = s
				newInviteRewardInstance.Main.Progress.TextLabel.Text = #value.."/"..inviteRewardInfo.required
				newInviteRewardInstance.Main.Progress.Main.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
				newInviteRewardInstance.Main.ImageLabel.Image = inviteRewardInfo.reward_image or newInviteRewardInstance.Main.ImageLabel.Image

				local canClaim = #value >= inviteRewardInfo.required and not completed

				newInviteRewardInstance.Main.ClaimBtn.Image = if canClaim then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_GRAY
				self.object.Main.Buttons.Friends.Time.Text = "Invited: "..NumberUtility.commas(#value)
			end)
			
			newInviteRewardInstance.Main.ClaimBtn.MouseButton1Down:Connect(function()
				local success = Network.Remote.Invoke("S_Invite_Rewards_Claim", inviteRewardInfo.id)
				
				if success then
					Audio.Play({name = "Success1"})
				end
			end)
		end
	end
end

function InviteRewards:Open()
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

function InviteRewards:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
end

return InviteRewards