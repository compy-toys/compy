## Life

This is a simple Game of Life implementation, which is maybe not the first, but certainly the best known zero-player computer game.
The game field is a two-dimensional array (grid), where each **cell** (block, square) is either _alive_ or _dead_ (in programming parlance, `1` or `0`).
Given the initial state and a few simple rules, we are simulatiing the life of these cells.

### Screen size

We have used the screen size before, but only in a very limited capacity, to determine where the middle is. This time, however, the whole game depends on how much pixels we have available.

```lua
cell_size = 10
screen_w, screen_h = gfx.getDimensions()
grid_w = screen_w / cell_size
grid_h = screen_h / cell_size
```

`getDimensions()` gives us the width and height of the screen, which we will divide by some scaling factor (say 10), resulting in a grid of 10-by-10 cells.

### Setup

Starting up, generate random values for cell states:

```lua
local function initializeGrid()
  for x = 1, grid_w do
    grid[x] = {}
    for y = 1, grid_h do
      -- Initialize with some random live cells
      grid[x][y] = math.random() > 0.7 and 1 or 0
    end
  end
end
```

### Simulation

Then, at each step, we apply the following rules:
* Any live cell with fewer than two live neighbours dies
* Any live cell with two or three live neighbours lives on
* Any live cell with more than three live neighbours dies
* Any dead cell with exactly three live neighbours becomes a live cell

(excerpt from `updateGrid()`)
```lua
  local neighbors = countAliveNeighbors(x, y)
  if grid[x][y] == 1 then
    newGrid[x][y] =
        (neighbors == 2 or neighbors == 3) and 1 or 0
  else
    newGrid[x][y] = (neighbors == 3) and 1 or 0
  end
```

We could just update the grid state on every `update()`, but that would mean the simulation has no consistent pace, it's going as fast as the hardware can crank update calls out, varying between devices.
Instead, we will create a simple timer. The timer is keeping track of elapsed time, and producing "ticks" inversely proportional to a set simulation speed.
On each tick, the grid updates and timer resets.

```lua
time = 0
speed = 10

tick = function()
  if time > (1 / speed) then
    time = 0
    return true
  end
end

function love.update(dt)
  time = time + dt
  if tick() then
    updateGrid()
  end
end
```

### Controls

Being a zero-player game, there's not much to do in the user interaction department. Still, we would like to add the ability to start a new simulation without restarting the whole run, and a knob to adjust the simulation speed.

```lua
function changeSpeed(d)
  if not d then return end
  if d < 0 and 1 < speed then
    speed = speed - 1
  end
  if 0 < d and speed < 99 then
    speed = speed + 1
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
```

Simple and straightforward on the keyboard. However...

### Touch

Until now, we had no concern about running our games outside the environment they are being developed in, so let's give this some thought.
In development, we have a keyboard and mouse, but people these days mostly use a smartphone or tablet as their first (and possibly only) choice.
Therefore, it would be useful to support touchscreens as an input method, too.
Fortunately, LOVE2D is helpful in this regard, as it also fires a mouse event, even if when the interaction was a tap on a touchscreen. This means that to support single touch, we don't have to do anything that different, other than paying attention to the limitations when designing the game controls.

#### Reset

What's a simple keystroke, is a little more involved with the mouse/touchscreen.
Any accidental tap should not trigger it, so we need to keep track of the time elapsed while the button or finger is held in the `update` function:

```lua
hold_time = 0
function love.mousepressed(_, y, button)
  if button == 1 then
    if love.mouse.isDown(1) then
      hold_time = hold_time + dt
    end
  end
end
```

When the same button is released, we check if it was held long enough.
Either way, reset the timer.

```lua
function love.mousereleased(_, y, button)
  if button == 1 then
    mouse_held = false
    if reset_time < hold_time then
      init()
    end
    hold_time = 0
  end
end
```

#### Speed

How to handle speeding up and down? We could split the screen up, and say that tapping the top half increases speed, while the bottom half decreases it:

```lua
function love.mousereleased(_, y, button)
  if button == 1 then
    mouse_held = false
    if reset_time < hold_time then
      init()
    else
      if y < mid_y then
        changeSpeed(1)
      else
        changeSpeed(-1)
      end
    end
    hold_time = 0
  end
end
```

(Remember, the y coordinate grows from the top of the screen towards the bottom)
This is a fine solution, but we can make it more interesting. Some videoplayer apps have a user experience where if you drag your finger on the screen, it adjusts the volume or the brightness, depending on direction. That sounds more interesting, let's implement it!

For a first approximation, try the `mousemoved` handler:
```lua
g_dir = nil

function love.mousemoved(_, _, _, dy)
  if love.mouse.isDown(1) then
    if dy < 0 then
      g_dir = 1
    elseif dy > 0 then
      g_dir = -1
    end
  end
end
```

This sets the pull direction while holding a click or tap. Then at release, change the speed accordingly:

```lua
function love.mousereleased(_, _, button)
  if button == 1 then
    mouse_held = false
    if hold_time > 1 then
      init()
    elseif g_dir then
      changeSpeed(g_dir)
    end
    hold_time = 0
  end
end
```

There's one problem with this approach: all taps will change the speed if there's even a miniscule difference between press and release. We should introduce some kind of treshold for the number of pixels the difference needs to be for it to count as a purposeful gesture.
Scrapping our first approach, we'll do something similar to the long tap: record the position on press...

```lua
hold_y = nil
function love.mousepressed(_, y, button)
  if button == 1 then
    mouse_held = true
    hold_y = y
  end
end
```

...and compare it when it's released:

```lua
epsilon = 3
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
```

As you can see, I have determined that the difference should be at least 3 pixels, regardless of the sign (hence the `maths.abs()`).

### Help text

With all that done, add some explanations for our users, and call it a day.
Note the calculations we need to make so it shows up relative to the bottom of the screen:

```lua
margin = 5

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
```
