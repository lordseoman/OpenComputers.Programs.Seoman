--[[
  This is for testing the functionality in lib/inventory.lua
--]]

local sFunc = require("functions")
local Inventory = require("inventory")
local component = require("component")
local event = require("event")

print("Here is a list of available chests:")
print("---------------------------------------")
local num = 1
local chests = {}
for addr, name in component.list() do
  if Inventory._chests:contains(name) then
    print(string.format("%d: %s %s", num, addr, name))
    table.insert(chests, addr)
    num = num + 1
  end
end
print("---------------------------------------")
local selected = {}
repeat
  if #selected == 0 then
    print("Please choose a chest to test with: ")
  else
    print("Please choose a second chest: ")
  end
  local args = { event.pull("key_down") }
  local selection = tonumber(string.char(args[3]))
  if selection < 1 or selection > #chests then
      print("Sorry, please choose from the above.")
  else
    local chest1 = component.proxy(chests[selection])
    print("You selected: addr="..chest1.address.." type="..chest1.type)
    table.insert(selected, chest1)
  end
until #selected == 2

print("Now place some items in the first chest.")