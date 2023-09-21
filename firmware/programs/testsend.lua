local control = require(".firmware.apis.control")

local a = ...

if a ~= nil then
    control.protocolSend(tonumber(a), "test222")
    print("sent")
else
    control.protocolReceive("test222")
    print("received")
end