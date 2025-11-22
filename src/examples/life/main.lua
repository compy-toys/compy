--- Conway's Game of Life
--- original from https://github.com/Aethelios/Conway-s-Game-of-Life-in-Lua-and-Love2D

gfx = love.graphics
gfx.setFont(font)
fh = font:getHeight()

cell_size = 10
margin = 5
screen_w, screen_h = gfx.getDimensions()
grid_w = screen_w / cell_size
grid_h = screen_h / cell_size
grid = {}

mouse_held = false
hold_y = nil
hold_time = 0
speed = 10
time = 0
epsilon = 3
reset_time = 1

tick = function()
  if time > (1 / speed) then
    time = 0
    return true
  end
end

function initializeGrid()
  for x = 1, grid_w do
    grid[x] = {}
    for y = 1, grid_h do
      -- Initialize with some random live cells
      grid[x][y] = 0.7 < math.random() and 1 or 0
    end
  end
end

local function init()
  time = 0
  initializeGrid()
end

function countHelper(nx, ny)
  local c = 0
  if 1 <= nx
      and nx <= grid_w
      and 1 <= ny
      and ny <= grid_h
  then
    local row = grid[nx] or {}
    c = c + (row[ny] or 0)
  end
  return c
end

function countAliveNeighbors(x, y)
  local count = 0
  for dx = -1, 1 do
    for dy = -1, 1 do
      if dx ~= 0 or dy ~= 0 then
        local nx, ny = x + dx, y + dy
        count = count + countHelper(nx, ny)
      end
    end
  end
  return count
end

local function updateGrid()
  local newGrid = {}
  for x = 1, grid_w do
    newGrid[x] = {}
    for y = 1, grid_h do
      local neighbors = countAliveNeighbors(x, y)
      if grid[x][y] == 1 then
        newGrid[x][y] =
            (neighbors == 2 or neighbors == 3) and 1 or 0
      else
        newGrid[x][y] = (neighbors == 3) and 1 or 0
      end
    end
  end
  grid = newGrid
end

function changeSpeed(d)
  if not d then return end
  if d < 0 and 1 < speed then
    speed = speed - 1
  end
  if 0 < d and speed < 99 then
    speed = speed + 1
  end
end

function love.update(dt)
  time = time + dt
  if love.mouse.isDown(1) then
    hold_time = hold_time + dt
  end
  if tick() then
    updateGrid()
  end
end

function love.keypressed(k)
  if k == "r" then
    init()
  end
  if k == "-" then
    changeSpeed(-1)
  end
  if k == "+" or k == "=" then
    changeSpeed(1)
  end
end

function love.mousepressed(_, y, button)
  if button == 1 then
    mouse_held = true
    hold_y = y
  end
end

function love.mousereleased(_, y, button)
  if button == 1 then
    mouse_held = false
    if reset_time < hold_time then
      init()
    else
      if hold_y then
        local dy = hold_y - y
        if math.abs(dy) > epsilon then
          changeSpeed(dy)
        end
      end
    end
    hold_y = nil
    hold_time = 0
  end
end

function drawHelp()
  local bottom = screen_h - margin
  local right_edge = screen_w - margin
  local reset_msg = "Reset: [r] key or long press"
  local speed_msg = "Set speed: [+]/[-] key or drag up/down"
  gfx.print(reset_msg, margin, (bottom - fh) - fh)
  gfx.print(speed_msg, margin, bottom - fh)
  local speed_label = string.format("Speed: %02d", speed)
  local label_w = font:getWidth(speed_label)
  gfx.print(speed_label, right_edge - label_w, bottom - fh)
end

function drawCell(x, y)
  gfx.setColor(.9, .9, .9)
  gfx.rectangle('fill',
    (x - 1) * cell_size,
    (y - 1) * cell_size,
    cell_size, cell_size)
  gfx.setColor(.3, .3, .3)

  gfx.rectangle('line',
    (x - 1) * cell_size,
    (y - 1) * cell_size,
    cell_size, cell_size)
end

function love.draw()
  for x = 1, grid_w do
    for y = 1, grid_h do
      if grid[x][y] == 1 then
        drawCell(x, y)
      end
    end
  end

  gfx.setColor(1, 1, 1, 0.5)
  drawHelp()
end

math.randomseed(os.time())
initializeGrid()
