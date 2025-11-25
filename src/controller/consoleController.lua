require("view.input.userInputView")
require("controller.editorController")
require("controller.userInputController")


local class = require('util.class')
local LANG = require("util.eval")
local FS = require('util.filesystem')
require("util.key")
require("util.table")
local TerminalTest = require("util.test_terminal")

--- @class ConsoleController
--- @field time number
--- @field model Model
--- @field main_ctrl table
--- @field main_env LuaEnv
--- @field pre_env LuaEnv
--- @field base_env LuaEnv
--- @field project_env LuaEnv
--- @field loaders function[]
--- @field input UserInputController
--- @field editor EditorController
--- @field view ConsoleView?
--- @field cfg Config
--- methods
--- @field edit function
--- @field finish_edit function
ConsoleController = class.create()

--- @param M Model
function ConsoleController.new(M, main_ctrl)
  local env = getfenv()
  local pre_env = table.clone(env)
  local config = M.cfg
  pre_env.font = config.view.font
  local IC = UserInputController(M.input)
  local self = setmetatable({
    time        = 0,
    model       = M,
    main_ctrl   = main_ctrl,
    input       = IC,
    -- console runner env
    main_env    = env,
    -- copy of the application's env before the prep
    pre_env     = pre_env,
    -- the project env where we make the API available
    base_env    = {},
    -- this is the env in which the user project runs
    -- subject to change, for example when switching projects
    project_env = {},

    loaders     = {},

    view        = nil,

    cfg         = config
  }, ConsoleController)
  --- the editor has to know about us
  local EC = EditorController(M.editor, self)
  self.editor = EC
  -- initialize the stub env tables
  ConsoleController.prepare_env(self)
  ConsoleController.prepare_project_env(self)

  return self
end

--- @param V ConsoleView
function ConsoleController:init_view(V)
  self.view = V
  self.input:init_view(V.input)
  self.input:update_view()
end

--- @param name string
--- @param f function
function ConsoleController:cache_loader(name, f)
  self.loaders[name] = f
end

--- @param name string
--- @return function?
function ConsoleController:get_loader(name)
  return self.loaders[name]
end

--- @param f function
--- @param cc ConsoleController
--- @param project_path string?
--- @return boolean success
--- @return string? errmsg
local function run_user_code(f, cc, project_path)
  local gfx = love.graphics
  local output = cc.model.output
  local env = cc:get_base_env()

  gfx.setCanvas(cc:get_canvas())
  local ok, call_err
  if project_path then
    env = cc:get_project_env()
  end
  ok, call_err = pcall(f)
  if project_path and ok then -- user project exec
    if love.PROFILE then
      love.PROFILE.frame = 0
      love.PROFILE.report = {}
    end
    cc.main_ctrl.set_user_handlers(env['love'])
  end
  output:restore_main()
  gfx.setCanvas()
  if not ok then
    local msg = LANG.get_call_error(call_err)
    return false, msg
  end
  return true
end

--- @param cc ConsoleController
local function close_project(cc)
  local ok = cc:close_project()
  if ok then
    print('Project closed')
  else
    Log.err('error in closing')
  end
end

--- @private
--- @param name string
--- @return string[]?
function ConsoleController:_readfile(name)
  local PS              = self.model.projects
  local p               = PS.current
  local ok, text_or_err = p:readfile(name)
  if ok then
    return text_or_err
  else
    print(text_or_err)
  end
end

--- @private
--- @param name string
--- @param content string[]
--- @return boolean success
--- @return string? err
function ConsoleController:_writefile(name, content)
  local P = self.model.projects
  local p = P.current
  local text = string.unlines(content)
  return p:writefile(name, text)
end

function ConsoleController:run_project(name)
  if love.state.app_state == 'inspect' or
      love.state.app_state == 'running'
  then
    self.input:set_error(
      { "There's already a project running!" })
    return
  end
  local P   = self.model.projects
  local cur = P.current
  local ok
  if cur and cur == name then
    ok = true
  else
    ok = self:open_project(name, false)
  end

  if ok then
    local runner_env        = self:get_project_env()
    local f, load_err, path = P:run(name, runner_env)
    if f then
      local n = name or P.current.name or 'project'
      Log.info('Running \'' .. n .. '\'')
      local rok, run_err = run_user_code(f, self, path)
      if rok then
        if self.main_ctrl.user_is_blocking() then
          love.state.app_state = 'running'
        end
      else
        print('Error: ', run_err)
      end
    else
      --- TODO extract error message here
      print(load_err)
    end
  end
end

_G.o_require = _G.require
--- @param cc ConsoleController
--- @param name string
local function project_require(cc, name)
  local P = cc.model.projects
  local fn = name .. '.lua'
  local open = P.current
  if open then
    local chunk = open:load_file(fn)
    local pr_env = cc:get_project_env()
    if chunk then
      setfenv(chunk, pr_env)
      return chunk()
    else
      --- hack around love.js not having the bit lib
      if name == 'bit' and _G.web then
        ---@diagnostic disable-next-line: inject-field
        pr_env.bit = o_require('util.luabit')
      end
    end
    --- TODO: is it desirable to allow out-of-project require?
    -- else
    -- _require(name)
  end
end

function ConsoleController.prepare_env(cc)
  local prepared            = cc.main_env
  prepared.gfx              = love.graphics

  local P                   = cc.model.projects

  prepared.require          = function(name)
    return project_require(cc, name)
  end

  --- @param f function
  local check_open_pr       = function(f, ...)
    if not P.current then
      print(P.messages.no_open_project)
    else
      return f(...)
    end
  end

  prepared.list_projects    = function()
    local ps = P:list()
    if ps:is_empty() then
      -- no projects, display a message about it
      print(P.messages.no_projects)
    else
      -- list projects
      cc.model.output:reset()
      print(P.messages.list_header)
      for _, p in ipairs(ps) do
        print('> ' .. p.name)
      end
    end
  end

  --- @param name string
  local open_project        = function(name)
    return cc:open_project(name)
  end

  prepared.project          = open_project

  prepared.close_project    = function()
    close_project(cc)
  end

  prepared.current_project  = function()
    if P.current and P.current.name then
      print('Currently open project: ' .. P.current.name)
    else
      print(P.messages.no_open_project)
    end
  end

  prepared.example_projects = function()
    local ok, err = P:deploy_examples()
    if not ok then
      print('err: ' .. err)
    end
  end

  prepared.clone            = function(old, new)
    local ok, err = P:clone(old, new)
    if not ok then
      print(err)
    end
  end

  prepared.list_contents    = function()
    return check_open_pr(function()
      local p = P.current
      local items = p:contents()
      print(P.messages.project_header(p.name))
      for _, f in pairs(items) do
        print('• ' .. f.name)
      end
    end)
  end

  --- @param name string
  --- @return string[]?
  prepared.readfile         = function(name)
    return check_open_pr(cc._readfile, cc, name)
  end

  --- @param name string
  --- @param content string[]
  prepared.writefile        = function(name, content)
    return check_open_pr(function()
      local p = P.current
      local fpath = p:get_path(name)
      local ex = FS.exists(fpath)
      if ex then
        -- TODO: confirm overwrite
      end
      local ok, err = cc:_writefile(name, content)
      if ok then
        print(name .. ' written')
      else
        print(err)
      end
    end)
  end

  --- @param name string
  prepared.edit             = function(name)
    return check_open_pr(cc.edit, cc, name)
  end

  prepared.run_project      = function(name)
    cc:run_project(name)
  end

  local terminal            = cc.model.output.terminal
  local compy_namespace     = {
    terminal = {
      --- @param x number
      --- @param y number
      gotoxy = function(x, y)
        return terminal:move_to(x, y)
      end,
      show_cursor = function()
        return terminal:show_cursor()
      end,
      hide_cursor = function()
        return terminal:hide_cursor()
      end,
      clear = function()
        return terminal:clear()
      end
    }
  }
  prepared.compy            = compy_namespace
  prepared.tty              = compy_namespace.terminal

  prepared.run              = prepared.run_project

  prepared.eval             = LANG.eval
  prepared.print_eval       = LANG.print_eval

  prepared.appver           = function()
    local ver = FS.read('ver.txt', true)
    if ver then print(ver) end
  end

  prepared.quit             = function()
    love.event.quit()
  end
end

--- API functions for the user
--- @param cc ConsoleController
function ConsoleController.prepare_project_env(cc)
  require("controller.userInputController")
  require("model.input.userInputModel")
  require("view.input.userInputView")
  local cfg                   = cc.model.cfg
  ---@type table
  local project_env           = cc:get_pre_env_c()
  project_env.gfx             = love.graphics

  project_env.require         = function(name)
    return project_require(cc, name)
  end

  --- @param msg string?
  project_env.pause           = function(msg)
    cc:suspend_run(msg)
  end
  project_env.stop            = function()
    cc:stop_project_run()
  end

  project_env.continue        = function()
    if love.state.app_state == 'inspect' then
      -- resume
      love.state.app_state = 'running'
      cc.main_ctrl.restore_user_handlers()
    else
      print('No project halted')
    end
  end

  project_env.close_project   = function()
    close_project(cc)
  end

  local ui_model, ui_con, input_ref
  local create_input_handle   = function()
    input_ref = table.new_reftable()
  end

  --- @param eval Evaluator
  --- @param prompt string?
  --- @param init str?
  local input                 = function(eval, prompt, init)
    if love.state.user_input then
      return -- there can be only one
    end

    if not input_ref then return end
    ui_model = UserInputModel(cfg, eval, true, prompt)
    ui_model:set_text(init)
    ui_con = UserInputController(ui_model, input_ref, true)
    local view = UserInputView(cfg.view, ui_con)
    ui_con:init_view(view)
    ui_con:update_view()

    love.state.user_input = {
      M = ui_model, C = ui_con, V = view
    }
    return input_ref
  end

  project_env.user_input      = function()
    create_input_handle()
    return input_ref
  end

  --- @param prompt string?
  --- @param init str?
  project_env.input_code      = function(prompt, init)
    return input(InputEvalLua, prompt, init)
  end
  --- @param prompt string?
  --- @param init str?
  project_env.input_text      = function(prompt, init)
    return input(InputEvalText, prompt, init)
  end

  --- @param content str
  project_env.write_to_input  = function(content)
    if not love.state.user_input then
      return
    end
    ui_model:set_text(content)
    ui_con:update_view()
  end

  --- @param filters table
  --- @param prompt string?
  project_env.validated_input = function(filters, prompt)
    return input(ValidatedTextEval(filters), prompt)
  end

  if love.debug then
    project_env.astv_input = function()
      return input(LuaEditorEval)
    end
  end

  --- @param name string
  project_env.edit       = function(name)
    return cc:edit(name)
  end

  project_env.eval       = LANG.eval
  project_env.print_eval = LANG.print_eval

  local base             = table.clone(project_env)
  local project          = table.clone(project_env)
  cc:_set_base_env(base)
  cc:_set_project_env(project)
end

---@param dt number
function ConsoleController:pass_time(dt)
  self.time = self.time + dt
  self.model.output.terminal:update(dt)
end

---@return number
function ConsoleController:get_timestamp()
  return self.time
end

function ConsoleController:evaluate_input()
  local inter = self.input

  local text = inter:get_text()
  if text:is_empty() then return end
  local eval = inter:get_eval()

  local eval_ok, res = inter:evaluate()

  if eval_ok and not string.is_non_empty(res) then
    return
  end

  if eval and eval.parser then
    if eval_ok then
      local code = string.unlines(text)
      local run_env = (function()
        if love.state.app_state == 'inspect' then
          return self:get_project_env()
        end
        return self:get_console_env()
      end)()
      local f, load_err = codeload(code, run_env)
      if f then
        local _, err = run_user_code(f, self)
        if err then
          inter:set_error({ err })
        else
          inter:clear()
        end
      else
        Log.error('Load error:', LANG.get_call_error(load_err))
        inter:set_error(load_err)
      end
    else
      local eval_err = res
      if eval_err then
        inter:set_error(eval_err)
      end
    end
  end
end

function ConsoleController:_reset_executor_env()
  self:_set_project_env(table.clone(self.base_env))
end

function ConsoleController:reset()
  self:quit_project()
  self.input:reset(true) -- clear history
end

function ConsoleController:restart()
  self:stop_project_run()
  self:run_project()
end

---@return LuaEnv
function ConsoleController:get_console_env()
  return self.main_env
end

---@return LuaEnv
function ConsoleController:get_pre_env_c()
  return table.clone(self.pre_env)
end

---@return LuaEnv
function ConsoleController:get_project_env()
  return self.project_env
end

---@return LuaEnv
function ConsoleController:get_base_env()
  return self.base_env
end

---@param t LuaEnv
function ConsoleController:_set_project_env(t)
  self.project_env = t
end

---@param t LuaEnv
function ConsoleController:_set_base_env(t)
  self.base_env = t
  table.protect(t)
end

function ConsoleController:suspend()
  if love.state.app_state ~= 'snapshot' then
    return
  end
  local runner_env = self:get_project_env()
  Log.info('Suspending project run')
  love.state.app_state = 'inspect'
  local msg = love.state.suspend_msg
  if msg then
    self.input:set_error({ tostring(msg) })
    love.state.suspend_msg = nil
  end

  self.model.output:invalidate_terminal()

  self.main_ctrl.save_user_handlers(runner_env['love'])
  self.main_ctrl.set_default_handlers(self, self.view)
end

--- @param msg string?
function ConsoleController:suspend_run(msg)
  if love.state.app_state ~= 'running' then
    return
  end
  love.state.app_state = 'snapshot'
  love.state.suspend_msg = msg
end

--- @param name string
--- @param play boolean
--- @return boolean success
function ConsoleController:open_project(name, play)
  local P = self.model.projects
  if not name then
    print('No project name provided!')
    return false
  end
  local cur = P.current
  if cur then
    self:close_project()
  end

  local open, create, err = P:opreate(name, play)
  local ok = open or create
  if ok then
    local project_loader = (function()
      local cached = self.loaders[name]
      if cached then
        return cached
      else
        local loader = P.current:get_loader()
        self:cache_loader(name, loader)
        return loader
      end
    end)()
    if not table.is_member(package.loaders, project_loader)
    then
      table.insert(package.loaders, 1, project_loader)
    end
    love.state.app_state = 'project_open'
  end
  if open then
    print('Project ' .. name .. ' opened')
  elseif create then
    print('Project ' .. name .. ' created')
  else
    print(err)
  end
  return ok
end

--- @return boolean success
function ConsoleController:close_project()
  local P = self.model.projects
  local open = P.current
  if open then
    local name = P.current.name
    local ok = P:close()
    local lf = self:get_loader(name)
    if lf then
      table.delete_by_value(package.loaders, lf)
    end
    self:_reset_executor_env()
    self.model.output:clear_canvas()
    View.clear_snapshot()
    love.state.app_state = 'ready'
    return ok
  end
  return true
end

function ConsoleController:stop_project_run()
  self.main_ctrl.set_default_handlers(self, self.view)
  self.main_ctrl.set_love_update(self)
  love.state.user_input = nil
  View.clear_snapshot()
  self.main_ctrl.set_love_draw(self, self.view)
  self.main_ctrl.clear_user_handlers()
  self.main_ctrl.report()
  love.state.app_state = 'project_open'
end

function ConsoleController:quit_project()
  self:stop_project_run()
  self:close_project()
  self.model.output:reset()
  self.input:reset()
end

--- @param name string
--- @param state EditorState
function ConsoleController:edit(name, state)
  if love.state.app_state == 'running' then return end

  local PS = self.model.projects
  local p  = PS.current
  local filename
  if state and state.buffer then
    filename = state.buffer.filename
  else
    filename = name or ProjectService.MAIN
  end
  local fpath = p:get_path(filename)
  local ex    = FS.exists(fpath)
  local text
  if ex then
    text = self:_readfile(filename)
  end

  if love.state.app_state ~= 'editor' then
    love.state.prev_state = love.state.app_state
    love.state.app_state = 'editor'
  end
  local save = function(newcontent)
    return self:_writefile(filename, newcontent)
  end

  self.editor:open(filename, text, save)
  self.editor:restore_state(state)
end

--- @return EditorState?
function ConsoleController:close_buffer()
  self.editor:close_buffer()
end

--- @return EditorState?
function ConsoleController:finish_edit()
  self.editor:save_state()
  local name, newcontent = self.editor:close()
  local ok, err = self:_writefile(name, newcontent)
  if ok then
    love.state.app_state = love.state.prev_state
    love.state.prev_state = nil
    --- TODO clear bufferlist
    return self.editor:get_state()
  else
    print(err)
  end
end

--- Handlers ---

--- @param t string
function ConsoleController:textinput(t)
  if love.state.app_state == 'editor' then
    self.editor:textinput(t)
  elseif self.cfg.mode == 'play' then
    --- console is disabled in this mode
  else
    local input = self.input
    if input:has_error() then
      input:clear_error()
    else
      if Key.ctrl() and Key.shift() then
        return
      end
      input:textinput(t)
    end
  end
end

--- @param k string
function ConsoleController:keypressed(k)
  local input = self.input

  local function terminal_test()
    local out = self.model.output
    if not love.state.testing then
      love.state.testing = 'running'
      input:cancel()
      TerminalTest.test(out.terminal)
    elseif love.state.testing == 'waiting' then
      TerminalTest.reset(out.terminal)
      love.state.testing = false
    end
  end

  if love.state.app_state == 'editor' then
    self.editor:keypressed(k)
  else
    if love.state.testing == 'running' then
      return
    end
    if love.state.testing == 'waiting' then
      terminal_test()
      return
    end

    if input:has_error() then
      if k == 'space' or Key.is_enter(k)
          or k == "up" or k == "down" then
        input:clear_error()
      end
      return
    end

    if k == "pageup" then
      input:history_back()
    end
    if k == "pagedown" then
      input:history_fwd()
    end
    local limit = input:keypressed(k)
    if limit then
      if k == "up" then
        input:history_back()
      end
      if k == "down" then
        input:history_fwd()
      end
    end
    if not Key.shift() and Key.is_enter(k) then
      if not input:has_error() then
        self:evaluate_input()
      end
    end

    -- Ctrl held
    if Key.ctrl() then
      if k == "l" then
        self.model.output:reset()
      end
      if love.DEBUG then
        if Key.alt() and k == 't' then
          terminal_test()
          return
        end
      end
    end
  end
  input:update_view()
end

--- @param k string
function ConsoleController:keyreleased(k)
  self.input:keyreleased(k)
  self.input:update_view()
end

--- @param x integer
--- @param y integer
--- @param btn integer
--- @param touch boolean
--- @param presses number
function ConsoleController:mousepressed(
    x, y, btn, touch, presses)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.mouse_enabled then
      self.editor.input:mousepressed(x, y, btn, touch, presses)
    end
  else
    self.input:mousepressed(x, y, btn, touch, presses)
  end
end

--- @param x integer
--- @param y integer
--- @param btn integer
--- @param touch boolean
--- @param presses number
function ConsoleController:mousereleased(
    x, y, btn, touch, presses)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.mouse_enabled then
      self.editor.input:mousereleased(x, y, btn, touch, presses)
    end
  else
    self.input:mousereleased(x, y, btn, touch, presses)
  end
end

--- @param x number
--- @param y number
--- @param dx number
--- @param dy number
--- @param touch boolean
function ConsoleController:mousemoved(x, y, dx, dy, touch)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.mouse_enabled then
      self.editor.input:mousemoved(x, y, dx, dy, touch)
    end
  else
    self.input:mousemoved(x, y, dx, dy, touch)
  end
end

--- @param x number
--- @param y number
function ConsoleController:wheelmoved(x, y)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.mouse_enabled then
      self.editor.input:wheelmoved(x, y)
    end
  else
    self.input:wheelmoved(x, y)
  end
end

--- @param id userdata
--- @param x number
--- @param y number
--- @param dx number?
--- @param dy number?
--- @param pressure number?
function ConsoleController:touchpressed(id, x, y,
                                        dx, dy, pressure)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.touch_enabled then
      self.editor.input:touchpressed(id, x, y, dx, dy, pressure)
    end
  else
    self.input:touchpressed(id, x, y, dx, dy, pressure)
  end
end

--- @param id userdata
--- @param x number
--- @param y number
--- @param dx number?
--- @param dy number?
--- @param pressure number?
function ConsoleController:touchreleased(id, x, y,
                                         dx, dy, pressure)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.touch_enabled then
      self.editor.input:touchreleased(id, x, y,
        dx, dy, pressure)
    end
  else
    self.input:touchreleased(id, x, y, dx, dy, pressure)
  end
end

--- @param id userdata
--- @param x number
--- @param y number
--- @param dx number?
--- @param dy number?
--- @param pressure number?
function ConsoleController:touchmoved(id, x, y,
                                      dx, dy, pressure)
  if love.state.app_state == 'editor' then
    if self.cfg.editor.touch_enabled then
      self.editor.input:touchmoved(id, x, y, dx, dy, pressure)
    end
  else
    self.input:touchmoved(id, x, y, dx, dy, pressure)
  end
end

--- @return Terminal
function ConsoleController:get_terminal()
  return self.model.output.terminal
end

--- @return love.Canvas
function ConsoleController:get_canvas()
  return self.model.output.canvas
end

--- @return ViewData
function ConsoleController:get_viewdata()
  return {
    w_error = self.input:get_wrapped_error(),
  }
end

function ConsoleController:autotest()
  --- @diagnostic disable-next-line undefined-global
  local autotest = prequire('tests.autotest')
  if autotest then
    autotest(self)
  end
end
