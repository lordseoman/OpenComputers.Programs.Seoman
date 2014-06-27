--[[
 * 
 * This provides a Touchscreen Menu system. 
 *
--]]

local component = require("component")
local term = require("term")

local colours = {
    white=0xFFFFFF,
    black=0x000000,
    blue=0x0000FF,
    red=0xFF0000,
    green=0x00FF00,
    yellow=0xFFFF00,
    magenta=0x00FFFF,
    purple=0xFF00FF,
    grey=0xC0C0C0,
}

local Menu = {
    windowSize=nil,
    title=nil,
    text_colour=colours.white,
    background_colour=colours.black,
    buttons={
        -- buttons on the bottom of the screen
        help={
            text="Help",
            y=-2,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
        },
        status={
            text="Status",
            y=-2,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
        },
        info={
            text="Info",
            y=-2,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
        },
        exit={
            text="EXIT",
            y=-2,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.red,
        },
    },
    monitor=nil,
    options={},
    page_support={
        num_per_page=27,
        min=1,
    },
    debug=false,
}

function Menu:new(o)
    if type(o) == nil then
        o = {}
    elseif type(o) ~= "table" then
        print("expected a table as input with any args; got " .. type(o))
        return
    end
    if o.title == nil then
        print("requires a 'title' for this menu")
        return
    end
    setmetatable(o, self)
    self.__index = self
    if not component.isAvailable("gpu") then
        error("You need a Graphics card.")
    end
    o.monitor = component.gpu
    o.monitor.setForeground(self.text_colour)
    o.monitor.setBackground(self.background_colour)
    local x, y = o.monitor.getResolution()
    o.monitor.fill(1, 1, x, y, " ")
    o.windowSize = {x, y}
    o.maxOptions = y - 8
    o.maxLength = x - 6
    return o
end

-- Find if a button has been clicked
function Menu:findClickXY(buttons, x, y)
    for _, button in pairs(buttons) do
        if self.debug then
            print(_)
            print(button.x..":"..button.y)
            print(button.xpad..":"..button.ypad)
            print(button.width)
            print(x..":"..y)
        end
        if (y >= (button.y - button.ypad)) and (y <= (button.y + button.ypad)) then
            if x >= button.x and x <= (button.x + button.width) then
                return button
            end
        end
    end
end

function Menu:drawBox(width, height, fgcolour, bgcolour)
    -- Save the foreground and background colour
    local oldfgc = self.monitor.getForeground()
    local oldbgc = self.monitor.getBackground()
    -- The offset is the upper left corner of the window
    local xOffset = math.floor((self.windowSize[1] - width) / 2) + 1
    local yOffset = math.floor((self.windowSize[2] - height) / 2) + 1
    -- If there is an offset then pad by 1
    if xOffset > 1 then
        self.monitor.fill(xOffset-1, yOffset-1, width+2, height+2, " ")
    else
        self.monitor.fill(xOffset, yOffset, width, height, " ")
    end
    self.monitor.setForeground(fgcolour)
    self.monitor.setBackground(bgcolour)
    -- Top border
    self.monitor.set(xOffset, yOffset, '+')
    self.monitor.set(xOffset + width, yOffset, '+')
    self.monitor.fill(xOffset + 1, yOffset, width-2, 1, '-')
    -- Copy this to the bottom
    self.monitor.copy(xOffset, yOffset, width, 1, 0, height)
    -- Do the sides by filling
    self.monitor.fill(xOffset, yOffset+1, 1, height-2, "|")
    self.monitor.fill(xOffset+width, yOffset+1, 1, height-2, "|")
    -- Restore the old fg and bg colours
    self.monitor.setForeground(oldfgc)
    self.monitor.setBackground(oldbgc)
end

-- Get the buttons that exist in this Y position
function Menu:getButtons(ypos)
    local xpos = nil
    if ypos == nil then
        xpos, ypos = term.getCursor()
    end
    local retArray = {}
    for _, button in pairs(self.buttons) do
        if button.y == ypos then
            table.insert(retArray, button)
--            table.insert(retArray, table.copy(button))
        end
    end
    return retArray
end
--
-- Render a string/button on the screen based on options in `item`
--
function Menu:renderItem(item)
    if item.xpad == nil then item.xpad = 0 end
    if item.ypad == nil then item.ypad = 0 end

    local text = item.text
    if item.xpad > 0 then
        text = string.rep(" ", item.xpad) .. item.text .. string.rep(" ", item.xpad)
    end
    local y = item.y - item.ypad

    if item.background_colour ~= nil then
        self.monitor.setBackground(item.background_colour)
    end
    if item.text_colour ~= nil then
        self.monitor.setForeground(item.text_colour)
    end
    self.monitor.fill(item.x, y, item.width, (item.ypad * 2) + 1, " ")
    self.monitor.set(item.x, y, text)
    -- Restore the text and background colours
    self.monitor.setForeground(self.text_colour)
    self.monitor.setBackground(self.background_colour)
end
--
-- A Button contains text and the state of the button determines the colour
-- padding and position
--
function Menu:setupItem(item, xpos, width)
    if item.setup == true then
        return
    end
    --
    -- A missing width means center it on the line, minus 6 for the borders
    if width == nil then 
        width = self.windowSize[1] - 6 
    end
    --
    -- xpad true mean the button width is the whole area, grow to cover
    if item.xpad == true then
        item.xpad = math.floor((width - string.len(but.text)) / 2)
    -- default the padding to 2
    elseif item.xpad == nil then
        item.xpad = 2
    end
    if item.ypad == nil then
        item.ypad = 0
    end
    -- if the y is -ve, then from the bottom
    if item.y == nil then
        item.y = ypos
    elseif item.y < 0 then
        item.y = self.windowSize[2] + 1 + item.y
    end
    --
    -- Figure out the width of the button
    item.width = string.len(item.text) + (2 * item.xpad)
    if item.width > width then
        error("Item "..item.text.." is too wide; "..item.width.." for area.")
    end
    item.x = xpos + math.floor((width - item.width)/2)
    --
    -- record as setup
    item.setup = true
end

function Menu:showHelp()
    self:showDialog({
        title="Help Panel", 
        lines={
            "This will show help on using this interface.",
            "",
            "Created by Simon Hookway, all hail..",
        },
        timeout=0, 
        buttons={
            close={
                x=-5,
                width=5,
                ypad=0,
                xpad=0,
                text="CLOSE", 
                text_colour=colours.yellow,
                background_colour=colours.red,
            },
        },
    })
end


function Menu:showStatus()
    self:showDialog({
        title="Status Panel", 
        lines={
            "This will show status of key items that are",
            "low as well as any issues that may have been",
            "shown.",
        },
        timeout=0, 
        buttons={
            close={
                x=-5,
                width=5,
                ypad=0,
                xpad=0,
                text="CLOSE", 
                text_colour=colours.yellow,
                background_colour=colours.red,
            },
        },
    })
end

function Menu:showInfo()
    self:showDialog({
        title="Information Panel", 
        lines={
            "There will be information on what requests",
            "are pending as well as filled recent requests",
            "in here soon.",
        },
        timeout=0, 
        buttons={
            close={
                x=-5,
                width=5,
                ypad=0,
                xpad=0,
                text="CLOSE", 
                text_colour=colours.yellow,
                background_colour=colours.red,
            },
        },
    })
end

function Menu:renderMainMenu()
    local x, y = self.windowSize
    -- Clear the screen
    self.monitor.fill(1, 1, x, y, " ")
    --
    -- Write the title in the middle top line
    self:renderItem({
        x=math.floor((x-string.len(self.title))/2),
        y=1,
        width=string.len(self.title),
        ypad=0,
        xpad=0,
        text=self.title, 
        text_colour=colours.yellow,
        background_colour=self.background_colour,
    })
    --
    -- The menu border comes next
    self.monitor.setForeground(colours.red)
    self.monitor.setBackground(self.background_colour)
    self.monitor.set(1, 2, '+')
    self.monitor.set(x, 2, '+')
    self.monitor.fill(2, 2, x-2, 1, '-')
    -- Copy this to the bottom
    self.monitor.copy(1, 2, x, 1, 0, y-5)
    -- Do the sides by filling
    self.monitor.fill(1, 3, 1, y-6, "|")
    self.monitor.fill(x, 3, 1, y-6, "|")
    --
    -- Write the buttons on the bottom of the screen
    local buttons = self:getButtons(-2)
    local width = math.floor((x - 4 - (2 * #buttons)) / #buttons)
    local xpos = 4
    for _, but in pairs(buttons) do
        self:setupItem(but, xpos, width)
        self:renderItem(but)
        xpos = xpos + width + 2
    end
end
--
-- A dialog is a window in the center of the monitor that shows information or
-- additional options, they have their own set of buttons.
--
function Menu:showDialog(dialog)
    --
    -- We expect a table now instead of arguments
    if type(dialog) ~= "table" then
        error("Expected dialog table object.")
    end
    self:setupDialog(dialog)
    --
    -- The offset is the upper left corner of the dialog
    local xOffset = math.floor((self.windowSize[1] - dialog.width) / 2) + 1
    local yOffset = math.floor((self.windowSize[2] - dialog.height) / 2) + 1
    --
    -- Now enter the write the lines to the screen and wait for input
    local result = dialog.result
    repeat
        -- Clear the box area first
        self.monitor.fill(xOffset, yOffset, dialog.width, dialog.height, " ")
        -- Draw the top of box for the dialog
        self.monitor.set(xOffset+1, yOffset+1, "+")
        self.monitor.fill(xOffset+2, yOffset+1, dialog.width-4, 1, "-")
        self.monitor.set(xOffset+dialog.width-1, yOffset+1, "+")
        -- Copy the top to the bottom
        self.monitor.copy(xOffset+1, yOffset+1, dialog.width-2, 1, 0, dialog.height-2)
        -- And fill the sides
        self.monitor.fill(xOffset+1, yOffset+2, 1, dialog.height-4, "|")
        self.monitor.fill(xOffset+1, yOffset+dialog.width-1, 1, dialog.height-4, "|")
        -- Render the title inside the box
        self:renderItem({
            x=xOffset + math.floor((dialog.inner_width-string.len(dialog.title))/2) + 3,
            y=yOffset + 2,
            width=string.len(dialog.title),
            ypad=0,
            xpad=0,
            text=dialog.title, 
            text_colour=colours.yellow,
            background_colour=self.background_colour,
        })
        --
        -- Now draw the buttons on the bottom inside the box
        for _, button in pairs(dialog.buttons) do
            if button.setup ~= true then
                if button.x < 0 then
                    button.x = xOffset + dialog.inner_width + 3 + button.x
                else
                    button.x = xOffset + 3 + button.x
                end
                button.y = yOffset + dialog.height - 3
                button.setup = true
            end
            self:renderItem(button)
        end
        --
        -- And finally draw the text in the box.
        local i = #dialog.lines
        local minNo = math.max(1, #dialog.lines - dialog.inner_height + 1)
        while i >= minNo do
            local x = xOffset + 3
            local y = yOffset + 4 + i - minNo
            self.monitor.set(x, y, string.sub(dialog.lines[i], 1, dialog.inner_width))
            i = i - 1
        end
        if result == nil then
            result = self:selectOption(dialog)
        end
    until result == true
end

function Menu:selectOption(dialog)
    return true
end

function Menu:setupDialog(dialog)
    if dialog.setup == true then
        return
    end
    --
    -- If the width of the dialog is not fixed then adjust it to fit the
    -- lines being shown
    if dialog.width == nil then
        dialog.inner_width = 0
        for i, line in pairs(dialog.lines) do
            if string.len(line) > (self.maxLength - 4) then
                error("Line "..i.." is too long for the dialog.")
            end
            dialog.inner_width = math.max(string.len(line), dialog.inner_width)
        end
    else
        dialog.inner_width = dialog.width
    end
    --
    -- If the height is not fixed then set the dialog height based on the
    -- number of lines provided
    if dialog.height == nil then
        dialog.inner_height = #dialog.lines
    else
        dialog.inner_height = dialog.height
    end
    --
    local count = 0
    for _, but in pairs(dialog.buttons) do count = count + 1 end
    if count > 0 then
        dialog.height = dialog.inner_height + 8
    else
        dialog.height = dialog.inner_height + 7
    end
    dialog.width = dialog.inner_width + 6
    dialog.setup = true
end	

Menu.hexcolours = colours

return Menu

