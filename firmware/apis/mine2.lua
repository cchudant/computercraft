local util = require(".firmware.apis.util")

local mine2 = {}

function mine2.selectItem(turtle, items)
	if type(items) == 'string' then items = { items } end

	for slot = 1, 16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil and util.arrayContains(items, detail.name) then
			turtle.select(slot)
			return true
		end
	end
	return false
end

local turtlesIds = {
	"computercraft:turtle_normal",
	"computercraft:turtle_advanced"
}
local lava = "minecraft:lava"
local water = "minecraft:water"
-- no gravel
local canReplaceLiquid = {
	"minecraft:andesite",
	"minecraft:cobbled_deepslate",
	"minecraft:cobblestone",
	"minecraft:andesite",
	"minecraft:granite",
	"minecraft:diorite",
	"minecraft:stone",
	"minecraft:deepslate",
	"minecraft:tuff",
	"minecraft:dirt",
	"minecraft:netherrack",
	"minecraft:magma_block",
	"minecraft:soul_sand",
	"minecraft:soul_soil",
	"minecraft:blackstone",
	"minecraft:calcite",
	"minecraft:smooth_basalt"
}
local toRemove = {
	"minecraft:andesite",
	"minecraft:cobbled_deepslate",
	"minecraft:cobblestone",
	"minecraft:andesite",
	"minecraft:granite",
	"minecraft:diorite",
	"minecraft:stone",
	"minecraft:deepslate",
	"minecraft:gravel",
	"minecraft:flint",
	"minecraft:tuff",
	"minecraft:dirt",
	"minecraft:netherrack",
	"minecraft:magma_block",
	"minecraft:soul_sand",
	"minecraft:soul_soil",
	"minecraft:blackstone",
	"minecraft:calcite",
	"minecraft:smooth_basalt"
}
function mine2.removeUselessItems(turtle, force)
	mine2.dropExcessItems(turtle, toRemove, 3, force)
end

function mine2.dropExcessItems(turtle, removeList, keepNStacks, force)
	local nStacks = 0
	if not force then
		for slot = 1, 16 do
			local detail = turtle.getItemDetail(slot)
			if detail ~= nil and util.arrayContains(removeList, detail.name) then
				nStacks = nStacks + 1
			end
		end
	end
	if nStacks > keepNStacks or force then
		local removed = 0
		for slot = 16, 1, -1 do
			local detail = turtle.getItemDetail(slot)
			local found = false
			if detail ~= nil and util.arrayContains(removeList, detail.name) then
				removed = removed + 1
				turtle.select(slot)
				turtle.dropDown()
			end
			if removed > keepNStacks - 1 then
				break
			end
		end
		turtle.select(1)
	end
end

function mine2.travelCuboid(turtle, options)
	local function turnRight()
		if options.right < 0 then
			turtle.turnLeft()
		else
			turtle.turnRight()
		end
	end
	local function turnLeft()
		if options.right < 0 then
			turtle.turnRight()
		else
			turtle.turnLeft()
		end
	end
	local function forward()
		while not turtle.forward() do end
	end
	local function up()
		if options.height < 0 then
			while not turtle.down() do end
		else
			while not turtle.up() do end
		end
	end
	local function down()
		if options.height < 0 then
			while not turtle.up() do end
		else
			while not turtle.down() do end
		end
	end

	local funcs = {
		turnRight = turnRight,
		turnLeft = turnLeft,
		up = up,
		down = down,
		forward = forward,
	}

	options = util.defaultArgs(options, {
		depth = nil,
		right = nil,
		height = nil,
		runBeforeEveryStep = function(funcs) end,
		runAfterEveryStep = function(funcs, bottom, up) end,
		prepareSameLevel = function(funcs, firstBottom, firstUp)
			funcs.forward()
		end,
		prepareUpOne = function(func, isDownwards)
			funcs.forward()
			funcs.up()
		end,
		runBeforeHeightStep = function(funcs, isDownwards) end,
		runAfterHeightStep = function(funcs, isDownwards) end,
		finish = function() turtle.back() end,
		heightStep = 1,
	})

	local isDownwards = false
	if options.height < 0 then isDownwards = true end

	if options.heightStep ~= 1 and options.heightStep ~= 3 then
		error("heightStep must be 1 or 3")
	end

	if options.depth == nil then error("No depth bound for cubeoid") end
	if options.right == nil then error("No right bound for cubeoid") end
	if options.height == nil then error("No height bound for cubeoid") end
	if options.depth < 0 then error("Depth cannot be negative") end

	if options.height == 0 or options.right == 0 or options.depth == 0 then
		return
	end

	local depth = options.depth
	local right = math.abs(options.right)
	local height = math.abs(options.height)

	local function line(x, bottom, up)
		for i = 1, x do
			options.runBeforeEveryStep(funcs, bottom, up)
			funcs.forward()
			options.runAfterEveryStep(funcs, bottom, up)
		end
	end

	local function layer(bottom, up)
		if depth == 1 then
			-- special case
			turnRight()
			line(right - 1, bottom, up)
			turnRight()
			turnRight()
			line(right - 1, bottom, up)
			turnRight()
		elseif right == 1 then
			-- special case
			line(depth - 1, bottom, up)
			turnRight()
			turnRight()
			line(depth - 1, bottom, up)
			turnRight()
			turnRight()
		else
			line(1, bottom, up)

			local fullRoundtrip = math.floor(right / 2)
			for i = 1, fullRoundtrip - 1 do
				line(depth - 2, bottom, up)
				turnRight()
				line(1, bottom, up)
				turnRight()
				line(depth - 2, bottom, up)
				turnLeft()
				line(1, bottom, up)
				turnLeft()
			end
			if right % 2 == 0 then
				line(depth - 2, bottom, up)
				turnRight()
				line(1, bottom, up)
				turnRight()
				line(depth - 1, bottom, up)
			else
				line(depth - 2, bottom, up)
				turnRight()
				line(1, bottom, up)
				turnRight()
				line(depth - 2, bottom, up)
				turnLeft()
				line(1, bottom, up)
				turnLeft()

				line(depth - 2, bottom, up)
				turnRight()
				turnRight()
				line(depth - 1, bottom, up)
			end
			turnRight()
			line(right - 1, bottom, up)
			turnRight()
		end
	end

	local heightStep = options.heightStep
	local nUpSteps = math.ceil(height / heightStep)

	local firstNGoUp = 1
	local firstUp = false
	local firstBottom = false
	if heightStep == 3 then
		if height % heightStep == 0 then
			firstNGoUp = 3
			firstUp = true
			firstBottom = true
		elseif height % heightStep == 1 then
			firstNGoUp = 2
			firstUp = false
			firstBottom = false
		elseif height % heightStep == 2 then
			firstNGoUp = 3
			firstUp = true
			firstBottom = false
		end
	end
	if isDownwards then
		local t = firstUp
		firstUp = firstBottom
		firstBottom = t
	end

	if heightStep == 3 and height % heightStep == 0 then
		options.prepareUpOne(funcs, isDownwards)
	else
		options.prepareSameLevel(funcs, firstBottom, firstUp)
	end

	for i = 1, nUpSteps do
		if i == 1 and heightStep == 3 then
			layer(firstBottom, firstUp)
		else
			layer(heightStep == 3, heightStep == 3)
		end

		if i < nUpSteps then
			local nGoUp = heightStep
			if i == 1 and heightStep == 3 then
				nGoUp = firstNGoUp
			end
			for i = 1, nGoUp do
				options.runBeforeHeightStep(funcs, isDownwards)
				funcs.up()
				options.runAfterHeightStep(funcs, isDownwards)
			end
		end
	end
	for i = 1, nUpSteps - 1 do
		local nGoUp = heightStep
		if i == 1 and heightStep == 3 then
			nGoUp = firstNGoUp
		end

		for j = 1, nGoUp do
			funcs.down()
		end
	end
	if heightStep == 3 and height % heightStep == 0 then
		funcs.down()
	end
	options.finish()
end

function mine2.digCuboidFuelRequired(depth, right, height)
	local levels = math.ceil(math.abs(height) / 3)

	-- mining the whole cuboid
	local required = levels * math.abs(right) * math.abs(depth)
	if right % 2 == 1 then
		required = required + math.abs(depth)
	end
	-- getting to height / backing
	required = required + (math.abs(height) * 2)

	return required * 1.1 -- safety margin
end

function mine2.protectedDig(side)
	local messageShown = 0
	local ret
	while true do
		local success, detail
		if side == 'down' then
			success, detail = turtle.inspectDown()
		elseif side == 'up' then
			success, detail = turtle.inspectUp()
		else
			success, detail = turtle.inspect()
		end

		if success then
			if util.arrayContains(turtlesIds, detail.name) then
				if messageShown < 3 then
					print("turtle in " .. side)
					messageShown = messageShown + 1
				end

				os.sleep(0.1)
			else
				if side == 'down' then
					ret = turtle.digDown()
				elseif side == 'up' then
					ret = turtle.digUp()
				else
					ret = turtle.dig()
				end
				break
			end
		else
			if side == 'down' then
				ret = turtle.digDown()
			elseif side == 'up' then
				ret = turtle.digUp()
			else
				ret = turtle.dig()
			end
			break
		end
	end
	if messageShown > 0 then
		print("turtle has gone away :)")
	end
	return ret
end

function mine2.digCuboid(turtle, options)
	local replaceLiquid
	local function dig()
		while mine2.protectedDig('front') do end
	end
	local function digDown()
		while mine2.protectedDig('down') do end
		replaceLiquid(turtle, 'down')
	end
	local function digUp()
		while mine2.protectedDig('up') do end
		replaceLiquid(turtle, 'up')
	end

	function replaceLiquid(turtle, dir)
		local success, detail
		if dir == 'down' then
			success, detail = turtle.inspectDown()
		else
			success, detail = turtle.inspectUp()
		end

		if success and (detail.name == lava or detail.name == water) and detail.state.level == 0 then
			if not mine2.selectItem(turtle, canReplaceLiquid) then
				return
			end

			if dir == 'down' then
				turtle.placeDown()
			else
				turtle.placeUp()
			end

			if dir == 'down' then
				digDown()
			else
				digUp()
			end

			turtle.select(1)
		end
	end

	if turtle.getFuelLevel() < mine2.digCuboidFuelRequired(options.depth, options.right, options.height) then
		error("not enough fuel")
	end

	options = util.defaultArgs(options, {
		depth = nil,
		right = nil,
		height = nil,
		runBeforeEveryStep = function(funcs)
			dig()
		end,
		runAfterEveryStep = function(funcs, bottom, up)
			if bottom then
				digDown()
			end
			if up then
				digUp()
			end
			mine2.removeUselessItems(turtle)
		end,
		prepareSameLevel = function(funcs, bottom, up)
			dig()
			funcs.forward()
			if bottom then
				digDown()
			end
			if up then
				digUp()
			end
		end,
		prepareUpOne = function(funcs, isDownwards)
			dig()
			funcs.forward()
			if isDownwards then
				digDown()
			else
				digUp()
			end
			funcs.up()
			if isDownwards then
				digDown()
			else
				digUp()
			end
		end,
		runBeforeHeightStep = function(funcs, isDownwards)
			if isDownwards then
				digDown()
			else
				digUp()
			end
		end,
		runAfterHeightStep = function(funcs, isDownwards)
			if isDownwards then
				digDown()
			else
				digUp()
			end
		end,
		finish = function()
			mine2.removeUselessItems(turtle, true)
			turtle.back()
		end,
		heightStep = 3,
	})

	mine2.travelCuboid(turtle, options)
end

function mine2.clearLava(turtle, options)
	util.defaultArgs(options, {
		depth = nil,
		right = nil,
		height = nil,
	})

	mine2.travelCuboid(turtle, options)
end

return mine2
