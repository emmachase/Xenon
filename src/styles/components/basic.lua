local basicTextComponent = {}

local function calcWidth(text)
  if #text == 0 then return 0 end

  local w = -1
  for i = 1, #text do
    w = w + font.widths[string.byte(text:sub(i, i)) - 31] + 1
  end

  return w
end

local function calcSizeBig(text)
  return math.ceil(calcWidth(text) / 2) * 2, math.ceil(font.height / 3) * 3
end

local function writeBig(surf, text, x, y, col, bg, align, width)
  local sw, sh = calcSizeBig(text)
  local tempSurf = surface.create(sw, sh, bg)

  tempSurf:drawText(text, font, 0, 0, col, bg, bg)
  if align == "left" then
    surf:drawSurfaceSmall(tempSurf, x, y)
  elseif align == "center" then
    surf:drawSurfaceSmall(tempSurf, math.floor(x + (width - sw / 2) / 2), y)
  else
    surf:drawSurfaceSmall(tempSurf, width + x - sw / 2, y)
  end
end

local function transformText(text, styles)
  local style = styles["text-transform"]
  if style == "uppercase" then
    return text:upper()
  elseif style == "lowercase" then
    return text:lower()
  elseif style == "capitalize" then
    return text:gsub("%f[%a]%w", function(c) return c:upper() end)
  end

  return text
end

function basicTextComponent.new(node)
  return setmetatable({ node = node }, { __index = basicTextComponent })
end

function basicTextComponent:render(surf, position, styles, resolver)
  local bgc
  if styles["background-color"] then
    bgc = resolver({}, "color", styles["background-color"])
    if bgc > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, bgc)
    end
  end

  local topPad,
        rightPad,
        _, -- bottomPad is unused
        leftPad = util.parseOrdinalStyle(resolver, styles, "padding")

  local lineHeight = 1
  if styles["line-height"] then
    lineHeight = resolver({}, "number", styles["line-height"])
  end

  local cY = position.top + topPad

  if styles["background"] then
    local path = styles["background"]:match("url(%b())"):sub(2, -2)
    local img = surface.load(path)

    local mw, mh = math.ceil(img.width / 2) * 2, math.ceil(img.height / 3) * 3
    if img.width ~= mw or img.height ~= mh then
      if bgc <= 0 then
        -- Gotta guess
        bgc = 0
      end

      local temp = surface.create(mw, mh, bgc)
      temp:drawSurface(img, 0, 0)

      img = temp
    end

    local pos = styles["background-position"] or "center"

    if pos == "left" then
      surf:drawSurfaceSmall(img, position.left + leftPad, cY)
    elseif pos == "right" then
      surf:drawSurfaceSmall(img, position.left + position.width - rightPad - img.width / 2, cY)
    elseif pos == "center" then
      surf:drawSurfaceSmall(img, position.left + math.floor((position.width - rightPad - img.width / 2) / 2), cY)
    end
  elseif styles.content then
    local text = resolver({}, "string", styles.content)
    text = transformText(text, styles)

    if styles["font-size"] == "2em" then
      if bgc <= 0 then
        error("'font-size: 2em' requires 'background-color' to be present")
      end

      writeBig(surf, text,
        position.left + leftPad, cY,
        resolver({}, "color", styles.color), bgc,
        styles["text-align"] or "left", position.width - leftPad - rightPad)
    else
      util.wrappedWrite(surf, text,
        position.left + leftPad, cY, position.width - leftPad - rightPad,
        resolver({}, "color", styles.color), styles["text-align"] or "left", lineHeight)
    end
  else
    if styles["font-size"] == "2em" then
      if bgc <= 0 then
        error("'font-size: 2em' requires 'background-color' to be present")
      end

      -- TODO Wrapping support?
      local text = self.node.children[1].content or ""
      text = transformText(text, styles)
      writeBig(surf, text,
        position.left + leftPad, cY,
        resolver({}, "color", styles.color), bgc,
        styles["text-align"] or "left", position.width - leftPad - rightPad)
    else
      local children = self.node.children
      local acc = ""

      foreach(child, children) do
        if child.type == "text" then
          acc = acc .. child.content
        elseif child.name == "br" then
          acc = transformText(acc, styles)

          cY = util.wrappedWrite(surf, acc,
            position.left + leftPad, cY, position.width - leftPad - rightPad,
            resolver({}, "color", styles.color), styles["text-align"] or "left", lineHeight)
          acc = ""
        elseif child.name == "span" then
          acc = acc .. child.children[1].content
        end
      end
      if #acc > 0 then
        acc = transformText(acc, styles)

        util.wrappedWrite(surf, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad,
          resolver({}, "color", styles.color), styles["text-align"] or "left", lineHeight)
      end
    end
  end
end

function basicTextComponent:resolveHeight(styles, context, resolver)
  local topPad,
        rightPad,
        bottomPad,
        leftPad = util.parseOrdinalStyle(resolver, styles, "padding")

  local cY = 0

  if styles["background"] then
    local path = styles["background"]:match("url(%b())"):sub(2, -2)
    local img = surface.load(path)

    cY = math.ceil(img.height / 3)
  elseif styles["font-size"] == "2em" then
    cY = math.ceil(font.height / 3)
  elseif styles.content then
    cY = util.wrappedWrite(nil, resolver({}, "string", styles.content),
      0, cY, context.width - leftPad - rightPad)
  else
    local children = self.node.children
    local acc = ""
    foreach(child, children) do
      if child.type == "text" then
        acc = acc .. child.content
      elseif child.name == "br" then
        cY = util.wrappedWrite(nil, acc,
          position.left + leftPad, cY, position.width - leftPad - rightPad)
        acc = ""
        cY = cY + 1
      elseif child.name == "span" then
        acc = acc .. child.children[1].content
      end
    end
    cY = cY + 1
  end

  if styles["line-height"] then
    cY = cY * resolver({}, "number", styles["line-height"])
  end

  return (topPad + bottomPad + cY) .. "px"
end

return basicTextComponent
