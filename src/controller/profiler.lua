if not love.profiler then
  Log.debug('profreq')
  love.profiler = require('lib.profile')
end

--- Run `f` if profiling is enabled
local guard = function(f)
  local pr = love.PROFILE
  if type(pr) ~= 'table' then return end

  return function()
    f()
  end
end

local start = function(oneshot)
  Log.debug('Starting profiler')
  love.PROFILE.running = true
  love.PROFILE.oneshot = oneshot

  love.profiler.start()
end

local stop = function()
  local pr = love.PROFILE
  if type(pr) ~= 'table' then return end
  Log.debug('Stopping profiling')
  love.PROFILE.running = false
  love.profiler.stop()
end

local update = function()
  local pr = love.PROFILE
  if pr.running then
    local n = pr.n_frames
    local r = pr.n_rows
    pr.frame = pr.frame + 1
    if pr.frame % n == 0 then
      local rep = love.profiler.report(r)
      Log.debug('Report:\n', rep)
      if not pr.reports then
        pr.reports = {}
      end
      table.insert(pr.reports, rep)
      if pr.oneshot then
        stop()
      end
    end
  end
end

local report = function()
  local r = table.clone(love.PROFILE.report)
  love.PROFILE.report = nil
  love.profiler.reset()
  return r
end

local p = {
  start_profiler = guard(start),
  start_oneshot = guard(function()
    start(true)
  end),
  stop_profiler = guard(stop),
  update = guard(update),
  report = guard(report),
}

return p
