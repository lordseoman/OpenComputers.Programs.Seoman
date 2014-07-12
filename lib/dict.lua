
local __version__ = "0.12"
local D = {}

function D:new(o)
    if type(o) == nil then
        o = {}
    elseif type(o) ~= "table" then
        print( "expected a table; got " .. type(o) )
        return
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

function dump(o, prefix)
    if prefix == nil then prefix = "" end
    if type(o) == 'table' then
        local s = '{'
        local num = 0
        for k, v in pairs(o) do
            repeat
                -- skip protected attributes
                if string.sub(k, 1, 1) == "_" then
                    break
                end
                if type(k) ~= 'number' then
                    k = '"' .. k .. '"'
                end
                if type(v) == "table" and v.__index ~= nil then
                    v = "object"
                end
                num = num + 1
                s = s .. '\n  ' .. prefix .. k .. ' = ' .. dump(v, prefix .. '  ')
            until true
        end
        if num > 0 then
            s = s .. '\n' .. prefix
        end
        return s .. '}'
    else
        return tostring(o)
    end
end

function D:dump(prefix)
    return dump(self)
end

function D:update(o)
    if type(o) == 'table' then
        for k, v in pairs(o) do
            repeat
                -- skip protected attributes
                if type(k) == "string" and string.sub(k, 1, 1) == "_" then
                    break
                end
                self[k] = v
            until true
        end
    end    
end

function D:length()
    local count = 0
    for k, v in pairs(self) do
        repeat
            -- skip protected attributes
            if type(k) == "string" and string.sub(k, 1, 1) == "_" then
                break
            end
            count = count + 1
        until true
    end
    return count
end

function D:extend(o)
    if type(o) == 'table' then
        for i=1, #o do
            self:add(o[i])
        end
    end
end

function D:slice(i1, i2)
    local n = #self
    -- default values for range
    i1 = i1 or 1
    i2 = i2 or n
    if i2 < 0 then
        i2 = n + i2 + 1
    elseif i2 > n then
        i2 = n
    end
    if i1 < 1 or i1 > n then
        return D:new{}
    end
    local res = D:new{}
    local k = 1
    for i = i1, i2 do
        res[k] = self[i]
        k = k + 1
    end
    return res
end

function D:add(item)
    table.insert(self, item)
end

function D:remove(item)
    for i=1, #self do
        if self[i] == item then
            return table.remove(self, i)
        end
    end
end    

function D:contains(item)
    for _, v in pairs(self) do
        if v == item then
            return true
        end
    end
    return false
end

function D:has_key(item)
    for k, _ in pairs(self) do
        if k == item then
            return true
        end
    end
    return false
end

function D:increment(name, count)
    if count == nil then count = 1 end
    local current = self[name]
    if current == nil then
        self[name] = count
    elseif type(current) ~= "number" then
        error("Attempt to inc non-number value.\n   name="..name)
    else
        self[name] = current + count
    end
    return current
end

-- make a new copy of this array
function D:copy()
    local x = self:new{}
    for k, v in pairs(self) do
        repeat
            if k == "__index" then
                break
            end
            if type(v) == "table" then
                if v.copy ~= nil then
                    x[k] = v:copy()
                else
                    x[k] = v
                end
            else
                x[k] = v
            end
        until true
    end
    return x
end

-- Returns key value pairs but skips hidden/protected attrs
function D:iteritems()
    if self:length() == 0 then
        return function() end, nil, nil
    end
    local keys = {}
    for n, v in pairs(self) do
        if type(n) == "number" then
            table.insert(keys, n)
        elseif type(n) == "string" and string.sub(n, 1, 1) ~= "_" and type(v) ~= "function" then
            table.insert(keys, n)
        end
    end
    local function iterator(t, i)
        i = i + 1
        if keys[i] == nil then
            return nil
        else
            return i, keys[i], self[keys[i]]
        end
    end
    return iterator, self, 0
end

return D
