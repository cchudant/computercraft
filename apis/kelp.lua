function placeLine(turtle, length)
    for i = 1,length do
        turtle.placeDown()
        turtle.forward()
    end
    turtle.placeDown()
end

function border(turtle, depth, right)
    placeLine(turtle, depth)
    turtle.turnRight()
    placeLine(turtle, right)
    turtle.turnRight()
    placeLine(turtle, depth)
    turtle.turnRight()
    placeLine(turtle, right)
end

function flatRectangle(turtle, depth, right)
    for i = 1, right do
        placeLine(turtle, depth)
        turtle.turnRight()
        turtle.turnRight()
        placeLine(turtle, depth)
        turtle.turnLeft()
        if i ~= right then
            turtle.forward()
        end
        turtle.turnLeft()
    end
end