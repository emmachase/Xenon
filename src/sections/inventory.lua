--== Various Helper Functions ==--

local function toListName(name, damage)
  return name .. "::" .. damage
end

local function fromListName(lName)
  return lName:match("(.+)%:%:")
end

local function anyFree()
  local c = 0
  for i = 1, 16 do
    c = c + turtle.getItemSpace(i)
  end

  return c > 0
end

--== Inventory Management Functions ==--

local list -- Item count list
local slotList -- Keep track of which slots (in chests) items are located
local function countItems()
  list = {}
  slotList = {}

  if config.showBlanks then
    for k, v in pairs(config.items) do
      local lName = toListName(k, v.damage or 0)
      list[lName] = 0
      slotList[lName] = {}
    end
  end

  for ck = 1, #chestPeriphs do
    local chestPeriph = chestPeriphs[ck]
    local cTable = chestPeriph.list()
    if not cTable then
      logger.error("Unable to list chest '" .. ck .. "'")
    else
      for k, v in pairs(cTable) do
        local lName = toListName(v.name, v.damage)

        if not list[lName] then
          list[lName] = v.count
          slotList[lName] = { { k, v.count, ck } }
        else
          list[lName] = list[lName] + v.count
          slotList[lName][#slotList[lName] + 1] = { k, v.count, ck }
        end
      end
    end
  end

  local rm = {}
  for k, _ in pairs(list) do
    if not config.items[fromListName(k)] then
      rm[#rm + 1] = k
    end
  end

  for i = 1, #rm do
    list[rm[i]] = nil
  end

  local els = renderer.querySelector("table")
  for i = 1, #els do
    els[i].adapter:updateData(list)
  end

  repaintMonitor()
end

local function dispense(mcname, count)
  while count > 0 do
    -- We don't need to check for item availability here because
    -- we already did that in processPayment()

    for i = #slotList[mcname], 1, -1 do
      local chestPeriph = chestPeriphs[slotList[mcname][i][3]]
      local amountPushed = chestPeriph.pushItems(config.self, slotList[mcname][i][1], count)

      count = count - amountPushed

      if count <= 0 then
        break
      end

      if not anyFree() then
        for j = 1, 16 do
          if turtle.getItemCount(j) > 0 then
            turtle.select(i)
            turtle.drop()
          end
        end
      end
    end
  end

  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.drop()
    end
  end

  countItems()
end

local function findItem(name)
  for k, item in pairs(config.items) do
    if item.addy == name then
      return item, toListName(k, item.damage or 0)
    end
  end

  return false
end
