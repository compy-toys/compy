require("model.input.inputText")
require("model.input.selection")
require("model.input.history")
require("model.lang.lua.error")
require("view.editor.visibleContent")

local class = require('util.class')
require("util.wrapped_text")
require("util.dequeue")
require("util.string.string")
require("util.debug")
require("util.lua")

--- @class UserInputModel
--- @field oneshot boolean
--- @field entered InputText
--- @field history History
--- @field evaluator Evaluator
--- @field cursor Cursor
--- @field error string[]?
--- @field visible VisibleContent
--- @field selection InputSelection
--- @field cfg Config
--- @field custom_status CustomStatus?
--- @field custom_label string?
--- @field _memo table
--- methods
--- @field new function
--- @field get_label fun(self): string?
--- @field init_visible function
--- @field add_text fun(self, string)
--- @field set_text fun(self, string, boolean)
--- @field line_feed fun(self)
--- @field get_text fun(self): InputText
--- @field get_text_line fun(self, integer): string
--- @field get_n_text_lines fun(self): integer
--- @field get_wrapped_text fun(self): VisibleContent
--- @field get_wrapped_error fun(self): string[]?
--- @field swap_lines function
UserInputModel = class.create()


--- @param cfg Config
--- @param eval Evaluator
--- @param oneshot boolean?
--- @param custom_label string?
function UserInputModel.new(cfg, eval, oneshot, custom_label)
  local self = setmetatable({
    oneshot = oneshot,
    entered = InputText(),
    history = History(),
    evaluator = eval,
    cursor = Cursor(),
    selection = InputSelection(),
    custom_status = nil,
    custom_label = custom_label,
    --- @private
    _memo = {},

    cfg = cfg,
  }, UserInputModel)

  UserInputModel.init_visible(self, { '' })

  return self
end

--- @return string?
function UserInputModel:get_label()
  local cl = self.custom_label
  if cl then return cl end

  local eval = self.evaluator
  if eval and eval.label then return eval.label end
end

--- @param text string[]
function UserInputModel:init_visible(text)
  local w = self.cfg.view.drawableChars
  local s = self.cfg.view.input_max
  self.visible = VisibleContent(w, text, 1, s)
  self.visible:set_default_range()
end

----------------
--  entered   --
----------------

--- @param text string
function UserInputModel:add_text(text)
  if type(text) == 'string' then
    self:pop_selected_text()
    local sl, cc    = self:get_cursor_pos()
    local cur_line  = self:get_text_line(sl)
    local pre, post = string.split_at(cur_line, cc)
    local lines     = string.lines(text)
    local n_added   = #lines
    if n_added == 1 then
      local nval = string.interleave(pre, text, post)
      self:_set_text_line(nval, sl, true)
      self:_advance_cursor(string.ulen(text))
    else
      local ent = self.entered
      local ins = table.clone(lines)
      local fl = ins[1]
      local ll = ins[n_added]
      ins[1] = pre .. fl
      ins[n_added] = ll .. post

      for k = n_added, 1, -1 do
        local line = ins[k]

        if k == 1 then
          ent:update(line, sl)
        else
          ent:insert(line, sl + 1)
        end
      end
      local last_line_i = sl + n_added - 1
      self:move_cursor(last_line_i, string.ulen(ll) + 1)
    end
    self:text_change()
  end
end

--- @param text str
--- @param keep_cursor boolean
function UserInputModel:set_text(text, keep_cursor)
  if type(text) == 'string' then
    local lines = string.lines(text)
    local n_added = #lines
    if n_added == 1 then
      self.entered = InputText({ text })
    end
    if not keep_cursor then
      self:_update_cursor(true)
    end
  elseif type(text) == 'table' then
    self.entered = InputText(text)
  end
  self:text_change()
  if not keep_cursor then
    self:init_visible(self.entered)
  end
  self:jump_end()
end

--- @private
--- @param text str
--- @param ln integer
--- @param keep_cursor boolean
function UserInputModel:_set_text_line(text, ln, keep_cursor)
  if type(text) == 'string' then
    local ent = self:get_text()
    if ent then
      local l = self:get_n_text_lines()
      if ln > l then
        ent:append(text)
      else
        ent:update(text, ln)
      end
      if not keep_cursor then
        self:_update_cursor(true)
      end
    elseif type(text) == 'table' and ln == 1 then
      self.entered = InputText(text)
    end
  end
end

--- @private
--- @param ln integer
function UserInputModel:_drop_text_line(ln)
  self:get_text():remove(ln)
  self:text_change()
end

--- @param ln integer?
function UserInputModel:delete_line(ln)
  local n = self:get_n_text_lines()
  if n == 1 then
    self:clear_input()
  else
    local l = ln or self:get_cursor_y()
    self:_drop_text_line(l)
  end
end

--- @param text string
--- @param li integer?
function UserInputModel:insert_text_line(text, li)
  local l = li or self:get_cursor_y()
  self.cursor.l = l + 1
  self:get_text():insert(text, l)
  self:text_change()
end

--- Swap to lines of text, second param defaults to cursor line
--- @param ln_that integer
--- @param ln_this integer?
--- @return boolean success
function UserInputModel:swap_lines(ln_that, ln_this)
  if not ln_that then return false end

  if self:has_selection() then
    return false
  else
    local ln_this = ln_this or self:get_cursor_y()
    local this = self:get_text_line(ln_this)
    local that = self:get_text_line(ln_that)

    local n = self:get_n_text_lines()
    if n < 2 then return true end
    if ln_this > n or ln_that > n or
        ln_this < 1 or ln_that < 1 then
      return false
    end

    self:_set_text_line(that, ln_this, true)
    self:_set_text_line(this, ln_that, true)
    self:set_cursor(Cursor(ln_that, self:get_cursor_x()))
    self:text_change()
    return true
  end
end

function UserInputModel:line_feed()
  local cl, cc = self:get_cursor_pos()
  local cur_line = self:get_text_line(cl)
  local pre, post = string.split_at(cur_line, cc)
  self:_set_text_line(pre, cl, true)
  self:insert_text_line(post, cl + 1)
  self:move_cursor(cl + 1, 1)
  self:text_change()
end

--- @return InputText
function UserInputModel:get_text()
  return self.entered or InputText()
end

--- @param l integer
--- @return string
function UserInputModel:get_text_line(l)
  local ent = self:get_text()
  return ent:get(l) or ''
end

--- @return integer
function UserInputModel:get_n_text_lines()
  local ent = self:get_text()
  return ent:length()
end

--- @return VisibleContent
function UserInputModel:get_wrapped_text()
  return self.visible
end

--- @param l integer
--- @return string
function UserInputModel:get_wrapped_text_line(l)
  return self:get_wrapped_text():get_line(l)
end

--- @return string
function UserInputModel:get_current_line()
  local cl = self:get_cursor_y() or 1
  return self:get_text():get(cl)
end

--- @param text string
function UserInputModel:paste(text)
  local sel = self:get_selection()
  local start = sel.start
  local fin = sel.fin
  if start and start.l and fin and fin.l and fin.c then
    local from, to = self:diff_cursors(start, fin)
    self:get_text():traverse(from, to, { delete = true })
    if from and to then
      self:move_cursor(from.l, from.c)
    end
  end
  self:add_text(text)
  self:clear_selection()
end

function UserInputModel:backspace()
  self:pop_selected_text()
  local line = self:get_current_line()
  local cl, cc = self:get_cursor_pos()
  local newcl = cl - 1
  local pre, post

  if cc == 1 then
    if cl == 1 then -- can't delete nothing
      return
    end
    -- line merge
    pre = self:get_text_line(newcl) or ''
    local pre_len = string.ulen(pre)
    post = line or ''
    local nval = pre .. post
    self:_set_text_line(nval, newcl, true)
    self:move_cursor(newcl, pre_len + 1)
    self:_drop_text_line(cl)
  else
    -- regular merge
    pre = string.usub(line, 1, cc - 2)
    post = string.usub(line, cc)
    local nval = pre .. post
    self:_set_text_line(nval, cl, true)
    self:cursor_left()
  end
  self:text_change()
end

function UserInputModel:delete()
  self:pop_selected_text()
  local line = self:get_current_line()
  local cl, cc = self:get_cursor_pos()
  local pre, post

  local n = self:get_n_text_lines()

  local llen = string.ulen(line)
  if cc == llen + 1 then
    if cl == n then
      return
    end
    -- line merge
    post = self:get_text_line(cl + 1)
    pre = line
    self:_drop_text_line(cl + 1)
  else
    -- regular merge
    pre = string.usub(line, 1, cc - 1)
    post = string.usub(line, cc + 1)
  end
  local nval = (pre or '') .. (post or '')
  self:_set_text_line(nval, cl, true)
  self:text_change()
end

function UserInputModel:clear_input()
  self.entered = InputText()
  self:text_change()
  self:clear_selection()
  self:_update_cursor(true)
  self.custom_status = nil
  self.history:reset_index()
end

--- @param history boolean?
function UserInputModel:reset(history)
  if history and self:keep_history() then
    self.history = History()
  end
  self:clear_input()
end

function UserInputModel:text_change()
  self.visible:wrap(self.entered)
  self.visible:check_range()
  self:_follow_cursor()
  local ev = self.evaluator
  if ev then
    self:highlight()
  end
end

function UserInputModel:highlight()
  local ev = self.evaluator
  if not ev then return end
  local text = self:get_text()

  local p = ev.parser
  if p then
    local ok, p_err = p.parse(text)
    local parse_err
    if not ok then
      parse_err = p_err
    end
    local hl
    if ev.highlighter then
      hl = ev.highlighter(text)
    end

    self._memo.highlight = { hl = hl, parse_err = parse_err }
  else
    if ev.highlighter then
      self._memo.highlight = { hl = ev.highlighter(text) }
    else
      self._memo.highlight = ev:validation_hl(text)
    end
  end
end

function UserInputModel:get_highlight()
  if not self._memo.highlight then
    self:highlight()
  end
  return self._memo.highlight
end

----------------
--  history   --
----------------

--- @return boolean
function UserInputModel:keep_history()
  return not self.oneshot
end

--- @private
function UserInputModel:_remember()
  if self:keep_history() then
    local ent = self.entered
    if string.is_non_empty_string_array(ent) then
      self.history:remember(ent)
    end
  end
end

function UserInputModel:history_back()
  if self:keep_history() then
    local t = self:get_text()
    local ok, hist = self.history:history_back(t)
    -- TODO: remember cursor pos?
    if ok then
      self:set_text(hist)
      self:jump_end()
    end
  end
end

function UserInputModel:history_fwd()
  if self:keep_history() then
    local t = self:get_text()
    local ok, hist = self.history:history_fwd(t)
    -- TODO: remember cursor pos?
    if ok then
      self:set_text(hist)
      self:jump_end()
    else
      self:clear_input()
    end
  end
end

----------------
--   cursor   --
----------------

--- Follow cursor movement with visible range
--- @private
function UserInputModel:_follow_cursor()
  local cl, cc = self:get_cursor_pos()
  local w = self.cfg.view.drawableChars
  local acl = cl + math.intdiv(cc, w)
  local vrange = self.visible:get_range()
  local diff = vrange:outside(acl)
  if diff ~= 0 then
    self.visible:move_range(diff)
  end
  self.visible:check_range()
end

--- @private
--- @param replace_line boolean
function UserInputModel:_update_cursor(replace_line)
  local cl = self:get_cursor_y()
  local t = self:get_text()
  if replace_line then
    self.cursor.c = string.ulen(t[cl]) + 1
    self.cursor.l = #t
  else

  end
end

--- @private
--- @param x integer?
--- @param y integer?
function UserInputModel:_advance_cursor(x, y)
  local cur_l, cur_c = self:get_cursor_pos()
  local move_x = x or 1
  local move_y = y or 0
  if move_y == 0 then
    local next = cur_c + move_x
    self.cursor.c = next
  else
    self.cursor.l = cur_l + move_y
    -- TODO multiline
  end
end

--- @param c Cursor
function UserInputModel:set_cursor(c)
  self.cursor = c
end

--- @param y integer?
--- @param x integer?
--- @param selection 'keep'|'move'?
function UserInputModel:move_cursor(y, x, selection)
  local prev_l, prev_c = self:get_cursor_pos()
  local c, l
  local line_limit = self:get_n_text_lines() + 1 -- allow for line just being added
  if y and y >= 1 and y <= line_limit then
    l = y
  else
    l = prev_l
  end
  local llen = #(self:get_text_line(l))
  local char_limit = llen + 1
  if x and x >= 1 and x <= char_limit then
    c = x
  else
    c = prev_c
  end
  self:set_cursor(Cursor(l, c))


  if selection == 'keep' then
  elseif selection == 'move' then
  else
    self:clear_selection()
  end
  self:_follow_cursor()
end

--- @return integer l
--- @return integer c
function UserInputModel:get_cursor_pos()
  return self.cursor.l, self.cursor.c
end

--- @return CursorInfo
function UserInputModel:get_cursor_info()
  return {
    cursor = self.cursor,
  }
end

--- @return integer
function UserInputModel:get_cursor_x()
  return self.cursor.c
end

--- @return integer
function UserInputModel:get_cursor_y()
  return self.cursor.l
end

--- @param dir VerticalDir?
--- @return boolean
function UserInputModel:is_at_limit(dir)
  local n = self:get_n_text_lines()
  local cl = self:get_cursor_y()
  if dir == 'down' then
    return cl == n
  elseif dir == 'up' then
    return cl == 1
  else
    if n < 3 then return true end
    local limit = cl == 1 or cl == n
    return limit
  end
end

--- @return InputDTO
function UserInputModel:get_input()
  return {
    text          = self:get_text(),
    highlight     = self:get_highlight(),
    selection     = self:get_ordered_selection(),
    visible       = self.visible,
    wrapped_error = self:get_wrapped_error(),
  }
end

--- @param dir VerticalDir
--- @return boolean? limit
function UserInputModel:cursor_vertical_move(dir)
  local cl, cc = self:get_cursor_pos()
  local w = self.visible.wrap_w
  local n = self:get_n_text_lines()
  local llen = string.ulen(self:get_text_line(cl))
  local full_lines = math.floor(llen / w)

  --- @param is_inline function
  --- @param is_not_last_line function
  --- @return boolean? limit
  local function move(is_inline, is_not_last_line)
    local keep = (function()
      if self.selection:is_held() then
        return 'keep'
      end
    end)()
    local function sgn(back, fwd)
      if dir == 'up' then
        return back()
      elseif dir == 'down' then
        return fwd()
      end
    end
    if llen > w and is_inline() then
      local newc = sgn(
        function() return math.max(cc - w, 0) end,
        function() return math.min(cc + w, llen + 1) end
      )
      self:move_cursor(cl, newc, keep)
      if keep then self:end_selection() end
      return
    end
    if is_not_last_line() then
      local nl = sgn(
        function() return cl - 1 end,
        function() return cl + 1 end
      )
      local target_line = self:get_text_line(nl)
      local target_len = string.ulen(target_line)
      local offset = math.fmod(cc, w)
      local newc
      if target_len > w then
        local base = sgn(
          function() return math.floor(target_len / w) * w end,
          function() return 0 end
        )
        local t_offset = sgn(
          function() return math.fmod(target_len, w) + 1 end,
          function() return math.fmod(w, target_len) end
        )

        local new_off = math.min(offset, t_offset)
        newc = base + new_off
      else
        newc = math.min(offset, 1 + string.ulen(target_line))
      end
      self:move_cursor(nl, newc, keep)
      if keep then self:end_selection() end
    else
      if self:is_selection_held() then
        sgn(
          function() self:jump_home() end,
          function() self:jump_end() end
        )
      end
      return true
    end
  end

  local limit
  if dir == 'up' then
    limit = move(
      function() return cc - w > 0 end,
      function() return cl > 1 end
    )
  elseif dir == 'down' then
    limit = move(
      function() return cc <= full_lines * w end,
      function() return cl < n end
    )
  else
    return
  end
  if not limit then self:_follow_cursor() end
  return limit
end

function UserInputModel:cursor_left()
  local cl, cc = self:get_cursor_pos()
  local nl, nc = (function()
    if cc > 1 then
      local next = cc - 1
      return nil, next
    elseif cl > 1 then
      local cpl = cl - 1
      local pl = self:get_text_line(cpl)
      local cpc = 1 + string.ulen(pl)
      return cpl, cpc
    end
  end)()

  if self.selection:is_held() then
    self:move_cursor(nl, nc, 'keep')
    self:end_selection()
  else
    self:move_cursor(nl, nc)
  end
end

function UserInputModel:cursor_right()
  local cl, cc = self:get_cursor_pos()
  local line = self:get_text_line(cl)
  local len = string.ulen(line)
  local next = cc + 1
  local nl, nc = (function()
    if cc <= len then
      return nil, next
    elseif cl < self:get_n_text_lines() then
      return cl + 1, 1
    end
  end)()

  if self.selection:is_held() then
    self:end_selection(cl, cc + 1)
    self:move_cursor(nl, nc, 'keep')
  else
    self:move_cursor(nl, nc)
  end
end

function UserInputModel:jump_home()
  local keep = (function()
    if self.selection:is_held() then
      return 'keep'
    end
  end)()
  local nl, nc = 1, 1
  self:end_selection(nl, nc)
  self:move_cursor(nl, nc, keep)
  self:_follow_cursor()
end

function UserInputModel:jump_end()
  local ent = self:get_text()
  local last_line = #ent
  local last_char = string.ulen(ent[last_line]) + 1
  local keep = (function()
    if self.selection:is_held() then
      return 'keep'
    end
  end)()
  self:end_selection(last_line, last_char)
  self:move_cursor(last_line, last_char, keep)
  self.visible:to_end()
  self.visible:check_range()
end

--- @return Status
function UserInputModel:get_status()
  return {
    label = self:get_label(),
    cursor = self.cursor,
    n_lines = self:get_n_text_lines(),
    custom = self.custom_status,
    input_more = self.visible:get_more(),
  }
end

function UserInputModel:jump_line_start()
  local keep = (function()
    if self.selection:is_held() then
      return 'keep'
    end
  end)()
  local l = self.cursor.l
  local nc = 1
  self:end_selection(l, nc)
  self:move_cursor(l, nc, keep)
end

function UserInputModel:jump_line_end()
  local ent = self:get_text()
  local line = self.cursor.l
  local char = string.ulen(ent[line]) + 1
  local keep = (function()
    if self.selection:is_held() then
      return 'keep'
    end
  end)()
  self:end_selection(line, char)
  self:move_cursor(line, char, keep)
end

--- @param cs CustomStatus
function UserInputModel:set_custom_status(cs)
  if type(cs) == 'table' then
    self.custom_status = cs
  end
end

----------------
-- evaluation --
----------------

--- @return boolean
--- @return string[]
function UserInputModel:evaluate()
  return self:handle(true)
end

function UserInputModel:cancel()
  self:handle(false)
  self:reset()
end

--- @param eval boolean
--- @return boolean
--- @return string[]|Error[]
function UserInputModel:handle(eval)
  local ent = self:get_text()
  local ok, result
  if ent:non_empty() then
    local ev = self.evaluator
    self:_remember()
    if eval then
      ok, result = ev:apply(ent)
      if ok then
        if self.oneshot then
          if love.harmony then
            if love.harmony.utils then
              love.harmony.utils.love_event('userinput')
            end
          else
            --- @diagnostic disable-next-line: param-type-mismatch
            love.event.push('userinput')
          end
        end
      else
        --- @TODO fix
        local perr = result[1]
        -- Log.debug(Debug.terse_t(perr, nil, nil, true))
        if perr then
          --- @TODO check line len and move to next if at end
          if perr.c then
            local c = perr.c
            if c > 1 then c = c + 1 end
            self:move_cursor(perr.l, c)
          end
        end
        return false, result
      end
    else
      ok = true
    end
  end

  return ok, (result or ent)
end

----------------
--   error    --
----------------
function UserInputModel:clear_error()
  self.error = nil
end

--- @return string[]?
function UserInputModel:get_wrapped_error()
  if self.error then
    local e = table.map(self.error, function(er)
      return tostring(er)
    end)
    local we = string.wrap_array(
      e,
      self.visible.wrap_w)
    table.insert(we, 1, 'Errors:')
    return we
  end
end

--- @TODO support error[] and string[]
--- @param errors Error[]?
function UserInputModel:set_error(errors)
  self.error = nil
  if type(errors) == "table" then
    if type(errors[1] == "string") then
      self.error = errors
    else
      self.error = {}
      for _, e in ipairs(errors) do
        table.insert(self.error, tostring(e))
      end
    end
  end
end

--- @return boolean
function UserInputModel:has_error()
  if self.error and #(self.error) > 0 then
    return true
  end
  return false
end

--- @param eval Evaluator
function UserInputModel:set_eval(eval)
  self.evaluator = eval
  self.label = eval.label or ''
end

----------------
-- selection  --
----------------
--- @param l integer
--- @param c integer
function UserInputModel:translate_grid_to_cursor(l, c)
  local wt       = self.visible.wrap_reverse
  local li       = wt[l] or wt[#wt]
  local line     = self:get_wrapped_text_line(l)
  local llen     = string.ulen(line)
  local c_offset = math.min(llen + 1, c)
  local c_base   = l - li
  local ci       = c_base * self.visible.wrap_w + c_offset
  return li, ci
end

--- @param c1 Cursor?
--- @param c2 Cursor?
--- @return Cursor?
--- @return Cursor?
function UserInputModel:diff_cursors(c1, c2)
  if c1 and c2 then
    local d = c1:compare(c2)
    if d > 0 then
      return c1, c2
    else
      return c2, c1
    end
  end
end

--- @param from Cursor?
--- @param to Cursor?
function UserInputModel:text_between_cursors(from, to)
  if from and to then
    return self:get_text():traverse(from, to)
  else
    return { '' }
  end
end

--- @param l integer?
--- @param c integer?
function UserInputModel:start_selection(l, c)
  local start = (function()
    if l and c then
      return Cursor(l, c)
    else -- default to current cursor position
      return Cursor(self:get_cursor_pos())
    end
  end)()
  self.selection.start = start
end

--- @param l integer?
--- @param c integer?
function UserInputModel:end_selection(l, c)
  local start         = self.selection.start
  local fin           = (function()
    if l and c then
      return Cursor(l, c)
    else -- default to current cursor position
      return Cursor(self:get_cursor_pos())
    end
  end)()
  local from, to      = self:diff_cursors(start, fin)
  local sel           = self:text_between_cursors(from, to)
  self.selection.fin  = fin
  self.selection.text = sel
end

--- @param is_mouse boolean
function UserInputModel:hold_selection(is_mouse)
  if not is_mouse then
    local cur_start = self:get_selection().start
    local cur_end = self:get_selection().fin
    if cur_start and cur_start.l and cur_start.c then
      self:start_selection(cur_start.l, cur_start.c)
    else
      self:start_selection()
    end
    if cur_end and cur_end.l and cur_end.c then
      self:end_selection(cur_end.l, cur_end.c)
    else
      self:end_selection()
    end
  end
  self.selection.held = true
end

function UserInputModel:release_selection()
  self.selection.held = false
end

--- @return InputSelection
function UserInputModel:get_selection()
  return self.selection
end

--- @return boolean
function UserInputModel:is_selection_held()
  return self.selection.held
end

--- @return InputSelection
function UserInputModel:get_ordered_selection()
  local sel = self.selection
  local s, e = self:diff_cursors(sel.start, sel.fin)
  local ret = InputSelection()
  ret.start = s
  ret.fin = e
  ret.text = sel.text
  ret.held = sel.held
  return ret
end

--- @return string[]
function UserInputModel:get_selected_text()
  return self.selection.text
end

--- @return string[]?
function UserInputModel:pop_selected_text()
  local t = self.selection.text
  local start = self.selection.start
  local fin = self.selection.fin
  if start and fin then
    local from, to = self:diff_cursors(start, fin)
    if from and to then
      self:get_text():traverse(from, to, { delete = true })
      self:text_change()
      self:move_cursor(from.l, from.c)
      self:clear_selection()
      return t
    end
  end
end

function UserInputModel:clear_selection()
  self.selection = InputSelection()
  self:release_selection()
end

--- @return boolean
function UserInputModel:has_selection()
  local s = self.selection
  return s:is_defined()
end

--- @param l integer
--- @param c integer
function UserInputModel:mouse_click(l, c)
  local li, ci = self:translate_grid_to_cursor(l, c)
  self:clear_selection()
  self:start_selection(li, ci)
  self:hold_selection(true)
end

--- @param l integer
--- @param c integer
function UserInputModel:mouse_release(l, c)
  local li, ci = self:translate_grid_to_cursor(l, c)
  self:release_selection()
  self:end_selection(li, ci)
  self:move_cursor(li, ci, 'keep')
end

--- @param l integer
--- @param c integer
function UserInputModel:mouse_drag(l, c)
  local li, ci = self:translate_grid_to_cursor(l, c)
  local sel = self:get_selection()
  local held = sel.held and love.mouse.isDown(1)
  if sel.start and held then
    self:end_selection(li, ci)
    self:move_cursor(li, ci, 'move')
  end
end
