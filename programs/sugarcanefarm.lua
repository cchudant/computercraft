os.loadAPI("/firmware/apis/mine2.lua")

-- local depth, right, height = ...
-- if depth == nil or right == nil or height == nil then
-- 	print("usage: mine2 <depth> <right> <height>")
-- 	return
-- end

-- depth = tonumber(depth)
-- right = tonumber(right)
-- height = tonumber(height)

depth = 5
right = 5
height = 1

function replaceLiquid(turtle, dir)
	local success, detail

	if success and (detail.name == lava or detail.name == water) and detail.state.level == 0 then
		if not selectItem(turtle, canReplaceLiquid) then
			return
		end

		if dir == 'down' then turtle.placeDown()
		else turtle.placeUp() end

		if dir == 'down' then digDown()
		else digUp() end

		turtle.select(1)
	end
end

travelCuboid(turtle, {
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

		if not success then
			if mine2.selectItem('minecraft:sugar_cane') then
				turtle.placeDown()
			end
		end
	end,
	finish = function()
		turtle.back()
	end,
})
