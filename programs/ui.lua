os.loadAPI("/firmware/apis/util.lua")

---@class UIObject
UIObject = {
    transparent = false,
    marginLeft = 0,
    marginTop = 0,
    marginBottom = 0,
    marginRight = 0,
}
function UIObject:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function UIObject:draw(term, x, y, requestedW, requestedH) end

function UIObject:getSize(requestedW, requestedH) return 0, 0 end

---@class Block: UIObject
Block = {
    ---@type number|nil|'fill'
    width = nil,
    ---@type number|nil|'fill'
    height = nil,
    backgroundColor = nil,
    textColor = nil,
    paddingLeft = 0,
    paddingTop = 0,
    paddingBottom = 0,
    paddingRight = 0,

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

    ---Direction children should be stacked first
    ---@type 'right'|'bottom'
    childrenDirection = 'right',
}
Block = UIObject:new(Block)

---@param self Block
local function computeContent(self, blockWidth, blockHeight, start, func)
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

        local realW = w + child.marginRight + child.marginLeft
        local realH = h + child.marginTop + child.marginBottom

        if self.childrenDirection == 'right' then
            widthThisLine = widthThisLine + realW
            maxHeightThisLine = math.max(maxHeightThisLine, realH)
            availableW = availableW - realW
            if availableW <= 0 and i ~= 1 then
                -- wrap
                totalW = math.max(widthThisLine, totalW)
                totalH = totalH + maxHeightThisLine

                availableW = blockWidth
                availableH = availableH - realH

                childAvailableW = availableW - child.marginRight - child.marginLeft
                childAvailableH = availableH - child.marginTop - child.marginBottom
                w, h = child:getSize(childAvailableW, childAvailableH)

                realW = w + child.marginRight + child.marginLeft
                realH = h + child.marginTop + child.marginBottom

                maxHeightThisLine = 0
                widthThisLine = 0
                totalLines = totalLines + 1
                iInLine = 1
            else
                totalW = totalW + w
                iInLine = iInLine + 1
            end
        end

        if i == 1 then totalLines = 1 end

        if func then
            if not func(i, iInLine, totalLines, widthThisLine, maxHeightThisLine, child, realW, realH) then break end
        end
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

    if self.width == 'full' then usedWidth = math.max(requestedW, usedWidth) end
    if self.height == 'full' then usedHeight = math.max(requestedH, usedHeight) end

    print(contentW, contentH, requestedW, requestedH, usedWidth, usedHeight)

    return usedWidth, usedHeight
end

function Block:getSize(requestedW, requestedH)
    local contentW, contentH = computeContent(
        self,
        requestedW - self.paddingLeft - self.paddingRight,
        requestedH - self.paddingTop - self.paddingBottom
    )
    return sizeFromContentSize(self, contentW, contentH, requestedW, requestedH)
end

local function drawChild(self, term, child, posX, posY, availableW, availableH)
    print("call", posX, posY, availableW, availableH)
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
end

local function calcSlackFromMiddle(max, nElems, i)
    local v = math.floor(max / nElems)
    local rem = max % nElems
    local skip = math.floor(nElems / 2 - rem / 2 + 0.5)

    if i < rem + skip and i >= skip then v = v + 1 end
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

        slack = calcSlackFromMiddle(slack, nElems - 1, i)
        return slack
    end
    return 0
end

function Block:draw(term, x, y, requestedW, requestedH)
    if self.transparent then return end
    local blockWidth = requestedW - self.paddingLeft - self.paddingRight
    local blockHeight = requestedH - self.paddingTop - self.paddingBottom

    local contentW, contentH, nLines = computeContent(self, blockWidth, blockHeight)
    local width, height = sizeFromContentSize(self, contentW, contentH, requestedW, requestedH)

    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)

        for i = 0, height - 1 do
            term.setCursorPos(x, y + i)
            for _ = 0, width - 1 do
                term.write(" ")
            end
        end
    end

    local posX, posY = x + self.paddingLeft, y + self.paddingTop

    local lineHeight = 0
    local lineWidth = 0
    local elemsInLine = 0
    computeContent(self, blockWidth, blockHeight, 1, function(i, iInLine, iLine, _, _, child, realW, realH)
        if i ~= 1 and iInLine == 1 then
            posY = posY + lineHeight
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

            posX = x + self.paddingLeft
        end

        local slackW = blockWidth - lineWidth   -- per line slack
        local slackH = blockHeight - lineHeight -- in line slack

        print(posX, posY)

        posX = posX + align(self.alignContentX, slackW, iInLine, elemsInLine)
        posY = posY + align(self.alignContentY, slackH, iLine, nLines)
        drawChild(self, term, child,
        	posX + child.marginLeft, posY + child.marginTop,
        	realW - child.marginLeft - child.marginRight, realH - child.marginTop - child.marginBottom)

        posX = posX + realW

        return true
    end)
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
    Block.new(self, obj)
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
    if term == nil then return nil end
    local newTerm = {
        defaultBackgroundColor = colors.black,
        defaultTextColor = colors.white,
        blinkPositionX = nil,
        blinkPositionY = nil,
        blinkBackgroundColor = colors.black,
        blinkTextColor = colors.white,
    }
    setmetatable(newTerm, {__index=term})
    return newTerm
end

function draw(obj, term)
    term = wrapTerm(term or _G.term)

    if not term then
        error("no term")
    end
    local w, h = term.getSize()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(term.defaultBackgroundColor)
    term.setTextColor(term.defaultTextColor)
    term.clear()
    term.setTextScale(0.7)
    obj:draw(term, 1, 1, w, h)
    if term.blinkPositionX ~= nil and term.blinkPositionY ~= nil then
        term.setCursorPos(term.blinkPositionX, term.blinkPositionY)
        term.setBackgroundColor(term.blinkBackgroundColor)
        term.setTextColor(term.blinkTextColor)
        term.setCursorBlink(true)
    end
end

function makeBlock()
	return Block:new {
        paddingTop = 1,
        paddingRight = 1,
        paddingBottom = 1,
        paddingLeft = 1,
        marginTop = 1,
        marginRight = 1,
        marginBottom = 1,
        marginLeft = 1,
        backgroundColor = colors.gray,
        Text:new { text = "Hello!" }
    }
end

local interface = Block:new {
    width = 'full',
    height = 'full',
    backgroundColor = colors.yellow,
    Text:new { text = 'begin' },
    Block:new {
    	width = 'full',
	    alignContentX = 'begin',
	    alignContentY = 'begin',
    	makeBlock(),
    },
    Block:new {
    	width = 'full',
	    alignContentX = 'begin',
	    alignContentY = 'begin',
    	makeBlock(),
    	makeBlock(),
    },
    Block:new {
    	width = 'full',
	    alignContentX = 'begin',
	    alignContentY = 'begin',
    	makeBlock(),
    	makeBlock(),
    	makeBlock(),
    },
}

local monitor = peripheral.wrap('right')
draw(interface, monitor)
