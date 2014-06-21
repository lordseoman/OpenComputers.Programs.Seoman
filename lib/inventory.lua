
local dict = require("dict")
local component = require("component")

local Inv = { fake=false }

chests = dict:new{
    "iron", "silver", "copper", "gold", "diamond", "crystal",
    "ender_chest",
    "container_chest",
}

directions = dict:new{ 
    down="up", up="down", south="north", north="south", west="east", east="west" 
}

function Inv:new(name)
    o = {}
    setmetatable(o, self)
    self.__index = self
    o:setup(name)
    return o
end

function Inv:setup(name)
    self.name = name
    local i, j = name:find('_', -5)
    if string.find(name, 'fake_') ~= nil then
        self.inv = nil
        self.size = tonumber(name:sub(i+1))
        self.fake = true
    else
        self.inv = component.get(name)
        if self.inv == nil then
            error("Failed to find inventory: "..name)
        end
        self.size = self.inv.getInventorySize()
    end
    self.dir = {}
    local pname = name:sub(1, i-1)
    if (chests:contains(pname) or self.fake) then
        self.input = { min=1, max=self.size }
        self.output = { min=1, max=self.size }
    -- Apiary from Forestry
    elseif pname == "apiculture" then
       self.input = { min=1, max=2 }
       self.output = { min=3, max=9 }
    -- Analyser from ExtraBees
    elseif pname == "core" then
        self.input = { min=1, max=6 }
        self.output = {min=9, max=12 }
    -- Inoculator
    elseif pname == "peripheral" then
        self.input = { min=4, max=9 }
        self.output = { min=10, max=15 }
        self.processing_slot = 3
        self.serum_slot = 16
    else
        error("bugger "..pname)
    end
end

function Inv:setDirection(direction, target)
    if not directions:contains(direction) then
        error("Unknown direction: "..direction)
    end
    self.dir[target.name] = direction
    target.dir[self.name] = directions[direction]
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

-- Pull a stack from one inventory to another.
--  - if `amount` is nil then the entire stack is pulled 
function Inv:pullStack(stack, source, amount)
    if self.fake then
        error("Can't pullStack on a fake inventory.")
    end
    if amount == nil or amount > stack.qty then 
        amount = stack.qty
    elseif amount < 1 then
        return
    end
    retList = {}
    totalPulled = 0
    for slot=self.input.min, self.input.max do
        pulled = self.inv.pullItemIntoSlot(self.dir[source.name], stack.slot, amount, slot)
        if pulled > 0 then
            print("pulled "..pulled.." "..self.dir[source.name])
            newstack = self.inv.getStackInSlot(slot)
            newstack.slot = slot
            newstack.inventory = self
            table.insert(retList, newstack)
            totalPulled = totalPulled + pulled
            amount = amount - pulled
        end
        if amount == 0 then
            break
        end
    end
    return retList
end

function Inv:pushStack(stack, target, amount)
    if amount == nil or amount > stack.qty then 
        amount = stack.qty
    elseif amount < 1 then
        return {}
    end
    retList = {}
    totalPushed = 0
    for slot=target.input.min, target.input.max do
        pushed = self.inv.pushItemIntoSlot(self.dir[target.name], stack.slot, amount, slot)
        if pushed > 0 then
            print("pushed "..pushed.." ".. self.dir[target.name])
            if not target.fake then
                newstack = target.inv.getStackInSlot(slot)
                newstack.slot = slot
                newstack.inventory = target
                table.insert(retList, newstack)
            end
            totalPushed = totalPushed + pushed
            amount = amount - pushed
        end
        if amount == 0 then
            break
        end
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
