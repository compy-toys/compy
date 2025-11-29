local class = require("util.class")

--- @class Statusline : ViewBase
Statusline = class.create(function(cfg)
  return { cfg = cfg }
end)


--- @param status Status
--- @param start_y integer?
function Statusline:draw(status, start_y)
  local gfx = love.graphics
  local cf = self.cfg
  local colors = (function()
    local state = love.state.app_state
    if state == 'inspect' then
      return cf.colors.statusline.inspect
    elseif state == 'running' then
      return cf.colors.statusline.user
    elseif state == 'editor' then
      return cf.colors.statusline.editor
    else
      return cf.colors.statusline.console
    end
  end)()

  local h = start_y or 0
  local w = cf.w
  local fh = cf.fh
  local font = cf.font
  local sb = cf.statusline_border
  local corr = sb / 2

  local start_box = { x = 0, y = h }
  local endTextX = start_box.x + w - fh
  local midX = (start_box.x + w) / 2

  local function drawBackground()
    gfx.setColor(colors.bg)
    gfx.setFont(font)
    gfx.rectangle("fill",
      start_box.x, start_box.y - corr, w, fh + sb)
  end

  --- @param m More?
  --- @return string
  local function morelabel(m)
    if not m then return '' end

    if m.up and not m.down then
      return '↑↑'
    elseif not m.up and m.down then
      return '↓↓ '
    elseif m.up and m.down then
      return '↕↕ '
    else
      return ''
    end
  end

  local function drawStatus()
    local state = love.state.app_state
    local custom = status.custom
    local start_text = {
      x = start_box.x + fh,
      y = start_box.y,
    }

    gfx.setColor(colors.fg)
    local label = status.label
    if label then
      gfx.print(label, start_text.x, start_text.y)
    end
    if love.DEBUG then
      gfx.setColor(cf.colors.debug)
      if love.state.testing then
        gfx.print('testing',
          midX - (8 * cf.fw),
          start_text.y + corr)
      end
      local sl = state or '???'
      local lw = font:getWidth(sl) / 2
      gfx.print((sl),
        midX - lw, start_text.y)
      gfx.setColor(colors.fg)
    end

    local c = status.cursor
    if type(c) == 'table' then
      if custom then
        local t_ic = ' ' .. c.l .. ':' .. c.c
        local lim = custom.buflen
        local sel, t_bbp, t_blp
        -- local more_i = ''
        if custom.content_type == 'lua' then
          sel = custom.selection
          t_bbp = 'B' .. sel .. ' '
          t_blp = custom.range:ln_label()
        else
          sel = custom.selection
          t_blp = 'L' .. sel
        end
        local more_b = morelabel(custom.buffer_more) .. ' '
        local more_i = morelabel(status.input_more) .. ' '
        local name = custom.name .. ' '

        gfx.setColor(colors.fg)
        local font = gfx.getFont()
        local w_il  = font:getWidth(" 999:9999")
        local w_br  = font:getWidth("B999 L999-999(99)")
        local w_mb  = font:getWidth(" ↕↕ ")
        local w_mi  = font:getWidth("  ↕↕ ")
        local s_mb  = endTextX - w_br - w_il - w_mi - w_mb
        local w_n  = font:getWidth(name)
        local s_n  = s_mb - w_n - 5
        local cw_p  = font:getWidth(t_blp)
        local cw_il = font:getWidth(t_ic)
        local sxl   = endTextX - (cw_p + w_il + w_mi)
        local s_mi  = endTextX - w_il


        gfx.setFont(self.cfg.font)
        gfx.setColor(colors.fg)
        if colors.fg2 then gfx.setColor(colors.fg2) end
        --- cursor pos
        gfx.print(t_ic, endTextX - cw_il, start_text.y)
        --- input more
        gfx.print(more_i, s_mi, start_text.y - 3)

        gfx.setColor(colors.fg)
        if custom.mode == 'reorder'
            and custom.content_type == 'plain' then
          gfx.setColor(colors.special)
        end
        --- block line range / line
        gfx.print(t_blp, sxl, start_text.y)
        gfx.setColor(colors.fg)
        --- block number
        if custom.content_type == 'lua' then
          local bpw = gfx.getFont():getWidth(t_bbp)
          local sxb = sxl - bpw
          if sel == lim then
            gfx.setColor(colors.indicator)
          end
          if custom.mode == 'reorder' then
            gfx.setColor(colors.special)
          end
          gfx.print(t_bbp, sxb, start_text.y)
        end

        --- buffer more
        gfx.setColor(colors.fg)
        gfx.print(more_b, s_mb, start_text.y)
        -- filename
        gfx.setColor(Color[Color.white])
        gfx.print(custom.name, s_n, start_text.y)
      else
        --- normal statusline
        local pos_c = ':' .. c.c
        local ln, l_lim
        if custom then
          ln = custom.line
          l_lim = custom.buflen
        else
          ln = c.l
          l_lim = status.n_lines
        end
        if ln == l_lim then
          gfx.setColor(colors.indicator)
        end
        local pos_l = 'L' .. ln

        local lw = gfx.getFont():getWidth(pos_l)
        local cw = gfx.getFont():getWidth(pos_c)
        local sx = endTextX - (lw + cw)
        gfx.print(pos_l, sx, start_text.y)
        gfx.setColor(colors.fg)
        gfx.print(pos_c, sx + lw, start_text.y)
      end
    end
  end

  gfx.push('all')
  drawBackground()
  drawStatus()
  gfx.pop()
end
