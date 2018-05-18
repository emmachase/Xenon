local tableComponent = {}

local function toListName(name, damage)
  return name .. "::" .. damage
end

local function fromListName(lName)
  return lName:match("(.+)%:%:")
end

local function makeTextEl(content, parent)
  return {
    type = "text",
    content = content,
    parent = parent
  }
end

function tableComponent.new(node, renderer)
  local t = { node = node, renderer = renderer }

  local rtemp = renderer.querySelector("#row-template")
  if #rtemp > 0 then
    local row = rtemp[1]

    for i = 1, #row.parent.children do
      if row.parent.children[i] == row then
        row.parent.children[i] = nil
      end
    end

    row.properties.id = nil
    t.rowTemplate = row
  end

  local tel = renderer.querySelector("th", node)
  for i = 1, #tel do
    tel[i].adapter = renderer.components.text.new(tel[i])
  end

  return setmetatable(t, { __index = tableComponent })
end

function tableComponent:render(surf, position, styles, resolver)
  if styles["background-color"] then
    local c = resolver({}, "color", styles["background-color"])
    if c > 0 then
      surf:fillRect(position.left, position.top, position.width, position.height, c)
    end
  end

  local rows = self.renderer.querySelector("tr", self.node)

  local flowY = position.top
  for i = 1, #rows do
    local row = rows[i]

    local flowX = position.left
    local maxH = 0

    local flexTot = 0
    local remWidth = position.width
    local widths = {}

    for j = 1, #row.children do
      local td = row.children[j]

      if td.styles.width then
        local w = resolver({width = position.width, flowW = remWidth}, "width", td.styles.width)
        remWidth = remWidth - w
        widths[j] = w
      else
        flexTot = flexTot + (tonumber(td.styles.flex) or 1)
      end
    end

    for j = 1, #row.children do
      local td = row.children[j]

      local height = tonumber(td.adapter:resolveHeight(td.styles, { width = 10 }, resolver):sub(1, -3))

      local width
      if widths[j] then
        width = math.floor(widths[j])
      else
        width = math.floor(remWidth * ((tonumber(td.styles.flex) or 1) / flexTot))
      end

      td.adapter:render(surf, {
        left = flowX,
        top = flowY,
        width = width,
        height = height
      }, td.styles, resolver)

      maxH = height

      flowX = flowX + width
    end

    flowY = flowY + maxH
  end
end

function tableComponent:updateData(data)
  self.data = data

  -- New data so create and restyle it
  local body = self.renderer.querySelector("tbody", self.node)[1]
  if self.rowTemplate then
    local newChildren = {}

    local sortedList = {}
    for k, _ in pairs(data) do
      sortedList[#sortedList + 1] = k
    end

    table.sort(sortedList, function(str1, str2)
      str1 = config.items[fromListName(str1)].disp
      str2 = config.items[fromListName(str2)].disp

      local i = 0
      local c1, c2
      repeat
        i = i + 1
        c1 = str1:sub(i, i):lower()
        c2 = str2:sub(i, i):lower()
      until i == #str1 or i == #str2 or c1 ~= c2

      return c1:byte() < c2:byte()
    end)

    for sI = 1, #sortedList do
      local k = fromListName(sortedList[sI])
      local v = tostring(data[sortedList[sI]])

      local skeleton = util.deepClone(self.rowTemplate)
      local tel = self.renderer.querySelector("td", skeleton)
      print("tel: " .. #tel)
      for i = 1, #tel do
        tel[i].adapter = self.renderer.components.text.new(tel[i])
      end

      local stock = self.renderer.querySelector("#stock", skeleton)[1]
      local name = self.renderer.querySelector("#name", skeleton)[1]
      local price = self.renderer.querySelector("#price", skeleton)[1]
      local pricePerStack = self.renderer.querySelector("#price-per-stack", skeleton)[1]
      local addy = self.renderer.querySelector("#addy", skeleton)[1]

      if stock then
        print("made stock babies")
        stock.children = { makeTextEl(v, stock) }
      end

      if name then
        name.children = { makeTextEl(config.items[k].disp or k, name) }
      end

      if price then
        price.children = { makeTextEl(config.items[k].price, price) }
      end

      if pricePerStack then
        pricePerStack.children = { makeTextEl(util.round(60 / config.items[k].price, 2), pricePerStack) }
      end

      if addy then
        addy.children = { makeTextEl(config.items[k].addy, addy) }
      end

      newChildren[#newChildren + 1] = skeleton
    end

    body.children = newChildren
  end

  self.renderer.processStyles()
end

return tableComponent