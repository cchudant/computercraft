local mine2 = require("apis.mine2")

-- local depth, right, height = ...
-- if depth == nil or right == nil or height == nil then
-- 	print("usage: mine2 <depth> <right> <height>")
-- 	return
-- end

-- depth = tonumber(depth)
-- right = tonumber(right)
-- height = tonumber(height)

function placeDirt(depth, right)
    mine2.travelCuboid(turtle, {
        depth = depth,
        right = right,
        height = 1,
        prepareSameLevel = function(funcs, firstBottom, firstUp) end,
        runBeforeEveryStep = function(funcs)
            mine2.selectItem(turtle, "minecraft:dirt")
            turtle.placeDown()
        end,
        finish = function() end,
    })
end


placeDirt(32, 14)