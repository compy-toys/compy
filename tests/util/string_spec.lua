require("util.string.string")

describe("StringUtils #string", function()
  local utest1 = 'когда'
  local utest2 = 'あいうえお'
  local utest3 = "日本"

  describe("splits", function()
    it('ASCII text', function()
      local atest1 = 'asdf'
      local pre, post = string.split_at(atest1, 1)
      assert.equal('', pre)
      assert.equal(atest1, post)
      pre, post = string.split_at(atest1, 2)
      assert.equal('a', pre)
      assert.equal('sdf', post)
    end)

    it('UTF-8 text', function()
      local pre, post = string.split_at(utest1, 1)
      assert.equal('', pre)
      assert.equal('когда', post)
      pre, post = string.split_at(utest1, 2)
      assert.equal('к', pre)
      assert.equal('огда', post)
    end)

    it('CJK text', function()
      local pre, post = string.split_at(utest3, 1)
      assert.equal('', pre)
      assert.equal('日本', post)
      pre, post = string.split_at(utest3, 2)
      assert.equal('日', pre)
      assert.equal('本', post)
    end)

    describe('on char', function()
      local test1 = 'first\nsecond'
      local test1_l1 = 'first'
      local test1_l2 = 'second'
      it('empty', function()
        local res = string.lines('')
        assert.same({ '' }, res)
      end)
      it('one', function()
        local res = string.lines(test1)
        assert.same({ test1_l1, test1_l2 }, res)
      end)

      it('none', function()
        local test = 'text'
        local res = string.lines(test)
        assert.same({ test }, res)
      end)

      it('preceding', function()
        local test = '\nmultiline\ncomment'
        local res = string.lines(test)
        assert.same({ '', 'multiline', 'comment' }, res)
      end)

      it('succeding', function()
        local test = 'multiline\ncomment\n\n'
        local res = string.lines(test)
        assert.same({ 'multiline', 'comment', '', '' }, res)
      end)
    end)

    describe('multiple', function()
      it('1', function()
        local test1 = { 'first\nsecond', 'third' }
        local test1_l1 = 'first'
        local test1_l2 = 'second'
        local test1_2 = 'third'
        local res = string.lines(test1)
        assert.same({ test1_l1, test1_l2, test1_2 }, res)
      end)
      it('2', function()
        local test1 = { 'first\nsecond', '', 'last' }
        local test1_l1 = 'first'
        local test1_l2 = 'second'
        local test1_l3 = ''
        local test1_2 = 'last'
        local res = string.lines(test1)
        assert.same({ test1_l1, test1_l2, test1_l3, test1_2 }, res)
      end)
      it('2b', function()
        local test1 = { 'first\nsecond', '', 'last' }
        local test1_l1 = 'first'
        local test1_l2 = 'second'
        local test1_l3 = ''
        local test1_2 = 'last'
        local res = string.split_array(test1, '\n')
        assert.same({ test1_l1, test1_l2, test1_l3, test1_2 }, res)
      end)
      it('invariance', function()
        local sierpinski = {
          'sierpinski = function(depth)',
          '  lines = { "*" }',
          '  for k = 2, depth + 1 do',
          '    sp = string.rep(" ", 2 ^ (k - 2))',
          '    tmp = { }',
          '    -- comment',
          '    for idx, line in ipairs(lines) do',
          '      tmp.idx = sp .. (line .. sp)',
          '      tmp.add = line .. (" " .. line)',
          '    end',
          '    lines = tmp',
          '  end',
          '  return table.concat(lines, "\\n")',
          'end',
          '',
          'print(sierpinski(4))',
        }
        local res = string.lines(sierpinski)
        assert.same(sierpinski, res)
      end)
    end)
  end)

  describe('substrings UTF-8 text with the other impl', function()
    it('splits', function()
      local s = string.usub(utest1, 1, 3)
      assert.equal('ког', s)
    end)

    it('splits the first char', function()
      local s = string.usub(utest1, 1, 1)
      assert.equal('к', s)
    end)

    it('trivially splits', function()
      local s = string.usub(utest1, 1, 5)
      assert.equal(utest1, s)
    end)

    it('trivially splits (negative end)', function()
      local s = string.usub(utest1, 1, -1)
      assert.equal(utest1, s)
    end)

    it('handles overindexing', function()
      local s = string.usub(utest1, 1, 6)
      assert.equal(utest1, s)
    end)

    it('handles overindexing from the start', function()
      local s = string.usub(utest1, 6)
      assert.equal("", s)
    end)

    describe('indexes negatively', function()
      it('one off', function()
        local s = string.usub(utest1, 1, -2)
        assert.equal('когд', s)
      end)

      it('two off', function()
        local s = string.usub(utest1, 1, -3)
        assert.equal('ког', s)
      end)

      it('off by one', function()
        local s = string.usub(utest1, 1, -5)
        assert.equal('к', s)
      end)

      it('suffix 1', function()
        local s = string.usub(utest1, -1)
        assert.equal('а', s)
      end)

      it('suffix 2', function()
        local s = string.usub(utest1, -2)
        assert.equal('да', s)
      end)

      it('suffix 2 ja', function()
        local s = string.usub(utest2, -2)
        assert.equal('えお', s)
      end)
    end)
  end)

  describe('joins', function()
    local words = { 'first', 'second' }
    it('no char specified', function()
      local res = string.join(words)
      assert.same('first second', res)
    end)
    it('newline specified', function()
      local res = string.unlines(words)
      assert.same('first\nsecond', res)
    end)
    it('comma specified', function()
      local res = string.join(words, ', ')
      assert.same('first, second', res)
    end)

    it('single word', function()
      local word = 'word'
      local w = { word }
      local res = string.join(w, ', ')
      assert.same(word, res)
      res = string.join(word, ', ')
      assert.same(word, res)
    end)

    it('single line', function()
      local str = 'lorem ipsum dolor'
      local w = { str }
      local res = string.unlines(w)
      assert.same(str, res)
      res = string.join(str, ', ')
      assert.same(str, res)
    end)
  end)

  describe('determines emptiness', function()
    it('empty single', function()
      local res = string.is_non_empty_string('')
      assert.is_false(res)
      local res2 = string.is_non_empty_string_array('')
      assert.is_false(res2)
    end)
    it('empty array', function()
      local res = string.is_non_empty_string_array({ '' })
      assert.is_false(res)
    end)
    it('empty array with multiple', function()
      local res = string.is_non_empty_string_array({ '', '' })
      assert.is_false(res)
    end)
    it('nonempty single', function()
      local res = string.is_non_empty_string('a')
      assert.is_true(res)
    end)
    it('nonempty array', function()
      local res = string.is_non_empty_string_array({ 'a', '' })
      assert.is_true(res)
    end)
    it('nonempty array with leading', function()
      local res = string.is_non_empty_string_array({ '', 'a' })
      assert.is_true(res)
    end)
  end)

  describe('wraps strings', function()
    it('even', function()
      local test1 = '123qweдлв'
      local test1_l1 = '123'
      local test1_l2 = 'qwe'
      local test1_l3 = 'длв'
      local res = string.wrap_at(test1, 3)
      assert.same({ test1_l1, test1_l2, test1_l3 }, res)
    end)
    it('with remainder', function()
      local test1 = 'длвqwe1234'
      local test1_l1 = 'длв'
      local test1_l2 = 'qwe'
      local test1_l3 = '123'
      local test1_l4 = '4'
      local res = string.wrap_at(test1, 3)
      assert.same({
        test1_l1,
        test1_l2,
        test1_l3,
        test1_l4 }, res)
    end)
    it('shorter', function()
      local test1 = '1234'
      local res = string.wrap_at(test1, 5)
      assert.same({ test1 }, res)
    end)
    it('empty', function()
      local test1 = ''
      local res = string.wrap_at(test1, 5)
      assert.same({ test1 }, res)
    end)
    it('whitespace', function()
      local test1 = ' '
      local res = string.wrap_at(test1, 5)
      assert.same({ test1 }, res)
    end)
    it('whitespace break', function()
      local test1 = ' '
      local res = string.wrap_at(test1 .. test1, 1)
      assert.same({ test1, test1 }, res)
    end)

    it('unicode', function()
      local test1 = "An expression was expected, and `�' can 't start an expression "
      local exp = { 'An expression was expected, an'
      , "d `�' can 't start an expressi"
      , 'on ' }
      local res = string.wrap_at(test1, 30)
      assert.same(exp, res)
    end)
  end)

  describe('wraps string arrays', function()
    it('empty', function()
      local e = {}
      local res = string.wrap_array(e, 80)
      assert.same(e, res)
    end)
    it('short', function()
      local e = { 'a', 'b' }
      local res = string.wrap_array(e, 8)
      assert.same(e, res)
    end)
    it('', function()
      local test1 = { '123456', 'asdfjkl;' }
      local res = string.wrap_array(test1, 3)
      assert.same({
        '123', '456', 'asd', 'fjk', 'l;'
      }, res)
    end)
    it('nowrap', function()
      local t = {
        ' comment1',
        ' comment2',
      }
      local res = string.wrap_array(t, 80)
      assert.same(t, res)
    end)
  end)

  describe('determines length', function()
    it('empty', function()
      assert.same(0, string.ulen(''))
    end)
    it('space', function()
      assert.same(1, string.ulen(' '))
    end)
    it('spaces', function()
      assert.same(3, string.ulen('   '))
    end)
    it('test 1', function()
      assert.same(5, string.ulen(utest1))
    end)
    it('test 2', function()
      assert.same(5, string.ulen(utest2))
    end)
  end)

  describe('splices', function()
    local function toTable(pre, mid, post)
      return {
        pre = pre, mid = mid, post = post
      }
    end
    local empty = { pre = '', mid = '', post = '' }

    it('empty', function()
      local t = ''
      local res = toTable(string.splice(t, 1, 2))
      assert.same(empty, res)
    end)

    it('', function()
      local t = 'test text'
      local exp = { pre = 'test', mid = ' ', post = 'text' }
      local res = toTable(string.splice(t, 4, 5))
      assert.same(exp, res)
    end)

    it('weird indices', function()
      local t = 'test text'
      local res = toTable(string.splice(t, 5, 1))
      assert.same(empty, res)

      res = toTable(string.splice(t, 304, 305))
      local exp = { pre = t, mid = '', post = '' }
      assert.same(exp, res)
    end)
  end)

  describe('validates', function()

  end)

  describe('matches', function()
    it('simple', function()
      assert.is_true(string.matches('abc', ''))
      assert.is_true(string.matches('ASD', 'S'))
      assert.is_true(string.matches('A123', '3'))
      assert.is_true(string.matches_r('abc', '.'))
      assert.is_true(string.matches_r('abc', '[cd]'))
      assert.is_true(string.matches_r('abc', '%S'))

      assert.is_false(string.matches('abc', 'd'))
      assert.is_false(string.matches('abc', '1'))
      assert.is_false(string.matches_r('abc', '%W'))
    end)
  end)
end)
