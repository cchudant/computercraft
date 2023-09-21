local ui = require("..apis.ui")
local storage = require("..apis.storage")

---@class Button: ui.Block
local Button = {
    backgroundColor = colors.gray,
    textColor = colors.white,
    active = false,
    activeDuration = 0.2, -- seconds
    activeBackgroundColor = colors.lightGray,
    activeTextColor = colors,
}
Button = ui.Block:new(Button)
function Button:onPress(termObj) end
function Button:onClick(termObj)
    self.active = true
    termObj.scheduleDelayed(function ()
        self.active = false
        termObj.setNeedsRedraw()
    end, self.activeDuration)
    self:onPress(termObj)
end

function itemView(storageConnection, makeChild)
    local itemsInStorage = nil

    local function createChildren()
        if itemsInStorage == nil then
            return ui.Text { text = "loading..." }
        end
        local children = {}
        for i,v in ipairs(itemsInStorage) do
            table.insert(children, makeChild(v, i))
        end

        return table.unpack(children)
    end

    local block = ui.Block:new {
        mount = function(self, term)
            self.task = term.addTask(storageConnection.listTopItems(
                20,
                function(items)
                    itemsInStorage = items
                    term.setNeedsRedraw()
                    self.replaceChildren(term, createChildren())
                end
            ))
            ui.Block.mount(self, term)
        end,
        unmount = function(self, term)
            term.removeTask(self.task)
        end,
        createChildren()
    }

    return block
end

local storageUI = {}
---@param term Redirect
---@param storageConnection StorageConnection
---@return fun() startUI
function storageUI.runUI(term, storageConnection)
    
    ui.drawLoop(ui.Block:new {
        width = 10,
        height = 10,
        ui.Block:new {
            width = '100%',
            alignContentX = 'spaceBetween',
            Button:new {
                marginLeft = 2,
                paddingX = 1,
                onPress = function()
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
            itemView(storageConnection, function (item)
                return ui.Block:new {
                    width = 20,
                    alignContentX = "spaceBetween",
                    marginX = 1,
                    ui.Text { text = item.name },
                    ui.Text { text = tostring(item.count) },
                }
            end)
        }
    }, term)
end

return storageUI
