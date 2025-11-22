TitleView = {
  draw = function(title, x, y, w, custom_font)
    title = title or "LÖVEputer"
    local prev_font = gfx.getFont()
    local font = custom_font or prev_font
    local fh = font:getHeight()
    x = x or 0
    y = y or gfx.getHeight() - 2 * fh
    w = w or gfx.getWidth()
    gfx.setColor(Color[0])
    gfx.rectangle("fill", x, y, w, fh)
    local i = 1
    local c = { 13, 12, 14, 10 }
    for lx = w - fh, w - 4 * fh, -fh do
      gfx.setColor(Color[c[i]])
      i = i + 1
      gfx.polygon("fill",
        lx,
        y,
        lx - fh,
        y,
        lx - 2 * fh,
        y + fh,
        lx - fh,
        y + fh)
    end
    gfx.setColor(Color[15])

    if custom_font then
      gfx.setFont(font)
    end
    gfx.print(title, x + fh, y)
    if custom_font then
      gfx.setFont(prev_font)
    end
  end
}
