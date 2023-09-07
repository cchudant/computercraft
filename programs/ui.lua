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

        local maxWidthThisLine = 0
        local maxHeightThisLine = 0
        if not onlyOneLine then maxWidthThisLine, maxHeightThisLine = computeTiling(true, 1) end

        print("hi?", start or 1, #self)

        for i = start or 1, #self do
            local child = self[i]
            local w, h = child:getSize(availableW, availableH)

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

            print("RUN")
            if func ~= nil then func(child, correctedX, correctedY, w, h) end

            maxWidthThisLine, maxHeightThisLine = math.max(maxWidthThisLine, w), math.max(maxHeightThisLine, h)

            if self.childrenDirection == 'bottom' then
                posX = posX + w + (child.marginLeft or 0) + (child.marginRight or 0)

                availableW = availableW - (child.marginLeft or 0) - (child.marginRight or 0) - w
                if availableW <= 0 then
                    availableW = blockWidth
                    posX = self.paddingLeft or 0
                    posY = posY + maxHeightThisLine + (child.marginTop or 0) + (child.marginBottom or 0)
                    availableH = availableH - h - (child.marginTop or 0) - (child.marginBottom or 0)
                    maxHeightThisLine = 0
                    if not onlyOneLine then maxWidthThisLine, maxHeightThisLine = computeTiling(true, i+1)
                    else return maxWidthThisLine, maxHeightThisLine end
                end
            else -- right
                posY = posY + w + (child.marginLeft or 0) + (child.marginRight or 0)

                availableH = availableH - (child.marginTop or 0) - (child.marginBottom or 0) - w
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

        posX, posY = posX + (self.paddingRight or 0), posY + (self.paddingBottom or 0)

        return posX, posY
    end

    return computeTiling(func)
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
        print("child draw!")
        child:draw(term, x + posX, y + posY, availableW, availableH)
    end)
end

local function stringDisplaySize(s)
    if string.len(s) == 0 then return 0, 0 end
    local maxHeight, maxWidth = 1, 0
    local currentWidth = 0
    for i = 1, string.len(s) do
        local c = s:sub(i, i)

        currentWidth = currentWidth + 1
        if c == '\n' then
            maxWidth = math.max(maxWidth, currentWidth)
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
function Text:new(text)
    Block.new(self, {})
    self.text = text
    self.width, self.height = stringDisplaySize(self.text)
    return self
end
function Text:draw(term, x, y, parentW, parentH)
    if self.transparent then return end
    term.setCursorPos(x, y)
    if self.backgroundColor ~= nil then
        term.setBackgroundColor(self.backgroundColor)
    end
    if self.textColor ~= nil then
        term.setTextColor(self.textColor)
    end
    term.write(self.text)
end
function Text:getSize()
    return self.width, self.height
end

interface = Block:new {
    -- Block:new {
    --     width = 'fill',
    --     height = 1,
    --     Text:new ("Search:"),
    -- },
    -- Block:new {
    --     paddingTop = 1,
    --     backgroundColor = colors.gray,
    --     Text:new("-> Hello")
    -- },
    -- Block:new {
    --     paddingTop = 1,
    --     backgroundColor = colors.gray,
    --     Text:new("-> Hello")
    -- },
    Text:new("-> Hello")
}

interface:draw(term, 1, 1, term.getSize())
