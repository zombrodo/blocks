local Blocks = {}

-- =============================================================================
-- Internal Object
-- =============================================================================

local Object = {}
Object.__index = Object

function Object:new(...)
end

function Object:extend()
  local class = {}
  for k, v in pairs(self) do
    if k:find("__") == 1 then
      class[k] = v
    end
  end

  class.__index = class
  class.super = self

  setmetatable(class, self)

  return class
end

function Object:is(T)
  local mt = getmetatable(self)
  while mt do
    if mt == T then
      return true
    end
    mt = getmetatable(mt)
  end

  return false
end

function Object:__call(...)
  local obj = setmetatable({}, self)
  obj:new(...)
  return obj
end

-- =============================================================================
-- Layout Functions
-- =============================================================================

local function parseValue(str)
  -- TODO: ensure that this isn't a silent error.

  local num, unit = str:match("^%s*(-?[%d.]+)%s*(.-)%s*$")
  return tonumber(num), unit ~= "" and unit or "px"
end

local function absolutePositioning(value, attribute, component)
  if component.parent then
    return component.parent[attribute] + value
  end
  return value
end

local function relativePositioning(value, attribute, component)
  local ratio = value / 100

  if attribute == "x" then
    if component.parent then
      return component.parent.x + (component.parent.w * ratio)
    end
    return love.graphics.getWidth() * ratio
  end

  if attribute == "y" then
    if component.parent then
      return component.parent.y + (component.parent.h * ratio)
    end
    return love.graphics.getHeight() * ratio
  end
end

local PositionDispatch = {
  ["px"] = absolutePositioning,
  ["%"] = relativePositioning,
}

local function absoluteDimension(value, attribute, component)
  return value
end

local function relativeDimension(value, attribute, component)
  local ratio = value / 100
  if attribute == "w" then
    if component.parent then
      return component.parent.w * ratio
    end
    return love.graphics.getWidth() * ratio
  end

  if attribute == "h" then
    if component.parent then
      return component.parent.h * ratio
    end
    return love.graphics.getHeight() * ratio
  end
end

local function autoDimension(value, attribute, component)
  if attribute == "w" then
    return component:getWidth()
  end

  if attribute == "h" then
    return component:getHeight()
  end
end

local DimensionDispatch = {
  ["px"] = absoluteDimension,
  ["%"] = relativeDimension,
  ["auto"] = autoDimension,
}


local DEFAULTS = {
  x = "0px", y = "0px", w = "100%", h = "100%"
}

-- TODO: Some nicer error handling wrt to units would be nice.

local function applyLayout(attribute, component)
  local raw = component.attributes[attribute] or DEFAULTS[attribute]

  if attribute == "x" then
    local value, units = parseValue(raw)
    return PositionDispatch[units](value, attribute, component)
  end

  if attribute == "y" then
    local value, units = parseValue(raw)
    return PositionDispatch[units](value, attribute, component)
  end

  if attribute == "w" then
    local value, units = parseValue(raw)
    return DimensionDispatch[units](value, attribute, component)
  end

  if attribute == "h" then
    local value, units = parseValue(raw)
    return DimensionDispatch[units](value, attribute, component)
  end

  error("Unknown attribute " .. attribute)
end

local function expandSlot(node, slotContent)
  for i, child in ipairs(node.children) do
    if child.type == "Slot" then
      table.remove(node.children, i)
      for j = #slotContent, 1, -1 do
        slotContent[j].parent = node
        table.insert(node.children, i, slotContent[j])
      end
      return true
    end

    if expandSlot(child, slotContent) then
      return true
    end
  end
  return false
end

-- =============================================================================
-- Base Component
-- =============================================================================

local Component = Object:extend()

function Component:new(componentDef)
  Component.super.new(self)

  self.attributes = componentDef
  self.type = "Component"

  self.x = 0
  self.y = 0
  self.w = 0
  self.h = 0

  self.children = {}
  self.parent = nil

  self.state = {}
  self.listeners = {}

  -- TODO: This probably belongs in some sorta styling mechanism, rather than here.
  self.font = love.graphics.getFont()
end

function Component:expandTemplate(path)
  local slotContent = self.children
  self.children = {}

  local template = Blocks.parse(path)
  if not template then
    error("Unable to parse template: " .. path)
  end

  if template.type == "Fragment" then
    for _, node in ipairs(template.children) do
      self:addChild(node)
    end
  else
    self:addChild(template)
  end

  if #slotContent > 0 then
    expandSlot(self, slotContent)
  end
end

function Component:resolveBox()
  self.x = applyLayout("x", self)
  self.y = applyLayout("y", self)
  self.w = applyLayout("w", self)
  self.h = applyLayout("h", self)
end

function Component:realiseChildren()
  for i, child in ipairs(self.children) do
    child:realise()
  end
end

function Component:realise()
  if self.template and not self._expanded then
    self:expandTemplate(self.template)
    self._expanded = true
  end

  self:resolveBox()
  self:realiseChildren()
end

function Component:addChild(child)
  child.parent = self
  table.insert(self.children, child)
end

function Component:removeChild(child)
  for i = #self.children, 1, -1 do
    if self.children[i] == child then
      table.remove(self.children, i)
    end
  end
end

function Component:on(event, callback)
  self.listeners[event] = self.listeners[event] or {}
  table.insert(self.listeners[event], callback)
end

function Component:emit(event, ...)
  if not self.listeners[event] then
    return
  end

  for _, cb in ipairs(self.listeners[event]) do
    cb(...)
  end
end

function Component:find(id)
  for _, child in ipairs(self.children) do
    if child.attributes.id == id then
      return child
    end
    local found = child:find(id)
    if found then
      return found
    end
  end
end

function Component:inBounds(x, y)
  return x >= self.x and x <= self.x + self.w
      and y >= self.y and y <= self.y + self.h
end

function Component:hitTest(x, y, depth)
  if not self:inBounds(x, y) then
    return nil
  end

  for i = #self.children, 1, -1 do
    local hit = self.children[i]:hitTest(x, y, depth)
    if hit then
      return hit
    end
  end

  return self
end

function Component:update(dt)
  for i, child in ipairs(self.children) do
    child:update(dt)
  end
end

function Component:draw()
  for i, child in ipairs(self.children) do
    child:draw()
  end
end

function Component:hook()
  local oldMousePressed = love.mousepressed
  love.mousepressed = function(x, y, button)
    local hit = self:hitTest(x, y)
    if not hit then
      return
    end

    local node = hit
    while node do
      if node.listeners["click"] then
        if node:emit("click", x, y) == false then
          break
        end
      end
      node = node.parent
    end
    oldMousePressed(x, y, button)
  end
end

function Component:__tostring()
  local this = string.format(
    "[%s x = %d (%s), y = %d (%s), w = %d (%s), h = %d (%s)]",
    self.type,
    self.x,
    self.attributes.x,
    self.y,
    self.attributes.y,
    self.w,
    self.attributes.w,
    self.h,
    self.attributes.h
  )

  local children = {}
  for i, child in ipairs(self.children) do
    table.insert(children, string.format("\t %s", child))
  end

  return string.format("%s\n%s", this, table.concat(children, "\n"))
end

-- =============================================================================
-- Component Registry
-- =============================================================================

local Registry = Object:extend()

function Registry:new()
  Registry.super.new(self)
  self.components = {
    component = Component
  }
end

function Registry:add(component, class)
  local key = string.lower(component)
  if self.components[key] then
    error("Component with key " .. key .. " has already been registered")
  end
  self.components[key] = class
end

function Registry:get(component)
  return self.components[string.lower(component)]
end

local ComponentRegistry = Registry()

-- =============================================================================
-- Slot
-- =============================================================================

local Slot = Component:extend()

function Slot:new(componentDef)
  Slot.super.new(self, componentDef)
  self.type = "Slot"
end

ComponentRegistry:add("slot", Slot)

-- =============================================================================
-- Fragment
-- =============================================================================

local Fragment = Component:extend()

function Fragment:new(componentDef)
  Fragment.super.new(self, componentDef)
  self.type = "Fragment"
end

function Fragment:resolveBox()
  if self.parent then
    self.x = self.parent.x
    self.y = self.parent.y
    self.w = self.parent.w
    self.h = self.parent.h
  else
    self.x = 0
    self.y = 0
    self.w = love.graphics.getWidth()
    self.h = love.graphics.getHeight()
  end
end

ComponentRegistry:add("fragment", Fragment)

-- =============================================================================
-- TextSegment Node (internal)
-- =============================================================================

local TextSegment = Component:extend()

function TextSegment:new(text)
  TextSegment.super.new(self, {})
  self.type = "TextSegment"
  self.text = text
end

function TextSegment:getWidth()
  return self.parent.font:getWidth(self.text)
end

function TextSegment:getHeight()
  return self.parent.font:getHeight()
end

function TextSegment:draw()
  TextSegment.super.draw(self)
  love.graphics.print(self.text, self.parent.font, self.x, self.y)
end

-- =============================================================================
-- XML Parser
-- =============================================================================

local XMLParser = {}

local function trim(str)
  return str:gsub("^%s*(.-)%s*$", "%1")
end

local function parseAttributes(attributeString)
  local attributes = {}
  if not attributeString then
    return attributes
  end

  for name, value in attributeString:gmatch('(%w+)%s*=%s*["\']([^"\']*)["\']') do
    attributes[name] = value
  end

  return attributes
end

local function parseTextSegment(text)
  local hasLeadingNewline = text:find("^%s*\n") ~= nil
  local hasTrailingNewline = text:find("\n%s*$") ~= nil

  local result = text:gsub("%s+", " ")

  if hasLeadingNewline then
    result = result:gsub("^ ", "")
  end

  if hasTrailingNewline then
    result = result:gsub(" $", "")
  end

  if #result == 0 then return end

  return TextSegment(result)
end

local function loadComponentRelative(tag, basePath)
  local relativeComponent = basePath .. string.lower(tag) .. ".xml"

  if love.filesystem.getInfo(relativeComponent) then
    return Blocks.parse(relativeComponent)
  end
end

local function createNode(tag, attributes, context)
  local constructor = ComponentRegistry:get(tag)
  if not constructor then
    local relativeComponent = loadComponentRelative(tag, context.basePath)
    if relativeComponent then
      return relativeComponent
    end
    error("Unknown component " .. tag)
  end

  return constructor(attributes)
end

function XMLParser.parse(xmlString, context)
  xmlString = trim(xmlString)
  xmlString = xmlString:gsub("</>", "</Fragment>"):gsub("<>", "<Fragment>")


  local stack = {}
  local root = nil
  local i = 1

  while i <= #xmlString do
    local tagStart = xmlString:find("<", i)
    if not tagStart then
      break
    end

    if tagStart > 1 then
      local textContent = xmlString:sub(i, tagStart - 1)
      if #stack > 0 then
        local parent = stack[#stack]
        local textNode = parseTextSegment(textContent)
        if textNode then
          parent:addChild(textNode)
        end
      end
    end

    local tagEnd = xmlString:find(">", tagStart)
    if not tagEnd then
      break
    end

    local tagContent = xmlString:sub(tagStart + 1, tagEnd - 1)

    -- CLOSING TAGS
    if tagContent:sub(1, 1) == '/' then
      local tagName = trim(tagContent:sub(2))
      if #stack > 0 and string.lower(stack[#stack].type) == string.lower(tagName) then
        table.remove(stack)
      end
      -- SELF CLOSING TAGS
    elseif tagContent:sub(-1) == '/' then
      local tagPart = trim(tagContent:sub(1, -2))
      local spacePos = tagPart:find('%s')
      local tagName, attrString

      if spacePos then
        tagName = tagPart:sub(1, spacePos - 1)
        attrString = tagPart:sub(spacePos + 1)
      else
        tagName = tagPart
      end

      local attributes = parseAttributes(attrString)
      local node = createNode(tagName, attributes, context)

      if #stack > 0 then
        local parent = stack[#stack]
        parent:addChild(node)
      else
        root = node
      end
      -- OPENING TAGS
    else
      local spacePos = tagContent:find('%s')
      local tagName, attrString

      if spacePos then
        tagName = tagContent:sub(1, spacePos - 1)
        attrString = tagContent:sub(spacePos + 1)
      else
        tagName = tagContent
      end

      local attributes = parseAttributes(attrString)
      local node = createNode(tagName, attributes, context)

      if #stack > 0 then
        local parent = stack[#stack]
        parent:addChild(node)
      else
        root = node
      end

      table.insert(stack, node)
    end

    i = tagEnd + 1
  end

  return root
end

function XMLParser.printNode(node, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)

  print(prefix .. "Tag: " .. node.tag)

  if next(node.attributes) then
    print(prefix .. "Attributes:")
    for k, v in pairs(node.attributes) do
      print(prefix .. "  " .. k .. " = " .. v)
    end
  end

  if node.text then
    print(prefix .. "Text: " .. node.text)
  end

  if #node.children > 0 then
    print(prefix .. "Children:")
    for _, child in ipairs(node.children) do
      XMLParser.printNode(child, indent + 1)
    end
  end
end

-- =============================================================================
-- Common Components
-- =============================================================================

-- =====================================
-- Text
-- =====================================

local Text = Component:extend()

function Text:new(componentDef)
  Text.super.new(self, componentDef)
  self.type = "Text"
end

function Text:realiseChildren()
  local cursorX = self.x
  for _, child in ipairs(self.children) do
    child.x = cursorX
    child.y = self.y
    cursorX = cursorX + child:getWidth()
  end
end

function Text:getHeight()
  local height = 0
  for _, child in ipairs(self.children) do
    height = math.max(child:getHeight(), height)
  end
  return height
end

function Text:getWidth()
  local width = 0
  for _, child in ipairs(self.children) do
    width = width + child:getWidth()
  end
  return width
end

ComponentRegistry:add("text", Text)

-- =====================================
-- Rectangle
-- =====================================

local Rectangle = Component:extend()

function Rectangle:new(componentDef)
  Rectangle.super.new(self, componentDef)
  self.type = "Rectangle"

  self.mode = componentDef.mode or "line"
end

function Rectangle:draw()
  love.graphics.rectangle(self.mode, self.x, self.y, self.w, self.h)
  Rectangle.super.draw(self)
end

ComponentRegistry:add("rectangle", Rectangle)
ComponentRegistry:add("rect", Rectangle)


-- =====================================
-- Circle
-- =====================================

local Circle = Component:extend()

function Circle:new(componentDef)
  Circle.super.new(self, componentDef)
  self.type          = "Circle"

  self.attributes.cx = componentDef.cx
  self.attributes.cy = componentDef.cy
  self.r             = componentDef.r or 0
  self.mode          = componentDef.mode or "line"
end

function Circle:resolveBox()
  local cxValue, cxUnit = parseValue(self.attributes.cx)
  local cyValue, cyUnit = parseValue(self.attributes.cy)

  self.cx = PositionDispatch[cxUnit](cxValue, "x", self)
  self.cy = PositionDispatch[cyUnit](cyValue, "y", self)

  self.x = self.cx - self.r
  self.y = self.cy - self.r
  self.w = self.r * 2
  self.h = self.r * 2
end

function Circle:draw()
  love.graphics.circle(self.mode, self.cx, self.cy, self.r)
  Circle.super.draw(self)
end

ComponentRegistry:add("circle", Circle)

-- =====================================
-- 9 Slice
-- =====================================

local NineSlice = Component:extend()

function NineSlice:new(componentDef)
  NineSlice.super.new(self, componentDef)
  self.type = "NineSlice"

  self.imagePath = componentDef.src
  if not self.imagePath then
    error("NineSlice component requires a 'src' attribute")
  end

  self.image = love.graphics.newImage(self.imagePath)
  local imageWidth, imageHeight = self.image:getDimensions()

  self.sliceLeft = componentDef.sliceLeft or math.floor(imageWidth / 3)
  self.sliceRight = componentDef.sliceRight or math.floor(imageWidth / 3)
  self.sliceTop = componentDef.sliceTop or math.floor(imageHeight / 3)
  self.sliceBottom = componentDef.sliceBottom or math.floor(imageHeight / 3)

  self.quads = {}

  self.quads.topLeft = love.graphics.newQuad(
    0,
    0,
    self.sliceLeft,
    self.sliceTop,
    imageWidth,
    imageHeight
  )

  self.quads.topCenter = love.graphics.newQuad(
    self.sliceLeft,
    0,
    imageWidth - self.sliceLeft - self.sliceRight,
    self.sliceTop,
    imageWidth,
    imageHeight
  )

  self.quads.topRight = love.graphics.newQuad(
    imageWidth - self.sliceRight,
    0,
    self.sliceRight,
    self.sliceTop,
    imageWidth,
    imageHeight
  )

  self.quads.middleLeft = love.graphics.newQuad(
    0,
    self.sliceTop,
    self.sliceLeft,
    imageHeight - self.sliceTop - self.sliceBottom,
    imageWidth,
    imageHeight
  )

  self.quads.center = love.graphics.newQuad(
    self.sliceLeft,
    self.sliceTop,
    imageWidth - self.sliceLeft - self.sliceRight,
    imageHeight - self.sliceTop - self.sliceBottom,
    imageWidth, imageHeight
  )

  self.quads.middleRight = love.graphics.newQuad(
    imageWidth - self.sliceRight,
    self.sliceTop,
    self.sliceRight,
    imageHeight - self.sliceTop - self.sliceBottom,
    imageWidth,
    imageHeight
  )

  self.quads.bottomLeft = love.graphics.newQuad(
    0,
    imageHeight - self.sliceBottom,
    self.sliceLeft, self.sliceBottom,
    imageWidth,
    imageHeight
  )
  self.quads.bottomCenter = love.graphics.newQuad(
    self.sliceLeft,
    imageHeight - self.sliceBottom,
    imageWidth - self.sliceLeft - self.sliceRight,
    self.sliceBottom,
    imageWidth,
    imageHeight
  )

  self.quads.bottomRight = love.graphics.newQuad(
    imageWidth - self.sliceRight,
    imageHeight - self.sliceBottom,
    self.sliceRight,
    self.sliceBottom,
    imageWidth,
    imageHeight
  )
end

function NineSlice:draw()
  local centerWidth = self.w - self.sliceLeft - self.sliceRight
  local centerHeight = self.h - self.sliceTop - self.sliceBottom

  love.graphics.draw(self.image,
    self.quads.topLeft,
    self.x,
    self.y)

  love.graphics.draw(
    self.image,
    self.quads.topCenter,
    self.x + self.sliceLeft,
    self.y,
    0,
    centerWidth / (self.image:getWidth() - self.sliceLeft - self.sliceRight),
    1
  )

  love.graphics.draw(
    self.image,
    self.quads.topRight,
    self.x + self.w - self.sliceRight,
    self.y
  )

  love.graphics.draw(
    self.image,
    self.quads.middleLeft,
    self.x,
    self.y + self.sliceTop,
    0,
    1,
    centerHeight / (self.image:getHeight() - self.sliceTop - self.sliceBottom)
  )

  love.graphics.draw(
    self.image,
    self.quads.center,
    self.x + self.sliceLeft,
    self.y + self.sliceTop, 0,
    centerWidth / (self.image:getWidth() - self.sliceLeft - self.sliceRight),
    centerHeight / (self.image:getHeight() - self.sliceTop - self.sliceBottom)
  )

  love.graphics.draw(
    self.image,
    self.quads.middleRight,
    self.x + self.w - self.sliceRight,
    self.y + self.sliceTop,
    0,
    1,
    centerHeight / (self.image:getHeight() - self.sliceTop - self.sliceBottom)
  )

  love.graphics.draw(
    self.image,
    self.quads.bottomLeft,
    self.x,
    self.y + self.h - self.sliceBottom
  )

  love.graphics.draw(
    self.image, self.quads.bottomCenter, self.x + self.sliceLeft,
    self.y + self.h - self.sliceBottom, 0,
    centerWidth / (self.image:getWidth() - self.sliceLeft - self.sliceRight),
    1
  )

  love.graphics.draw(
    self.image,
    self.quads.bottomRight,
    self.x + self.w - self.sliceRight,
    self.y + self.h - self.sliceBottom
  )

  NineSlice.super.draw(self)
end

ComponentRegistry:add("nineslice", NineSlice)
ComponentRegistry:add("9slice", NineSlice)

-- =====================================
-- Sprite
-- =====================================

local Sprite = Component:extend()

function Sprite:new(componentDef)
  Sprite.super.new(self, componentDef)

  self.spritePath = componentDef.src
  if not self.spritePath then
    error("Sprite component requires a 'src' attribute")
  end

  self.sprite = love.graphics.newImage(self.spritePath)
end

function Sprite:getWidth()
  return self.sprite:getWidth()
end

function Sprite:getHeight()
  return self.sprite:getHeight()
end

function Sprite:draw()
  love.graphics.draw(self.sprite, self.x, self.y)
end

ComponentRegistry:add("sprite", Sprite)

-- =====================================
-- Flex
-- =====================================

local FLEX_AXIS = {
  row = {
    main = "x",
    cross = "y",
    mainSize = "w",
    crossSize = "h",
    getMain = "getWidth",
    getCross = "getHeight",
  },
  column = {
    main = "y",
    cross = "x",
    mainSize = "h",
    crossSize = "w",
    getMain = "getHeight",
    getCross = "getWidth",
  }
}

local function getAxisValue(component, func)
  if component[func] then
    return component[func](component)
  end

  return 0
end

local function resolveBasis(component, axis, flexContainer)
  local raw = component.attributes.basis
  if not raw then
    return getAxisValue(component, axis.getMain)
  end

  local value, unit = parseValue(raw)
  if unit == "%" then
    return flexContainer[axis.mainSize] * value / 100
  end
  return value
end

local Flex = Component:extend()

function Flex:new(componentDef)
  Flex.super.new(self, componentDef)

  self.type = "Flex"
  self.direction = componentDef.direction or "row"
  self.justify = componentDef.justify or "start"
  self.align = componentDef.align or "start"
  self.gap = componentDef.gap
end

function Flex:realiseChildren()
  if #self.children == 0 then
    return
  end

  local axis = FLEX_AXIS[self.direction]

  local basis = {}
  local totalBasis = 0
  local grow = {}
  local totalGrow = 0

  for i, child in ipairs(self.children) do
    local growVal = tonumber(child.attributes.grow) or 0
    grow[i] = growVal
    totalGrow = totalGrow + growVal

    local basisVal = resolveBasis(child, axis, self)
    basis[i] = basisVal
    totalBasis = totalBasis + basisVal
  end

  local gapValue, gapUnit = parseValue(self.gap)
  local gap = gapValue
  if gapUnit == "%" then
    gap = (self[axis.mainSize] * gapValue) / 100
  end

  local totalGap = gap * (#self.children - 1)
  local leftover = self[axis.mainSize] - totalGap - totalBasis

  if totalGrow > 0 and leftover > 0 then
    for i = 1, #self.children do
      if grow[i] > 0 then
        basis[i] = basis[i] + leftover * (grow[i] / totalGrow)
      end
    end
  end

  local cursor = self[axis.main]
  local stepGap = gap

  if leftover > 0 then
    if self.justify == "center" then
      cursor = cursor + leftover / 2
    elseif self.justify == "end" then
      cursor = cursor + leftover
    elseif self.justify == "space-between" and #self.children > 1 then
      stepGap = gap + leftover / (#self.children - 1)
    elseif self.justify == "space-around" then
      local pad = leftover / (2 * self.children)
      cursor    = cursor + pad
      stepGap   = gap + 2 * pad
    end
  end

  for i, child in ipairs(self.children) do
    child[axis.main]     = cursor
    child[axis.mainSize] = basis[i]

    if self.align == "stretch" then
      child[axis.cross]     = self[axis.cross]
      child[axis.crossSize] = self[axis.crossSize]
    else
      local crossSize = getAxisValue(child, axis.getCross)
      if crossSize == 0 then crossSize = self[axis.crossSize] end

      if self.align == "center" then
        child[axis.cross] = self[axis.cross] + (self[axis.crossSize] - crossSize) / 2
      elseif self.align == "end" then
        child[axis.cross] = self[axis.cross] + self[axis.crossSize] - crossSize
      else
        child[axis.cross] = self[axis.cross]
      end
      child[axis.crossSize] = crossSize
    end

    child:realiseChildren()
    cursor = cursor + basis[i] + stepGap
  end
end

ComponentRegistry:add("flex", Flex)

-- =============================================================================
-- Entrypoint
-- =============================================================================

function Blocks.parse(xmlFile)
  local contents = love.filesystem.read(xmlFile)

  if not contents then
    error("Could not read file: " .. xmlFile)
  end

  local context = {
    filePath = xmlFile,
    basePath = string.match(xmlFile, "(.*/)") or ""
  }

  return XMLParser.parse(contents, context)
end

function Blocks.load(xmlFile)
  local tree = Blocks.parse(xmlFile)

  if tree then
    tree:realise()
  end

  return tree
end

function Blocks.component(name)
  local component = Component:extend()
  ComponentRegistry:add(name, component)
  return component
end

return Blocks
