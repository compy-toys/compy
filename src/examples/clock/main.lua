local gfx = love.graphics

width, height = gfx.getDimensions()
midx = width / 2
midy = height / 2

local M = 60
local H = M * M
local D = 24

local h, m, s, t
function setTime()
  local time = os.date("*t")
  h = time.hour
  m = time.min
  s = time.sec
  t = s + M * m + H * h
end

setTime()

math.randomseed(os.time())
color = math.random(7)
bg_color = math.random(7)
font = gfx.newFont(144)

local function pad(i)
  return string.format("%02d", i)
end

function getTimestamp()
  local hours = pad(math.fmod((t / H), D))
  local minutes = pad(math.fmod((t / M), M))
  local seconds = pad(math.fmod(t, M))
  return string.format("%s:%s:%s", hours, minutes, seconds)
end

function love.draw()
  gfx.setColor(Color[color + Color.bright])
  gfx.setBackgroundColor(Color[bg_color])
  gfx.setFont(font)
  local text = getTimestamp()
  local off_x = font:getWidth(text) / 2
  local off_y = font:getHeight() / 2
  gfx.print(text, midx - off_x, midy - off_y)
end

function love.update(dt)
  t = t + dt
end

function cycle(c)
  if 7 < c then
    return 1
  end
  return c + 1
end

local function shift()
  return love.keyboard.isDown("lshift", "rshift")
end
local function color_cycle(k)
  if k == "space" then
    if shift() then
      bg_color = cycle(bg_color)
    else
      color = cycle(color)
    end
  end
end
function love.keyreleased(k)
  color_cycle(k)
  if k == "r" and shift() then
    setTime()
  end
  if k == "p" then
    pause("STOP THE CLOCKS!")
  end
end
