local util = require(".firmware.apis.util")

local control = {}

control.VERSION_MAJOR = 2

if fs ~= nil then

	local file = fs.open("/firmware/commits", "r") --[[@as ReadHandle]]
	local commits = file.readAll()
	commits = string.gsub(commits --[[@as string]], "%s+", "")
	
	control.VERSION_MINOR = tonumber(commits)
	
else
	control.VERSION_MINOR = 2 -- this is for unit tests
end

control.VERSION = control.VERSION_MAJOR .. '.' .. control.VERSION_MINOR
control.PROTOCOL_STRING = 'CONTROL'

local function isVersionGreater(versionMajorA, versionMinorA, versionMajorB, versionMinorB)
	return versionMajorA > versionMajorB or
			(versionMajorA == versionMajorB and versionMinorA > versionMinorB)
end

local _isSetup = false
local function setupModem()
	if _isSetup then return end
	_isSetup = true

	for _,per in ipairs(peripheral.getNames()) do
		local a, b = peripheral.getType(per)
		if a == "modem" and b == nil then -- no wired modems :)
			rednet.open(per)
		end
	end
end

---Block until a matching message is received
---@param command string? command or nil if we want to match any commands
---@param sender number? computerid of the sender or nil if we want to match all of them
---@param timeout number? timeout in seconds - if nil, it will block forever
---@param nonce string? optionally match a specific nonce
---@return any? args the received arguments or nil if timeout expired
---@return string? command the received command
---@return number? sender the sender who sent this message
---@return string? nonce the received nonce
function control.protocolReceive(command, sender, timeout, nonce)
	setupModem()
	local startTime = os.clock()
	local elapsed = 0
	while true do
		local toWait = nil
		if timeout ~= nil then
			toWait = timeout - elapsed
		end

		---@diagnostic disable-next-line: param-type-mismatch
		local snd, message = rednet.receive(toWait)

		if type(message) == 'table' and message.protocol == control.PROTOCOL_STRING and
				(sender == nil or sender == snd) and
				(command == nil or message.command == command) and
				(nonce == nil or message.nonce == nonce) then
			return message.args, message.command, snd, message.nonce
		end

		elapsed = os.clock() - startTime
		if timeout ~= nil and elapsed > timeout then
			break
		end
	end
end

---Send a message to a client
---@param clientID number client id
---@param command string command
---@param args any? args
---@param nonce string? nonce
function control.protocolSend(clientID, command, args, nonce)
	setupModem()
	rednet.send(clientID, {
		protocol = control.PROTOCOL_STRING,
		command = command,
		args = args,
		nonce = nonce,
	})
end

---Broadcast a message
---@param command string command
---@param args any? args
---@param nonce string? nonce
function control.protocolBroadcast(command, args, nonce)
	setupModem()
	---@diagnostic disable-next-line: missing-parameter
	rednet.broadcast({
		protocol = control.PROTOCOL_STRING,
		command = command,
		args = args,
		nonce = nonce,
	})
end

-- A task that serves Remote Term requests
local function remoteTermSourceTask(shell)
	local clientid
	local nonce

	_, _, clientid, nonce = control.protocolReceive('connectTerm')
	control.protocolSend(clientid --[[@as number]], 'connectedTerm', nil, nonce)

	local methods = {
		"write", "blit", "clear", "clearLine", "getCursorPos", "setCursorPos", "setCursorBlink",
		"isColor", "isColour", "getSize", "scroll", "redirect", "setTextColor", "setTextColour",
		"getTextColor", "getTextColour", "setBackgroundColor", "setBackgroundColour",
		"getBackgroundColor", "getBackgroundColour"
	}

	local function taskSend()
		while true do
			term.clear()
			term.setCursorPos(1, 1)

			local termObj = {}
			local native = term.native()

			for _,method in ipairs(methods) do
				termObj[method] = function(...)
					control.protocolSend(clientid --[[@as number]], 'term', {
						method = method,
						args = {...},
					}, nonce)
					return native[method](...)
				end
			end

			term.redirect(termObj)
			shell.run("shell")
			term.redirect(native)

			control.protocolSend(clientid --[[@as number]], 'endTerm', nil, nonce)
			clientid = nil
		end
	end
	local function taskReceive()
		while true do
			local args = control.protocolReceive('termEvent', clientid, nil, nonce)
			os.queueEvent(args.event, table.unpack(args.args))
		end
	end
	parallel.waitForAny(taskReceive, taskSend)
end

---A task that connects to a Remote Term client by id
---@param sourceid number
function control.remoteTermClient(sourceid)
	local nonce
	local function taskReceiveEnd()
		control.protocolReceive('endTerm', sourceid, nil, nonce)
	end
	local function taskReceive()
		term.clear()
		term.setCursorPos(1, 1)

		while true do
			local args = control.protocolReceive('term', sourceid, nil, nonce)
			local ret = table.pack(
				term[args.method](table.unpack(args.args))
			)
		end
	end
	local function taskSend()
		while true do
			local bag = {os.pullEvent()}
			local event = bag[1]
			local args = {}
			for i = 2,#bag do
				args[i-1] = bag[i]
			end

			local all_events = {
				"char", "key", "key_up", "paste", "terminate",
				"mouse_click", "mouse_up", "mouse_scroll", "mouse_drag",
				"term_resize"
			}

			for _,ev in pairs(all_events) do
				if ev == event and sourceid ~= nil then
					control.protocolSend(sourceid, 'termEvent', {
						event = ev,
						args = args,
					}, nonce)
					break
				end
			end
		end
	end

	local _, _, _, nonce_ = control.protocolSend(sourceid, 'connectTerm')
	nonce = nonce_
	control.protocolReceive('connectedTerm', nil, nil, nonce)

	parallel.waitForAny(taskReceive, taskSend, taskReceiveEnd)
end

local function remoteControlTask(shell)
	local control_commands = {
		identify = function(arg)
			return {
				id = os.getComputerID(),
				label = os.getComputerLabel(),
				-- location = {_getLocation()},
				uptime = os.clock(),
				turtle = not not turtle,
				pocket = not not pocket,
				fuel = turtle and turtle.getFuelLevel(),
			}
		end,
		shellRun = function(arg) return shell.run(arg) end,
		turtle = function(arg)
			if not turtle then return end 
			if type(arg.method) == 'string' and type(arg.args) == 'table' then
				return table.pack(turtle[arg.method](table.unpack(arg.args)))
			end
		end,
		currentUpdate = function(arg)
			return { versionMajor = control.VERSION_MAJOR, versionMinor = control.VERSION_MINOR }
		end,
		getUpdate = function(arg)
			local codeTable = {}
			local function makeCodeTable(path)
				for i,el in ipairs(fs.list(path)) do
					local fullpath = fs.combine(path, el)
					if fs.isDir(fullpath) then
						makeCodeTable(fullpath)
					else -- is file
						file = fs.open(fullpath, 'r') --[[@as ReadHandle]]
						codeTable[fullpath] = file.readAll()
						file.close()
					end
				end
			end
			makeCodeTable('/firmware')
			codeTable['startup.lua'] = codeTable['firmware/computerStartup.lua']

			util.prettyPrint(util.objectKeys(codeTable))

			return {
				files = codeTable,
				versionMajor = control.VERSION_MAJOR,
				versionMinor = control.VERSION_MINOR,
			}
		end
	}

	while true do
		local args, command, sender, nonce = control.protocolReceive()
		print(command)
		local cmd = control_commands[command]
		-- for shutdown and reboot, send rep before running command
		if cmd == 'shutdown' then
			control.protocolSend(sender --[[@as number]], 'shutdownRep', nil, nonce)
			os.shutdown()
		elseif cmd == 'reboot' then
			control.protocolSend(sender --[[@as number]], 'rebootRep', nil, nonce)
			os.reboot()
		elseif cmd == 'updateCode' then
			control.protocolSend(sender --[[@as number]], 'updateCodeRep', nil, nonce)
			control.autoUpdate()
		elseif cmd ~= nil then
			local ret = cmd(args)
			control.protocolSend(sender --[[@as number]], command .. "Rep", ret, nonce)
		end
	end
end

function control.sourceTask(shell)
	parallel.waitForAll(
		function() remoteControlTask(shell) end,
		function() remoteTermSourceTask(shell) end
	)
end

---@class IdentifyRep
---@field location number[]? x y z
---@field distance number?
---@field id number
---@field label string?
---@field uptime number
---@field turtle boolean
---@field pocket boolean
---@field fuel number?

---@return IdentifyRep
local function handleIdentify(arg, x, y, z)
	if x ~= nil then
		local dist = vector.new(table.unpack(arg.location)) - vector.new(x, y, z)
		arg.distance = dist:length()
	else
		arg.distance = nil
	end
	return arg
end

---Broadcast a command, wait until a timeout and collect all the received answers
---@param command string command
---@param args any? args
---@param timeout number? defaults to 1s
---@return { args: any?, id: number? }[] answers
function control.broadcastCommandRoundtrip(command, args, timeout)
	if timeout == nil then timeout = 1 end

	local nonce = control.newNonce()

	control.protocolBroadcast(command, args, nonce)

	local startTime = os.clock()
	local elapsed = 0
	local reps = {}
	while true do
		local ret, _, sourceid = control.protocolReceive(command .. 'Rep', nil, timeout - elapsed, nonce)
		local elapsed = os.clock() - startTime

		table.insert(reps, { args = ret, id = sourceid })

		if elapsed > timeout then
			break
		end
	end
	return reps
end

---Create a new random nonce
---@return string
function control.newNonce()
	return tostring(math.floor(math.random() * 10000000))
end

---Send a message and wait for a response
---@param sourceid number? computerid of the peer
---@param command string command
---@param arg any? arg
---@return any? ret the return value
function control.sendRoundtrip(sourceid, command, arg)
	local nonce = control.newNonce()
	control.protocolSend(sourceid --[[@as number]], command, arg, nonce)
	local ret = control.protocolReceive(command .. 'Rep', sourceid, nil, nonce)
	return ret
end

---List all reachable peers
---@param timeout any
---@return IdentifyRep[]
function control.listAvailable(timeout)
	local reps = control.broadcastCommandRoundtrip('identify', nil, timeout)

	local available = {}
	for _,rep in ipairs(reps) do
		if rep.args ~= nil then
			rep.args.id = rep.id
			table.insert(available, handleIdentify(rep.args))
		end
	end
	return available
end

---perform an autoupdate over the air
---this function may reboot
---@param timeout number? defaults to 1s
---@return boolean success always false, since we reboot on success
---@return integer peers number of peers available
function control.autoUpdate(timeout)
	local reps = control.broadcastCommandRoundtrip('currentUpdate', nil, timeout)

	local maxVer = {versionMajor = control.VERSION_MAJOR, versionMinor = control.VERSION_MINOR}
	for _,rep in ipairs(reps) do
		if rep.args ~= nil and
				isVersionGreater(rep.args.versionMajor, rep.args.versionMinor, maxVer.versionMajor, maxVer.versionMinor) then
			maxVer = rep.args
			maxVer.id = rep.id
		end
	end

	if isVersionGreater(maxVer.versionMajor, maxVer.versionMinor, control.VERSION_MAJOR, control.VERSION_MINOR) then
		-- need to update
		local rep = control.sendRoundtrip(maxVer.id, 'getUpdate')

		-- apply update
		for k,v in pairs(rep.files) do
			local function mkdirs(path)
				if path == '' then return end
				mkdirs(fs.getDir(path))
				fs.makeDir(path)
			end
			mkdirs(fs.getDir(k))
			local file = fs.open(k, 'w') --[[@as WriteHandle]]
			file.write(v)
			file.close()
		end

		print("Firmware flashed over the air!")
		print("Rebooting...")
		os.reboot()
		return true, #reps
	else
		return false, #reps
	end
end

---Wait for a specific message to be emitted by a peer
---@param sourceid number computer id of the peer
---@param timeout number? defaults to 1s
---@param command string? the command the peer should emit or 'identify' if not provided
---@param args any? args associated with the command
---@return any? response the answer
function control.waitForReady(sourceid, timeout, command, args)
	if command == nil then command = 'identify' end
	if timeout == nil then timeout = 1 end
	if timeout == -1 then timeout = nil end
	local nonce = control.newNonce()

	local rep
	local function receive()
		rep = control.protocolReceive(command .. 'Rep', sourceid, timeout, nonce)
	end

	local function send()
		while true do
			control.protocolSend(sourceid, command, args, nonce)
			os.sleep(1)
		end
	end
	parallel.waitForAny(receive, send)

	return rep
end


---Remote control a computer
---@param sourceid number the computer id
---@return ConnectControl
function control.connectControl(sourceid)
	local turtleFunctions = {
		"craft", "forward", "back", "up", "down", "turnLeft", "turnRight", "select",
		"getSelectedSlot", "getItemCount", "getItemSpace", "getItemDetail", "equipLeft",
		"equipRight", "attack", "attackUp", "attackDown", "dig", "digUp", "digDown", "place",
		"placeUp", "placeDown", "detect", "detectUp", "detectDown", "inspect", "inspectUp",
		"inspectDown", "compare", "compareUp", "compareDown", "compareTo", "drop", "dropUp",
		"dropDown", "suck", "suckUp", "suckDown", "refuel", "getFuelLevel", "getFuelLimit",
		"transferTo"
	}

	---@class TurtleControl
	---@field id number
	local turtle = { id = sourceid }
	for _,method in ipairs(turtleFunctions) do
		---@diagnostic disable-next-line: assign-type-mismatch
		turtle[method] = function(...)
			local ret = control.sendRoundtrip(sourceid, 'turtle', {
				method = method,
				args = {...},
			})
			return table.unpack(ret)
		end
	end

	---@class ConnectControl
	---@field id number
	---@field turtle TurtleControl
	local control = {
		id = sourceid,
		identify = function() 
			local args = control.sendRoundtrip(sourceid, 'identify')
			return handleIdentify(args)
		end,
		shutdown = function() control.sendRoundtrip(sourceid, 'shutdown') end,
		reboot = function() control.sendRoundtrip(sourceid, 'reboot') end,
		shellRun = function(command) return control.sendRoundtrip(sourceid, 'shellRun', command) end,
		turtle = turtle
	}
	return control
end

return control
