
local transformedItems = {}

local predicateCache = {}
local predicateIDCounter = 0
print("lesgo")
print(tostring(config.items))
print(tostring(#config.items))
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
      predicateCache[predicateID] = item.predicate
    end
  end

  print("yo?")
  transformedItems[util.toListName(item.modid, item.damage or 0, item.predicateID or 0)] = item
end
