os.loadAPI("/firmware/apis/util.lua")

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
function UIObject:getSize(requestedW, requestedH) end

Block = UIObject:new {
    width = 'fill',
    height = 'fill',
    backgroundColor = nil,
    textColor = nil,
    paddingLeft = 0,
    paddingTop = 0,
    paddingBottom = 0,
    paddingRight = 0,

    minHeight = nil,
    minWidth = nil,
    maxHeight = nil,
    maxWidth = nil,

    childrenDirection = 'right',
    centerElements = false
}

local function blockTiling(self, requestedW, requestedH, func)
    local function computeTiling(onlyOneLine, start)
        local posX, posY = (self.paddingLeft or 0), (self.paddingTop or 0)

        local blockWidth = requestedW - (self.paddingLeft or 0) - (self.paddingRight or 0)
        local blockHeight = requestedH - (self.paddingTop or 0) - (self.paddingBottom or 0)
        local availableW = blockWidth
        local availableH = blockHeight

        local totalW, totalH = 0, 0

        local maxWidthThisLine = 0
        local maxHeightThisLine = 0
        if not onlyOneLine then maxWidthThisLine, maxHeightThisLine = computeTiling(true, 1) end

        for i = start or 1, #self do
            local child = self[i]
            local w, h = child:getSize(availableW, availableH)
        	print(availableW, availableH, w, h)

            posX, posY = posX + (child.marginLeft or 0), posY + (child.marginTop or 0)

            local correctedX, correctedY = posX, posY
            if self.centerItems then
                if self.childrenDirection == 'bottom' then
                    local fatW = maxWidthThisLine - w
                    correctedX = correctedX + math.floor((fatW / 2) + 0.5) -- pseudo round
                else
                    local fatH = maxHeightThisLine - h
                    correctedY = correctedY + math.floor((fatH / 2) + 0.5) -- pseudo round
                end
            end

            if func ~= nil and not onlyOneLine then func(child, correctedX, correctedY, w, h) end

            maxWidthThisLine, maxHeightThisLine = math.max(maxWidthThisLine, w), math.max(maxHeightThisLine, h)
            totalW, totalH = math.max(maxWidthThisLine, totalW), math.max(maxHeightThisLine, totalH)

            if self.childrenDirection == 'right' then
                posX = posX + w + (child.marginLeft or 0) + (child.marginRight or 0)

                availableW = availableW - (child.marginLeft or 0) - (child.marginRight or 0) - w
                print("then ", availableW)
                if availableW <= 0 then
                    posX = self.paddingLeft or 0
                    posY = posY + maxHeightThisLine + (child.marginTop or 0) + (child.marginBottom or 0)
                    availableW = blockWidth
                    availableH = availableH - h - (child.marginTop or 0) - (child.marginBottom or 0)
                    maxHeightThisLine = 0
                    if not onlyOneLine then maxWidthThisLine, maxHeightThisLine = computeTiling(true, i+1)
                    else return maxWidthThisLine, maxHeightThisLine end
                end
            else -- bottom
                posY = posY + w + (child.marginLeft or 0) + (child.marginRight or 0)

                availableH = availableH - (child.marginTop or 0) - (child.marginBottom or 0) - h
                if availableH <= 0 then
                    availableH = blockHeight
                    posY = self.paddingTop or 0
                    posX = posX + maxWidthThisLine + (child.marginLeft or 0) + (child.marginRight or 0)
                    availableW = availableW - w - (child.marginLeft or 0) - (child.marginRight or 0)
                    maxWidthThisLine = 0
                    if not onlyOneLine then maxWidthThisLine, maxHeightThisLine = computeTiling(true, i+1)
                    else return maxWidthThisLine, maxHeightThisLine end
                end
            end
        end

        if onlyOneLine then return maxWidthThisLine, maxHeightThisLine end

        local usedWidth = totalW + (self.paddingLeft or 0) + (self.paddingRight or 0)
        local usedHeight = totalH + (self.paddingTop or 0) + (self.paddingBottom or 0)

        if self.minWidth ~= nil then usedWidth = math.max(usedWidth, self.minWidth) end
        if self.maxWidth ~= nil then usedWidth = math.min(usedWidth, self.maxWidth) end
        if self.minHeight ~= nil then usedHeight = math.max(usedHeight, self.minHeight) end
        if self.maxHeight ~= nil then usedHeight = math.min(usedHeight, self.maxHeight) end

        if self.width == 'fill' then usedWidth = math.min(requestedW, usedWidth) end
        if self.height == 'fill' then usedHeight = math.min(requestedH, usedHeight) end

        print('end', requestedW, availableW, requestedH, availableH)

        return usedWidth, usedHeight
    end

    return computeTiling()
end

function Block:getSize(requestedW, requestedH)
    return blockTiling(self, requestedW, requestedH)
end

function Block:draw(term, x, y, requestedW, requestedH)
    if self.transparent then return end

    local width, height = self:getSize(requestedW, requestedH)
    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)

        for i = 1, height do
            term.setCursorPos(x, y + i)
            for _ = 1, width do
                term.write(" ")
            end
        end
    end

    blockTiling(self, requestedW, requestedH, function(child, posX, posY, availableW, availableH)
        if self.textColor ~= nil then
            term.setTextColor(self.textColor)
        end
        if self.backgroundColor ~= nil then
            term.setBackgroundColor(self.backgroundColor)
        end
        print("drraw", x + posX, y + posY, availableW, availableH)
        child:draw(term, x + posX, y + posY, availableW, availableH)
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
    print(self, obj)
    self.text = obj.text
    self.width, self.height = stringDisplaySize(self.text)
    return self
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

interface = Block:new {
    -- Block:new {
    --     -- width = 'fill',
    --     height = 1,
    --     Text:new("Search:"),
    -- },
    -- Block:new {
    --     paddingTop = 1,
    --     backgroundColor = colors.gray,
    --     Text:new("-> sdds")
    -- },
    -- Block:new {
    --     paddingTop = 1,
    --     backgroundColor = colors.gray,
    --     Text:new("-> s")
    -- },
    Text:new { text = "-> dddddddddd2d" },
    Text:new { text = "hi" }
}
print(interface[1]:getSize())
print(interface[2]:getSize())


monitor = peripheral.wrap('right')
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()
monitor.setTextScale(0.7)
print(interface:getSize(monitor.getSize()))
-- interface:draw(monitor, 1, 1, monitor.getSize())
