require("action")
require("drawing")

gfx = love.graphics
width, height = gfx.getDimensions()
midx = width / 2
midy = height / 2
incr = 10

tx, ty = midx, midy
debug = false

local r = user_input()

function eval(input)
  local f = actions[input]
  if f then
    f()
  end
end

function love.draw()
  gfx.setFont(font)
  drawBackground()
  drawHelp()
  drawTurtle(tx, ty)
  if debug then
    drawDebuginfo()
  end
end

function love.keypressed(key)
  if love.keyboard.isDown("lshift", "rshift") then
    if key == "r" then
      tx, ty = midx, midy
    end
  end
  if key == "space" then
    debug = not debug
  end
  if key == "pause" then
    pause()
  end
end

function love.keyreleased(key)
  if key == "i" then
    r = input_text("TURTLE")
  end

  if love.keyboard.isDown("lctrl", "rctrl") then
    if key == "escape" then
      love.event.quit()
    end
  end
end

function love.update()
  if ty > midy then
    debug_color = Color.red
  end
  if not r:is_empty() then
    eval(r())
  end
end
