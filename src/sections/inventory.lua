--== Various Helper Functions ==--

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
local hasPredCache -- Keep track of which items have predicates
local function countItems()
  list = {}
  hasPredCache = {}
  slotList = {}

  -- Perform some initial transformations on the data
  foreach(item, config.items) do
    local bName = util.toListName(item.modid, item.damage or 0, 0)
    if not hasPredCache[bName] then
      hasPredCache[bName] = item.predicateID ~= nil
    end

    if config.showBlanks then
      local lName = util.toListName(item.modid, item.damage or 0, item.predicateID or 0)
      list[lName] = 0
      slotList[lName] = {}
    end
  end
  
  -- Iterate over all known chests
  for ck = 1, #chestPeriphs do
    local chestPeriph = chestPeriphs[ck]
    local cTable = chestPeriph.list()
    if not cTable then
      logger.error("Unable to list chest '" .. ck .. "'")
    else
      for k, v in pairs(cTable) do -- For each item..
        local bName = util.toListName(v.name, v.damage, 0) -- Simplified name to check if deep predicate matching is required
        
        local predicateID = 0
        if hasPredCache[bName] then
          -- This item has known predicates, find which one
          for predicateID = 1, #predicateCache do
            -- TODO transform v with getItemMeta if initial match fails
            if util.matchPredicate(predicateCache[predicateID], v) then
              predicateID = predicateID
            end
          end
        end


        local lName = util.toListName(v.name, v.damage, predicateID)

        if transformedItems[lName] then
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
  end

  local els = renderer.querySelector("table.stock-table")
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
      return item, util.toListName(k, item.damage or 0)
    end
  end

  return false
end
