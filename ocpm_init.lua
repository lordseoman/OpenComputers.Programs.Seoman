local component = require("component")
local fs = require("filesystem")

if fs.exists('/usr/bin/ocpm.lua') then
  print("ocpm is already installed, use ocpm update instead.")
  return
end

if not component.isAvailable("internet") then
  error("You need an Internet card installed.")
end

if not fs.exists('/usr') then
  print("Making /usr/")
  fs.makeDirectory('/usr/')
end
if not fs.exists('/usr/bin') then
  print("Making /ust/bin/")
  fs.makeDirectory('/usr/bin')
end

local wget = loadfile("/bin/wget.lua")
print ("Downloading Open Computers Package Manager (ocpm.lua)")
wget("-q", "https://github.com/lordseoman/OpenComputers.Programs.Seoman/raw/master/ocpm.lua", "/usr/bin/ocpm.lua")
print ("..done. run ocpm --help|-h for details")