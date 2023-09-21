
local mine2 = require(".firmware.apis.mine2")
local startedPath = "started"
local donePath    = "done"

function resetFile()
    save_format = {
        turnRight = false,
        turnLeft  = false,
        digUp     = false,
        placeUp   = false,
        forward   = false
    }

    startedBlobW = fs.open(startedPath, "w")
    doneBlobW = fs.open(donePath, "w")

    startedBlobW.write(textutils.serialise(save_format))
    doneBlobW.write(textutils.serialise(save_format))

    startedBlobW.close()
    doneBlobW.close()

    return
end

function safe(turtle, instruction)
    startedBlobR = fs.open(startedPath, "r")
    doneBlobR = fs.open(donePath, "r")

    started = textutils.unserialise(startedBlobR.readAll())
    done = textutils.unserialise(doneBlobR.readAll())

    startedBlobR.close()
    doneBlobR.close()

    instructions = {
        turnRight = turtle.turnRight,
        turnLeft  = turtle.turnLeft,
        digUp     = turtle.digUp,
        placeUp   = turtle.placeUp,
        forward   = turtle.forward,
    }

    instructionStarted = started[instruction]
    instructionDone = done[instruction]

    print(instruction, instructionStarted, instructionDone)

    if instructionStarted == true and instructionDone == true then
        return
    end
    
    if instructionStarted == true and instructionDone == false then
        -- if instruction == "digUp" then
        --     instructions[instruction]()
        -- else
        --     while not instructions[instruction]() do end
        -- end

        done[instruction] = true
        doneBlobW = fs.open(donePath, "w")
        doneBlobW.write(textutils.serialise(done))
        doneBlobW.close()
        
        return
    end

    if instructionStarted == false and instructionDone == false then
        started[instruction] = true
        startedBlobW = fs.open(startedPath, "w")
        startedBlobW.write(textutils.serialise(started))
        startedBlobW.close()

        if instruction == "digUp" then
            instructions[instruction]()
        else
            while not instructions[instruction]() do end
        end

        done[instruction] = true
        doneBlobW = fs.open(donePath, "w")
        doneBlobW.write(textutils.serialise(done))
        doneBlobW.close()
        
        return
    end
end

function applyRules(turtle)

    success, block = turtle.inspectUp()
    if block.name == nil or block.name == "minecraft:white_wool" then
        while not mine2.selectItem(turtle, "minecraft:black_wool") do end
        safe(turtle, "turnRight")
        safe(turtle, "digUp")
        safe(turtle, "placeUp")
        safe(turtle, "forward")
    end
    if block.name == "minecraft:black_wool" then
        while not mine2.selectItem(turtle, "minecraft:white_wool") do end
        safe(turtle, "turnLeft")
        safe(turtle, "digUp")
        safe(turtle, "placeUp")
        safe(turtle, "forward")
    end
    resetFile()
end

function refuel(turtle)
    if turtle.getFuelLevel() < 100 then
        print("refueling ...")
        while not mine2.selectItem(turtle, "minecraft:dried_kelp_block") do end
        item = turtle.getItemDetail()
        for i=1,item.count do
            turtle.refuel()
        end
        print("refueling done")
    end
end

while true do
    refuel(turtle)
    applyRules(turtle)
end

-- resetFile()
