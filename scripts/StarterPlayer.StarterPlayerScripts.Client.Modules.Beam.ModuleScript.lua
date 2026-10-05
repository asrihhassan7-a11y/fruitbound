--> Variables
local _L = _G._L

local Tracker
local Services
local Signal
local Spr

--> Constants

------------->
local Beam = {}

function Beam._init()
	Tracker = _L.Get {"Common", "Library", "Classes", "Tracker", "Tracker"}
	Trove = _L.Get {"Common", "Library", "Classes", "Trove"}
	Timer = _L.Get {"Common", "Library", "Classes", "Timer"}
	Services = _L.Get {"Common", "Library", "Services"}
	Signal = _L.Get {"Common", "Library", "Classes", "Signal"}
	Spr = _L.Get {"Common", "Library", "Physics", "Spr"}
	cancellableDelay = _L.Get {"Common", "Library", "Functions", "cancellableDelay"}
end

function Beam._start()
	Beam._current = {tracker = Tracker.new(nil), trove = Trove.new()}
	
	Beam._current.tracker:Bind(function(value)
		Beam._current.trove:Clean()
		
		if not value then
			return
		end
		
		local part1 = value[1]
		local part2 = value[2]
		
		if not part1 or not part2 then
			return
		end
		
		local arrows = {}
		
		Beam._current.trove:Add(Timer.Simple(0.5, function()
			local newArrow = _L.Assets.Models.Arrow:Clone()
			
			local originalSize = newArrow.Size
			originalSize = Vector3.new(originalSize.X * 1.5, originalSize.Y * 1.5, originalSize.Z * 0.4)
			
			newArrow.Size = Vector3.zero
			
			Spr.Target(newArrow, 1, 3, {
				Size = originalSize
			})
			
			Beam._current.trove:Add(newArrow)
			
			newArrow.Parent = _L.Debris
			
			arrows[newArrow] = {
				instance = newArrow,
				t = 0
			}
		end))
		
		Beam._current.trove:Add(Services.RunService.RenderStepped:Connect(function(dt)
			for arrowInstance, arrow in pairs(arrows) do
				if arrow.t >= 1 then
					arrows[arrowInstance] = nil
					
					Spr.Target(arrowInstance, 0.8, 5, {
						Size = Vector3.zero
					})
					
					Beam._current.trove:Add(cancellableDelay(1, function()
						arrowInstance:Destroy()
					end))
					
					continue
				end
				
				local cf = CFrame.lookAt(part1.CFrame.Position, part2.CFrame.Position)
				arrow.instance.CFrame = cf:Lerp(CFrame.new(part2.CFrame.Position) * (cf - cf.Position), math.clamp(arrow.t, 0, 1)) * CFrame.Angles(math.rad(90), 0, math.rad(-90))
				arrow.t += dt / 4
			end
		end))
	end)
end

function Beam.Set(value)
	Beam._current.tracker:Set(value)
end

return Beam