local class = require('util.class')
require('util.dequeue')
require('util.string.string')
require('util.debug')

--- @class History: Dequeue<string[]>
--- @field index integer
History = class.create()

function History.new()
  local self = Dequeue.typed('string[]')

  setmetatable(self, {
    __index = function(t, k)
      local value = History[k] or Dequeue[k]
      return value
    end
  })
  return self
end

--- @param input string[]?
--- @return boolean
function History:remember(input)
  if string.is_non_empty_string_array(input) then
    if not self.index then
      self:append(input)
      return true
    end
  end
  return false
end

function History:reset_index()
  self.index = nil
end

--- @param current string[]?
--- @return boolean
--- @return string[]?
function History:history_back(current)
  local r = self:remember(current)
  local hi = self.index
  if hi and hi > 0 then
    local prev = self[hi - 1]
    if prev then
      if string.is_non_empty_string_array(current) then
        self[hi] = current
      end
      self.index = hi - 1
      return true, prev
    end
    return false
  else
    local off = 0
    if r then off = 1 end
    self.index = self:get_last_index() - off
    local prev = self[self.index] or { '' }
    return true, prev
  end
end

--- @param current string[]?
--- @return boolean
--- @return string[]?
function History:history_fwd(current)
  if self.index then
    local hi = self.index
    local next = self[hi + 1]
    if string.is_non_empty_string_array(current) then
      self[hi] = current
    end
    if next then
      self.index = hi + 1
      return true, next
    end
  end
  return false
end

--- @protected
--- @return integer
function History:_get_length()
  return #(self)
end

--- @protected
--- @param i integer
function History:_get_entry(i)
  return self[i]
end

--- @protected
--- @return string[][]
function History:_get_entries()
  return self:items()
end

--- For debug purposes, log content
--- @param f function
function History:_dump(f)
  local log = f or Log.debug
  local h = self:items()
  local t = table.map(h, function(t)
    return table.concat(t, '⏎')
  end)
  local i = self.index or '-'
  local l = ' [' .. self:length() .. '] '
  log(i .. l .. Debug.text_table(t, false, nil, 64)  )
end
