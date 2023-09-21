local mine2 = require("..apis.mine2")

function applyRules(turtle)
    local success, block = turtle.inspectUp()
    if block.name == nil or block.name == "minecraft:white_wool" then
        while not mine2.selectItem(turtle, "minecraft:black_wool") do end
        while not turtle.turnRight() do end
        while not turtle.digUp() do end
        while not turtle.placeUp() do end
        while not turtle.forward() do end
    end
    if block.name == "minecraft:black_wool" then
        while not mine2.selectItem(turtle, "minecraft:white_wool") do end
        while not turtle.turnLeft() do end
        while not turtle.digUp() do end
        while not turtle.placeUp() do end
        while not turtle.forward() do end
    end
end

function refuel(turtle)
    if turtle.getFuelLevel() < 100 then
        print("refueling ...")
        while not mine2.selectItem(turtle, "minecraft:dried_kelp_block") do end
        item = turtle.getItemDetail()
        for i=1,item.count do
            turtle.refuel()
        end
        print("refueling done")
    end
end

while true do
    refuel(turtle)
    applyRules(turtle)
end
