local mine2 = require("apis.mine2")

function applyRules(turtle)
    local success, block = turtle.inspectDown()
    if block.name == nil or block.name == "minecraft:white_wool" then
        turtle.turnRight()
        while not mine2.selectItem(turtle, "minecraft:black_wool") do end
        turtle.digDown()
        turtle.placeDown()
        turtle.forward()
    end
    if block.name == "minecraft:black_wool" then
        turtle.turnLeft()
        while not mine2.selectItem(turtle, "minecraft:white_wool") do end
        turtle.digDown()
        turtle.placeDown()
        turtle.forward()
    end
end

while true do
    applyRules(turtle)
end
