os.loadAPI("/firmware/apis/util.lua")

---@class UIObject
UIObject = {
    transparent = false,
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
function UIObject:__newindex(index, value)
    if index == 'margin' then
        self.marginLeft = value
        self.marginRight = value
        self.marginTom = value
        self.marginBottom = value
    elseif index == 'marginX' then
        self.marginLeft = value
        self.marginRight = value
    elseif index == 'marginY' then
        self.marginTom = value
        self.marginBottom = value
    end
    rawset(self, index, value)
end

---@diagnostic disable-next-line: duplicate-set-field
function UIObject:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    if o.marginX ~= nil then
        UIObject.__newindex(o, 'marginX', o.marginX)
        o.marginX = nil
    end
    if o.marginY ~= nil then
        UIObject.__newindex(o, 'marginY', o.marginY)
        o.marginY = nil
    end
    if o.margin ~= nil then
        UIObject.__newindex(o, 'margin', o.margin)
        o.margin = nil
    end

    return o
end

function UIObject:draw(term, x, y, requestedW, requestedH) end

function UIObject:getSize(requestedW, requestedH) return 0, 0 end

function UIObject:onMonitorTouch(x, y, requestedW, requestedH) end

function UIObject:onClick(x, y, button, requestedW, requestedH) end

function UIObject:onMouseClick(x, y, button, requestedW, requestedH) end

---@class Block: UIObject
Block = {
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
Block = UIObject:new(Block)
function Block:__newindex(index, value)
    if index == 'padding' then
        self.paddingLeft = value
        self.paddingRight = value
        self.paddingTom = value
        self.paddingBottom = value
    elseif index == 'paddingX' then
        self.paddingLeft = value
        self.paddingRight = value
    elseif index == 'paddingY' then
        self.paddingTom = value
        self.paddingBottom = value
    end
    UIObject.__newindex(self, index, value)
end
function Block:new(o)
    UIObject.new(self, o)
    if o.paddingX ~= nil then
        Block.__newindex(o, 'paddingX', o.paddingX)
        o.paddingX = nil
    end
    if o.paddingY ~= nil then
        Block.__newindex(o, 'paddingY', o.paddingY)
        o.paddingY = nil
    end
    if o.padding ~= nil then
        Block.__newindex(o, 'padding', o.padding)
        o.padding = nil
    end
    return o
end

---@param self Block
local function computeContent(self, blockWidth, blockHeight, start, func)
    if blockWidth == nil then blockWidth = 0 end
    if blockHeight == nil then blockHeight = 0 end
    local availableW = blockWidth
    local availableH = blockHeight
    local widthThisLine = 0
    local maxHeightThisLine = 0

    local totalW, totalH = 0, 0
    local totalLines = 0

    local iInLine = 0

    for i = start or 1, #self do
        local child = self[i]
        local childAvailableW = availableW - child.marginRight - child.marginLeft
        local childAvailableH = availableH - child.marginTop - child.marginBottom
        local w, h = child:getSize(childAvailableW, childAvailableH)
        if w == '100%' then w = blockWidth - child.marginRight - child.marginLeft end
        if h == '100%' then h = blockHeight - child.marginTop - child.marginBottom end

        local realW = w + child.marginRight + child.marginLeft
        local realH = h + child.marginTop + child.marginBottom

        if self.childrenDirection == 'right' then
            availableW = availableW - realW

            if availableW < 0 and i ~= 1 then
                -- wrap

                availableW = blockWidth

                childAvailableW = availableW - child.marginRight - child.marginLeft
                childAvailableH = availableH - child.marginTop - child.marginBottom
                w, h = child:getSize(childAvailableW, childAvailableH)
                if w == '100%' then w = blockWidth - child.marginRight - child.marginLeft end
                if h == '100%' then h = blockHeight - child.marginTop - child.marginBottom end

                realW = w + child.marginRight + child.marginLeft
                realH = h + child.marginTop + child.marginBottom

                totalW = math.max(widthThisLine, totalW)
                totalH = totalH + maxHeightThisLine

                maxHeightThisLine = realH

                availableW = 0
                availableH = availableH - realH

                widthThisLine = 0
                totalLines = totalLines + 1
                iInLine = 1
            else
                maxHeightThisLine = math.max(maxHeightThisLine, realH)
                widthThisLine = widthThisLine + realW
                totalW = totalW + realW
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

local function sizeFromContentSize(self, contentW, contentH, requestedW, requestedH)
    local usedWidth = contentW + self.paddingLeft + self.paddingRight
    local usedHeight = contentH + self.paddingTop + self.paddingBottom

    if self.minWidth ~= nil then usedWidth = math.max(usedWidth, self.minWidth) end
    if self.maxWidth ~= nil then usedWidth = math.min(usedWidth, self.maxWidth) end
    if self.minHeight ~= nil then usedHeight = math.max(usedHeight, self.minHeight) end
    if self.maxHeight ~= nil then usedHeight = math.min(usedHeight, self.maxHeight) end

    if self.height ~= nil then usedHeight = self.height end
    if self.width ~= nil then usedWidth = self.width end

    return usedWidth, usedHeight
end

function Block:getSize(requestedW, requestedH)
    if requestedW == nil then requestedW = self.paddingLeft + self.paddingRight end
    if requestedH == nil then requestedH = self.paddingTop + self.paddingBottom end
    local contentW, contentH = computeContent(
        self,
        requestedW - self.paddingLeft - self.paddingRight,
        requestedH - self.paddingTop - self.paddingBottom
    )
    return sizeFromContentSize(self, contentW, contentH, requestedW, requestedH)
end

local function calcSlackFromMiddle(max, nElems, i)
    local v = math.floor(max / nElems)
    local rem = max % nElems
    local skip = nElems / 2 - rem / 2

    if i < rem + math.ceil(skip) and i > math.floor(skip) then v = v + 1 end
    return v
end

local function align(alignContent, slack, i, nElems)
    if alignContent == 'begin' then
        return 0
    elseif alignContent == 'end' then
        if i == 1 then return slack end
        return 0
    elseif alignContent == 'center' then
        if i == 1 then return math.floor(slack / 2) end
        return 0
    elseif alignContent == 'space' then
        slack = calcSlackFromMiddle(slack, nElems + 1, i)
        return slack
    elseif alignContent == 'spaceBetween' then
        if i == 1 then return 0 end

        slack = calcSlackFromMiddle(slack, nElems - 1, i - 1)
        return slack
    end
    return 0
end

local function computeFullTiling(self, blockWidth, blockHeight, contentW, contentH, nLines, drawChild)
    local posX, posY = x + self.paddingLeft, y + self.paddingTop

    local lineHeight = 0
    local lineWidth = 0
    local elemsInLine = 0
    computeContent(self, blockWidth, blockHeight, 1,
        function(i, iInLine, iLine, wThisLine_, maxHThisLine_, child, realW, realH)
            if i ~= 1 and iInLine == 1 then
                posY = posY + lineHeight
                posX = x + self.paddingLeft
            end

            if iInLine == 1 then
                -- get line height!
                local first = true
                computeContent(self, blockWidth, blockHeight, i, function(_, iInLine_, _, wThisLine, maxHThisLine)
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

            posX = posX + align(self.alignContentX, slackW, iInLine, elemsInLine)
            if iInLine == 1 then
                posY = posY + align(self.alignContentY, slackH, iLine, nLines)
            end

            -- between children align
            local correctedY = posY + align(self.alignChildren, lineHeight - realH, 1, 1)

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

function Block:draw(term, x, y, requestedW, requestedH)
    if self.transparent then return end
    local blockWidth = requestedW - self.paddingLeft - self.paddingRight
    local blockHeight = requestedH - self.paddingTop - self.paddingBottom

    local contentW, contentH, nLines = computeContent(self, blockWidth, blockHeight)
    local width, height = sizeFromContentSize(self, contentW, contentH, requestedW, requestedH)
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

    computeFullTiling(self, blockWidth, blockHeight, contentW, contentH, nLines,
        function(child, posX, posY, availableW, availableH)
            term.setTextColor(term.defaultTextColor)
            term.setBackgroundColor(term.defaultBackgroundColor)
            if self.textColor ~= nil then
                term.setTextColor(self.textColor)
            end
            if self.backgroundColor ~= nil then
                term.setBackgroundColor(self.backgroundColor)
            end
            child:draw(term, posX, posY, availableW, availableH)
            term.setTextColor(term.defaultTextColor)
            term.setBackgroundColor(term.defaultBackgroundColor)
            return true
        end)
end

local function findChildAt(self, x, y, requestedW, requestedH)
    if self.transparent then return end
    local blockWidth = requestedW - self.paddingLeft - self.paddingRight
    local blockHeight = requestedH - self.paddingTop - self.paddingBottom

    local contentW, contentH, nLines = computeContent(self, blockWidth, blockHeight)

    local foundChild, relX, relY
    computeFullTiling(self, blockWidth, blockHeight, contentW, contentH, nLines,
        function(child, posX, posY, availableW, availableH)
            if x >= posX and x < posX + availableW and y >= posY and y < posY + availableH then
                relX = x - posX
                relY = y - posY
                foundChild = child
                return false
            end
            return true
        end)

    return foundChild, relX, relY
end

function Block:onMonitorTouch(x, y, requestedW, requestedH)
    local child, relX, relY = findChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMonitorTouch(relX, relY, requestedW, requestedH)
    end
end

function Block:onClick(x, y, button, requestedW, requestedH)
    local child, relX, relY = findChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMonitorTouch(relX, relY, button, requestedW, requestedH)
    end
end

function Block:onMouseClick(x, y, button, requestedW, requestedH)
    local child, relX, relY = findChildAt(self, x, y, requestedW, requestedH)
    if child then
        child:onMonitorTouch(relX, relY, button, requestedW, requestedH)
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

Text = UIObject:new {
    text = nil,
    backgroundColor = nil,
    textColor = nil,
}
function Text:new(obj)
    UIObject.new(self, obj)
    obj.text = obj.text
    obj.width, obj.height = stringDisplaySize(obj.text)
    return obj
end

function Text:draw(term, x, y, parentW, parentH)
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
        local c = self.text:sub(i, i)

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

function Text:getSize()
    return self.width, self.height
end

local function wrapTerm(term)
    local newTerm = {
        defaultBackgroundColor = colors.black,
        defaultTextColor = colors.white,
        blinkPositionX = nil,
        blinkPositionY = nil,
        blinkBackgroundColor = colors.black,
        blinkTextColor = colors.white,
    }
    setmetatable(newTerm, { __index = term })
    return newTerm
end

local function redraw(obj, termObj)
    local w, h = termObj.getSize()
    termObj.setCursorPos(1, 1)
    termObj.setBackgroundColor(termObj.defaultBackgroundColor)
    termObj.setTextColor(termObj.defaultTextColor)
    termObj.clear()
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

---@diagnostic disable-next-line: lowercase-global
function drawLoop(obj, termObj)
    termObj = wrapTerm(termObj or term)

    while true do
        redraw(obj, termObj)

        local event, a, b, c = os.pullEvent()

        local w, h = termObj.getSize()

        if event == 'monitor_touch' then
            obj:onMonitorTouch(b, c, w, h)
            obj:onClick(b, c, 0, w, h)
        elseif event == 'mouse_click' then
            obj:onMouseClick(b, c, a, w, h)
            obj:onClick(b, c, a, w, h)
        end
    end
end
