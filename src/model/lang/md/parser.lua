local ct = require("conf.md")
local luahl = require("model.lang.lua.parser")().highlighter
require("model.lang.highlight")
require("util.string.string")
require("util.debug")
require("util.dequeue")

local add_paths = {
  'lib/' .. 'djot' .. '/?.lua',
  'lib/?.lua',
}
if love and not TESTING then
  local love_paths = string.join(add_paths, ';')
  love.filesystem.setRequirePath(
    love.filesystem.getRequirePath() .. love_paths)
else
  local lib_paths = string.join(add_paths, ';src/')
  package.path = lib_paths .. ';' .. package.path
end

local djot = require("djot.djot")


--- @alias MdTagType
--- | 'heading'
--- | 'list'
--- | 'list_item'
--- | 'block_attributes'
--- | 'attributes'
--- | 'footnote'
--- | 'note_label'
--- | 'table'
--- | 'row'
--- | 'image'
--- | 'link'

--- @alias MdTokenType
--- | 'header'
--- | 'link'
--- | 'bold'
--- | 'italic'
--- | 'list'
--- | 'hr'
--- | 'code'

--- There's no proper namespacing on the type annotation level,
--- hence restating the djot AST type
--- @class mdAST
--- @field tag string
--- @field s? string
--- @field children mdAST[]
--- @field pos? string[]

local tag_to_type = {
  str        = 'default',
  heading    = 'heading',
  emph       = 'emph',
  strong     = 'strong',
  verbatim   = 'code',
  code_block = 'code',
  list_item  = 'list_marker',
  link       = 'link',
  image      = 'link',
}

local function logwarn(wt)
  Log.debug(Debug.terse_ast(wt, true))
end

--- @param input str
--- @param skip_posinfo boolean?
--- @return djotAST
local function parse(input, skip_posinfo)
  local text = string.unlines(input)
  local posinfo = not (skip_posinfo == true)

  return djot.parse(text, posinfo, logwarn)
end

local function is_lua_block(t)
  if not type(t) == "table" then return false end
  return t.t == 'code_block' and t.lang == 'lua'
end

--- @param pos string[]
local function convert_pos(pos)
  local startPos, endPos = pos[1], pos[2]

  local startLine, startChar = startPos:match("(%d+):(%d+):")
  local endLine, endChar = endPos:match("(%d+):(%d+):")
  local sl, sc = tonumber(startLine), tonumber(startChar)
  local el, ec = tonumber(endLine), tonumber(endChar)
  return sl, sc, el, ec
end

--- courtesy of Claude
--- @param node mdAST
--- @param tags? string[][]
--- @return string[][] tags
local function transformAST(node, tags)
  tags = tags or {}

  if node.pos then
    local text = node.s
    local sl, sc, el, ec = convert_pos(node.pos)

    for line = sl, el do
      tags[line] = tags[line] or {}

      local lineStartChar = (line == sl) and sc or 1
      local lineEndChar =
          (line == el)
          and ec
          or string.ulen(text or ' ')

      for char = lineStartChar, lineEndChar do
        tags[line][char] = node.tag
      end
    end
  end

  if node.children then
    for _, child in ipairs(node.children) do
      transformAST(child, tags)
    end
  end

  return tags
end

--- Recursively filters nodes in a tree structure
--- @param node mdAST
--- @param pred function
--- @param results? table
--- @return table
local function filter_tree(node, pred, results)
  if not node or not pred then return {} end

  local results = results or {}

  if pred(node) then
    table.insert(results, node)
  end
  if node.children then
    for _, child in ipairs(node.children) do
      local filtered_children = filter_tree(child, pred)
      for _, c in pairs(filtered_children) do
        table.insert(results, c)
      end
    end
  end

  return results
end

--- Highlight string array
--- @param input str
--- @return SyntaxColoring
local highlighter = function(input)
  local doc = parse(input) --[[@as mdAST]]
  local code_blocks = filter_tree(doc, is_lua_block)

  local colored_tokens = SyntaxColoring()
  local tagged = transformAST(doc)

  for l, line in pairs(tagged) do
    for i, c in pairs(line) do
      local typ = tag_to_type[c]
      if typ then
        colored_tokens[l][i] = ct[typ]
      end
    end
  end
  for _, cb in ipairs(code_blocks) do
    local sl, sc = convert_pos(cb.pos)
    local stripped = (function()
      --- remove trailing newline if present
      if string.sub(cb.s, -1) == '\n' then
        return string.sub(cb.s, 1, -2)
      end
      return cb.s
    end)()
    local hl = luahl(stripped)
    for l, line in pairs(hl) do
      for i, c in pairs(line) do
        colored_tokens[l + sl][i + sc - 1] = c
      end
    end
  end
  return colored_tokens
end

return {
  parse        = parse,
  highlighter  = highlighter,
  transformAST = transformAST,
}
