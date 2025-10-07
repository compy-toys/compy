require("util.dequeue")
require("util.string.string")
require("util.view")
local class = require('util.class')
local Terminal = require("lib.terminal")

local gfx = love.graphics

--- @class CanvasModel
--- @field terminal table
--- @field canvas love.Canvas
--- @field term_canvas love.Canvas
--- @field cfg table
--- @field write function
--- @field push function
--- @field reset function
--- @field update function
--- @field get_canvas function
--- @field draw_to function
--- @field restore_main function
CanvasModel = class.create()

--- @param cfg Config
function CanvasModel.new(cfg)
  local w, h
  if cfg.view.sizedebug then
    w = cfg.view.debugwidth * cfg.view.fw
    h = cfg.view.debugheight * cfg.view.fh
  else
    w = cfg.view.w
    -- h = ViewUtils.get_drawable_height(cfg.view)
    h = cfg.view.h
  end
  local canvas = gfx.newCanvas(w, h)
  local custom_height = cfg.view.fh * cfg.view.lh
  local term = Terminal(w, h, cfg.view.font,
    nil, custom_height)

  local color = cfg.view.colors.terminal
  term:hide_cursor()
  term:set_cursor_color(unpack(color.fg))
  term:set_cursor_backcolor(unpack(color.bg))
  term:clear()
  local t_canvas = term.canvas
  local self = setmetatable({
    terminal = term,
    canvas = canvas,
    term_canvas = t_canvas,
    cfg = cfg,
  }, CanvasModel)

  return self
end

function CanvasModel:write(text)
  if string.is_non_empty_string(text) then
    self.terminal:print(text)
  end
end

function CanvasModel:push(newResult)
  if type(newResult) == 'table' then
    local t = string.unlines(newResult)
    self:write(t)
  else
    self:write(tostring(newResult) .. '\n')
  end
end

function CanvasModel:reset()
  self.terminal:clear()
  self.terminal:move_to(1, 1)
end

function CanvasModel:invalidate_terminal()
end

function CanvasModel:update(dt)
  self.terminal:update(dt)
end

function CanvasModel:get_canvas()
  return self.canvas
end

function CanvasModel:clear_canvas()
  return self.canvas:renderTo(function()
    gfx.clear(0, 0, 0, 0)
  end)
end

function CanvasModel:draw_to()
  gfx.setCanvas(self.canvas)
end

function CanvasModel:restore_main()
  gfx.setCanvas()
end
