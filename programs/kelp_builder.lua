os.loadAPI("/firmware/apis/kelp.lua")

local depth, right, height = ...
if depth == nil or right == nil or height == nil then
	print("usage: mine2 <depth> <right> <height>")
	return
end

depth = tonumber(depth)
right = tonumber(right)
height = tonumber(height)

function placeInChest(turtle)
	turtle.turnLeft()
	turtle.turnLeft()
	for i=1,16 do
		turtle.select(i)
		turtle.drop()
	end
	turtle.turnLeft()
	turtle.turnLeft()
end

function mineKelp(turtle, depth, right, height)
	kelp.digRectangle(turtle, depth, right)
	placeInChest(turtle)
	for i=1,height do
		turtle.up()
	end
	kelp.suckRectangle(turtle, depth, right)
	for i=1,height do
		turtle.down()
	end
	placeInChest(turtle)
end

mineKelp(turtle, depth, right, height)