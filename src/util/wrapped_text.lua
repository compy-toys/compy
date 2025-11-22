local class = require('util.class')
require("util.dequeue")
require("util.string.string")
require("util.lua")

--- Example text: {
--- 'ABBA',
--- 'EDDA AC/DC',
--- }
--- Assume a wrap width of 5, wrapped text comes out to: {
--- 'ABBA',
--- 'EDDA ',
--- 'AC/DC',
--- }
--- @alias WrapForward integer[][]
--- Mapping from original line numbers to wrapped line numbers.
--- e.g. {1: {1}, 2: {2, 3}}
---
--- @alias WrapReverse integer[]
--- Inverse mapping from apparent line number to original
--- Key is line number in wrapped, value is line number in
--- unwrapped original, e.g. {1: 1, 2: 2, 3: 2} means two
--- lines of text were broken up into three, because the second
--- exceeded the width limit
---
--- @alias WrapRank integer[]
--- The number of wraps that produced this line
--- (i.e. offset from the original line number)

--- @class WrappedText
--- @field text Dequeue<string>
--- @field orig Dequeue<string>
--- @field wrap_w integer
--- @field wrap_forward WrapForward
--- @field wrap_reverse WrapReverse
--- @field wrap_rank WrapRank
--- @field n_breaks integer
---
--- @field wrap function
--- @field get_text fun(self): Dequeue<string>
--- @field get_line function
--- @field get_text_length function
WrappedText = class.create()

--- @param w integer
--- @param text Dequeue<string>?
--- @return WrappedText
function WrappedText.new(w, text)
  local self = setmetatable({}, WrappedText)
  self:_init(w, text)

  return self
end

--- @protected
--- @param w integer
--- @param text Dequeue<string>?
function WrappedText:_init(w, text)
  if type(w) ~= "number" or w < 1 then
    error('invalid wrap length')
  end
  if type(text) == 'string' then
    error('invalid string array passed')
  end
  self.text = Dequeue.typed('string')
  self.orig = Dequeue.typed('string')
  self.wrap_w = w
  self.wrap_forward = {}
  self.wrap_reverse = {}
  self.wrap_rank = {}
  self.n_breaks = 0
  if text then
    self:wrap(text)
    self.orig = text
  end
end

--- @param text Dequeue<string>
function WrappedText:wrap(text)
  local w = self.wrap_w or 64
  local display = Dequeue.typed('string')
  local wrap_forward = {}
  local wrap_reverse = {}
  local wrap_rank = {}
  local breaks = 0
  local revi = 1
  if text then
    for i, l in ipairs(text) do
      local len = string.ulen(l)
      local brk = (function()
        if not len or len == 0 then return 0 end
        local div = math.intdiv(len, w)
        if math.fmod(len, w) == 0 then
          return div - 1
        else
          return div
        end
      end)()

      -- remember how many apparent lines will be overall
      local ap = brk + 1
      local fwd = {}
      for r = 1, ap do
        wrap_reverse[revi] = i
        wrap_rank[revi] = r - 1
        table.insert(fwd, revi)
        revi = revi + 1
      end
      wrap_forward[i] = fwd
      breaks = breaks + brk
      local lines = string.wrap_at(l, w)
      for _, tl in ipairs(lines) do
        table.insert(display, tl)
      end
    end
    self.orig = text
  end
  self.text = display
  self.wrap_forward = wrap_forward
  self.wrap_reverse = wrap_reverse
  self.wrap_rank = wrap_rank
  self.n_breaks = breaks
end

--- @return Dequeue<string>
function WrappedText:get_text()
  return self.text
end

--- @param l integer
function WrappedText:get_line(l)
  return self.text[l]
end

--- @return integer
function WrappedText:get_text_length()
  return #(self.text or {})
end
