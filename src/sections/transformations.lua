
local transformedItems = {}

local predicateCache = {}
local predicateIDCounter = 0
foreach(item, config.items) do
  if item.predicate then
    for predicateID = 1, #predicateCache do
      local predicate = predicateCache[predicateID]
      if util.equals(predicate, item.predicate) then
        item.predicateID = predicateID
      end
    end

    if not item.predicateID then
      predicateIDCounter = predicateIDCounter + 1

      item.predicateID = predicateIDCounter
      predicateCache[predicateIDCounter] = item.predicate
    end
  end

  transformedItems[util.toListName(item.modid, item.predicateID or 0)] = item
end
