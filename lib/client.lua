--[[
 *
 * This is the Client component of a Server-Client Remote Command Execution
 * API used to request information and execute remote commands from OC -> OC
 * and from OC -> CC.
 *
 * Example:
 *
 *      client = Client:new(name)
 *      client:setup()
 *      client:register()
 *      request = client:newRequest("peripheral_call", "iron_1", "getAllStacks")
 *      local msgId = client:send(request, callback, ...)
 *   --- OR ---
 *      local response = client:sendAndWait(request)
 *
--]]

local component = require("component")
local serial = require("serialization")
local dict = require("dict")

local Client = {}

-- Load config, if none then run the setupWizard.
function Client:setup()
    self.msgQueue = dict:new{ _msgId=1, }
    -- Generate a random key the will identify our messages.
    math.randomseed(os.time())
    self.clientKey = string.format("%x", math.random(1000000000, 9999999999999))
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
        modem_address = "",
        -- Name of the service we are using, this should be the same as the 
        -- server is registered with.
        service_name = "",
    }
end

-- Save the config to file for the next time we are run
function Client:saveConfig(filename)
    
end

function Client:register()
    local request = self:newRequest("register", self.service)
    self:sendAndWait(request)
    self.service_address = request.response.source
    if type(request.response.reply) == "table" then
        print("From ".. request.response.source ..": "..request.response.reply[1])
        self.msgQueue:increment("_msgId", request.response.reply[2])
    else
        print("From ".. request.reply.source ..": "..request.reply.reply)
    end
end

function Client:unregister()
    
end

-- Send a request but don't wait for a response
function Client:send(request)
    request.id = string.format("%x-%d", self.clientKey, self.msgQueue:increment("_msgId"))
    self.msgQueue[request.id] = request
    if request.target == nil then
        self.modem.broadcast(self.port, serial.serialize(request))
    else
        self.modem.send(request.target, self.port, serial.serialize(request))
    end
    return request.id
end

function Client:sendAndWait(request)
    self:send(request)
    self:wait(request.id)
end

function Client:wait(msgId)
    
end

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

function Client:addListener()
    local queue = self.msgQueue
    local debug = self.debug
    
    local function listenForResponses(event, dst, src, port, dist, rport, msg)
        local retVal = true
        local message = serial.unserialize(msg)
        -- Make sure we were sent a valid request <-> response
        if type(message) ~= "table" then
            if debug then
                print("Invalid modem message: "..msg)
            end
            return
        end
        -- Get the original request from our Queue, the ID will be unique to us
        -- so if it's not on our queue it's probably someone elses.
        local request = queue[response.id]
        if request == nil then
            if debug then
                print("Not our response ("..response.id.."), ignoring.")
            end
        -- We seem to get multiple events triggered from the one message so if
        -- we already have a response logged then ignore the request as a dup
        elseif request.response ~= nil then
            if debug then
                print("Got a reply already, dropping.")
            end
        else
            request.response = response
            -- Store the source from the event since the CC server version can't
            -- get the address of the adapter, this way the register command can
            -- store the real source of the server.
            request.response.source = src
            if response.error ~= nil then
                print("Error from remote: "..response.error)
            else
                print("Request = "..dump(request))
            end
        end
        return retVal
    end
    
    event.listen("modem_message", listenForResponses)
    return listenForResponses
end
