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
	for i=1,height do
		turtle.up()
	end
	kelp.suckRectangle(turtle, depth, right)
	for i=1,height do
		turtle.down()
	end
end

for i = 0,1 do
	for j = 0,1 do
		turtle.forward()
		for k =1,i do
			if k== 1 then
				turtle.dig()
				turtle.forward()
			end
			kelp.digLine(2)
		end
		turtle.turnRight()
		for k =1,j do
			if k== 1 then
				turtle.dig()
				turtle.forward()
			end
			kelp.digLine(2)
		end
		turtle.turnLeft()
		mineKelp(turtle, 2, 2, height)
		turtle.turnLeft()
		for k =1,j do
			if k== 1 then
				turtle.dig()
				turtle.forward()
			end
			kelp.digLine(8)
		end
		turtle.turnLeft()
		for k =1,i do
			if k== 1 then
				turtle.dig()
				turtle.forward()
			end
			kelp.digLine(8)
		end
		turtle.forward()
		placeInChest(turtle)
		turtle.turnRight()
        turtle.turnRight()
	end
end
		