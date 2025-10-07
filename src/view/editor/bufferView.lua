require("model.input.cursor")
require("view.editor.visibleContent")
require("view.editor.visibleStructuredContent")

local class = require("util.class")
require("util.scrollable")
require("util.table")
-- local B = require("util.block")

--- @param cfg ViewConfig
local function new(cfg)
  local l = cfg.lines

  return {
    cfg = cfg,
    LINES = l,
    SCROLL_BY = math.floor(l / 2),
    w = cfg.drawableChars,

    content = nil,
    content_type = nil,
    more = { up = false, down = false },
    offset = 0,
    buffer = nil
  }
end

--- @class BufferView : ViewBase
--- @field content VisibleContent|VisibleStructuredContent
--- @field content_type ContentType
--- @field buffer BufferModel
---
--- @field LINES integer
--- @field SCROLL_BY integer
--- @field w integer
--- @field offset integer
--- @field more More
---
--- @field open function
--- @field refresh function
BufferView = class.create(new)

--- @private
--- @param r Range
function BufferView:_update_visible(r)
  self.content:set_range(r)
end

--- @param buffer BufferModel
function BufferView:open(buffer)
  local L = self.LINES
  self.buffer = buffer
  if not self.buffer then
    error('no buffer')
  end
  local cont = buffer.content_type
  self.content_type = cont

  if cont == 'plain' or cont == 'md' then
    local bufcon = buffer:get_text_content()
    self.buffer:highlight()
    self.content = VisibleContent(
      self.w, bufcon, self.SCROLL_BY, L)
    self.hl = self.buffer:get_highlight()
  elseif cont == 'lua' then
    local bufcon = buffer:get_content()
    self.content =
        VisibleStructuredContent(
          self.w,
          bufcon,
          buffer.highlighter,
          self.SCROLL_BY,
          L)
  else
    error 'unknown filetype'
  end

  -- TODO clean this up
  local clen = self.content:get_text_length()
  self.offset = math.max(clen - L, 0)
  local off = self.offset
  if off > 0 then
    self.more.up = true
  end

  local ir = self:_get_end_range()
  self:_update_visible(ir)
  if off > 0 then self:scroll('down', 1) end
end

--- @private
--- @return integer[][]
--- @return boolean loaded_is_sel
function BufferView:_get_wrapped_selection()
  local sel = self.buffer:get_selection()
  local cont = self.content
  local ret = {}
  if self.content_type == 'lua'
  then
    --- @type Range?
    local br = cont:get_block_pos(sel)
    if br then
      for _, l in ipairs(br:enumerate()) do
        table.insert(ret, self.content.wrap_forward[l])
      end
    end
  else
    ret[1] = self.content.wrap_forward[sel]
  end

  local ls = self.buffer:loaded_is_sel(false)
  return ret, ls
end

--- @return BufferState
function BufferView:get_state()
  local buf = self.buffer
  return {
    filename = buf.name,
    selection = buf.selection,
    offset = self.offset,
  }
end

--- @param moved integer?
function BufferView:refresh(moved)
  if not self.content then
    error('no buffer is open')
  end
  local text = self.buffer:get_text_content()
  self.hl = self.buffer:get_highlight()

  self.content:wrap(text)
  if self.content_type == 'lua' then
    self.content:load_blocks(self.buffer.content)
  end

  if moved then
    local sel = self.buffer:get_selection()
    if self.content_type == 'lua' then
      local vsc = self.content
      local blocks = vsc.blocks
      blocks:move(moved, sel)
      vsc:recalc_range()
    else
      local t = Dequeue(text)
      t:move(moved, sel)
      self.content:wrap(t)
    end
  end

  local clen = self.content:get_content_length()
  local off = self.offset
  local si = 1 + off
  local ei = math.min(self.LINES, clen + 1) + off
  self:_update_visible(Range(si, ei))
end

-------------------
---  scrolling  ---
-------------------

--- @private
--- @return Range
function BufferView:_get_end_range()
  local clen = self.content:get_text_length()
  return Scrollable.calculate_end_range(self.LINES, clen)
end

--- @param dir VerticalDir
--- @param by integer?
--- @param warp boolean?
function BufferView:scroll(dir, by, warp)
  local by = by or self.SCROLL_BY
  local l = self.content:get_content_length()
  local n = (function()
    if dir == 'up' then
      if warp then
        return -l
      else
        return -by
      end
    else
      local er = self:_get_end_range()
      local c = self.content:get_range()
      if warp then
        return er.start - c.start - self.LINES
      else
        return by
      end
    end
  end)()
  local o = self.content:move_range(n)
  self.offset = self.offset + o
end

--- @param off integer
function BufferView:scroll_to(off)
  self:scroll('up', nil, true)
  self:scroll('down', off)
end

--- @param ln integer
function BufferView:scroll_to_line(ln)
  local off = self.content.wrap_forward[ln][1]
  self:scroll_to(off)
end

--- @return boolean
--- @return VerticalDir?
--- @return number? diff
function BufferView:is_selection_visible()
  local sel = self.buffer:get_selection()

  local s_w
  if self.content_type == 'lua'
  then
    s_w = self.content:get_block_app_pos(sel):enumerate()
  else
    s_w = self.content.wrap_forward[sel]
  end

  local sel_s = s_w[1]
  local sel_e = s_w[#s_w]
  local r = self.content:get_range()
  if r:inc(sel_s) and r:inc(sel_e) then return true end

  local dir = (function()
    if r.start > sel_s then return 'up' end
    if r.fin < sel_e then return 'down' end
  end)()
  local d = (function()
    if dir == 'up' then
      return r.start - sel_s
    elseif dir == 'down' then
      --- TODO: smooothen around the end
      local off = self.LINES - 1
      -- local er = self:_get_end_range()
      -- if er:inc(sel_e) then
      --   off = 0 -- self.SCROLL_BY
      -- end
      return sel_s - r.fin + off
    end
  end)()

  return false, dir, d
end

function BufferView:follow_selection()
  local v, dir, d = self:is_selection_visible()
  if not v then
    if dir and d then self:scroll(dir, d) end
  end
end

--- @param special boolean
function BufferView:draw(special)
  local gfx = love.graphics
  local cf_colors = self.cfg.colors
  local colors = cf_colors.editor
  local font = self.cfg.font
  local fh = self.cfg.fh * 1.032 -- magic constant
  local fw = self.cfg.fw
  local vc = self.content
  --- @type VisibleContent|VisibleStructuredContent
  local content_text = vc:get_visible()
  local last_line_n = #content_text
  local width, height = gfx.getDimensions()


  local draw_background = function()
    gfx.push('all')
    gfx.setColor(colors.bg)
    gfx.rectangle("fill", 0, 0, width, height)
    gfx.setColor(Color.with_alpha(colors.fg, .0625))
    local bh = math.min(last_line_n, self.cfg.lines) * fh
    gfx.rectangle("fill", 0, 0, width, bh)
    gfx.pop()
  end

  local draw_highlight = function()
    local ws, ls = self:_get_wrapped_selection()

    local highlight_line = function(ln)
      if not ln then return end
      if special then
        gfx.setColor(colors.highlight_special)
      else
        if ls then
          gfx.setColor(colors.highlight_loaded)
        else
          gfx.setColor(colors.highlight)
        end
      end
      local l_y = (ln - 1) * fh
      gfx.rectangle('fill', 0, l_y, width, fh)
    end

    local off = self.offset
    for _, w in ipairs(ws) do
      for _, v in ipairs(w) do
        if self.content.range:inc(v) then
          if (not self.cfg.show_append_hl)
              and (v == self.content:get_content_length() + 1)
          then
            --- skip hl
          else
            highlight_line(v - off)
          end
        end
      end
    end
  end

  local draw_text = function()
    gfx.setFont(font)
    if self.content_type == 'lua' then
      local vbl = vc:get_visible_blocks()
      for _, block in ipairs(vbl) do
        local rs = block.app_pos.start
        --- @type WrappedText
        local wt = block.wrapped
        local text = wt:get_text()
        local highlight = { hl = block.highlight }
        local ltf = function(l)
          return l + rs - 1 - self.offset
        end
        local ctf = function(a) return a end
        local limit = self.cfg.lines

        ViewUtils.draw_hl_text(text, highlight, {
          colors = { text = colors }, fw = fw, fh = fh
        }, {
          ltf = ltf, ctf = ctf, limit = limit,
        })
      end -- for

      if love.DEBUG then
        --- phantom text
        gfx.setColor(Color.with_alpha(colors.fg, 0.3))
        local text = string.unlines(content_text)
        gfx.print(text)
      end
    elseif self.content_type == 'md' then
      local text      = vc:get_visible()
      local highlight = { hl = self.hl }
      local ltf       = function(l) return l end
      local ctf       = function(a)
        --- @diagnostic disable-next-line: param-type-mismatch
        return vc:translate_from_visible(a)
      end
      local limit     = self.cfg.lines

      ViewUtils.draw_hl_text(text, highlight, {
        colors = { text = colors }, fw = fw, fh = fh
      }, {
        ltf = ltf, ctf = ctf, limit = limit,
      })
    elseif self.content_type == 'plain' then
      gfx.setColor(colors.fg)
      local text = string.unlines(content_text)

      gfx.print(text)
    end
  end

  local draw_debuginfo = function()
    if not love.DEBUG then return end
    local showap = false
    local lnc = colors.fg
    local x = self.cfg.w - font:getWidth('   ') - 3
    local lnvc = Color.with_alpha(lnc, 0.2)
    gfx.setColor(lnvc)
    gfx.rectangle("fill", x, 0, 2, self.cfg.h)
    local seen = {}
    for ln = 1, self.LINES do
      local l_y = (ln - 1) * fh
      local vln = ln + self.offset
      local ln_w = self.content.wrap_reverse[vln]
      if ln_w then
        local l = string.format('%3d', ln_w)
        local l_x = self.cfg.w - font:getWidth(l)
        local l_xv = l_x - font:getWidth(l) - 3.5
        if showap then
          gfx.setColor(lnvc)
          gfx.print(string.format('%3d', vln), l_xv, l_y)
        end
        if not seen[ln_w] then
          gfx.setColor(lnc)
          gfx.print(l, l_x, l_y)
          seen[ln_w] = true
        end
      end
    end
  end

  draw_background()
  draw_highlight()
  draw_text()
  draw_debuginfo()
end
