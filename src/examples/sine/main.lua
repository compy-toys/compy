local gfx = love.graphics

local x0 = 0
local xe = gfx.getWidth()
local y0 = 0
local ye = gfx.getHeight()

local xh = xe / 2
local yh = ye / 2

gfx.setColor(1, 1, 1, 0.5)
gfx.setLineWidth(1)
gfx.line(xh, y0, xh, ye)
gfx.line(x0, yh, xe, yh)

gfx.setColor(1, 0, 0)
gfx.setPointSize(2)

local amp = 100
local times = 2
local points = { }

for x = 0, xe do
  local v = 2 * math.pi * (x - xh) / xe
  local y = yh - math.sin(v * times) * amp
  table.insert(points, x)
  table.insert(points, y)
end

gfx.points(points)
