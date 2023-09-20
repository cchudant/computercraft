local ui = require("apis.ui")
local storage = require("apis.storage")

local storageUI = {}
---@param term Redirect
---@param storageConnection any
---@return fun() startUI
function storageUI.runUI(term, storageConnection)
    local interface = ui.Block:new {
        alignContentX = 'center',
        width = '100%',
        height = '100%',
        -- alignContentX = 'begin',
        -- ui.Block:new {
            ui.Block:new {
                backgroundColor = colors.yellow,
                minWidth = 20,
                height = 1,
                marginX = 2,
                marginY = 1,
            },
            ui.Block:new {
                backgroundColor = colors.yellow,
                minWidth = 20,
                height = 1,
                marginX = 2,
                marginY = 1,
            },
            ui.Block:new {
                backgroundColor = colors.yellow,
                minWidth = 20,
                height = 1,
                marginX = 2,
                marginY = 1,
            },
            ui.Block:new {
                backgroundColor = colors.yellow,
                minWidth = 20,
                height = 1,
                marginX = 2,
                marginY = 1,
            },
            ui.Block:new {
                backgroundColor = colors.yellow,
                minWidth = 20,
                height = 1,
                marginX = 2,
                marginY = 1,
            }
        -- }
    }
    -- ui.drawLoop(interface, term)
    print(interface:getSize(term.getSize()))
    os.sleep(1000)


    ui.drawLoop(ui.Block:new {
        width = 10,
        height = 10,
        ui.Block:new {
            width = '100%',
            alignContentX = 'spaceBetween',
            ui.Block:new {
                marginLeft = 2,
                paddingX = 1,
                backgroundColor = colors.gray,
                textColor = colors.white,
                onClick = function()
                    storageConnection.transfer({
                        type = 'storeItems',
                        source = 'minecraft:chest_20',
                        amount = 'all',
                    })
                end,
                ui.Text:new { text = "Push" },
            },
            ui.Block:new { -- search bar
                ui.Text:new {
                    text = "Search:",
                    backgroundColor = colors.gray,
                    textColor = colors.white
                },
                ui.TextInput:new {
                    width = 20,
                    height = 1,
                    backgroundColor = colors.lightGray,
                    textColor = colors.white
                }
            }
        },
        ui.Block:new {
            width = '100%',
            height = '100%',
            alignContentX = 'center',
            ui.Block:new {
                alignContentX = 'begin',
                ui.Block:new {
                    backgroundColor = colors.yellow,
                    minWidth = 20,
                    height = 1,
                    marginX = 2,
                    marginY = 1,
                },
                ui.Block:new {
                    backgroundColor = colors.yellow,
                    minWidth = 20,
                    height = 1,
                    marginX = 2,
                    marginY = 1,
                },
                ui.Block:new {
                    backgroundColor = colors.yellow,
                    minWidth = 20,
                    height = 1,
                    marginX = 2,
                    marginY = 1,
                },
                ui.Block:new {
                    backgroundColor = colors.yellow,
                    minWidth = 20,
                    height = 1,
                    marginX = 2,
                    marginY = 1,
                },
                ui.Block:new {
                    backgroundColor = colors.yellow,
                    minWidth = 20,
                    height = 1,
                    marginX = 2,
                    marginY = 1,
                }
            }
        }
    }, term)
end

return storageUI
