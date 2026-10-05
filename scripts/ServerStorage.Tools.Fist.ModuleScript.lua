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
	DealtDamage = nil,
	Health = nil,
	IsProgressive = false,
	CharacterSize = 1,
	Equip = function(self, tool)
		self.Animations.PunchIdle:Play()
	end,
	Unequip = function(self, tool)
		self.Animations.PunchIdle:Stop()
		--self.Animations.LeftPunch:Stop()
		--self.Animations.RightPunch:Stop()
	end,
	Activate = function(self, tool)
		self.Props.Debounce = if self.Props.Debounce == nil then true else self.Props.Debounce
		
		if not self.Cooldown then
			self.Cooldown = true

			task.delay(0.6, function()
				self.Cooldown = false
			end)
			
			local currentStrength = self.User.Stats:Get("Strength"):Get()
			local currentTool = _L.Shared.GetCurrentToolFromStrength(currentStrength)
			local strengthGranted = math.ceil(currentTool.GrantedStrength * 0.5)
			self:GiveToolStrength(strengthGranted)
			
			if self.Props.Debounce then
				self.Animations.LeftPunch:Play()
			else
				self.Animations.RightPunch:Play()
			end
			
			self.Props.Debounce = not self.Props.Debounce
			
			local didHit = false
			
			for _, player:Player in pairs(_L.Players:GetPlayers()) do
				if player ~= self.Player and player.Character and (self.Character.PrimaryPart.Position - player.Character.PrimaryPart.Position).Magnitude < 5 then
					didHit = true
					local user = _L.User.Get(player)
					user.Consumer:DealDamage(self.Player, currentTool.DealtDamage)
				end
			end
			
			self.Animations.WeightRep:Play()
			_L.Functions.PlaySound(if didHit then "FistHit1" else "Swing1", {
				Parent = self.Character.PrimaryPart,
				RollOffMaxDistance = 50
			})
		end
	end,
}



