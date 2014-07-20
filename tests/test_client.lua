--[[
 *
 * Test the client <--> server API library
 *
 *
--]]

-- Remove the cached packages so any changes come through.
package.loaded.functions = nil
package.loaded.scheduler = nil
package.loaded.client = nill

local func = require("functions")
local Scheduler = require("scheduler")
local Client = require("client")
local LuaUnit = require("luaunit")

local MyClient = func.inheritsFrom(Client)
local scheduler = Scheduler:new{}
local TestClient = {}

function TestClient:setup()
    print("Called setup.")
    self.c = MyClient:new()
    self.c:setup()
    print("Starting the listener..")
    scheduler:spawn("test_listener", self.c.listener, self.c)
end

function TestClient:tearDown()
    print("Called tearDown.")
    scheduler:kill()
end

function TestClient:test_1_register()
    print("Registration test..")    
    assertEquals(self.c:register(), true)
end

function TestClient:test_2_echo()
    print("Echo with wait test..")
    local msg = { barnie=1, [5]="suni",}
    local req = self.c:newRequest("echo", msg)
    local res = self.c:send(req)
    assertEquals(res.id, req.id)
    assertEquals(req.target, res.source)
    assertEquals(res.reply, msg)
end

LuaUnit:run(TestClient)
