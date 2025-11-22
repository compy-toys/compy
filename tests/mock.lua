require('util.dequeue')
require('util.string.string')
require('util.debug')

local held = {
  lctrl = false,
  rctrl = false,
  lshift = false,
  rshift = false,
  lalt = false,
  ralt = false,
  --- aka Super / Win / Cmd
  lgui = false,
  rgui = false,
}

local mods = {
  C = 'lctrl',
  S = 'lshift',
  M = 'lalt',
}

local W = 1024
local H = 600

--- @param t love
local function mock_love(t)
  local love = {
    keyboard = {
      isDown = function(k) return held[k] end
    },
    graphics = {
      mock = true,
      getWidth = function() return W end,
      getHeight = function() return H end,
      getDimensions = function() return W, H end,
      newCanvas = function() end,
      setCanvas = function() end,
      clear = function() end,
    },
  }
  for k, v in pairs(t) do
    love[k] = v
  end
  _G.love = love
  _G.TESTING = Dequeue()
end

local function release_keys()
  for k, _ in pairs(held) do
    held[k] = false
  end
end

--- @param s string
--- @param press function
--- @param hold boolean?
local function keystroke(s, press, hold)
  local keypress = press or love.keypressed
  local ks = string.split(s, '-')
  for _, v in ipairs(ks) do
    local m = mods[v]
    if m then
      held[m] = true
    else
      keypress(v)
    end
  end
  if not hold then
    release_keys()
  end
end

return {
  mock_love = mock_love,
  keystroke = keystroke,
  release_keys = release_keys,
}
