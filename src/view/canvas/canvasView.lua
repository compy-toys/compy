require("view.canvas.bgView")
require("view.canvas.terminalView")

local class = require("util.class")
require("util.view")

local gfx = love.graphics

--- @class CanvasView : ViewBase
--- @field bg BGView
CanvasView = class.create(function(cfg)
  return {
    cfg = cfg,
    bg = BGView(cfg)
  }
end)

--- @param terminal table
--- @param canvas love.Canvas
--- @param term_canvas love.Canvas
--- @param drawable_height number
--- @param snapshot love.Image?
function CanvasView:draw(
    terminal, canvas, term_canvas, drawable_height, snapshot
)
  local cfg = self.cfg
  local test = cfg.drawtest

  gfx.reset()
  gfx.push('all')
  gfx.setBlendMode('alpha', 'alphamultiply') -- default
  if ViewUtils.conditional_draw('show_snapshot') then
    if snapshot then
      gfx.draw(snapshot)
    end
    self.bg:draw(drawable_height)
  end

  if not test then
    if ViewUtils.conditional_draw('show_terminal') then
      -- gfx.setBlendMode('multiply', "premultiplied")
      TerminalView.draw(terminal, term_canvas, snapshot)
    end
    if ViewUtils.conditional_draw('show_canvas') then
      gfx.draw(canvas)
    end
    gfx.setBlendMode('alpha', 'alphamultiply') -- default
  else
    gfx.setBlendMode('alpha', 'alphamultiply') -- default
    for i = 0, love.test_grid_y - 1 do
      for j = 0, love.test_grid_x - 1 do
        local off_x = cfg.debugwidth * cfg.fw
        local off_y = cfg.debugheight * cfg.fh
        local dx = j * off_x
        local dy = i * off_y
        gfx.reset()
        gfx.translate(dx, dy)

        local index = (i * love.test_grid_x) + j + 1

        local b = ViewUtils.blendModes[index]
        if b then
          -- gfx.setBlendMode('alpha') -- default
          if ViewUtils.conditional_draw('show_terminal') then
            b.blend()
            TerminalView.draw(terminal, term_canvas, snapshot)
          end
          gfx.setBlendMode('alpha') -- default
          if ViewUtils.conditional_draw('show_canvas') then
            gfx.draw(canvas)
          end

          gfx.setBlendMode('alpha') -- default
          gfx.setColor(1, 1, 1, 1)
          gfx.setFont(cfg.labelfont)

          -- gfx.print(index .. ' ' .. b.name)
          gfx.print(b.name)
        end
      end
    end
  end

  gfx.pop()
end
