local class = require("util.class")

--- @class BGView : ViewBase
BGView = class.create(function(cfg)
  return { cfg = cfg }
end)

function BGView:draw(drawable_height)
  local cfg = self.cfg
  local w = cfg.w
  local fh = cfg.fh

  gfx.push('all')

  -- background in case input is not visible
  gfx.rectangle("fill",
    0,
    drawable_height - 2,
    w,
    fh * 2 + 2
  )
  gfx.pop()
end
