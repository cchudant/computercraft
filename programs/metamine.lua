os.loadAPI("/firmware/apis/mine2.lua")

local depth, right, height = ...
if depth == nil or right == nil or height == nil then
	print("usage: metamine <depth> <right> <height>")
	return
end

TURTLE1 = "computercraft:turtle_normal"
TURTLE2 = "computercraft:turtle_advanced"

local nTurtles = 0
for slot=1,16 do
	local detail = turtle.getItemDetail(slot)
	if detail ~= nil and (detail.name == TURTLE1 or detail.name == TURTLE2) then
		nTurtles = nTurtles + detail.count
	end
end

function selectTurtle()
	for slot=1,16 do
		local detail = turtle.getItemDetail(slot)
		if detail ~= nil and (detail.name == TURTLE1 or detail.name == TURTLE2) then
			turtle.select(slot)
			return true
		end
	end
	return false
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)

print("I have " .. nTurtles .. " turtles.")

function placeTurtle(side, depth, right, height, turn)
	selectTurtle()
	if side == 'front' then while not turtle.place() do end
	elseif side == 'top' then while not turtle.placeUp() do end
	else while not turtle.placeDown() do end end

	local t
	repeat
		sleep(0.1)
		t = peripheral.wrap(side)
	until t ~= nil 
	t.turnOn()
	local id = t.getID()

	print("waiting for " .. id)
	controlApi.waitForReady(id, 5)

	print(side, depth, right, height)
	local turtle = controlApi.connectControl(id).turtle
	if turn == 'left' then
		turtle.turnLeft()
	elseif turn == 'right' then
		turtle.turnRight()
	elseif turn == 'back' then
		turtle.turnLeft()
		turtle.turnLeft()
	end

	return function()
		mine2.digCuboid(turtle, {
			depth = depth, right = right, height = height,
			prepareSameLevel = function() end,
			prepareUpOne = function(funcs)
				if isDownwards then digDown() 
				else digUp() end
				funcs.up()
				if isDownwards then digDown() 
				else digUp() end
			end,
			finish = function() end
		})
	end
end

function findBest(nChunksRight, nChunksHeight)
	local usedTurtles = nChunksHeight * nChunksRight

	local wouldUseIfChunkedRight = usedTurtles + nChunksHeight
	local wouldUseIfChunkedHeight = usedTurtles + nChunksRight

	local canChunkRight = math.ceil(right / nChunksRight) > 1 and wouldUseIfChunkedRight <= nTurtles
	local canChunkHeight = math.ceil(height / nChunksHeight) > 1 and wouldUseIfChunkedHeight <= nTurtles

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

print(nChunksRight .. "x" .. nChunksHeight)

local nGoBackHeight = 0

local turtles = {}

function gnForChunkHeight(ch)
	local nForChunkHeight = math.floor(height / nChunksHeight)
	if ch <= height % nChunksHeight then
		nForChunkHeight = nForChunkHeight + 1
	end
	return nForChunkHeight
end
function gnForChunkRight(cr)
	local nForChunkRight = math.floor(right / nChunksRight)
	if cr <= right % nChunksRight then
		nForChunkRight = nForChunkRight + 1
	end
	return nForChunkRight
end

turtle.forward()

for ch = 1, nChunksHeight-1 do
	local nForChunkHeight = gnForChunkHeight(ch)
	for k = 1, nForChunkHeight do
		turtle.up()
	end
end

for ch = nChunksHeight, 1, -1 do
	local nForChunkHeight = gnForChunkHeight(ch)

	if ch ~= nChunksHeight then
		turtle.down()
		-- place up
		print('cr', 1, 'ch', ch)
		table.insert(turtles, placeTurtle('top', depth, gnForChunkRight(1), nForChunkHeight, 'front'))
		--

		print(ch)

		for k = 2, nForChunkHeight do
			turtle.down()
		end
	end

	turtle.turnRight()
	for cr = 1, nChunksRight-1 do
		local nForChunkRight = gnForChunkRight(cr)
		for k = 1, nForChunkRight do
			turtle.forward()
		end
	end
	turtle.back()
	-- place forward
	table.insert(turtles, placeTurtle('front', depth, gnForChunkRight(nChunksRight), nForChunkHeight, 'left'))
	--
	local nForChunkRight = gnForChunkRight(1)
	for k = 2, nForChunkRight do
		turtle.back()
	end

	for cr = nChunksRight-1, 2, -1 do
		local nForChunkRight = gnForChunkRight(cr)
		turtle.back()
		-- place forward
		print('cr', cr, 'ch', ch)
		table.insert(turtles, placeTurtle('front', depth, nForChunkRight, nForChunkHeight, 'left'))
		--
		for k = 2, nForChunkRight do
			turtle.back()
		end
	end
	turtle.turnLeft()
end
local nForChunkRight = gnForChunkRight(1)
local nForChunkHeight = gnForChunkHeight(1)

turtle.back()
-- place forward
print('cr', 1, 'ch', 1)
table.insert(turtles, placeTurtle('front', depth, nForChunkRight, nForChunkHeight, 'back'))
--