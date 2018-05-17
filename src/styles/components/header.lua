local headerComponent = {}

function headerComponent.new(node)
  return setmetatable({node = node}, { __index = headerComponent })
end

function headerComponent:render(surf, position, styles, resolver)
  if styles["background-color"] then
    local c = resolver({}, "color", styles["background-color"])
    if c > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, c)
    end
  end

  surf:drawString("Header", position.left, position.top)
  local estr = "HeaderE"
  surf:drawString(estr, position.left + position.width - #estr, position.top + position.height - 1)
end

function headerComponent:resolveHeight(styles, context, resolver)
  return (resolver(context, "number", styles.padding) * 2 + 1) .. "px"
end

return headerComponent
