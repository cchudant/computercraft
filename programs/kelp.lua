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

    for j=1,height do
        turtle.digDown()
        turtle.down()
    end
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
        for j=1,right do
            turtle.dig()
            turtle.forward()
        end
    end
    turtle.turnLeft()
end

function kelpUnSetup(depth, right, chunkY, chunkX)
    turtle.turnLeft()
    for i=2,chunkX do
        for j=1,depth do
            turtle.dig()
            turtle.forward()
        end
    end
    turtle.turnLeft()
    for i=2,chunkY do
        for j=1,right do
            turtle.dig()
            turtle.forward()
        end
    end
    turtle.turnLeft()
    turtle.turnLeft()
end

depth = 10
right = 10
height = 8

chunckDepth = 3
chunckRight = 3

for y=chunckDepth,1,-1 do
    for x=chunckRight,1,-1 do
        turtle.dig()
        turtle.forward()

        kelpSetup(depth, right, x, y)
        kelpHarvest(depth, right, height)
        kelpUnSetup(depth, right, x, y)

        turtle.back()
        turtle.turnRight()
        turtle.turnRight()
        for k=1,16 do
            turtle.select(k)
            turtle.drop()
        end
        turtle.turnRight()
        turtle.turnRight()
    end
end




