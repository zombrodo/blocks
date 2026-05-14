local Blocks = require "blocks"

local ui = {}

local uiPage = 1

function love.load()
  ui[1] = Blocks.load("examples/basic.xml")
  ui[2] = Blocks.load("examples/primitives.xml")
  ui[3] = Blocks.load("examples/composition.xml")
  ui[4] = Blocks.load("examples/flex.xml")
end

function love.update(dt)
end

function love.draw()
  ui[uiPage]:draw()
end

function love.keypressed(key)
  if key == "left" then
    uiPage = math.max(1, uiPage - 1)
  end

  if key == "right" then
    uiPage = math.min(#ui, uiPage + 1)
  end
end