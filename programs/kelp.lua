os.loadAPI("/firmware/apis/mine2.lua")

-- local depth, right, height = ...
-- if depth == nil or right == nil or height == nil then
-- 	print("usage: mine2 <depth> <right> <height>")
-- 	return
-- end

-- depth = tonumber(depth)
-- right = tonumber(right)
-- height = tonumber(height)


function kelpHarvest(depth, right, height)

    mine2.travelCuboid(turtle, {
        depth = depth,
        right = right,
        height = 1,
        prepareSameLevel = function(funcs, firstBottom, firstUp) end,
        runBeforeEveryStep = function(funcs)
            turtle.dig()
        end,
        finish = function() end,
    })

    for j=1,height do
        turtle.up()
    end

    mine2.travelCuboid(turtle, {
        depth = depth,
        right = right,
        height = 1,
        prepareSameLevel = function(funcs, firstBottom, firstUp)
        end,
        runBeforeEveryStep = function(funcs)
            turtle.suckDown()
        end,
        finish = function() end,
    })

    for j=1,height-1 do
        turtle.digDown()
        turtle.down()
    end
    turtle.down()
end

function kelpSetup(depth, right, chunkY, chunkX)
    for i=2,chunkY do
        for j=1,depth do
            turtle.dig()
            turtle.forward()
        end
    end
    turtle.turnRight()
    for i=2,chunkX do
        for j=2,right do
            turtle.dig()
            turtle.forward()
        end
    end
    turtle.turnLeft()
end

depth = 2
right = 2
height = 8

chunckDepth = 2
chunckRight = 2

-- for i=0,chunckDepth-1 do
--     for j=0,chunckRight-1 do
turtle.dig()
turtle.forward()

kelpSetup(depth, right, 2, 1)
kelpHarvest(depth, right, height)

-- turtle.back()
-- turtle.turnRight()
-- turtle.turnRight()
-- for k=1,16 do
--     turtle.place()
-- end
-- turtle.turnRight()
-- turtle.turnRight()



