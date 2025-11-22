--- @class SemanticInfoBase
--- @field name string
--- @field line integer

--- @alias AssignmentType
--- | 'function'
--- | 'method'
--- | 'local'
--- | 'global'
--- | 'field'

--- @class Assignment : SemanticInfoBase
--- @field type AssignmentType

--- @class Require : SemanticInfoBase

local class = require('util.class')

--- @class SemanticInfo
--- @field assignments Assignment[]
--- @field requires Require[]
SemanticInfo = class.create(function(asn, reqs)
  return {
    assignments = asn or {},
    requires = reqs or {},
  }
end)
