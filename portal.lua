--[[
 *
 * This is a touchscreen portal controller.
 *
--]]
 
-- This is frustrating but necessary, clear out the cache
package.loaded.menu = nil
package.loaded.inventory = nil
 
local PortalCrtl = require("menu")
local Inventory = require("inventory")

local colours = PortalCrtl.hexcolours

function PortalCrtl:showInfo() 
    self:showDialog({
        title="Portal Usage Information",
        lines={
            "Place a linking book into the bookshelf in any",
            "position you like and hit the refresh button.",
            "",
            "The position of the book in the bookcase determines",
            "the order shown on the screen, to reorder, just swap",
            "the books around in the bookcase and hit refresh.",
            "",
            "To travel, click the book title shown on the screen,",
            "the portal will close after 12 seconds."
        },
        buttons={
            {
                ypad=0,
                xpad=1,
                text="CLOSE",
                text_colour=colours.yellow,
                background_colour=colours.red,
                callback=function (menu, selection) return true end
            },
        },
    })
end

function PortalCrtl:refresh()
    -- Show the Dialog Box and return straight away, note that the screen
    -- will not get refreshed until we return, so the dialog box will remain
    -- until the refresh is complete
    self:showDialog({
        title="Scanning",
        lines={
            "Scanning the bookshelves..",
            "",
            "     ...please  wait...",
        },
        buttons={},
        result=true,
    })
    self:refreshTitles()
end

function PortalCrtl:loadConfig()
    self.config = {
        title = "Nexus Portal Controller",
        -- Is this a remote portal
        remote_site = false,
        -- The addresses of the components
        bookcase_top_addr = "04df43a7",
        bookcase_bot_addr = "8980e8bf",
        share_chest_addr  = "631dfdd3",
        portal_chest_addr = "8017c972",
        book_recepticle_addr = "68367be9",
        -- Chest is below the Book Recepticle
        portal_chest_direction = "down",
        -- Direction the top bookcase is to the transvestor interface
        bookcase_top_to_tvectorint = "east",
        -- The direction of the bookcase to the chest, both must be the same
        chest_to_bookcase_direction = "east",
    }
end

function PortalCrtl:saveConfig()
    return
end

function PortalCrtl:setup()
    self:loadConfig()
    self.title = {
        ypad=0,
        xpad=0,
        text=self.config.title, 
        text_colour=colours.yellow,
        background_colour=self.background_colour,
    }
    self:setupItem(self.title, 1, 1)
    --
    -- Setup the storage parts, this isn't needed on remote portals
    if not self.config.remote_site then
        -- Create a fake Inventory for the Bookcases
        self.fake_bookcase_top = Inventory:new("fake_bookcaseTop_16")
        self.fake_bookcase_bot = Inventory:new("fake_bookcaseBot_16")
        -- Each bookcase has a chest that we scan and access the books through
        self.chest_top = Inventory:new(self.config.bookcase_top_addr)
        self.chest_top.bookcase = self.fake_bookcase_top
        self.chest_bot = Inventory:new(self.config.bookcase_bot_addr)
        self.chest_bot.bookcase = self.fake_bookcase_bot
        -- Set the direction between them
        self.chest_top:setDirection(self.config.chest_to_bookcase_direction, self.fake_bookcase_top)
        self.chest_bot:setDirection(self.config.chest_to_bookcase_direction, self.fake_bookcase_bot)
        self.chests = { self.chest_top, self.chest_bot, }
        -- Create a fake share where the Transvector Interface is, this allows us to
        -- move books directly to the share chest without going through the bottom
        -- chest.
        self.fake_share = Inventory:new("fake_sharechest_27")
        self.chest_top:setDirection(self.config.bookcase_top_to_tvectorint, self.fake_share)
        -- And finally the share chest under the bottom chest
        self.share_chest = Inventory:new(self.config.share_chest_addr)
        self.chest_bot:setDirection("down", self.share_chest)
        -- Initialise the books
        self:refreshTitles()
    end
    -- The portal now.
    self.portal_chest = Inventory:new(self.config.portal_chest_addr)
    self.recepticle = Inventory:new(self.config.book_recepticle_addr)
    self.recepticle:setDirection(self.config.portal_chest_direction, self.portal_chest)
    -- Set the list spacing to 2
    self.page_support.spacing = 2
    -- Set the number displayed based on the size of the screen
    self.page_support.num_per_page = math.floor((self.windowSize[2] - 11) / self.page_support.spacing)
    -- The page down button shifts half the viewing window.
    self.page_support.shift_count = math.floor(self.page_support.num_per_page / 2)
end

-- Scan the bookcase by pulling all the books from the bookcase (fake) into the
-- chest.
local function isLinkingBook(stack)
    return stack.name == 'Linking book'
end

function PortalCrtl:scanBookcase(chest)
    if chest:slotsUsed() > 0 then
        error("The chest at "..chest.inv.address.." is not empty.")
    end
    chest:pullAll(chest.bookcase)
    stacks = chest:scanChest(isLinkingBook)
    chest:pushAll(chest.bookcase, true)
    return stacks
end

function PortalCrtl:refreshTitles()
    self.linking_books = {}
    for _, chest in ipairs(self.chests) do
        for slot, stack in pairs(self:scanBookcase(chest)) do
            table.insert(self.linking_books, stack)
        end
    end
end

-- The main menu will show a list of title, the order is important as its
-- the order in the linking_books list also.
function PortalCrtl:getMainMenuList()
    titles = {}
    for _, stack in ipairs(self.linking_books) do
        table.insert(titles, stack.destination)
    end
    return titles
end

function PortalCrtl:selectThingFromList(button)
    book = self:activate(button.reference)
    for x=0, 11 do
        self:showDialog({
            title="Activating Portal",
            lines={
                "Openning portal to:",
                "",
                button.text,
                "",
                "Portal will close in "..12-x,
            },
            buttons={},
            width=30,
            result=true,
        })
        sleep(1)
    end
    self:deactivate(book)
end

-- Shift a book based on the referenceIndex in the list of books into the
-- Book Recepticle to active the portal.
--
-- Returns the stack/book for use with deactivate.
function PortalCrtl:activate(referenceIndex)
    return nil
end

-- Shift a book from the recepticle back into it's place in the bookshelf,
-- note that the original position of the book in the bookshelf is stored as
-- book.position while book.slot is updated by the Inventory class to be its
-- current position.
function PortalCrtl:deactivate(book)
    if book == nil then
        return
    end
end

local portal = PortalCrtl:new({
    buttons={
        -- buttons on the bottom of the screen
        {
            text="Info",
            y=0,    --bottom
            xpad=1,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
            callback=function(menu, button) menu:showInfo() end,
        },{
            text="Refresh",
            y=0,    --bottom
            xpad=1,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.blue,
            callback=function(menu, button) menu:refresh() end,
        },{
            text="Sleep",
            y=0,    --bottom
            xpad=1,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.green,
            callback=function(menu, button) return menu:sleep() end
        },{
            text="EXIT",
            y=0,    --bottom
            xpad=1,
            ypad=1,
            text_colour=colours.white,
            background_colour=colours.red,
            callback=function(menu, button) menu:shutdown() end,
        },
    },
    windowSize={70, 38},
})
portal:run()
