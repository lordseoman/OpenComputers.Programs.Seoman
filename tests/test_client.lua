--[[
 *
 * Test the client <--> server API library
 *
 *
--]]

-- Remove the cached packages so any changes come through.
package.loaded.functions = nil
package.loaded.scheduler = nil
package.loaded.client = nil

local func = require("functions")
local Scheduler = require("scheduler")
local Client = require("client")
local LuaUnit = require("luaunit")

local MyClient = func.inheritsFrom(Client)
local myscheduler = Scheduler:new{}
local TestClient = {}

function TestClient:test_1_setup()
    print("Setting up client.")
    self.c = MyClient:new()
    self.c:setup()
    print("Starting the listener..")
    myscheduler:spawn("test_listener", self.c.listener, self.c)
    -- Allow the listener to start up
    myscheduler:wait(0.5)
end

function TestClient:test_2_register()
    print("Registration test..")    
    assertEquals(self.c:register(), true)
end

function TestClient:test_3_echo()
    print("Echo with wait test..")
    local msg = { barnie=1, [5]="suni",}
    local req = self.c:newRequest("echo", msg)
    local res = self.c:send(req)
    assertEquals(res.id, req.id)
    assertEquals(req.target, res.source)
    assertEquals(res.reply, msg)
end
    
function TestClient:test_99_shutdown()
    myscheduler:kill("test_listener")
end
myscheduler:spawn("testrunner", LuaUnit.run, LuaUnit, TestClient)
myscheduler:run()
