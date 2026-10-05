--> Top
local _L = require(game:GetService("ReplicatedStorage").Framework.Library)

--> Variables


--> Constants


---------------------------<
return {
	Name = script.Name,
	Model = script.Model,
	
	IsProgressive = true,
	
	RequiredStrength = 0,
	
	GrantedStrength = 1,
	DealtDamage = 10,
	Health = 100,
	CharacterSize = 1,
	
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