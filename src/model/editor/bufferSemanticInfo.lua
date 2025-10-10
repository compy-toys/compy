require('util.table')

--- @alias blocknum integer

--- @class Definition: Assignment
--- @field block blocknum

--- @class RequireCall: Require
--- @field block blocknum

--- @class BufferSemanticInfo
--- @field definitions Definition[]
--- @field requires RequireCall[]

--- @param si SemanticInfo
--- @param rev table
--- @return BufferSemanticInfo
local function convert(si, rev)
  local blockmap = function(a)
    local r = table.clone(a)
    r.block = rev[a.line]
    return r
  end
  local as = si.assignments
  local defs = table.map(as, blockmap)
  local rs = si.requires
  local reqs = table.map(rs, blockmap)

  return {
    definitions = defs,
    requires = reqs,
  }
end

return {
  convert = convert,
}
