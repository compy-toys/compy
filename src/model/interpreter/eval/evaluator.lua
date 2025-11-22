require('model.interpreter.eval.filter')
require("model.lang.highlight")

local class = require('util.class')

--- @class Evaluator
--- @field label string
--- @field parser Parser?
--- @field highlighter Highlighter?
--- @field apply function
--- @field custom_apply function?
--- @field line_validators ValidatorFilter[]
--- @field astValidators AstValidatorFilter[]
--- @field transformers TransformerFilter[]
Evaluator = class.create()


--- @param self Evaluator
--- @param s string[]
local function validate(self, s)
  local errors = {}
  local valid = true

  for _, fv in ipairs(self.line_validators or {}) do
    if #s == 1 then
      local ok, verr = fv(s[1])
      if not ok and verr then
        valid = false
        local e = Error.wrap(verr)
        table.insert(errors, e)
      end
    else
      for i, l in ipairs(s) do
        local ok, verr = fv(l)
        if not ok and verr then
          valid = false
          local e = Error.wrap(verr)
          if e and not e.l then e.l = i end
          table.insert(errors, e)
        end
      end
    end
  end
  return valid, errors
end

--- @param self Evaluator
--- @param s string[]
--- @return boolean ok
--- @return str content|errpr
--- @return luaAST? ast
local function default_apply(self, s)
  local valid, errors = validate(self, s)
  local parser = self.parser

  if valid then
    if parser then
      local ok, result = parser.parse(s)
      if not ok then
        table.insert(errors, result)
        return false, errors
      else
        local ast = result
        return true, s, ast
      end
    end
    return true, s
  else
    return false, errors
  end
end

--- @param label string
--- @param tools {parser: Parser?, highlighter: Highlighter?}
--- @param filters Filters?
--- @param custom_apply function?
function Evaluator.new(label, tools, filters, custom_apply)
  local f = filters or {}
  local t = tools or {}

  return setmetatable({
    label           = label,
    parser          = t.parser,
    highlighter     = t.highlighter,
    line_validators = f.line_validators or {},
    astValidators   = f.astValidators or {},
    transformers    = f.transformers or {},
    validate        = validate,
    custom_apply    = custom_apply,
    apply           = function(self, s)
      local custom = custom_apply
      local default = default_apply
      if custom then
        return custom(s)
      else
        return default(self, s)
      end
    end,
  }, Evaluator)
end

--- @param s string[]
--- @return Highlight?
function Evaluator:validation_hl(s)
  local hl = SyntaxColoring()
  if string.is_non_empty_string_array(s) then
    local _, errors = validate(self, s)

    local first_err = Error.get_first(errors)
    if first_err and first_err.c then
      --- reversed hufbeschlag
      --- due to quirks of display, the error should point
      --- before what it's didactictally simple index is,
      --- and we don't want to burden the validation author
      --- with this detail
      first_err.c = first_err.c - 1
    end
    return { hl = { {} }, parse_err = first_err }
  end
  return hl
end

--- @param label string
--- @param filters Filters?
--- @param custom_apply function?
function Evaluator.plain(label, filters, custom_apply)
  return Evaluator(label, {}, filters, custom_apply)
end

TextEval = Evaluator.plain('text')

local luaParser = require("model.lang.lua.parser")()
local luaTools = {
  parser = luaParser,
  highlighter = luaParser.highlighter
}

--- @param label string?
--- @param filters Filters?
--- @param custom_apply function?
LuaEval = function(label, filters, custom_apply)
  local l = label or 'lua'
  return Evaluator(l, luaTools, filters, custom_apply)
end

local mdParser = require("model.lang.md.parser")
local mdTools = {
  highlighter = mdParser.highlighter
}

--- @param label string?
MdEval = function(label)
  local l = label or 'markdown'
  return Evaluator(l, mdTools)
end

InputEvalText = Evaluator.plain('text input')
local function id(x)
  return x
end
InputEvalLua = Evaluator('lua input', luaTools, nil, id)

ValidatedTextEval = function(filter)
  local ft = Filters.validators_only(filter)
  return Evaluator.plain('plain', ft)
end

LuaEditorEval = (function()
  --- AST validations
  local test = function(ast)
    -- Log.info('AST', Debug.terse_ast(ast, true, 'lua'))
    -- return false, Error('test', 1, 1)
    return true
  end

  --- text validations
  local max_length = function(n)
    return function(s)
      if string.len(s) < n then
        return true
      end
      return false, 'line too long!'
    end
  end
  local line_length = max_length(64)

  local ft = {
    validators = { line_length },
    astValidators = { test },
  }
  return LuaEval(nil, ft)
end)()
