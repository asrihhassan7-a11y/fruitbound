game["Run Service"].RenderStepped:Connect(function()
	script.Parent.Rotation = math.sin(tick() * 10) / 2
end)