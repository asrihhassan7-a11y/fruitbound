--> Variables
local _L = _G._L

local Network
local Pool
local Services
local Spr
local NumberUtility
local DamageIndicator

local Pools = {}

--> Constants

---------->
return {
	{
		name = "Punch",
		
		callback = function(props)
			local pool = Pools[props.name]

			if not pool or not props.player then
				return
			end
			
			local playerCharacter = props.player.Character

			if not playerCharacter or not playerCharacter.PrimaryPart then
				return
			end
			
			task.delay(0.25, function()
				if playerCharacter.PrimaryPart then
					local startPosition = (playerCharacter:GetPivot() * CFrame.new(0, 0, -3)).Position

					local newInstance = pool:get()

					newInstance.Position = startPosition

					newInstance.Parent = _L.Debris

					for _, v in pairs(newInstance.Attachment:GetChildren()) do
						v:Emit(v.Rate)
					end

					Audio.Play({name = "Punch1", speed = math.random(12, 15) / 10, position = playerCharacter.PrimaryPart.Position})

					task.delay(1.75, function()
						newInstance.Parent = nil

						pool:back(newInstance)
					end)
				end
			end)
		end,
	},
	
	{
		name = "Fireball",
		
		callback = function(props)
			local pool = Pools[props.name]
			
			if not pool then
				return
			end
			
			local playerCharacter = props.player.Character
			
			if not playerCharacter then
				return
			end
			
			local rightHand = playerCharacter:FindFirstChild("RightHand")
			
			if not rightHand then
				return
			end
			
			local startPosition = rightHand.CFrame
			local endPosition = CFrame.new(startPosition.Position, props.position) * CFrame.new(0, 0, -100)
			
			local newInstance = pool:get()
			
			local totalTime = 0
			local newTrove = Trove.new()
			
			newTrove:Add(function()
				newInstance.Parent = nil
				pool:back(newInstance)
			end)
			
			local factor = 2
			
			newTrove:Connect(Services.RunService.RenderStepped, function(dt)
				if totalTime * factor >= 10 then
					newTrove:Destroy()
					return
				end
				
				newInstance:PivotTo(startPosition:Lerp(endPosition, totalTime))
				
				totalTime += dt / factor
			end)
			
			local p = {}
			local already = false
			
			if props.player == _L.Player then
				newTrove:Add(Services.RunService.RenderStepped:Connect(function()
					for _, player in pairs(Services.Players:GetPlayers()) do
						if player ~= _L.Player and player.Character and not p[player] and player.Character.PrimaryPart then				
							local character = player.Character
							local s = newInstance:GetExtentsSize()

							local h = math.max(s.X, s.Y, s.Z)

							if (newInstance:GetPivot().Position - character.PrimaryPart.Position).Magnitude <= h then
								p[player] = true
								
								local success = Network.Remote.Invoke("S_Damage_Register", player, props.info.damage)
								
								if not success then
									if not already then
										already = true
										Network.Bindable.Fire("C_Notifications_Add", {
											text = "🛡️ This player has protection on!",
											color = Color3.fromRGB(0, 248, 255),
											audio = {name = "Protection1"},
											duration = 2
										})
									end
									continue
								end
								
								DamageIndicator = DamageIndicator or _L.Get {"Client", "Modules", "DamageIndicator"}
								
								DamageIndicator(character, props.info.damage, nil, UDim2.fromScale(2.5, 2.5))
								--local damageGui = _L.Assets.UI.DamageGui:Clone()

								--local old = character.PrimaryPart:FindFirstChild("DamageGui")

								--if old then
								--	old:Destroy()
								--end
								
								--if success then
								--	Audio.Play {name = "Damage1"}
								--end
								
								--damageGui.Main.Damage.Text = "-"..NumberUtility.short(props.info.damage)
								--damageGui.Main.UIScale.Scale = 0
								--damageGui.Parent = character.PrimaryPart

								--Spr.Target(damageGui.Main.UIScale, 0.8, 3, {
								--	Scale = 0.3
								--})

								--task.delay(3, function()
								--	if damageGui.Parent == character.PrimaryPart then
								--		Spr.Target(damageGui.Main.UIScale, 0.8, 5, {
								--			Scale = 0
								--		})

								--		task.delay(2, function()
								--			damageGui:Destroy()
								--		end)
								--	end
								--end)
							end
						end
					end
				end))
			end

			newInstance.Parent = _L.Debris
		end,
	},
	
	{
		-- Harvest pop: a small burst of leaves at the bush
		name = "Harvest",

		callback = function(props)
			local position = props.position
			if typeof(position) ~= "Vector3" then
				return
			end

			local TweenService = game:GetService("TweenService")
			local colors = {Color3.fromRGB(110, 215, 100), Color3.fromRGB(80, 185, 80), Color3.fromRGB(160, 235, 120)}
			local origin = position + Vector3.new(0, 3, 0)

			for i = 1, 7 do
				local leaf = Instance.new("Part")
				leaf.Name = "HarvestLeaf"
				leaf.Size = Vector3.new(0.5, 0.12, 0.35)
				leaf.Color = colors[math.random(#colors)]
				leaf.Material = Enum.Material.SmoothPlastic
				leaf.Anchored = true
				leaf.CanCollide = false
				leaf.CanQuery = false
				leaf.CanTouch = false
				leaf.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				leaf.Parent = _L.Debris

				local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.4, math.random() - 0.5).Unit
				local goal = CFrame.new(origin + dir * (2.5 + math.random() * 2)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				TweenService:Create(leaf, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = goal, Transparency = 1}):Play()
				task.delay(0.6, function()
					leaf:Destroy()
				end)
			end

			if Audio then
				Audio.Play({name = "Plop1", speed = math.random(9, 12) / 10, position = position})
			end
		end,
	},
	
	_init = function()
		Pool = _L.Get {"Common", "Library", "Classes", "Pool"}
		Audio = _L.Get {"Common", "Library", "Audio"}
		Services = _L.Get {"Common", "Library", "Services"}
		Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
		Network = _L.Get {"Common", "Library", "Network"}
		Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
		NumberUtility = _L.Get {"Common", "Library", "Utilities", "NumberUtility"}
	end,
	
	_start = function()
		Pools.Holder = Pool.new({name = "Holder", template = _L.Assets.Models.Holder})
		
		for _, instance in pairs(_L.Assets.Models.Powers:GetChildren()) do
			local newPool = Pool.new({name = instance.Name, template = instance})
			Pools[instance.Name] = newPool
		end
	end,
}