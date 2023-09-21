local mine2 = require(".apis.mine2")

mine2.travelCuboid(turtle, {
    depth = 6,
    right = 19,
    height = 1,
    prepareSameLevel = function(funcs, firstBottom, firstUp) end,
    runBeforeEveryStep = function(funcs)
        mine2.selectItem(turtle, {"minecraft:cobblestone", "minecraft:cobbled_deepslate"})
        turtle.placeDown()
    end,
    finish = function() end,
})