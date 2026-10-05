--> Variables
local _L = _G._L

local Services
local GIFs
local Maid

--> Constants
local MAX_IMAGE_SIZE = 1024

---------->
-------------------------<
---- Spritesheet: https://ezgif.com/gif-to-sprite
---- Transparent GIF: https://onlinegiftools.com/create-transparent-gif
---- Pixels Info: https://www.posterburner.com/Image-Size-Finder.aspx
-------------------------<
local GIF = {}
GIF.__index = GIF

GIF._objects = {}

function GIF._init()
	Services = _L.Get {"Common", "Library", "Services"}
	GIFs = _L.Get {"Common", "Modules", "Databases", "GIFs"}
	Maid = _L.Get {"Common", "Library", "Classes", "Maid"}
end

function GIF._start()
	Services.RunService.RenderStepped:Connect(function()
		for _, self in pairs(GIF._objects) do
			if self.IsPlaying == true then
				if (tick() - self._lastTick) >= self.speed then
					self._lastTick = tick()
					self._currentFrameIndex += 1

					if self.instance.Visible then
						self.instance.ImageRectOffset = self._offsets[self._currentFrameIndex]
					end

					if self._currentFrameIndex >= self.totalFrames then
						if not self.looped then
							self.IsPlaying = false
						end

						self._currentFrameIndex = 0
					end
				end
			end
		end
	end)
end

function GIF.new(props)
	local self = setmetatable({}, GIF)

	self.instance = props.instance
	self.looped = props.looped or false
	self.url = props.url or props.instance.Image

	self._offsets = {}
	self._lastTick = 0
	self._currentFrameIndex = 0

	self.IsPlaying = false

	self._maid = Maid.new()

	self:_construct()

	return self
end

function GIF:_construct()
	if GIF._objects[self.instance] then
		GIF._objects[self.instance]:destroy()
	end

	local gifInfo = GIFs[self.url]

	self.size = gifInfo.size
	self.rows = gifInfo.rows
	self.columns = gifInfo.columns
	self.totalFrames = gifInfo.total_frames
	self.speed = gifInfo.speed

	local realWidth
	local realHeight
	local currentColumn, currentRow = 0, 0

	if math.max(self.size.X, self.size.Y) > MAX_IMAGE_SIZE then
		local longest = self.size.X > self.size.Y and "Width" or "Height"

		if longest == "Width" then
			realWidth = MAX_IMAGE_SIZE
			realHeight = (realWidth / self.size.X) * self.size.Y
		elseif longest == "Height" then
			realHeight = MAX_IMAGE_SIZE
			realWidth = (realHeight / self.size.Y) * self.size.X
		end
	else
		realWidth = self.size.X
		realHeight = self.size.Y
	end

	self.instance.ImageRectSize = Vector2.new(realWidth / self.columns, realHeight / self.rows)

	self._maid:GiveTask(function()
		self.instance.ImageRectOffset = Vector2.new(0, 0)
		self.instance.ImageRectSize =  Vector2.new(0, 0)
	end)

	for i = 1, self.totalFrames do
		local currentX = currentColumn * realWidth / self.columns
		local currentY = currentRow * realHeight / self.rows

		table.insert(self._offsets, Vector2.new(currentX, currentY))

		currentColumn += 1

		if currentColumn >= self.columns then
			currentColumn = 0
			currentRow += 1
		end
	end

	self.instance.Destroying:Connect(function()
		self:Destroy()
	end)

	GIF._objects[self.instance] = self

	self._maid:GiveTask(function()
		GIF._objects[self.instance] = nil
	end)
end

function GIF:Play()
	self._lastTick = 0
	self.IsPlaying = true
end

function GIF:Stop()
	self.IsPlaying = false
end

function GIF:Destroy()
	self._maid:Destroy()
end

return GIF

