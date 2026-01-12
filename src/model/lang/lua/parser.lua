require("model.lang.lua.error")
require("model.lang.highlight")
local ct = require("conf.lua")
require("util.debug")
require("util.string.string")
require("util.dequeue")

--- @class luaAST : token

--- @alias CPos 'first'|'last'

--- @class Comment
--- @field text string
--- @field position CPos
--- @field idf integer
--- @field idl integer
--- @field first Cursor
--- @field last Cursor
--- @field multiline boolean
--- @field prepend_newline boolean

return function(lib)
  local l = lib or 'metalua'
  local add_paths = {
    '',
    'lib/' .. l .. '/?.lua',
    'lib/?.lua',
    -- 'lib/lua/5.1/?'
  }
  if love and not TESTING then
    local love_paths = string.join(add_paths, ';')
    love.filesystem.setRequirePath(
      love.filesystem.getRequirePath() .. love_paths)
  else
    local lib_paths = string.join(add_paths, ';src/')
    package.path = lib_paths .. ';' .. package.path
  end

  local mlc = require('metalua.metalua.compiler').new()

  --- Iterates over lexstream
  --- @param stream table
  --- @return table tokens
  local realize_stream = function(stream)
    local tokens = Dequeue.typed('string')
    local n
    repeat
      n = stream:next()
      tokens:append(n)
    until n.tag == 'Eof'
    return tokens
  end

  --- Parses text table to lexstream
  --- @param code str
  --- @return table lexstream
  local stream_tokens = function(code)
    local c = string.unlines(code)
    local lexstream = mlc:src_to_lexstream(c)
    return lexstream
  end

  --- Parses text table to tokens
  --- @param code str
  --- @return table
  local tokenize = function(code)
    local stream = stream_tokens(code)
    return realize_stream(stream)
  end

  --- Parses lexstream to AST
  --- @param stream table
  --- @return ParseResult
  local parse_stream = function(stream)
    return mlc:lexstream_to_ast(stream)
  end

  --- @param ast luaAST
  --- @param ... any
  --- @return Comment[]
  local ast_extract_comments = function(ast, ...)
    local a2s = mlc:a2s(...)
    return a2s:extract_comments(ast)
  end

  --- Finds error location and message in parse result
  --- @param result string
  --- @return Error
  local get_error = function(result)
    local err_lines = string.lines(result)
    local err_first_line = err_lines[1]
    local err_second_line = err_lines[2]
    local colons = string.split(err_first_line, ':')
    local colons2 = string.split(err_second_line, ':')
    local match2 = string.gmatch(colons2[2] or '', '%d+')
    local line = tonumber(match2() or '') or -1
    local char = tonumber(match2() or '') or -1
    local errmsg = string.trim(colons[4])
    return Error(errmsg, char, line)
  end

  --- Read lexstream and determine highlighting
  --- @param tokens luaAST
  --- @return SyntaxColoring
  local syntax_hl = function(tokens)
    if not tokens then return {} end

    --- @type SyntaxColoring
    local colored_tokens = SyntaxColoring()

    --- @param tag string
    --- @param single boolean
    --- @return TokenType?
    local function getType(tag, single)
      if tag == 'Keyword' then
        if single then
          return 'kw_single'
        else
          return 'kw_multi'
        end
      elseif tag == 'Number' then
        return 'number'
      elseif tag == 'String' then
        return 'string'
      elseif tag == 'Id' then
        return 'identifier'
      else
        return nil
      end
    end

    --- @param first Cursor
    --- @param last Cursor
    --- @param text string
    --- @param lex_t LexType
    --- @param tl integer
    local function multiline(first, last, text, lex_t, tl)
      local ls = first.l
      local le = last.l
      local cs = first.c
      local ce = last.c
      local lines = string.lines(text)

      local n_lines = #lines
      local till = le + 1 - ls
      -- if the first line has no text after the block starter,
      -- we need to add an empty line on the front
      if n_lines + 1 == till then
        table.insert(lines, 1, '')
      end

      -- first line
      for i = cs, cs + string.ulen(lines[1]) + tl do
        colored_tokens[ls][i] = ct[lex_t]
      end
      for i = 2, till - 1 do
        local e = string.ulen(lines[i])
        for j = 1, e + 2 do
          colored_tokens[ls + i - 1][j] = ct[lex_t]
        end
      end
      -- last line
      for i = 1, ce do
        colored_tokens[le][i] = ct[lex_t]
      end
    end

    --- @param t token
    --- @return SyntaxColoring?
    local function colorize(t)
      local text     = t[1]
      local tag      = t.tag
      local lfi      = t.lineinfo.first
      local lla      = t.lineinfo.last
      local first    = { l = lfi.line, c = lfi.column }
      local last     = { l = lla.line, c = lla.column }
      -- local first_f = lfi.facing
      -- local last_f  = lla.facing
      local comments = {}
      local function add_comment(c)
        local id = c.lineinfo.first.id
        if not comments[id] then
          local comment_text = c[1]
          if string.sub(comment_text, 1, 2) == '[[' then
            -- TODO unclosed comment block
            -- orig_print(Debug.terse_t(c))
          end

          local cfi    = c.lineinfo.first
          local cla    = c.lineinfo.last
          local cfirst = { l = cfi.line, c = cfi.column }
          local clast  = { l = cla.line, c = cla.column }
          local li     = {
            first = cfirst,
            last = clast,
            text = comment_text,
          }
          comments[id] = li
        end
      end
      if lfi.comments then
        for _, c in ipairs(lfi.comments) do
          add_comment(c)
        end
      end
      if lla.comments then
        for _, c in ipairs(lla.comments) do
          add_comment(c)
        end
      end

      -- normal tokens
      if first.l == last.l then
        local l = first.l
        local single = false
        if string.ulen(text) == 1 then
          single = true
        end
        for i = first.c, last.c do
          local typ            = getType(tag, single)
          colored_tokens[l][i] = ct[typ]
        end
      else
        local tl = 2 --- a string block starts with '[['
        multiline(first, last, text, 'string', tl)
      end

      -- comments
      for _, co in pairs(comments) do
        local ls = co.first.l
        local le = co.last.l
        local cs = co.first.c
        local ce = co.last.c
        if ls == le then
          for i = cs, ce do
            colored_tokens[ls][i] = ct['comment']
          end
        else
          local tl = 4 --- a block comment starts with '--[['
          multiline(co.first, co.last, co.text, 'comment', tl)
        end
      end
    end -- colorize

    if tokens.next then
      repeat
        local t = tokens:next()
        colorize(t)
      until t.tag == 'Eof'
    else
      for _, t in pairs(tokens) do
        colorize(t)
      end
    end
    return colored_tokens
  end

  --------------------
  ---    Public    ---
  --------------------

  --- @param ast luaAST
  --- @param ... any
  --- @return string
  local ast_to_src = function(ast, ...)
    local a2s = mlc:a2s(...)
    return a2s:run(ast)
  end

  --- Parses code to AST
  --- @param code str
  --- @return boolean success
  --- @return ParseResult<luaAST>
  local parse = function(code)
    local stream = stream_tokens(code)
    local ok, res = pcall(parse_stream, stream)
    local ret = res
    if not ok then
      ---@diagnostic disable-next-line: param-type-mismatch
      ret = get_error(res)
    end
    return ok, ret
  end

  --- @param code string[]
  --- @return string[]?
  local pprint = function(code, wrap)
    local w = wrap or 80
    local ok, r = parse(code)
    if ok then
      --- @diagnostic disable-next-line: param-type-mismatch
      local src = ast_to_src(r, {}, w)
      return string.lines(src)
    end
  end

  --- Highlight string array
  --- @param code str
  --- @return SyntaxColoring
  local highlighter = function(code)
    return syntax_hl(tokenize(code))
  end

  --- @param text string[]
  --- @param w integer
  --- @param single boolean
  --- @return boolean ok
  --- @return Block[]
  --- @return ParseResult<luaAST>
  local chunker = function(text, w, single)
    require("model.editor.content")
    if string.is_non_empty_string_array(text) then
      local wrap = w
      local ret = Dequeue.typed('block')
      local ok, r = parse(text)
      local has_lines = false
      if ok then
        local idx = 1  -- block number
        local last = 0 -- last line number
        local comment_ids = {}
        --- Create chunk from comment text and pos
        --- @param ctext str
        --- @param c Comment
        --- @param range Range
        local add_comment_block = function(ctext, c, range)
          ret:insert(
            Chunk.new(ctext, range),
            idx)
          comment_ids[c.idf] = true
          comment_ids[c.idl] = true
        end
        --- @param comments Comment[]
        --- @param pos CPos
        local get_comments = function(comments, pos)
          for _, c in ipairs(comments) do
            -- Log.warn('c', c.position)
            -- Log.warn(Debug.terse_t(c, nil, nil, true))
            if c.position == pos
                and not (comment_ids[c.idl] or comment_ids[c.idf])
            then
              local cfl, cll = c.first.l, c.last.l
              -- account for empty lines
              if cfl > last + 1 then
                ret:insert(Empty(last + 1), idx)
                idx = idx + 1
                comment_ids[c.idf] = true
                comment_ids[c.idl] = true
              end
              if cfl == cll then
                local ctext = '--' .. c.text
                add_comment_block(ctext, c, Range.singleton(cfl))
                idx = idx + 1
                last = cll
              else
                local lines = string.lines(c.text)
                if c.multiline then
                  if c.prepend_newline then
                    table.insert(lines, 1, '')
                  end
                  local l1 = lines[1] or ''
                  if #lines == 1 then
                    lines[1] = '--[[' .. l1 .. ']]'
                  else
                    local llast = lines[#lines] or ''
                    lines[1] = '--[[' .. l1
                    lines[#lines] = llast .. ']]'
                  end
                  local wrapped = string.wrap_array(lines, wrap)
                  local w_t = string.unlines(wrapped)

                  add_comment_block(wrapped, c, Range(cfl, cll))
                  idx = idx + 1
                  last = cll
                else
                  for i, l in ipairs(lines) do
                    local ln = cfl + i - 1
                    local ctext = '--' .. l
                    add_comment_block(ctext, c, Range.singleton(ln))
                    idx = idx + 1
                    last = cll
                  end
                end
              end
            end
          end
        end

        --- multiline empty collapse offset
        local of = 0
        for _, v in ipairs(r) do
          has_lines = true
          local li = v.lineinfo
          local fl, ll = li.first.line, li.last.line

          local comments = ast_extract_comments(v, {}, wrap)

          get_comments(comments, 'first')
          --- account for empty lines, including the zeroth
          if fl > last + 1 then
            ret:insert(Empty(last + 1 - of), idx)
            idx = idx + 1
            last = last + 1
            of = of + (fl - last - 1)
          end
          local tex = table.slice(text or {}, fl, ll)
          local chunk = Chunk(tex, Range(fl - of, ll - of))
          ret:insert(chunk, idx)
          idx = idx + 1
          last = ll

          get_comments(comments, 'last')
        end

        if single or not has_lines then
          --- @diagnostic disable-next-line: param-type-mismatch
          local single_comment = ast_extract_comments(r, {}, wrap)
          get_comments(single_comment, 'first')
        end

        if
            ret:last().tag ~= 'empty' and (
            --- no empty line at EOF
              not single
              --- there is an empty line at the end
              or single and (#string.lines(text) > last)
            )
        then
          ret:push_back(Empty(last + 1 - of))
        end
        return true, ret, r
      else
        --- content is not valid lua
        return false, Dequeue(text, 'string'), r
      end
    else
      return true, Dequeue({ Empty(1) }, 'block'), r
    end
  end

  --- @param code str
  --- @param n integer?
  --- @return string[]?
  local function trunc(code, n)
    local lines = n or 1
    if lines == 1 then
      local txt = string.lines(code)
      local line1 = txt[1]:sub(1, -1) .. '…'
      return { line1 }
    end
  end

  return {
    parse       = parse,
    pprint      = pprint,
    highlighter = highlighter,
    ast_to_src  = ast_to_src,
    chunker     = chunker,
    trunc       = trunc,
  }
end
