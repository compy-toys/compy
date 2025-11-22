require('util.table')
require('util.string.string')

local w = 64

local noop = function() end
--- @param init str
--- @return fun(str): boolean, string?
--- @return reftable handle
local get_save_function = function(init)
  local handle = table.new_reftable()
  handle(string.unlines(init))
  --- @param content str
  --- @return boolean
  --- @return string?
  local save = function(content)
    handle(string.unlines(content))
    return true
  end
  return save, handle
end

return {
  get_save_function = get_save_function,
  noop = noop,
  LINES = 16,
  SCROLL_BY = 8,
  w = w,
  mock_view_cfg = {
    view = {
      drawableChars = w,
      lines = 16,
      input_max = 14
    },
  }
}
