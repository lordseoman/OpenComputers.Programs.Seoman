--[[
 *
 * Testing suite for the menu libraries.
 *
--]]

local event = require("event")
local Menu = require("menu")

m = Menu:new{ title="A Testing Menu", windowSize={85, 40}, }

m.monitor.fill(5, 5, 25, 25, "o")
event.pull("touch")

m:drawBox(30, 30, m.hexcolours.blue, m.hexcolours.magenta)
event.pull("touch")

m:renderMainMenu()
event.pull("touch")

m.monitor.set(5, 10, "Click a button")
local p = { event.pull("touch") }
m.monitor.set(5, 12, "Thanks "..p[6]..", you hit button "..p[5])
local button = m:findClickXY(m.buttons, p[3], p[4])
if button then
    m.monitor.set(5, 14, "You clicked "..button.text)
else
    m.monitor.set(5, 14, "Sorry, failed to get a button.")
end

m.monitor.fill(5, 10, 20, 10, " ")
m:showInfo()
event.pull("touch")
