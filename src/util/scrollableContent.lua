require("util.wrapped_text")
require("util.scrollable")
require("util.range")

--- @class ScrollableContent: WrappedText
--- @field range Range?
--- @field size integer
--- @field size_max integer
--- @field overscroll_max integer
--- @field scroll_by integer
---
--- @field get_default_range fun(self): Range
--- @field check_range fun(self)
--- @field wrap fun(self, text: Dequeue<string>)
--- @field set_range fun(self, Range)
--- @field get_range fun(self): Range
--- @field set_default_range fun(self)
--- @field move_range fun(self, integer): integer
--- @field get_content_length fun(self): integer
--- @field get_visible function
--- @field get_more fun(self): More
--- @field to_end fun(self)
ScrollableContent = {}
ScrollableContent.__index = ScrollableContent

setmetatable(ScrollableContent, {
  __index = WrappedText,
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

--- @param size integer
--- @param overscroll integer
--- @param size_max integer
--- @return ScrollableContent
function ScrollableContent.new(size, overscroll, size_max)
  --- @type ScrollableContent
  --- @diagnostic disable-next-line: assign-type-mismatch
  local self = setmetatable({
    overscroll_max = overscroll,
    size = size,
    size_max = size_max,
    scroll_by = size_max / 2,
    offset = 0,
  }, ScrollableContent)
  self:_init()
  self:to_end()


  return self
end

function ScrollableContent:get_default_range()
  local L = math.min(self.size_max, self.size)
  return Range(1, L)
end

--- Set the visible range so that last of the content is visible
function ScrollableContent:to_end()
  self.range = self:_get_end_range()
  self.offset = self.range.start - 1
end

--- @private
--- @return Range
function ScrollableContent:_get_end_range()
  local L = self.size_max
  local clen = self.size or 0
  local off = math.max(clen - L, 0)
  local si = 1
  local ei = math.min(L, clen + 1)
  return Range(si, ei):translate(off)
end

--- Invoked after text changes, validate range
function ScrollableContent:check_range()
  local l = self.size
  local r = self.range
  if r then
    local rl = r:len()
    if r.fin > l then
      r.fin = l
    end
    if rl < self.size_max then
      self:set_default_range()
    end
  else
    self:set_default_range()
  end
end

--- @private
function ScrollableContent:_update_meta()
  self:_update_overscroll()
end

--- @protected
function ScrollableContent:_update_overscroll()
  local over = math.min(self.overscroll_max, self.size)
  self.overscroll = over
end

--- @protected
function ScrollableContent:_init()
  self:_update_overscroll()
end

--- @param newsize integer
function ScrollableContent:update(newsize)
  self.size = newsize
  self:set_default_range()
  self:_update_meta()
end

function ScrollableContent:get_range()
  return self.range
end

function ScrollableContent:set_range(r)
  if r then
    self.offset = r.start - 1
    self.range = r
  end
end

function ScrollableContent:set_default_range()
  self.range = self:get_default_range()
  self.offset = 0
end

function ScrollableContent:move_range(by)
  if type(by) == "number" then
    local r = self.range
    local upper = self.size + self.overscroll
    if r then
      local nr, n = r:translate_limit(by, 1, upper)
      self:set_range(nr)
      return n
    end
  end
  return 0
end

--- @param content any[]
function ScrollableContent:get_visible(content)
  local si, ei = self.range.start, self.range.fin
  return table.slice(content, si, ei)
end

function ScrollableContent:get_content_length()
  return self.size
end

function ScrollableContent:get_more()
  local vrange = self:get_range()
  local vlen = self:get_content_length()
  local more = {
    up = vrange.start > 1,
    down = vrange.fin < vlen
  }
  return more
end

--- @param dir VerticalDir
--- @param by integer?
--- @param warp boolean?
function ScrollableContent:scroll(dir, by, warp)
  local by = by or self.scroll_by
  local l = self.size
  local n = (function()
    if dir == 'up' then
      if warp then
        return -l
      else
        return -by
      end
    else
      local er = self:_get_end_range()
      local c = self:get_range()
      if warp then
        return er.start - c.start - self.size_max
      else
        return by
      end
    end
  end)()
  self:move_range(n)
end
