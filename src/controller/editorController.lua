require("model.interpreter.eval.evaluator")
require("controller.userInputController")
require("controller.searchController")
require("view.input.customStatus")

local class = require('util.class')

--- @param M EditorModel
--- @oaram CC ConsoleController
local function new(M, CC)
  return {
    input = UserInputController(M.input, nil, true),
    model = M,
    search = SearchController(
      M.search,
      UserInputController(M.search.input, nil, true)
    ),
    console = CC,
    view = nil,
    mode = 'edit',
  }
end

--- @alias EditorMode
--- | 'edit' --- default
--- | 'reorder'
--- | 'search'

--- @class EditorController
--- @field model EditorModel
--- @field input UserInputController
--- @field search SearchController
--- @field console ConsoleController
--- @field view EditorView?
--- @field state EditorState?
--- @field mode EditorMode
EditorController = class.create(new)

--- @param v EditorView
function EditorController:init_view(v)
  self.view = v
  self.input:init_view(self.view.input)
end

--- @param name string
--- @param content str?
--- @param save function
function EditorController:open(name, content, save)
  local w = self.model.cfg.view.drawableChars
  local is_lua = string.match(name, '.lua$')
  local is_md = string.match(name, '.md$')
  local ch, hl, pp, tr

  if is_lua then
    self.input:set_eval(LuaEditorEval)
    local luaEval = LuaEval()
    local parser = luaEval.parser
    if not parser then return end
    hl = luaEval.highlighter
    --- @param t string
    --- @param single boolean
    ch = function(t, single)
      return parser.chunker(t, w, single)
    end
    pp = function(t)
      return parser.pprint(t, w)
    end
    tr = function(code)
      return parser.trunc(code, self.model.cfg.view.fold_lines)
    end
  elseif is_md then
    local mdEval = MdEval()
    hl = mdEval.highlighter
    self.input:set_eval(mdEval)
  else
    self.input:set_eval(TextEval)
  end

  local b = BufferModel(name, content, save, ch, hl, pp, tr)
  self.model.buffers:push_front(b)
  self.view:open(b)
  self:update_status()
  self:set_state()
  self.input:update_view()
end

--- @private
function EditorController:_dump_bufferlist()
  for i, v in ipairs(self.model.buffers) do
    Log.debug(i, v.name)
  end
  orig_print()
end

function EditorController:follow_require()
  local buf = self:get_active_buffer()
  if not buf.semantic then return end
  local bn = buf:get_selection()
  local reqs = buf.semantic.requires
  local reqsel = table.find_by_v(reqs, function(r)
    return r.block == bn
  end)

  if reqsel then
    local name = reqsel.name
    self.console:edit(name .. '.lua')
  else
    self:pop_buffer()
  end
end

function EditorController:pop_buffer()
  local bs = self.model.buffers
  local n_buffers = bs:length()
  if n_buffers < 2 then return end
  bs:pop_front()
  local b = bs:first()
  self.view:get_current_buffer():open(b)
  self:update_status()
end

function EditorController:close_buffer()
  local bs = self.model.buffers
  local n_buffers = bs:length()
  if n_buffers < 2 then
    -- Log.debug('fin', n_buffers)
    self.console:finish_edit()
  else
    -- Log.debug(':bd', n_buffers)
    self:pop_buffer()
  end
end

--- @param m EditorMode
--- @return boolean
local function is_normal(m)
  return m == 'edit'
end

--- @param mode EditorMode
function EditorController:set_mode(mode)
  local buf = self:get_active_buffer()
  local set_reorg = function()
    self:save_state()
  end
  local init_search = function()
    local db = buf.semantic
    if db then
      self:save_state()
      local ds = db.definitions
      self.search:load(ds)
    end
  end

  local current = self.mode
  if is_normal(current) then
    if mode == 'reorder' then
      set_reorg()
    end
    if mode == 'search' then
      init_search()
    end
    self.mode = mode
  else
    --- currently in a special mode, only return is allowed
    if is_normal(mode) then
      self.mode = mode
    end
  end
  Log.info('-- ' .. string.upper(mode) .. ' --')
  self:update_status()
end

--- @return EditorMode
function EditorController:get_mode()
  return self.mode
end

--- @return boolean
function EditorController:is_normal_mode()
  return is_normal(self.mode)
end

--- @param clipboard string
function EditorController:set_clipboard(clipboard)
  self.state.clipboard = clipboard
end

--- @return string
function EditorController:get_clipboard()
  return self.state.clipboard
end

--- @param clipboard string?
function EditorController:set_state(clipboard)
  --- TODO: multibuffer support
  local buf = self:get_active_buffer()
  local bid = buf:get_id()
  local buf_view_state = self.view:get_buffer(bid):get_state()
  if self.state then
    self.state.buffer = buf_view_state
    self.state.moved = buf:get_selection()
    if clipboard then self:set_clipboard(clipboard) end
  else
    self.state = {
      buffer = buf_view_state,
      clipboard = clipboard,
      moved = buf:get_selection()
    }
  end
end

--- @return EditorState
function EditorController:get_state()
  return self.state
end

function EditorController:save_state()
  --- TODO: multibuffer support
  self:set_state(love.system.getClipboardText())
end

--- @param state EditorState?
function EditorController:restore_state(state)
  --- TODO: multibuffer support
  if state then
    local buf = self:get_active_buffer()
    local sel = state.buffer.selection
    local off = state.buffer.offset
    buf:set_selection(sel)
    self.view:get_current_buffer():scroll_to(off)
    local clip = state.clipboard
    if string.is_non_empty_string(clip) then
      love.system.setClipboardText(clip or '')
    end
  end
end

--- @return {name: string, content: string[]}[]
function EditorController:close()
  self.input:clear()
  local bfs = self.model:get_buffers_content()
  self.model.buffers = Dequeue()
  self.view.buffers = {}
  --- TODO is this needed?
  return bfs
end

--- @return BufferModel
function EditorController:get_active_buffer()
  return self.model.buffers:first()
end

--- @return Id
function EditorController:get_active_buffer_id()
  local buf = self:get_active_buffer()
  return buf:get_id()
end

--- @private
--- @param sel integer
--- @return CustomStatus
function EditorController:_generate_status(sel)
  --- @type BufferModel
  local buffer = self:get_active_buffer()
  local len = buffer:get_content_length() + 1
  local bufview = self.view:get_buffer(buffer:get_id())
  local more = bufview.content:get_more()
  local cs
  local m = self.mode
  local ct = bufview.content_type
  if ct == 'lua' then
    local range = bufview.content:get_block_app_pos(sel)
    cs = CustomStatus(buffer.name, ct, len, more, sel, m, range)
  else
    cs = CustomStatus(buffer.name, ct, len, more, sel, m)
  end

  return cs
end

function EditorController:update_status()
  local sel = self:get_active_buffer():get_selection()
  local cs = self:_generate_status(sel)
  self.input:set_custom_status(cs)
end

--- @param t string
function EditorController:textinput(t)
  self.view:update_input()
  if self.mode == 'edit' then
    local input = self.model.input
    if input:has_error() then
      input:clear_error()
    else
      if Key.ctrl() and Key.shift() then
        return
      end
      self.input:textinput(t)
    end
  elseif self.mode == 'search' then
    self.search:textinput(t)
  end
end

--- @return InputDTO
function EditorController:get_input()
  return self.input:get_input()
end

--- @param buf BufferModel
function EditorController:save(buf)
  local ok, err = buf:save()
  if not ok then Log.error("can't save: ", err) end
end

---------------------------
---  keyboard handlers  ---
---------------------------

--- @private
--- @param go fun(nt: string[]|Block[])
function EditorController:_handle_submit(go)
  local inter = self.input
  local raw = inter:get_text()

  local buf = self:get_active_buffer()
  local ct = buf.content_type
  if ct == 'lua' then
    if not string.is_non_empty_string_array(raw) then
      local sel = buf:get_selection()
      local block = buf:get_content():get(sel)
      if not block then return end
    else
      local _, raw_chunks = buf.chunker(raw, true)
      local pretty = buf.printer(raw)
      if pretty then
        inter:set_text(pretty)
      else
        --- fallback to original in case of unparse-able input
        pretty = raw
      end
      local ok, res = inter:evaluate()
      local _, chunks = buf.chunker(pretty, true)
      if ok then
        if #chunks < #raw_chunks then
          local rc = raw_chunks
          if rc[1].tag == 'empty' then
            table.insert(chunks, 1, Empty(0))
          end
          if rc[#rc].tag == 'empty' then
            local li = chunks[#chunks].pos.fin
            table.insert(chunks, Empty(li + 1))
          end
        end
        go(chunks)
      else
        local eval_err = res
        if eval_err then
          inter:set_error(eval_err)
        end
      end
    end
  else
    go(raw)
  end
end

--- @private
--- @param dir VerticalDir
--- @param by integer?
--- @param warp boolean?
--- @param moved integer?
function EditorController:_move_sel(dir, by, warp, moved)
  local buf = self:get_active_buffer()
  if self.input:has_error() then return end

  --- @type boolean
  local mv = (function()
    if moved then return true end
    return false
  end)()
  local m = buf:move_selection(dir, by, warp, mv)
  if m then
    if mv then self.view:refresh(moved) end
    self.view:get_current_buffer():follow_selection()
    self:update_status()
  end
end

--- @private
--- @param dir VerticalDir
--- @param warp boolean?
--- @param by integer?
function EditorController:_scroll(dir, warp, by)
  self.view:get_current_buffer():scroll(dir, by, warp)
  self:update_status()
end

--- @private
--- @param save boolean
function EditorController:_reorg(save)
  local moved = self.state.moved
  if not moved then return end

  local buf = self:get_active_buffer()
  if save then
    local target = buf:get_selection()
    buf:move(moved, target)
    buf:rechunk()
    self:save(buf)
  else
    buf:set_selection(moved)
    self:restore_state(self:get_state())
  end
  self.view:refresh()

  self:set_mode('edit')
end

--- @private
--- @param k string
function EditorController:_reorg_mode_keys(k)
  if k == 'escape' then
    self:_reorg(false)
  end
  if Key.is_enter(k) then
    self:_reorg(true)
  end

  local function navigate()
    -- move selection
    if k == "up" then
      self:_move_sel('up', nil, nil, self.state.moved)
    end
    if k == "down" then
      self:_move_sel('down', nil, nil, self.state.moved)
    end
    if k == "home" then
      self:_move_sel('up', nil, true, self.state.moved)
    end
    if k == "end" then
      self:_move_sel('down', nil, true, self.state.moved)
    end

    -- scroll
    if not Key.shift()
        and k == "pageup" then
      self:_scroll('up', Key.ctrl())
    end
    if not Key.shift()
        and k == "pagedown" then
      self:_scroll('down', Key.ctrl())
    end
    if Key.shift()
        and k == "pageup" then
      self:_scroll('up', false, 1)
    end
    if Key.shift()
        and k == "pagedown" then
      self:_scroll('down', false, 1)
    end
  end

  navigate()
end

function EditorController:_search_mode_keys(k)
  if k == 'escape' then
    self:set_mode('edit')
    self.search:clear()
    return
  end

  self.input:update_view()
  local jump = self.search:keypressed(k)
  if jump then
    local buf = self:get_active_buffer()
    local bn = jump.block
    local ln = jump.line - 1
    buf:set_selection(bn)
    self.view:get_current_buffer():scroll_to_line(ln)
    self:set_mode('edit')
    self.search:clear()
  end
end

--- @private
--- @param k string
function EditorController:_normal_mode_keys(k)
  local input          = self.input
  local inputView      = self.view.input
  local is_empty       = input:is_empty()
  local at_limit_start = inputView:is_at_limit('up')
  local at_limit_end   = inputView:is_at_limit('down')
  local passthrough    = true
  local block_input    = function() passthrough = false end
  --- @type BufferModel
  local buf            = self:get_active_buffer()

  local function newline()
    if Key.is_enter(k) then
      --- insert empty block if input is empty
      if is_empty
          and not Key.ctrl()
          and Key.shift()
          and not Key.alt() then
        buf:insert_newline()
        self:save(buf)
        self.view:refresh()
        block_input()
      end
      --- insert empty block regardless
      if Key.ctrl()
          and not Key.shift()
          and not Key.alt() then
        local r = buf:insert_newline()
        self:save(buf)
        if r then
          local l = buf.loaded
          self:_move_sel('down', 1)
          if l then buf:set_loaded() end
        end
        self.view:refresh()
        block_input()
      end
    end
  end

  local function delete_block()
    local t = string.unlines(buf:get_selected_text())
    buf:delete_selected_text()
    love.system.setClipboardText(t)
    self:save(buf)
    self.view:refresh()
  end

  local function paste()
    local t = love.system.getClipboardText()
    input:add_text(t)
  end
  local function copy()
    local t = string.unlines(buf:get_selected_text())
    love.system.setClipboardText(t)
    self:set_clipboard(t)
    block_input()
  end
  local function cut()
    copy()
    delete_block()
  end

  local function copycut()
    if Key.ctrl() then
      if k == "c" or k == "insert" then
        copy()
        block_input()
      end
      if k == "x" then
        cut()
        block_input()
      end
    end
    if Key.shift() then
      if k == "delete" then
        cut()
        block_input()
      end
    end
  end
  local function paste_k()
    if (Key.ctrl() and k == "v")
        or (Key.shift() and k == "insert")
    then
      paste()
      block_input()
    end
  end

  if is_empty then
    copycut()
  end
  newline()

  paste_k()

  --- @param add boolean?
  local function load_selection(add)
    local t = buf:get_selected_text()
    if string.is_non_empty(t) then
      buf:set_loaded()
    else
      buf:clear_loaded()
    end
    if add then
      local c = input:get_cursor_info().cursor
      input:add_text(t)
      input:set_cursor(c)
    else
      input:set_text(t)
      input:jump_home()
    end
  end


  --- handlers
  local function submit()
    if not Key.ctrl() and not Key.shift() and Key.is_enter(k) then
      local bufv = self.view:get_current_buffer()
      local function go(newtext)
        if bufv:is_selection_visible() then
          if buf:loaded_is_sel(true) then
            local _, n = buf:replace_selected_text(newtext)
            buf:clear_loaded()
            self:save(buf)
            input:clear()
            self.view:refresh()
            self:_move_sel('down', n)
            load_selection()
            self:update_status()
          else
            buf:select_loaded()
            bufv:follow_selection()
          end
        else
          bufv:follow_selection()
        end
      end

      self:_handle_submit(go)
    end
  end
  local function load()
    if not Key.ctrl() and
        not Key.shift()
        and k == "escape" then
      load_selection()
    end
    if not Key.ctrl() and
        Key.shift() and
        k == "escape" then
      load_selection(true)
    end
  end
  local function delete()
    if Key.ctrl() then
      if k == "delete"
          or (k == "y" and is_empty) then
        delete_block()
        block_input()
      end
    end
  end
  local function navigate()
    -- move selection
    if Key.ctrl() then
      if k == "up" then
        self:_move_sel('up')
        block_input()
      end
      if k == "down" then
        self:_move_sel('down')
        block_input()
      end
      if k == "home" then
        self:_move_sel('up', nil, true)
      end
      if k == "end" then
        self:_move_sel('down', nil, true)
      end
    else
      if k == "up" and at_limit_start then
        self:_move_sel('up')
        block_input()
      end
      if k == "down" and at_limit_end then
        self:_move_sel('down')
        block_input()
      end
    end

    -- scroll
    if not Key.shift()
        and k == "pageup" then
      self:_scroll('up', Key.ctrl())
    end
    if not Key.shift()
        and k == "pagedown" then
      self:_scroll('down', Key.ctrl())
    end
    if Key.shift()
        and k == "pageup" then
      self:_scroll('up', false, 1)
    end
    if Key.shift()
        and k == "pagedown" then
      self:_scroll('down', false, 1)
    end

    -- step into
    if Key.ctrl() then
      if k == "o" then
        self:follow_require()
      end
    end
  end
  local function clear()
    if Key.ctrl() and k == "w" then
      buf:clear_loaded()
      input:clear()
    end
  end

  submit()
  load()
  delete()
  navigate()
  clear()

  if passthrough then
    input:keypressed(k)
  end
end

--- @param k string
function EditorController:keypressed(k)
  self.input:update_view()
  local mode = self.mode

  if Key.ctrl() then
    if k == "m" then
      self:set_mode('reorder')
    end
    if k == "f" then
      self:set_mode('search')
    end
  end

  if mode == 'reorder' then
    self:_reorg_mode_keys(k)
  elseif mode == 'search' then
    self:_search_mode_keys(k)
  else
    self:_normal_mode_keys(k)
  end

  if love.debug then
    local buf = self:get_active_buffer()
    local bufview = self.view:get_buffer(buf:get_id())
    if k == 'f5' then
      if Key.ctrl() then buf:rechunk() end
      bufview:refresh()
    end
  end
end
