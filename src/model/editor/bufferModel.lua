require("model.editor.content")
local analyzer = require("model.lang.lua.analyze")
local bsi = require("model.editor.bufferSemanticInfo")

local class = require('util.class')
require('util.table')
require('util.range')
require('util.string.string')
require('util.dequeue')

--- Convert Blocks to string array
--- @param blocks Block[]
--- @return Dequeue<string>
local function render_blocks(blocks)
  local ret = Dequeue.typed('string')
  for _, v in ipairs(blocks) do
    if v:is_empty() then
      ret:append('')
    else
      ret:append_all(v.lines)
    end
  end
  ret:append('')
  return ret
end

--- Todo: convert to class, store revmap
--- @alias Content Dequeue<string>|Dequeue<Block>

--- @param name string
--- @param content string
--- @param save function
--- @param chunker Chunker?
--- @param highlighter Highlighter?
--- @param printer function?
--- @return BufferModel?
local function new(name, content, save,
                   chunker, highlighter, printer)
  local _content, sel, ct, semantic
  local readonly = false

  local lines = string.lines(content or '')

  local function plaintext()
    ct = 'plain'
    _content = Dequeue(lines, 'string')
    sel = #_content + 1
  end
  --- only passing this around so the linter shuts up about nil
  --- @param chk function
  local function luacontent(chk)
    ct = 'lua'
    local ok, blocks = chk(lines)
    if ok then
      local len = #blocks
      sel = len + 1
    else
      readonly = true
      sel = 1
    end
    _content = blocks
  end

  if type(chunker) == "function" then
    luacontent(chunker)
  elseif type(highlighter) == 'function' then
    plaintext()
    ct = 'md'
  else
    plaintext()
  end

  return {
    name = name or 'untitled',
    content = _content,
    content_type = ct,
    save_file = save,
    chunker = chunker,
    highlighter = highlighter,
    printer = printer,
    revmap = {},
    semantic = semantic,
    selection = sel,
    readonly = readonly
  }
end

--- @class BufferModel
--- @field name string
--- @field content Dequeue -- Content
--- @field content_type ContentType
--- @field save_file function
--- @field selection integer
--- @field loaded integer?
--- @field readonly boolean
--- @field semantic BufferSemanticInfo?
--- @field revmap table?
---
--- @field chunker Chunker
--- @field highlighter Highlighter
--- @field printer Printer
--- @field move_selection function
--- @field get_selection function
--- @field get_selected_text function
--- @field delete_selected_text function
--- @field replace_selected_text function
--- @field get_text_content function
BufferModel = class.create(new)

function BufferModel:analyze()
  if self.content_type ~= 'lua' then return end
  local lines = string.lines(self:get_text_content())
  local ok, blocks, ast = self.chunker(lines)
  if not ok then return end
  local anaok, ana = pcall(analyzer.analyze, ast)
  if not anaok then return end
  for bi, v in ipairs(blocks) do
    if (v.pos) then
      for _, l in ipairs(v.pos:enumerate()) do
        self.revmap[l] = bi
      end
    end
  end
  self.semantic = bsi.convert(ana, self.revmap)
end

function BufferModel:rechunk()
  if self.content_type ~= 'lua' then return end
  local content = self:get_text_content()
  local _, blocks = self.chunker(content)
  self.content = blocks
end

function BufferModel:save()
  self:highlight()
  local text = self:get_text_content()
  self:analyze()
  return self.save_file(text)
end

function BufferModel:highlight()
  if self.highlighter then
    local text = self:get_text_content()
    self.hl = self.highlighter(text)
  end
end

--- @return Dequeue
function BufferModel:get_content()
  return self.content
end

--- Return the buffer content as a string array
--- @return string[] content
function BufferModel:get_text_content()
  --- TODO require
  require = _G.o_require or _G.require
  if self.content_type == 'lua'
  then
    return render_blocks(self.content)
  else
    return self.content:items()
  end
end

--- @return SyntaxColoring? hl
function BufferModel:get_highlight()
  if self.highlighter
  then
    return self.hl
  end
end

--- Returns number of lines/blocks
--- @return integer
function BufferModel:get_content_length()
  return #(self.content) or 0
end

--- @param dir VerticalDir
--- @param by integer
--- @param warp boolean?
--- @param move boolean?
--- @return boolean moved
function BufferModel:move_selection(dir, by, warp, move)
  local l = self:get_content_length()
  local last = (function()
    if move then return l end
    return l + 1
  end)()
  if warp then
    if dir == 'up' then
      self.selection = 1
      return true
    end
    if dir == 'down' then
      self.selection = last
      return true
    end
    return false
  end

  local cur = self.selection
  local by = by or 1
  if dir == 'up' then
    if (cur - by) >= 1 then
      self.selection = cur - by
      return true
    end
  end
  if dir == 'down' then
    if (cur + by) <= last then
      self.selection = cur + by
      return true
    end
  end
  return false
end

--- @param sel integer
function BufferModel:set_selection(sel)
  self.selection = sel
end

--- Get index of selected line/block
--- @return integer blocknum
function BufferModel:get_selection()
  return self.selection
end

--- @private
--- @return Block?
function BufferModel:_get_selected_block()
  if self.content_type == 'plain' then return end

  local sel = self.selection
  if sel == self:get_content_length() + 1 then
    local ln = self.content:last().pos.fin + 1
    return Empty(ln)
  end
  return self.content[sel]
end

--- Get the line number of selection first line
--- @return integer
function BufferModel:get_selection_start_line()
  if self.content_type == 'lua' then
    local b = self:_get_selected_block()
    if b then
      local ln = b.pos.start
      return ln
    end
  end
  return self.selection
end

--- Return the selection as string array
--- @return string[]
function BufferModel:get_selected_text()
  local sel = self.selection
  if self.content_type == 'lua' then
    --- @type Block
    local s = self.content[sel]
    if table.is_instance(s, 'chunk') then
      return table.clone(s.lines)
    else
      return {}
    end
  else
    return self.content[sel] or {}
  end
end

------------------
---   modify   ---
------------------

--- @param rechunk boolean?
function BufferModel:_text_change(rechunk)
  if self.content_type == 'lua' then
    if rechunk then
      self:rechunk()
      self:rechunk()
    end
  end
  if self.content_type == 'md' then
    self:highlight()
  end
end

function BufferModel:delete_selected_text()
  local sel = self.selection
  if self.content_type == 'lua' then
    local sb = self.content[sel]
    if not sb then return end

    local l = sb.pos:len()
    self.content:remove(sel)
    for i = sel, self:get_content_length() do
      local b = self.content[i]
      local r = b.pos
      b.pos = r:translate(-l)
    end
  else
    self.content:remove(sel)
  end
  self:_text_change()
end

--- @param t string[]|Block[]
--- @return boolean insert
--- @return integer? inserted_lines
function BufferModel:replace_selected_text(t)
  if self.content_type == 'lua' then
    local chunks = t
    local n = #chunks
    if n == 0 then
      return false
    end
    local sel = self.selection
    --- content start and original length
    local cs, ol = (function()
      local current = self.content[sel]
      if current then
        return current.pos.start, self.content[sel].pos:len()
      end
      local last = self.content:last()
      if last then
        return self.content:last().pos.fin + 1, 0
      else --- empty file
        return 1, 0
      end
    end)()

    if n == 1 then
      local c = chunks[1]
      local nr = c.pos:translate(cs - 1)
      c.pos = nr
      self.content[sel] = chunks[1]
    else
      --- remove old chunk
      self.content:remove(sel)
      --- insert new version of the chunk(s)
      for i = #chunks, 1, -1 do
        local c = chunks[i]
        local nr = c.pos:translate(cs - 1)
        c.pos = nr
        self.content:insert(c, sel)
      end
    end
    --- move subsequent chunks down
    local diff = chunks[n].pos:len() - ol
    if diff ~= 0 then
      for i = sel + 1, self:get_content_length() do
        local b = self.content[i]
        b.pos = b.pos:translate(diff)
      end
    end

    self:_text_change()
    return true, n
  else
    local sel = self.selection
    local clen = #(self.content)
    local ti = sel
    if #t == 1 then
      self.content[ti] = t[1]
      if ti > clen then
        self:_text_change()
        return true, 1
      end
    else
      self.content:remove(ti)
      for i = #t, 1, -1 do
        self.content:insert(t[i], ti)
      end
      self:_text_change()
      return true, #t
    end
    return false
  end
end

--- Insert a new line or empty block _before_ the selection
--- @param i integer?
function BufferModel:insert_newline(i)
  --- block or line number
  local bln = i or self:get_selection()
  if self.content_type == 'lua' then
    local sb = self.content[bln]
    if not sb then return end
    local prev_b = self.content[bln - 1]
    -- disallow consecutive empties
    local prev_empty = prev_b and prev_b:is_empty()
    local sel_empty = sb:is_empty()
    local cons = prev_empty or sel_empty
    if cons then return end

    local ln = self:get_selection_start_line()
    self.content:insert(Empty(ln), bln)
    self:_text_change(true)
  else
    self.content:insert('', bln)
    self:_text_change()
  end
end

--- @param i integer
--- @param npos integer
function BufferModel:move(i, npos)
  self.content:move(i, npos)
  self:_text_change(true)
end

------------------
---   loaded   ---
------------------

--- Record index of selection loaded into input
--- @param i integer?
function BufferModel:set_loaded(i)
  local n = i or self:get_selection()
  self.loaded = n
end

function BufferModel:clear_loaded()
  self.loaded = nil
end

--- Check whether the current selection is the same as the one
--- loaded previously. The default value if nothing is loaded
--- is use-case dependent, so it's supplied via parameter.
--- @param default boolean
--- @return boolean
function BufferModel:loaded_is_sel(default)
  --- only check if there is in fact something to compare to
  if not self.loaded then
    return default
  end
  return self.loaded == self.selection
end

--- Change selection to previously loaded
function BufferModel:select_loaded()
  local l = self.loaded
  if l then
    self.selection = l
  end
end
