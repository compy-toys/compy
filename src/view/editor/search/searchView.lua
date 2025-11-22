local class = require('util.class')
require('view.editor.search.resultsView')
require("view.input.userInputView")

--- @param cfg ViewConfig
--- @param ctrl SearchController
local function new(cfg, ctrl)
  local self = {
    controller = ctrl,
    results = ResultsView(cfg),
    input = UserInputView(cfg, ctrl.input)
  }
  ctrl:init_view(self)
  return self
end

--- @class SearchView
--- @field controller SearchController
--- @field results ResultsView
--- @field input UserInputView
SearchView = class.create(new)

function SearchView:draw()
  local ctrl = self.controller
  local rs = ctrl:get_results()
  gfx.push("all")
  self.results:draw(rs)
  if ViewUtils.conditional_draw('show_input') then
    self.input:draw()
  end
  gfx.pop()
end
