--> Top
local _L = require(game:GetService("ReplicatedStorage").Framework.Library)

--> Variables


--> Constants


---------------------------<
return {
	Name = script.Name,
	Model = script.Model,
	
	IsProgressive = true,
	
	RequiredStrength = 5000000000000000,
	
	GrantedStrength = 4000000000,
	DealtDamage = 1339571480,
	Health = 13395714800,
	CharacterSize = 3.8,
	
	Equip = function(self, tool)
	
	end,
	
	Unequip = function(self, tool)
		
	end,
	
	Activate = function(self, tool)
		if not self.Cooldown then
			self.Cooldown = true

			task.delay(0.7, function()
				self.Cooldown = false
			end)
			
			local currentMultiplier = _L.Shared.CalculateCurrentMultiplier(self.Player)
			self:GiveToolStrength(tool.GrantedStrength)
			
			self.Animations.WeightRep:Play()
			_L.Functions.PlaySound("Swing1", {
				Parent = self.Character.PrimaryPart,
				RollOffMaxDistance = 50
			})
		end
	end,
}