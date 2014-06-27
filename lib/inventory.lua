--[[
  This presents an Inventory object that wraps an OC component.
--]]
local dict = require("dict")
local component = require("component")

local Inv = {}

Inv._chests = dict:new{
    "iron", "silver", "copper", "gold", "diamond", "crystal",
    "ender_chest",
    "chest",
}

-- These allow oposites to be coded, pushItemIntoSlot and pullItemIntoSlot use
-- string directions (ForgeDirection) and not ints.
directions = dict:new{ 
    down="up", up="down", south="north", north="south", west="east", east="west" 
}

function Inv:new(address)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o:setup(address)
    return o
end

function Inv:setup(address)
    -- A fake inventory should be used when one side of an Inventory pair
    -- doesn't have an Adapter next to it. This means you can't pull or 
    -- push from this inventory, BUT you can pushInto or pullFrom.
    --
    -- A fake inventory should have an address of fake_<>_X
    -- Where <> is unique and X is the size of the inventory
    if string.find(address, 'fake_') ~= nil then
        local i, j = address:find('_', -5)
        self.inv = { address=address, type="chest", }
        self.size = tonumber(address:sub(i+1))
        self.canTransfer = false
    else
        -- Resolve a partial address to a full one that can be used with
        -- proxy
        address = component.get(address)
        if address == nil then
            error("Failed to resolve inventory/component: "..address)
        end
        self.inv = component.proxy(address)
        self.size = self.inv.getInventorySize()
        self.canTransfer = true
    end
    self.dir = {}
    if self._chests:contains(self.inv.type) then
        self.input = { min=1, max=self.size }
        self.output = { min=1, max=self.size }
    -- AESU from GregTech
    elseif self.inv.type == "gt_aesu" then
        self.charge_slot = 1
        self.discharge_slot = 2
    -- Apiary from Forestry
    elseif self.inv.type == "apiculture_0" then
        self.input = { min=1, max=2 }
        self.output = { min=3, max=9 }
    -- Analyser from ExtraBees
    elseif self.inv.type == "core_0" then
        self.input = { min=1, max=6 }
        self.output = {min=9, max=12 }
    -- Inoculator
    elseif self.inv.type == "extrabees_block_advgeneticmachine" then
        self.input = { min=4, max=9 }
        self.output = { min=10, max=15 }
        self.processing_slot = 3
        self.serum_slot = 16
    -- Ender IO Capacitor
    elseif self.inv.type == "blockcapacitorbank" then
        self.input = { min=1, max=4 }
        self.output = { min=1, max=4 }
    else
        error("Unknown inventory type: "..self.inv.type)
    end
end

function Inv:setDirection(direction, target)
    if not directions:contains(direction) then
        error("Unknown direction: "..direction)
    end
    self.dir[target.inv.address] = direction
    target.dir[self.inv.address] = directions[direction]
end

function Inv:clearOutput(target)
    for slot=self.input.min, self.output.max do
        thisStack = self.inv.getStackInSlot(slot)
        if thisStack ~= nil then
            thisStack.slot = slot
            self:pushStack(thisStack, target)
        end
    end
end

-- Can I combine
function Inv:canCombine(source, target)
    -- If there is nothing in the slot then we can put upto maxSize of
    -- the source stack into the slot.
    if target == nil then
        return source.maxSize
    end
    -- If the stacks are not the same then nil
    if not (source.id == target.id and source.damage == target.damage) then
        return nil
    end
    -- If the slot has room return how much room it has
    if target.maxSize > target.size then
        return target.maxSize - target.size
    end
    -- Otherwise no room
    return 0
end

-- Pull a stack from one inventory to another.
--  - if `amount` is nil then the entire stack is pulled 
function Inv:pullStack(stack, source, amount)
    if not self.canTransfer then
        error("Can't pullStack to this inventory: "..self.inv.type)
    end
    if amount == nil or amount > stack.size then 
        amount = stack.size
    elseif amount < 1 then
        return
    end
    retList = {}
    for slot=self.input.min, self.input.max do
        local origStack = self.inv.getStackInSlot(slot)
        local space = self:canCombine(stack, origStack)
        if space and space > 0 then
            local transfer = math.min(space, amount)
            -- The response to pullItem is nil whether it works or not, so check
            -- our slot to see if we got the stacks
            self.inv.pullItemIntoSlot(self.dir[source.name], stack.slot, transfer, slot)
            newstack = self.inv.getStackInSlot(slot)
            if newstack == nil then
                print("Failed to pull into slot "..slot)
            else
                local pulled = space - (newstack.maxSize - newstack.size)
                if pulled > 0 then
                    print("pulled "..pulled.." "..self.dir[source.name])
                    newstack.slot = slot
                    newstack.inventory = self
                    table.insert(retList, newstack)
                    amount = amount - pulled
                end
            end
            if amount == 0 then
                break
            end
        end
    end
    if amount > 0 then
        print("Failed to transfer requested amount.")
    end
    return retList
end

function Inv:pushStack(stack, target, amount)
    if not self.canTransfer then
        error("Can't pushStack from this inventory: "..self.inv.type)
    end
    if amount == nil or amount > stack.size then 
        amount = stack.size
    elseif amount < 1 then
        return {}
    end
    retList = {}
    for slot=target.input.min, target.input.max do
        -- Have to push then check as OC always returns nil and an error but
        -- it does actually work
        self.inv.pushItemIntoSlot(self.dir[target.name], stack.slot, amount, slot)
        local oldstack = self.inv.getStackInSlot(stack.slot)
        if oldstack then
            pushed = stack.size - oldstack.size
            stack.size = oldstack.size
        else
            pushed = stack.size
        end
        if pushed > 0 then
            print("pushed "..pushed.." ".. self.dir[target.name])
            if target.canTransfer then
                newstack = target.inv.getStackInSlot(slot)
                newstack.slot = slot
                newstack.inventory = target
                table.insert(retList, newstack)
            end
            amount = amount - pushed
        end
        if amount == 0 then
            break
        end
    end
    if amount > 0 then
        print("Failed to push amount requested.")
    end
    return retList
end

function Inv:clear(target)
    for slot=1, self.size do
        stack = inv.getStackInSlot(slot)
        if stack ~= nil then
            stack.slot = slot
            self:pushStack(stack, target)
        end
    end
end

function Inv:hasStock(compFunc)
    if compFunc == nil then
        compFunc = function(s) return true end
    end
    for slot=1, self.size do
        stack = self.inv.getStackInSlot(slot)
        if stack ~= nil and compFunc(stack) then
            return true
        end
    end
    return false
end

function Inv:waitUntilCount(count)
    local num
    repeat
        num = 0
        for slot=1, self.size do
            if self.inv.getStackInSlot(slot) ~= nil then 
                num = num + 1 
            end
        end
        os.sleep(2)
    until num >= count
end

return Inv
