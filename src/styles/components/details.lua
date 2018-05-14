local detailsComponent = {}

function detailsComponent.new(node)
  return setmetatable({node = node}, { __index = detailsComponent })
end

function detailsComponent:render(styles)
  draw()
end

return detailsComponent
