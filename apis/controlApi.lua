VERSION_MAJOR = 2

local file = fs.open("/firmware/commits", "r")
local commits = file.readAll()
commits = commits:gsub("%s+", "")

VERSION_MINOR = tonumber(commits)

VERSION = VERSION_MAJOR .. '.' .. VERSION_MINOR
PROTOCOL_STRING = 'CONTROL'

function _isVersionGreater(versionMajorA, versionMinorA, versionMajorB, versionMinorB)
	return versionMajorA > versionMajorB or
			(versionMajorA == versionMajorB and versionMinorA > versionMinorB)
end

_isSetup = false
function _setup()
	if _isSetup then return end

	function modem_side()
		for _,per in ipairs(peripheral.getNames()) do
			if peripheral.getType(per) == "modem" then
				return per
			end
		end
		return nil, "No modem on cumputer!"
	end

	local side, err = modem_side()
	if side == nil then error(err) end

	rednet.open(side)
	_isSetup = true
	return true
end

function protocolReceive(command, sender, timeout, nonce)
	_setup()
	local startTime = os.clock()
	local elapsed = 0
	-- print(command, sender, nonce)
	while true do
		local to_wait = nil
		if timeout ~= nil then
			to_wait = timeout - elapsed
		end

		local snd, message = rednet.receive(to_wait)

		if type(message) == 'table' and message.protocol == PROTOCOL_STRING and
				(sender == nil or sender == snd) and
				(command == nil or message.command == command) and
				message.nonce == nonce then
			return message.args, message.command, snd, message.nonce
		end

		elapsed = os.clock() - startTime
		if timeout ~= nil and elapsed > timeout then
			break
		end
	end
end
function protocolSend(client, command, args, nonce)
	_setup()
	rednet.send(client, {
		protocol = PROTOCOL_STRING,
		command = command,
		args = args,
		nonce = nonce,
	})
end
function protocolBroadcast(command, args, nonce)
	_setup()
	rednet.broadcast({
		protocol = PROTOCOL_STRING,
		command = command,
		args = args,
		nonce = nonce,
	})
end

-- A task that serves Remote Term requests
function _remoteTermSourceTask(shell)
	local clientid
	local nonce

	_, _, clientid, nonce = protocolReceive('connectTerm')
	protocolSend(clientid, 'connectedTerm', nil, nonce)

	local methods = {
		"write", "blit", "clear", "clearLine", "getCursorPos", "setCursorPos", "setCursorBlink",
		"isColor", "isColour", "getSize", "scroll", "redirect", "setTextColor", "setTextColour",
		"getTextColor", "getTextColour", "setBackgroundColor", "setBackgroundColour",
		"getBackgroundColor", "getBackgroundColour"
	}

	function taskSend()
		while true do
			term.clear()
			term.setCursorPos(1, 1)

			termObj = {}
			native = term.native()

			for _,method in ipairs(methods) do
				termObj[method] = function(...)
					protocolSend(clientid, 'term', {
						method = method,
						args = {...},
					}, nonce)
					return native[method](...)
				end
			end

			term.redirect(termObj)
			shell.run("shell")
			term.redirect(native)

			protocolSend(clientid, 'endTerm', nil, nonce)
			clientid = nil
		end
	end
	function taskReceive()
		while true do
			args = protocolReceive('termEvent', clientid, nil, nonce)
			os.queueEvent(args.event, unpack(args.args))
		end
	end
	parallel.waitForAny(taskReceive, taskSend)
end

-- A task that connects to a Remote Term client by id
function remoteTermClient(sourceid)
	local nonce
	function taskReceiveEnd()
		protocolReceive('endTerm', sourceid, nil, nonce)
	end
	function taskReceive()
		term.clear()
		term.setCursorPos(1, 1)

		while true do
			args = protocolReceive('term', sourceid, nil, nonce)
			ret = table.pack(
				term[args.method](unpack(args.args))
			)
		end
	end
	function taskSend()
		while true do
			bag = {os.pullEvent()}
			event = bag[1]
			args = {}
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
					protocolSend(sourceid, 'termEvent', {
						event = ev,
						args = args,
					}, nonce)
					break
				end
			end
		end
	end

	local _, _, _, nonce_ = protocolSend(sourceid, 'connectTerm')
	nonce = nonce_
	protocolReceive('connectedTerm', nil, nil, nonce)

	parallel.waitForAny(taskReceive, taskSend, taskReceiveEnd)
end

function _remoteControlTask(shell)
	local control_commands = {
		identify = function(arg)
			return {
				id = os.getComputerID(),
				label = os.getComputerLabel(),
				location = {gps.locate()},
				uptime = os.clock(),
				turtle = turtle or nil,
				pocket = pocket or nil,
				fuel = turtle and turtle.getFuelLevel(),
			}
		end,
		shellRun = function(arg) shell.run(arg) end,
		turtle = function(arg)
			if not turtle then return end 
			if type(arg.method) == 'string' and type(arg.args) == 'table' then
				-- print('called', arg.method, arg.args)
				return table.pack(turtle[arg.method](unpack(arg.args)))
			end
		end,
		currentUpdate = function(arg)
			return { versionMajor = VERSION_MAJOR, versionMinor = VERSION_MINOR }
		end,
		getUpdate = function(arg)
			local codeTable = {}
			function makeCodeTable(path)
				for i,el in ipairs(fs.list(path)) do
					local fullpath = fs.combine(path, el)
					if fs.isDir(fullpath) then
						makeCodeTable(fullpath)
					else -- is file
						file = fs.open(fullpath, 'r')
						codeTable[fullpath] = file.readAll()
						file.close()
					end
				end
			end
			makeCodeTable('/firmware')
			codeTable['/startup.lua'] = codeTable['/firmware/computerStartup.lua']

			return {
				files = codeTable,
				versionMajor = VERSION_MAJOR,
				versionMinor = VERSION_MINOR,
			}
		end
	}

	while true do
		local args, command, sender, nonce = protocolReceive()
		-- print(command, sender, nonce)
		local cmd = control_commands[command]
		-- for shutdown and reboot, send rep before running command
		if cmd == 'shutdown' then
			protocolSend(sender, 'shutdownRep', nil, nonce)
			os.shutdown()
		elseif cmd == 'reboot' then
			protocolSend(sender, 'rebootRep', nil, nonce)
			os.reboot()
		elseif cmd == 'updateCode' then
			protocolSend(sender, 'updateCodeRep', nil, nonce)
			autoUpdate()
		elseif cmd ~= nil then
			local ret = cmd(args)
			print("snd", sender, method, args, unpack(ret))
			protocolSend(sender, command .. "Rep", ret, nonce)
		end
	end
end

function _sourceTask(shell)
	parallel.waitForAll(
		function() _remoteControlTask(shell) end,
		function() _remoteTermSourceTask(shell) end
	)
end

function _handleIdentify(arg, x, y, z)
	arg.id = sourceid
	if x ~= nil then
		local dist = vector.new(unpack(arg.location)) - vector.new(x, y, z)
		arg.distance = dist:length()
	else
		arg.distance = nil
	end
	return arg
end

function _broadcastCommandRoundtrip(command, args, timeout)
	if timeout == nil then timeout = 1 end

	local nonce = tostring(math.floor(math.random() * 10000000))

	protocolBroadcast(command, args, nonce)

	local startTime = os.clock()
	local elapsed = 0
	local reps = {}
	while true do
		local ret, _, sourceid = protocolReceive(command .. 'Rep', nil, timeout - elapsed, nonce)
		local elapsed = os.clock() - startTime

		table.insert(reps, { args = ret, id = sourceid })

		if elapsed > timeout then
			break
		end
	end
	return reps
end
function _sendRoundtrip(sourceid, command, arg)
	local nonce = tostring(math.floor(math.random() * 10000000))
	protocolSend(sourceid, command, arg, nonce)
	local ret = protocolReceive(command .. 'Rep', sourceid, nil, nonce)
	return ret
end

function listAvailable(timeout)
	local reps = _broadcastCommandRoundtrip('identify', nil, timeout)

	local x, y, z = gps.locate()
	local available = {}
	for _,rep in ipairs(reps) do
		if rep.args ~= nil then
			rep.args.id = rep.id
			table.insert(available, _handleIdentify(rep.args, x, y, z))
		end
	end
	return available
end

-- this function may reboot
function autoUpdate(timeout)
	local reps = _broadcastCommandRoundtrip('currentUpdate', nil, timeout)

	local maxVer = {versionMajor = VERSION_MAJOR, versionMinor = VERSION_MINOR}
	for _,rep in ipairs(reps) do
		if rep.args ~= nil and
				_isVersionGreater(rep.args.versionMajor, rep.args.versionMinor, maxVer.versionMajor, maxVer.versionMinor) then
			maxVer = rep.args
			maxVer.id = rep.id
		end
	end

	if _isVersionGreater(maxVer.versionMajor, maxVer.versionMinor, VERSION_MAJOR, VERSION_MINOR) then
		-- need to update
		local rep = _sendRoundtrip(maxVer.id, 'getUpdate')

		-- apply update
		for k,v in pairs(rep.files) do
			function mkdirs(path)
				if path == '' then return end
				mkdirs(fs.getDir(path))
				fs.makeDir(path)
			end
			mkdirs(fs.getDir(k))
			local file = fs.open(k, 'w')
			file.write(v)
			file.close()
		end

		print("Firmware flashed over the air!")
		print("Rebooting...")
		os.sleep(1)
		os.reboot()
	else
		return false, table.getn(reps)
	end
end

function waitForReady(sourceid, timeout)
	if timeout == nil then timeout = 1 end
	local nonce = tostring(math.floor(math.random() * 10000000))

	local rep
	function receive()
		rep = protocolReceive('identifyRep', sourceid, timeout, nonce)
	end

	function send()
		while true do
			protocolSend(sourceid, 'identify', args, nonce)
			os.sleep(0.2)
		end
	end
	parallel.waitForAny(receive, send)

	return rep
end

function connectControl(sourceid)
	local turtleFunctions = {
		"craft", "forward", "back", "up", "down", "turnLeft", "turnRight", "select",
		"getSelectedSlot", "getItemCount", "getItemSpace", "getItemDetail", "equipLeft",
		"equipRight", "attack", "attackUp", "attackDown", "dig", "digUp", "digDown", "place",
		"placeUp", "placeDown", "detect", "detectUp", "detectDown", "inspect", "inspectUp",
		"inspectDown", "compare", "compareUp", "compareDown", "compareTo", "drop", "dropUp",
		"dropDown", "suck", "suckUp", "suckDown", "refuel", "getFuelLevel", "getFuelLimit",
		"transferTo"
	}

	local turtle = { id = sourceid }
	for _,method in ipairs(turtleFunctions) do
		turtle[method] = function(...)
			local ret = _sendRoundtrip(sourceid, 'turtle', {
				method = method,
				args = {...},
			})
			print("src", sourceid, method, args, unpack(ret))
			os.sleep(1)
			return unpack(ret)
		end
	end

	return {
		id = sourceid,
		identify = function() 
			local args = _sendRoundtrip(sourceid, 'identify')
			local x, y, z = gps.locate()
			return _handleIdentify(args, x, y, z)
		end,
		shutdown = function() _sendRoundtrip(sourceid, 'shutdown') end,
		reboot = function() _sendRoundtrip(sourceid, 'reboot') end,
		shellRun = function(command) return _sendRoundtrip(sourceid, 'shellRun', command) end,
		turtle = turtle
	}
end
