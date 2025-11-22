-- main.lua

require "constants"
require "strategy"

gfx = love.graphics

-- virtual game space
VIRTUAL_W = 640
VIRTUAL_H = 480

-- runtime configuration
USE_FIXED = true
FIXED_DT = 1 / 60
MAX_STEPS = 5
SPEED_SCALE = 1.5
MOUSE_SENSITIVITY = 1

-- runtime variables
view_tf = nil
screen_w, screen_h = 0, 0
paddle_max_y = 0
ball_max_y = 0

inited = false
mouse_enabled = false
time_t, acc = 0, 0

-- game state

S = { }

S.player = {
  x = PADDLE_OFFSET_X,
  y = 0,
  dy = 0
}
S.opp = {
  x = 0,
  y = 0,
  dy = 0
}
S.ball = {
  x = 0,
  y = 0,
  dx = BALL_SPEED_X,
  dy = BALL_SPEED_Y
}
S.score = {
  player = 0,
  opp = 0
}
S.state = "start"

S.strategy = {
  fn = nil,
  text = nil
}

-- ui resources
font = nil
texts = { }
center_canvas = nil

-- screen helpers

function update_view_transform(w, h)
  screen_w = w
  screen_h = h
  local sx = w / VIRTUAL_W
  local sy = h / VIRTUAL_H
  view_tf = love.math.newTransform()
  view_tf:scale(sx, sy)
end

function cache_dims()
  local w = gfx.getWidth()
  local h = gfx.getHeight()
  update_view_transform(w, h)
end

function layout()
  S.player.x = PADDLE_OFFSET_X
  S.player.y = (VIRTUAL_H - PADDLE_HEIGHT) / 2
  S.opp.x = (VIRTUAL_W - PADDLE_OFFSET_X) - PADDLE_WIDTH
  S.opp.y = (VIRTUAL_H - PADDLE_HEIGHT) / 2
  S.ball.x = (VIRTUAL_W - BALL_SIZE) / 2
  S.ball.y = (VIRTUAL_H - BALL_SIZE) / 2
  paddle_max_y = VIRTUAL_H - PADDLE_HEIGHT
  ball_max_y = VIRTUAL_H - BALL_SIZE
end

-- text helpers

function set_text(name, str)
  local old = texts[name]
  if old then
    old:release()
  end
  texts[name] = gfx.newText(font, str)
end

function rebuild_score_texts()
  set_text("score_l", tostring(S.score.player))
  set_text("score_r", tostring(S.score.opp))
end

function rebuild_opp_texts()
  set_text("easy", "1 Player (easy)")
  set_text("hard", "1 Player (hard)")
  set_text("manual", "2 Players (keyboard)")
end

-- canvas 

function draw_center_line()
  local x = VIRTUAL_W / 2 - 2
  local step = BALL_SIZE * 2
  local y = 0
  while y < VIRTUAL_H do
    gfx.rectangle("fill", x, y, 4, BALL_SIZE)
    y = y + step
  end
end

function build_center_canvas()
  if center_canvas then
    center_canvas:release()
  end
  center_canvas = gfx.newCanvas(VIRTUAL_W, VIRTUAL_H)
  gfx.setCanvas(center_canvas)
  gfx.clear(0, 0, 0, 0)
  gfx.setColor(COLOR_FG)
  draw_center_line()
  gfx.setCanvas()
end

-- initialization

function build_static_texts()
  font = gfx.getFont()
  set_text("start", "Press Space to Start")
  set_text("gameover", "Game Over")
  rebuild_opp_texts()
  rebuild_score_texts()
end

function set_strategy(name)
  S.strategy.fn = strategy[name]
  S.strategy.text = texts[name]
end

function do_init()
  cache_dims()
  layout()
  build_center_canvas()
  build_static_texts()
  mouse_enabled = true
  time_t = love.timer.getTime()
  inited = true
  set_strategy("hard")
end

function ensure_init()
  if not inited then
    do_init()
  end
end

-- paddle and ball movement

function clamp_paddle(p)
  if p.y < 0 then
    p.y = 0
  end
  if VIRTUAL_H < p.y + PADDLE_HEIGHT then
    p.y = VIRTUAL_H - PADDLE_HEIGHT
  end
end

function move_paddle(p, dir, dt)
  p.dy = PADDLE_SPEED * dir
  p.y = p.y + p.dy * dt
  clamp_paddle(p)
end

function check_scored(bx)
  if bx < 0 then
    return "opp"
  end
  if VIRTUAL_W < bx + BALL_SIZE then
    return "player"
  end
  return nil
end

function move_ball(b, dt)
  b.x = b.x + b.dx * dt
  b.y = b.y + b.dy * dt
  if b.y < 0 then
    b.y = 0
    b.dy = -b.dy
  end
  if VIRTUAL_H < b.y + BALL_SIZE then
    b.y = VIRTUAL_H - BALL_SIZE
    b.dy = -b.dy
  end
  return check_scored(b.x)
end

function bounce_ball(b)
  if b.y < 0 then
    b.y = 0
    b.dy = -b.dy
  end
  if ball_max_y < b.y then
    b.y = ball_max_y
    b.dy = -b.dy
  end
end

-- collision and score

function hit_offset(b, p)
  local pc = p.y + PADDLE_HEIGHT / 2
  local bc = b.y + BALL_SIZE / 2
  return (bc - pc) / (PADDLE_HEIGHT / 2)
end

function collide(b, p, off)
  local hx1 = b.x < p.x + PADDLE_WIDTH
  local hx2 = p.x < b.x + BALL_SIZE
  local hy1 = b.y < p.y + PADDLE_HEIGHT
  local hy2 = p.y < b.y + BALL_SIZE
  if hx1 and hx2 and hy1 and hy2 then
    b.x = p.x + off
    b.dx = -b.dx
    b.dy = b.dy + hit_offset(b, p) * (BALL_SPEED_Y * 0.75)
  end
end

function scored(side)
  local s = S.score
  s[side] = s[side] + 1
  rebuild_score_texts()
  if WIN_SCORE <= s[side] then
    S.state = "gameover"
    love.mouse.setRelativeMode(false)
    return true
  end
  return false
end

function reset_ball()
  local b = S.ball
  b.x = (VIRTUAL_W - BALL_SIZE) / 2
  b.y = (VIRTUAL_H - BALL_SIZE) / 2
  local total = S.score.player + S.score.opp
  local dir = (total % 2 == 0) and 1 or -1
  b.dx = dir * BALL_SPEED_X
  b.dy = ((total % 3 - 1) * BALL_SPEED_Y) * 0.3
end

-- control and update

key_actions = {
  start = { },
  play = { },
  gameover = { }
}

function key_actions.start.space()
  S.state = "play"
  love.mouse.setRelativeMode(true)
  reset_ball()
end

function key_actions.start.e()
  set_strategy("easy")
end

function key_actions.start.h()
  set_strategy("hard")
end

key_actions.start["1"] = function()
  if S.strategy.fn ~= strategy.easy then
    set_strategy("hard")
  end
end

key_actions.start["2"] = function()
  set_strategy("manual")
end

function key_actions.play.space()
  
end

function key_actions.play.r()
  S.score.player = 0
  S.score.opp = 0
  rebuild_score_texts()
  layout()
  S.state = "start"
  love.mouse.setRelativeMode(false)
end

key_actions.gameover.space = key_actions.play.r

for name in pairs(key_actions) do
  key_actions[name].escape = love.event.quit
end

function love.keypressed(k)
  local group = key_actions[S.state]
  if group and group[k] then
    group[k]()
  end
end

keydown = {
  q = -1,
  a = 1
}

function update_player(dt)
  local dir = 0
  for k, v in pairs(keydown) do
    if love.keyboard.isDown(k) then
      dir = v
    end
  end
  move_paddle(S.player, dir, dt)
end

function love.mousemoved(x, y, dx, dy, t)
  if not mouse_enabled or t
       or S.state ~= "play"
  then
    return 
  end
  local p = S.player
  p.y = p.y + dy * MOUSE_SENSITIVITY
  clamp_paddle(p)
end

-- main step/update

function step_ball(b, dt)
  move_ball(b, dt)
  bounce_ball(b)
  collide(b, S.player, PADDLE_WIDTH)
  collide(b, S.opp, -BALL_SIZE)
end

function handle_score()
  local side = check_scored(S.ball.x)
  if side then
    scored(side)
    reset_ball()
    return true
  end
  return false
end

function step_game(dt)
  if S.state ~= "play" then
    return 
  end
  local sdt = dt * SPEED_SCALE
  update_player(sdt)
  S.strategy.fn(S, sdt)
  step_ball(S.ball, sdt)
  handle_score()
end

function update_fixed(rdt)
  acc = acc + rdt
  local steps = 0
  while FIXED_DT <= acc and steps < MAX_STEPS do
    step_game(FIXED_DT)
    acc = acc - FIXED_DT
    steps = steps + 1
  end
end

function love.update(dt)
  ensure_init()
  local now = love.timer.getTime()
  local rdt = now - time_t
  time_t = now
  if USE_FIXED then
    update_fixed(rdt)
  else
    step_game(rdt)
  end
end

-- drawing

function draw_bg()
  gfx.clear(COLOR_BG)
  gfx.setColor(COLOR_FG)
end

function draw_paddle(p)
  gfx.rectangle("fill", p.x, p.y, PADDLE_WIDTH, PADDLE_HEIGHT)
end

function draw_ball(b)
  gfx.rectangle("fill", b.x, b.y, BALL_SIZE, BALL_SIZE)
end

function draw_scores()
  gfx.draw(texts.score_l, VIRTUAL_W / 2 - 60, SCORE_OFFSET_Y)
  gfx.draw(texts.score_r, VIRTUAL_W / 2 + 40, SCORE_OFFSET_Y)
end

function draw_state_text(s)
  local t = texts[s]
  if t then
    gfx.draw(t, VIRTUAL_W / 2 - 40, VIRTUAL_H / 2 - 16)
  end
  if s == "start" and S.strategy.text then
    gfx.draw(S.strategy.text, VIRTUAL_W / 2 - 40, VIRTUAL_H / 2)
  end
end

function love.draw()
  draw_bg()
  gfx.push()
  gfx.applyTransform(view_tf)
  gfx.draw(center_canvas)
  draw_paddle(S.player)
  draw_paddle(S.opp)
  draw_ball(S.ball)
  draw_scores()
  draw_state_text(S.state)
  gfx.pop()
end

function love.resize(w, h)
  update_view_transform(w, h)
  build_center_canvas()
end
