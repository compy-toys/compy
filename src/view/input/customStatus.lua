local class = require('util.class')

--- @class CustomStatus table
--- @field name string
--- @field content_type ContentType
--- @field buflen integer
--- @field buffer_more More
--- @field selection integer
--- @field mode EditorMode
--- @field range Range?
CustomStatus = class.create(
  function(name, ct, len, more, sel, mode, range)
    return {
      name = name,
      content_type = ct,
      buflen = len,
      buffer_more = more,
      selection = sel,
      mode = mode,
      range = range,
    }
  end)

function CustomStatus:__tostring()
  if self.range then
    return 'B' .. self.range
  else
    return 'L' .. self.selection
  end
end
