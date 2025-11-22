### Turtle

Turtle graphics game inspired by the LOGO family of languages.
It is currently in a very early stage of implementation, offering few features.

#### Multiple source files

The entrypoint for all projects is `main.lua`, and in some cases, that's all you will need, but in more complex cases such as this one, splitting up the code into multiple smaller files can greatly enhance readability and maintainability.
Doing is this is quite simple: create the new file, and include it in `main.lua` using the `require()` function.

There are two potential pitfalls to look out for here:
* The file should have `.lua` extension, but when `require()`-ing it, you need to omit that.
* Don't declare variables or functions `local` if you want to use it from the outside world.

Example in `main.lua`:
```lua
require('action')
```
This imports the definitions from `action.lua` so they can be used in `main.lua`.
Notice that the code has been organized thematically, with the parts concerning what the turtle can do located in `action.lua` while it's presentation (how to it's displayed) moved to `drawing.lua`.

#### Advanced drawing

Since we are controlling the turtle programmatically, it makes a lot of sense to draw the turtle programmatically, taking advantage of the graphics system conveniences.
Effectively this means that instead of calculating the coordinates for every element we want to draw, we change the coordinate system first, and draw in it's terms, which is often more convenient.

For the most simple example of this, let's represent the turtle with only an ellipse with a major radius `y_r` and a minor radius `x_r`:
```lua
local x_r = 15
local y_r = 20
function turtleA(x, y)
  gfx.ellipse("fill", x, y, x_r, y_r, 100)
end
function turtleB(x, y)
  gfx.translate(x, y)
  gfx.ellipse("fill", 0, 0, x_r, y_r, 100)
end
```
We can draw it at (x, y) either by drawing the shape to (x, y), or first translating the whole drawing to (x, y), and drawing at (0, 0). This might not seem that big of a deal in this simple case, but when the number of transformations and shapes go up, things cat get hard to track very quickly.

###### Aside: Ellipses

An ellipse is a symmetrical curved shape that resembles a stretched circle. Unlike a circle which has the same width all around, an ellipse has two key measurements: the major axis (its longest measurement from edge to edge through the center) and the minor axis (its shortest measurement through the center). These two axes are always perpendicular to each other and meet at the center of the ellipse. The ratio between these axes determines how "stretched" or "squished" the ellipse appears - when they're equal, you get a perfect circle.
The way we translate this for LOVE is an "x radius" and a "y radius". <br />In our case, we want the turtle body to be longer vertically and shorter horizontally, so `y` will be our major axis and `x` the minor.

Next, we are adding the turtle's head, which is in some sort of relation to it's body, but also the location where the whole drawing is.
```lua
gfx.circle("fill", 0, ((0 - y_r) - head_r) + neck, head_r, 100)
```
Using the second method, we are able to provide the head position in "turtle coordinates".
So far, there's nothing about this we couldn't have done the other route, but let's proceed to the legs, which we want to draw at an angle. LOVE doesn't provide us any way to do this with only the ellipse function, we do need to `rotate` first.

See this condensed example:
```lua
function frontLeftLeg(x, y, x_r, y_r, leg_xr, leg_yr)
  gfx.setColor(Color[Color.green + Color.bright])
  --- move to the turtle's position
  gfx.translate(x, y)
  --- move to where the leg attaches to the body
  gfx.translate(-x_r, -y_r / 2 - leg_xr)
  --- rotate
  gfx.rotate(-math.pi / 4)
  --- draw the leg
  gfx.ellipse("fill", 0, 0, leg_xr, leg_yr, 100)
end
```

(Other functions, like `print()`, do provide a way to draw rotated and scaled, but for ellipses, it's not supported, so the transformations have to be applied first.)

###### Aside: Angles

The `rotate` function takes a radian value as it's argument. We want the legs at 45 degree angles, which in radian terms is equal to `π / 4`. Also, in the example above, to draw the left leg, it needs to rotate counter-clockwise, hence the negative value.

##### Pushes and pops

You will notice that the actual code does not look like that. For one, in the leg-drawing functions, there's only one `translate()` call, because they are happening relative to the turtle, we already moved where the turtle is.
Another, more interesting difference is the `push()` - `pop()` pairs around each leg.
```lua
--- left front leg
gfx.push("all")
gfx.translate(-x_r, -y_r / 2 - leg_xr)
gfx.rotate(-math.pi / 4)
gfx.ellipse("fill", 0, 0, leg_xr, leg_yr, 100)
gfx.pop()
--- right front leg
gfx.push("all")
gfx.translate(x_r, -y_r / 2 - leg_xr)
gfx.rotate(math.pi / 4)
gfx.ellipse("fill", 0, 0, leg_xr, leg_yr, 100)
gfx.pop()
```
Say we are done drawing the left leg, and now we want to proceed to drawing the other one. We could do the opposite transformations to go back to "zero", or transform from our current state to the desired one, but that leads to more complicated math and less readable code.
Instead, we work in stages. When done with the first leg, we can "reset" to our previous state (the "turtle coordinates"), and set up our next one again relative to the center.
`push()` and `pop()` are like parens, they need to be balanced. Draw operations have to happen every frame, meaning several tens of times each second, and each push saves some data. This is fine, _if_ we properly clean up after ourselves by popping back and letting go of the data, otherwise we will run out of storage very quickly.

### User documentation

How to use:
Press [I] to open the console.
