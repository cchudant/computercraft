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
	print("Run", ...)
	return shell.run(...)
end
function newShell.execute(...)
	print("execute", ...)
	return shell.execute(...)
end

local function setPaths(firmware)
	shell.setPath(shell.path() .. ":" .. firmware .. "/programs")
	local newRequire, newPackage = require('cc.require').make(childEnv, firmware .. "/apis")
	childEnv.require = newRequire
	childEnv.package = newPackage
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
local env = setmetatable(childEnv, { __index = _G })

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
			os.run(env, "/autorun.lua")
		else
			os.run(env, shell.resolveProgram("shell"))
		end
	end
)
