
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
		runBeforeHeightStep = function(funcs) end,
		runAfterHeightStep = function(funcs) end,
		heightStep = 1,
	})

	if options.heightStep ~= 1 and options.heightStep ~= 3 then
		error("heightStep must be 1 or 3")
	end

	if options.depth == nil then error("No depth bound for cubeoid") end
	if options.right == nil then error("No right bound for cubeoid") end
	if options.height == nil then error("No height bound for cubeoid") end

	local depth = options.depth
	if depth < 0 then error("Depth cannot be negative") end
	local right = math.abs(options.right) 
	local height = math.abs(options.height)

	local heightStep = options.heightStep

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
		line(depth-2, bottom, up)
	    if right % 2 == 0 then
		    turnRight()
		    line(1, bottom, up)
		    turnRight()
		    line(depth-1, bottom, up)
		    turnRight()
		else
			-- have to go back a bit
		    turnRight()
			for i = 1,depth-2 do
				turtle.forward()
			end
		    line(1, bottom, up)
		    turnRight()
		end
	    line(right-1, bottom, up)
	    turnRight()
	end

	if heightStep == 3 and height % heightStep == 0 then
		options.prepareUpOne(funcs)
	else
		options.prepareSameLevel(funcs)
	end

	local nUpSteps = math.ceil(height/heightStep)

	for i = 1,nUpSteps do
		if heightStep == 3 then
			local bottom = i ~= 1 or height % heightStep == 0
			local up = i ~= 1 or (height % heightStep == 0 or height % heightStep == 2)
			layer(bottom, up)
		else
			layer(false, false)
		end

		if i < height/heightStep then
			for i = 1,heightStep do
				options.runBeforeHeightStep(funcs)
			    funcs.up()
				options.runAfterHeightStep(funcs)
			end
		end
	end
	for i = 1,height-heightStep do
		funcs.down()
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
		runAfterHeightStep = function(funcs)
			digUp()
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
