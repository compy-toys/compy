local G = love.graphics
math.randomseed(os.time())
cw, ch = G.getDimensions()
midx = cw / 2

require("math")
require("examples")

size = 28
spacing = 3
offset = size + 4

local colors = {
  bg = Color[Color.black],
  pos = Color[Color.white + Color.bright],
  neg = Color[Color.red + Color.bright],
  text = Color[Color.white],
  help = Color.with_alpha(Color[Color.white], 0.5)
}

body = ""
legend = ""
help =
    "Hint:\n" ..
    "left click for next example\n" ..
    "shift + left click to go back\n" ..
    "right click for a random one"
showHelp = true
count = 16
ex_idx = 1
local time = 0

function load_example(ex)
  if type(ex) == "table" then
    body = ex.code
    setupTixy()
    legend = ex.legend
    write_to_input(body)
  end
end

function advance()
  local e = examples[ex_idx]
  load_example(e)
  if ex_idx < #examples then
    ex_idx = ex_idx + 1
  end
end

function retreat()
  if 1 < ex_idx then
    local e = examples[ex_idx]
    load_example(e)
    ex_idx = ex_idx - 1
  end
end

function pick_random(t)
  if type(t) == "table" then
    local n = #t
    local r = math.random(n)
    return t[r], r
  end
end

function randomize()
  local e, i = pick_random(examples)
  load_example(e)
  ex_idx = i + 1
end

function b2n(b)
  if b then
    return 1
  else
    return 0
  end
end

function n2b(n)
  if n ~= 0 then
    return true
  else
    return false
  end
end

function tixy(t, i, x, y)
  return 0.1
end

function setupTixy()
  local code = "return function(t, i, x, y)\n" .. body .. " end"
  local f = loadstring(code)
  if f then
    setfenv(f, _G)
    time = 0
    tixy = f()
  end
end

function drawBackground()
  G.setColor(colors.bg)
  G.rectangle("fill", 0, 0, cw, ch)
end

function drawCircle(color, radius, x, y)
  G.setColor(color)
  G.circle(
    "fill",
    x * (size + spacing) + offset,
    y * (size + spacing) + offset,
    radius
  )
  G.circle(
    "line",
    x * (size + spacing) + offset,
    y * (size + spacing) + offset,
    radius
  )
end

function clamp(value)
  local color = colors.pos
  local radius = (value * size) / 2
  if radius < 0 then
    radius = -radius
    color = colors.neg
  end
  if size / 2 < radius then
    radius = size / 2
  end
  return color, radius
end

function drawOutput()
  local index = 0
  local ts = time
  for y = 0, count - 1 do
    for x = 0, count - 1 do
      local value = tonumber(tixy(ts, index, x, y)) or -0.1
      local color, radius = clamp(value)
      drawCircle(color, radius, x, y)
      index = index + 1
    end
  end
end

function drawText()
  G.setColor(colors.text)
  local sof = (size / 2) + offset
  local hof = sof / 2
  G.printf(legend, midx + hof, sof, midx - sof)
  if showHelp then
    G.setColor(colors.help)
    G.setFont(font)
    G.printf(help, midx + hof, ch - (5 * sof), midx - sof)
  end
end

function love.draw()
  drawBackground()
  drawOutput()
  drawText()
end

r = user_input()

function love.update(dt)
  time = time + dt
  if r:is_empty() then
    input_code("function tixy(t, i, x, y)", string.lines(body))
  else
    local ret = r()
    body = string.unlines(ret)
    setupTixy()
    legend = ""
  end
end

function love.mousepressed(_, _, button)
  if button == 1 then
    if Key.shift() then
      retreat()
    else
      advance()
    end
  end
  if button == 2 then
    randomize()
  end
end

advance()
