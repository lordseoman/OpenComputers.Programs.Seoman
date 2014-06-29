--[[
 *
 * Testing suite for the menu libraries.
 *
--]]

-- Add a forced clear of the packages
package.loaded.menu = nil

local event = require("event")
local Menu = require("menu")

m = Menu:new{ title="A Testing Menu", windowSize={85, 40}, }

m.monitor.set(5, 35, "Click anywhere to continue.")
m.monitor.fill(5, 5, 25, 25, "o")
event.pull("touch")

m.monitor.fill(1, 1, m.windowSize[1], m.windowSize[2], " ")
m:drawBox(30, 30, m.hexcolours.blue, m.hexcolours.magenta)
m.monitor.set(5, m.windowSize[2]-2, "Click anywhere to continue.")
event.pull("touch")

m:renderMainMenu()
m.monitor.set(5, 15, "Click anywhere to continue.")
event.pull("touch")

m.monitor.fill(5, 10, m.windowSize[1]-5, m.windowSize[2]-15, " ")
m.monitor.set(5, 10, "Click a button")
local p = { event.pull("touch") }
m.monitor.set(5, 12, "Thanks "..p[6]..", you hit button "..p[5])
local button = m:findClickXY(m.buttons, p[3], p[4])
if button then
    m.monitor.set(5, 14, "You clicked "..button.text)
else
    m.monitor.set(5, 14, "Sorry, failed to get a button.")
end
m.monitor.set(5, 15, "Click anywhere to continue.")
event.pull("touch")

-- This renders the dialog and waits for input, so no need to wait
m.monitor.fill(5, 10, m.windowSize[1]-5, m.windowSize[2]-15, " ")
m:showInfo()

-- Now run the menu
m:run()
