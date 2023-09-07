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
    centerElements = false,
}

local function blockTiling(self, requestedW, requestedH, func)
    local posX, posY = (self.paddingLeft or 0), (self.paddingTop or 0)

    local blockWidth = requestedW - (self.paddingLeft or 0) - (self.paddingRight or 0)
    local blockHeight = requestedH - (self.paddingTop or 0) - (self.paddingBottom or 0)
    local availableW = blockWidth
    local availableH = blockHeight

    local maxWidthThisLine, maxHeightThisLine = 0, 0
    -- if not onlyOneLine then maxWidthThisLine, maxHeightThisLine = computeTiling(true, 1) end

    local totalW, totalH = 0, 0

    for i = start or 1, #self do
        local child = self[i]
        local w, h = child:getSize(
        	availableW - (child.marginRight or 0) - (child.marginLeft or 0),
        	availableH - (child.marginTop or 0) - (child.marginBottom or 0)
        )

        local realW = w + (child.marginRight or 0) + (child.marginLeft or 0)
        local realH = h + (child.marginTop or 0) + (child.marginBottom or 0)
        maxWidthThisLine, maxHeightThisLine = math.max(maxWidthThisLine, realW), math.max(maxHeightThisLine, realH)

        posX, posY = posX + (child.marginLeft or 0), posY + (child.marginTop or 0)
        if self.childrenDirection == 'right' then
            availableW = availableW - realW
            totalW = totalW + w
            print(totalW, i, availableW, realW, maxWidthThisLine, maxHeightThisLine)
            if availableW <= 0 and i ~= 1 then
            	-- wrap
                totalW = blockWidth
            	totalH = totalH + maxHeightThisLine
                posX = self.paddingLeft or 0
                posY = posY + maxHeightThisLine

			    w, h = child:getSize(
			    	availableW - (child.marginRight or 0) - (child.marginLeft or 0),
			    	availableH - (child.marginTop or 0) - (child.marginBottom or 0)
			    )
			    realW = w + (child.marginRight or 0) + (child.marginLeft or 0)
			    realH = h + (child.marginTop or 0) + (child.marginBottom or 0)

                availableW = blockWidth
                availableH = availableH - realH
                maxHeightThisLine = 0

            end
        end

        -- local correctedX, correctedY = posX, posY
        -- if self.centerItems then
        --     if self.childrenDirection == 'bottom' then
        --         local fatW = maxWidthThisLine - w
        --         correctedX = correctedX + math.floor((fatW / 2) + 0.5) -- pseudo round
        --     else
        --         local fatH = maxHeightThisLine - h
        --         correctedY = correctedY + math.floor((fatH / 2) + 0.5) -- pseudo round
        --     end
        -- end

        if func ~= nil then func(child, posX, posY, w, h) end

        if self.childrenDirection == 'right' then
            posX = posX + realW
        end
    end
    if self.childrenDirection == 'right' then
    	totalH = totalH + maxHeightThisLine
    end

    local usedWidth = totalW + (self.paddingLeft or 0) + (self.paddingRight or 0)
    local usedHeight = totalH + (self.paddingTop or 0) + (self.paddingBottom or 0)

    if self.minWidth ~= nil then usedWidth = math.max(usedWidth, self.minWidth) end
    if self.maxWidth ~= nil then usedWidth = math.min(usedWidth, self.maxWidth) end
    if self.minHeight ~= nil then usedHeight = math.max(usedHeight, self.minHeight) end
    if self.maxHeight ~= nil then usedHeight = math.min(usedHeight, self.maxHeight) end

    if self.width == 'fill' then usedWidth = math.min(requestedW, usedWidth) end
    if self.height == 'fill' then usedHeight = math.min(requestedH, usedHeight) end

    return usedWidth, usedHeight
end

function Block:getSize(requestedW, requestedH)
    return blockTiling(self, requestedW, requestedH)
end

function Block:draw(term, x, y, requestedW, requestedH)
    if self.transparent then return end

    local width, height = self:getSize(requestedW, requestedH)
    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)

        print("Got", requestedW, requestedH, width, height)
        for i = 0, height-1 do
            term.setCursorPos(x, y + i)
            for _ = 0, width-1 do
                term.write(" ")
            end
        end
    end

    blockTiling(self, requestedW, requestedH, function(child, posX, posY, availableW, availableH)
    	print("call", posX, posY, availableW, availableH)
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

interface = Block:new {
	width = 'full',
	height = 'full',
    Block:new {
        paddingTop = 1,
        paddingRight = 1,
        paddingBottom = 1,
        paddingLeft = 1,
        backgroundColor = colors.gray,
    	Text:new { text = "Hello!" }
    },
}

local monitor = peripheral.wrap('right')
monitor.setCursorPos(1, 1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()
monitor.setTextScale(0.7)
monitor.defaultBackgroundColor = colors.black
monitor.defaultTextColor = colors.white
local w, h = 10, 10-- monitor.getSize()
print(interface[1]:getSize(w, h))
interface:draw(monitor, 1, 1, w, h)
