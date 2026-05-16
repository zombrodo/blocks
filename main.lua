local Blocks = require "blocks"

local Counter = require "examples.counter"

local ui = {}

local uiPage = 1

local function loadCounter()
  local tree = Blocks.load("examples/counter-demo.xml")

  if not tree then
    error("Unable to load counter-demo.xml")
  end

  local counter = tree:find("counter")

  counter:on("click", function(hit) counter:onClick(hit) end)

  tree:hook()

  return tree
end

function love.load()
  ui[1] = Blocks.load("examples/basic.xml")
  ui[2] = Blocks.load("examples/primitives.xml")
  ui[3] = Blocks.load("examples/composition.xml")
  ui[4] = Blocks.load("examples/flex.xml")
  ui[5] = loadCounter()
end

function love.update(dt)
  ui[uiPage]:update(dt)
  if ui[uiPage].isDirty then
    ui[uiPage]:realise()
    ui[uiPage].isDirty = false
  end
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
