local JUST_FLASHED = ...

term.clear()
term.setCursorPos(1, 1)

local childEnv = {}
setmetatable(childEnv, { __index = _ENV })
local newShell = {}
setmetatable(newShell, { __index = shell })
childEnv.shell = newShell
childEnv.multishell = multishell

function newShell.run(...)
	_G.require = childEnv.require
	_G.package = childEnv.package
	_ENV.require = childEnv.require
	_ENV.package = childEnv.package
	print("Run", package.path, require, ...)
	return shell.run(...)
end
function newShell.execute(...)
	print("execute", ...)
	return shell.execute(...)
end

local function setPaths(firmware)
	shell.setPath(shell.path() .. ":" .. firmware .. "/programs")
	local newRequire, newPackage = require('cc.require').make(childEnv, firmware .. "/apis")
	newPackage.path = newPackage.path .. ";" .. firmware .. "/apis"
	childEnv.require = newRequire
	childEnv.package = newPackage
	print('hello', newPackage.path)
end

if JUST_FLASHED ~= nil then
	print("Firmware flashed!")
	setPaths("/disk/firmware")
else
	setPaths("/firmware")
end

-- require = childEnv.require
-- package = childEnv.package
-- package = childEnv.package

-- require = childEnv.require

local controlApi = childEnv.require("controlApi")
if JUST_FLASHED == nil then
	controlApi.autoUpdate()
end

print("Running ControlAPI " .. controlApi.VERSION .. " on computer " .. os.getComputerID() .. ".")

parallel.waitForAny(
	function() controlApi.sourceTask(shell) end,
	function()
		if fs.exists("/autorun.lua") then
			-- shell.run("autorun")
			os.run(childEnv, "/autorun.lua")
		else
			os.run(childEnv, shell.resolveProgram("shell"))
		end
	end
)
