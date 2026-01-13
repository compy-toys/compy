require("view.titleView")
require("view.editor.editorView")
require("view.canvas.canvasView")
require("view.input.userInputView")

local class = require("util.class")
require("util.color")
require("util.view")
require("util.debug")

local gfx = love.graphics

--- @param cfg Config
--- @param ctrl ConsoleController
local function new(cfg, ctrl)
  local self = {
    title = TitleView,
    canvas = CanvasView(cfg.view),
    input = UserInputView(cfg.view, ctrl.input),
    editor = EditorView(cfg.view, ctrl.editor),
    controller = ctrl,
    cfg = cfg,
    drawable_height = ViewUtils.get_drawable_height(cfg.view),
  }
  --- hook the view in the controller
  ctrl:init_view(self)
  return self
end

--- @class ConsoleView
--- @field title table
--- @field canvas CanvasView
--- @field input UserInputView
--- @field editor EditorView
--- @field controller ConsoleController
--- @field cfg Config
--- @field drawable_height number
ConsoleView = class.create(new)

--- @param terminal table
--- @param canvas love.Canvas
--- @param snapshot love.Image?
function ConsoleView:draw(terminal, canvas, snapshot)
  if love.DEBUG then
    self:draw_placeholder()
  end

  local function drawConsole()
    local tc = self.controller.model.output.term_canvas
    self.canvas:draw(
      terminal, canvas, tc,
      self.drawable_height, snapshot)

    if ViewUtils.conditional_draw('show_input') then
      self.input:draw()
    end
  end

  local function drawEditor()
    self.editor:draw()
  end

  gfx.push('all')
  if love.state.app_state == 'editor' then
    drawEditor()
  else
    drawConsole()
  end
  gfx.pop()
end

function ConsoleView:draw_placeholder()
  local band = self.cfg.view.fh
  local w    = self.cfg.view.w
  local h    = self.cfg.view.h
  gfx.push('all')
  gfx.setColor(Color[Color.yellow])
  for o = -h, w, 2 * band do
    gfx.polygon("fill"
    , o + 0, h
    , o + h, 0
    , o + h + band, 0
    , o + band, h
    )
  end
  gfx.pop()
end
