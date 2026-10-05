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
local ProgressBar
local Notifications
local RankUtility

--> Constants

------------->
local Ranks = {
	name = script.Name
}

function Ranks:_init()
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
	ProgressBar = _L.Get {"Client", "Modules", "Classes", "ProgressBar"}
	RankUtility = _L.Get {"Common", "Modules", "Utilities", "RankUtility"}
	
	self.is_open = Tracker.new(false)
	self.trove = Trove.new()
end

function Ranks:_start()
	Notifications = UI.Get("Notifications")
	
	self.object = _L.PlayerGui.Ranks
	
	self.is_open:Bind(function(value, props)
		if value then
			self:Open()
		else
			self:Close()
		end
	end)
	
	local data = Data.Await()

	if data then
		local ttt = (30*60)
		
		Tracker.Subscribe({data:Track("rank_reward"), data:Track({"stats", "Crops_Harvested"}), data:Track("crop_legacy"), data:Track({"stats", "Total_Time"})}, function()
			local canClaim = RankUtility.canClaim(data)
			-- rank progress = real crops harvested (RankUtility.getProgress / getInfoFromData)
			local progress = RankUtility.getProgress(data)
			local t = data:Get({"stats", "Total_Time"})
			local v = RankUtility.getNextInfoFromData(data)
			local cc = RankUtility.getInfoFromData(data)
			local tttt = RankUtility.getTimeLeft(data)
			local p = progress/if v then v.required else progress
			local s = p > 0
			self.object.Main.Pages.DailyView.Content.Main.Container.Progress.Main.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
			self.object.Main.Pages.DailyView.Content.Main.Container.Progress.TextLabel.Text = if v then NumberUtility.commas(progress).."/"..NumberUtility.commas(v.required) else "MAX RANK"
			self.object.Main.Pages.DailyView.Content.Main.Container.Progress.TextLabel.Text = if v then NumberUtility.commas(progress).."/"..NumberUtility.commas(v.required) else ""
			self.object.Main.A.T.Text = if v then "🌱 You need "..NumberUtility.commas(v.required-progress).." more Harvests to rank up 🌱" else ""
			self.object.Main.A.C.Text = if cc then cc.name else ""
			self.object.Main.A.N.Text = if v then v.name else ""
			self.object.Main.Dark.Visible = t < ttt
			self.object.Main.Dark.Time.Text = NumberUtility.timer.short.auto(ttt-t).." left to unlock!"
			self.object.Main.ClaimBtn.Image = if canClaim then Constants.POP_BUTTON_GREEN else Constants.POP_BUTTON_GRAY
			self.object.Main.ClaimBtn.Number.Text = if canClaim then "CLAIM!" else NumberUtility.timer.short.auto(tttt)
		end)
		
		self.object.Main.ClaimBtn.MouseButton1Down:Connect(function()
			local success = Network.Remote.Invoke("S_Rank_Reward_Claim")

			if success then
				Notifications:add({text = "✅ Rank reward claimed!", color = Color3.fromRGB(0, 255, 0), audio = {name = "Success1"}})
			end
		end)
	end
end
	
function Ranks:Open()
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

function Ranks:Close()
	self.object.Main.Visible = false
	
	Spr.Target(workspace.CurrentCamera, 0.7, 4, {
		FieldOfView = 70
	})

	Spr.Target(Services.Lighting.Blur, 0.7, 4, {
		Size = 0
	})
	
	local bottomBar = _L.PlayerGui.Main:FindFirstChild("Bottom") if bottomBar and bottomBar:FindFirstChild("Toolbar") then bottomBar.Toolbar.Visible = true end
end

return Ranks