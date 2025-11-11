require("view.input.userInputView")
require("view.editor.bufferView")
require("view.editor.search.searchView")

require("util.string.string")
local class = require('util.class')

--- @param cfg ViewConfig
--- @param ctrl EditorController
local function new(cfg, ctrl)
  local ev = {
    cfg = cfg,
    controller = ctrl,
    input = UserInputView(cfg, ctrl.input),
    buffers = {},
    search = SearchView(cfg, ctrl.search),
  }
  --- hook the view in the controller
  ctrl.view = ev
  return ev
end

--- @class EditorView : ViewBase
--- @field controller EditorController
--- @field input UserInputView
--- @field buffers { [string]: BufferView }
--- @field search SearchView
EditorView = class.create(new)

function EditorView:draw()
  local ctrl = self.controller
  local mode = ctrl:get_mode()
  if mode == 'search' then
    self.search:draw(ctrl.search:get_input())
  else
    local spec = mode == 'reorder'
    local bv = self:get_current_buffer()

    if ViewUtils.conditional_draw('show_buffer') then
      bv:draw(spec)
    end
    if ViewUtils.conditional_draw('show_input') then
      local input = ctrl:get_input()
      self.input:draw(input)
    end
  end
end

--- @param buffer BufferModel
--- @return BufferView
function EditorView:open(buffer)
  local bid = buffer:get_id()
  local opn = self.buffers[bid]
  if not opn then
    local v           = BufferView(self.cfg)
    self.buffers[bid] = v
    v:open(buffer)
    return v
  end
  return opn
end

--- @return BufferView
function EditorView:get_current_buffer()
  local ctrl = self.controller
  local bm = ctrl:get_active_buffer()
  local bid = bm:get_id()
  return self.buffers[bid]
end

--- @param bid string
--- @return BufferView
function EditorView:get_buffer(bid)
  return self.buffers[bid]
end

--- @param moved integer?
function EditorView:refresh(moved)
  self:get_current_buffer():refresh(moved)
end
