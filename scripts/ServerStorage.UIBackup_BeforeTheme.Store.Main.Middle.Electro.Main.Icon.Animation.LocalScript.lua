local icon = script.Parent

game:GetService("RunService").Heartbeat:Connect(function()
	icon.Position = UDim2.fromScale(0.075, 0.675 - (math.sin(math.cos(math.sin(tick())))) / 4)
end)