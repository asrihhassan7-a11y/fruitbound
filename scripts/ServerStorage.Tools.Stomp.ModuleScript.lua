--> Top
local _L = require(game:GetService("ReplicatedStorage").Framework.Library)

--> Variables


--> Constants


---------------------------<
return {
	Name = script.Name,
	Model = script.Model,
	RequiredGamepass = nil,
	RequiredStrength = nil,
	GrantedStrength = nil,
	DealtDamage = 4,
	Health = nil,
	IsProgressive = false,
	CharacterSize = 1,
	Equip = function(self, tool)
	end,
	Unequip = function(self, tool)
		--self.Animations.Stomp:Stop()
	end,
	Activate = function(self, tool)
		if not self.Cooldown then
			self.Cooldown = true

			task.delay(3, function()
				self.Cooldown = false
			end)
			
			local function findFirstCharacterInRegion(partsList)
				local alreadyFound = {}
				local characters = {}
				for _, part in next, partsList do
					if part.Parent and part.Parent:FindFirstChild("Humanoid") and not alreadyFound[part.Parent] then
						if part.Parent.Parent == workspace then
							alreadyFound[part.Parent] = true
							characters[#characters+1] = part.Parent
						end
					end
				end
				return characters
			end
			
			self.Animations.Stomp:Play()

			task.wait(1.75)
			
			local currentStrength = self.User.Stats:Get("Strength"):Get()
			local currentTool = _L.Shared.GetCurrentToolFromStrength(currentStrength)
			local strengthGranted = math.ceil(currentTool.GrantedStrength * 1.75) 
			self:GiveToolStrength(strengthGranted)
			
			local velocity = self.Character.PrimaryPart.Velocity
			local unit = velocity.magnitude > 0 and velocity.unit or Vector3.new(0, 0, 0)
			local dot = unit:Dot(self.Character.PrimaryPart.CFrame.lookVector)
			local dot2 =self.Character.PrimaryPart.CFrame.rightVector:Dot(unit)
			local xframe = (self.Character.LeftFoot.CFrame)
			local newRegion = _L.Region.new(xframe, Vector3.new(4 + self.Character.UpperTorso.Size.X * 2,4 + self.Character.UpperTorso.Size.Y * 2,4 + self.Character.UpperTorso.Size.Z * 3))
			local hitCharacters = findFirstCharacterInRegion(newRegion:Cast(self.Character))
			
			if hitCharacters then
				for _, hitCharacter in pairs(hitCharacters) do
					local hitPlayer = _L.Players:GetPlayerFromCharacter(hitCharacter)
					if hitPlayer then
						local user = _L.User.Get(hitPlayer)
						user.Consumer:DealDamage(self.Player, currentTool.DealtDamage * 2)
					end
				end
			end
			
			_L.Functions.PlaySound("Stomp1", {
				PlaybackSpeed = math.random(1.30, 2.00),
				Parent = self.Character.PrimaryPart,
				RollOffMaxDistance = 50
			})
			
			task.wait(0.2)
			
			local newCrack = _L.Assets.VFX.StompCrack:Clone()
			newCrack.Size = Vector3.new(0, 0, 0)
			newCrack.Position = self.Character.LeftFoot.Position
			newCrack.Parent = _L.Debris
			
			local bestTool = _L.Shared.GetCurrentToolFromStrength(self.User.Stats:Get("Strength"):Get())
			
			_L.spr.target(newCrack, 0.7, 4, {
				Size = Vector3.new(5 * bestTool.CharacterSize, 0, 5 * bestTool.CharacterSize)
			})
			
			task.delay(2, function()
				_L.spr.target(newCrack.Decal, 1, 2, {
					Transparency = 1
				})
				
				task.wait(1)
				
				newCrack:Destroy()
			end)
		end
	end,
}



