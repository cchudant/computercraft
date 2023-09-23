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

	for _, per in ipairs(peripheral.getNames()) do
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

			for _, method in ipairs(methods) do
				termObj[method] = function(...)
					control.protocolSend(clientid --[[@as number]], 'term', {
						method = method,
						args = { ... },
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
			local bag = { os.pullEvent() }
			local event = bag[1]
			local args = {}
			for i = 2, #bag do
				args[i - 1] = bag[i]
			end

			local all_events = {
				"char", "key", "key_up", "paste", "terminate",
				"mouse_click", "mouse_up", "mouse_scroll", "mouse_drag",
				"term_resize"
			}

			for _, ev in pairs(all_events) do
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
				for i, el in ipairs(fs.list(path)) do
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

			return {
				files = codeTable,
				versionMajor = control.VERSION_MAJOR,
				versionMinor = control.VERSION_MINOR,
			}
		end
	}

	util.parallelGroup(function(addTask)
		while true do
			local args, command, sender, nonce = control.protocolReceive()
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
				addTask(function()
					local ret = cmd(args)
					control.protocolSend(sender --[[@as number]], command .. "Rep", ret, nonce)
				end)
			end
		end
	end)
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
	for _, rep in ipairs(reps) do
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

	local maxVer = { versionMajor = control.VERSION_MAJOR, versionMinor = control.VERSION_MINOR }
	for _, rep in ipairs(reps) do
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
		for k, v in pairs(rep.files) do
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
	for _, method in ipairs(turtleFunctions) do
		---@diagnostic disable-next-line: assign-type-mismatch
		turtle[method] = function(...)
			local ret = control.sendRoundtrip(sourceid, 'turtle', {
				method = method,
				args = { ... },
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

---@generic T
---@return control.Connection<T>
local function makeConnection(protocol, serverID, pullEvent, sendEvent)
	local connectionID = util.newNonce()
	local fullProtocolString = protocol
	if serverID then fullProtocolString = fullProtocolString .. ":" .. serverID end

	local function roundtripRpc(method, ...)
		local nonce = util.newNonce()
		sendEvent(fullProtocolString, method, nonce, connectionID, table.pack(...))
		while true do
			local fullProtocolString2, method2, nonce2, connectionID2, args = pullEvent(fullProtocolString)
			if fullProtocolString == fullProtocolString2
				and method .. 'Rep' == method2
				and nonce == nonce2
				and connectionID == connectionID2
				and type(args) == 'table'
			then
				local success, err = table.unpack(args, 1, 2)
				if not success then
					error("Server returned error: " .. err)
				end
				return table.unpack(args, 2, args.n)
			end
		end
	end

	---@class control.Connection<T>: {}|T
	local connection = {}
	setmetatable(connection, {
		__index = function(_, method)
			return function(...)
				print(method)
				return roundtripRpc(method, ...)
			end
		end
	})

	function connection.subscribeEvent(event)
		roundtripRpc("subscribeEvent", event)
	end

	function connection.unsubscribeEvent(event)
		roundtripRpc("unsubscribeEvent", event)
	end

	function connection.close(event)
		roundtripRpc("close", event)
	end

	---@param filter string?
	---@return string event
	---@return any ...
	function connection.pullEvent(filter)
		while true do
			local fullProtocolString2, method2, nonce, connectionID2, args = pullEvent(fullProtocolString)
			if fullProtocolString == fullProtocolString2
				and method2 == 'end' and connectionID == connectionID2 then
				-- end of connection
				return 'end'
			elseif fullProtocolString == fullProtocolString2
				and method2 == 'keepAlive' and connectionID == connectionID2 then
				-- keep alive
				
				sendEvent(fullProtocolString, 'keepAliveRep', nonce, connectionID)
			elseif fullProtocolString == fullProtocolString2
				and "event" == method2
				and connectionID == connectionID2
				and type(args) == 'table'
				and type(args[1]) == 'string'
				and (filter == nil or filter == args[1])
			then
				return table.unpack(args, 1, args.n)
			end
		end
	end

	return connection
end

---@return control.Connection
function control.localConnect(protocol, serverID)
	local function pullEvent(fullProtocolString)
		local fullProtocolString, method, nonce, connectionID, args = os.pullEvent(fullProtocolString)
		return fullProtocolString, method, nonce, connectionID, args
	end
	local function sendEvent(fullProtocolString, method, nonce, connectionID, args)
		os.queueEvent(fullProtocolString, method, nonce, connectionID, args)
	end

	return makeConnection(protocol, serverID, pullEvent, sendEvent)
end

---@return control.Connection
function control.remoteConnect(protocol, computerID, serverID)
	local function pullEvent(fullProtocolString)
		while true do
			local sender, message = rednet.receive(fullProtocolString)
			if type(message) == 'table' and sender == computerID then
				return fullProtocolString, message.method, message.nonce, message.connectionID, message.args
			end
		end
	end
	local function sendEvent(fullProtocolString, method, nonce, connectionID, args)
		rednet.send(computerID, {
			protocol = fullProtocolString,
			method = method,
			nonce = nonce,
			connectionID = connectionID,
			args = args,
		}, fullProtocolString)
	end

	return makeConnection(protocol, serverID, pullEvent, sendEvent)
end

---@param methods { [string]: fun(connectionID: string, ...) }
---@param protocol string
---@param serverID string?
---@return fun(...: fun(addTask: fun(...: fun()))) startServer
---@return control.Server server
---@return fun(): control.Connection getLocalConnection
function control.makeServer(methods, protocol, serverID)
	---@class control.Server
	local server = {
		---@type boolean
		isUp = false,
	}

	local protected = true

	---@type { [string]: string[] } event => connectionID[]
	local eventsSubscribed = {}
	---@type { [string]: number } { [connectionID]: number of requests }
	local currentlyAnswering = {}
	---@type { [string]: number|'local' } connectionID => sender id / 'local'
	local connectionIDs = {}

	---@type { [string]: number } connectionID => os.clock() time
	local lastKeepAlives = {}

	local fullProtocolString = protocol
	if serverID then fullProtocolString = fullProtocolString .. ":" .. serverID end

	local function sendTo(connectionID, nonce, method, ...)
		local sender = connectionIDs[connectionID]
		if sender == nil then error("connectionID is not connected", 2) end
		if sender == 'local' then
			os.queueEvent(fullProtocolString, method, nonce, connectionID, table.pack(...))
		else
			rednet.send(sender, {
				protocol = fullProtocolString,
				method = method,
				nonce = nonce,
				connectionID = connectionID,
				args = table.pack(...),
			}, fullProtocolString)
		end
	end

	function server.triggerEvent(event, ...)
		local subs = eventsSubscribed[event]
		if subs ~= nil then
			for _, connectionID in ipairs(subs) do
				sendTo(connectionID, nil, "event", event, ...)
			end
		end
	end

	function server.subscribeEvent(connectionID, event)
		local subs = eventsSubscribed[event]
		if subs == nil then
			subs = {}
			eventsSubscribed[event] = subs
		end
		table.insert(subs, connectionID)
	end

	function server.unsubscribeEvent(connectionID, event)
		local subs = eventsSubscribed[event]
		if subs ~= nil then
			local index = util.arrayIndexOf(subs, connectionID)
			if index > 0 then table.remove(subs, index) end
		end
		if #subs == 0 then
			eventsSubscribed[event] = nil
		end
	end

	function server.closeConnection(connectionID)
		lastKeepAlives[connectionID] = nil
		for event, subs in pairs(eventsSubscribed) do
			if subs ~= nil then
				local index = util.arrayIndexOf(subs, connectionID)
				if index > 0 then table.remove(subs, index) end
			end
			if #subs == 0 then
				eventsSubscribed[event] = nil
			end
		end

		if (currentlyAnswering[connectionID] or 0) == 0 then
			connectionIDs[connectionID] = nil
		end
	end

	function server.close()
		os.queueEvent(fullProtocolString .. ":end")
	end

	---@param ... fun(addTask: fun(...: fun()))
	local function startServer(...)
		util.parallelGroup(
			function(addTask)
				---@param sender number|'local'
				---@param connectionID string
				---@param method string
				---@param args table
				---@param answer fun(...)
				local function handleRpc(sender, connectionID, method, args, answer)
					if method == "keepAliveRep" then
						lastKeepAlives[connectionID] = os.clock()
					elseif method == "subscribeEvent" then
						connectionIDs[connectionID] = sender
						if args[1] == nil then
							answer(false, "no event provided")
						else
							server.subscribeEvent(connectionID, args[1])
							answer(true)
						end
					elseif method == "unsubscribeEvent" then
						if args[1] == nil then
							answer(false, "no event provided")
						else
							server.unsubscribeEvent(connectionID, args[1])
							answer(true)
						end
					elseif method == "close" then
						server.closeConnection(connectionID)
						answer(true)
					elseif methods[method] ~= nil then
						addTask(function()
							local func = methods[method]

							connectionIDs[connectionID] = sender
							currentlyAnswering[connectionID] = (currentlyAnswering[connectionID] or 0) + 1

							if protected then
								local ret = table.pack(xpcall(func, debug.traceback, connectionID,
									table.unpack(args, 1, args.n)))
								if ret[1] then
									answer(true, table.unpack(ret, 2, ret.n))
								else
									print("Server Error: " .. ret[2])
									answer(false, ret[2])
								end
							else
								local ret = table.pack(func(connectionID, table.unpack(args, 1, args.n)))
								answer(true, table.unpack(ret, 1, ret.n))
							end

							currentlyAnswering[connectionID] = (currentlyAnswering[connectionID] or 0) - 1
							if (currentlyAnswering[connectionID] or 0) == 0 then
								connectionIDs[connectionID] = nil
								currentlyAnswering[connectionID] = nil
							end
						end)
					else
						-- answer(false, "No such method")
					end
				end

				local function networkTask() -- network requests
					setupModem()
					while true do
						local sender, message = rednet.receive(fullProtocolString)
						if type(message) == 'table' and sender ~= nil
							and message.protocol == fullProtocolString
							and type(message.nonce) == 'string'
							and type(message.method) == 'string'
							and type(message.args) == 'table'
							and type(message.connectionID) == 'string'
						then
							handleRpc(sender, message.connectionID, message.method, message.args, function(...)
								rednet.send(sender, {
									protocol = fullProtocolString,
									method = message.method .. 'Rep',
									nonce = message.nonce,
									connectionID = message.connectionID,
									args = table.pack(...),
								}, fullProtocolString)
							end)
						end
					end
				end
				local function localTask() -- local requests
					while true do
						local protocol, method, nonce, connectionID, args = os.pullEvent(fullProtocolString)
						if protocol == fullProtocolString
							and type(nonce) == 'string'
							and type(connectionID) == 'string'
							and type(method) == 'string'
							and type(args) == 'table'
							and type(connectionID) == 'string'
						then
							handleRpc('local', connectionID, method, args, function(...)
								os.queueEvent(fullProtocolString, method .. 'Rep', nonce, connectionID, table.pack(...))
							end)
						end
					end
				end
				local function keepAliveTask() -- keep alives
					local keepAliveTime = 5
					os.sleep(keepAliveTime)
					while true do
						-- operate on a copy, so that when new connectionIDs are created during sleep, we don't remove them
						-- until next loop turn
						local connectionIDsCopy = util.objectCopy(connectionIDs)
						for connectionID, _ in pairs(connectionIDsCopy) do
							sendTo(connectionID, nil, "keepAlive")
						end
						os.sleep(keepAliveTime)
						-- clear any connection that has not responded
						local clock = os.clock()
						for connectionID, _ in pairs(connectionIDsCopy) do
							local keepAlive = lastKeepAlives[connectionID] or 0
							if keepAlive ~= nil and clock - keepAlive > keepAliveTime then
								server.closeConnection(connectionID)
							end
						end
					end
				end
				local function endCondition() -- server end condition
					server.isUp = true
					os.queueEvent(fullProtocolString .. ":start")
					os.pullEvent(fullProtocolString .. ":end")
					server.isUp = false
				end

				parallel.waitForAny(networkTask, localTask, keepAliveTask, endCondition)

				for connectionID, _ in pairs(connectionIDs) do
					sendTo(connectionID, nil, "end")
				end
			end,
			...
		)
	end

	local function getLocalConnection()
		if not server.isUp then
			os.pullEvent(fullProtocolString .. ":start")
		end
		return control.localConnect(protocol, serverID)
	end

	return startServer, server, getLocalConnection
end

return control
