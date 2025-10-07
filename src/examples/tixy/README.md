## tixy

Reimplementation of https://tixy.land/, a javascript project.
The idea is driving a 16x16 duotone dot matrix display by defining a function, which gets evaluated for each individual pixel and over time.
Input parameters to the function are: `t, i, x, y`, (hence the name), that is:

* `t` - time
* `i` - index of the pixel
* `x` - vertical coordinate
* `y` - horizontal coordinate

### Multiple source files

See the `turtle` project for detailed explanation.

### Math

`math.lua` does a couple of things:

* defines a `hypot()` function - this is something that the javascript Math library has, and some examples make use of it, so it had to be reimplemented
* imports the `math` module contents into the global namespace

The latter is for the sake of brevity, more involved procedural drawing uses a lot of math functions in concert, repetition gets tedious quickly.

This provides a great opportunity to explain how the global environment works. It resides in a special table named `_G`.
We can add fields this way:
```lua
for k, v in pairs(math) do
  _G[k] = v
end
```

...and finally,
* it imports the bit library
The lua implementation we use does not have bitwise operators, even though they can be very useful for creating pixel patterns. Just like with the math functions, we add these to the global table for ease of use.

#### Bitwise operations

Relevant operations from the `bit` library:

* `bor(x1 [,x2...])`
* `band(x1 [,x2...])`
* `bxor(x1 [,x2...])`
  Bitwise OR, bitwise AND, and bitwise XOR of all (read: not just two are supported) arguments
* `lshift(x, n)` / `rshift(x, n)`
  Shift of `x` left or right by `n` bits

### Function body

We need to take advantage of several more advanced features in lua.
First, to take some string and if it's valid code, turn it into a function, we use `loadstring`.

```lua
local f = loadstring(code)
```

Should there be some syntactic problem, we will get `nil` back, so the next stop is checking for that. In our case, the input already validates, so we should not find ourselves on the unhappy side of this.

Next, set up the environment the function will run in, which should be `_G`, the same environment we prepared with easy access to math functions and bit operations.

```lua
setfenv(f, _G)
```

Then we can actually run it:
```lua
tixy = f()
```

Here's what the actual function looks like:

```lua
function f()
  return function(t, i, x, y)
    -- body
  end
end
```

Meaning that `f` returns another function, which will then be used for calculating the value of each pixel.

### Mouse handling

To switch between examples, we make use of mouse handling. For this use case, LÖVE2D provides these event handlers:
* `mousepressed(x, y, button)` / `mousereleased(x, y, button)`
  When a mouse button is clicked or released.
* `mousemoved(x, y, dx, dy)`
  When the mouse moves. `(x,y)` is the current position, `(dx,dy)` is the difference compared to the last move event's `(x,y)`.
* `wheelmoved(x, y)`
  Mouse wheel movement.

We don't care about most of this, only what button was clicked, so the first parameters are `_`, which means "I don't care". The `button` parameter takes a value of 1 for left click, 2 for right click, and 3 for the middle button. Your mouse might have extra buttons, but support for those is not guaranteed.

```lua
function love.mousepressed(_, _, button)
  if button == 1 then
    -- ...
  end
  if button == 2 then
    randomize()
  end
end
```

### Plumbing

#### Boolean helpers

Some C-like languages, Javascript included, treat numbers and booleans somewhat loosely (or so loosely that they don't even have a boolean type).
Lua is not like that, so we have to explicitly convert from bools to numbers (`b2n()`) or from numbers to bools (`n2b()`).

#### Math helpers

The `tixy` function returns a number value which we use for the radius of a pixel. This value can be negative, but of course, we can't draw a circle with a less-than-zero radius, and we'd also like it to use a different color. Also, physical pixels have an upper size limit, so when drawing, we need to limit the value so it's never larger than a set maximum. In graphics, making sure that a value stays within bounds is often called *clamping* the value.

```lua
function clamp(value)
  local color = colors.pos
  local radius = (value * size) / 2
  if radius < 0 then
    radius = -radius
    color = colors.neg
  end
  if size / 2 < radius then
    radius = size / 2
  end
  return color, radius
end
```

#### Drawing

```lua
function drawCircle(color, radius, x, y)
  gfx.setColor(color)
  gfx.circle(
    "fill",
    x * (size + spacing) + offset,
    y * (size + spacing) + offset,
    radius
  )
  gfx.circle(
    "line",
    x * (size + spacing) + offset,
    y * (size + spacing) + offset,
    radius
  )
end
```

Why is this code drawing circles twice? First, one circle is filled, the other is an outline, but it's not like it's using a different color, or adding a heavier line. The answer is antialiasing, which our graphics library won't do by default for solids, but will for lines.

##### Antialiasing

Imagine you draw a diagonal line on a grid made of tiny squares (pixels). Computer screens are made up of tiny square pixels arranged in a grid (unlike our round ones), and these pixels can only represent images in blocky steps. Because the line has to go through these squares, the edges look like little stairs instead of a smooth line — this is called "aliasing" or jagged edges. Antialiasing helps by gently blending the colors of the line's edge into the squares next to it, so the line looks smoother and less like stairs. It's like softly coloring the edges so the line looks smoother.
