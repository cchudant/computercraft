function arrayContains(array, item)
	for _, v in ipairs(array) do
		if item == v then
			return true
		end
	end
	return false
end

function selectItem(turtle, items)
	if type(items) == 'string' then items = {items} end

	for slot=1,16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil and arrayContains(items, detail.name) then
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
	"minecraft:blackstone"
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
	"minecraft:blackstone"
}
function removeUselessItems(turtle, force)
	local nStacks = 0
	if not force then
		for slot=1,16 do
			local detail = turtle.getItemDetail(slot)
			if detail ~= nil and arrayContains(toRemove, detail.name) then
				nStacks = nStacks + 1
			end
		end
	end
	if nStacks > 3 or force then
		local removed = 0
		for slot=16,1,-1 do
			local detail = turtle.getItemDetail(slot)
			local found = false
			if detail ~= nil and arrayContains(toRemove, detail.name) then
				removed = removed + 1
				turtle.select(slot)
				turtle.dropDown()
			end
			if removed > 2 then
				break
			end
		end
		turtle.select(1)
	end
end

function defaultArgs(options, defaults)
	for k,v in pairs(defaults) do
		if options[k] == nil then
			options[k] = defaults[k]
		end
	end
end

function travelCuboid(turtle, options)
	function turnRight()
		if options.right < 0 then turtle.turnLeft()
		else turtle.turnRight() end
	end
	function turnLeft()
		if options.right < 0 then turtle.turnRight()
		else turtle.turnLeft() end
	end
	function forward()
		while not turtle.forward() do end
	end
	function up()
		if options.height < 0 then while not turtle.down() do end
		else while not turtle.up() do end end
	end
	function down()
		if options.height < 0 then while not turtle.up() do end
		else while not turtle.down() do end end
	end

	funcs = {
		turnRight = turnRight,
		turnLeft = turnLeft,
		up = up,
		down = down,
		forward = forward,
	}

	defaultArgs(options, {
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

	function line(x, bottom, up)
	    for i = 1,x do
	        options.runBeforeEveryStep(funcs, bottom, up)
	        funcs.forward()
	    	options.runAfterEveryStep(funcs, bottom, up)
	    end
	end

	function layer(bottom, up)
		if depth == 1 then
			-- special case
			turnRight()
			line(right-1, bottom, up)
			turnRight()
			turnRight()
			line(right-1, bottom, up)
			turnRight()
		elseif right == 1 then
			-- special case
			line(depth-1, bottom, up)
			turnRight()
			turnRight()
			line(depth-1, bottom, up)
			turnRight()
			turnRight()
		else
			line(1, bottom, up)

			local fullRoundtrip = math.floor(right/2)
		    for i = 1,fullRoundtrip-1 do
		        line(depth-2, bottom, up)
		        turnRight()
		        line(1, bottom, up)
		        turnRight()
		        line(depth-2, bottom, up)
		        turnLeft()
		        line(1, bottom, up)
		        turnLeft()
		    end
		    if right % 2 == 0 then
		        line(depth-2, bottom, up)
		        turnRight()
		        line(1, bottom, up)
		        turnRight()
		        line(depth-1, bottom, up)
		    else
		        line(depth-2, bottom, up)
		        turnRight()
		        line(1, bottom, up)
		        turnRight()
		        line(depth-2, bottom, up)
		        turnLeft()
		        line(1, bottom, up)
		        turnLeft()

		        line(depth-2, bottom, up)
		        turnRight()
		        turnRight()
				line(depth-1, bottom, up)
			end
	        turnRight()
	        line(right-1, bottom, up)
	        turnRight()
	    end
	end

	local heightStep = options.heightStep
	local nUpSteps = math.ceil(height/heightStep)

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

	for i = 1,nUpSteps do
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
			for i = 1,nGoUp do
				options.runBeforeHeightStep(funcs, isDownwards)
			    funcs.up()
				options.runAfterHeightStep(funcs, isDownwards)
			end
		end
	end
	for i = 1,nUpSteps-1 do
		local nGoUp = heightStep
		if i == 1 and heightStep == 3 then
			nGoUp = firstNGoUp
		end

		for j = 1,nGoUp do
			funcs.down()
		end
	end
	if heightStep == 3 and height % heightStep == 0 then
		funcs.down()
	end
	options.finish()
end

function digCuboidFuelRequired(depth, right, height)
	return math.ceil(depth / 3) * right * height + 200
end
function protectedDig(side)
	repeat
		local success, detail
		if dir == 'down' then success, detail = turtle.inspectDown()
		elseif dir == 'up' then success, detail = turtle.inspectUp()
		else success, detail = turtle.inspect() end

		if success and not arrayContains(turtlesIds, detail.name) then
			if dir == 'down' then turtle.digDown()
			elseif dir == 'up' then turtle.digUp()
			else turtle.dig() end
		else
			os.sleep(0.1)
		end
	until not success
end

function digCuboid(turtle, options)
	function dig()
		protectedDig('front')
	end
	function digDown()
		protectedDig('down')
		replaceLiquid(turtle, 'down')
	end
	function digUp()
		protectedDig('up')
		replaceLiquid(turtle, 'up')
	end

	function replaceLiquid(turtle, dir)
		local success, detail
		if dir == 'down' then success, detail = turtle.inspectDown()
		else  success, detail = turtle.inspectUp() end

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

	if turtle.getFuelLevel() < digCuboidFuelRequired(options.depth, options.right, options.height) then
		error("not enough fuel")
	end

	defaultArgs(options, {
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
			removeUselessItems(turtle)
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
			if isDownwards then digDown() 
			else digUp() end
			funcs.up()
			if isDownwards then digDown() 
			else digUp() end
		end,
		runBeforeHeightStep = function(funcs, isDownwards)
			if isDownwards then digDown() 
			else digUp() end
		end,
		runAfterHeightStep = function(funcs, isDownwards)
			if isDownwards then digDown() 
			else digUp() end
		end,
		finish = function()
			removeUselessItems(turtle, true)
			turtle.back()
		end,
		heightStep = 3,
	})

	travelCuboid(turtle, options)
end

function clearLava(turtle, options)
	defaultArgs(options, {
		depth = nil,
		right = nil,
		height = nil,
	})

	travelCuboid(turtle, options)
end
