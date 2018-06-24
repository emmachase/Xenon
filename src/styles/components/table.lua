local tableComponent = {}

local function makeTextEl(content, parent)
  return {
    type = "text",
    content = (parent.properties.prepend or "")
              .. content ..
              (parent.properties.append or ""),
    parent = parent
  }
end

local function addClass(node, class)
  local prop = node.properties
  local cc = prop.class or ""

  if #cc > 0 then
    local stM, enM = cc:find(class)
    if (not stM) or cc:sub(stM - 1, enM + 1):match("%S+") ~= class then
      prop.class = cc .. " " .. class
    end
  else
    prop.class = class
  end
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
  foreach(th, tel) do
    th.adapter = renderer.components.text.new(th)
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
  foreach(row, rows) do
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
      if row.styles["line-height"] and not td.styles["line-height"] then
        td.styles["line-height"] = row.styles["line-height"]
      end

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

      maxH = math.max(maxH, height)

      flowX = flowX + width
    end

    if row.styles["background-color"] then
      local c = resolver({}, "color", row.styles["background-color"])
      if c > 0 then
        surf:fillRect(position.left, flowY, position.width, maxH, c)
      end
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
      local cOrder1 = transformedItems[str1].order
      local cOrder2 = transformedItems[str2].order

      if (cOrder1 or cOrder2) and (cOrder1 ~= cOrder2) then
        return (cOrder1 or math.huge) < (cOrder2 or math.huge)
      end

      str1 = transformedItems[str1].disp
      str2 = transformedItems[str2].disp

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
      local k = sortedList[sI]
      local v = tostring(data[sortedList[sI]])

      local skeleton = util.deepClone(self.rowTemplate)
      skeleton.parent = body

      local tel = self.renderer.querySelector("td", skeleton)
      foreach(td, tel) do
        td.adapter = self.renderer.components.text.new(td)
      end

      local stock = self.renderer.querySelector("#stock", skeleton)[1]
      local name = self.renderer.querySelector("#name", skeleton)[1]
      local price = self.renderer.querySelector("#price", skeleton)[1]
      local pricePerStack = self.renderer.querySelector("#price-per-stack", skeleton)[1]
      local addy = self.renderer.querySelector("#addy", skeleton)[1]
      local addyFull = self.renderer.querySelector("#addy-full", skeleton)[1]

      if stock then
        stock.children = { makeTextEl(v, stock) }
        addClass(stock, "stock")

        v = tonumber(v)
        if v < (transformedItems[k].critical or config.criticalStock or 10) then
          addClass(stock, "critical")
        elseif v < (transformedItems[k].low or config.lowStock or 50) then
          addClass(stock, "low")
        end
      end

      if name then
        name.children = { makeTextEl(transformedItems[k].disp or k, name) }
        addClass(name, "name")
      end

      if price then
        price.children = { makeTextEl(transformedItems[k].price, price) }
        addClass(price, "price")
      end

      if pricePerStack then
        pricePerStack.children = { makeTextEl(util.round(60 / transformedItems[k].price, 2), pricePerStack) }
        addClass(pricePerStack, "price-per-stack")
      end

      if addy then
        addy.children = { makeTextEl(transformedItems[k].addy, addy) }
        addClass(addy, "addy")
      end

      if addyFull then
        addyFull.children = { makeTextEl(transformedItems[k].addy .. "@" .. config.name .. ".kst", addyFull) }
        addClass(addyFull, "addy-full")
      end

      newChildren[#newChildren + 1] = skeleton
    end

    body.children = newChildren
  end

  self.renderer.processStyles()
end

return tableComponent