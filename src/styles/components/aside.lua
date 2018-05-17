local asideComponent = {}

function asideComponent.new(node)
  return setmetatable({node = node}, { __index = asideComponent })
end

function asideComponent:render(surf, position, styles, resolver)
  if styles["background-color"] then
    local c = resolver({}, "color", styles["background-color"])
    if c > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, c)
    end
  end

  surf:drawString("Aside", position.left, position.top)
  local estr = "AsideE"
  surf:drawString(estr, position.left + position.width - #estr, position.top + position.height - 1)
end

return asideComponent
