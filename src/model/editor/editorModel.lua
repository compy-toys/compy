require("model.editor.bufferModel")
require("model.editor.searchModel")
require("model.input.userInputModel")

local class = require('util.class')

--- @class EditorModel
--- @field input UserInputModel
--- @field buffers Dequeue<BufferModel>
--- @field search Search
--- @field cfg Config
EditorModel = class.create(function(cfg)
  return {
    input = UserInputModel(cfg, LuaEval()),
    buffers = Dequeue.new({}, 'BufferModel'),
    search = Search(cfg),
    cfg = cfg,
  }
end)

--- @return {name: string, content: string[]}[]
function EditorModel:get_buffers_content()
  local ret = {}
  for _, buf in ipairs(self.buffers) do
    local b = {
      name = buf.name,
      content = buf:get_text_content(),
    }
    table.insert(ret, b)
  end
  return ret
end
