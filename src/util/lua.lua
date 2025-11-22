local require = _G.o_require or _G.require

--- Require `name`.lua if exists
--- @param name string
local function prequire(name)
  local ok, module = pcall(function()
    return require(name)
  end)
  if ok then return module end
end

--- @param code string
--- @param env table?
--- @return function? chunk
--- @return string? err
local codeload = function(code, env)
  local f, err = loadstring(code)

  if not f then return nil, err end
  if env then
    setfenv(f, env)
  end
  return f
end

local t = {
  prequire = prequire,
  error_test = function()
    if love and love.DEBUG then
      error('error injection test')
    end
  end,
  codeload = codeload,
  b2s = function(b)
    return b and '#t' or '#f'
  end,
}

for k, v in pairs(t) do
  _G[k] = v
end

--- Returns the largest n such that n * y ≤ x ≤ (n + 1) * y
--- with 0 as fallback in cases of IEEE754 (or math) shenanigans
--- @param x number
--- @param y number
--- @return number
local function intdiv(x, y)
  local n, _ = math.modf(x / y)
  if n ~= n then
    return 0
  else
    return n
  end
end

math.intdiv = intdiv
