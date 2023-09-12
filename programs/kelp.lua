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


depth = 10
right = 10
height = 8

turtle.dig()
turtle.forward()
kelpHarvest(depth, right, height)
turtle.back()


