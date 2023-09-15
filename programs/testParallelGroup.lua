local util = require("util")

util.parallelGroup(function (addTasks)
    addTasks(
        function()
            print("2 started")
            os.sleep(2)
            print("2 finished")
        end,
        function()
            print("1 started")
            os.sleep(1)
            print("1 finished")
        end
    )
    print("parent finished")
end)
