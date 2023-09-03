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

function placeTurtle()
	selectTurtle()
	turtle.place()
end

-- mine2.digCuboid(turtle, {depth = depth, right = right, height = height})

local nChunksRight = 1
local nChunksHeight = 1

while true do
	local usedTurtles = nChunksHeight * nChunksRight

	local wouldUseIfChunkedRight = usedTurtles + nChunksHeight
	local wouldUseIfChunkedHeight = usedTurtles + nChunksRight

	local canChunkRight = math.floor(right / nChunksRight) > 1 and wouldUseIfChunkedRight <= nTurtles
	local canChunkHeight = math.floor(height / nChunksHeight) > 1 and wouldUseIfChunkedHeight <= nTurtles

	print(wouldUseIfChunkedHeight, wouldUseIfChunkedRight, canChunkHeight, canChunkRight)

	if wouldUseIfChunkedHeight < wouldUseIfChunkedRight and canChunkHeight then 
		nChunksHeight = nChunksHeight + 1
	elseif wouldUseIfChunkedRight < wouldUseIfChunkedHeight and canChunkRight then 
		nChunksRight = nChunksRight + 1
	else
		break
	end
end

print(nChunksRight .. "x" .. nChunksHeight)

local nGoBackHeight = 0

for ch = 1, nChunksHeight do

	local nGoBackRight = 0

	for cr = 1, nChunksRight do
		turtle.place()

		local nForChunkRight = math.floor(right / nChunksRight)
		if cr > right % nChunksRight then
			nForChunkRight = nForChunkRight + 1
		end

		if cr ~= nChunksRight then
			turtle.turnRight()
			nGoBackRight = nGoBackRight + nForChunkRight
			for i = 1, nForChunkRight do
				turtle.forward()
			end
			turtle.turnLeft()
		end

	end
	turtle.turnLeft()
	for i = 1, nGoBackRight do
		turtle.forward()
	end
	turtle.turnRight()

	local nForChunkHeight = math.floor(height / nChunksHeight)
	if ch > height % nChunksHeight then
		nForChunkHeight = nForChunkHeight + 1
	end

	if ch ~= nChunksHeight then
		nGoBackHeight = nGoBackHeight + nForChunkHeight
		for i = 1, nForChunkHeight do
			turtle.up()
		end
	end

end

for i = 1, nGoBackHeight do
	turtle.down()
end



-- for r in 1, do


-- end