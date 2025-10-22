require("model.interpreter.eval.evaluator")
require("model.input.userInputModel")
require("controller.userInputController")
require("view.input.userInputView")

TU = require('tests.testutil')

describe("input view spec #input", function()
  local w        = 8
  local mockConf = TU.mock_view_cfg(w)

  mock           = require("tests.mock")
  local love     = {
    state = {
      --- @type AppState
      app_state = 'ready',
    },
  }
  mock.mock_love(love)

  local luaEval = LuaEval()
  local model   = UserInputModel(mockConf, luaEval)
  local t       = string.times("x", mockConf.view.drawableChars + 3)
  model:add_text(t)
  local ctrl = UserInputController(model)

  it('whether cursor is at limit lines', function()
    local view = UserInputView(mockConf.view, ctrl)
    assert.is_false(view:is_at_limit('up'))
    assert.is_true(view:is_at_limit('down'))
    model:jump_home()
    assert.is_true(view:is_at_limit('up'))
    assert.is_false(view:is_at_limit('down'))
  end)
end)
