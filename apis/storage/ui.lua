local ui = require('ui')
local storage = require('storage')
local pretty = require('cc.pretty').pretty_print

local storageUI = {}
---@param term Redirect
---@param storageConnection any
---@return fun() startUI
function storageUI.runUI(term, storageConnection)
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
            ui.Block:new {     -- search bar
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
        }
    }, term)
end

return storageUI
