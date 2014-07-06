
local component = require("component")
local args = {...}


if args[1] == "list" then
    for address, cType in component.list() do
        print(address:sub(1, 8) ..": "..cType)
    end
elseif args[1] == "methods" then
    local address = component.get(args[2])
    if address == nil then
        print("No component found with that address or type: "..args[2])
        return
    end
    thisProx = component.proxy(address)
    for name, _ in pairs(thisProxy) do
        print(name)
    end
end
