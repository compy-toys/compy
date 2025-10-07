## Paint

The Paint(brush) game is a touch-first project. It can, of course, be used with a mouse, and will offer keyboard conveniences, but it's foremost intent is to be used on a touchscreen.

### Interface design

We have 3 main areas of interest:
* the color palette
* the tool pane
* the canvas

```plain
+--------+--------------------------------------------------+
│  +--+  │                                                  │
│  |  |  │                                                  │
│  +--+  │                                                  │
│  tool  │                                                  │
│  +--+  │                                                  │
│  |  |  │                                                  │
│  +--+  │                                                  │
│--------│                     canvas                       │
│        │                                                  │
│        │                                                  │
│  line  │                                                  │
│        │                                                  │
│        │                                                  │
│        │                                                  │
+-----------+-----+-----+-----+-----+-----+-----+-----+-----+
│  +-----+  │     │     │     │     │     │     │     │     │
+  │color│  +-----+-----+-----+-----+-----+-----+-----+-----+
│  +-----+  │     │     │     │     │     │     │     │     │
+-----------+-----+-----+-----+-----+-----+-----+-----+-----+
```

The tool window is further split in two: tool selection and tool size (or line width).
Similarly, the color palette is split between the controls for selecting and displaying said selection.
We can draw freely on the rest of the space.

#### Palette

Building on the 16-color theme, we will divide the screen into 10 columns (8 colors + 2 for display).
Then halve these columns to get the row height. Display the selected background on a double block, with the foreground color in the middle.

```lua
width, height = gfx.getDimensions()
--- color palette
block_w = width / 10
block_h = block_w / 2
pal_h = 2 * block_h
pal_w = 8 * block_w
sel_w = 2 * block_w
```

#### Toolbox

It shall be 1.5 times column width, the height taking the rest of the screen not used by the palette. We will also add a margin so the controls have some breathing room from the side.

```lua
--- tool pane
margin = block_h / 10
box_w = 1.5 * block_w
box_h = height - pal_h
```

Currently, there's only two tools: a brush and an eraser. We have to divide the available space between them, being mindful that they will need to fit on different screen sizes.
We will have double margins on the top and bottom, and quadruple to the sides, displaying them on top of each other, that comes out to:

```lua
m_4 = margin * 4
n_t = 2
icon_h = (tool_h - m_4) / n_t
icon_w = (box_w - m_4 - m_4) / 1
icon_d = math.min(icon_w, icon_h)
```

Depending on the screen, we might be more limited based on either height or width, so the square icon's size will be the determined by the smaller of the two. This ensures that we can comfortably draw them on any reasonable size. There might be edge cases of screens so small that we can't display properly, a shortcoming whose solution is left as an exercise to the reader.

### Interaction

#### Pointing and clicking

A very central theme in this application is determining where the user clicks/taps. For starters there's the drawing, but also switching tools and colors.

Click and taps will start out in the `point()` function:

```lua
function point(x, y, btn)
  if inPaletteRange(x, y) then
    setColor(x, y, btn)
  end
  if inCanvasRange(x, y) then
    useCanvas(x, y, btn)
  end
  if inToolRange(x, y) then
    selectTool(x, y)
  end
  if inWeightRange(x, y) then
    setLineWeight(y)
  end
end
```

Simply check where the click is, and forward it to the respective handler. If we set up our functions correctly, there should not be more than one thing happening in any single interaction.

For example:

```lua
function inCanvasRange(x, y)
  return (y < height - pal_h and box_w < x)
end

function inPaletteRange(x, y)
  return (height - pal_h <= y
    and width - pal_w <= x and x <= width)
end
```

To be registered on the canvas (more on that later), a the x coordinate has to be strictly larger than the toolbox width, and strictly smaller than `height - palette height`. On the other hand,
th function that detects palette click uses `<=`. Not that it would be that terrible to have a single pixel width of overlap/hiatus, but this way each one is accounted for.

Once we know what interface element we are on, we can move on to the tiny bit more advanced math:

```lua
function setColor(x, y)
  local row = math.modf((height - y) / block_h)
  local col = math.modf((x - sel_w) / block_w)

  color = col + (8 * row)
end
```

To find out which color block was clicked, we have to do some integer division.
`math.modf(n)` splits up a `n` into it's integer and fractional part.
```lua
local i, f = math.modf(2.3)
-- i = 2 , f = 0.3
```

In our case, we are only interested in the whole number to navigate our grid, and work back to a color index, preferably the same one that was used for displaying it:

```lua
  local y = height - block_h
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
```

## Drawing

Okay, let's create some pictures. It's time we talked about what a canvas is. In LOVE parlance, a canvas is a piece of drawable graphics, just like lines and rectangles, but we can draw multiple things on them. This can already be useful if for drawing the same thing multiple times on the screen. Of course, that's always possible with repeating most of the code, or using functions (a better idea). However, with a canvas, we can do the rendering off-screen, and put the whole result up at once. When drawing heavy graphics, this is a lot easier on the hardware.

We will use a canvas to record the player's drawings. Not only is this very convenient, it spares the horrible amount of work it would take to store every click and the tool used, and re-render it on each frame.

Let's see how this works. First, we set up the canvas:

```lua
can_w = width - box_w
can_h = height - pal_h - 1
canvas = gfx.newCanvas(can_w, can_h)
```

The default size of a canvas would be equivalent to the screen, but we have some UI elements here, so a bit smaller makes more sense. However, this does mean we need to calculate the offsets properly when detecting clicks and displaying it.

We can draw on a canvas (and not the screen) by calling the `setCanvas()` function with the canvas as the parameter, doing the various operations as we normally would, then calling it again, this time without any parameters, which resets the main canvas as active.

This is somewhat cumbersome, and there *is* a shortcut provided: `Canvas` objects have a `renderTo()` function, which does much the same for us automatically, provided we wrap the drawing operations in a function:

```lua
function useCanvas(x, y, btn)
  local aw = getWeight()
  canvas:renderTo(function()
    -- ...
    gfx.circle("fill", x - box_w, y, aw)
  end)
end
```

Note the _x_ coordinate, which is offset by `box_w` (the width of the side panel). When drawing, we go the opposite direction: `gfx.draw(canvas, box_w)`.

### Click detection

There's one more challenge to tackle: with touch, we don't have second button, no right-click. If we want a secondary use case (like setting the background color instead of the foreground), we have to come up with some other way.
Double clicks/taps are a workable solution, but there is a problem: detecting them is not trivial. Any second click is necessarily preceded by a first one, so you need to kind of hold off on doing anything and wait to see if a second tap follows.

To solve for this, we created custom handlers for single and double clicks:

```lua
function love.singleclick(x, y)
  point(x, y, 1)
end

function love.doubleclick(x, y)
  point(x, y, 2)
end
```

A drawback of this is it feels somewhat less snappy, because of the wait time, but there isn't really a way around this. Another quirk is that if you move the cursor or your finger, it can't be registered as a double click on the same point, so instead of trying the impossible and deciding which position between the two should be the relevant one, these are considered invalid and no action is taken.

With these, our rudimentary Paint app is complete.
