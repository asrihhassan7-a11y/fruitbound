local icon = script.Parent

game:GetService("RunService").Heartbeat:Connect(function()
	icon.Rotation += 0.1
end)