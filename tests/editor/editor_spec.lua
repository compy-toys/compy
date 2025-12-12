--- @diagnostic disable: invisible
require("model.editor.editorModel")
require("controller.editorController")
require("view.editor.editorView")
require("view.editor.visibleContent")

local mock, TU

describe('Editor #editor', function()
  setup(function()
    mock = require("tests.mock")
    TU = require('tests.testutil')

    local love = {
      state = {
        --- @type AppState
        app_state = 'ready',
      },
    }
    mock.mock_love(love)
  end)

  local trtl =
  'Turtle graphics game inspired the LOGO family of languages.'

  local turtle_doc = {
    '',
    trtl,
    '',
  }

  --- @param cfg Config
  --- @return EditorController
  --- @return function press
  --- @return EditorView view
  local function wire(cfg)
    local model = EditorModel(cfg)
    local controller = EditorController(model)
    -- this hooks itself back into the controller
    EditorView(cfg.view, controller)
    local function press(...)
      controller:keypressed(...)
    end

    return controller, press, controller.view
  end

  local print_result = "print(sierpinski(4))"
  local sierpinski = {
    "function sierpinski(depth)",
    "  lines = { '*' }",
    "  for e = 2, depth + 1 do",
    "    sp, tmp = string.rep(' ', 2 ^ (e - 2))",
    "    tmp = {}",
    "    for idx, line in ipairs(lines) do",
    "      tmp[idx] = sp .. line .. sp",
    "      tmp[idx + #lines] = line .. ' ' .. line",
    "    end",
    "    lines = tmp",
    "  end",
    [[  return table.concat(lines, '\n')]],
    "end",
    "",
    print_result,
  }

  describe('opens', function()
    it('no wrap needed', function()
      local w = 80
      local controller = wire(TU.mock_view_cfg(w))

      local save = TU.get_save_function(turtle_doc)
      controller:open('turtle', turtle_doc, save)

      local buffer = controller:get_active_buffer()
      local bc = buffer:get_content()

      assert.same(turtle_doc, bc)
      assert.same(#turtle_doc, buffer:get_content_length())

      local sel = buffer:get_selection()
      local sel_t = buffer:get_selected_text()
      --- default selection is at the end
      assert.same(#turtle_doc, sel)
      --- and it's an empty line, of course
      assert.same('', sel_t)
    end)
  end)

  describe('plaintext works', function()
    describe('with wrap', function()
      local w = 16
      love.state.app_state = 'editor'

      local controller, press = wire(TU.mock_view_cfg(w))

      local save = TU.get_save_function(turtle_doc)

      controller:open('turtle', turtle_doc, save)

      local buffer = controller:get_active_buffer()
      local start_sel = #turtle_doc

      it('opens', function()
        local bc = buffer:get_content()

        assert.same(turtle_doc, bc)
        assert.same(#turtle_doc, buffer:get_content_length())

        local sel = buffer:get_selection()
        local sel_t = buffer:get_selected_text()
        --- default selection is at the end
        assert.same(start_sel, sel)
        --- and it's an empty line, of course
        assert.same('', sel_t)
      end)

      it('interacts', function()
        --- select middle line
        mock.keystroke('up', press)
        assert.same(start_sel - 1, buffer:get_selection())
        assert.same(turtle_doc[2], buffer:get_selected_text())
        --- load it
        local input = function()
          return controller.input:get_text():items()
        end
        mock.keystroke('escape', press)
        assert.same({ turtle_doc[2] }, input())
        mock.keystroke('end', press)
        mock.keystroke('down', press)
        assert.same(start_sel, buffer:get_selection())
        -- load the empty
        mock.keystroke('escape', press)
        assert.same({ '' }, input())
        --- add text
        controller:textinput('-')
        controller:textinput('-')
        controller:textinput(' ')
        controller:textinput('t')
        controller:textinput('e')
        controller:textinput('s')
        controller:textinput('t')
        assert.same({ '-- test' }, input())
        --- replace line with input content
        mock.keystroke('return', press)
        local new = {
          '',
          trtl,
          '-- test',
          ''
        }
        assert.same(new, buffer:get_text_content())
        --- input clears
        assert.same({ '' }, input())
        --- highlight moves down
        assert.same(start_sel + 1, buffer:get_selection())

        mock.keystroke('up', press)
        assert.same(start_sel, buffer:get_selection())
        --- replace
        controller:textinput('i')
        controller:textinput('n')
        controller:textinput('s')
        controller:textinput('e')
        controller:textinput('r')
        controller:textinput('t')
        assert.same({ 'insert' }, input())
        mock.keystroke('escape', press)
        assert.same({ '-- test' }, input())
      end)
    end)


    describe('with scroll', function()
      local l = 6

      local controller, _, view = wire(TU.mock_view_cfg(80, l))
      local model = controller.model

      local save = TU.get_save_function(sierpinski)
      --- use it as plaintext for this test
      controller:open('sierpinski.txt', sierpinski, save)
      local buf = controller:get_active_buffer()
      local bv = view:open(buf)

      local visible = bv.content
      local scroll = bv.SCROLL_BY

      local off = #sierpinski - l + 1
      local start_range = Range(off + 1, #sierpinski + 1)

      it('loads', function()
        --- inital scroll is at EOF, meaning last l lines are visible
        --- plus the phantom line
        assert.same(off, bv:get_offset())
        assert.same(start_range, visible.range)
      end)
      local base = Range(1, l)
      it('scrolls up', function()
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 2), visible.range)
        controller:keypressed('pageup')
        assert.same(start_range:translate(-scroll * 3), visible.range)
        controller:keypressed('pageup')
      end)
      it('tops out', function()
        assert.same(base, visible.range)
      end)
      it('scrolls down', function()
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 2), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 3), visible.range)
        controller:keypressed('pagedown')
        assert.same(base:translate(scroll * 4), visible.range)
        controller:keypressed('pagedown')
      end)
      it('bottoms out', function()
        local limit = #sierpinski + visible.overscroll
        -- assert.same(Range(limit - l + 2, limit), visible.range)
      end)
    end)

    describe('with scroll and wrap', function()
      local l = 6

      local controller, _, view = wire(TU.mock_view_cfg(27, l))

      local save = TU.get_save_function(sierpinski)
      controller:open('sierpinski.txt', sierpinski, save)

      local function press(...)
        controller:keypressed(...)
      end

      local buffer = controller:get_active_buffer()
      --- @type BufferView
      local bv = view:open(buffer)
      -- bv:open(buffer)

      local visible = bv.content
      local scroll = bv.SCROLL_BY

      local clen = visible:get_content_length()
      local off = clen - l
      local start_range = Range(off + 1, clen)
      it('loads', function()
        --- inital scroll is at EOF, meaning last l lines are visible
        --- plus the phantom line
        assert.same(off, bv:get_offset())
        assert.same(start_range, visible.range)
      end)
      local base = Range(1, l)
      describe('scrolls', function()
        it('scrolls up', function()
          mock.keystroke('pageup', press)
          assert.same(start_range:translate(-scroll), visible.range)
          mock.keystroke('pageup', press)
          assert.same(start_range:translate(-scroll * 2), visible.range)
          mock.keystroke('pageup', press)
          assert.same(start_range:translate(-scroll * 3), visible.range)
          mock.keystroke('pageup', press)
          assert.same(start_range:translate(-scroll * 4), visible.range)
        end)
        it('tops out', function()
          mock.keystroke('pageup', press)
          assert.same(base, visible.range)
        end)
        it('scrolls down', function()
          mock.keystroke('pagedown', press)
          assert.same(base:translate(scroll), visible.range)
          mock.keystroke('pagedown', press)
          assert.same(base:translate(scroll * 2), visible.range)
          mock.keystroke('pagedown', press)
          assert.same(base:translate(scroll * 3), visible.range)
          mock.keystroke('pagedown', press)
          assert.same(base:translate(scroll * 4), visible.range)
          mock.keystroke('pagedown', press)
          assert.same(base:translate(scroll * 5), visible.range)
        end)
        it('bottoms out', function()
          mock.keystroke('pagedown', press)
          mock.keystroke('pagedown', press)
          mock.keystroke('pagedown', press)
          local limit = clen + visible.overscroll
          assert.same(Range(limit - l + 1, limit), visible.range)
        end)

        describe('moving the selection affects scrolling', function()
          local sel = buffer:get_selection()
          local sel_t = buffer:get_selected_text()

          --- default selection is at the end
          assert.same(#sierpinski + 1, sel)
          --- and it's an empty line, of course
          assert.same('', sel_t)

          it('from below', function()
            mock.keystroke('pageup', press)
            mock.keystroke('up', press)
            --- it's now one above the starting range, the
            --- phantom line not visible
            -- assert.same(start_range:translate(-1), visible.range)
            mock.keystroke('pageup', press)
            mock.keystroke('down', press)
            --- after scrolling up and moving the sel back, we
            --- are back to the start
            --- TODO
            assert.same(Range(19, 24), visible.range)
            -- assert.same(start_range, visible.range)
          end)
          it('to above', function()
            local srs = visible.range.start
            --- let's move up a screen's worth with the sel
            for _ = 1, l do
              mock.keystroke('up', press)
            end
            local cs = bv:_get_wrapped_selection()[1][1]
            local d = cs - srs
            --- TODO
            -- assert.same(start_range:translate(d), visible.range)
            assert.same(start_range:translate(d + 3),
              visible.range)
            mock.keystroke('up', press)
            -- assert.same(start_range:translate(d - 1), visible.range)
            assert.same(start_range:translate(d + 2), visible.range)
          end)
          it('tops out', function()
            --- move up to the first line
            for _ = 1, clen do
              mock.keystroke('up', press)
            end
            assert.same(base, visible.range)
          end)
          it('from above', function()
            mock.keystroke('pagedown', press)
            mock.keystroke('pagedown', press)
            mock.keystroke('down', press)
            assert.same(base:translate(1), visible.range)
          end)
          it('to below', function()
            for _ = 2, l do
              mock.keystroke('down', press)
            end
            mock.keystroke('pageup', press)
            mock.keystroke('down', press)
            local ws = bv:_get_wrapped_selection()[1]
            local cs = ws[#ws]
            --- TODO
            -- assert.same(Range(cs - l + 1, cs), visible.range)
            assert.same(Range(11, 16), visible.range)
          end)
          it('bottoms out', function()
            local s = buffer:get_selection()
            for _ = s, #sierpinski do
              mock.keystroke('down', press)
            end
            assert.same(start_range, visible.range)
            mock.keystroke('down', press)
            mock.keystroke('down', press)
            assert.same(start_range, visible.range)
          end)
        end)
      end)

      describe('jumps', function()
        local sel = table.clone(buffer:get_selection())
        it('to top', function()
          mock.keystroke('C-pageup', press)
          --- scrolls to top
          assert.same(base, visible.range)
          --- and selection is unaffected
          assert.same(sel, buffer:get_selection())
        end)
        it('to bottom', function()
          -- mock.keystroke('C-pagedown', press)
          --- scrolls to bottom
          --- TODO
          -- assert.same(start_range, visible.range)
          --- and selection is unaffected
          assert.same(sel, buffer:get_selection())
        end)
      end)
      describe('warps selection', function()
        mock.keystroke('up', press)
        local sel = table.clone(buffer:get_selection())
        it('to bottom', function()
          mock.keystroke('C-end', press)
          --- warps to bottom
          --- TODO
          -- assert.same(start_range, visible.range)
          assert.same(Range(19, 24), visible.range)
          assert.is_not.same(sel, buffer:get_selection())
        end)
        it('to top', function()
          mock.keystroke('C-home', press)
          --- warps to top
          assert.same(base, visible.range)
          assert.is_not.same(sel, buffer:get_selection())
        end)
      end)
      describe('input', function()
        local inter = controller.input
        it('loads', function()
          inter:add_text('asd')
          local selected = buffer:get_selected_text()
          mock.keystroke('escape', press)
          assert.same(inter:get_text(), { selected })
        end)
        it("doesn't clear on move", function()
          mock.keystroke('C-end', press)
          -- load the empty
          mock.keystroke('escape', press)
          assert.same({ '' }, inter:get_text())
        end)
        it('inserts', function()
          -- mock.keystroke('up', press)
          local prefix = 'asd '
          local selected = buffer:get_selected_text()
          inter:add_text(prefix)
          mock.keystroke('S-escape', press)
          local res = string.join(inter:get_text())
          assert.same(prefix .. selected, res)
        end)
      end)
    end)
  end)
  --- end plaintext

  describe('structured (lua) works', function()
    it('changing single line', function()
      local controller, press = wire(TU.mock_view_cfg())
      local save, savefile = TU.get_save_function(sierpinski)

      controller:open('sierpinski.lua', sierpinski, save)

      local input = controller.input
      local buffer = controller:get_active_buffer()
      local cont = buffer:get_content()


      assert.same('lua', buffer.content_type)
      assert.same('block', cont:type())
      assert.same(4, buffer:get_content_length())
      local modified = table.clone(sierpinski)
      local new_print = 'print(sierpinski(3))'
      mock.keystroke('up', press)
      assert.same(3, buffer:get_selection())
      assert.same({ print_result }, buffer:get_selected_text())
      input:clear()
      input:add_text(new_print)
      mock.keystroke('return', press)
      assert.same(4, buffer:get_selection())
      local after = savefile()
      modified[#modified] = new_print
      modified[#modified + 1] = ''
      assert.same(string.unlines(modified), after)
    end)
  end)
end)
