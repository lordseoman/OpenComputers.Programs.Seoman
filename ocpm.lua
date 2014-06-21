--[[
Another Open Computers Package Manager (ocpm)

Why another package manager you ask, because I wanted something simple that I 
could download updates and dependencies to my programs with. MPT was still too
broken with the CC versus OC differences and OPPM is a little too Open Programs
for me.
--]]

local component = require("component")
local event = require("event")
local fs = require("filesystem")
local process = require("process")
local serial = require("serialization")
local shell = require("shell")
local term = require("term")

local wget = loadfile("/bin/wget.lua")


local OCPM = {}

function OCPM:new(o)
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

function OCPM:setup()
    if not component.isAvailable("internet") then
        io.stderr:write("This program requires an internet card to run.")
        return
    end
    self.args, self.options = shell.parse(...)
end

function OCPM:getURL(url)
    local sContent = ""
    local result, response = pcall(internet.request, url)
    if not result then
        return nil
    end
    for chunk in response do
        sContent = sContent..chunk
    end
    return sContent
end

function OCPM:download(url, path)
    if self.options.f then
        wget("-fq", url, path)
    else
        wget("-q", url, path)
    end
end


ocpm = OCPM:{}
ocpm:setup()
