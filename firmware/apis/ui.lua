local util = require(".firmware.apis.util")

local ui = {}

---@class ui.UIObject
ui.UIObject = {
    transparent = false,
    mounted = false,
    marginLeft = 0,
    marginTop = 0,
    marginBottom = 0,
    marginRight = 0,

    ---@type number|nil
    ---Shorthand to marginLeft, marginRight, marginTop, marginBottom
    margin = nil,
    ---@type number|nil
    ---Shorthand to marginLeft, marginRight
    marginX = nil,
    ---@type number|nil
    ---Shorthand to marginTop, marginBottom
    marginY = nil,
}

---@diagnostic disable-next-line: duplicate-set-field
function ui.UIObject:__newindex(index, value)
    if index == 'margin' then
        self.marginLeft = value
        self.marginRight = value
        self.marginTop = value
        self.marginBottom = value
    elseif index == 'marginX' then
        self.marginLeft = value
        self.marginRight = value
    elseif index == 'marginY' then
        self.marginTop = value
        self.marginBottom = value
    end
    rawset(self, index, value)
end

---@diagnostic disable-next-line: duplicate-set-field
---@return ui.UIObject
function ui.UIObject:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    if o.marginX ~= nil then
        ui.UIObject.__newindex(o, 'marginX', o.marginX)
        o.marginX = nil
    end
    if o.marginY ~= nil then
        ui.UIObject.__newindex(o, 'marginY', o.marginY)
        o.marginY = nil
    end
    if o.margin ~= nil then
        ui.UIObject.__newindex(o, 'margin', o.margin)
        o.margin = nil
    end

    return o
end

function ui.UIObject:draw(term, x, y, requestedW, requestedH) end

function ui.UIObject:getSize(requestedW, requestedH) return 0, 0 end

function ui.UIObject:mount(term)
    self.mounted = true
end

function ui.UIObject:unMount(term)
    self.mounted = false
end

function ui.UIObject:onMonitorTouch(term, x, y, requestedW, requestedH) end

function ui.UIObject:onClick(term, x, y, button, requestedW, requestedH) end

function ui.UIObject:onMouseClick(term, x, y, button, requestedW, requestedH) end

---@class ui.Grid: ui.UIObject
ui.Grid = {
    -- ---@type number|nil|'100%'
    -- width = nil,
    -- ---@type number|nil|'100%'
    -- height = nil,

    ---@type number
    childWidth = nil,
    ---@type number
    childHeight = nil,
    backgroundColor = nil,
    textColor = nil,

    paddingLeft = 0,
    paddingTop = 0,
    paddingBottom = 0,
    paddingRight = 0,

    ---@type number|nil
    ---Shorthand to paddingLeft, paddingRight, paddingTop, paddingBottom
    padding = nil,
    ---@type number|nil
    ---Shorthand to paddingLeft, paddingRight
    paddingX = nil,
    ---@type number|nil
    ---Shorthand to paddingTop, paddingBottom
    paddingY = nil,

    -- ---@type number?
    -- minHeight = nil,
    -- ---@type number?
    -- minWidth = nil,
    -- ---@type number?
    -- maxHeight = nil,
    -- ---@type number?
    -- maxWidth = nil,
}
ui.Grid = ui.UIObject:new(ui.Grid)
function ui.Grid:__newindex(index, value)
    if index == 'padding' then
        self.paddingLeft = value
        self.paddingRight = value
        self.paddingTop = value
        self.paddingBottom = value
    elseif index == 'paddingX' then
        self.paddingLeft = value
        self.paddingRight = value
    elseif index == 'paddingY' then
        self.paddingTop = value
        self.paddingBottom = value
    end
    ui.UIObject.__newindex(self, index, value)
end

---@return ui.Grid
function ui.Grid:new(o)
    ui.UIObject.new(self, o)
    if o.paddingX ~= nil then
        ui.Block.__newindex(o, 'paddingX', o.paddingX)
        o.paddingX = nil
    end
    if o.paddingY ~= nil then
        ui.Block.__newindex(o, 'paddingY', o.paddingY)
        o.paddingY = nil
    end
    if o.padding ~= nil then
        ui.Block.__newindex(o, 'padding', o.padding)
        o.padding = nil
    end
    return o
end

function ui.Grid:replaceChildren(term, ...)
    for i = #self, 1, -1 do
        local child = self[i]
        if child.mounted then child:unMount(term) end
        self[i] = nil
    end
    local packed = table.pack(...)
    for i = 1, packed.n do
        self[i] = packed[i]
        if self.mounted then
            packed[i]:mount(term)
        end
    end
end

function ui.Grid:mount(term)
    for _, child in ipairs(self) do
        child:mount(term)
    end
    ui.UIObject.mount(self, term)
end

function ui.Grid:unMount(term)
    for _, child in ipairs(self) do
        child:unMount(term)
    end
    ui.UIObject.unMount(self, term)
end

function ui.Grid:getSize(requestedW, requestedH)
    requestedW = requestedW - self.paddingLeft - self.paddingRight
    requestedH = requestedH - self.paddingTop - self.paddingBottom
    local nElemsW, nElemsH = math.floor(requestedW / self.childWidth), math.floor(requestedH / self.childHeight)
    local width = nElemsW * self.childWidth + self.paddingLeft + self.paddingRight
    local height = nElemsH * self.childHeight + self.paddingTop + self.paddingBottom
    return width, height
end

function ui.Grid:draw(term, x, y, requestedW, requestedH)
    requestedW = requestedW - self.paddingLeft - self.paddingRight
    requestedH = requestedH - self.paddingTop - self.paddingBottom
    local nElemsW, nElemsH = math.floor(requestedW / self.childWidth), math.floor(requestedH / self.childHeight)
    local width = nElemsW * self.childWidth + self.paddingLeft + self.paddingRight
    local height = nElemsH * self.childHeight + self.paddingTop + self.paddingBottom

    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)

        for i = 0, height - 1 do
            term.setCursorPos(x, y + i)
            for _ = 0, width - 1 do
                term.write(" ")
            end
        end
    end

    for iy = 1, nElemsH do
        for ix = 1, nElemsW do

            local posX = x + self.paddingLeft + (ix - 1) * self.childWidth
            local posY = y + self.paddingTop + (iy - 1) * self.childHeight

            local i = ix + nElemsW * (iy - 1)
            local child = self[i]
            if child == nil then break end
            term.setTextColor(term.defaultTextColor)
            term.setBackgroundColor(term.defaultBackgroundColor)
            if self.textColor ~= nil then
                term.setTextColor(self.textColor)
            end
            if self.backgroundColor ~= nil then
                term.setBackgroundColor(self.backgroundColor)
            end
            child:draw(term, posX, posY, self.childWidth, self.childHeight)
            term.setTextColor(term.defaultTextColor)
            term.setBackgroundColor(term.defaultBackgroundColor)
        end
    end
end

local function gridFindChildAt(self, x, y, requestedW, requestedH)
    requestedW = requestedW - self.paddingLeft - self.paddingRight
    requestedH = requestedH - self.paddingTop - self.paddingBottom
    local nElemsW = math.floor(requestedW / self.childWidth)

    x = x - self.paddingLeft
    y = y - self.paddingTop

    local ix = math.floor(x / self.childWidth)
    local iy = math.floor(y / self.childHeight)
    
    -- man i hate that lua indexes start at one
    local relX, relY = (x - 1) % self.childWidth + 1, (y - 1) % self.childHeight + 1
    print(relX, relY, ix, iy, iy * nElemsW + ix)
    local child = self[iy * nElemsW + ix]
    return child, relX, relY
end

function ui.Grid:onMonitorTouch(term, x, y, requestedW, requestedH)
    local child, relX, relY = gridFindChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMonitorTouch(term, relX, relY, requestedW, requestedH)
    end
end

function ui.Grid:onClick(term, x, y, button, requestedW, requestedH)
    local child, relX, relY = gridFindChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onClick(term, relX, relY, button, requestedW, requestedH)
    end
end

function ui.Grid:onMouseClick(term, x, y, button, requestedW, requestedH)
    local child, relX, relY = gridFindChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMouseClick(term, relX, relY, button, requestedW, requestedH)
    end
end

---@class ui.Block: ui.UIObject
ui.Block = {
    ---@type number|nil|'100%'
    width = nil,
    ---@type number|nil|'100%'
    height = nil,
    backgroundColor = nil,
    textColor = nil,

    paddingLeft = 0,
    paddingTop = 0,
    paddingBottom = 0,
    paddingRight = 0,

    ---@type number|nil
    ---Shorthand to paddingLeft, paddingRight, paddingTop, paddingBottom
    padding = nil,
    ---@type number|nil
    ---Shorthand to paddingLeft, paddingRight
    paddingX = nil,
    ---@type number|nil
    ---Shorthand to paddingTop, paddingBottom
    paddingY = nil,

    ---@type number?
    minHeight = nil,
    ---@type number?
    minWidth = nil,
    ---@type number?
    maxHeight = nil,
    ---@type number?
    maxWidth = nil,

    ---Align content in the X dimension
    ---@type 'begin'|'center'|'spaceBetween'|'space'|'end'
    alignContentX = 'begin',
    ---Align content in the Y dimension
    ---@type 'begin'|'center'|'spaceBetween'|'space'|'end'
    alignContentY = 'begin',

    ---Align the children within the same line
    ---@type 'begin'|'center'|'end'
    alignChildren = 'begin',

    ---Direction children should be stacked first
    ---@type 'right'|'bottom'
    childrenDirection = 'right',
}
ui.Block = ui.UIObject:new(ui.Block)
function ui.Block:__newindex(index, value)
    if index == 'padding' then
        self.paddingLeft = value
        self.paddingRight = value
        self.paddingTop = value
        self.paddingBottom = value
    elseif index == 'paddingX' then
        self.paddingLeft = value
        self.paddingRight = value
    elseif index == 'paddingY' then
        self.paddingTop = value
        self.paddingBottom = value
    end
    ui.UIObject.__newindex(self, index, value)
end

---@return ui.Block
function ui.Block:new(o)
    ui.UIObject.new(self, o)
    if o.paddingX ~= nil then
        ui.Block.__newindex(o, 'paddingX', o.paddingX)
        o.paddingX = nil
    end
    if o.paddingY ~= nil then
        ui.Block.__newindex(o, 'paddingY', o.paddingY)
        o.paddingY = nil
    end
    if o.padding ~= nil then
        ui.Block.__newindex(o, 'padding', o.padding)
        o.padding = nil
    end
    return o
end

function ui.Block:replaceChildren(term, ...)
    for i = #self, 1, -1 do
        local child = self[i]
        if child.mounted then child:unMount(term) end
        self[i] = nil
    end
    local packed = table.pack(...)
    for i = 1, packed.n do
        self[i] = packed[i]
        if self.mounted then
            packed[i]:mount(term)
        end
    end
end

function ui.Block:mount(term)
    for _, child in ipairs(self) do
        child:mount(term)
    end
    ui.UIObject.mount(self, term)
end

function ui.Block:unMount(term)
    for _, child in ipairs(self) do
        child:unMount(term)
    end
    ui.UIObject.unMount(self, term)
end

---@param self ui.Block
local function blockComputeContent(self, blockWidth, blockHeight, start, func)
    if blockWidth == nil then blockWidth = 0 end
    if blockHeight == nil then blockHeight = 0 end
    local availableW = blockWidth
    local widthThisLine = 0
    local maxHeightThisLine = 0

    local totalW, totalH = 0, 0
    local totalLines = 0

    local iInLine = 0

    for i = start or 1, #self do
        local child = self[i]
        local childAvailableW = availableW - child.marginRight - child.marginLeft
        local childAvailableH = blockHeight - totalH - child.marginTop - child.marginBottom
        local w, h = child:getSize(childAvailableW, childAvailableH)
        if w == '100%' then w = blockWidth - child.marginRight - child.marginLeft end
        if h == '100%' then h = blockHeight - child.marginTop - child.marginBottom end

        local realW = w + child.marginRight + child.marginLeft
        local realH = h + child.marginTop + child.marginBottom

        if self.childrenDirection == 'right' then
            if availableW - realW < 0 and i ~= 1 then
                -- wrap

                availableW = blockWidth

                totalW = math.max(widthThisLine, totalW)
                totalH = totalH + maxHeightThisLine

                childAvailableW = availableW - child.marginRight - child.marginLeft
                childAvailableH = blockHeight - totalH - child.marginTop - child.marginBottom
                w, h = child:getSize(childAvailableW, childAvailableH)
                if w == '100%' then w = blockWidth - child.marginRight - child.marginLeft end
                if h == '100%' then h = blockHeight - child.marginTop - child.marginBottom end

                realW = w + child.marginRight + child.marginLeft
                realH = h + child.marginTop + child.marginBottom

                maxHeightThisLine = realH

                availableW = availableW - realW

                widthThisLine = 0
                totalLines = totalLines + 1
                iInLine = 1
            else
                availableW = availableW - realW
                maxHeightThisLine = math.max(maxHeightThisLine, realH)
                widthThisLine = widthThisLine + realW
                totalW = math.max(widthThisLine, totalW)
                iInLine = iInLine + 1
            end
        end

        if i == 1 then totalLines = 1 end

        if func then
            if not func(i, iInLine, totalLines, widthThisLine, maxHeightThisLine, child, realW, realH) then break end
        end

        -- if iInLine == 1 and i ~= 1 then
        -- 	if self.childrenDirection == 'right' then
        -- 		maxHeightThisLine = 0
        -- 	end
        -- end
    end

    if self.childrenDirection == 'right' then
        totalH = totalH + maxHeightThisLine
    end

    return totalW, totalH, totalLines
end

local function blockComputeSize(self, requestedW, requestedH)
    if self._cachedSize ~= nil
        and self._cachedSize[1] == requestedW
        and self._cachedSize[2] == requestedH
    then
        return self._cachedSize[3], self._cachedSize[4], self._cachedSize[5],
            self._cachedSize[6], self._cachedSize[7]
    end

    if requestedW == nil then requestedW = self.paddingLeft + self.paddingRight end
    if requestedH == nil then requestedH = self.paddingTop + self.paddingBottom end
    local contentW, contentH, nLines = blockComputeContent(
        self,
        requestedW - self.paddingLeft - self.paddingRight,
        requestedH - self.paddingTop - self.paddingBottom
    )

    local usedWidth = contentW + self.paddingLeft + self.paddingRight
    local usedHeight = contentH + self.paddingTop + self.paddingBottom

    if self.minWidth ~= nil then usedWidth = math.max(usedWidth, self.minWidth) end
    if self.maxWidth ~= nil then usedWidth = math.min(usedWidth, self.maxWidth) end
    if self.minHeight ~= nil then usedHeight = math.max(usedHeight, self.minHeight) end
    if self.maxHeight ~= nil then usedHeight = math.min(usedHeight, self.maxHeight) end

    if self.height ~= nil then usedHeight = self.height end
    if self.width ~= nil then usedWidth = self.width end

    self._cachedSize = self._cachedSize or {}
    self._cachedSize[1], self._cachedSize[2], self._cachedSize[3],
    self._cachedSize[4], self._cachedSize[5],
    self._cachedSize[6], self._cachedSize[7] =
        requestedW, requestedH, usedWidth, usedHeight, contentW, contentH, nLines

    return usedWidth, usedHeight, contentW, contentH, nLines
end

function ui.Block:getSize(requestedW, requestedH)
    return blockComputeSize(self, requestedW, requestedH)
end

local function blockCalcSlackFromMiddle(max, nElems, i)
    local v = math.floor(max / nElems)
    local rem = max % nElems
    local skip = nElems / 2 - rem / 2

    if i < rem + math.ceil(skip) and i > math.floor(skip) then v = v + 1 end
    return v
end

local function blockAlign(alignContent, slack, i, nElems)
    if alignContent == 'begin' then
        return 0
    elseif alignContent == 'end' then
        if i == 1 then return slack end
        return 0
    elseif alignContent == 'center' then
        if i == 1 then return math.floor(slack / 2) end
        return 0
    elseif alignContent == 'space' then
        slack = blockCalcSlackFromMiddle(slack, nElems + 1, i)
        return slack
    elseif alignContent == 'spaceBetween' then
        if i == 1 then return 0 end

        slack = blockCalcSlackFromMiddle(slack, nElems - 1, i - 1)
        return slack
    end
    return 0
end

local function blockComputeFullTiling(self, blockWidth, blockHeight, contentW, contentH, nLines, drawChild)
    local posX, posY = self.paddingLeft, self.paddingTop

    local lineHeight = 0
    local lineWidth = 0
    local elemsInLine = 0
    blockComputeContent(self, blockWidth, blockHeight, 1,
        function(i, iInLine, iLine, wThisLine_, maxHThisLine_, child, realW, realH)
            if i ~= 1 and iInLine == 1 then
                posY = posY + lineHeight
                posX = self.paddingLeft
            end

            if iInLine == 1 then
                -- get line height!
                local first = true
                blockComputeContent(self, blockWidth, blockHeight, i, function(_, iInLine_, _, wThisLine, maxHThisLine)
                    if not first and iInLine_ == 1 then
                        return false -- stop iteration
                    end

                    lineHeight = maxHThisLine
                    lineWidth = wThisLine
                    elemsInLine = iInLine_
                    first = false
                    return true
                end)
            end

            local slackW = blockWidth - lineWidth -- per line slack
            local slackH = blockHeight - contentH -- whole content slack

            posX = posX + blockAlign(self.alignContentX, slackW, iInLine, elemsInLine)
            if iInLine == 1 then
                posY = posY + blockAlign(self.alignContentY, slackH, iLine, nLines)
            end

            -- between children align
            local correctedY = posY + blockAlign(self.alignChildren, lineHeight - realH, 1, 1)

            if not drawChild(child,
                    posX + child.marginLeft, correctedY + child.marginTop,
                    realW - child.marginLeft - child.marginRight, realH - child.marginTop - child.marginBottom)
            then
                return false
            end

            posX = posX + realW

            return true
        end)
end

function ui.Block:draw(term, x, y, requestedW, requestedH)
    local blockWidth = requestedW - self.paddingLeft - self.paddingRight
    local blockHeight = requestedH - self.paddingTop - self.paddingBottom
    local width, height, contentW, contentH, nLines = blockComputeSize(self, requestedW, requestedH)
    if width == '100%' then width = requestedW end
    if height == '100%' then height = requestedH end

    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)

        for i = 0, height - 1 do
            term.setCursorPos(x, y + i)
            for _ = 0, width - 1 do
                term.write(" ")
            end
        end
    end

    blockComputeFullTiling(self, blockWidth, blockHeight, contentW, contentH, nLines,
        function(child, posX, posY, availableW, availableH)
            term.setTextColor(term.defaultTextColor)
            term.setBackgroundColor(term.defaultBackgroundColor)
            if self.textColor ~= nil then
                term.setTextColor(self.textColor)
            end
            if self.backgroundColor ~= nil then
                term.setBackgroundColor(self.backgroundColor)
            end
            child:draw(term, x + posX, y + posY, availableW, availableH)
            term.setTextColor(term.defaultTextColor)
            term.setBackgroundColor(term.defaultBackgroundColor)
            return true
        end)

    self._cachedSize = nil
end

local function blockFindChildAt(self, x, y, requestedW, requestedH)
    if self.transparent then return end
    local blockWidth = requestedW - self.paddingLeft - self.paddingRight
    local blockHeight = requestedH - self.paddingTop - self.paddingBottom

    x = x + self.paddingLeft

    local contentW, contentH, nLines = blockComputeContent(self, blockWidth, blockHeight)

    local foundChild, relX, relY
    blockComputeFullTiling(self, blockWidth, blockHeight, contentW, contentH, nLines,
        function(child, posX, posY, availableW, availableH)
            posX = posX + self.paddingLeft
            posY = posY + self.paddingTop
            if x >= posX and x <= posX + availableW and y >= posY and y <= posY + availableH then
                relX = x - posX
                relY = y - posY
                foundChild = child
                return false
            end
            return true
        end)

    return foundChild, relX, relY
end

function ui.Block:onMonitorTouch(term, x, y, requestedW, requestedH)
    local child, relX, relY = blockFindChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMonitorTouch(term, relX, relY, requestedW, requestedH)
    end
end

function ui.Block:onClick(term, x, y, button, requestedW, requestedH)
    local child, relX, relY = blockFindChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onClick(term, relX, relY, button, requestedW, requestedH)
    end
end

function ui.Block:onMouseClick(term, x, y, button, requestedW, requestedH)
    local child, relX, relY = blockFindChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMouseClick(term, relX, relY, button, requestedW, requestedH)
    end
end

local function stringDisplaySize(s)
    if string.len(s) == 0 then return 0, 0 end
    local maxWidth, maxHeight = 0, 1
    local currentWidth = 0
    for i = 1, string.len(s) do
        local c = s:sub(i, i)

        currentWidth = currentWidth + 1
        maxWidth = math.max(maxWidth, currentWidth)
        if c == '\n' then
            maxHeight = maxHeight + 1
            currentWidth = 0
        end
    end
    return maxWidth, maxHeight
end

---@class ui.Text: ui.UIObject
ui.Text = {
    transparent = false,
    text = nil,
    backgroundColor = nil,
    textColor = nil,
    width = nil,
    height = nil
}
ui.Text = ui.UIObject:new(ui.Text)
---@return ui.Text
function ui.Text:new(obj)
    ui.UIObject.new(self, obj)
    obj.text = obj.text
    obj.width, obj.height = stringDisplaySize(obj.text)
    return obj
end

function ui.Text:draw(term, x, y, parentW, parentH)
    if self.transparent then return end
    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)
    end
    if self.textColor ~= nil then
        term.setTextColor(self.textColor)
    end
    term.setCursorPos(x, y)
    local offsetWidth, offsetHeight = 0, 0
    for i = 1, string.len(self.text) do
        local c = string.sub(self.text, i, i)

        if offsetWidth < parentW and offsetHeight < parentH then
            term.write(c)
        end

        offsetWidth = offsetWidth + 1
        if c == '\n' then
            offsetWidth = 0
            offsetHeight = offsetHeight + 1
            term.setCursorPos(x + offsetWidth, y + offsetWidth)
        end
    end
end

function ui.Text:getSize()
    return self.width, self.height
end

---@class ui.TextInput: ui.UIObject
ui.TextInput = {
    text = "",
    backgroundColor = nil,
    textColor = nil,
    width = 25,
    height = 1,
    focus = true,
    _globalOnChar = nil,
    _globalOnKey = nil
}
ui.TextInput = ui.UIObject:new(ui.TextInput)

function ui.TextInput:draw(term, x, y, parentW, parentH)
    if self.transparent then return end
    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)
    end
    if self.textColor ~= nil then
        term.setTextColor(self.textColor)
    end
    term.setCursorPos(x, y)
    -- the -1 is because the blink position takes a char
    local shownText = string.sub(self.text, math.max(string.len(self.text) - self.width - 1, 0), string.len(self.text))
    term.write(shownText)

    local left = self.width - string.len(shownText)
    for _ = 1, left do
        term.write(' ')
    end

    if self.focus then
        term.blinkPositionX, term.blinkPositionY = x + string.len(shownText), y
        term.blinkBackgroundColor = self.backgroundColor
        term.blinkTextColor = self.textColor
    end
end

function ui.TextInput:mount(term)
    self._globalOnChar = function(_, c)
        self.text = self.text .. c
        term.setNeedsRedraw()
        self:onChange(term, self.text)
    end
    self._globalOnKey = function(_, key)
        if key == 259 and string.len(self.text) > 0 then -- backspace
            self.text = string.sub(self.text, 1, string.len(self.text) - 1)
            term.setNeedsRedraw()
            self:onChange(term, self.text)
        end
    end
    term.addGlobalListener('char', self._globalOnChar)
    term.addGlobalListener('key', self._globalOnKey)
end

function ui.TextInput:unMount(term)
    term.removeGlobalListener('char', self._globalOnChar)
    term.removeGlobalListener('key', self._globalOnKey)
end

function ui.TextInput:getSize()
    return self.width, self.height
end

function ui.TextInput:onChange(term, newText) end

local function wrapTerm(term)
    ---@class UIContext: Redirect
    local newTerm = {
        defaultBackgroundColor = colors.black,
        defaultTextColor = colors.white,
        blinkPositionX = nil,
        blinkPositionY = nil,
        blinkBackgroundColor = colors.black,
        blinkTextColor = colors.white,
        _globalListeners = {},
        _timeouts = {},
        _needsRedraw = false,
        _stopFlag = false,
        ---@type fun(...: fun())
        addTask = nil,
        ---@type fun(...: fun())
        removeTask = nil,
    }
    function newTerm.addGlobalListener(event, handler)
        local obj = newTerm._globalListeners[event] or {}
        table.insert(obj, handler)
        newTerm._globalListeners[event] = obj
    end

    function newTerm.removeGlobalListener(event, handler)
        local obj = newTerm._globalListeners[event] or {}
        local index = util.arrayIndexOf(handler)
        if index > 0 then
            table.remove(obj, index)
            newTerm._globalListeners[event] = obj
        end
        return index > 0
    end

    function newTerm.scheduleDelayed(func, seconds)
        local timer = os.startTimer(seconds)
        newTerm._timeouts[timer] = func
    end

    function newTerm.close()
        newTerm._stopFlag = true
    end

    function newTerm.setNeedsRedraw()
        newTerm._needsRedraw = true
    end

    setmetatable(newTerm, { __index = term })
    return newTerm
end

local function redraw(obj, termObj)
    local w, h = termObj.getSize()
    termObj.setCursorPos(1, 1)
    termObj.setBackgroundColor(termObj.defaultBackgroundColor)
    termObj.setTextColor(termObj.defaultTextColor)
    termObj.setCursorBlink(false)
    termObj.setTextScale(0.5)
    obj:draw(termObj, 1, 1, w, h)
    if termObj.blinkPositionX ~= nil and termObj.blinkPositionY ~= nil then
        termObj.setCursorPos(termObj.blinkPositionX, termObj.blinkPositionY)
        termObj.setBackgroundColor(termObj.blinkBackgroundColor)
        termObj.setTextColor(termObj.blinkTextColor)
        termObj.setCursorBlink(true)
    end
end

---@param obj ui.UIObject
---@param termObj Redirect
function ui.drawLoop(obj, termObj)
    termObj = wrapTerm(termObj or term)

    util.parallelGroup(function(addTask, removeTask)
        termObj.addTask = addTask
        termObj.removeTask = removeTask

        obj:mount(termObj)

        termObj.clear()
        redraw(obj, termObj)
        while not termObj._stopFlag do
            termObj._needsRedraw = false
            local bag = table.pack(os.pullEvent())
            local event, a, b, c = table.unpack(bag, 1, bag.n)

            local w, h = termObj.getSize()
            if event == 'monitor_touch' then
                obj:onMonitorTouch(termObj, b, c, w, h)
                obj:onClick(termObj, b, c, 0, w, h)
            elseif event == 'mouse_click' then
                obj:onMouseClick(termObj, b, c, a, w, h)
                obj:onClick(termObj, b, c, a, w, h)
            elseif event == 'timer' then
                local func = termObj._timeouts[a]
                if func then
                    func(termObj)
                    termObj._timeouts[a] = nil
                end
            end

            if termObj._globalListeners[event] ~= nil then
                for _, handler in ipairs(termObj._globalListeners[event]) do
                    handler(table.unpack(bag, 1, bag.n))
                end
            end

            if termObj._needsRedraw then
                redraw(obj, termObj)
            end
        end

        obj:unMount(termObj)
    end)
end

return ui
