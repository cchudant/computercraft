

function digLine(turtle, length)
    print(turtle)
    for i = 1,length do
        turtle.dig()
        if i ~= length then
            turtle.forward()
        end
    end
end

function suckLine(turtle, length)
    for i = 1,length do
        turtle.suckDown()
        if i ~= length then
            turtle.forward()
        end
    end
end

function digRectangle(turtle, depth, right)
    for i = 1, right do
        print(turtle)
        digLine(turtle, depth)
        turtle.turnRight()
        turtle.turnRight()
        digLine(turtle, depth)
        turtle.turnLeft()
        if i ~= right then
            turtle.forward()
        end
        turtle.turnLeft()
    end
    turtle.turnLeft()
    digLine(turtle, right)
    turtle.turnRight()
end

function suckRectangle(turtle, depth, right)
    for i = 1, right do
        suckLine(turtle, depth)
        turtle.turnRight()
        turtle.turnRight()
        suckLine(turtle, depth)
        turtle.turnLeft()
        if i ~= right then
            turtle.forward()
        end
        turtle.turnLeft()
    end
    turtle.turnLeft()
    suckLine(turtle, right)
    turtle.turnRight()
end