local function mkdirs(path)
    if path == '' then return end
    mkdirs(path)
    fs.makeDir(path)
end
local function arrayContains(arr, elem)
    for i, el in ipairs(arr) do
        if elem == el then
            return true
        end
    end
    return false
end
local function copyFiles(path, dest, predicate)
    if predicate ~= nil and not predicate(path, dest) then
        return
    end
    if fs.exists(dest) then
        fs.delete(dest)
    end
    if fs.isDir(path) then
        for _, el in ipairs(fs.list(path)) do
            copyFiles(fs.combine(path, el), fs.combine(dest, el), predicate)
        end
    else -- is file
        mkdirs(fs.getDir(dest))
        fs.copy(path, dest)
    end
end

local ignoreList = {}
local f = fs.open('/disk/firmware/.deployignore', 'r')
if f ~= nil then
    while true do
        local line = f.readLine()
        if line == nil then break end
        table.insert(ignoreList, line)
    end
    f.close()
end

copyFiles('/disk/firmware', '/firmware', function(path, dest)
    if arrayContains(ignoreList, path) or arrayContains(ignoreList, fs.getName(path)) then
        return false
    end
    if arrayContains(ignoreList, dest) or arrayContains(ignoreList, fs.getName(dest)) then
        return false
    end
    return true
end)
copyFiles('/disk/firmware/computerStartup.lua', '/startup.lua')

shell.run('startup JUST_FLASHED')
