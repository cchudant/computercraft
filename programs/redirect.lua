local bag = table.pack(...)
local file, program = table.unpack(bag)

local f = fs.open(file, "w")

local realTerm = term.current()
local newTermObj = setmetatable({}, { __index = realTerm })
local newLine = true
function newTermObj.write(text)
    f.write(text)
    newLine = true
    return realTerm.write(text)
end
function newTermObj.setCursorPos(x, y)
    if newLine then
        f.write('\n')
        f.flush()
    end
    newLine = false
    return realTerm.setCursorPos(x, y)
end
term.redirect(newTermObj)

shell.run(program, table.unpack(bag, 3))

f.close()
