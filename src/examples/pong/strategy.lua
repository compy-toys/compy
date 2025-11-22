-- strategy.lua
-- opponent behavior module

strategy = { }

-- fast AI (hard)
function strategy.hard(S, dt)
  local c = S.opp.y + PADDLE_HEIGHT / 2
  local by = S.ball.y + BALL_SIZE / 2
  local d = by - c
  if math.abs(d) < AI_DEADZONE then
    S.opp.dy = 0
  else
    local dir = (0 < d) and 1 or -1
    move_paddle(S.opp, dir, dt)
  end
end

-- slow AI (easy)
function strategy.easy(S, dt)
  local c = S.opp.y + PADDLE_HEIGHT / 2
  local by = S.ball.y + BALL_SIZE / 2
  local d = by - c
  if math.abs(d) < AI_DEADZONE then
    S.opp.dy = 0
  else
    local dir = (0 < d) and 1 or -1
    move_paddle(S.opp, dir, dt * 0.6)
  end
end

-- Manual (second player)
function strategy.manual(S, dt)
  local dir = 0
  if love.keyboard.isDown("up") then
    dir = -1
  elseif love.keyboard.isDown("down") then
    dir = 1
  end
  move_paddle(S.opp, dir, dt)
end
