local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local childEnv = {}
setmetatable(childEnv, { __index = _ENV })
local newShell = {}
setmetatable(newShell, { __index = shell })
childEnv.shell = nil -- shell
childEnv.multishell = nil -- multishell

local firmwareDir
if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	firmwareDir = "/disk/firmware"
else
	firmwareDir = "/firmware"
end

shell.setPath(shell.path() .. ":" .. firmwareDir .. "/programs")

-- fix require importing
-- this is a hack

local module = require("cc.require")
local newModule = setmetatable({ hello = '999999' }, { __index = module })
function newModule.make(...)
	local r, p = module.make(...)
	print("MAKE!!")
	p.loaded["cc.require"] = newModule
	p.path = p.path .. ";" .. firmwareDir .. "/apis/?.lua;" .. firmwareDir .. "/apis/?;" .. firmwareDir .. "/apis/?/init.lua"
	return r, p
end

local newRequire, newPackage = newModule.make(childEnv, firmwareDir .. "/apis")
childEnv.require = newRequire
childEnv.package = newPackage
require, package = newRequire, newPackage

local originalDofile = dofile
function newDofile(filename)
	if filename == "rom/modules/main/cc/require.lua" then
		return newModule
	end

	return originalDofile(filename)
end
childEnv.dofile = newDofile
dofile = newDofile

-- end hack



local controlApi = childEnv.require("controlApi")
if JUST_FLASHED == nil then
	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi.sourceTask(shell) end,
	function()
		if fs.exists("/autorun.lua") then
			os.run(childEnv, "/rom/programs/shell.lua", "/autorun.lua")
		else
			os.run(childEnv, "/rom/programs/shell.lua")
		end
	end
)
