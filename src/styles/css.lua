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

    for applicator in applicatorStr:gmatch("[^,]+") do
      applicators[#applicators + 1] = #ruleset + 1
      ruleset[#ruleset + 1] = {trim(applicator), {}}
    end

    local contents = IRules:match("%b{}"):sub(2, -2)

    for rule in contents:gmatch("[^%;]+") do
      local name = rule:match("^%s-([^%s%:]+)")
      if name then
        local rest = rule:match("%:%s*(.+)"):reverse():match("%s*(.+)"):reverse()

        foreach(applicator, applicators) do
          ruleset[applicator][2][#ruleset[applicator][2] + 1] = {name, rest}
        end
      end
    end
  end

  return ruleset
end
