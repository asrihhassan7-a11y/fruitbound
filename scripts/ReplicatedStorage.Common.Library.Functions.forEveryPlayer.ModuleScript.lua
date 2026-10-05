local Players = game:GetService("Players")

return function(f1, f2)
	for _, player in pairs(Players:GetPlayers()) do
		task.spawn(function()
			f1(player)
		end)
	end
	
	local p1 = Players.PlayerAdded:Connect(function(player)
		f1(player)
	end)
	
	local p2 = Players.PlayerRemoving:Connect(function(player)
		f2(player)
	end)
	
	local disconnected = false
	
	return function()
		if disconnected then
			return
		end
		
		disconnected = true
		
		p1:Disconnect()
		p2:Disconnect()
	end
end