os.loadAPI("/firmware/apis/mine2.lua")

depth = 15
right = 5

while true do
	while mine2.selectItem(turtle, 'minecraft:oak_log') do
		turtle.dropUp()
	end

	function cutTree() 
		local success, detail = turtle.inspectDown()
		if success and detail.name == 'minecraft:oak_log' then
			turtle.digDown()
			local success, detail = turtle.inspectUp()
			local level = 0
			while success and detail.name == 'minecraft:oak_log' do
				turtle.digUp()
				turtle.up()
				level = level + 1					
				success, detail = turtle.inspectUp()
			end

			for _ = level, 1, -1 do
				turtle.down()
			end

		end

		if not success and mine2.selectItem(turtle, 'minecraft:oak_sapling') then
			turtle.placeDown()
		end
		mine2.dropExcessItems(turtle, {'minecraft:oak_sapling'}, 2)
		turtle.suckDown()
	end

	mine2.travelCuboid(turtle, {
		depth = depth,
		right = right,
		height = 1,
		prepareSameLevel = function(funcs)
			turtle.dig()
			funcs.forward()
			cutTree()
		end,
		runBeforeEveryStep = function(funcs)
			turtle.dig()
		end,
		runAfterEveryStep = function(funcs)
			cutTree()
		end,
	})

	while mine2.selectItem(turtle, 'minecraft:oak_log') do
		turtle.dropUp()
	end

	turtle.select(1)

	os.sleep(60*5)
end


