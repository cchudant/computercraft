
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

resetFile()