local class = require('util.class')

--- @param model Search
--- @param uic UserInputController
local function new(model, uic)
  local self = {
    model = model,
    input = uic,
  }
  return self
end

--- @class SearchController
--- @field model Search
--- @field input UserInputController
SearchController = class.create(new)

--- @param v SearchView
function SearchController:init_view(v)
  self.view = v
  self.input:init_view(self.view.input)
end

--- @param items table[]
function SearchController:load(items)
  self.model:load(items)
  self.input:update_view()
end

--- @return ResultsDTO
function SearchController:get_results()
  local res = self.model:get_results()
  return {
    results = res,
    selection = self.model:get_selection(true),
  }
end

--- @return InputDTO
function SearchController:get_input()
  return self.input:get_input()
end

function SearchController:clear()
  self.model.input:clear_input()
  self.model:clear()
end

function SearchController:update_results()
  local kws = self.input:get_text()[1]
  self.model:narrow(kws)
end

---------------------------
---  keyboard handlers  ---
---------------------------

--- @private
--- @param dir VerticalDir
--- @param by integer?
--- @param warp boolean?
function SearchController:_move_sel(dir, by, warp)
  local m = self.model:move_selection(dir, by, warp)
  if m then
    self.model:follow_selection()
  end
end

--- @private
--- @param dir VerticalDir
--- @param warp boolean?
--- @param by integer?
function SearchController:_scroll(dir, warp, by)
  self.model:scroll(dir, by, warp)
  self.input:update_view()
  -- self:update_status() -- TODO: show more arrows
end

--- @param k string
--- @return table? jump
function SearchController:keypressed(k)
  self.input:update_view()
  local function navigate()
    -- move selection
    if k == "up" then
      self:_move_sel('up')
    end
    if k == "down" then
      self:_move_sel('down')
    end
    if k == "home" then
      self:_move_sel('up', nil, true)
    end
    if k == "end" then
      self:_move_sel('down', nil, true)
    end

    -- scroll
    if not Key.shift()
        and k == "pageup" then
      self:_scroll('up', Key.ctrl())
    end
    if not Key.shift()
        and k == "pagedown" then
      self:_scroll('down', Key.ctrl())
    end
    if Key.shift()
        and k == "pageup" then
      self:_scroll('up', false, 1)
    end
    if Key.shift()
        and k == "pagedown" then
      self:_scroll('down', false, 1)
    end
  end
  local function removers()
    local input = self.model.input
    if k == "backspace" then
      input:backspace()
      self:update_results()
    end
    if k == "delete" then
      input:delete()
      self:update_results()
    end
  end

  navigate()
  removers()

  if Key.is_enter(k) then
    --- no linebreaks in search
    if Key.shift() or Key.ctrl() then return end
    local sel = self.model.selection
    local r = self.model.resultset[sel].r
    self.input:update_view()
    return r
  end
  self.input:update_view()
end

--- @param t string
function SearchController:textinput(t)
  self.input:update_view()
  self.input:add_text(t)
  self:update_results()
end
