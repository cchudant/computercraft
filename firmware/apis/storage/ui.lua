local ui = require(".firmware.apis.ui")
local util = require(".firmware.apis.util")
local storage = require(".firmware.apis.storage")

local retrieveChest = 'minecraft:chest_26'

---@class Button: ui.Block
local Button = {
    backgroundColor = colors.gray,
    textColor = colors.white,
    active = false,
    activeDuration = 0.2, -- seconds
    activeBackgroundColor = colors.lightGray,
    activeTextColor = colors.white,
}
Button = ui.Block:new(Button)
function Button:new(o)
    ui.Block.new(self, o)
    o.unactiveBackgroundColor = o.backgroundColor
    o.unactiveTextColor = o.textColor
    return o
end

function Button:onPress(termObj) end

function Button:onClick(termObj)
    self.active = true
    self.backgroundColor = self.activeBackgroundColor
    self.textColor = self.activeTextColor
    termObj.setNeedsRedraw()
    termObj.scheduleDelayed(function()
        self.active = false
        self.backgroundColor = self.unactiveBackgroundColor
        self.textColor = self.unactiveTextColor
        termObj.setNeedsRedraw()
    end, self.activeDuration)
    self:onPress(termObj)
end

local function itemView(storageConnection)
    local itemsInStorage = nil

    local search = ''

    local function makeChild(item)
        local countText = ""
        local textColor = colors.lightBlue
        if not item.craft then
            countText = tostring(item.count)
            textColor = colors.white
        end

        local width = 25
        local displayName = item.displayName
        if string.len(displayName) > width - string.len(countText) then
            displayName = string.sub(displayName, 1, width - string.len(countText) - 1) .. "."
        end

        return Button:new {
            backgroundColor = colors.black,
            textColor = textColor,
            activeBackgroundColor = colors.gray,
            width = width,
            height = 1,
            alignContentX = "spaceBetween",
            marginX = 0.5,
            paddingLeft = 1,
            onPress = function(self, term)
                term.addTask(function()
                    storageConnection.transfer({
                        type = "retrieveItems",
                        name = item.name,
                        amount = 'stack',
                        destination = retrieveChest,
                    })
                end)
            end,
            ui.Text:new { text = displayName },
            ui.Text:new { text = countText },
        }
    end

    local function createChildren()
        if itemsInStorage == nil then
            return ui.Text:new { text = "loading..." }
        end
        local children = {}
        for i, v in ipairs(itemsInStorage) do
            table.insert(children, makeChild(v, i))
        end

        return table.unpack(children)
    end

    local block
    local function task(term)
        storageConnection.listTopItems(
            {
                fuzzySearch = search,
                otherwiseShowCrafts = true,
            },
            function(items)
                itemsInStorage = items
                term.setNeedsRedraw()
                block:replaceChildren(term, createChildren())
            end
        )
    end

    block = ui.Grid:new {
        childWidth = 26,
        childHeight = 1,
        mount = function(self, term)
            self.task = term.addTask(function() task(term) end)
            ui.Block.mount(self, term)
        end,
        unMount = function(self, term)
            term.removeTask(self.task)
            ui.Grid.unMount(self, term)
        end,
        createChildren()
    }

    local function onTextChange(term, newText)
        search = newText
        if block.task ~= nil then
            term.removeTask(block.task)
            block.task = term.addTask(function() task(term) end)
        end
    end

    return block, onTextChange
end

local function craftView(storageConnection, item)
    return ui.Block:new {
        width = '100%',
        height = '100%',
        maxWidth = 60,
        maxHeight = 20,
        backgroundColor = 'lightBlue',
        alignContentY = 'spaceBetween',
        ui.Block:new {
            width = '100%',
            ui.Text:new {
                width = '100%',
                text = "Crafting " .. item.displayName,
            },
        },
        ui.Block:new {
            width = '100%',
            Button:new {
                paddingY = 1,
                paddingX = 5,
                ui.Text:new {
                    text = "Order"
                },
                marginLeft = 1,
            }
        },
    }
end

local storageUI = {}
---@param term Redirect
---@param getStorageConnection fun(): StorageConnection
---@return fun() startUI
function storageUI.runUI(term, getStorageConnection)
    ---@type StorageConnection
    local storageConnection
    ui.drawLoop(ui.Text:new {
        text = 'loading...',
        mount = function(self, term)
            term.addTask(function()
                storageConnection = getStorageConnection()
                term.close()
            end)
        end
    }, term)

    local itemsBlock, onTextChange = itemView(storageConnection)

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
                onPress = function(self, term)
                    term.addTask(function()
                        storageConnection.transfer({
                            type = "storeItems",
                            amount = 'all',
                            source = retrieveChest
                        })
                    end)
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
