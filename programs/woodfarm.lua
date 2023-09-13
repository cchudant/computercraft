depth = 15
right = 3


function farm()
	for d=1,depth
end

while true do
	while mine2.selectItem(turtle, 'minecraft:sugar_cane') do
		turtle.dropUp()
	end

	farm()
	while mine2.selectItem(turtle, 'minecraft:sugar_cane') do
		turtle.dropUp()
	end

	os.sleep(60*5)
end