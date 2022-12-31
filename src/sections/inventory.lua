--== Various Helper Functions ==--

local function anyFree()
  local c = 0
  for i = 1, 16 do
    c = c + turtle.getItemSpace(i)
  end

  return c > 0
end

local function getFreeSlot()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then
      return i
    end
  end
end

--== Inventory Management Functions ==--

local drawRefresh

local function processChest(chestPeriph, list, slotList, hasPredCache)
  local cTable = chestPeriph.list()
  if not cTable then
    logger.error("Unable to list chest '" .. chestPeriph .. "'")
  else
    for k, v in pairs(cTable) do -- For each item..
      local bName = util.toListName(v.name, 0) -- Simplified name to check if deep predicate matching is required

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

          local cachedMeta = chestPeriph.getItemDetail(k)
          for chkPredicateID = 1, #predicateCache do
            if util.matchPredicate(predicateCache[chkPredicateID], cachedMeta) then
              predicateID = chkPredicateID
              break
            end
          end
        end
      end


      local lName = util.toListName(v.name, predicateID)

      if transformedItems[lName] then
        if not list[lName] then
          list[lName] = v.count
          slotList[lName] = { { k, v.count, chestPeriph } }
        else
          list[lName] = list[lName] + v.count
          slotList[lName][#slotList[lName] + 1] = { k, v.count, chestPeriph }
        end
      end
    end
  end
end

local list -- Item count list
local slotList -- Keep track of which slots (in chests) items are located
local hasPredCache -- Keep track of which items have predicates
local function countItems()
  local hasDrawnRefresh = false
  
  local lastList = slotList

  list = {}
  hasPredCache = {}
  slotList = {}

  -- Perform some initial transformations on the data
  foreach(item, config.items) do
    local bName = util.toListName(item.modid, 0)
    if not hasPredCache[bName] then
      hasPredCache[bName] = item.predicateID ~= nil
    end

    if config.showBlanks then
      local lName = util.toListName(item.modid, item.predicateID or 0)
      list[lName] = 0
      slotList[lName] = {}
    end
  end
  
  -- Iterate over all known chests
  for ck = 1, #chestPeriphs do
    local chestPeriph = chestPeriphs[ck]
    processChest(chestPeriph, list, slotList, hasPredCache)
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
  local toMoveCount = count
  while toMoveCount > 0 do
    -- We don't need to check for item availability here because
    -- we already did that in processPayment()

    for i = #slotList[mcname], 1, -1 do
      local chestPeriph = slotList[mcname][i][3]
      local amountPushed = 0
      -- if config.outChest then
      --   local tempSlot = getFreeSlot()
      --   amountPushed = chestPeriph.pushItems(config.self, slotList[mcname][i][1], toMoveCount, tempSlot)
      --   outChest.pullItems(config.self, tempSlot)
      -- else
      amountPushed = chestPeriph.pushItems(chestToSelf[chestPeriph], slotList[mcname][i][1], toMoveCount)
      -- end

      toMoveCount = toMoveCount - amountPushed

      if toMoveCount <= 0 then
        break
      end

      if not anyFree() then -- and not config.outChest then
        for j = 1, 16 do
          if turtle.getItemCount(j) > 0 then
            turtle.select(j)
            turtle.drop()
          end
        end
      end
    end
  end

  -- if config.outChest then
  --   local toBeDispensed = count
  --   local iList, iSlotList = {}, {}
  --   processChest(outChest, iList, iSlotList, hasPredCache)
  --   for i = #iSlotList[mcname], 1, -1 do
  --     toBeDispensed = toBeDispensed -
  --       outChest.drop(
  --         iSlotList[mcname][i][1],
  --         math.min(iSlotList[mcname][i][2], toBeDispensed),
  --         config.outChestDir or "up")

  --     if toBeDispensed <= 0 then
  --       break
  --     end
  --   end
  -- else
  for i = 1, 16 do
    if turtle.getItemCount(i) > 0 then
      turtle.select(i)
      turtle.drop()
    end
  end
  -- end

  countItems()
end

local function findItem(name)
  for k, item in pairs(config.items) do
    if item.addy == name then
      return item, util.toListName(item.modid, item.predicateID or 0)
    end
  end

  return false
end
