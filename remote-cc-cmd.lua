--[[
 *
 * This is a remote calling library for sending remote commands to a
 * connected ComputerCraft device running the remote-cc-listener.lua
 * script.
 *
--]]
local __version__ = "0.23"

local component = require("component")
local event = require("event")
local serial = require("serialization")
local dict = require("dict")

local slaveAddr = nil
local port = 221
local msgQueue = dict:new{ _msgId=1, }

function msgQueue:getNextId()
    return self:increment("_msgId")
end

component.modem.open(port)

function register()
    msg = {
        id=msgQueue:getNextId(),
        source=component.modem.address,
        command="register",
    }
    component.modem.broadcast(port, serial.serialize(msg))
    msg.callback=function(reply)
        print ("Running callback..")
        slaveAddr = request.reply.source
        if type(request.reply.reply) == "table" then
            print("From ".. request.reply.source ..": "..request.reply.reply[1])
            msgQueue:increment("_msgId", request.reply.reply[2])
        else
            print("From ".. request.reply.source ..": "..request.reply.reply)
        end
    end
    msgQueue[msg.id] = msg
end

function unregister()
    msg = {
        id=msgQueue:getNextId(),
        source=component.modem.address,
        command="unregister",
    }
    msgQueue[msg.id] = msg
    component.modem.broadcast(port, serial.serialize(msg))
end

function sendCommand(command, ...)
    if slaveAddr == nil then
        print("Cannot send commands without registration.")
        return false
    end   
    msg = {
        id=msgQueue:getNextId(),
        source=component.modem.address,
        command=command,
        args={...},
    }
    msgQueue[msg.id] = msg
    component.modem.send(slaveAddr, port, serial.serialize(msg))
    return true
end

function listenForResponses(event, dst, src, port, dist, rport, msg)
    local retVal = true
    local response = serial.unserialize(msg)
    request = msgQueue[response.id]
    --print(dump(response))
    if request == nil then
        --print("Got response to non-existant request ("..response.id.."), ignoring.")
    elseif request.reply ~= nil then
        --print("Got a reply already, dropping.")
    else
        request.reply = response
        request.reply.source = src
        if response.error ~= nil then
            print("Error from remote: "..response.error)
        else
            print("Request = "..dump(request))
        end
        if request.command == 'quit' then
            print("Removing listener")
            retVal = false
        end
    end
    return retVal
end

function waitForResponses(timeout)
    print("Waiting for response to requests.")
    if timeout == nil then timeout = 5 end
    local tries = 0
    while msgQueue:length() > 0 and tries < timeout do
        for i, msgId, request in msgQueue:iteritems() do
            if request.reply ~= nil and request.done == nil then
                -- Flag as being done while the callback is running, so when 
                -- this become an event listener 2 requests shouldn't get called
                -- on the same request.
                request.done = true
                -- should pcall this one later.!!
                if type(request.callback) == "function" then
                    request.callback(request)
                end
                -- And remove the request from the message queue
                msgQueue[msgId] = nil
                -- reset the timeout value whenever something comes back
                tries = 0
            end 
        end
        os.sleep(1)
        tries = tries + 1
    end
end

event.listen("modem_message", listenForResponses)

print("unregistering first, just in case.")
unregister()
print("registering..")
register()
waitForResponses()
if slaveAddr ~= nil then
    print("sending echo")
    sendCommand("echo", "simon", "is", 1)
    print("sending peripheral call")
    sendCommand("peripheral_call", "container_chest_20", "getAllStacks")
    waitForResponses()
    print("sending quit")
    sendCommand("quit")
    waitForResponses()
else
    print("Registration failed, removing listener..")
    event.ignore("modem_message", listenForResponses)
end
