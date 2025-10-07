width, height = gfx.getDimensions()
--- color palette
block_w = width / 10
block_h = block_w / 2
pal_h = 2 * block_h
pal_w = 8 * block_w
sel_w = 2 * block_w

--- tool pane
margin = block_h / 10
m_2 = margin * 2
m_4 = margin * 4
box_w = 1.5 * block_w
box_h = height - pal_h
marg_l = box_w - m_2
tool_h = box_h / 2
tool_midx = box_w / 2

n_t = 2
icon_h = (tool_h - m_4 - m_2) / n_t
-- one col for now
icon_w = (box_w - m_4 - m_4) / 1
icon_d = math.min(icon_w, icon_h)
-- line weight
weight_h = box_h / 2
wb_y = box_h - weight_h
weights = { 1, 2, 4, 5, 6, 9, 11, 13 }

--- canvas
can_w = width - box_w
can_h = height - pal_h - 1
canvas = gfx.newCanvas(can_w, can_h)

--- selected
color = 0    -- black
bg_color = 0 -- black
weight = 3
tool = 1     -- brush

function inCanvasRange(x, y)
  return (y < height - pal_h and box_w < x)
end

function inPaletteRange(x, y)
  return (height - pal_h <= y
    and width - pal_w <= x and x <= width)
end

function inToolRange(x, y)
  return (x <= box_w and y <= tool_h)
end

function inWeightRange(x, y)
  return (x <= box_w and y < height - pal_h and wb_y < y)
end

function drawBackground()
  gfx.setColor(Color[Color.black])
  gfx.rectangle("fill", 0, 0, width, height)
end

function drawPaletteOutline(y)
  gfx.setColor(Color[bg_color])
  gfx.rectangle("fill", 0, y - block_h, block_w * 2, block_h * 2)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("line", 0, y - block_h, sel_w, pal_h)
  gfx.rectangle("line", sel_w, y - block_h, width, pal_h)
end

function drawSelectedColor(y)
  gfx.setColor(Color[color])
  gfx.rectangle("fill", block_w / 2, y - (block_h / 2),
    block_w, block_h)
  -- outline
  local line_color = Color.white + Color.bright
  if color == line_color then
    line_color = Color.black
  end
  gfx.setColor(Color[line_color])
  gfx.rectangle("line", block_w / 2, y - (block_h / 2),
    block_w, block_h)
end

function drawColorBoxes(y)
  for c = 0, 7 do
    local x = block_w * (c + 2)
    gfx.setColor(Color[c])
    gfx.rectangle("fill", x, y, width, block_h)
    gfx.setColor(Color[c + 8])
    gfx.rectangle("fill", x, y - block_h, width, block_h)
    gfx.setColor(Color[Color.white])
    gfx.rectangle("line", x, y, width, block_h)
    gfx.rectangle("line", x, y - block_h, width, block_h)
  end
end

function drawColorPalette()
  local y = height - block_h
  drawPaletteOutline(y)
  drawSelectedColor(y)
  drawColorBoxes(y)
end

function drawBrush(cx, cy)
  gfx.push()
  gfx.translate(cx, cy)
  local s = icon_d / 100 * .8
  gfx.scale(s, s)
  gfx.rotate(math.pi / 4) -- 45 degree rotation

  -- Draw the brush handle (wooden brown color)
  gfx.setColor(0.6, 0.4, 0.2)
  gfx.rectangle("fill", -8, -80, 16, 60)

  -- Handle highlight
  gfx.setColor(0.8, 0.6, 0.4)
  gfx.rectangle("fill", -6, -75, 3, 50)

  -- Metal ferrule
  gfx.setColor(0.7, 0.7, 0.8)
  gfx.rectangle("fill", -10, -25, 20, 12)

  -- Ferrule shine
  gfx.setColor(0.9, 0.9, 1.0)
  gfx.rectangle("fill", -8, -24, 3, 10)

  -- Bristles with smooth flame-shaped tip
  gfx.setColor(0.2, 0.2, 0.2)
  gfx.rectangle("fill", -12, -13, 24, 25)

  -- Create flame tip using bezier curve
  local curve = love.math.newBezierCurve(
    -12, 12, -- Start left
    -15, 20, -- Control point 1 (outward curve)
    -5, 30,  -- Control point 2 (inward curve)
    0, 35,   -- Tip point
    5, 30,   -- Control point 3 (inward curve)
    15, 20,  -- Control point 4 (outward curve)
    12, 12   -- End right
  )

  local points = curve:render()
  gfx.polygon("fill", points)

  gfx.pop()
end

function drawEraser(cx, cy)
  gfx.push()
  gfx.translate(cx, cy)
  local s = icon_d / 100
  gfx.scale(s, s)
  gfx.rotate(math.pi / 4) -- 45 degree rotation

  -- Main eraser body (light blue)
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", -12, -40, 24, 60)

  -- Blue stripes running lengthwise (darker blue)
  gfx.setColor(Color[Color.blue])
  gfx.rectangle("fill", -12, -40, 6, 60)
  gfx.rectangle("fill", 6, -40, 6, 60)

  -- Worn eraser tip (slightly darker)
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("fill", -12, 15, 24, 8)

  -- Eraser crumbs
  gfx.setColor(Color[Color.white])
  gfx.circle("fill", 18, 25, 2)
  gfx.circle("fill", 22, 30, 1.5)
  gfx.circle("fill", 15, 32, 1)

  gfx.pop()
end

-- this is a color
goose = { 0.303, 0.431, 0.431 }
local tools = {
  drawBrush,
  drawEraser,
}
function drawTools()
  local tb = icon_d
  local tb_half = tb / 2
  for i = 1, n_t do
    local x = tool_midx - tb_half
    local y = (i - 1) * (m_2 + tb)
    if i == tool then
      gfx.setColor(Color[Color.black])
    else
      gfx.setColor(Color[Color.white + Color.bright])
    end
    gfx.rectangle("fill", x, y + m_2, tb, tb)

    gfx.setColor(Color[Color.black])
    gfx.rectangle("line", x, y + m_2, tb, tb)

    local draw = tools[i]
    draw(tool_midx - m_2, y + tb_half + m_4)
  end
end

function drawWeightSelector()
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("line", 0, box_h - weight_h, box_w - 1, weight_h)
  local h = (weight_h - (2 * margin)) / 8
  local w = marg_l
  for i = 0, 7 do
    local y = wb_y + margin + (i * h)
    local lw = i + 1
    local mid = y + (h / 2)
    gfx.setColor(Color[Color.white + Color.bright])
    gfx.rectangle("fill", margin, y, w, h)
    if lw == weight then
      -- gfx.setColor(Color[Color.white])
      -- gfx.rectangle("fill", margin, y, w, h)
      gfx.setColor(goose)
      local rx1 = 3 * margin
      local rx2 = 5 * margin
      local ry1 = mid - margin
      local ry2 = ry1 + m_2
      local x1 = 5 * margin
      local x2 = 7 * margin
      local y1 = mid - m_2
      local y2 = mid + m_2
      gfx.polygon("fill",
        -- body
        rx2, ry1,
        rx1, ry1,
        rx1, ry2,
        rx2, ry2,
        -- head
        x1, y2,
        x2, mid,
        x1, y1
      )
      gfx.setColor(Color[Color.black])
      gfx.setLineWidth(2)
      gfx.polygon("line",
        -- body
        rx2, ry1,
        rx1, ry1,
        rx1, ry2,
        rx2, ry2,
        -- head
        x1, y2,
        x2, mid,
        x1, y1
      )
      gfx.setLineWidth(1)
    else
    end
    gfx.setColor(Color[Color.black])
    local aw = weights[lw]
    gfx.rectangle("fill", box_w / 3, mid - (aw / 2),
      box_w / 2, aw)
  end
end

function drawToolbox()
  --- outline
  gfx.setColor(Color[Color.white])
  gfx.rectangle("fill", 0, 0, box_w - 1, height - pal_h)
  gfx.setColor(Color[Color.white + Color.bright])
  gfx.rectangle("line", 0, 0, box_w - 1, box_h)
  drawTools()
  drawWeightSelector()
end

function getWeight()
  local aw
  if tool == 1 then
    aw = weights[weight]
  elseif tool == 2 then
    aw = weights[weight] * 1.5
  end
  return aw
end

function drawTarget()
  local x, y = love.mouse.getPosition()
  if inCanvasRange(x, y) then
    local aw = getWeight()
    gfx.setColor(Color[Color.white])
    gfx.circle("line", x, y, aw)
  end
end

function love.draw()
  drawBackground()
  drawToolbox()
  drawColorPalette()
  gfx.draw(canvas, box_w)
  drawTarget()
end

function setColor(x, y, btn)
  local row = math.modf((height - y) / block_h)
  local col = math.modf((x - sel_w) / block_w)
  if btn == 1 then
    color = col + (8 * row)
  elseif btn > 1 then
    bg_color = col + (8 * row)
  end
end

function setTool(_, y)
  local h = icon_d + m_4
  local sel = math.modf(y / h) + 1
  if sel <= n_t then
    tool = sel
  end
end

function setLineWeight(y)
  local ws = #weights
  local h = weight_h / ws
  local lw = math.modf((y - wb_y) / h) + 1
  if lw > 0 and lw <= ws then
    weight = lw
  end
end

function useCanvas(x, y, btn)
  local aw = getWeight()
  canvas:renderTo(function()
    if btn == 1 then
      if tool == 1 then
        gfx.setColor(Color[color])
      elseif tool == 2 then
        gfx.setColor(Color[bg_color])
      end
    elseif btn == 2 then
      gfx.setColor(Color[bg_color])
    end
    gfx.circle("fill", x - box_w, y, aw)
  end)
end

function point(x, y, btn)
  if inPaletteRange(x, y) then
    setColor(x, y, btn)
  end
  if inCanvasRange(x, y) then
    useCanvas(x, y, btn)
  end
  if inToolRange(x, y) then
    setTool(x, y)
  end
  if inWeightRange(x, y) then
    setLineWeight(y)
  end
end

function love.singleclick(x, y)
  point(x, y, 1)
end

function love.doubleclick(x, y)
  point(x, y, 2)
end

function love.mousemoved(x, y, dx, dy)
  if inCanvasRange(x, y)
  then
    for btn = 1, 2 do
      if
          love.mouse.isDown(btn)
      then
        useCanvas(x, y, btn)
      end
    end
  end
end

colorkeys = {
  ['1'] = 0,
  ['2'] = 1,
  ['3'] = 2,
  ['4'] = 3,
  ['5'] = 4,
  ['6'] = 5,
  ['7'] = 6,
  ['8'] = 7,
}
function love.keypressed(k)
  if k == 'tab' then
    if tool >= n_t then
      tool = 1
    else
      tool = tool + 1
    end
  end
  if k == '[' then
    if weight > 1 then
      weight = weight - 1
    end
  end
  if k == ']' then
    if weight < #weights then
      weight = weight + 1
    end
  end
  local c = colorkeys[k]
  if c then
    if Key.shift() then
      c = c + 8
    end
    color = c
  end
end
