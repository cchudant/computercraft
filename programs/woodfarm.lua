os.loadAPI("/firmware/apis/mine2.lua")

depth = 15
right = 3

while true do
	while mine2.selectItem(turtle, 'minecraft:sugar_cane') do
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
			local success, detail = turtle.inspect()
			if success and detail.name == 'minecraft:oak_log' then
				turtle.digDown()
				local success, detail = turtle.inspectUp()
				local level = 1
				while success and detail.name == 'minecraft:oak_log' do
					turtle.digUp()
					turtle.up()
					level = level + 1					
					success, detail = turtle.inspectUp()
				end

				for _ = level, 1, -1 do
					turtle.down()
				end

				if mine2.selectItem(turtle, 'minecraft:sapling') then
					turtle.placeDown()
				end
				mine2.dropExcessItems(turtle, {'minecraft:sapling'}, 2)
			end

		end,
	})

	while mine2.selectItem(turtle, 'minecraft:oak_log') do
		turtle.dropUp()
	end

	turtle.select(1)

	os.sleep(60*5)
end


