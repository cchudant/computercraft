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
        print("task")
        storageConnection.listTopItems(
            search,
            20,
            function(items)
                print("items", #items)
                itemsInStorage = items
                term.setNeedsRedraw()
                block:replaceChildren(term, createChildren())
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
---@param getStorageConnection fun(): StorageConnection
---@return fun() startUI
function storageUI.runUI(term, getStorageConnection)
    local storageConnection
    ui.drawLoop(ui.Text:new {
        text = 'loading...',
        mount = function(self, term)
            term.addTask(function ()
                storageConnection = getStorageConnection()
                print("connected 2")
                term.close()
            end)
        end
    }, term)

    print(2)

    local itemsBlock, onTextChange = itemView(storageConnection, function (item)
        return ui.Block:new {
            width = 25,
            height = 1,
            alignContentX = "spaceBetween",
            marginX = 0.5,
            ui.Text:new { text = item.displayName },
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
            alignContentX = 'center',
            itemsBlock
        }
    }
    
    ui.drawLoop(interface, term)
end

return storageUI
