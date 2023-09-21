local mine2 = require("..apis.mine2")

-- local depth, right, height = ...
-- if depth == nil or right == nil or height == nil then
-- 	print("usage: mine2 <depth> <right> <height>")
-- 	return
-- end

-- depth = tonumber(depth)
-- right = tonumber(right)
-- height = tonumber(height)

depth = 37
right = 40
height = 1

while true do
	while mine2.selectItem(turtle, 'minecraft:sugar_cane') do
		turtle.dropUp()
	end

	mine2.travelCuboid(turtle, {
		depth = depth,
		right = right / 2,
		height = height,
		runBeforeEveryStep = function(funcs)
			turtle.dig()
		end,
		runAfterEveryStep = function(funcs, bottom, up)
			local success, detail = turtle.inspectDown()
			if success and detail.name == 'minecraft:sugar_cane' then
				turtle.digDown()
			end
		end,
	})

	while mine2.selectItem(turtle, 'minecraft:sugar_cane') do
		turtle.dropUp()
	end

	turtle.turnRight()
	for i = 1,right/2 do
		turtle.forward()
	end
	turtle.turnLeft()

	mine2.travelCuboid(turtle, {
		depth = depth,
		right = right / 2,
		height = height,
		runBeforeEveryStep = function(funcs)
			turtle.dig()
		end,
		runAfterEveryStep = function(funcs, bottom, up)
			local success, detail = turtle.inspectDown()
			if success and detail.name == 'minecraft:sugar_cane' then
				turtle.digDown()
			end
		end,
	})

	turtle.turnLeft()
	for i = 1,right/2 do
		turtle.forward()
	end
	turtle.turnRight()

	while mine2.selectItem(turtle, 'minecraft:sugar_cane') do
		turtle.dropUp()
	end

	os.sleep(60*5)
end
