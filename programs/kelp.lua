os.loadAPI("/firmware/apis/mine2.lua")

-- local depth, right, height = ...
-- if depth == nil or right == nil or height == nil then
-- 	print("usage: mine2 <depth> <right> <height>")
-- 	return
-- end

-- depth = tonumber(depth)
-- right = tonumber(right)
-- height = tonumber(height)

depth = 4
right = 4
height = 8

turtle.dig()
turtle.forward()
mine2.travelCuboid(turtle, {
	depth = depth,
	right = right,
	height = 1,
    prepareSameLevel = function(funcs, firstBottom, firstUp)
    end,
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

turtle.back()


