os.loadAPI("/firmware/apis/ui.lua")

local monitor = peripheral.find('monitor')
monitor.setTextScale(0.5)

ui.drawLoop(
    ui.Block:new {
        width = 10,
        height = 10,
        ui.Text:new { text = "hello" },
    --     ui.Block:new {
    --         width = '100%',
    --         alignContentX = 'spaceBetween',            
    --         ui.Block:new {
    --             marginLeft = 2,
    --             paddingX = 1,
    --             backgroundColor = colors.gray,
    --             textColor = colors.white,
    --             ui.Text:new { text = "Push" }
    --         },
    --         ui.Block:new { -- search bar
    --             ui.Text:new {
    --                 text = "Search:",
    --                 backgroundColor = colors.gray,
    --                 textColor = colors.white
    --             },
    --             ui.Block:new {
    --                 width = 20,
    --                 height = 1,
    --                 backgroundColor = colors.lightGray,
    --                 textColor = colors.white
    --             }
    --         }
    --     }
    },
    monitor
)
