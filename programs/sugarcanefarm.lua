os.loadAPI("/firmware/apis/mine2.lua")

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
	while mine2.selectItem('minecraft:sugar_cane') do
		turtle.dropUp()
	end

	mine2.travelCuboid(turtle, {
		depth = depth,
		right = right,
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
	while mine2.selectItem('minecraft:sugar_cane') do
		turtle.dropUp()
	end

	os.sleep(60*5)
end
