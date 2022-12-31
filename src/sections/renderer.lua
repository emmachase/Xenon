--== Initialize Renderer ==--

local defaultLayout =
  --#ignore
[[]]
--#includeFile "src/styles/default.html"

local defaultStyles =
  --#ignore
[[]]
--#includeFile "src/styles/default.css"

local userLayout = fs.open(fs.combine(shell.dir(), config.layout or "layout.html"), "r")
local userStyles = fs.open(fs.combine(shell.dir(), config.styles or "styles.css"), "r")

local layout, styles = defaultLayout, defaultStyles
if userLayout then
  layout = userLayout.readAll()
  userLayout.close()
end

if userStyles then
  styles = userStyles.readAll()
  userStyles.close()
end

--#require "src/styles/renderer.lua" as renderer
renderer.inflateXML(layout)
renderer.processStyles(styles)
