require("view.editor.visibleBlock")

require("util.wrapped_text")
require("util.scrollable")
require("util.range")

--- @class VSCOpts
--- @field wrap_w integer
--- @field size_max integer
--- @field overscroll_max integer
--- @field cfg ViewConfig
--- @alias ReverseMap Dequeue<integer>
--- Inverse mapping from line number to block index

--- @class VisibleStructuredContent: WrappedText
--- @field offset integer
--- @field overscroll integer
--- @field highlighter fun(c: string[]): SyntaxColoring
--- @field size_max integer
--- @field range Range?
--- @field v_blocks Dequeue<VisibleBlock>
--- @field reverse_map ReverseMap
---
--- @field set_range fun(self, Range)
--- @field get_range fun(self): Range
--- @field move_range fun(self, integer): integer
--- @field load_blocks fun(self, blocks: Block[])
--- @field recalc_range function
--- @field get_visible fun(self): string[]
--- @field get_visible_blocks fun(self): VisibleBlock[]
--- @field get_content_length fun(self): integer
--- @field get_block_pos fun(self, integer): Range?
--- @field get_block_app_pos fun(self, integer): Range?
--- @field get_more fun(self): More
--- @field to_end fun(self)

VisibleStructuredContent = {}
VisibleStructuredContent.__index = VisibleStructuredContent

setmetatable(VisibleStructuredContent, {
  __index = WrappedText,
  __call = function(cls, ...)
    return cls.new(...)
  end,
})

--- @param opts VSCOpts
--- @param blocks Block[]
--- @param highlighter fun(c: string[]): SyntaxColoring
--- @return VisibleStructuredContent
function VisibleStructuredContent.new(
    opts,
    blocks,
    highlighter)
  local self = setmetatable({
    overscroll = opts.overscroll_max,
    opts = opts,
    highlighter = highlighter,
  }, VisibleStructuredContent)
  self:load_blocks(blocks)
  self:to_end()

  return self
end

--- Set the visible range so that last of the content is visible
function VisibleStructuredContent:to_end()
  self.range = Scrollable.to_end(
    self.opts.size_max, self:get_text_length())
  self.offset = self.range.start - 1
end

--- Process a list of blocks into VisibleBlocks
--- @param blocks Block[]
function VisibleStructuredContent:load_blocks(blocks)
  local fulltext = Dequeue.typed('string')
  local revmap = Dequeue.typed('integer')
  local visible_blocks = Dequeue()
  local off = 0
  local w = self.opts.wrap_w
  for bi, v in ipairs(blocks) do
    if v:is_empty() then
      fulltext:append('')
      local npos = v.pos:translate(off)
      visible_blocks:append(
        VisibleBlock(w, { '' }, {}, v.pos, npos))
    else
      fulltext:append_all(v.lines)
      local hl = self.highlighter(v.lines)
      local vblock = VisibleBlock(w, v.lines, hl,
        v.pos, v.pos:translate(off))
      off = off + vblock.wrapped.n_breaks
      visible_blocks:append(vblock)
    end
    if (v.pos) then
      for _, l in ipairs(v.pos:enumerate()) do
        revmap[l] = bi
      end
    end
  end
  WrappedText._init(self, self.opts.wrap_w, fulltext)
  self:_init()
  self.reverse_map = revmap
  self.v_blocks = visible_blocks
end

function VisibleStructuredContent:recalc_range()
  local ln, aln = 1, 1
  for _, v in ipairs(self.v_blocks) do
    local l = #(v.wrapped.orig)
    local al = #(v.wrapped.text)
    v.pos = Range(ln, ln + l - 1)
    v.app_pos = Range(aln, aln + al - 1)
    ln = ln + l
    aln = aln + al
  end
end

--- @private
function VisibleStructuredContent:_update_meta()
  local rev = self.wrap_reverse
  local rl = #rev
  local fwd = self.wrap_forward
  table.insert(rev, ((rev[rl] or 0) + 1))
  table.insert(fwd, { #(self.text) + 1 })
  self:_update_overscroll()
end

--- @protected
function VisibleStructuredContent:_update_overscroll()
  local len = WrappedText.get_text_length(self)
  local over = math.min(self.opts.overscroll_max, len)
  self.overscroll = over
end

--- @protected
function VisibleStructuredContent:_init()
  self:_update_overscroll()
end

--- @param text string[]
function VisibleStructuredContent:wrap(text)
  WrappedText.wrap(self, text)
  self:_update_meta()
end

--- @return Range
function VisibleStructuredContent:get_range()
  return self.range
end

--- @param r Range
function VisibleStructuredContent:set_range(r)
  self.range = r
end

--- @param by integer
--- @return integer n
function VisibleStructuredContent:move_range(by)
  if type(by) == "number" then
    local r = self.range
    local upper = self:get_text_length() + self.overscroll
    local nr, n = r:translate_limit(by, 1, upper)
    self:set_range(nr)
    return n
  end
  return 0
end

function VisibleStructuredContent:get_visible()
  local si, ei = self.range.start, self.range.fin
  return table.slice(self.text, si, ei)
end

function VisibleStructuredContent:get_visible_blocks()
  local si = self.wrap_reverse[self.range.start]
  local ei = self.wrap_reverse[self.range.fin]
  local sbi, sei = self.reverse_map[si], self.reverse_map[ei]
  return table.slice(self.v_blocks, sbi, sei)
end

--- @return integer
function VisibleStructuredContent:get_content_length()
  return self:get_text_length()
end

--- @param bn integer
--- @return Range?
function VisibleStructuredContent:get_block_pos(bn)
  local cl = #(self.v_blocks)
  if bn > 0 and bn <= cl then
    return self.v_blocks[bn].pos
  elseif cl == 0 then --- empty/new file
    Range.singleton(1)
  elseif bn == cl + 1 then
    return Range.singleton(self.v_blocks[cl].pos.fin + 1)
  end
end

--- @param bn integer
--- @return Range?
function VisibleStructuredContent:get_block_app_pos(bn)
  local cl = #(self.v_blocks)
  if bn > 0 and bn <= cl then
    return self.v_blocks[bn].app_pos
  elseif bn == cl + 1 then
    local wr = self.wrap_reverse
    return Range.singleton(#wr)
  end
end

--- @return More
function VisibleStructuredContent:get_more()
  local vrange = self:get_range()
  local vlen = self:get_content_length()
  local more = {
    up = vrange.start > 1,
    down = vrange.fin < vlen
  }
  return more
end
