local icon = script.Parent

game:GetService("RunService").Heartbeat:Connect(function()
	icon.Size = UDim2.fromScale(0.285*(math.sin(tick()*6)+64)/64,0.6*(math.sin(tick()*6+math.pi)+64)/64)
end)