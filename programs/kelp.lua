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

mine2.travelCuboid(turtle, {
	depth = depth,
	right = right,
	height = height,
	runBeforeEveryStep = function(funcs)
		turtle.dig()
	end,
})

for j=1,height do
    turtle.up()
end

mine2.travelCuboid(turtle, {
	depth = depth,
	right = right,
	height = height,
	runBeforeEveryStep = function(funcs)
		turtle.suckDown()
	end,
})

for j=1,height do
    turtle.down()
end


