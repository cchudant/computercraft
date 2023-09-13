os.loadAPI("/firmware/apis/mine2.lua")

mine2.travelCuboid(turtle, {
    depth = 6,
    right = 19,
    height = 1,
    prepareSameLevel = function(funcs, firstBottom, firstUp) end,
    runBeforeEveryStep = function(funcs)
        mine2.selectItem(turtle, "minecraft:cobblestone")
        turtle.placeDown()
    end,
    finish = function() end,
})