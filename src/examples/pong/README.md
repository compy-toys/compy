# Pong2 with square ball

This example shows how to build a small 
real-time game step by step. 
It demonstrates how to structure 
a program, store all state in one table, 
update the world in small bounded time steps, 
and draw the result every frame.

The goal of this example is also to show 
how discrete simulation works in practice — 
how the game world advances in small, 
fixed slices of time instead of depending 
on the speed of the device.

The approach used here also helps overcome 
the limited performance
of Compy hardware by keeping updates 
deterministic and efficient.

---

### 1. Files and purpose

The project has three files:
- **constants.lua** — numbers that never change: 
sizes, colors, speeds. 
- **strategy.lua** — code that decides 
how the right paddle moves.
It can follow the ball (AI) or be controlled 
by a second player.
- **main.lua** — the main program. 
It sets up the screen, initializes state, 
runs the update loop and draws the picture.

Separating logic, constants, and behavior 
keeps the program readable and efficient.

---

### 2. Constants

```lua
PADDLE_WIDTH   = 10
PADDLE_HEIGHT  = 60
BALL_SIZE      = 10
AI_DEADZONE    = 4
COLOR_FG       = {1, 1, 1}
COLOR_BG       = {0, 0, 0}
```
These numbers define proportions, not absolute pixels. 
The actual paddle and ball sizes are computed 
in main.lua from the current screen height, 
so the game scales to different displays.
They are still read-only during the run.

---

### 3. Game state

All moving objects and scores live in one table S:
```lua
S = {
  player = { x, y, w, h, dy },
  opp    = { x, y, w, h, dy },
  ball   = { x, y, dx, dy, size },
  playerScore = 0,
  oppScore    = 0,
  state = "start"
}
```
The program updates these values each step 
and then draws them. Keeping everything 
together makes it easy to inspect and debug.

---

### 4. Setting up the screen

At startup, cache_dims() measures 
the screen once and stores:
```lua
screen_w  = G.getWidth()
screen_h  = G.getHeight()
local base_h = 480
local scale  = screen_h / base_h
paddle_w  = math.floor(PADDLE_WIDTH  * scale + 0.5)
paddle_h  = math.floor(PADDLE_HEIGHT * scale + 0.5)
ball_size = math.floor(BALL_SIZE     * scale + 0.5)
paddle_max_y = screen_h - paddle_h
ball_max_y   = screen_h - ball_size
center_x     = math.floor(screen_w / 2 + 0.5)
```
This way, the same proportions are kept, 
but real sizes follow the
actual screen size.

---

### 5. Drawing the scene

All drawing happens inside love.draw():
	1.	Clear the screen.
	2.	Draw the cached divider canvas.
	3.	Draw paddles, ball, and scores.
	4.	Draw text messages such as “Press Space”.

Example:
```lua
function love.draw()
  cache_dims()
  G.clear(COLOR_BG)
  G.setColor(COLOR_FG)
  G.draw(CENTER_CANVAS)
  draw_paddle(S.player)
  draw_paddle(S.opp)
  draw_ball(S.ball)
  draw_scores()
  draw_state_text()
end
```
The center divider is drawn once on a canvas. 
Its segment height uses the same `ball_size` 
that was computed from the screen, 
so the whole scene stays proportional.
Drawing only from cached data keeps rendering 
predictable even on slow devices.

---

### 6. Input and control

The left paddle can be moved with the mouse 
or keys Q and A.
The right paddle uses a strategy selected 
at startup:
```lua
strategy.set_opp_strategy("ai")
```
for a computer opponent, or
```lua
strategy.set_opp_strategy("manual")
```
for a second human using arrow keys.

Press Space to start or restart; 
Escape to quit.Input handling 
is done via a small key_actions
table instead of long if-chains, 
making it easy to extend for 
new game states.

---

### 7. The update loop

`love.update(dt)` is called many times per second. 
The program measures real time since the previous 
frame and advances the simulation in small bounded 
time steps. Each integration step uses the same duration 
(`FIXED_DT`), but the total number of steps per frame 
is limited by `MAX_STEPS`. This prevents the game
from getting stuck if one frame takes too long.

```lua
acc = acc + rdt
while acc >= FIXED_DT and steps < MAX_STEPS do
  step_game(FIXED_DT)
  acc = acc - FIXED_DT
  steps = steps + 1
end
```
Originally this bounded-step loop 
was added to compensate for 
an expensive per-frame screenshot 
on Compy. After removing that feature, 
the loop is no longer strictly required 
for performance. It remains good practice, 
because random long frames can still
happen when the garbage collector (GC) runs.

`FIXED_DT` is the duration of 
one physics step (1/60 s).
`MAX_STEPS` limits the number 
of updates per frame, ensuring 
consistent gameplay across devices.

### 8. One step and ball logic

Each call to step_game(dt) advances 
the world by one quantum of time:
```lua
update_player(dt)
strategy.update(S, dt)
step_ball(S.ball, dt)
handle_score()
```
These operations are simple arithmetic updates, 
chosen to be fast enough for Compy’s limitations. 
The combination of short steps and minimal math 
gives smooth motion without heavy load.

When checking for goals, the code compares
`b.x + b.size` with `screen_w`, 
not with a constant, because the ball size 
was scaled earlier in `cache_dims()` 
and copied into `S.ball.size` during layout.

---

### 9. Handling score

After each step, the game checks if a goal
was scored or the ball left the screen:
```lua
function handle_score()
  if check_scored(S.ball.x) then
    reset_ball()
    return true
  end
  if S.ball.x < 0 or
     screen_w < S.ball.x + S.ball.size
  then
    reset_ball()
    return true
  end
  return false
end
```
This helper centralizes score handling.
It replaces the old check_score() calls
and ensures the ball resets correctly.

---

### 10. Opponent strategies

`strategy.lua` defines how the right paddle 
moves.

AI strategy
```lua
local d = (S.ball.y + S.ball.size/2) -
          (S.opp.y + S.opp.h/2)
if math.abs(d) > AI_DEADZONE then
  move_paddle(S.opp, (d > 0) and 1 or -1, dt)
end
```
The paddle follows the ball but pauses inside 
a small “dead zone” so it does not react instantly.

Manual strategy:
```lua
if love.keyboard.isDown("up") then dir = -1
elseif love.keyboard.isDown("down") then dir = 1 end
move_paddle(S.opp, dir, dt)
```
Any new behavior can be added as:
```lua
strategy.set_opp_strategy("custom", function(S, dt)
  -- your logic here
end)
```
Because the module is separate, 
the game code stays clean.

---

### 11. Discrete simulation and Compy performance

The discrete, bounded-step simulation 
is  not only a teaching tool.
It is also a performance solution.

On Compy, frame rate and CPU speed 
can vary between devices. 
If physics were tied directly to dt, 
motion would become slower
or faster depending on load.

By processing time in small, 
bounded slices the game stays predictable 
even when rendering slows down 
on Compy devices.

Originally, bounded updates were introduced 
to offset the performance loss from taking 
a full-frame screenshot each cycle.
After that feature was removed, 
this logic became optional for speed, 
yet still valuable to absorb random long frames 
caused by the garbage collector (GC).

In short, discrete time keeps the game fair 
and efficient even on limited hardware.

--- 

### 12. Common issues
 
 * Tunneling: a fast ball may skip 
   a paddle if the time step is too large. 
   Reduce ball speed or lower `FIXED_DT`.
 * Frame drop: if too many updates pile up, 
   the loop stops at `MAX_STEPS` and 
   the game slows slightly instead of freezing.
 * Mixed timing: always use fixed `dt` 
   for physics and real `dt` only for animation 
   or timers.
 * High SPEED_SCALE: makes movement faster 
   but less accurate.
 * Bounded steps also protect the game 
   from rare GC pauses.
 * Bounded steps also protect the game 
   from rare GC pauses that can freeze
   animation for a moment.
