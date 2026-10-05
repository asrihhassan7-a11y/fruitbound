--> Top
local _L = require(game:GetService("ReplicatedStorage").Framework.Library)

--> Variables


--> Constants


---------------------------<
return {
	Name = script.Name,
	Model = script.Model,
	
	IsProgressive = true,
	
	RequiredStrength = 100000000000,
	
	GrantedStrength = 9000000,
	DealtDamage = 2571145,
	Health = 25711450,
	CharacterSize = 3.05,
	
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