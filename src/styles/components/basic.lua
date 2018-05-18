local basicTextComponent = {}

function basicTextComponent.new(node)
  return setmetatable({node = node}, { __index = basicTextComponent })
end

function basicTextComponent:render(surf, position, styles, resolver)
  if styles["background-color"] then
    local c = resolver({}, "color", styles["background-color"])
    if c > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, c)
    end
  end

  local pads = {}
  for pad in (styles.padding or "0"):gmatch("%S+") do
    pads[#pads + 1] = pad
  end

  local topPad    = resolver({}, "number", pads[1])
  local rightPad  = resolver({}, "number", pads[2] or pads[1])
  --  local bottomPad = resolver({}, "number", pads[3] or pads[1])
  local leftPad   = resolver({}, "number", pads[4] or pads[2] or pads[1])

  local cY = position.top + topPad

  if styles.content then
    util.wrappedWrite(surf, resolver({}, "string", styles.content),
      position.left + leftPad, cY, position.width - leftPad - rightPad,
      resolver({}, "color", styles.color), styles["text-align"] or "left")
  else
    local children = self.node.children
    local acc = ""
    for i = 1, #children do
      if children[i].type == "text" then
        acc = acc .. children[i].content
      elseif children[i].name == "br" then
        cY = util.wrappedWrite(surf, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad,
          resolver({}, "color", styles.color), styles["text-align"] or "left")
        acc = ""
        cY = cY + 1
      elseif children[i].name == "span" then
--        cY = util.wrappedWrite(surf, children[i].children[1].content or "",
--          position.left + leftPad, cY, position.width - leftPad - rightPad,
--          resolver({}, "color", styles.color), styles["text-align"] or "left")
        acc = acc .. children[i].children[1].content
      end
    end
    if #acc > 0 then
      util.wrappedWrite(surf, acc,
        position.left + leftPad, cY, position.width - leftPad - rightPad,
        resolver({}, "color", styles.color), styles["text-align"] or "left")
    end
  end
end

function basicTextComponent:resolveHeight(styles, context, resolver)
  local pads = {}
  for pad in (styles.padding or "0"):gmatch("%S+") do
    pads[#pads + 1] = pad
  end

  local topPad    = resolver({}, "number", pads[1])
  local rightPad  = resolver({}, "number", pads[2] or pads[1])
  local bottomPad = resolver({}, "number", pads[3] or pads[1])
  local leftPad   = resolver({}, "number", pads[4] or pads[2] or pads[1])

  local cY = 0

  -- TODO LINE HEIGHT

  if styles.content then
    cY = util.wrappedWrite(nil, resolver({}, "string", styles.content),
      0, cY, context.width - leftPad - rightPad, nil, styles["text-align"] or "left")
  else
    local children = self.node.children
    for i = 1, #children do
      if children[i].type == "text" then
        cY = util.wrappedWrite(nil, children[i].content or "",
          0, cY, context.width - leftPad - rightPad, nil, styles["text-align"] or "left")
      elseif children[i].name == "br" then
        cY = cY + 1
      end
    end
  end

  return (topPad + bottomPad + (styles["line-height"] or 1) * cY) .. "px"
end

return basicTextComponent
