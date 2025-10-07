local examples = {}

function example(c, l)
  table.insert(examples, {
    code = c,
    legend = l
  })
end

example(
  "return b2n(math.random() < 0.1)",
  "for every dot return 0 or 1 \nto change the visibility"
)
example(
  "return math.random()",
  "use a float between 0 and 1 \nto define the size"
)
example(
  "return math.sin(t)",
  "parameter `t` is \nthe time in seconds"
)
example(
  "return i / 256",
  "param `i` is the index \nof the dot (0..255)"
)
example(
  "return x / count",
  "`x` is the column index\n from 0 to 15"
)
example("return y / count", "`y` is the row\n also from 0 to 15")
example(
  "return y - 7.5",
  "positive numbers are white,\nnegatives are red"
)
example("return y - t", "use the time\nto animate values")
example(
  "return y - 4 * t",
  "multiply the time\nto change the speed"
)
example(
  "return ({1, 0, -1})[i % 3 + 1]",
  "create patterns using \ndifferent color"
)
example(
  "return sin(t - sqrt((x - 7.5)^2 + (y-6)^2) )",
  "skip `math.` to use methods \nand props like `sin` or `pi`"
)
example("return sin(y/8 + t)", "more examples ...")
example("return y - x", "simple triangle")
example(
  "return b2n( (y > x) and (14 - x < y) )",
  "quarter triangle"
)
example("return i % 4 - y % 4", "pattern")
example(
  "return b2n(n2b(math.fmod(x, 4)) and n2b(math.fmod(y, 4)))",
  "grid"
)
example("return b2n( x>3 and y>3 and x<12 and y<12 )", "square")
example(
  "return -1 * b2n( x>t and y>t and x<15-t and y<15-t )",
  "animated square"
)
example("return (y-6) * (x-6)", "mondrian squares")
example(
  "return floor(y - 4 * t) * floor(x - 2 - t)",
  "moving cross"
)
example("return band(4 * t, i, x, y)", "sierpinski")
example(
  "return y == 8 and band(t * 10, lshift(1, x)) or 0",
  "binary clock"
)
example("return random() * 2 - 1", "random noise")
example("return sin(i ^ 2)", "static smooth noise")
example("return cos(t + i + x * y)", "animated smooth noise")
example("return sin(x/2) - sin(x-t) - y+6", "waves")
example(
  "return (x-8) * (y-8) - sin(t) * 64",
  "bloop bloop bloop"
)
example(
  "return -.4 / (hypot(x - t%10, y - t%8) - t%2 * 9)",
  "fireworks"
)
example("return sin(t - hypot(x, y))", "ripples")
example(
  "return band( ({5463,2194,2386})[ band(y+t*9, 7) ]" ..
  " or 0, lshift(1, x - 1) )", "scrolling TIXY")
example("return (x-y) - sin(t) * 16", "wipe")
example("return (x-y)/24 - sin(t)", "soft wipe")
example("return sin(t*5) * tan(t*7)", "disco")
example(
  "return (x-(count/2))^2 + (y-(count/2))^2 - 15*cos(pi/4)",
  "日本"
)
example(
  "return (x-5)^2 + (y-5)^2 - 99*sin(t)",
  "create your own!"
)

return examples
