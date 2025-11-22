local class = require('util.class')

--- @param cfg ViewConfig
local new = function(cfg)
  return {
    cfg = cfg,
  }
end

--- @class ResultsView : ViewBase
--- @field cfg ViewConfig
--- @field draw function
ResultsView = class.create(new)

--- @param results ResultsDTO
function ResultsView:draw(results)
  local colors = self.cfg.colors.editor
  local fh = self.cfg.fh * 1.032 -- magic constant
  local width, height = gfx.getDimensions()
  local has_results = (results.results and #(results.results) > 0)

  local draw_background = function()
    gfx.push('all')
    gfx.setColor(colors.results.bg)
    gfx.rectangle("fill", 0, 0, width, height)
    gfx.pop()
  end

  local draw_results = function()
    local getLabel = function(t)
      if t == 'function' then
        return ""
      elseif t == 'method' then
        return ""
      elseif t == 'local' then
        return ""
      elseif t == 'global' then
        return ""
      elseif t == 'field' then
        return ""
      end
    end
    gfx.push('all')
    gfx.setFont(self.cfg.font)
    if not has_results then
      gfx.setColor(Color.with_alpha(colors.results.fg, 0.5))
      gfx.print("No results", 25, 0)
    else
      for i, v in ipairs(results.results) do
        local ln = i
        local lh = (ln - 1) * fh
        local t = v.r.type
        local label = getLabel(t)
        gfx.setColor(Color.with_alpha(colors.results.fg, 0.5))
        gfx.print(label, 2, lh + 2)
        gfx.setColor(colors.results.fg)
        gfx.print(v.r.name, 25, lh)
      end
    end
    gfx.pop()
  end

  local draw_selection = function()
    local highlight_line = function(ln)
      if not ln then return end

      gfx.setColor(colors.highlight)
      local l_y = (ln - 1) * fh
      gfx.rectangle('fill', 0, l_y, width, fh)
    end
    local v = results.selection
    highlight_line(v)
  end

  draw_background()
  if has_results then
    draw_selection()
  end
  draw_results()
end
