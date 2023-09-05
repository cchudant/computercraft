
-- local depth, right, height = ...

-- print("DEPTH:  " .. depth)
-- print("RIGHT:  " .. right)
-- print("HEIGHT:  " .. height)

-- depth = tonumber(depth)
-- right = tonumber(right)
-- height = tonumber(height)

-- fuel_to_have = depth * right * (height / 3) + 500

-- print("Fuel level: " .. turtle.getFuelLevel() .. "/" .. fuel_to_have)

-- if turtle.getFuelLevel() < fuel_to_have then
-- 	print("Unsufficient fuel! Trying to refuel...")
-- 	for i = 1,16 do
-- 		if turtle.getItemCount(i) > 0 then
-- 			turtle.select(i)
-- 			while turtle.refuel(1)
-- 					and turtle.getFuelLevel() < fuel_to_have do end
-- 		end
-- 	end
-- 	turtle.select(1)
-- 	print("Fuel level: " .. turtle.getFuelLevel() .. "/" .. fuel_to_have)
-- 	if turtle.getFuelLevel() < fuel_to_have then
-- 		print("Please provide fuel and try again")
-- 		return 1
-- 	end
-- end

function selectItem(turtle, item)
	for slot=1,16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil and detail.name == item then
			turtle.select(slot)
			return true
		end
	end
	return false
end
local _toRemove = {
	"minecraft:andesite",
	"minecraft:cobbled_deepslate",
	"minecraft:cobblestone",
	"minecraft:andesite",
	"minecraft:granite",
	"minecraft:diorite",
	"minecraft:stone",
	"minecraft:gravel",
	"minecraft:flint",
	"minecraft:tuff",
	"minecraft:dirt"
}
function removeUselessItems(turtle)
	local stacksAllowed = 2
	for slot=1,16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil then
			for _,v in ipairs(_toRemove) do
				if v == detail.name then
					stacksAllowed = stacksAllowed - 1
					break
				end
			end
		end
		if stacksAllowed == 0 then
			break
		end
	end
	if stacksAllowed <= 0 then
		for slot=1,16 do
			local detail = turtle.getItemDetail(slot)
			local found = false
			if detail ~= nil then
				for _,v in ipairs(_toRemove) do
					if v == detail.name then
						found = true
						break
					end
				end
			end
			if found then
				turtle.select(slot)
				turtle.dropDown()
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
	function up()
		if options.height < 0 then turtle.down()
		else turtle.up() end
	end
	function down()
		if options.height < 0 then turtle.up()
		else turtle.down() end
	end

	funcs = {
		turnRight = turnRight,
		turnLeft = turnLeft,
		up = up,
		down = down,
	}

	defaultArgs(options, {
		depth = nil,
		right = nil,
		height = nil,
		runBeforeEveryStep = function(funcs) end,
		runAfterEveryStep = function(funcs, bottom, up) end,
		prepareSameLevel = function(funcs, firstBottom, firstUp)
			turtle.forward()
		end,
		prepareUpOne = function(func, isDownwards)
			turtle.forward()
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
	        turtle.forward()
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

function digCuboid(turtle, options)
	function dig()
		while turtle.dig() do end
	end
	function digDown()
		while turtle.digDown() do end
	end
	function digUp()
		while turtle.digUp() do end
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
			turtle.forward()
			if bottom then
				digDown()
			end
			if up then
				digUp()
			end
		end,
		prepareUpOne = function(funcs, isDownwards)
			dig()
			turtle.forward()
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
			removeUselessItems(turtle)
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
