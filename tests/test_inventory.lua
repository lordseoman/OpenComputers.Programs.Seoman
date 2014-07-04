--[[
  This is for testing the functionality in lib/inventory.lua
--]]

-- This is annoying, lua is caching across executions
package.loaded.inventory = nil

local sFunc = require("functions")
local Inventory = require("inventory")
local component = require("component")
local event = require("event")
local sides = require("sides")
local dict = require("dict")

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
    table.insert(selected, chests[selection])
  end
until #selected == 2

print("---------------------------------------")
local inv1 = Inventory:new(selected[1])
print(string.format("Inventory '%s' with %d slots", inv1.inv.type, inv1.size))
local inv2 = Inventory:new(selected[2])
print(string.format("Inventory '%s' with %d slots", inv2.inv.type, inv2.size))

print("---------------------------------------")
print("Where is chest #2 compared to chest #1?")
for i=0, #sides-1 do 
  print("  "..i..": "..sides[i])
end
repeat
  local args = { event.pull("key_down") }
  local selection = tonumber(string.char(args[3]))
  if selection < 0 or selection >= #sides then
      print("Sorry, please try again: _")
  else
      inv1:setDirection(sides[selection], inv2)
  end
until #selected == 2
print("---------------------------------------")

print("Now place some items in the first chest, and hit a key.")
event.pull("key_down")
local stacks = inv1:scanChest()
for slot, stack in pairs(stacks) do
  print(" - slot "..stack.slot.." - "..stack.name.." (qty: "..stack.size..")")
end

print("Transfering half of each stack to chest #2")
local newstacks = dict:new{}
for slot, stack in pairs(stacks) do
  local result = inv1:pushStack(stack, inv2, math.floor(stack.size/2))
  for _, stack in ipairs(result) do
    newstacks[stack.slot] = stack
  end
end
print("Outcome..")
print("---------------------------------------")
for slot, stack in pairs(newstacks) do
  print(stack.inventory.inv.type..": "..stack.name.." (qty: "..stack.size..") ".."slot: "..stack.slot)
end

print("Press any key to transfer items back using PULL")
event.pull("key_down")
for slot, stack in pairs(newstacks) do
  local result = inv1:pullStack(stack, inv2)
end
local stacks = inv1:scanChest()
for slot, stack in pairs(stacks) do
  print(" - slot "..stack.slot.." - "..stack.name.." (qty: "..stack.size..")")
end
print("Condensing Items.")
inv1.inv.condenseItems()
for slot, stack in pairs(stacks) do
  print(" - slot "..stack.slot.." - "..stack.name.." (qty: "..stack.size..")")
end
