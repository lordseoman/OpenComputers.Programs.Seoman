
local sFunc
do
    local loadFunc, err = loadfile("simon/simons_functions")
    if type(loadFunc) == "function" then
        sFunc = loadFunc()
    else
        print("Error loading (simons_functions) API: " .. err)
        return
    end
end

local dict = sFunc:require("simons_dict")

local Traits = { all={}, }

function Traits:new(o)
    if type(o) == nil then
        o = {}
    elseif type(o) ~= "table" then
        print("expected a table as input with any args; got " .. type(o))
        return
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

function Traits:add(t)
    self.all[t.name] = t
end

function Traits:get(name)
    return self.all[name]
end

function Traits:getSerum(name)
    i, j = string.find(name, '%.')
    if i == nil then
        trait = self:get(name)
        subject = nil
    else
        trait = self:get(string.sub(name, 1, i-1))
        subject = string.sub(name, i+1)
    end
    if trait ~= nil then
        return trait:getSerum(subject)
    end
end

function Traits:addSerum(serum)
    local done = false
    for dmy, trait in pairs(self.all) do
        if trait:addSerum(serum) == true then
            --print ("Added serum ("..serum.name..") to "..trait.name)
            done = true
            break
        end
    end
    if done == false then
        print("Failed to add serum: "..serum.name)
    end
end

function Traits:getList(priorities)
    traits = {}
    for _, trait in ipairs(priorities) do
        table.insert(traits, self.all[trait])
    end
    return traits
end

local traits = Traits:new{}

local Trait = { 
    default=nil, 
    name=nil,
    description="Unknown",
    serum=nil,
    map={},
}

function Trait:new(o)
    if type(o) == nil then
        o = {}
    elseif type(o) ~= "table" then
        print("expected a table as input with any args; got " .. type(o))
        return
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

local NumberTrait = Trait:new{}

function NumberTrait:score(bee)
    if bee.beeInfo.isAnalyzed then 
        return (bee.beeInfo.active[self.name] + bee.beeInfo.inactive[self.name]) / 2
    else
        return self.default
    end
end

function NumberTrait:addSerum(serum)
    local found = false
    for value, serumName in pairs(self.serum) do
        if (type(serumName) == "string" and serumName == serum.name) or (type(serumName) == "table" and serumName.name == serum.name) then
            serum.trait = self.name
            serum.isNeeded = function (self, bee)
                return bee.beeInfo.active[self.trait] < value or bee.beeInfo.inactive[self.trait] < value
            end
            self.serum[value] = serum
            found = true
            break
        end
    end
    return found
end

function NumberTrait:getSerum(subject)
    if subject == nil then
        return self:getHighestSerum()
    else
        local retItem = nil
        for value, name in pairs(self.map) do
            if name == subject then
                serum = self.serum[value]
                if type(serum) == "table" then
                    retItem = serum
                end
                break
            end
        end
        return retItem
    end
end

function NumberTrait:getHighestSerum()
    retVal = 0
    retItem = nil
    for value, serum in pairs(self.serum) do
        if type(serum) == "table" and value > retVal then
            retVal = value
            retItem = serum
        end
    end
    return retItem
end

traits:add(NumberTrait:new{
    name="fertility", 
    description="Number of drones produced when dead", 
    default=1, 
    map={
        [1]="1",
        [2]="2",
        [3]="3",
        [4]="4",
    },
    serum={
        [1] = "Blerg Blerg",
        [2] = "Blerg Blerg",
        [3] = "Blerg Blerg",
        [4] = "Maximum Fertility Serum",
    },
})
traits:add(NumberTrait:new{
    name="flowering", 
    description="The pollination speed", 
    default=20, 
    map={
        [5]  = "Slowest",
        [10] = "Slower",
        [15] = "Slow",
        [20] = "Normal",
        [25] = "Fast",
        [30] = "Faster",
        [35] = "Fastest",
        [99] = "Maximum",
    },
    serum={
        [5] = "Blerg",
        [10] = "Blerg",
        [15] = "Blerg",
        [20] = "Average Flowering Serum",
        [25] = "Blerg",
        [30] = "Blerg",
        [35] = "Blerg",
        [99] = "Blerg",
    },
})
traits:add(NumberTrait:new{
    name="speed", 
    description="How fast a worker the bee is", 
    default=1, 
    serum={
        [0.3] = "Blerg",
        [0.6] = "Blerg",
        [0.8] = "Blerg",
        [1.0] = "Blerg",
        [1.2] = "Fast Production Serum",
        [1.4] = "Blerg",
        [1.7] = "Blerg",
    },
    map={
        [0.3] = "Slowest",
        [0.6] = "Slower",
        [0.8] = "Slow",
        [1.0] = "Normal",
        [1.2] = "Fast",
        [1.4] = "Faster",
        [1.7] = "Fastest",
    },
})
traits:add(NumberTrait:new{
    name="lifespan", 
    description="How long the bee lives", 
    default=40, 
    map={
        [10] = "Shortest",
        [20] = "Shorter",
        [30] = "Short",
        [35] = "Shortened",
        [40] = "Normal",
        [45] = "Elongated",
        [50] = "Long",
        [60] = "Longer",
        [70] = "Longest",
    },
    serum={
        [10] = "Blerg",
        [20] = "Blerg",
        [30] = "Short Lifespan Serum",
        [35] = "Blerg",
        [40] = "Normal Lifespan Serum",
        [45] = "Elongated Lifespan Serum",
        [50] = "Long Lifespan Serum",
        [60] = "Blerg",
        [70] = "Blerg",
    },
})

local BooleanTrait = Trait:new{ default=0 }

function BooleanTrait:score(bee)
    if bee.beeInfo.isAnalyzed then
        return (
            (bee.beeInfo.active[self.name] and 1 or 0) +
            (bee.beeInfo.inactive[self.name] and 1 or 0)
        ) / 2.0
    else
        return self.default
    end
end

function BooleanTrait:getSerum(subject)
    if type(self.serum) == "table" then
        return self.serum
    end
end

function BooleanTrait:getHighestSerum()
    if type(self.serum) == "table" then
        return self.serum
    end
end

function BooleanTrait:addSerum(serum)
    if (type(self.serum) == "string" and serum.name == self.serum) or (type(self.serum) == "table" and self.serum.name == serum.name) then
        serum.trait = self.name
        serum.isNeeded = function (self, bee)
            return bee.beeInfo.active[self.trait] == false or bee.beeInfo.inactive[self.trait] == false
        end
        self.serum = serum
        return true
    end
    return false
end

traits:add(BooleanTrait:new{
    name="nocturnal", 
    description="Can the bee work at night", 
    serum="Nocturnal Serum"
})
traits:add(BooleanTrait:new{
    name="caveDwelling", 
    description="Can the bee work underground", 
    serum="Cave Dwelling Serum"
})
traits:add(BooleanTrait:new{
    name="tolerantFlyer", 
    description="Can the bee work in rain", 
    serum="Rainfall Serum"
})

local WeightedTrait = Trait:new{ weights={} }

function WeightedTrait:score(bee)
    if bee.beeInfo.isAnalysed then
        return (
            (self.weights[bee.beeInfo.active[self.name]] or self.default) +
            (self.weights[bee.beeInfo.inactive[self.name]] or self.default)
        ) / (2 * self.max)
    else
        return self.default
    end
end

function WeightedTrait:addSerum(serum)
    local found = false
    for value, serumName in pairs(self.serum) do
        if (type(serumName) == "string" and serumName == serum.name) or (type(serumName) == "table" and serumName.name == serum.name) then
            serum.trait = self.name
            serum.weights = self.weights
            serum.isNeeded = function (self, bee)
                return self.weights[bee.beeInfo.active[self.trait]] ~= self.weights[value] or self.weights[bee.beeInfo.inactive[self.trait]] ~= self.weights[value]
            end
            self.serum[value] = serum
            found = true
            break
        end
    end
    return found
end

function WeightedTrait:getSerum(subject)
    if subject == nil then
        return self:getHighestSerum()
    else
        serum = self.serum[subject]
        if type(serum) == "table" then
            return serum
        end
    end
end

function WeightedTrait:getHighestSerum()
    retVal = 0
    retItem = nil
    for subject, serum in pairs(self.serum) do
        if type(serum) == "table" then
            value = self.weights[subject]
            if value > retVal then
                retVal = value
                retItem = serum
            end
        end
    end
    return retItem
end

traits:add(WeightedTrait:new{
    name="humidityTolerance",
    default=0,
    weights={
        ["None"]=0,
        ["Up 1"]=1, 
        ["Up 2"]=2, 
        ["Down 1"]=1,
        ["Down 2"]=2,
        ["Both 1"]=2, 
        ["Both 2"]=4,
    },
    max=4,
    serum={
        ["None"] = "Blerg",
        ["Up 1"] = "Blerg",
        ["Up 2"] = "Blerg",
        ["Down 1"] = "Blerg",
        ["Down 2"] = "Blerg",
        ["Both 1"] = "Blerg",
        ["Both 2"] = "Humid. Both 2 Tol. Serum",
    },
})
traits:add(WeightedTrait:new{
    name="temperatureTolerance",
    default=0,
    weights={
        ["None"]=0,
        ["Up 1"]=1, 
        ["Up 2"]=2, 
        ["Down 1"]=1,
        ["Down 2"]=2,
        ["Both 1"]=2, 
        ["Both 2"]=4,
    },
    max=4,
    serum={
        ["None"] = "Blerg",
        ["Up 1"] = "Blerg",
        ["Up 2"] = "Blerg",
        ["Down 1"] = "Blerg",
        ["Down 2"] = "Blerg",
        ["Both 1"] = "Blerg",
        ["Both 2"] = "Temp. Both 2 Tol. Serum",
    },
})
traits:add(WeightedTrait:new{
    name="flowerProvider",
    default=0,
    weights={
        ["Rocks"] = 4, 
        ["Flowers"] = 4,
        ["Jungle"] = 3,
        ["Cacti"] = 2, 
        ["Nether"] = 2,
        ["Mushroom"] = 0,
        ["Exotic Flowers"] = 0, 
        ["Wheat"] = 1,
    },
    max=5,
    serum={
        ["Flowers"] = "Flowers Pollination Serum",
        ["Rocks"] = "Rocks Pollination Serum",
        ["Nether"] = "Nether Pollination Serum",
        ["Cacti"] = "Cacti Pollination Serum",
        ["Jungle"] = "Jungle Pollination Serum",
        ["Exotic Flowers"] = "Blerg",
        ["Mushroom"] = "Blerg",
        ["Wheat"] = "Blerg",
    },
})
traits:add(WeightedTrait:new{
    name="effect",
    default=0,
    weights={
        ["None"] = 3,
        ["Agressive"] = 0,
        ["Beatific"] = 5,
    },
    max=5,
    serum={
        ["None"] = "None Effect Serum",
        ["Agressive"] = "apiculture.effect.aggressive Effect Serum",
        ["Beatific"] = "apiculture.effect.beatific Effect Serum",
    },
})

return traits

