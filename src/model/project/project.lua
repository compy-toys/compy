require("util.lua")
require("util.string.string")
local FS = require("util.filesystem")
local class = require('util.class')

local function error_annot(base)
  return function(err)
    local msg = base
    if err then
      msg = msg .. ': ' .. err
    end
    return msg
  end
end

local messages = {
  no_projects         = 'No projects available',
  list_header         = 'Projects:\n─────────',
  project_header      = function(name)
    local pl = 'Project ' .. name .. ':'
    return pl .. '\n' .. string.times('─', string.ulen(pl))
  end,
  file_header         = function(name, width)
    local w = width or 64
    local l = string.ulen(name) + 2
    local pad = string.times('─', math.floor((w - l) / 2))
    return string.format('%s %s %s', pad, name, pad)
  end,

  invalid_filename    = error_annot('Filename invalid'),
  already_exists      = function(name)
    local n = name or ''
    return 'A project already exists with this name: ' .. n
  end,
  write_error         = error_annot('Cannot write target directory'),
  pr_does_not_exist   = function(name)
    local n = name or ''
    return n .. ' is not an existing project'
  end,
  file_does_not_exist = function(name)
    local n = name or ''
    return n .. ' does not exist'
  end,
  no_open_project     = 'No project is open',
}

--- Determine if the supplied string is a valid filename
--- @param name string
--- @return boolean valid
--- @return string? error
local function validate_filename(name)
  if not string.is_non_empty_string(name) then
    return false, messages.invalid_filename('Empty')
  end
  if string.ulen(name) > 60 then
    return false, messages.invalid_filename('Too long')
  end
  if name:match('%.%.')
      or name:match('/')
  then
    return false, messages.invalid_filename('Forbidden characters')
  end
  return true
end

--- @class Project
--- @field name string
--- @field path string
--- @field play boolean
--- @field contents function
--- @field readfile function
--- @field writefile function
--- @field get_path function
Project = class.create(function(pname, play)
  local path = play and
      love.paths.play_path or
      FS.join_path(love.paths.project_path, pname)
  return {
    name = pname,
    path = path,
    play = play,
  }
end)

--- @return table
function Project:contents()
  return FS.dir(self.path)
end

--- @param name string
--- @return boolean success
--- @return string?|string result|errmsg
function Project:readfile(name)
  local fp
  if self.play then
    fp = FS.join_path(love.paths.play_path, name)
  else
    fp = FS.join_path(self.path, name)
  end

  if not FS.exists(fp, "file", self.play) then
    return false, messages.file_does_not_exist(name)
  else
    return true, FS.combined_read(fp)
  end
end

--- @return function? chunk
function Project:load_file(filename)
  local rok, content = self:readfile(filename)
  if rok then
    return codeload(content)
  end
end

--- @param get_env fun(): LuaEnv
--- @return function
function Project:get_loader(get_env)
  --- @param modname string
  --- @return unknown|string
  return function(modname)
    local fn = modname .. '.lua'
    local f = self:load_file(fn)
    Log.debug(string.format("%s loader, loading %s",
      self.name, modname))
    if f then
      setfenv(f, get_env())
      return assert(f)
    else
      return string.format(
        "\n\tno file %s (project loader)", fn)
    end
  end
end

--- @param name string
--- @param data string
--- @return boolean? success
--- @return string? error
function Project:writefile(name, data)
  local valid, err = validate_filename(name)
  if not valid then
    return false, err
  end
  local fp = FS.join_path(self.path, name)
  return FS.write(fp, data)
end

--- @param name string
--- @return string? path
function Project:get_path(name)
  return FS.join_path(self.path, name)
end

local newps = function()
  ProjectService.path = love.paths.project_path
  ProjectService.messages = messages
  return {
    --- @type Project?
    current = nil,
    play = false,
  }
end

--- @class ProjectService
--- @field path string
--- @field messages table
--- @field current Project
--- methods
--- @field validate_filename function
--- @field create function
--- @field list function
--- @field open function
--- @field close function
--- @field deploy_examples function
--- @field run function
ProjectService = class.create(newps)
ProjectService.MAIN = 'main.lua'
ProjectService.README = 'README.md'
ProjectService.messages = messages

--- @param name string
--- @return string? path
--- @return string? error
local function can_be_project(path, name)
  local ok, n_err = validate_filename(name)
  if not ok then
    return nil, n_err
  end
  local p_path = FS.join_path(path, name)
  if FS.exists(p_path) then
    return nil, messages.already_exists(name)
  end
  return p_path
end

--- @param path string
--- @param name string?
--- @param check_vfs boolean?
--- @return string? path
--- @return string? error
function ProjectService.is_project(path, name, check_vfs)
  local p_path = FS.join_path(path, name)
  local ex = FS.exists(p_path)
  if (not ex and not check_vfs) or
      (check_vfs and not FS.dir(p_path, "directory", true))
  then
    return nil, messages.pr_does_not_exist(name)
  end
  local main = FS.join_path(p_path, ProjectService.MAIN)
  if not FS.exists(main) and
      check_vfs and not FS.dir(main, "file", true)
  then
    return nil, messages.pr_does_not_exist(name)
  end
  return p_path, nil
end

--- @param name string
--- @return boolean success
--- @return string? error
function ProjectService:create(name)
  local p_path, err = can_be_project(ProjectService.path, name)
  if not p_path then
    return false, err
  end

  local dir_ok = FS.mkdir(p_path)
  if not dir_ok then
    return false, messages.write_error()
  end
  local main = FS.join_path(p_path, ProjectService.MAIN)
  local example = [[
print('Hello world!')
]]
  local ok, write_err = FS.write(main, example)
  if not ok then
    return false, write_err
  end
  local readme = FS.join_path(p_path, ProjectService.README)
  local r_text = '## ' .. name
  local rok, r_err = FS.write(readme, r_text)
  if not rok then
    return false, r_err
  end
  return true
end

--- @return table projects
function ProjectService:list()
  local folders = FS.dir(self.path)
  local ret = Dequeue()
  for _, f in pairs(folders) do
    if f.type and f.type == 'directory' then
      local ok = self.is_project(ProjectService.path, f.name)
      if ok then
        ret:push_back(Project(f.name))
      end
    end
  end
  return ret
end

--- @param name string?
--- @param play boolean?
--- @return boolean success
--- @return string? errmsg
function ProjectService:open(name, play)
  if play then
    self.current = Project('play', true)
    return true
  else
    local path, p_err = self.is_project(self.path, name)
    -- noop if already open
    if self.current == name then
      return true
    end
    if path then
      self.current = Project(name)
      return true
    end
    return false, p_err
  end
end

--- @param name string
--- @param play boolean
--- @return boolean open
--- @return boolean create
--- @return string? err
function ProjectService:opreate(name, play)
  if play then
    local ok = self:open('play', true)
    return ok, false
  else
    local ook, _ = self:open(name, false)
    if ook then
      return ook, false
    else
      local cok, c_err = self:create(name, false)
      if cok then
        self:open(name)
        return false, cok
      else
        return false, false, c_err
      end
    end
  end
end

--- @return boolean success
function ProjectService:close()
  self.current = nil
  return true
end

--- @return boolean success
--- @return string? error
function ProjectService:deploy_examples()
  local cp_ok = true
  local cp_err
  local ex_base = 'examples'
  local examples = FS.dir(ex_base, 'directory', true)
  if #examples == 0 then
    return false, 'No examples'
  end
  for _, i in ipairs(examples) do
    if i and i.type == 'directory' then
      local s_path = FS.join_path(ex_base, i.name)
      local t_path = FS.join_path(ProjectService.path, i.name)
      local ok, err = FS.cp_r(s_path, t_path, true)
      if not ok then
        Log.error(err)
        cp_ok = false
        cp_err = err
      else
        Log.trace('copied example ' .. i.name .. ' to ' .. t_path)
      end
    end
  end

  return cp_ok, cp_err
end

--- @param old string
--- @param new string
--- @return boolean success
--- @return string? error
function ProjectService:clone(old, new)
  local o_path, o_err =
      self.is_project(ProjectService.path, old)
  local n_path, n_err =
      can_be_project(ProjectService.path, new)
  if o_err or not o_path then
    return false, o_err
  end
  if n_err or not n_path then
    return false, n_err
  end

  local ok, err = FS.cp_r(o_path, n_path)
  if not ok then
    return false, err
  end
  return true
end

--- @param name string
--- @param env LuaEnv
--- @return function?
--- @return string? error
--- @return string? path
function ProjectService:run(name, env)
  local p_path, err
  if not name then
    if self.current then
      p_path = self.current.path
    else
      return nil, messages.no_open_project
    end
  else
    p_path, err = self.is_project(ProjectService.path, name)
  end
  if p_path then
    local _, code = self.current:readfile(ProjectService.MAIN)
    local content, c_err = codeload(code, env)
    return content, c_err, p_path
  end
  return nil, err
end
