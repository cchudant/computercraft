local control = require(".firmware.apis.control")
local util = require('.firmware.apis.util')
local mine2 = require(".firmware.apis.mine2")

local FUEL = 'minecraft:dried_kelp_block'

local depth, right, height, nTurtles, facing = ...

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)
nTurtles = tonumber(nTurtles)

if depth < 0 then
	print("depth cannot be negative")
	return
end

if depth == nil or right == nil or height == nil or nTurtles == nil then
	print("usage: metamine <depth> <right> <height> <turtles> <facing>")
	return
end

if facing ~= 'south' and facing ~= 'north' and facing ~= 'west' and facing ~= 'east' then
	print("invalid facing")
	print("usage: metamine2 <depth> <right> <height> <turtles> <facing>")
	return
end

local TURTLE1 = "computercraft:turtle_normal"
local TURTLE2 = "computercraft:turtle_advanced"
local SHULKER_BOX = "minecraft:yellow_shulker_box"

-- print("I have " .. nTurtles .. " turtles.")
if nTurtles == 0 then
	print("Not enough turtles, need at least one")
	return
end

local function turtleFinishTask(id)
	control.waitForReady(id, -1, 'metamine:back')

	print(id .. ' break')
	local success, detail = turtle.inspect()
	if not success or (detail.name ~= TURTLE1 and detail.name ~= TURTLE2) then
		error("Error: " .. id .. " not where expected")
	end

	while true do
		local sucked = false

		while turtle.suck() do sucked = true end

		if not sucked then break end

		turtle.turnLeft()
		turtle.turnLeft()

		local succ, detail = turtle.inspect()
		if succ and detail.name == 'minecraft:shulker_box' then
			for i = 1,16 do 
				local item = turtle.getItemDetail(i)
				if item ~= nil and item.name ~= FUEL and item.name ~= TURTLE1 and item.name ~= TURTLE2 and item.name ~= SHULKER_BOX then
					turtle.select(i)
					turtle.drop()
				end
			end
		end

		turtle.turnRight()
		turtle.turnRight()
	end

	turtle.dig()

	print(id .. ' finished')

	while mine2.selectItem(turtle, {TURTLE1, TURTLE2}) do
		local succ, detail = turtle.inspectUp()
		if succ and detail.name ~= SHULKER_BOX then
			turtle.digUp()
			succ, detail = turtle.inspectUp()
		end

		if not succ then
			for slot = 1, 16 do
				local detail = turtle.getItemDetail(slot)
				if
					detail ~= nil and detail.name == SHULKER_BOX and
					usedShulkers[slot] == true
				then
					turtle.select(slot)
					turtle.placeUp()
				end
			end
		end

		if not turtle.dropUp() then
			-- shulker is full

			-- find empty slot
			for slot = 1, 16 do
				local detail = turtle.getItemDetail(slot)
				if detail == nil then
					turtle.select(slot)
					turtle.digUp()
					usedShulkers[slot] = nil
				end
			end
		end
	end
end

local function turtleTask(id, nLeft, offsetDepth, offsetRight, offsetHeight, depth, right, height)
	local control_ = control.connectControl(id)
	local remoteTurtle = control_.turtle

	print('left', nLeft)
	for i = 1,nLeft do
		remoteTurtle.turnLeft()
	end
	control.protocolSend(id, 'metamine:start')

	print(id .. ' started')
end


local usedShulkers = {}

local function placeTurtle(offsetDepth, offsetRight, offsetHeight, depth, right, height)

	-- find a turtle in shulker boxes

	while not mine2.selectItem(turtle, {TURTLE1, TURTLE2}) do
		local succ, detail = turtle.inspectUp()

		if succ and detail.name ~= SHULKER_BOX then
			turtle.digUp()
			succ, detail = turtle.inspectUp()
		end

		if not succ then
			for slot = 1, 16 do
				local detail = turtle.getItemDetail(slot)
				if
					detail ~= nil and detail.name == SHULKER_BOX and
					usedShulkers[slot] ~= true
				then
					turtle.select(slot)
					turtle.placeUp()
				end
			end
		end

		if not turtle.suckUp() then
			-- shulker is empty

			-- find empty slot
			for slot = 1, 16 do
				local detail = turtle.getItemDetail(slot)
				if detail == nil then
					turtle.select(slot)
					turtle.digUp()
					usedShulkers[slot] = true
				end
			end
		end
	end

	while not turtle.place() do end

	local t
	repeat
		os.sleep(0.1)
		t = peripheral.wrap('front')
	until t ~= nil 
	t.turnOn()
	local id = t.getID()

	local success, detail = turtle.inspect()
	if not success then error(detail) end

	local facings = {
		south = 0,
		east = 1,
		north = 2,
		west = 3,
	}

	repeat
		print("waiting for " .. id)
	until control.waitForReady(id, 15)

	local fuelRequired = mine2.digCuboidFuelRequired(depth, right, height) + (depth + math.abs(right) + math.abs(height))*2 + 100

	control.protocolSend(id, 'shellRun', "/firmware/programs/metamineCb "..offsetDepth.." "..offsetRight.." "..offsetHeight.." "..depth.." "..right.." "..height.." "..fuelRequired)
	local function receiveGive()
		while true do
			control.protocolReceive('metamine:refuelGive', id)

			print("refueling " .. id)
			local displayed = 1
			while not mine2.selectItem(turtle, FUEL) do
				os.sleep(0.1)
				if displayed < 3 then
					print("please provide fuel")
					displayed = displayed + 1
				end
			end
			turtle.drop()
		end
	end
	local function receiveDone()
		control.protocolReceive('metamine:refuelDone', id)
	end

	parallel.waitForAny(receiveDone, receiveGive)
	while turtle.suck() do end

	local nLeft = (facings[facing] - facings[detail.state.facing]) % 4
	return { id, nLeft, offsetDepth, offsetRight, offsetHeight, depth, right, height }
end

local function findBest(nChunksRight, nChunksHeight)
	local usedTurtles = nChunksHeight * nChunksRight

	local wouldUseIfChunkedRight = usedTurtles + nChunksHeight
	local wouldUseIfChunkedHeight = usedTurtles + nChunksRight

	local canChunkRight = math.ceil(math.abs(right) / nChunksRight) > 1 and wouldUseIfChunkedRight <= nTurtles
	local canChunkHeight = math.ceil(math.abs(height) / nChunksHeight) > 1 and wouldUseIfChunkedHeight <= nTurtles

	if canChunkRight and canChunkHeight then
		local nChunksRight1, nChunksHeight1 = findBest(nChunksRight + 1, nChunksHeight)
		local nChunksRight2, nChunksHeight2 = findBest(nChunksRight, nChunksHeight + 1)
		if nChunksRight1 * nChunksHeight1 >= nChunksRight2 * nChunksHeight2 then
			return nChunksRight1, nChunksHeight1
		else
			return nChunksRight2, nChunksHeight2
		end
	elseif canChunkRight then
		return findBest(nChunksRight + 1, nChunksHeight)
	elseif canChunkHeight then
		return findBest(nChunksRight, nChunksHeight + 1)
	end

	return nChunksRight, nChunksHeight
end

local nChunksRight, nChunksHeight = findBest(1, 1)

print("Tiling found is " .. nChunksRight .. "x" .. nChunksHeight)

local nGoBackHeight = 0

local turtles = {}

local function gnForChunkHeight(ch)
	local nForChunkHeight = math.floor(math.abs(height) / nChunksHeight)
	if ch <= math.abs(height) % nChunksHeight then
		nForChunkHeight = nForChunkHeight + 1
	end
	if height < 0 then nForChunkHeight = -nForChunkHeight end
	return nForChunkHeight
end
local function gnForChunkRight(cr)
	local nForChunkRight = math.floor(math.abs(right) / nChunksRight)
	if cr <= math.abs(right) % nChunksRight then
		nForChunkRight = nForChunkRight + 1
	end
	if right < 0 then nForChunkRight = -nForChunkRight end
	return nForChunkRight
end

local allTurtles = {}

util.parallelGroup(function(addTask)
	while turtle.dig() do end
	mine2.removeUselessItems(turtle, true)

	for ch = nChunksHeight, 1, -1 do
		for cr = nChunksRight, 1, -1 do
			local offsetDepth = 0
			local offsetRight = 0
			local offsetHeight = 0
			for i = 1, ch-1 do
				local nForChunkHeight = gnForChunkHeight(i)
				offsetHeight = offsetHeight + nForChunkHeight
			end
			for i = 1, cr-1 do
				local nForChunkRight = gnForChunkRight(i)
				offsetRight = offsetRight + nForChunkRight
			end
			local turtleObj = placeTurtle(offsetDepth, offsetRight, offsetHeight, depth, gnForChunkRight(cr), gnForChunkHeight(ch))
			table.insert(allTurtles, turtleObj)
			addTask(function()
				turtleTask(table.unpack(turtleObj))
			end)
		end
	end
end)
-- launchTurtlesTask({startTask}, nChunksHeight * nChunksRight + 1)

local tasks = {}
for _, turtle in ipairs(allTurtles) do
	table.insert(tasks, function() turtleFinishTask(table.unpack(turtle)) end)
end

parallel.waitForAll(table.unpack(tasks))

print("all done")

-- remove last shulker on top
for slot = 1, 16 do
	local detail = turtle.getItemDetail(slot)
	if detail == nil then
		turtle.select(slot)
		turtle.digUp()
		usedShulkers[slot] = nil
	end
end
