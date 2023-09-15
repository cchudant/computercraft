local ui = require('ui')
local storage = require('storage')

local storageServer = storage.storageServer()
local success, errors, transfered, results = storageServer.storeItems({{ source = 'chest1', amount = 'all' }}, {})

local monitor = peripheral.find('monitor') --[[@as Monitor]]
monitor.setTextScale(0.5)

ui.drawLoop(
    ui.Block:new {
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
                ui.Text:new { text = "Push" }
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
        }
    },
    monitor
)
