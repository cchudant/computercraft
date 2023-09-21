if fs.exists("./disk/do_not_flash") then
	print("This disk should not be flashed!")
	return
end

if fs.exists("./disk/firmware") then
	shell.run("rm ./disk/firmware")
end
if fs.exists("./disk/startup.lua") then
	shell.run("rm ./disk/startup.lua")
end
shell.run("cp ./firmware ./disk/firmware")
shell.run("cp ./disk/firmware/computerStartup.lua ./disk/startup.lua")

print("Done")
