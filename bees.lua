
local Bees = {}
    
function Bees:fixName(name)
    return name:gsub("bees%.species%.",""):gsub("^.", string.upper)
end

function Bees:fixBee(bee)
    if bee.beeInfo ~= nil then
        bee.beeInfo.displayName = self:fixName(bee.beeInfo.displayName)
        if bee.beeInfo.isAnalyzed then
            bee.beeInfo.active.species = self:fixName(bee.beeInfo.active.species)
            bee.beeInfo.inactive.species = self:fixName(bee.beeInfo.inactive.species)
        end
    end
end

function Bees:fixParents(parents)
    parents.allele1 = self:fixName(parents.allele1)
    parents.allele2 = self:fixName(parents.allele2)
    if parents.result then
        parents.result = self:fixName(parents.result)
    end
end

function Bees:beeName(bee)
    local name = bee.slot .. "="
    if bee.beeInfo.active then
        return name .. bee.beeInfo.active.species:sub(1,3) .. "-" .. bee.beeInfo.inactive.species:sub(1,3)
    else
        return name .. bee.beeInfo.displayName:sub(1,3)
    end
end

function Bees:isQueen(bee)
    return bee.id == 13339
end

function Bees:isPrincess(bee)
    return bee.rawName == "item.beeprincessge"
end

function Bees:isDrone(bee)
    return bee.rawName == "item.beedronege"
end

function Bees:isBee(bee)
    return self:isQueen(bee) or self:isPrincess(bee) or self:isDrone(bee)
end

function Bees:isSpecies(bee, species)
    return bee.beeInfo.active.species == species or bee.beeInfo.inactive.species == species
end

function Bees:isPure(bee, species)
    local isPure = bee.beeInfo.active.species == bee.beeInfo.inactive.species
    if species then
        return isPure and bee.beeInfo.active.species == species
    else
        return isPure
    end
end

return Bees

