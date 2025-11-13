Prof = require("controller.profiler")
require("view.view")

require("util.string.string")
require("util.key")
local LANG = require("util.eval")

local messages = {
  user_break = "BREAK into program",
  exit_anykey = "Press any key to exit.",
  exec_error = function(err)
    Log.error((debug.traceback(
      "Error: " .. tostring(err), 1):gsub("\n[^\n]+$", "")
    ))
    return 'Execution error at ' .. err
  end
}

local get_user_input = function()
  if love.state.app_state == 'inspect' then return end
  return love.state.user_input
end
--- @type boolean
local user_update
--- @type boolean
local user_draw

local _supported = {
  'keypressed',
  'keyreleased',
  'textinput',

  'mousemoved',
  'mousepressed',
  'mousereleased',
  'wheelmoved',
  --- custom handlers
  'singleclick',
  'doubleclick',

  'touchmoved',
  'touchpressed',
  'touchreleased',
}

local _C, _mode

--- @param msg string
local function user_error_handler(msg)
  local err = LANG.get_call_error(msg) or ''
  local user_msg = messages.exec_error(err)
  _C:suspend_run(user_msg)
  print(user_msg)
end

--- @param f function
--- @param ...   any
--- @return boolean success
--- @return any result
--- @return any ...
local function wrap(f, ...)
  if _G.web then
    -- local ok, r = pcall(f, ...)
    -- if not ok then
    --   user_error_handler(r)
    -- end
    -- return r
    -- return xpcall(f, user_error_handler, ...)
    --- TODO no error handling, sorry, it leads to a stack overflow
    --- in love.wasm
    return f(...)
  else
    return xpcall(f, user_error_handler, ...)
  end
end

--- @param f function
--- @return function
local function error_wrapper(f)
  return function(...)
    return wrap(f, ...)
  end
end

--- @param userlove table
local set_handlers = function(userlove)
  --- @param key string
  local function hook_if_differs(key)
    local orig = Controller._defaults[key]
    local new = userlove[key]
    if orig and new and orig ~= new then
      --- @type function
      love[key] = error_wrapper(new)
    end
  end

  -- input hooks
  for _, k in ipairs(_supported) do
    hook_if_differs(k)
  end
  -- update - special handling, inner updates
  local up = userlove.update
  if up and up ~= Controller._defaults.update then
    user_update = true
    Controller._userhandlers.update = up
  end

  -- drawing - separate table
  local draw = userlove.draw

  if draw and draw ~= View.main_draw then
    --- @diagnostic disable-next-line: duplicate-set-field
    love.draw = function()
      draw()
      View.drawFPS()
    end
    user_draw = true
  end
end

local click_delay = 0.2
local drift_tolerance = 2.5

local click_count = 0
local click_timer = 0
--- @type Point?
local click_pos = nil

--- @param prev Point?
--- @param cur Point?
--- @return boolean
local function no_drift(prev, cur)
  if prev and cur
  then
    local px, py = prev.x, prev.y
    local cx, cy = cur.x, cur.y
    if px and cx and math.abs(px - cx) < drift_tolerance
    then
      if py and cy and math.abs(py - cy) < drift_tolerance
      then
        return true
      end
    end
  end
  return false
end

--- @class Controller
--- @field _defaults Handlers
--- @field _userhandler Handlers
--- public interface
--- @field set_love_draw function
--- @field setup_callback_handlers function
--- @field set_default_handlers function
--- @field save_user_handlers function
--- @field clear_user_handlers function
--- @field restore_user_handlers function
--- @field user_is_blocking function
Controller = {
  --- @private
  _defaults = {
    singleclick = function() end,
    doubleclick = function() end,
  },
  --- @private
  _userhandlers = {},

  ----------------
  --  keyboard  --
  ----------------
  --- @private
  --- @param C ConsoleController
  set_love_keypressed = function(C)
    local function keypressed(k)
      if Key.ctrl() and Key.shift() then
        if love.DEBUG then
          if k == "1" then
            table.toggle(love.debug, 'show_terminal')
            table.toggle(love.debug, 'show_buffer')
          end
          if k == "2" then
            table.toggle(love.debug, 'show_snapshot')
          end
          if k == "3" then
            table.toggle(love.debug, 'show_canvas')
          end
          if k == "5" then
            table.toggle(love.debug, 'show_input')
          end
        end
      end
      if Key.ctrl() and Key.alt() then
        if love.DEBUG then
          if k == "d" then
            Log.debug(Debug.termdebug(C.model.output.terminal))
          end
        end
      end
      C:keypressed(k)
    end
    Controller._defaults.keypressed = keypressed
    love.keypressed = keypressed
  end,

  --- @private
  --- @param C ConsoleController
  set_love_keyreleased = function(C)
    --- @diagnostic disable-next-line: duplicate-set-field
    local function keyreleased(k)
      C:keyreleased(k)
    end
    Controller._defaults.keyreleased = keyreleased
    love.keyreleased = keyreleased
  end,

  --- @private
  --- @param C ConsoleController
  set_love_textinput = function(C)
    local function textinput(t)
      C:textinput(t)
    end
    Controller._defaults.textinput = textinput
    love.textinput = textinput
  end,

  -------------
  --  mouse  --
  -------------
  --- @private
  --- @param C ConsoleController
  set_love_mousepressed = function(C)
    --- @param x number
    --- @param y number
    --- @param button number
    --- @param touch boolean
    --- @param presses number
    local function mousepressed(x, y, button, touch, presses)
      if love.DEBUG then
        Log.info(string.format('click! {%d, %d}', x, y))
      end
      C:mousepressed(x, y, button, touch, presses)
    end

    Controller._defaults.mousepressed = mousepressed
    love.mousepressed = mousepressed
  end,

  --- @private
  --- @param C ConsoleController
  set_love_mousereleased = function(C)
    --- @param x number
    --- @param y number
    --- @param button number
    --- @param touch boolean
    --- @param presses number
    local function mousereleased(x, y, button, touch, presses)
      C:mousereleased(x, y, button, touch, presses)
    end

    Controller._defaults.mousereleased = mousereleased
    love.mousereleased = mousereleased
  end,

  --- @private
  --- @param C ConsoleController
  set_love_mousemoved = function(C)
    --- @param x number
    --- @param y number
    --- @param dx number
    --- @param dy number
    --- @param touch boolean
    local function mousemoved(x, y, dx, dy, touch)
      C:mousemoved(x, y, dx, dy, touch)
    end

    Controller._defaults.mousemoved = mousemoved
    love.mousemoved = mousemoved
  end,

  --- @private
  --- @param C ConsoleController
  set_love_wheelmoved = function(C)
    --- @param x number
    --- @param y number
    local function wheelmoved(x, y)
      C:wheelmoved(x, y)
    end

    Controller._defaults.wheelmoved = wheelmoved
    love.wheelmoved = wheelmoved
  end,

  -------------
  --  touch  --
  -------------
  --- @private
  --- @param C ConsoleController
  set_love_touchpressed = function(C)
    --- @param id userdata
    --- @param x number
    --- @param y number
    --- @param dx number?
    --- @param dy number?
    --- @param pressure number?
    local function touchpressed(id, x, y, dx, dy, pressure)
      C:touchpressed(id, x, y, dx, dy, pressure)
    end

    Controller._defaults.touchpressed = touchpressed
    love.touchpressed = touchpressed
  end,
  --- @private
  --- @param C ConsoleController
  set_love_touchreleased = function(C)
    --- @param id userdata
    --- @param x number
    --- @param y number
    --- @param dx number?
    --- @param dy number?
    --- @param pressure number?
    local function touchreleased(id, x, y, dx, dy, pressure)
      C:touchreleased(id, x, y, dx, dy, pressure)
    end

    Controller._defaults.touchreleased = touchreleased
    love.touchreleased = touchreleased
  end,
  --- @private
  --- @param C ConsoleController
  set_love_touchmoved = function(C)
    --- @param id userdata
    --- @param x number
    --- @param y number
    --- @param dx number?
    --- @param dy number?
    --- @param pressure number?
    local function touchmoved(id, x, y, dx, dy, pressure)
      C:touchmoved(id, x, y, dx, dy, pressure)
    end

    Controller._defaults.touchmoved = touchmoved
    love.touchmoved = touchmoved
  end,

  --------------
  --  update  --
  --------------
  --- @private
  --- @param C ConsoleController
  set_love_update = function(C)
    local function update(dt)
      if love.PROFILE then
        Prof.update()
      end
      if click_timer > 0 then
        click_timer = click_timer - dt
      end
      if click_timer <= 0 then
        if click_count == 1 then
          -- single click confirmed after delay
          local handler = love.singleclick
          if handler then
            local x, y = love.mouse.getPosition()
            local cur = { x = x, y = y }
            if no_drift(click_pos, cur) then
              handler(x, y)
            end
          end
        elseif click_count >= 2 then
          -- double click detected
          local dbl_handler = love.doubleclick
          if dbl_handler then
            local x, y = love.mouse.getPosition()
            local cur = { x = x, y = y }
            if no_drift(click_pos, cur) then
              dbl_handler(x, y)
            end
          end
        end
        click_count = 0
      end
      local ddr = View.prev_draw
      local ldr = love.draw
      local ui = get_user_input()
      if ldr ~= ddr or ui then
        local function draw()
          if ldr then
            wrap(ldr)
          end
          local user_input = get_user_input()
          if user_input then
            user_input.V:draw(user_input.C:get_input())
          end
        end
        View.prev_draw = draw
        love.draw = draw
      end
      C:pass_time(dt)

      local uup = Controller._userhandlers.update
      if user_update and uup
      then
        wrap(uup, dt)
      end
      if _mode ~= 'play' then
        Controller.snapshot()
      end
      if love.harmony then
        love.harmony.timer_update(dt)
      end
    end

    if not Controller._defaults.update then
      Controller._defaults.update = update
    end
    love.update = update
  end,

  ---------------
  --    draw   --
  ---------------
  --- @private
  --- @param C ConsoleController
  --- @param CV ConsoleView
  set_love_draw = function(C, CV)
    local function draw()
      View.draw(C, CV)
      View.drawFPS()
    end
    love.draw = draw

    View.prev_draw = love.draw
    View.main_draw = love.draw
    View.end_draw = function()
      local w, h = gfx.getDimensions()
      gfx.setColor(Color[Color.white])
      gfx.setFont(C.cfg.view.font)
      gfx.clear()
      gfx.printf(messages.exit_anykey, 0, h / 3, w, "center")
    end
  end,


  --- Quit
  --- @private
  --- @param C ConsoleController
  set_love_quit = function(C)
    local cfg = C.cfg

    local function quit()
      if love.state.app_state == 'shutdown' then
        return false
      end

      if cfg.mode == 'play' then
        C:quit_project()
        love.state.app_state = 'shutdown'
        love.state.user_input = nil

        love.draw = View.end_draw
        return true
      end
      if love.state.app_state == 'running' then
        C:stop_project_run()
        return true
      end
    end
    love.quit = quit
  end,

  --- @private
  snapshot = function()
    if user_draw then
      View.snap_canvas()
    end
  end,

  ----------------
  ---  public  ---
  ----------------
  --- @param CC ConsoleController
  init = function(CC, mode)
    _C = CC
    _mode = mode
  end,
  --- @param C ConsoleController
  --- @param CV ConsoleView
  set_default_handlers = function(C, CV)
    Controller.set_love_keypressed(C)
    Controller.set_love_keyreleased(C)
    Controller.set_love_textinput(C)
    -- SKIPPED textedited - IME support, TODO?

    Controller.set_love_mousemoved(C)
    Controller.set_love_mousepressed(C)
    Controller.set_love_mousereleased(C)
    Controller.set_love_wheelmoved(C)

    Controller.set_love_touchpressed(C)
    Controller.set_love_touchreleased(C)
    Controller.set_love_touchmoved(C)

    --- SKIPPED joystick and gamepad support

    --- intented to run as kiosk app
    --- SKIPPED focus
    --- SKIPPED mousefocus
    --- SKIPPED visible
    --- SKIPPED resize
    --- SKIPPED filedropped
    --- SKIPPED directorydropped

    --- target device has laptop form factor, hence disabled
    --- SKIPPED displayrotated

    --- SKIPPED threaderror
    --- SKIPPED lowmemory

    user_update = false
    Controller.set_love_update(C)
    user_draw = false
    Controller.set_love_draw(C, CV)
    Controller._defaults.draw = View.main_draw
    Controller.set_love_quit(C)
  end,

  --- @param C ConsoleController
  setup_callback_handlers = function(C)
    local cfg = C.cfg
    local playback = cfg.mode == 'play'

    local clear_user_input = function()
      love.state.user_input = nil
    end

    --- @diagnostic disable-next-line: undefined-field
    local handlers = love.handlers

    handlers.keypressed = function(k)
      --- Power shortcuts
      local function quickswitch()
        if Key.ctrl() and k == 't' then
          if love.state.app_state == 'running'
              or love.state.app_state == 'inspect'
              or love.state.app_state == 'project_open'
          then
            C:stop_project_run()
            local st = love.state.editor
            if st then
              C:edit(st.buffer.filename, st)
            else
              C:edit()
            end
          elseif love.state.app_state == 'editor' then
            if C.editor:is_normal_mode() then
              local ed_state = C:finish_edit()
              love.state.editor = ed_state
              C:run_project()
            end
          end
        end
      end
      local function project_state_change()
        if Key.ctrl() then
          if k == "pause" then
            C:suspend_run(messages.user_break)
          end
          if Key.shift() then
            -- Ensure the user can get back to the console
            if k == "q" then
              C:quit_project()
            end
            if k == "s" then
              if love.state.app_state == 'running' then
                C:stop_project_run()
              elseif love.state.app_state == 'editor' then
                C:close_buffer()
              end
            end
            if k == "r" then
              C:reset()
            end
          end
        end
      end
      local function restart()
        if Key.ctrl() and Key.alt() and k == "r" then
          C:restart()
        end
      end
      local function profile()
        if Key.ctrl() and Key.alt() and k == "p" then
          if Key.shift() then
            Prof.stop_profiler()
          else
            -- Prof.start_profiler()
            Prof.start_oneshot()
          end
        end
        if k == "f10" then
          if love.PROFILE.fpsc == 'off' then
            love.PROFILE.fpsc = 'T_L'
          elseif love.PROFILE.fpsc == 'T_L' then
            love.PROFILE.fpsc = 'T_R'
          elseif love.PROFILE.fpsc == 'T_R' then
            love.PROFILE.fpsc = 'off'
          end
        end
      end

      if playback then
        if love.state.app_state == 'shutdown' then
          love.event.quit()
        end
        restart()
        if love.PROFILE then
          profile()
        end
      else
        restart()
        quickswitch()
        if love.PROFILE then
          profile()
        end
        project_state_change()
      end

      local user_input = get_user_input()
      if user_input then
        user_input.C:keypressed(k)
      else
        if love.keypressed then return love.keypressed(k) end
      end
    end

    handlers.textinput = function(t)
      local user_input = get_user_input()
      if user_input then
        user_input.C:textinput(t)
      else
        if love.textinput then return love.textinput(t) end
      end
    end

    handlers.keyreleased = function(k)
      if Key.ctrl() then
        if k == "escape" then
          love.event.quit()
        end
      end
      local user_input = get_user_input()
      if user_input then
        user_input.C:keyreleased(k)
      else
        if love.keyreleased then return love.keyreleased(k) end
      end
    end

    --- @param x integer
    --- @param y integer
    --- @param btn integer
    --- @param touch boolean
    --- @param presses number
    handlers.mousepressed = function(x, y, btn, touch, presses)
      local user_input = get_user_input()
      if user_input then
        user_input.C:mousepressed(x, y, btn, touch, presses)
      else
      end
      if love.mousepressed then
        return love.mousepressed(x, y, btn, touch, presses)
      end
    end

    --- @param x integer
    --- @param y integer
    --- @param btn integer
    --- @param touch boolean
    --- @param presses number
    handlers.mousereleased = function(x, y, btn, touch, presses)
      if btn == 1 then
        click_count = click_count + 1
        click_timer = click_delay
        click_pos = { x = x, y = y }
      end
      local user_input = get_user_input()
      if user_input then
        user_input.C:mousereleased(x, y, btn, touch, presses)
      else
      end
      if love.mousereleased then
        return love.mousereleased(x, y, btn, touch, presses)
      end
    end

    --- @param x number
    --- @param y number
    --- @param dx number
    --- @param dy number
    --- @param touch boolean
    handlers.mousemoved = function(x, y, dx, dy, touch)
      local user_input = get_user_input()
      if user_input then
        user_input.C:mousemoved(x, y, dx, dy, touch)
      else
      end
      if love.mousemoved then
        return love.mousemoved(x, y, dx, dy, touch)
      end
    end

    handlers.userinput = function()
      local user_input = get_user_input()
      if user_input then
        clear_user_input()
      end
    end

    --- @param id userdata
    --- @param x number
    --- @param y number
    --- @param dx number?
    --- @param dy number?
    --- @param pressure number?
    handlers.touchpressed = function(id, x, y, dx, dy, pressure)
      local user_input = get_user_input()
      if user_input then
        user_input.C:touchpressed(id, x, y, dx, dy, pressure)
      else
      end
      if love.touchpressed then
        return love.touchpressed(id, x, y, dx, dy, pressure)
      end
    end

    --- @param id userdata
    --- @param x number
    --- @param y number
    --- @param dx number?
    --- @param dy number?
    --- @param pressure number?
    handlers.touchreleased = function(id, x, y, dx, dy, pressure)
      local user_input = get_user_input()
      if user_input then
        user_input.C:touchreleased(id, x, y, dx, dy, pressure)
      else
      end
      if love.touchreleased then
        return love.touchreleased(id, x, y, dx, dy, pressure)
      end
    end

    --- @param id userdata
    --- @param x number
    --- @param y number
    --- @param dx number?
    --- @param dy number?
    --- @param pressure number?
    handlers.touchmoved = function(id, x, y, dx, dy, pressure)
      local user_input = get_user_input()
      if user_input then
        user_input.C:touchmoved(id, x, y, dx, dy, pressure)
      else
      end
      if love.touchmoved then
        return love.touchmoved(id, x, y, dx, dy, pressure)
      end
    end


    --- @diagnostic disable-next-line: undefined-field
    table.protect(love.handlers)
  end,

  set_user_handlers = set_handlers,

  user_is_blocking = function()
    return (user_update or user_draw)
  end,

  --- @param userlove table
  save_user_handlers = function(userlove)
    --- @param key string
    local function save_if_differs(key)
      local orig = Controller._defaults[key]
      local new = userlove[key]
      if orig and new and orig ~= new then
        Controller._userhandlers[key] = new
      end
    end

    -- input hooks
    for _, a in pairs(_supported) do
      save_if_differs(a)
    end
    save_if_differs('draw')
  end,

  restore_user_handlers = function()
    set_handlers(Controller._userhandlers)
  end,

  clear_user_handlers = function()
    Controller._userhandlers = {}
    View.clear_snapshot()
  end,

  oneshot = function()
    if not love.PROFILE then return end
    Prof.start_oneshot()
  end,

  report = function()
    if not love.PROFILE then return end
    local report = Prof.report()
    if report then
      Log.debug(report)
    end
  end,
}
