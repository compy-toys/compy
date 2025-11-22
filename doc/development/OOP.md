## OOP

Even though lua is not an object oriented language per se, it
can approximate some OO behaviors with clever use of metatables.

See:

- [http://lua-users.org/wiki/ObjectOrientedProgramming][oo1]
- [http://lua-users.org/wiki/ObjectOrientationTutorial][oo2]

### Class factory

To automate this, a class factory utility was added.

First, import it:

```lua
local class = require('util.class')
```

Then it can be used in the following ways:

#### passing a constructor (record/dataclass pattern)

```lua
A = class.create(function()
  return { a = 'a' }
end
)
--- results in an instance with the preset values
local a = A()

B = class.create(function(x, y)
  return { x = x, y = y }
end)
--- results in a B instance where x = 1 and y = 2
local b = B(1, 2)
```

Note: in the codebase, the function is often not defined inline,
and very likely is named `new`, _however_ be careful not to
confuse it with the [`new` method][n]. If the function is not a
member of the class, it's this pattern.

##### late init

Sometimes it's useful to extract some behavior that's required
both on init but also later on-demand. An instance method is a
fine solution for this, but in order to invoke it, a full-blown
properly initialized instance is necessary, so it can't be done
in the constructor. Also, it would be nice to not have to do it
on each call site where an instance is created. Hence,
`lateinit`.

Let's say we have Text objects, storing text line-by-line, and
we want to know the average line length. This of course needs to
be calculated on first creation, and any time the text changes.

```lua
local function new(text)
  return {
    text = string.lines(text or '')
  }
end
local function lateinit(self)
  local n = #(self.text)
  if n ~= 0 then
    local lens = table.map(self.text, string.ulen)
    local l = 0
    for _, v in ipairs(lens) do
      l = l + v
    end
    self.avg_len = l / n
  else
    self.avg_len = 0
  end
end

--- @class Text
--- @field text string[]
--- @field avg_len number
Text = class.create(new, lateinit)
```

#### `new` method

For more advanced use cases, it will probably be necessary to
manually control the metatable setup, this is achieved by
defining the `new()` method on the class.

```lua
N = class.create()
N.new = function(cfg)
  local width = cfg.width or 10
  local height = cfg.height or 5
  local self = setmetatable({
    label = 'meta',
    width = width,
    height = height,
    area = width * height,
  }, N)

  return self
end

local n = N({width = 80, height = 25})
```

[oo1]: https://archive.vn/B3buW
[oo2]: https://archive.vn/muhJx
[n]: #new-method
