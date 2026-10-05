--{{SERVICES}}
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

--{{MODULES}}
local Settings = require(script.Settings)

--{{SETTINGS}} : SET ACCORDING TO MODULE'S ORGANIZATION.
local RandomOffset, FadeOutTime, FadeInTime, IndicatorLength = Settings.RandomOffset, Settings.FadeOutTime, Settings.FadeInTime, Settings.IndicatorLength
local FadeOutInfo, FadeInInfo = Settings.FadeOutInfo, Settings.FadeInInfo
local Colors, Sizes = Settings.Colors, Settings.Sizes

return function (Victim : Model, Damage : NumberValue, Color : Color3, Size : UDim2, font : Enum.Font)

	if Victim then
		Color = Color or Color3.new(1)
		Size = Size or Sizes.Small
		Damage = tostring(Damage) or '0'
		font = font or script.Damage.Bill.T1.Font
		
		local DamageIndicator = script:WaitForChild("Damage"):Clone()
		DamageIndicator.Bill.Size = Size
		DamageIndicator.Parent, DamageIndicator.CFrame, DamageIndicator.Anchored = workspace, Victim:FindFirstChild("HumanoidRootPart").CFrame * CFrame.new(math.random(unpack(RandomOffset)), 0, 0), false
		DamageIndicator.Bill.T1.Text = ""..Damage; DamageIndicator.Bill.T1:FindFirstChild("Text").Text = ""..Damage
		
		DamageIndicator.Bill.T1.Font = font
		DamageIndicator.Bill.T1:WaitForChild("Text").Font = font
		
		local Tween = TweenService:Create(DamageIndicator.Bill.T1:FindFirstChild("Text"), TweenInfo.new(.5, FadeOutInfo.EasingStyle, FadeOutInfo.EasingDirection), {TextColor3 = Color})
		Tween:Play();
		Tween:Destroy();
		
		task.delay(IndicatorLength, function()
			local Tween = TweenService:Create(DamageIndicator.Bill.T1:FindFirstChild("Text"), TweenInfo.new(1, FadeInInfo.EasingStyle, FadeInInfo.EasingDirection), {TextColor3 = Color3.fromRGB(255,255,255)})
			Tween:Play();
			Tween:Destroy();
			task.delay(1, function()
				DamageIndicator:Destroy()
			end)
		end)

		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.P = 10000
		BodyVelocity.MaxForce = Vector3.new(0,4e4,0)
		BodyVelocity.Velocity = Vector3.new(0,20,0)
		BodyVelocity.Parent = DamageIndicator
		task.delay(.1, function()
			BodyVelocity:Destroy()
		end)
	end
end