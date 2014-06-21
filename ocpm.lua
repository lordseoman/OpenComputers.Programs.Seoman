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


local OCPM = {
  repofilename="/etc/ocpm/repos.cfg",
}

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
        self.repos = self:readfile(self.repofilename) or {}
    else
        self.repos = {}
    end
end

function OCPM:readfile(filename)
    local file, msg = io.open("/etc/ocpm/repos.cfg","rb")
    if not file then
        io.stderr:write("Error while trying to read repos.cfg: "..msg)
        return
    end
    local data = file:read("*a")
    file:close()
    return serial.unserialize(data) or {}
end
        
function OCPM:savefile(filename, data)
    local file, msg = io.open(filename,"wb")
    if not file then
        io.stderr:write("Error while trying to save repos.cfg: "..msg)
        return
    end
    file:write(serial.serialize(data))
    file:close()
end

function OCPM:parseArgs(...)
    args, self.options = shell.parse(...)
    if args[1] == "addrepo" then
        self:addRepository(args[2], args[3])
    elseif args[1] == "install" then
        self:install(args[2])
    elseif args[1] == "search" then
        self:search(args[2])
    elseif args[1] == "forceocpm" then
        local repo = self:getRepository("seoman")
        if repo == nil then
            print("You need to add the seoman repo first.")
            return
        end
        self:download(repo.url .. "/ocpm.lua", "/usr/bin/ocpm.lua", true)
    end
end

function OCPM:search(packagename)
    local fsList, errmsg = fs.list("/etc/ocpm/packages/")
    if fsList == nil then
        is.stderr:write("Error getting list of packages: "..errmsg)
        return
    end
    for plistFn in fsList do
        pkglist = self:readfile(plistFn)
        for pname, pkgdata in pairs(pkglist) do
            if pname:find(packagename) ~= nil then
                print(pname.."\t: "..pkgdata.description)
            end
        end
    end
end

function OCPM:getRepository(name)
    for repo in pairs(self.repos) do
        if repo.name == name then
            return repo
        end
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
    print("Downloading package list: etc/ocpm/packages/"..name)
    self:download(url.."/packages.cfg", "/etc/ocpm/packages/"..name)
    self:savefile(self.repofilename)
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

function OCPM:download(url, path, force)
    if force then
        wget("-fq", url, path)
    else
        wget("-q", url, path)
    end
end

ocpm = OCPM:new{}
ocpm:setup()
ocpm:parseArgs(...)
