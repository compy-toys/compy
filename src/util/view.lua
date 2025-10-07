require("util.string.string")

--- @param cfg ViewConfig
--- @return number
local get_drawable_height = function(cfg)
  local ch = cfg.fh * cfg.lh
  local d = cfg.h
      - cfg.fh -- statusline
      - cfg.fh -- input line
  local n_lines = math.floor(d / ch)
  local res = n_lines * ch
  return res
end

--- Write a line of text to output
--- pass 0 for breaks if the text is already wrapped!
--- @param l number
--- @param str string
--- @param y number
--- @param breaks integer
--- @param cfg ViewConfig
local write_line = function(l, str, y, breaks, cfg)
  local dy = y - (-l + 1 + breaks) * cfg.fh
  gfx.setFont(cfg.font)
  gfx.print(str, 0, dy)
end

--- Write a token to output
--- @param dy number
--- @param dx number
--- @param token string
--- @param color table
--- @param bgcolor table
--- @param selected boolean
local write_token = function(dy, dx, token,
                             color, bgcolor, selected)
  gfx.push('all')
  if selected then
    gfx.setColor(color)
    local back = string.rep('█', string.ulen(token))
    gfx.print(back, dx, dy)
    gfx.setColor(bgcolor)
  else
    gfx.setColor(color)
  end
  gfx.print(token, dx, dy)
  gfx.pop()
end

--- Hide elements for debugging
--- Return true if DEBUG is not enabled or is
--- enabled and the appropriate flag is set
--- @param k string
--- @return boolean
local conditional_draw = function(k)
  if love.DEBUG then
    return love.debug[k] == true
  end
  return true
end

--[[
AlphaMode = AlphaM | PreM
BlendMode = Alpha AlphaMode
            Add AlphaMode
            Subtract AlphaMode
            Replace AlphaMode
            Multiply PreM
            Darken PreM
            Lighten PreM
            Screen AlphaMode
]]
local blendModes = {
  { -- 1
    name = 'Alpha AlphaM',
    blend = function() gfx.setBlendMode('alpha', "alphamultiply") end
  },
  { -- 2
    name = 'Alpha PreM',
    blend = function() gfx.setBlendMode('alpha', "premultiplied") end
  },
  -- add
  {
    name = 'Add AlphaM',
    blend = function() gfx.setBlendMode('add', "alphamultiply") end
  },
  {
    name = 'Add PreM',
    blend = function() gfx.setBlendMode('add', "premultiplied") end
  },
  -- subtract
  {
    name = 'Subtract AlphaM',
    blend = function() gfx.setBlendMode('subtract', "alphamultiply") end
  },
  {
    name = 'Subtract PreM',
    blend = function() gfx.setBlendMode('subtract', "premultiplied") end
  },
  -- replace
  {
    name = 'Replace AlphaM',
    blend = function() gfx.setBlendMode('replace', "alphamultiply") end
  },
  {
    name = 'Replace PreM',
    blend = function() gfx.setBlendMode('replace', "premultiplied") end
  },

  -- pre only
  {
    name = 'Multiply PreM',
    blend = function() gfx.setBlendMode('multiply', "premultiplied") end
  },
  {
    name = 'Darken PreM',
    blend = function() gfx.setBlendMode('darken', "premultiplied") end
  },
  {
    name = 'Lighten PreM',
    blend = function() gfx.setBlendMode('lighten', "premultiplied") end
  },
  -- screen
  {
    name = 'Screen AlphaM',
    blend = function() gfx.setBlendMode('screen', "alphamultiply") end
  },
  {
    name = 'Screen PreM',
    blend = function() gfx.setBlendMode('screen', "premultiplied") end
  },
}

--- This is a subset of viewconfig needed for displaying text
--- @class TextDisplayConfig
--- @field colors TextDisplayColors
--- @field fw integer
--- @field fh integer

--- @class TextDisplayColors
--- @field text BaseColors
--- @field error BaseColors?

--- @class TextHighlightOpts
--- @field ltf function line transformer
--- @field ctf function coordinate transformer
--- @field limit integer ltf(line number) not shown starting here

--- @param text string[]
--- @param highlight Highlight
--- @param cfg TextDisplayConfig
--- @param options TextHighlightOpts
local function draw_hl_text(text, highlight, cfg, options)
  local hl = highlight.hl

  local colors = cfg.colors
  local fg = colors.text.fg
  local bg = colors.text.bg
  local fh = cfg.fh
  local fw = cfg.fw
  local color = fg

  local ltf = options.ltf
  local tf = options.ctf
  local limit = options.limit

  for l, line in ipairs(text) do
    local len = string.ulen(line)

    local t_l = ltf(l)
    if t_l > limit
        or not len then
      return
    end

    for c = 1, len do
      local char = string.usub(line, c, c)
      if hl then
        local tlc = tf(Cursor(l, c))
        if tlc then
          local ci = (function()
            if hl[tlc.l] then
              return hl[tlc.l][tlc.c]
            end
          end)()
          if ci then
            color = Color[ci] or fg
          end
        end
      end
      gfx.setColor(color)
      local dy = (t_l - 1) * fh
      local dx = (c - 1) * fw
      write_token(dy, dx, char, color, bg, false)
    end
  end
end

ViewUtils = {
  get_drawable_height = get_drawable_height,
  write_line = write_line,
  write_token = write_token,
  draw_hl_text = draw_hl_text,
  conditional_draw = conditional_draw,

  blendModes = blendModes,
}
