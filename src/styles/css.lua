-- CSS Parser

local function trim(str)
  return str:match("%s*(.+)"):reverse():match("%s*(.+)"):reverse()
end

return function(toParse)
  local ruleset = {}
  local order = {}

  local next = toParse:find("%/%*")
  while next do
    local endComment = toParse:find("%*%/", next + 2)
    toParse = toParse:sub(1, next - 1) .. toParse:sub(endComment + 2)

    next = toParse:find("%/%*")
  end

  for IRules in toParse:gmatch("%s*([^{}]+%s-%b{})") do
    local applicatorStr = IRules:match("^[^{}]+")
    local applicators = {}
    local orderIS = {}
    for applicator in applicatorStr:gmatch("[^,]+") do
      applicators[#applicators + 1] = trim(applicator)
      ruleset[trim(applicator)] = ruleset[trim(applicator)] or {}
      order[#order + 1] = {trim(applicator), {}}
      orderIS[#orderIS + 1] = #order
    end

    local contents = IRules:match("%b{}"):sub(2, -2)

    for rule in contents:gmatch("[^%;]+") do
      local name = rule:match("^%s-([^%s%:]+)")
      if name then
        local rest = rule:match("%:%s*(.+)"):reverse():match("%s*(.+)"):reverse()

        for i = 1, #applicators do
          local applicator = applicators[i]
          ruleset[applicator][name] = rest
        end

        for i = 1, #orderIS do
          local oT = order[orderIS[i]][2]
          oT[#oT + 1] = name
        end
      end
    end
  end

  return ruleset, order
end
