local util = require("util")

util.parallelGroup(function (addTasks)
    addTasks(
        function()
            os.sleep(2)
            print("2 finished")
        end,
        function()
            os.sleep(1)
            print("1 finished")
        end
    )
    print("parent finished")
end)
