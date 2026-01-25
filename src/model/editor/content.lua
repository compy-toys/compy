local class = require('util.class')
require("util.dequeue")
require("util.range")

--- @alias Block Empty|Chunk

--- @class Empty
--- @field tag 'empty'
--- @field pos Range
Empty = class.create(function(ln)
  return {
    tag = 'empty',
    pos = Range.singleton(ln),
  }
end)

function Empty:is_empty()
  return true
end

function Empty:__tostring()
  return string.format('L%d: <empty>', self.pos.start)
end

--- @class Chunk
--- @field tag 'chunk'
--- @field lines Dequeue<string>
--- @field hl SyntaxColoring
--- @field pos Range
Chunk = class.create()

--- @param lines str
--- @param pos Range
--- @return Chunk
function Chunk.new(lines, pos)
  local ls = (function()
    if type(lines) == 'string' then return { lines } end
    return lines
  end)()
  local self = setmetatable({
    tag = 'chunk',
    lines = Dequeue(ls),
    pos = pos,
  }, Chunk)

  return self
end

function Chunk:is_empty()
  return false
end

function Chunk:__tostring()
  local ret = ''
  for i, l in ipairs(self.lines) do
    ret = ret .. string.format('\nL%d:\t%s',
      self.pos.start + i - 1, l)
  end
  return ret
end
