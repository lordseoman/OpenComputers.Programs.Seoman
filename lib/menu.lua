--[[
 * 
 * This provides a Touchscreen Menu system. 
 *
--]]

require("functions")

local component = require("component")
local term = require("term")
local event = require("event")
local computer = require("computer")

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
        {
            text="Help",
            y=0,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
            callback=function(menu, button) return menu:showHelp() end
        },{
            text="Status",
            y=0,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
            callback=function(menu, button) return menu:showStatus() end
        },{
            text="Sleep",
            y=0,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.green,
            callback=function(menu, button) return menu:sleep() end
        },{
            text="Info",
            y=0,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
            callback=function(menu, button) return menu:showInfo() end
        },{
            text="EXIT",
            y=0,    --bottom
            xpad=2,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.red,
            callback=function(menu, button) return menu:shutdown() end
        },
    },
    monitor=nil,
    options={},
    page_support={
        spacing=1,
        num_per_page=27,
        min=1,
    },
    debug=false,
    isShutdown=false,
    isAsleep=false,
    isSetup=false,
    sleepTimer=20,
}

function Menu:new(o)
    if type(o) == nil then
        o = {}
    elseif type(o) ~= "table" then
        error("expected a table as input with any args; got " .. type(o))
    end
    setmetatable(o, self)
    self.__index = self
    if not component.isAvailable("gpu") then
        error("You need a Graphics card.")
    end
    o.monitor = component.gpu
    o.monitor.setForeground(self.text_colour)
    o.monitor.setBackground(self.background_colour)
    if o.windowSize == nil then
        local x, y = o.monitor.getResolution()
        o.windowSize = {x, y}
    else
        o.monitor.setResolution(o.windowSize[1], o.windowSize[2])
    end
    o.monitor.fill(1, 1, o.windowSize[1], o.windowSize[2], " ")
    o.maxOptions = o.windowSize[2] - 8
    o.maxLength = o.windowSize[1] - 6
    return o
end

function Menu:setup()
    if self.isSetup then
        return
    end
    -- Set the list spacing to 2
    self.page_support.spacing = 2
    -- Set the number displayed based on the size of the screen
    self.page_support.num_per_page = math.floor((self.windowSize[2] - 11) / self.page_support.spacing)
    -- The page down button shifts half the viewing window.
    self.page_support.shift_count = math.floor(self.page_support.num_per_page / 2)    
    -- The title element doesn't change, so fix that one here
    self.title = {
        y=1,
        ypad=0,
        xpad=0,
        text=self.title, 
        text_colour=colours.yellow,
        background_colour=self.background_colour,
    }
    self:setupItem(self.title, 1, 1)
    self._isSetup = true
end

-- Find if a button has been clicked
function Menu:findClickXY(buttons, x, y)
    if self.debug then
        self.monitor.set(10, self.windowSize[2]-4, "Click at "..x..","..y..":")
    end
    for _, button in ipairs(buttons) do
        if self.debug then
            message = string.format(
                "Button %d,%d => %d, %d", button.x, button.y, button.dx, button.dy
            )
            self.monitor.set(26, self.windowSize[2]-4, message)
            os.sleep(2)
        end
        if (y >= button.y) and (y < button.dy) and (x >= button.x) and (x < button.dx) then
            return button
        end
    end
end

function Menu:drawBox(width, height, fgcolour, bgcolour)
    -- Save the foreground and background colour
    local oldfgc = self.monitor.getForeground()
    local oldbgc = self.monitor.getBackground()
    -- The offset is the upper left corner of the window
    local xOffset = math.floor((self.windowSize[1] - width) / 2)
    local yOffset = math.floor((self.windowSize[2] - height) / 2)
    -- If there is an offset then pad by 1 and clear the area
    self.monitor.setForeground(fgcolour)
    self.monitor.setBackground(bgcolour)
    if xOffset > 1 then
        self.monitor.fill(xOffset-1, yOffset-1, width+2, height+2, " ")
    else
        self.monitor.fill(xOffset, yOffset, width, height, " ")
    end
    -- Top border
    self.monitor.set(xOffset, yOffset, '+')
    self.monitor.set(xOffset+width-1, yOffset, '+')
    self.monitor.fill(xOffset + 1, yOffset, width-2, 1, '-')
    -- Copy this to the bottom
    self.monitor.copy(xOffset, yOffset, width, 1, 0, height-1)
    -- Do the sides by filling
    self.monitor.fill(xOffset, yOffset+1, 1, height-2, "|")
    self.monitor.fill(xOffset+width-1, yOffset+1, 1, height-2, "|")
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
    for _, button in ipairs(self.buttons) do
        if (ypos >= button.y) and (button.dy == nil or ypos < button.dy) then
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
    if item.background_colour ~= nil then
        self.monitor.setBackground(item.background_colour)
    end
    if item.text_colour ~= nil then
        self.monitor.setForeground(item.text_colour)
    end
    self.monitor.fill(item.x, item.y, item.dx - item.x, item.dy - item.y, " ")
    self.monitor.set(item.x + item.xpad, item.y + item.ypad, item.text)
    -- Restore the text and background colours
    self.monitor.setForeground(self.text_colour)
    self.monitor.setBackground(self.background_colour)
end
--
-- A Button contains text and the state of the button determines the colour
-- padding and position
--
function Menu:setupItem(item, xpos, ypos, width)
    if item.setup == true then
        return
    end
    if width == nil then
        width = self.windowSize[1]
    end
    --
    -- Figure out the width of the button
    if item.width == nil then
        item.width = string.len(item.text)
    elseif item.width > string.len(item.text) then
        error("Item "..item.text.." is too wide; "..item.width.." for area.")
    end
    --
    -- A missing x value means center it within 'width'
    if item.x == nil then
        item.x = xpos + math.floor((width - item.width)/2)
    elseif item.x < 0 then
        item.x = xpos + width + item.x
    else
        item.x = xpos + item.x
    end
    --
    -- xpad true mean the button width is the whole area, grow to cover
    if item.xpad == true then
        item.xpad = math.floor((width - item.width) / 2)
    -- default the padding to 2
    elseif item.xpad == nil then
        item.xpad = 2
    end
    item.x = item.x - item.xpad
    item.dx = item.x + (item.xpad * 2) + item.width
    if item.ypad == nil then
        item.ypad = 0
    end
    -- if the y is -ve, then from the bottom
    if item.y == nil then
        item.y = ypos
    else
        item.y = ypos + item.y
    end
    item.y = item.y - (2 * item.ypad)
    item.dy = item.y + (item.ypad * 2) + 1
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
            {
                ypad=0,
                xpad=0,
                text="CLOSE", 
                text_colour=colours.yellow,
                background_colour=colours.red,
                result=true,
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
            {
                ypad=0,
                xpad=0,
                text="CLOSE", 
                text_colour=colours.yellow,
                background_colour=colours.red,
                result=true,
            },
        },
    })
end

-- Put the screen to sleep
function Menu:sleep()
    self.isAsleep = true
    self.monitor.fill(2, 3, self.windowSize[1]-2, self.windowSize[2]-6, " ")
    self:showDialog({
        title="Gone To Sleep", 
        lines={
            "This display has gone to sleep, to wake me up",
            "just click on the button below.",
            "Even asleep, I will be processing background",
            "tasks.",
        },
        timeout=0, 
        buttons={
            {
                ypad=1,
                xpad=1,
                text="WAKE UP", 
                text_colour=colours.yellow,
                background_colour=colours.red,
                result=true,
            },
        },
    })
    self.isAsleep = false
    computer.pushSignal("wakeup")
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
            {
                ypad=0,
                xpad=0,
                text="CLOSE", 
                text_colour=colours.yellow,
                background_colour=colours.red,
                result=true,
            },
        },
    })
end

function Menu:shutdown(msg)
    if msg == nil then msg = "Quiting" end
    -- Show the closing dialog
    self:showDialog({
        title="Shutdown",
        lines={msg.." . Goodbye",},
        timeout=4,
        buttons={},
    })
    -- reset the monitor colours
    self.monitor.setBackground(colours.black)
    self.monitor.setForeground(colours.white)
    self.monitor.fill(1, 1, self.windowSize[1], self.windowSize[2], " ")
    self.monitor.set(1,5, "Thankyou, please come again.")
    --
    self.isShutdown = true
    return true
end

function Menu:selectThingFromList(selection)
    self:showDialog({
        title="Main Item Selected",
        lines={
           "You have selected the following:", 
           "", 
           "  - "..selection.text, 
           "",
           "If you are seeing this it is because the selectThingFromList() method",
           "on the menu has not been overriden. This dialog will timeout after",
           "4 seconds.",
        },
        timeout=4,
        buttons={},
    })
end

function Menu:renderList(listOfThings, xpos, ypos)
    
    -- The number of items rendered on in the main area.
    local count = 0
    -- The list of buttons or items that can be selected
    local items = {}
    
    -- Set the page_controls
    self.page_support.total = #listOfThings
    self.page_support.max = 0
    
    for idx, thing in ipairs(listOfThings) do
        -- Use a repeat loop because Lua doesn't have 'continue'
        repeat
            -- Skip the ones off the top of the list, so if we have scrolled 
            -- down then min is the top of the viewing window for the list.
            if idx < self.page_support.min then
                break
            end
            -- Set the background colour, if the current thing is the active
            -- thing (has been selected) then highlight it
            if self.page_support.active == thing then
                background_colour = colours.green
            else
                background_colour = self.background_colour
            end
        
            -- Create an item just for this 'thing', we need to do this each
            -- time because the position changes
            local item = {
                x=0,
                y=((count - self.page_support.min) * self.page_support.spacing),
                ypad=0,
                xpad=0,
                reference=idx,
                text=thing,
                text_colour=colours.lightBlue,
                background_colour=background_colour,
                callback=self.selectThingFromList,
            }
            self:setupItem(item, xpos, ypos)
            table.insert(items, item)
            self:renderItem(item)
        until true
        self.page_support.max = count
        -- page_support.min is the first item so we need +1 to give us the number
        -- rendered already.
        if (count - self.page_support.min + 1) >= self.page_support.num_per_page then
            break
        end
    end
    for _, item in ipairs(self:getPageControls(xpos, ypos)) do
        self:renderItem(item)
        table.insert(items, item)
    end
end

function Menu:renderMainMenu()
    local x, y = self.windowSize[1], self.windowSize[2]
    -- Clear the screen
    self.monitor.fill(1, 1, x, y, " ")
    --
    -- Write the title in the middle top line
    self:renderItem(self.title)
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
    local buttons = self:getButtons(y)
    if #buttons == 0 then
        buttons = self:getButtons(0)
    end
    local width = math.floor((x - 4)/#buttons)
    local xpos = 3 + (x - (#buttons * width) - 4)
    for _, but in ipairs(buttons) do
        self:setupItem(but, xpos, y, width)
        self:renderItem(but)
        xpos = xpos + width
    end
    return buttons
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
    -- The offset is the upper left corner of the dialog frame
    local xOffset = math.floor((self.windowSize[1] - dialog.width) / 2)
    local yOffset = math.floor((self.windowSize[2] - dialog.height) / 2)
    --
    -- Now enter the write the lines to the screen and wait for input
    local result = dialog.result
    repeat
        self:drawBox(dialog.width, dialog.height, dialog.text_colour, dialog.background_colour)
        -- Render the title inside the box
        title = {
            ypad=0,
            xpad=0,
            text=dialog.title, 
            text_colour=colours.yellow,
            background_colour=self.background_colour,
        }
        self:setupItem(title, xOffset+1, yOffset+1, dialog.width-2)
        self:renderItem(title)
        --
        -- Now draw the buttons on the bottom inside the box
        for _, button in ipairs(dialog.buttons) do
            self:setupItem(button, xOffset+1, yOffset+dialog.height-2, dialog.width-2)
            self:renderItem(button)
        end
        --
        -- And finally draw the text in the box.
        local i = #dialog.lines
        local minNo = math.max(1, #dialog.lines - dialog.inner_height + 1)
        while i >= minNo do
            local x = xOffset + 3
            local y = yOffset + 3 + i - minNo
            self.monitor.set(x, y, string.sub(dialog.lines[i], 1, dialog.inner_width))
            i = i - 1
        end
        if result == nil then
            result = self:selectOption(dialog)
        end
    until result == true
end

function Menu:selectOption(dialog, sleepTimer)
    -- If the dialog doesn't specify events, then use "touch"
    local oldWFE = nil
    local waitForEvents = { "touch", }
    if dialog.event then waitForEvents = dialog.events end
    -- If the sleep timer should be active (usually only from renderMainMenu)
    local timerId = nil
    if sleepTimer and not dialog.timeout then
        timerId = event.timer(sleepTimer, function () self:sleep() end)
    end
    while true do
        local args
        if dialog.timeout and dialog.timeout > 0 then
            args = { event.pull(dialog.timeout, nil) }
        else
            args = { event.pull(nil) }
        end
        -- Returns nil if the timeout is triggered.
        if args[1] == nil then
            if sleepTimer == nil then
                return true
            else
                oldWFE = waitForEvents
                waitForEvents = { "wakeup", }
            end
        elseif args[1] == "wakeup" then
            waitForEvent = oldWFE
        -- See if the event is one we are waiting for
        elseif table.contains(waitForEvents, args[1]) then
            -- Handle specific events
            if args[1] == 'touch' then
                button = self:findClickXY(dialog.buttons, args[3], args[4])
                if button then
                    if timerId then
                        event.cancel(timerId)
                    end
                    if button.result then
                        return button.result
                    elseif button.callback then
                        return button.callback(self, button)
                    else
                        return button
                    end
                end
            end
        end
    end
    error("Should never get to here")
end

function Menu:setupDialog(dialog)
    if dialog.setup == true then
        return
    end
    if dialog.text_colour == nil then
        dialog.text_colour = self.text_colour
    end
    if dialog.background_colour == nil then
        dialog.background_colour = self.background_colour
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
    local bHeight = 0
    for _, but in pairs(dialog.buttons) do bHeight = math.max(bHeight, (but.ypad * 2) + 1) end
    -- The height is text height (inner) + 5 for title and border and gap + buttons
    dialog.height = dialog.inner_height + 5 + bHeight
    dialog.width = dialog.inner_width + 6
    dialog.setup = true
end	

-- Page control
function Menu:pagingButton(button)
    if button.text == "Up" then
        self.page_support.min = self.page_support.min - 1
    elseif button.text == "PgUp" then
        self.page_support.min = math.max(self.page_support.min - self.page_support.shift_count, 1)
    elseif button.text == "Dn" then
        self.page_support.min = self.page_support.min + 1
    elseif button.text == "PgDn" then
        self.page_support.min = math.min(self.page_support.min + self.page_support.shift_count, self.page_support.total)
    else
        error("Unknown paging button.")
    end
end

function Menu:getPageControls(xpos, ypos)
    local buttons = {}
    if self.page_support.min > 1 then
        local Up1 = {
            x=self.windowSize[1] - 5,
            y=ypos + 1,
            width=4,
            ypad=1,
            xpad=1,
            text="Up",
            text_colour=colours.lightBlue,
            background_colour=colours.yellow,
            callback=self.pagingButton,
        }
        local PgUp = {
            x=self.windowSize[1] - 5,
            y=ypos+5,
            width=4,
            ypad=1,
            xpad=0,
            text="PgUp",
            text_colour=colours.lightBlue,
            background_colour=colours.yellow,
            callback=self.pagingButton,
        }
        table.insert(buttons, Up1)
        table.insert(buttons, PgUp)
    end
    if self.page_support.max < self.page_support.total then
        local dn1 = {
            x=self.windowSize[1] - 5,
            y=ypos + (self.page_support.num_per_page * self.page_support.spacing) - 2,
            width=4,
            ypad=1,
            xpad=1,
            text="Dn",
            text_colour=colours.lightBlue,
            background_colour=colours.yellow,
        }
        local PgDn = {
            x=self.windowSize[1] - 5,
            y=ypos + (self.page_support.num_per_page * self.page_support.spacing) - 6,
            width=4,
            ypad=1,
            xpad=0,
            text="PgDn",
            text_colour=colours.lightBlue,
            background_colour=colours.yellow,
        }
        table.insert(buttons, Dn1)
        table.insert(buttons, PgDn)
    end
    return buttons
end

function Menu:getMainMenuList()
    return {
        "This is a placeholder because nothing is in the list.",
        "Click to get nothing really.",
    }
end

function Menu:run()
    self:setup()
    repeat
        self:renderMainMenu()
        self:renderList(self:getMainMenuList())
        self:selectOption({buttons=self.buttons}, self.sleepTimer)
    until self.isShutdown
end

Menu.hexcolours = colours

return Menu

