--[[
 *
 * This is a ComputerCraft script, copy it onto any CC terminal and run,
 * then send the CC terminal remote commands from OC using the remote-cc-cmd.lua
 * script.
 *
--]]

modem = peripheral.find("oc_adapter")
if modem == nil then
    print("No OC Adapter block found attached to this terminal.")
    return
end

local port = 221
local serverAddr = {}
local seen = {}
local quit = false

modem.open(port)

function dump(o, prefix)
    if prefix == nil then prefix = "  " end
    if type(o) == 'table' then
        local s = '{\n'
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
                s = s .. prefix .. k .. ' = ' .. dump(v, prefix .. '  ') .. ',\n'
            until true
        end
        return s .. '}\n'
    else
        return tostring(o)
    end
end

local function contains(self, id)
    for i, v in pairs(self) do
        if v == id then
            return true
        end
    end
    return false
end   
rawset(table, "contains", contains)

while quit == false do
    local event, side, port, dst, msg = os.pullEvent("modem_message")
    local request = textutils.unserialize(msg)
    if table.contains(serverAddr, request.source) then
        if seen[request.id] == nil then
            seen[request.id] = 1
            --print("New request: "..request.command)
            --print(dump(request.args))
            local reply = { id=request.id, }
            if request.command == "quit" then
                print("Quitting... bye.")
                quit = true
                reply.reply = "Okay, quitting."
            elseif request.command == "register" then
                print("Source already registered.")
                reply.reply = "Registration successful."
            elseif request.command == "echo" then
                print("Echoing request.")
                reply.reply = request.args
            elseif request.command == "unregister" then
                print("Unregistration request.")
                table.remove(serverAddr, request.source)
                reply.reply = "Source removed."
            elseif request.command == "peripheral_call" then
                print("Calling method on peripheral.")
                if peripheral.isPresent(request.args[1]) == false then
                    reply.error = "No such peripheral"
                else
                    local methods = peripheral.getMethods(request.args[1])
                    if not table.contains(methods, request.args[2]) then
                        reply.error = "No such peripheral method: "..request.args[2]
                    else
                        reply.reply = peripheral.call(unpack(request.args))
                    end
                end
            end
            modem.transmit(port, port, textutils.serialize(reply))
        end
    elseif request.command == "register" then
        print("New registration request.")
        table.insert(serverAddr, request.source)
        local reply = { id=request.id, reply="Registration successful.", }
        modem.transmit(port, port, textutils.serialize(reply))
    elseif request.source ~= nil then
        print("Ignoring request from "..request.source)
    else
        print("Uncommon message: "..request)
    end
end
