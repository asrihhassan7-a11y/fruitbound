--> Top
local _L = require(game:GetService("ReplicatedStorage").Framework.Library)

--> Variables


--> Constants


---------------------------<
return {
	Name = script.Name,
	Model = script.Model,
	
	IsProgressive = true,
	
	RequiredStrength = 320000,
	
	GrantedStrength = 2500,
	DealtDamage = 3050,
	Health = 30500,
	CharacterSize = 2.3,
	
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