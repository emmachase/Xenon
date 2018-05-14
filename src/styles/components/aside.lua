local asideComponent = {}

function asideComponent.new(node)
  return setmetatable({node = node}, { __index = asideComponent })
end

function asideComponent:render(styles)
  draw()
end

return asideComponent
