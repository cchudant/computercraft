local ui = require(".firmware.apis.ui")
local util = require(".firmware.apis.util")
local storage = require(".firmware.apis.storage")

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
    termObj.setNeedsRedraw()
    termObj.scheduleDelayed(function ()
        self.active = false
        termObj.setNeedsRedraw()
    end, self.activeDuration)
    self:onPress(termObj)
end

function itemView(storageConnection, makeChild)
    local itemsInStorage = nil

    local search = ''

    local function createChildren()
        if itemsInStorage == nil then
            return ui.Text:new { text = "loading..." }
        end
        local children = {}
        for i,v in ipairs(itemsInStorage) do
            table.insert(children, makeChild(v, i))
        end

        return table.unpack(children)
    end

    local block
    local function task(term)
        storageConnection.listTopItems(
            '',
            20,
            function(items)
                itemsInStorage = items
                print("set needs redraw")
                term.setNeedsRedraw()
                os.queueEvent('dummy')
                block.replaceChildren(term, createChildren())
                util.prettyPrint(createChildren())
            end
        )
    end

    block = ui.Block:new {
        mount = function(self, term)
            self.task = term.addTask(function() task(term) end)
            ui.Block.mount(self, term)
        end,
        unMount = function(self, term)
            term.removeTask(self.task)
            ui.Block.unMount(self, term)
        end,
        createChildren()
    }

    local function onTextChange(term, newText)
        search = newText
        if block.task then
            term.removeTask(block.task)
            block.task = term.addTask(function() task(term) end)
        end
    end

    return block, onTextChange
end

local storageUI = {}
---@param term Redirect
---@param storageConnection StorageConnection
---@return fun() startUI
function storageUI.runUI(term, storageConnection)

    local itemsBlock, onTextChange = itemView(storageConnection, function (item)
        return ui.Block:new {
            width = 20,
            alignContentX = "spaceBetween",
            marginX = 1,
            ui.Text:new { text = item.name },
            ui.Text:new { text = tostring(item.count) },
        }
    end)

    local interface = ui.Block:new {
        width = '100%',
        height = '100%',
        backgroundColor = colors.black,
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
                    textColor = colors.white,
                    onChange = function(self, term, newText)
                        onTextChange(term, newText)
                    end
                }
            }
        },
        ui.Block:new {
            width = '100%',
            height = '100%',
            itemsBlock
        }
    }
    
    ui.drawLoop(interface, term)
end

return storageUI
