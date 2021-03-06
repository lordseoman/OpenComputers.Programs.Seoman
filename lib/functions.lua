
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
    elseif type(o) == "string" then
        return '"'..o..'"'
    else
        return tostring(o)
    end
end

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
    -- only set the metatable if the original had one, otherwise we would
    -- be removing the existing one on `destiny` or causing an `error`
    local _meta = getmetatable(self)
    if _meta ~= nil then
        setmetatable(destiny, _meta)
    end
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

local function extend(t1, t2)
    for _, v2 in ipairs(t2) do
        table.insert(t1, v2)
    end 
    return t1
end
rawset(table, "extend", extend)

local function rpad(s, length, char)
    if char == nil then 
        char = " "
    elseif #char > 1 then
        char = char:sub(1, 1)
    end
    if #s < length then
        return s .. char:rep(length - #s)
    else
        return s:sub(1, length)
    end
end
rawset(string, "rpad", rpad)

local function extend_new(t1, t2)
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

local function foreach(t1, func, ...)
    for _, v in ipairs(t1) do
        func(v, ...)
    end
end
rawset(table, "foreach", foreach)

local function split(str, pat)
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

function Func.require(filename)
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

function Func.createClass(...)
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

function Func.inheritsFrom( baseClass )

    local new_class = {}
    local class_mt = { __index = new_class }

    function new_class:new()
        local newinst = {}
        setmetatable( newinst, class_mt )
        return newinst
    end

    if nil ~= baseClass then
        setmetatable( new_class, { __index = baseClass } )
    end
    --
    -- Implementation of additional OO properties starts here --
    --
    -- Return the class object of the instance
    function new_class:class()
        return new_class
    end
    --
    -- Return the super class object of the instance
    function new_class:superClass()
        return baseClass
    end
    --
    -- Return true if the caller is an instance of theClass
    function new_class:isa( theClass )
        local b_isa = false

        local cur_class = new_class

        while ( nil ~= cur_class ) and ( false == b_isa ) do
            if cur_class == theClass then
                b_isa = true
            else
                cur_class = cur_class:superClass()
            end
        end

        return b_isa
    end

    return new_class
end


function Func.zip(t1, t2, func)
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
