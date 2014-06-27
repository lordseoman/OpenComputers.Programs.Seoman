--[[
  This is for testing the functionality in lib/inventory.lua
--]]

local sFunc = require("functions")
local Inventory = require("inventory")
local component = require("component")
local event = require("event")

print("Please select a chest to test with.")
local num = 1
for addr, name in component.list() do
  if Inventory._chests:contains(name) then
    print(string.format("%d: %s %s", num, addr, name))
    num = num + 1
  end
end

local args = { event.pull("key_down") }
local charCode = args[3]
local code = args[4]

print("You selected "..charCode.." ("..type(charCode)..") code="..code)