local tableComponent = {}

function tableComponent.new(node)
  return setmetatable({node = node}, { __index = tableComponent })
end

function tableComponent:render(styles)
  draw()
end

return tableComponent
