local util = {}

function util.wrappedWrite(surf, text, x, y, width, color)
  local stX = x
  for word in text:gmatch("%S+") do
    if x + #word > stX + width then
      x = stX
      y = y + 1
    end

--    local col = colors.white
--    if word:upper() == word then
--      col = colors.red
--    end
    if surf then
      surf:drawString(word, x, y, nil, color)
    end
    x = x + #word + 1
  end

  return y + 1
end

return util