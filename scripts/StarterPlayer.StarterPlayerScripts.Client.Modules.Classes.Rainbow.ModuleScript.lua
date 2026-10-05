--> Variables
local _L = _G._L

local Services
local GIFs
local Maid

--> Constants

-------------------------<
local Rainbow = {}
Rainbow.__index = Rainbow

Rainbow._objects = {}

function Rainbow._init()
	Services = _L.Get {"Common", "Library", "Services"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
end

function Rainbow._start()
	local m

	if Services.RunService:IsClient() then
		m = Services.RunService.RenderStepped
	else
		m = Services.RunService.Heartbeat
	end

	m:Connect(function()
		for _, self in pairs(Rainbow._objects) do
			local delta = (os.clock() - self._last_clock) * (1 / self.speed)

			if delta >= 1 then
				self._last_clock = os.clock()
				delta = 0
			end

			self.callback(Color3.fromHSV(delta, 1, 1))
		end
	end)
end

function Rainbow.new(props)
	local self = setmetatable({}, Rainbow)

	self.id = Services.HttpService:GenerateGUID(false)
	self.callback = props.callback
	self.speed = props.speed

	self._last_clock = 0

	self._maid = Maid.new()

	self:_construct()

	return self
end

function Rainbow:_construct()
	Rainbow._objects[self.id] = self

	self._maid:GiveTask(function()
		Rainbow._objects[self.id] = nil
	end)
end

function Rainbow:Destroy()
	self._maid:Destroy()
end

return Rainbow