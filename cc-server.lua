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
local quit = false

modem.open(port)
print("Listening for commands on "..port)

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
            s = s .. '\n'
        end
        return s .. prefix .. '}'
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
    if serverAddr[request.source] ~= nil then
        local msgQueue = serverAddr[request.source]
        local reply = { id=request.id, }
        if request.command == 'unregister' then
            print("Unregistration request.")
            serverAddr[request.source] = nil
            reply.reply = "Source removed."
        elseif msgQueue[request.id] == nil then
            msgQueue[request.id] = request.command
            msgQueue["maxId"] = math.max(request.id, msgQueue["maxId"])
            print("request = "..dump(request.args))
            if request.command == "quit" then
                print("Quitting... bye.")
                quit = true
                reply.reply = "Okay, quitting."
            elseif request.command == "register" then
                print("Source already registered.")
                reply.reply = {"Already registered.", msgQueue["maxId"],}
            elseif request.command == "echo" then
                print("Echoing request.")
                reply.reply = request.args
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
        end
        if reply.reply ~= nil or reply.error ~= nil then
            modem.transmit(port, port, textutils.serialize(reply))
        end
    elseif request.command == "register" then
        print("New registration request.")
        serverAddr[request.source] = {}
        serverAddr[request.source][request.id] = request.command
        serverAddr[request.source]["maxId"] = request.id
        local reply = { id=request.id, reply="Registration successful.", }
        modem.transmit(port, port, textutils.serialize(reply))
    elseif request.source ~= nil then
        print("Ignoring request from "..request.source)
    else
        print("Uncommon message: "..request)
    end
end
