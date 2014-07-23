--[[
 *
 * This is the Client component of a Server-Client Remote Command Execution
 * API used to request information and execute remote commands from OC -> OC
 * and from OC -> CC.
 *
 * Example:
 *
 *      client = Client:new()
 *      client:setup()
 *      client:register()
 *      request = client:newRequest("peripheral_call", "iron_1", "getAllStacks")
 *      local msgId = client:send(request, client.print, client)
 *   --- OR ---
 *      local response = client:send(request)
 *      client:print(response)
 *
--]]

local component = require("component")
local serial = require("serialization")
local dict = require("dict")
local scheduler = require("scheduler")

local Client = {}

-- Load config, if none then run the setupWizard.
function Client:setup()
    self.msgQueue = dict:new{ _msgId=1, }
    -- Generate a random key the will identify our messages.
    math.randomseed(os.time())
    self.clientKey = string.format("%x", math.random(0xF000000000, 0xFFFFFFFFFF))
    self:loadConfig()
    -- Get the modem or link card
    local address = component.get(self.config.modem_address)
    if address == nil then
        error("Failed to find network device.")
    end
    self.modem = component.proxy(address)
    -- The service is used to register with the right server when broadcasting
    -- for the servers address. This way we don't need to store the servers
    -- address as we can register by broadcasting.
    self.service = self.config.service_name
    self.timeout = self.config.timeout
end

-- Request the configuration items from the user
function Client:setupWizard()
    
end

-- Load the current config from file
function Client:loadConfig()
    self.config = {
        -- Port to send requests on and receive response on
        port = 221,
        -- Address of the modem or link card to send requests through
        modem_address = "fde263a8",
        -- Name of the service we are using, this should be the same as the 
        -- server is registered with.
        service_name = "remote_command",
        -- How long to wait for responses
        timeout = 5,
    }
end

-- Save the config to file for the next time we are run
function Client:saveConfig(filename)
    
end

-------------------------------------------------------------------------------
--
-- Register this client for a specific service.
--
function Client:register()
    local request = self:newRequest("register", self.service)
    local response = self:send(request)
    if response ~= nil then
        self.service_address = request.response.source
        if type(request.response.reply) == "table" then
            print("From ".. request.response.source ..": "..request.response.reply[1])
            self.msgQueue:increment("_msgId", request.response.reply[2])
        else
            print("From ".. request.reply.source ..": "..request.reply.reply)
        end
        return true
    else
        return false
    end
end

function Client:unregister()
    
end

-------------------------------------------------------------------------------
--
-- Send a prepared request.
--
-- If the callback is nil then this methods will wait for a response before
-- returning, otherwise the return value is nil and the callback will be called
-- when a response arrives.
--
-- Signature:
--              response = client:send(request)
--              msgId = client:send(request, obj.refresh, obj)
--
-- If a callback is not provided (first form) then the response is returned,
-- unless there was an error in the response in which case nil is returned.
--
function Client:send(request, callback, ...)
    request.id = string.format("%x-%d", self.clientKey, self.msgQueue:increment("_msgId"))
    self.msgQueue[request.id] = request
    if request.target == nil then
        self.modem.broadcast(self.port, serial.serialize(request))
    else
        self.modem.send(request.target, self.port, serial.serialize(request))
    end
    local retVal
    if type(callback) == "function" then
        request.callback = callback
        request.callback_args = {...}
        retVal = request.id
    else
        print("Waiting for registration response..")
        scheduler:waitForEvent(msgId, self.timeout)
        retVal = request.response
    end
    return retVal
end

-------------------------------------------------------------------------------
--
-- Create a new Request, provide the remote command and arguments.
--
-- Signature:
--      
--      req = client:newRequest("peripheral_call", "back", "getEnergyStored")
--
function Client:newRequest(command, ...)
    local request = {
        sent=false,
        source=component.modem.address,
        command=command,
        args={...},
    }
    if self.targetAddr ~= nil then
        request.target = self.targetAddr
    end
    return request
end

-------------------------------------------------------------------------------
--
-- This is the listener, part of the Client that monitors for modem_message
-- events which contain responses to requests sent by this client.
--
-- Signature:
--              scheduler:spawn("clientListener", client.listener, client)
--
-- The callback should be of the form:
--
--              function obj:callback(arg1, request) 
--                  ...
--              end
--
-- Such that:
--
--              request.callback = obj.callback
--              request.callback_args = { obj, "arg1", }
--
-- The callback should have the request being the last arguement and the first
-- can be the obj if using obj:callback instead of a local function.
--
function Client:listener()
    print("Listening for modem_messages containing responses for our Queue.")
    local quit = false
    --
    repeat
        event, dst, src, port, dist, rport, msg = scheduler:waitForEvent("modem_message")
        local message = serial.unserialize(msg)
        -- Make sure we were sent a valid request <-> response
        if type(message) ~= "table" then
            if self.debug then
                print("Invalid modem message: "..msg)
            end
            break
        end
        -- Get the original request from our Queue, the ID will be unique to us
        -- so if it's not on our queue it's probably someone elses.
        local request = self.msgQueue[response.id]
        if request == nil then
            if self.debug then
                print("Not our response ("..response.id.."), ignoring.")
            end
        -- We seem to get multiple events triggered from the one message so if
        -- we already have a response logged then ignore the request as a dup
        elseif request.response ~= nil then
            if self.debug then
                print("Got a reply already, dropping.")
            end
        -- It is ours.
        else
            request.response = response
            -- Store the source from the event since the CC server version can't
            -- get the address of the adapter, this way the register command can
            -- store the real source of the server.
            request.response.source = src
            if response.error ~= nil then
                print("Error from remote: "..response.error)
            elseif self.debug then
                print("Request = "..dump(request))
            end
            -- Now, client:send() adds a callback to handle the response while
            -- client:sendAndWait() sits waiting for a wakeup call from here.
            if request.callback ~= nil then
                local args = table.copy(request.callback_args)
                table.insert(args, request)
                local status, errOrOutput = pcall(request.callback, table.unpack(args))
                if not status then
                    print("[E]: Callback failed: "..errOrOutput)
                end
            else
                scheduler:pushSignal(request.id)
            end
        end
    until quit == true
end

function Client:print(message)
    print("Message = "..dump(message))
end

return Client
