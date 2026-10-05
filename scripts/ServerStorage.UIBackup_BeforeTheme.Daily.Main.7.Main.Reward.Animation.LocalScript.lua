local icon = script.Parent

game:GetService("RunService").Heartbeat:Connect(function()
	icon.Rotation += 1
	icon.Position = UDim2.fromScale(0.5, 0.5 - 0.75*(math.sin(math.cos(math.sin(tick())))) / 4)
end)