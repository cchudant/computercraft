os.loadAPI("/firmware/apis/ui.lua")

local monitor = peripheral.find('monitor')
monitor.setTextScale(0.5)

ui.drawLoop(
    ui.Block {
        width = '100%',
        height = '100%',
        ui.Block {
            width = '100%',
            alignContentX = 'spaceBetween',            
            ui.Block {
                marginLeft = 2,
                paddingX = 1,
                backgroundColor = colors.gray,
                textColor = colors.white,
                ui.Text { text = "Push" }
            },
            ui.Block { -- search bar
                ui.Text {
                    text = "Search:",
                    backgroundColor = colors.gray,
                    textColor = colors.white
                },
                ui.Block {
                    width = 20,
                    backgroundColor = colors.lightGray,
                    textColor = colors.white
                }
            }
        }
    },
    monitor
)
