local Blocks = require "blocks"

local Counter = Blocks.component("counter")
Counter.template = "examples/counter.xml"

function Counter:new(componentDef)
  Counter.super.new(self, componentDef)

  self.type = "Counter"
  self.value = 0
end

function Counter:onClick(hit)
  if hit.id == "increment" then
    self.value = self.value + 1
  end

  if hit.id == "decrement" then
    self.value = self.value - 1
  end
end

return Counter