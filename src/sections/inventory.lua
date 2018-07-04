--== Various Helper Functions ==--

local function anyFree()
  local c = 0
  for i = 1, 16 do
    c = c + turtle.getItemSpace(i)
  end

  return c > 0
end

--== Inventory Management Functions ==--

local drawRefresh

local list  -- Item count list
local slotList  -- Keep track of which slots (in chests) items are located
local hasPredCache  -- Keep track of which items have predicates
local function countItems()
  local hasDrawnRefresh = false

  local lastList = slotList

  list = {}
  hasPredCache = {}
  slotList = {}

  -- Perform some initial transformations on the data
  foreach(item, config.items)
  do
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

          -- First see if we can match the predicate without making expensive meta calls
          for chkPredicateID = 1, #predicateCache do
            if util.matchPredicate(predicateCache[chkPredicateID], v) then
              predicateID = chkPredicateID
              break
            end
          end

          -- Check detailed metadata
          if predicateID == 0 then
            -- This may take a while, so make sure to alert potential customers while shop is unavaliable
            -- TODO: ^^^^^ but only when sleep is required

            local cachedMeta = chestPeriph.getItemMeta(k)
            for chkPredicateID = 1, #predicateCache do
              if util.matchPredicate(predicateCache[chkPredicateID], cachedMeta) then
                predicateID = chkPredicateID
                break
              end
            end
          end
        end

        local lName = util.toListName(v.name, v.damage, predicateID)

        if transformedItems[lName] then
          if not list[lName] then
            list[lName] = v.count
            slotList[lName] = {{k, v.count, ck}}
          else
            list[lName] = list[lName] + v.count
            slotList[lName][#slotList[lName] + 1] = {k, v.count, ck}
          end
        end
      end
    end
  end

  if not util.equals(lastList, slotList) then
    local els = renderer.querySelector("table.stock-table")
    for i = 1, #els do
      els[i].adapter:updateData(list)
    end

    repaintMonitor()
  end
end

local function dispense(mcname, count)
  while count > 0 do
    -- We don't need to check for item availability here because
    -- we already did that in processPayment()

    for i = #slotList[mcname], 1, -1 do
      local chestPeriph = chestPeriphs[slotList[mcname][i][3]]
      local targetChest = (config.outChest or config.self)
      if not (config.outChest and targetChest == config.outChest) then
        local amountPushed = chestPeriph.pushItems(targetChest, slotList[mcname][i][1], count)
      else
        local amountPushed = 0
      end

      count = count - amountPushed

      if count <= 0 then
        break
      end

      if not anyFree() and not config.outChest then
        for j = 1, 16 do
          if turtle.getItemCount(j) > 0 then
            turtle.select(i)
            turtle.drop()
          end
        end
      end
    end
  end

  if config.outChest then
    local toBeDispensed = count
    for k, v in pairs(outChest.list()) do
      if toBeDispensed <= 0 then
        break
      end
      if v.name == mcname then
        toBeDispensed = toBeDispensed - outChest.drop(k, math.min(v.count, toBeDispensed), config.outChestDir or "up")
      end
    end
  else
    for i = 1, 16 do
      if turtle.getItemCount(i) > 0 then
        turtle.select(i)
        turtle.drop()
      end
    end
  end

  countItems()
end

local function findItem(name)
  for k, item in pairs(config.items) do
    if item.addy == name then
      return item, util.toListName(item.modid, item.damage or 0, item.predicateID or 0)
    end
  end

  return false
end
