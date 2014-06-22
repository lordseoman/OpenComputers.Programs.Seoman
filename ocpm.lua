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
  install_basedir="/usr",
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
    if fs.exists(self.repofilename) then
        self.repos = self:readfile(self.repofilename) or {}
    else
        self.repos = {}
    end
end

function OCPM:readfile(filename)
    local file, msg = io.open(filename,"rb")
    if not file then
        io.stderr:write("Error while trying to read "..filename..": "..msg)
        return
    end
    local data = file:read("*a")
    file:close()
    return serial.unserialize(data) or {}
end
        
function OCPM:savefile(filename, data)
    local file, msg = io.open(filename,"wb")
    if not file then
        io.stderr:write("Error while trying to save "..filename..": "..msg)
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
        self:install(args[2], true)
    elseif args[1] == "search" then
        local pkgs = self:search(args[2])
        local pad = " "
        for _, pData in ipairs(pkgs) do
            print(pData.pkgname..pad:rep(16 - #pData.pkgname)..": "..pData.pkg.description)  
        end
    elseif args[1] == "update" then
        for _, repo in ipairs(self.repos) do
            self:updatePackages(repo)
        end
    elseif args[1] == "forceocpm" then
        local repo = self:getRepository("seoman")
        if repo == nil then
            print("You need to add the seoman repo first.")
            return
        end
        self:download(repo.url .. "/ocpm.lua", "/usr/bin/ocpm.lua", true)
    end
end

function OCPM:search(packagename, exact)
    local basedir = "/etc/ocpm/packages/"
    local fsList, errmsg = fs.list(basedir)
    pkgs = {}
    if fsList == nil then
        is.stderr:write("Error getting list of packages: "..errmsg)
        return pkgs
    end
    for plistFn in fsList do
        pkglist = self:readfile(basedir..plistFn)
        for pname, pkgdata in pairs(pkglist) do
            if (packagename == nil) or ( 
                (exact and pname == packagename) or (not exact and pname:find(packagename) ~= nil)
                ) then
                table.insert(pkgs, {repo=plistFn, pkg=pkgdata, pkgname=pname,}) 
            end
        end
    end
    return pkgs
end

function OCPM:getRepository(name)
    for _, repo in ipairs(self.repos) do
        if repo.name == name then
            return repo
        end
    end
end

function OCPM:addRepository(name, url)
    for _, repo in ipairs(self.repos) do
        if repo.name == name or repo.url == url then
            print("Repository alredy exists in list.")
            return
        end
    end
    print("Adding package repository: "..name)
    table.insert(self.repos, {name=name, url=url})
    self:updatePackages(repo)
    self:savefile(self.repofilename)
end
    
function OCPM:updatePackages(repo)
    print("Downloading package list: etc/ocpm/packages/"..repo.name)
    self:download(repo.url.."/packages.cfg", "/etc/ocpm/packages/"..repo.name, true)
end

function OCPM:install(packagename, update)
    local pkglist = self:search(packagename, true)
    if #pkglist == 0 then
        print("No package by that name to install.")
        return
    end
    local repo = self:getRepository(pkglist[1].repo)
    if repo == nil then
        print("Repository config for package list is missing.")
        return
    end
    print("Installing "..pkglist[1].pkgname)
    for remoteFn, localPath in pairs(pkglist[1].pkg.files) do
        -- If the localPath is specified with '/' as the first character then don't
        -- prepend the install_basedir
        if localPath:find("^/") == nil then
            localPath = fs.concat(self.install_basedir, localPath)
        end
        if not fs.exists(localPath) then
            fs.makeDirectory(localPath)
        end
        -- Append the name of the file to localPath.
        localPath = fs.concat(localPath, fs.name(remoteFn))
        self:download(repo.url .. remoteFn, localPath, update)
    end
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
