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
    if not fs.exists('/etc/ocpm/packages') then
        fs.makeDirectory('/etc/ocpm/packages')
    end
    if fs.exists('/etc/ocpm/repos.cfg') then
        local file, msg = io.open("/etc/ocpm/repos.cfg,"rb")
        if not file then
            io.stderr:write("Error while trying to read repos.cfg: "..msg)
            return
        end
        local data = file:read("*a")
        file:close()
        self.repos = serial.unserialize(data) or {}
    end
end

function OCPM:save()
    local file, msg = io.open("/etc/ocpm/repos.cfg","wb")
    if not file then
        io.stderr:write("Error while trying to save repos.cfg: "..msg)
        return
    end
    local data = serial.serialize(self.repos)
    file:write(data)
    file:close()
end

function OCPM:parseArgs(args)
    self.args, self.options = shell.parse(args)
    if self.args[1] == "addrepo" then
        self:addRepository(self.args[2], self.args[3])
    end
end

function OCPM:addRepository(name, url)
    for repo in pairs(self.repos) do
        if repo.name == name or repo.url == url then
            print("Repository alredy exists in list.")
            return
        end
    end
    print("Adding package repository: "..name)
    table.insert(self.repos, {name=name, url=url})
    print("Downloading package list.")
    self:download(url.."/packages.cfg", "/etc/ocpm/packages/"..name)
    self:save()
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
ocpm:parseArgs(...)
