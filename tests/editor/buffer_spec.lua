require('model.editor.bufferModel')
local parser = require('model.lang.lua.parser')()

require('util.table')


describe('Buffer #editor', function()
  local w = 64
  local chunker = function(t, single)
    return parser.chunker(t, w, single)
  end
  -- local chunker = parser.chunker
  local hl = parser.highlighter

  local noop = function() end

  it('renders plaintext', function()
    local l1 = 'line 1'
    local l2 = 'line 2'
    local l3 = 'x = 1'
    local l4 = 'the end'
    local tst = { l1, l2, l3, l4 }
    local cbuffer = BufferModel('untitled', tst, noop)
    local bc = cbuffer:get_content()
    assert.same(cbuffer.content_type, 'plain')
    assert.same(4, #bc)
    assert.same(l1, bc[1])
    assert.same(l2, bc[2])
    assert.same(l3, bc[3])
    assert.same(l4, bc[4])
  end)

  it('renders lua', function()
    local l1 = '--- comment 1'
    local l2 = '--- comment 2'
    local l3 = 'x = 1'
    local l4 = '--- comment end'
    local tst = { l1, l2, l3, l4 }
    local cbuffer = BufferModel('untitled.lua', tst, noop, chunker, hl)
    local bc = cbuffer:get_content()
    assert.same(cbuffer.content_type, 'lua')
    assert.same(4, #bc)
    assert.same({ l1 }, bc[1].lines)
    assert.same({ l2 }, bc[2].lines)
    assert.same({ l3 }, bc[3].lines)
    assert.same({ l4 }, bc[4].lines)
  end)

  describe('setup', function()
    local meat = [[function sierpinski(depth)
  lines = { '*' }
  for i = 2, depth + 1 do
    sp = string.rep(' ', 2 ^ (i - 2))
    tmp = {} -- comment
    for idx, line in ipairs(lines) do
      tmp[idx] = sp .. line .. sp
      tmp[idx + #lines] = line .. ' ' .. line
    end
    lines = tmp
  end
  return table.concat(lines, '\n')
end]]
    local txt = string.lines([[--- @param depth integer
]] .. meat .. [[


print(sierpinski(4))]])
    local buffer = BufferModel('test.lua', txt, noop, chunker, hl)
    it('sets name', function()
      assert.same('test.lua', buffer.name)
    end)
    local bufcon = buffer:get_content()
    it('sets content', function()
      assert.same('block', bufcon:type())
      assert.same(4, #bufcon)
      assert.same({ '--- @param depth integer' }, bufcon[1].lines)
      assert.same(string.lines(meat), bufcon[2].lines)
      assert.is_true(table.is_instance(bufcon[3], 'empty'))
      assert.same({ 'print(sierpinski(4))' }, bufcon[4].lines)
    end)
  end)

  describe('modifications', function()
    describe('plaintext', function()
      local turtle_doc = {
        '',
        'Turtle graphics game inspired the LOGO family of languages.',
      }
      local buffer = BufferModel('README', turtle_doc)
      it('insert newline', function()
        assert.same(#turtle_doc + 1, buffer:get_selection())
        local qed = 'qed.'
        buffer:replace_selected_text({ qed })
        assert.same(#turtle_doc + 1, buffer:get_selection())
        assert.same(qed, buffer:get_selected_text())
        buffer:insert_newline()
        local new = {
          '',
          'Turtle graphics game inspired the LOGO family of languages.',
          '',
          qed,
        }
        assert.same(new, buffer:get_text_content())
      end)
    end)

    describe('lua', function()
      local turtle = {
        '--- @diagnostic disable',
        'width, height = gfx.getDimensions()',
        'midx = width / 2',
        'midy = height / 2',
        'incr = 5',
        '',
        'tx, ty = midx, midy',
        'debug = false',
        'debugColor = Color.yellow',
        '',
        'bg_color = Color.black',
        '',
        'local function drawHelp()',
        '  gfx.setColor(Color[Color.white])',
        '  gfx.print("Press [I] to open console", 20, 20)',
        '  gfx.print("Enter \'forward\', \'back\', \'left\', or \'right\' to move the turtle!", 20, 40)',
        'end',
        '',
        'local function drawDebuginfo()',
        '  gfx.setColor(Color[debugColor])',
        '  local label = string.format("Turtle position: (%d, %d)", tx, ty)',
        '  gfx.print(label, width - 200, 20)',
        'end',
        '',
        'function love.draw()',
        '  drawBackground()',
        '  drawHelp()',
        '  drawTurtle(tx, ty)',
        '  if debug then drawDebuginfo() end',
        'end',
        '',
        'function love.keypressed(key)',
        '  if love.keyboard.isDown("lshift", "rshift") then',
        '    if key == \'r\' then',
        '      tx, ty = midx, midy',
        '    end',
        '  end',
        '  if key == \'space\' then',
        '    debug = not debug',
        '  end',
        '  if key == \'pause\' then',
        '    stop()',
        '  end',
        'end',
        '',
        'function love.keyreleased(key)',
        '  if key == \'i\' then',
        '    input_text(r)',
        '  end',
        '  if key == \'return\' then',
        '    eval()',
        '  end',
        '',
        '  if love.keyboard.isDown("lctrl", "rctrl") then',
        '    if key == "escape" then',
        '      love.event.quit()',
        '    end',
        '  end',
        'end',
        '',
        'local t = 0',
        'function love.update(dt)',
        '  t = t + dt',
        '  if ty > midy then',
        '    debugColor = Color.red',
        '  end',
        'end',
        '',
      }
      local text = turtle

      local buffer = BufferModel('main.lua', text,
        noop, chunker, hl)
      local bc = buffer:get_content()
      local n_blocks = 24
      it('invariants', function()
        assert.same(n_blocks, #bc)
        assert.same(n_blocks, buffer:get_content_length())

        assert.same(text, buffer:get_text_content())

        assert.same(n_blocks + 1, buffer:get_selection())
        local ln = buffer:get_selection_start_line()
        assert.same(68, ln)
      end)

      it('dropping blocks', function()
        local delbuf = table.clone(buffer)
        delbuf:move_selection('up', nil, true)
        assert.same(1, delbuf:get_selection())
        delbuf:delete_selected_text()
        assert.same(n_blocks - 1, delbuf:get_content_length())
        delbuf:delete_selected_text()
        assert.same(n_blocks - 2, delbuf:get_content_length())
        assert.same(1, delbuf:get_selection())
        assert.same({ text[3] }, delbuf:get_selected_text())
      end)

      it('insert empty', function()
        local embuf = table.clone(buffer)
        embuf:move_selection('up', nil, true)
        assert.same(1, embuf:get_selection())
        embuf:insert_newline()
        assert.same('', embuf:get_text_content()[1])
        embuf:move_selection('down', 2)
        assert.same(3, embuf:get_selection())
        assert.same({ 'width, height = gfx.getDimensions()' }, embuf:get_selected_text())

        local res = {
          '',
          '--- @diagnostic disable',
          '',
          'width, height = gfx.getDimensions()',
          'midx = width / 2',
        }
        assert.same(3, embuf:get_selection())
        embuf:insert_newline()
        assert.same(3, embuf:get_selection())
        assert.same(res, table.take(embuf:get_text_content(), 5))
        --- no consecutive empties
        embuf:insert_newline()
        assert.same(res, table.take(embuf:get_text_content(), 5))
        embuf:move_selection('down')
        assert.same({ 'width, height = gfx.getDimensions()' }, embuf:get_selected_text())
        embuf:insert_newline()
        assert.same(res, table.take(embuf:get_text_content(), 5))
      end)

      it('replacing single line with empty', function()
        local replbuf = table.clone(buffer)
        replbuf:move_selection('down', nil, true)
        replbuf:move_selection('up', 2)

        local ln = replbuf:get_selection_start_line()
        assert.same(61, ln)
        assert.same({ 'local t = 0' }, replbuf:get_selected_text())
        assert.same({ text[ln] }, replbuf:get_selected_text())

        local empty = Empty(ln)
        local ins, n = replbuf:replace_selected_text({ empty })
        assert.truthy(ins)
        assert.same(1, n)
      end)
      it('replacing block with empty', function()
        local replbuf = table.clone(buffer)
        replbuf:move_selection('down', nil, true)
        replbuf:move_selection('up', 1)

        local ln = replbuf:get_selection_start_line()
        assert.same(
          { 'function love.update(dt)',
            '  t = t + dt',
            '  if ty > midy then',
            '    debugColor = Color.red',
            '  end',
            'end', },
          replbuf:get_selected_text())

        local empty = Empty(ln)
        local ins, n = replbuf:replace_selected_text({ empty })
        assert.truthy(ins)
        assert.same(1, n)
      end)
      it('replacing middle block with empty', function()
        local replbuf = table.clone(buffer)
        replbuf:move_selection('down', nil, true)
        replbuf:move_selection('up', 4)

        local ln = replbuf:get_selection_start_line()
        assert.same(46, ln)
        assert.same({
            'function love.keyreleased(key)',
            "  if key == 'i' then",
            '    input_text(r)',
            '  end',
            "  if key == 'return' then",
            '    eval()',
            '  end',
            '',
            '  if love.keyboard.isDown("lctrl", "rctrl") then',
            '    if key == "escape" then',
            '      love.event.quit()',
            '    end',
            '  end',
            'end',
          },
          replbuf:get_selected_text())

        local empty = Empty(ln)
        local ins, n = replbuf:replace_selected_text({ empty })
        assert.truthy(ins)
        assert.same(1, n)

        replbuf:move_selection('down', nil, true)

        ln = replbuf:get_selection_start_line()
        assert.same(55, ln)
      end)

      it('replacing line in block', function()
        local replbuf = table.clone(buffer)
        replbuf:move_selection('down', nil, true)
        replbuf:move_selection('up', 1)

        local orig = { 'function love.update(dt)',
          '  t = t + dt',
          '  if ty > midy then',
          '    debugColor = Color.red',
          '  end',
          'end' }
        assert.same(orig, replbuf:get_selected_text())
        local new = table.clone(orig)
        new[2] = '  t = t + dt + 1'

        local ok, chunks = chunker(new, true)
        assert.is_true(ok)
        local _, n = replbuf:replace_selected_text(chunks)
        assert.same(1, n)
      end)
      it('breaking line in block', function()
        local replbuf = table.clone(buffer)
        replbuf:move_selection('down', nil, true)
        replbuf:move_selection('up', 1)

        local orig = { 'function love.update(dt)',
          '  t = t + dt',
          '  if ty > midy then',
          '    debugColor = Color.red',
          '  end',
          'end' }
        assert.same(orig, replbuf:get_selected_text())
        local new = table.clone(orig)
        new[2] = '  t = t +'
        table.insert(new, 3, '       dt')

        local ok, chunks = chunker(new, true)
        assert.is_true(ok)
        local _, n = replbuf:replace_selected_text(chunks)
        assert.same(1, n)

        assert.same(24, replbuf:get_selection())
      end)

      describe('lua', function()
        local addbuf = table.clone(buffer)
        local orig_b = { 'function love.update(dt)',
          '  t = t + dt',
          '  if ty > midy then',
          '    debugColor = Color.red',
          '  end',
          'end' }

        it('introducing a new line', function()
          addbuf:move_selection('down', nil, true)
          addbuf:move_selection('up', 2)

          local orig = { 'local t = 0' }
          assert.same(orig, addbuf:get_selected_text())
          local new = table.clone(orig)
          table.insert(new, 'local t2 = 2')

          local ok, chunks = chunker(new, true)
          assert.is_true(ok)
          local _, n = addbuf:replace_selected_text(chunks)
          assert.same(2, n)

          assert.same(23, addbuf:get_selection())
        end)
        it('adding line in block', function()
          addbuf:move_selection('down', 2)
          assert.same(orig_b, addbuf:get_selected_text())
          local new = table.clone(orig_b)
          table.insert(new, 3, '  t2 = t2 + 2 * dt')

          local ok, chunks = chunker(new, true)
          assert.is_true(ok)

          local _, n = addbuf:replace_selected_text(chunks)
          assert.same(1, n)

          assert.same(25, addbuf:get_selection())
        end)
      end)


      --- end ---
    end)
  end)
end)
