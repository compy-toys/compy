require('util.lua')

--- CLI arguments
--- 1 <game>
--- 2 [<mode>]
--- 3 [options]
--- -2 love
--- -1 embedded boot.lua
--- @return Start
local argparse = function()
  local args = _G.arg

  local m = args[2]
  if m then
    if m == 'harmony' then
      return { mode = 'harmony' }
    elseif m == 'test' then
      local autotest = false
      local drawtest = false
      local sizedebug = false
      for _, a in ipairs(args) do
        if a == '--auto' then autotest = true end
        if a == '--size' then sizedebug = true end
        if a == '--draw' then
          drawtest = true
          sizedebug = true
        end
        if a == '--all' then
          drawtest = true
          sizedebug = true
          autotest = true
        end
      end
      return {
        mode = 'test',
        testflags = {
          auto = autotest,
          draw = drawtest,
          size = sizedebug
        }
      }
    elseif m == 'play' then
      local path = args[3]
      return { mode = 'play', path = path }
    end
  end
  return { mode = 'ide' }
end

local start = argparse()

if start.mode == 'harmony' then
  require("harmony.init")(true)
end

--- @diagnostic disable-next-line: duplicate-set-field
function love.conf(t)
  t.window.resizable = false
  if os.getenv("DEBUG") then
    love.DEBUG = true
  end
  if os.getenv("TRACE") then
    love.TRACE = true
  end

  if os.getenv("COMPY_PROF") then
    print('DEBUG: initializing profiler')
    local frames = os.getenv("FRAMES") or 50
    love.PROFILE = {
      reports = {},
      frame = 0,
      n_frames = frames,
      n_rows = 7,
      fpsc = 'T_R_B'
    }
  end

  t.identity = 'compy'
  t.window.resizable = false

  local width = 1024
  local height = 600
  if start.mode ~= 'play' then
    local hidpi = os.getenv("HIDPI")

    if hidpi == 'true' or hidpi == 'TRUE' then
      t.window.width = width * 2
      t.window.height = height * 2
      love.hiDPI = true
    else
      t.window.width = width
      t.window.height = height
    end
    love.fixHeight = t.window.height
    love.fixWidth = t.window.width
    -- Android: use SD card for storage
    t.externalstorage = true

    t.window.title = 'Compy IDE'
  else
    local gp = start.path or ''
    local title = 'Compy Player'
    if string.len(gp) > 0 then
      title = string.format('%s - %s', 'Compy Player', gp)
    end
    t.window.resizable = true
    love.fixHeight = height
    love.fixWidth = width
    t.window.title = title
  end
  love.test_grid_x = 4
  love.test_grid_y = 4

  --- disable unused modules to shorten startup
  t.modules.joystick = false
  t.modules.physics = false


  local hostconf = prequire('host')
  if hostconf then
    hostconf.conf_love(t)
  end
  love.start = start
end
