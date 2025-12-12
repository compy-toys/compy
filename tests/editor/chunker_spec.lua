local parser = require('model.lang.lua.parser')()

require('util.table')

local inputs = require('tests.editor.chunker_inputs')
local TU = require('tests.testutil')


describe('parser.chunker #chunk', function()
  local w = TU.wrap
  local chunker = function(t, single)
    return parser.chunker(t, w, single)
  end

  describe('produces blocks', function()
      for i, test in ipairs(inputs) do
        local str = test[1]
        local blk = test[2]

        it('matches ' .. i, function()
          local ok, output = chunker(str)
          assert.is_true(ok)
          assert.same(blk, output)
        end)
      end
  end)
end)
