---@alias reftable table
---@return reftable
table.new_reftable = function()
  local RT = {}
  --- @return boolean
  function RT:is_empty()
    if self.value then
      return false
    end
    return true
  end

  setmetatable(RT, {
    __call = function(self, ...)
      local argv = { ... }
      local argc = #argv

      if argc == 0 then
        local v = self.value
        self.value = nil
        return v
      else
        self.value = argv[1]
      end
    end
  })
  return RT
end


--- Create a sequence from the table keys
--- @param t table
--- @return table keys
table.keys = function(t)
  -- for k, v in pairs({ 1, 2, fos = 'asd' }) do print(k, v) end
  local keys = {}
  for k, _ in pairs(t) do
    -- keys[k] = k
    table.insert(keys, k)
  end
  return keys
end

--- @param obj table
--- @param seen table?
--- @param omit table?
-- https://gist.github.com/tylerneylon/81333721109155b2d244
function table.clone(obj, seen, omit)
  -- Handle non-tables and previously-seen tables.
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  -- if omit and omit[obj] then return {} end

  -- New table; mark it as seen and copy recursively.
  local s = seen or {}
  local res = {}
  s[obj] = res
  for k, v in pairs(obj) do
    -- omiting keys only on the main level
    if not omit or (omit and not omit[k]) then
      res[table.clone(k, s)] = table.clone(v, s)
    end
  end
  return setmetatable(res, getmetatable(obj))
end

--- Make table readonly, optionally only the specified fields
--- @param t table
--- @param fields? table
--- @return table protected
--- @return table original
function table.protect(t, fields)
  local orig = t
  local proxy = {}

  setmetatable(proxy, {
    __index = function(_, k)
      return orig[k]
    end,
    __newindex = function(_, k, v)
      if not fields then
        Log("Protected table")
        return
      end
      local fs = {}
      for _, f in ipairs(fields) do
        fs[f] = f
      end
      if fs[k] then
        Log("Can't redefine " .. k)
        return
      end
      orig[k] = v
    end,
  })
  getmetatable(proxy).__metatable = 'no-no'
  t = proxy
  return t, orig
end

--- @diagnostic disable-next-line: duplicate-set-field
function table.pack(...)
  --- @class t
  local t = { ... }
  t.n = #t
  return t
end

--- Return a new table containing keys which are present in the
--- `other`, but not in `self`.
--- @param other table
--- @return table difference
function table.diff(self, other)
  local diff = {}
  -- for i, v in ipairs(other) do
  --   if not self[i] then
  --     diff[i] = v
  --   end
  -- end
  for k, v in pairs(other) do
    if not self[k] then
      diff[k] = v
    end
  end
  return diff
end

--- Determine if two tables have the same content
--- @param other table
--- @return boolean same
function table.equal(self, other)
  if type(other) ~= "table" then return false end

  local diff = table.diff(self, other)
  local next = next
  if next(diff) == nil then
    return true
  end
  return false
end

function table.toggle(self, k)
  if type(self) == "table" and k then
    if not self[k] then
      self[k] = true
    else
      self[k] = false
    end
  end
end

--- https://stackoverflow.com/a/24823383
--- @param self table
--- @param first integer?
--- @param last integer?
--- @param step integer?
function table.slice(self, first, last, step)
  local sliced = {}

  for i = first or 1, last or #self, step or 1 do
    sliced[#sliced + 1] = self[i]
  end

  return sliced
end

--- Determine if the table is an array, i.e. not used as a hash
--- @param self table
--- @return boolean is_array
function table.is_array(self)
  if not self or not type(self) == "table" then
    return false
  end
  local is_array = true
  for k, _ in pairs(self) do
    if type(k) ~= 'number' then
      return false
    end
  end
  return is_array
end

--- Flatten tables of tables
--- @param self table
--- @param depth integer?
--- @return table?
function table.flatten(self, depth)
  if not self or not type(self) == "table" then
    return
  end
  local d = depth or 1
  local ret = {}
  if d == 1 then
    for _, v in pairs(self) do
      for _, w in pairs(v) do
        table.insert(ret, w)
      end
    end
  else
    --- TODO?
  end
  return ret
end

--- Return odd-indexed elements
--- @param self table
--- @return table?
function table.odds(self)
  if not self or not type(self) == "table" then
    return
  end
  local ret = {}
  for i, v in ipairs(self) do
    local rem = i % 2
    if rem == 1 then
      table.insert(ret, v)
    end
  end
  return ret
end

--- Try to determine the 'type' of the object
--- @param self table
--- @param t string
--- @return boolean
function table.is_instance(self, t)
  if not self or not t then return false end
  local typ = string.lower(type(self))
  local tag = string.lower(self.tag)
  local tt  = string.lower(t)
  return tt == typ or tt == tag
end

--- @param self table
--- @param e any
--- @return boolean
function table.is_member(self, e)
  if not self or not e then return false end
  local ret = false
  for _, v in pairs(self) do
    if v == e then return true end
  end
  return ret
end

--- @param self table
--- @param e any
--- @return boolean
function table.delete_by_value(self, e)
  if not self or not e then return false end
  local i = -1
  for j, v in pairs(self) do
    if v == e then i = j end
  end
  if i > 0 then
    table.remove(self, i)
    return true
  end
  return false
end

--- Find index of 'e' if present. Returns first instance
--- @param self table
--- @param e any
--- @return integer?
function table.find(self, e)
  if not self or not e then return end
  for i, v in pairs(self) do
    if v == e then return i end
  end
end

--- Find first element that the predicate holds for
--- @param self table[]
--- @param pred function
--- @return integer?
function table.find_by(self, pred)
  if not self or not pred then return end
  for i, v in pairs(self) do
    if pred(v) then return i end
  end
end

--- Find first element that the predicate holds for
--- @param self table[]
--- @param pred function
--- @return any?
function table.find_by_v(self, pred)
  if not self or not pred then return end
  for _, v in pairs(self) do
    if pred(v) then return v end
  end
end

--- Filter elements that satisfy the predicate
--- enumerates sequentially
--- @param self table[]
--- @param pred function
--- @return table[]
function table.filter_array(self, pred)
  if not self or not pred then return {} end
  local res = {}
  for _, v in ipairs(self) do
    if pred(v) then table.insert(res, v) end
  end
  return res
end

--- TODO testability for hash impl
--- @param self table[]
--- @param pred function
--- @return table[]
function table.filter(self, pred)
  if not self or not pred then return {} end
  local res = {}
  for k, v in ipairs(self) do
    if pred(v) then res[k] = v end
  end
  return res
end

--- Find element where the value returned by 'select' is the
--- smallest, courtesy of Perplexity (mostly)
--- @param self table[]
--- @param select function
--- @return table?
function table.min_by(self, select)
  local minValue = self[1]
  local minKey = select(minValue)

  for i = 2, #self do
    local currentKey = select(self[i])
    if currentKey < minKey then
      minValue = self[i]
      minKey = currentKey
    end
  end

  return minValue
end

--- Return first n elements.
--- TODO refactor to use slice()
--- @param self table
--- @param n integer
--- @return table
function table.take(self, n)
  local ret = {}
  for i = 1, n do
    ret[i] = self[i]
  end
  return ret
end

--- Apply f to all elements of the table (returns new table)
--- @param self table
--- @param f function
--- @return table
function table.map(self, f)
  local ret = {}
  for k, v in pairs(self) do
    ret[k] = f(v)
  end
  return ret
end
