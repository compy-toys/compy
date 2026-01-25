local parser = require("model.lang.lua.parser")('metalua')
local term = require("util.termcolor")
local FS = require("util.filesystem")
require("util.color")
require("util.debug")

local inputs = (function()
  local ok, i = pcall(require, "lib.metalua.spec.ast_inputs")
  if ok then
    return i
  else
    Log.warn('AST inputs missing, are submodules checked out?')
    return {}
  end
end)()

if not orig_print then
  _G.orig_print = print
end

local show_ast = os.getenv("SHOW_AST")
local parser_debug = os.getenv("PARSER_DEBUG") or show_ast

local w = 64

describe('parser #ast', function()
  local function do_code(ast, seen_comments)
    local code, comments = parser.ast_to_src(ast, seen_comments, w)
    local seen = seen_comments or {}
    for k, v in pairs(comments) do
      --- if a table was passed in, this modifies it
      seen[k] = v
    end
    local hl = parser.highlighter(code)
    if parser_debug then
      local code_t = string.lines(code)
      for l, line in ipairs(code_t) do
        io.write("'")
        for j = 1, #code do
          local c = (hl[l][j])
          term.print_c(c, string.usub(line, j, j), true)
        end
        io.write(term.reset)
        io.write("'")
        print()
      end
      io.write(term.reset)
    end
    if show_ast then
      Log.debug(Debug.terse_ast(ast, true))
    end
    return code, seen_comments
  end

  describe('produces ASTs', function()
    for _, test_t in pairs(inputs) do
      local tag = test_t[1]
      local tests = test_t[2]
      describe('for ' .. tag, function()
        for i, tc in ipairs(tests) do
          local input = tc[1]
          local output = tc[2]

          local ok, r = parser.parse(input)
          local result = {}
          if ok then
            if parser_debug then
              io.write(string.rep('=', 80))
              print(Debug.text_table(input))
            end

            it('matches ' .. i, function()
              local has_lines = false
              local seen_comments = {}
              for _, v in ipairs(r) do
                if show_ast then
                  local fn = string.format('%s_input_%d', tag, i)

                  local skip_lineinfo = false
                  local tree = Debug.terse_ast(r, skip_lineinfo)
                  local f = string.format('/*\n%s\n*/\n%s',
                    string.unlines(input),
                    tree
                  )
                  FS.write_tempfile(f, 'json5', fn)
                end

                has_lines = true
                local ct, _ = do_code(v, seen_comments)
                for _, cl in ipairs(string.lines(ct) or {}) do
                  table.insert(result, cl)
                end
              end
              --- corner case, e.g comments only
              --- it is valid code, but gets parsed a bit differently
              if not has_lines then
                result = string.lines(do_code(r)) or {}
              end

              --- remove trailing newline
              if result[#result] == '' then
                table.remove(result)
              end
              assert.same(output, result)
              assert.is_true(parser.parse(output))
            end)
          else
            Log.warn('syntax error in input #' .. i)
            --- @diagnostic disable-next-line: undefined-field
            local err = string.gsub(r.msg, '\\n', '\n')
            Log.error(err)
          end
        end
      end)
    end
  end)

  ---
end)
