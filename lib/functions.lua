
local function copy(self, destiny)
    if destiny == nil then destiny = {} end
    for k, v in pairs(self) do
        repeat
            if k == "__index" then
                break
            end
            if type(v) == "table" then
                if v.copy ~= nil then
                    destiny[k] = v:copy()
                else
                    destiny[k] = v
                end
            else
                destiny[k] = v
            end
        until true
    end
    setmetatable(destiny, getmetatable(self))
    return destiny
end
rawset(table, "copy", copy)

local function contains(self, id)
    for i, v in pairs(self) do
        if v == id then
            return true
        end
    end
    return false
end
rawset(table, "contains", contains)

function extend(t1, t2)
    for _, v2 in ipairs(t2) do
        table.insert(t1, v2)
    end 
    return t1
end
rawset(table, "extend", extend)

function rpad(s, length)
    if #s < length then
        return s .. " ":rep(length - #s)
    else
        return s:sub(1, length)
    end
end
rawset(string, "rpad", rpad)

function extend_new(t1, t2)
    result = {}
    for _, v1 in ipairs(t1) do
        table.insert(results, v1)
    end 
    for _, v2 in ipairs(t2) do
        table.insert(results, v2)
    end 
    return result
end         
rawset(table, "extend_new", extend_new)

function foreach(t1, func, ...)
    for _, v in ipairs(t1) do
        func(v, ...)
    end
end
rawset(table, "foreach", foreach)

function split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
	        table.insert(t,cap)
        end
        last_end = e+1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end
rawset(string, "split", split)

local Func = { colourNames={
    "red", "green", "blue", "yellow", "white", "black", "brown", "pink",
    "magenta", "lightBlue", "cyan", "purple",
}, }

function Func:require(filename)
    if fs.exists(filename) == false then
        filename = fs.combine("lib", filename)
    end
    if fs.exists(filename) == false then
        filename = fs.combine("simon",  filename)
    end
    local loadFunc, err = loadfile(filename)
    if type(loadFunc) == "function" then
        return loadFunc()
    else
        print ( "Error loading ("..filename..") API: " .. err)
    end
end

-- look up for `k' in list of tables `plist'
local function search(k, plist)
    for i=1, table.getn(plist) do
        local v = plist[i][k]     -- try `i'-th superclass
        if v then return v end
    end
end

function Func:createClass(...)
    local c = {}        -- new class

    -- class will search for each method in the list of its
    -- parents (`arg' is the list of parents)
    setmetatable(c, {__index = function (t, k) return search(k, arg) end})

    -- prepare `c' to be the metatable of its instances
    c.__index = c

    -- define a new constructor for this new class
    function c:new (o)
        o = o or {}
        setmetatable(o, c)
        return o
    end

    -- return new class
    return c
end

function Func:zip(t1, t2, func)
    if func == nil then
        func = function ( x1, x2 ) return { x1, x2 } end
    end
    result = {}
    for _, v1 in ipairs(t1) do
        for _, v2 in ipairs(t2) do
            table.insert(result, func(v1, v2))
        end
    end 
    return result
end 
 
return Func
