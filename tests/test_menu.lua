--[[
 *
 * Testing suite for the menu libraries.
 *
--]]

local event = require("event")
local Menu = require("menu")

m = Menu:new{title="A Testing Menu",}

m.monitor.fill(5, 5, 25, 25, "o")
event.pull("touch")

m:drawBox(30, 30, m.hexcolours.blue, m.hexcolours.magenta)
event.pull("touch")

m:renderMainMenu()
event.pull("touch")
