require('model.editor.bufferModel')
local parser = require('model.lang.lua.parser')()
require("view.editor.visibleStructuredContent")

require("util.string.string")
TU = require('tests.testutil')

local lua_ex =
[[local x, y

function eval(input)
  local f = actions[input]
  if f then
    f()
  end
end

function love.draw()
  gfx.setFont(font)
  drawBackground()
  drawHelp()
  drawTurtle(tx, ty)
  if debug then
    drawDebuginfo()
  end
end

function love.update()
  if ty > midy then
    debug_color = Color.red
  end
  if not r:is_empty() then
    eval(r())
  end
end]]

local chunker = function(t, single)
  return parser.chunker(t, TU.w, single)
end
-- local chunker = parser.chunker
local hl = parser.highlighter

describe('VisibleStructuredContent #visible', function()
  local lines = string.lines(lua_ex)
  local buffer = BufferModel('main.lua',
    lines, TU.noop, chunker, hl)
  local vsc = VisibleStructuredContent({
      wrap_w = TU.w,
      overscroll_max = TU.SCROLL_BY,
      size_max = TU.LINES,
      view_config = TU.mock_view_cfg
    },
    buffer:get_content(),
    buffer.highlighter,
    buffer.truncer
  )

  it('invariants', function()
    assert.same(TU.LINES, vsc.opts.size_max)
    assert.same(TU.SCROLL_BY, vsc.opts.overscroll_max)
  end)

  it('scrolls', function()
    assert.same(27, #lines)
    -- assert.same(11, vsc.offset)
    vsc:move_range(-50)
    assert.same(Range(1, TU.LINES), vsc.range)
  end)
end)
