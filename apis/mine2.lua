
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

-- depth = 8
-- right = 8 -- must be pair
-- height = 9 -- must be multiple of 3

local function select_item(item)
	for slot=1,16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil and detail.name == item then
			turtle.select(slot)
			return true
		end
	end
	return false
end

function defaultArgs(options, defaults)
	for k,v in pairs(defaults) do
		if options[k] == nil then
			options[k] = defaults[k]
		end
	end
end

function travelCuboid(turtle, options)
	print("Hello2")

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
		prepareSameLevel = function(funcs)
			turtle.forward()
		end,
		prepareUpOne = function(funcs)
			turtle.forward()
			funcs.up()
		end,
		runBeforeHeightStep = function(funcs, isDownwards) end,
		runAfterHeightStep = function(funcs, isDownwards) end,
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
	        turnRight()
			for i = 1,depth-2 do
				turtle.forward()
			end
	        line(1, bottom, up)
		end
        turnRight()
        line(right-1, bottom, up)
        turnRight()
	end

	local heightStep = options.heightStep

	if heightStep == 3 and height % heightStep == 0 then
		options.prepareUpOne(funcs)
	else
		options.prepareSameLevel(funcs)
	end

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

	for i = 1,nUpSteps do
		print("layer")
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
	turtle.back()
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
		end,
		prepareSameLevel = function(funcs)
			dig()
			turtle.forward()
		end,
		prepareUpOne = function(funcs)
			dig()
			turtle.forward()
			digUp()
			funcs.up()
			digUp()
		end,
		runBeforeHeightStep = function(funcs, isDownwards)
			if isDownwards then digDown() 
			else digUp() end
		end,
		runAfterHeightStep = function(funcs, isDownwards)
			if isDownwards then digDown() 
			else digUp() end
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
