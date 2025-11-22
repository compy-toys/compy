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
