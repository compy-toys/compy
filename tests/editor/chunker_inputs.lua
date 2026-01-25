require('model.editor.content')

--- @param s str
--- @param r Block[]
local prep = function(s, r)
  return {
    string.lines(s),
    r
  }
end

local sierp_code = [[function sierpinski(depth)
  lines = { '*' }
  for c = 2, depth + 1 do
    sp = string.rep(' ', 2 ^ (c - 2))
    tmp = {} -- comment
    for idx, line in ipairs(lines) do
      tmp[idx] = sp .. line .. sp
      tmp[idx + #lines] = line .. ' ' .. line
    end
    lines = tmp
  end
  return table.concat(lines, '\n')
end

print(sierpinski(4))]]
local sierp_code_2 = [[function sierpinski(depth)
  lines = { '*' }
  for c = 2, depth + 1 do
    sp = string.rep(' ', 2 ^ (c - 2))
    tmp = {} -- comment
    for idx, line in ipairs(lines) do
      tmp[idx] = sp .. line .. sp
      tmp[idx + #lines] = line .. ' ' .. line
    end
    lines = tmp
  end
  return table.concat(lines, '\n')
end


print(sierpinski(4))]]
local sierp_res = {
  Chunk(string.lines([[function sierpinski(depth)
  lines = { '*' }
  for c = 2, depth + 1 do
    sp = string.rep(' ', 2 ^ (c - 2))
    tmp = {} -- comment
    for idx, line in ipairs(lines) do
      tmp[idx] = sp .. line .. sp
      tmp[idx + #lines] = line .. ' ' .. line
    end
    lines = tmp
  end
  return table.concat(lines, '\n')
end]]), Range(1, 13)),
  Empty(14),
  Chunk({ 'print(sierpinski(4))' }, Range.singleton(15)),
  Empty(16)
}

local chonk_1 = Chunk({
    'function chonky()',
    '  return {"big", "chungus"}',
    'end'
  },
  Range(1, 3)
)
local chonk_res = {
  chonk_1,
  Empty(4),
  Chunk({ 'print(string.unlines(chonky()))' },
    Range.singleton(5)),
  Empty(6),
}

return {
  prep(
    "local x = 1",
    { Chunk({ 'local x = 1' }, Range.singleton(1)),
      Empty(2) }
  ),
  prep({ '' }, { Empty(1) }),
  prep({ '', '' }, { Empty(1) }),
  prep({ '   ', '' }, { Empty(1) }),

  prep(
    "\nlocal x = 1",
    { Empty(1),
      Chunk({ 'local x = 1' }, Range.singleton(2)),
      Empty(3) }
  ),
  prep(
    "local x = 1\n",
    { Chunk({ 'local x = 1' }, Range.singleton(1)),
      Empty(2) }
  ),
  prep(
    "local x = 1\n\n\n\n",
    { Chunk({ 'local x = 1' }, Range.singleton(1)),
      Empty(2) }
  ),
  prep(
    "\nlocal x = 1\n",
    { Empty(1),
      Chunk({ 'local x = 1' }, Range.singleton(2)),
      Empty(3) }
  ),
  prep(
    "\n\n\nlocal x = 1\n\n\n",
    { Empty(1),
      Chunk({ 'local x = 1' }, Range.singleton(2)),
      Empty(3) }
  ),

  prep(sierp_code, sierp_res),
  prep(sierp_code_2, sierp_res),

  prep([[function chonky()
  return {"big", "chungus"}
end

print(string.unlines(chonky()))]], chonk_res),
  prep([[function chonky()
  return {"big", "chungus"}
end
print(string.unlines(chonky()))]],
    {
      chonk_1,
      Chunk({ 'print(string.unlines(chonky()))' },
        Range.singleton(4)),
      Empty(5),
    }
  ),

  --- here comes the fun
  prep([[function chonky()
  return {"big", "chungus"}
end


print(string.unlines(chonky()))]], chonk_res),

  prep([[function chonky()
  return {"big", "chungus"}
end


print(string.unlines(chonky()))
print(1)]], {
    chonk_1,
    Empty(4),
    Chunk({ 'print(string.unlines(chonky()))' },
      Range.singleton(5)),
    Chunk({ 'print(1)' },
      Range.singleton(6)),
    Empty(7),
  }),

  prep([[function chonky()
  return {"big", "chungus"}
end


print(string.unlines(chonky()))
print(1)

x = 1
y = 2]], {
    chonk_1,
    Empty(4),
    Chunk({ 'print(string.unlines(chonky()))' },
      Range.singleton(5)),
    Chunk({ 'print(1)' }, Range.singleton(6)),
    Empty(7),
    Chunk({ 'x = 1' }, Range.singleton(8)),
    Chunk({ 'y = 2' }, Range.singleton(9)),
    Empty(10),
  }),

  prep([[function chonky()
  return {"big", "chungus"}
end


print(string.unlines(chonky()))
print(1)

x = 1

y = 2]], {
    chonk_1,
    Empty(4),
    Chunk({ 'print(string.unlines(chonky()))' },
      Range.singleton(5)),
    Chunk({ 'print(1)' }, Range.singleton(6)),
    Empty(7),
    Chunk({ 'x = 1' }, Range.singleton(8)),
    Empty(9),
    Chunk({ 'y = 2' }, Range.singleton(10)),
    Empty(11),
  }),

  prep([[--- luadoc comment
function chonky()
  --- inline comment
  return {"big", "chungus"}
end]], {
    Chunk({ '--- luadoc comment' }, Range(1, 1)),
    Chunk({
        'function chonky()',
        '  --- inline comment',
        '  return {"big", "chungus"}',
        'end'
      },
      Range(2, 5)
    ),
    Empty(6),
  })

}
