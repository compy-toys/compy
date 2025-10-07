local parser = require("model.lang.lua.parser")('metalua')
local analyzer = require("model.lang.lua.analyze")
local term = require("util.termcolor")
local FS = require("util.filesystem")
require("util.color")
require("util.debug")

local inputs = require("tests.interpreter.analyzer_inputs")

if not orig_print then
  _G.orig_print = print
end

-- when testing with Lua5.3
if not _G.unpack then
  _G.unpack = table.unpack
end

local w = 64

local analyzer_debug = os.getenv("ANA_DEBUG")
local show_ast = os.getenv("SHOW_AST") or analyzer_debug

describe('analyzer #analyzer', function()
  local function do_code(ast, seen_comments)
    local code, comments = parser.ast_to_src(ast, seen_comments, w)
    local seen = seen_comments or {}
    for k, v in pairs(comments) do
      --- if a table was passed in, this modifies it
      seen[k] = v
    end
    local hl = parser.highlighter(code)
    if analyzer_debug then
      local code_t = string.lines(code)
      for l, line in ipairs(code_t) do
        io.write("'")
        for j = 1, #code do
          local c = hl[l][j]
          term.print_c(c, string.usub(line, j, j), true)
        end
        io.write(term.reset)
        io.write("'")
        print()
      end
      io.write(term.reset)
    end
    return code, seen_comments
  end

  describe('produces ASTs', function()
    for _, test_t in pairs(inputs) do
      local tag = test_t[1]
      if tag then
        local tests = test_t[2]
        describe('for ' .. tag, function()
          for i, tc in ipairs(tests) do
            local input = tc[1]
            local output = tc[2]

            local ok, r = parser.parse(input)
            local result = {}
            if ok then
              if analyzer_debug or show_ast then
                print(
                  string.format("%s %s %s",
                    string.rep('=', 20),
                    tag .. ' ' .. i,
                    string.rep('=', 20)
                  ))
              end
              local seen_comments = {}
              for _, v in ipairs(r) do
                if show_ast then
                  local fn =
                      string.format('%s_input_%d', tag, i)

                  local skip_lineinfo = true
                  local tree = Debug.terse_ast(r, skip_lineinfo)
                  local f = string.format('/*\n%s\n*/\n%s',
                    string.unlines(input),
                    tree
                  )
                  local wres, werr =
                      FS.write_tempfile(f, 'json5', fn)
                  if not wres then
                    Log.warn("no write", werr)
                  end
                end

                local ct, _ = do_code(v, seen_comments)
                for _, cl in ipairs(string.lines(ct) or {}) do
                  table.insert(result, cl)
                end
              end

              ---@diagnostic disable-next-line: param-type-mismatch
              local semDB = analyzer.analyze(r)
              it('matches ' .. i, function()
                assert.same(output, semDB)
              end)
            else
              Log.warn('syntax error in input #' .. i)
              local err = string.gsub(r.msg, '\\n', '\n')
              Log.error(err)
            end
          end
        end)
      end
    end
  end)

  ---
end)
