require("view.input.statusline")

local class = require('util.class')
require("util.debug")
require("util.view")


--- @param cfg ViewConfig
--- @param ctrl UserInputController
local new = function(cfg, ctrl)
  return {
    cfg = cfg,
    controller = ctrl,
    statusline = Statusline(cfg),
    oneshot = ctrl.model.oneshot,
  }
end

--- @class UserInputView : ViewBase
--- @field controller UserInputController
--- @field statusline table
--- @field oneshot boolean
UserInputView = class.create(new)

--- @param input InputDTO
function UserInputView:draw_input(input)
  local gfx = love.graphics

  local cfg = self.cfg
  local status = self.controller:get_status()
  local cf_colors = cfg.colors
  local colors = (function()
    if love.state.app_state == 'inspect' then
      return cf_colors.input.inspect
    elseif love.state.app_state == 'running' then
      return cf_colors.input.user
    else
      return cf_colors.input.console
    end
  end)()

  local fh = cfg.fh
  local fw = cfg.fw
  local h = cfg.h
  local drawableWidth = cfg.drawableWidth
  local w = cfg.drawableChars
  -- drawtest hack
  if drawableWidth < gfx.getWidth() / 3 then
    w = w * 2
  end

  local cursorInfo = self.controller:get_cursor_info()
  local cl, cc = cursorInfo.cursor.l, cursorInfo.cursor.c
  local acc = cc - 1
  --- overflow binary and actual height (in lines)
  local overflow = 0
  local of_h = 0

  local text = input.text
  local vc = input.visible
  local inLines = math.min(
    vc:get_content_length(),
    cfg.input_max)

  --- The Overflow
  --- When the cursor is on the last character of the line
  --- we display it at the start of the next line as that's
  --- where newly added text will appear
  --- However, when the line also happens to be wrap-length,
  --- there either is no next line yet, or it would look the
  --- same as if it was at the start of the next.
  --- Hence, the overflow phantom line.
  local curline = text[cl]
  local clen = string.ulen(curline)
  local q, rem = math.modf(acc / w)
  local ofpos = rem == 0 and acc == clen and clen > 0
  if ofpos
      and string.is_non_empty_string_array(text)
  then
    overflow = 1
    of_h = q
  end

  local apparentLines = inLines + overflow
  local inHeight = inLines * fh
  local apparentHeight = inHeight
  local y = h - (#text * fh)

  local wrap_forward = vc.wrap_forward
  local wrap_reverse = vc.wrap_reverse

  local start_y = h - apparentLines * fh

  local function drawCursor()
    local y_offset = math.floor(acc / w)
    local yi = y_offset + 1
    local acl = (wrap_forward[cl] or { 1 })[yi] or 1
    local vcl = acl - vc.offset + of_h

    if vcl < 1 then return end

    local ch = start_y + (vcl - 1) * fh
    local x_offset = math.fmod(acc, w)

    gfx.push('all')
    gfx.setColor(cf_colors.input.cursor)
    gfx.print('|', (x_offset - .5) * fw, ch)
    gfx.pop()
  end

  local drawBackground = function()
    gfx.setColor(colors.bg)
    gfx.rectangle("fill",
      0,
      start_y,
      drawableWidth,
      apparentHeight * fh)
  end

  local highlight = input.highlight
  local visible = vc:get_visible()
  gfx.setFont(self.cfg.font)
  drawBackground()
  self.statusline:draw(status, apparentLines)

  if highlight then
    local hl = highlight.hl
    if highlight.parse_err then
      --- grammar = 'lua'
      local color = colors.fg
      local perr = highlight.parse_err
      local el, ec
      if perr then
        el = perr.l
        ec = perr.c
      end
      for l, s in ipairs(visible) do
        local ln = l + vc.offset
        local tl = string.ulen(s)

        if not tl then return end

        for c = 1, tl do
          local char = string.usub(s, c, c)

          local hl_li = wrap_reverse[ln]
          local tlc = vc:translate_from_visible(Cursor(l, c))

          if tlc then
            local ci = (function()
              if hl[tlc.l] then
                return hl[tlc.l][tlc.c]
              end
            end)()
            if ci then
              color = Color[ci] or colors.fg
            end
          end
          if perr and ln > el or
              (ln == el and (c > ec or ec == 1)) then
            color = cf_colors.input.error
          end
          local selected = (function()
            local sel = input.selection
            local startl = sel.start and sel.start.l
            local endl = sel.fin and sel.fin.l
            if startl then
              local startc = sel.start.c
              local endc = sel.fin.c
              if startc and endc then
                if startl == endl then
                  local sc = math.min(sel.start.c, sel.fin.c)
                  local endi = math.max(sel.start.c, sel.fin.c)
                  return l == startl and c >= sc and c < endi
                else
                  return
                      (l == startl and c >= sel.start.c) or
                      (l > startl and l < endl) or
                      (l == endl and c < sel.fin.c)
                end
              end
            end
          end)()
          --- number of lines back from EOF
          local diffset = #text - vc.range.fin
          local of = overflow
          --- push any further lines down to display phantom line
          if ofpos and hl_li > cl then
            of = of - 1
          end
          local dy = y - (-ln - diffset + 1 + of) * fh
          local dx = (c - 1) * fw
          ViewUtils.write_token(dy, dx,
            char, color, colors.bg, selected)
        end
      end
    else
      --- grammar = 'md'
      for l, s in ipairs(visible) do
        local ln = l + vc.offset
        local tl = string.ulen(s)
        if not tl then return end

        for c = 1, tl do
          local char = string.usub(s, c, c)
          local color = colors.fg

          --- @diagnostic disable-next-line: param-type-mismatch
          local tlc = vc:translate_from_visible(Cursor(l, c))

          if tlc then
            local row = hl[tlc.l]
            local lex_t = row[tlc.c]
            if lex_t then
              color = Color[lex_t] or colors.fg
            end
          end
          local hl_li = wrap_reverse[ln]

          local selected = (function()
            local sel = input.selection
            local startl = sel.start and sel.start.l
            local endl = sel.fin and sel.fin.l
            if startl then
              local startc = sel.start.c
              local endc = sel.fin.c
              if startc and endc then
                if startl == endl then
                  local sc = math.min(sel.start.c, sel.fin.c)
                  local endi = math.max(sel.start.c, sel.fin.c)
                  return l == startl and c >= sc and c < endi
                else
                  return
                      (l == startl and c >= sel.start.c) or
                      (l > startl and l < endl) or
                      (l == endl and c < sel.fin.c)
                end
              end
            end
          end)()
          --- number of lines back from EOF
          local diffset = #text - vc.range.fin
          local of = overflow
          --- push any further lines down to display phantom line
          if ofpos and hl_li > cl then
            of = of - 1
          end
          local dy = y - (-ln - diffset + 1 + of) * fh
          local dx = (c - 1) * fw
          ViewUtils.write_token(dy, dx,
            char, color, colors.bg, selected)
        end
      end
    end
  else
    for l, str in ipairs(visible) do
      gfx.setColor(colors.fg)
      ViewUtils.write_line(l, str, start_y, 0, self.cfg)
    end
  end
  drawCursor()
end

--- @param input InputDTO
function UserInputView:draw(input)
  local err_text = input.wrapped_error or {}
  local isError = string.is_non_empty_string_array(err_text)

  local colors = self.cfg.colors
  local fh = self.cfg.fh
  local h = self.cfg.h

  if isError then
    local drawableWidth = self.cfg.drawableWidth
    local inLines = #err_text
    local inHeight = inLines * fh
    local apparentHeight = #err_text
    local start_y = h - inHeight
    local drawBackground = function()
      gfx.setColor(colors.input.error_bg)
      gfx.rectangle("fill",
        0,
        start_y,
        drawableWidth,
        apparentHeight * fh)
    end

    drawBackground()
    gfx.setColor(colors.input.error)
    for l, str in ipairs(err_text) do
      local breaks = 0 -- starting height is already calculated
      ViewUtils.write_line(l, str, start_y, breaks, self.cfg)
    end
  else
    self:draw_input(input)
  end
end

--- Whether the cursor is at limit, accounting for word wrap.
--- If it's not at a limit line according to the model, it can't
--- be there according to the view, but the reverse is not true,
--- hence this utility function.
--- @param dir VerticalDir
--- @return boolean
function UserInputView:is_at_limit(dir)
  local ml = self.controller.model:is_at_limit(dir)
  if not ml then
    return false
  else
    local model = self.controller.model
    local w = self.cfg.drawableChars
    local cur = model:get_cursor_info().cursor
    if dir == 'up' then
      if cur.l ~= 1 then
        return false
      else
        return cur.c < w
      end
    else
      local nl = model:get_n_text_lines()
      if cur.l ~= nl then
        return false
      else
        local ll = string.ulen(model:get_current_line())
        local il = math.floor(ll / w)
        local c  = math.floor(cur.c / w)
        return il == c
      end
    end
  end
end
