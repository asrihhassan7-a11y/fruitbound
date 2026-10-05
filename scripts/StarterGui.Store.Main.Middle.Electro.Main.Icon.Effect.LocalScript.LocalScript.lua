local period = 2
local effect = script.Parent
local TweenService = game:GetService("TweenService")
local TInfo = TweenInfo.new(0.4,Enum.EasingStyle.Linear,Enum.EasingDirection.Out)

coroutine.wrap(function()
	while task.wait(period) do
		local tween = TweenService:Create(effect.UIGradient,TInfo,{Offset = Vector2.new(1,0)})
		tween:Play()
		tween.Completed:Connect(function()
			effect.UIGradient.Offset = Vector2.new(-1,0)
		end)
	end
end)()