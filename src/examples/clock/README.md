### Clock

In this example, we explore how to properly create a program with it's own drawing function. Additionally, we will query the underlying system for the current time and date.

#### Overriding `love.draw()`

We will be taking over the screen drawing for this simple game.
Similar to `update()`, we can override the `love.draw()` function and have the LOVE2D framework handle displaying the content we wish.
Drawing generally follows a simple procedure: set up some values, such as what foreground and background color to use, then build up our desired image using basic elements. These are called graphics "primitives", and we can access them from the `love.graphics` table (aliased here as `gfx`).

So, our example clock:
```lua
function love.draw()
  gfx.setColor(Color[color + Color.bright])
  gfx.setBackgroundColor(Color[bg_color])
  gfx.setFont(font)

  local text = getTimestamp()
  local off_x = font:getWidth(text) / 2
  local off_y = font:getHeight() / 2
  gfx.print(text, midx - off_x, midy - off_y)
end
```
Let's see this step-by-step.
In the first half, we set up the properties: the colors and the font. Strictly speaking, the font could be moved out of here, because it will not change through the run, but the player is able to change the background and foreground colors, so these may be different between calls of the `draw()` function.
Having done this, we need to _provide_ the text being displayed (`getTimestamp()` function, discussed later), then position it center screen. This requires some thinking on our part.
The way the `print` helper, and most graphics helpers work, is by starting drawing at the coordinates provided, but these coordinates will point to the leftmost and topmost (remember, x grows downwards in screen coordinates) corner of the element being displayed.
So, we need to determine the half-width and half-height of our text object to correctly draw it at the center. To do this, we can use the `getWidth()` and `getHeight()` helpers.
We determined the midpoint of the screen earlier:
```lua
width, height = gfx.getDimensions()
midx = width / 2
midy = height / 2
```
Armed with this, we can draw the time dead center:
```lua
gfx.print(text, midx - off_x, midy - off_y)
```

#### Getting the timestamp

To keep time, we'll do two things: first, ask what it is currently, then increment the value every second.

First, declare some variables and constants:
```lua
local M = 60 -- seconds in a minute, minutes in an hour
local H = m * m -- seconds in an hour
local D = 24 -- hours in a day

local H, M, S, t
```
Uppercase names refer to ratios (which are constants), lowercase ones to variable value of hours, minutes, seconds. Keeping to this convention aids readability.

```lua
function setTime()
  local time = os.date("*t")
  h = time.hour
  m = time.min
  s = time.sec
  t = s + M * m + H * h
end
```
Reading the current time is achieved by using `os.date()`, which unlike `os.time()`, allows us to specify the format of the resulting stringfx. We want to achieve the end result of "hour:minute"second", which we could get with the format string "%H:%M:%S", but we also need these intermediate values separately, to keep time. Instead, if the special format string "*t" is passed to the function, it will return a table with the parts of the timestamp instead of a stringfx.

#### Timekeeping

Using the update function, we can keep track of time elapsed:
```lua
function love.update(dt)
  t = t + dt
end
```
Going back from the number of seconds to a human-readable time will require some division:
```lua
local function pad(i)
  return string.format("%02d", i)
end

function getTimestamp()
  local hours = pad(math.fmod((t / H), D))
  local minutes = pad(math.fmod((t / M), M))
  local seconds = pad(math.fmod(t, M))
  return string.format("%s:%s:%s", hours, minutes, seconds)
end
```
Quick aside on format strings: for a digital clock, we usually want to have the numbers displayed as two digits, with colons in between them. To achieve this, we `pad` all our results, then stitch them together with `string.format()`.
In the above code, we are doing two different kinds of division.First, an integer division (`/`), going from seconds to minutes and hours, in this case we are only interested in the whole numbers, for example: 143 seconds is two full minutes and then some, but what the clock will be displaying is '02', so the remaining 23 seconds is not interesing for the minutes part.
However, for 143 minutes, the display _should_ say 23, disregarding the two full hours, we are only interested in the remainder part. We can get this value by using `math.fmod()`, in this example, `math.fmod(143, 60)`.

#### User documentation

This program displays the current time in a randomly selected color over a randomly selected background. These colors can be changed by pressing [Space] and [Shift-Space], respectively.
Should the clock deviate from the correct time (for example, because the program run was paused), it can be reset with the [R] key.
