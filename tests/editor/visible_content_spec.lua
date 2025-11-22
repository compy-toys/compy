require("view.editor.visibleContent")
require("model.input.cursor")

require("util.string.string")

local md_ex = [[### Input validation

As an extension to the user input functionality, `validated_input()` allows arbitrary user-specified filters.
A "filter" is a function, which takes a string as input and returns a boolean value of whether it is valid and an optional `Error`.
The `Error` is structure which contains the error message (`msg`), and the location the error comes from, with line and character fields (`l` and `c`).

#### Helper functions

* `string.ulen(s)` - as opposed to the builtin `len()`, this works for unicode strings
* `string.usub(s, from, to)` - unicode substrings
* `Char.is_alpha(c)` - is `c` a letter
* `Char.is_alnum(c)` - is `c` a letter or a number (alphanumeric)
]]

describe('VisibleContent #visible', function()
  local md_text = string.lines(md_ex)
  local w = 64
  local turtle_doc = {
    '',
    'Turtle graphics game inspired the LOGO family of languages.',
    '',
  }

  it('translates', function()
    local visible = VisibleContent(w, md_text, 1, 8)
    --- scroll to the top
    visible:move_range(- #md_text)
    local cur11 = Cursor()
    local cur33 = Cursor(3, 3)
    local cur3w = Cursor(3, w)
    local cur3wp1 = Cursor(3, w + 1)
    local cur44 = Cursor(4, 4)
    assert.same(cur11, visible:translate_to_wrapped(cur11))
    assert.same(cur33, visible:translate_to_wrapped(cur33))
    assert.same(cur3w, visible:translate_to_wrapped(cur3w))
    assert.same(Cursor(4, 1), visible:translate_to_wrapped(cur3wp1))

    assert.same(cur33, visible:translate_from_visible(cur33))
    local cur3_67 = Cursor(3, 3 + w)
    local exp3_67 = Cursor(4, 3)
    assert.same(exp3_67, visible:translate_to_wrapped(cur3_67))

    --- scroll to bottom
    visible:to_end()
    -- #01: ''
    -- #02: '* `string.ulen(s)` - as opposed to the builtin `len()`, this wor'
    -- #03: 'ks for unicode strings'
    -- #04: '* `string.usub(s, from, to)` - unicode substrings'
    -- #05: '* `Char.is_alpha(c)` - is `c` a letter'
    -- #06: '* `Char.is_alnum(c)` - is `c` a letter or a number (alphanumeric'
    -- #07: ')'
    -- #08: ''
    assert.same(Cursor(9, 3 + w),
      visible:translate_from_visible(cur33))
    assert.same(Cursor(10, 4),
      visible:translate_from_visible(cur44))
    assert.is_nil(visible:translate_from_visible(Cursor(5, 40)))
    local cur71 = Cursor(7, 1)
    assert.same(Cursor(12, 65),
      visible:translate_from_visible(cur71))
  end)
  local os_max = 8
  local input_max = 16

  local content1 = VisibleContent(80, {},
    os_max, input_max)
  local content2 = VisibleContent(30, turtle_doc,
    os_max, input_max)
  describe('produces forward mapping', function()
    it('1', function()
      local fwd1 = { { 1 } }
      assert.same(fwd1, content1.wrap_forward)
    end)
    it('2', function()
      local fwd2 = { { 1 }, { 2, 3 }, { 4 }, { 5 } }
      assert.same(fwd2, content2.wrap_forward)
    end)
  end)
  describe('produces reverse mapping', function()
    it('1', function()
      local rev1 = { 0 }
      assert.same(rev1, content1.wrap_reverse)
    end)
    it('2', function()
      local rev2 = { 1, 2, 2, 3, 4 }
      assert.same(rev2, content2.wrap_reverse)
    end)
  end)

  describe('correctly determines visible range', function()
    local w = 5
    local L = 4
    local starter = '123'
    local wrapper = VisibleContent(w, { starter }, 0, L)
    it('1', function()
      assert.same({ starter }, wrapper:get_text())
      assert.same(1, wrapper:get_text_length())
      wrapper:check_range()
      assert.same(Range(1, 1), wrapper:get_range())
    end)
  end)
end)
