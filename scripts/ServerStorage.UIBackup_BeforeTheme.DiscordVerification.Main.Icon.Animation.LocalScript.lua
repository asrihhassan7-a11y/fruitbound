local icon = script.Parent

game:GetService("RunService").Heartbeat:Connect(function()
	icon.Position = UDim2.fromScale(0.191, 0.5 - 0.5 * (math.sin(math.cos(math.sin(tick())))) / 4)
end)