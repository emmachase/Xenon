local tableComponent = {}

function tableComponent.new(node)
  return setmetatable({node = node}, { __index = tableComponent })
end

function tableComponent:render(surf, position, styles, resolver)
  if styles["background-color"] then
    local c = resolver({}, "color", styles["background-color"])
    if c > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, c)
    end
  end

  surf:drawString("Table", position.left, position.top)
  local estr = "TableE"
  surf:drawString(estr, position.left + position.width - #estr, position.top + position.height - 1)

--  for i = 1, term.getSize() do
--    surf:drawPixel(i - 1, ({term.getSize()})[2] - 1, 2^(i % 2 + 6))
--  end
end

return tableComponent