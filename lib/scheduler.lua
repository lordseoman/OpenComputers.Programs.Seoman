--[[
 *
 * This package provides a threading library using the concept of spawning
 * separate processes while allowing those processes to maintain a state.
 * This allows you to have muliple threads all manipulating or using the 
 * same class; such as a UI that reacts to multiple forms of input.
 *
 * The user is responsible for any locking requirements.
 *
 * When using this library, scheduler:suspend() and scheduler:wait() must be
 * used in place of os.sleep() or other timer operations.
 *
--]]

require("functions")
local keyboard = require("keyboard")
local computer = require("computer")

local Scheduler = {
    name="scheduler",
    version="0.9",
    debug=false,
}

function Scheduler:new(functions)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    -- Add each function to the table
    o.threads = {}
    for k, v in pairs(functions) do
        o.threads[k] = o:_wrapFunction(v)
    end
    return o
end

-------------------------------------------------------------------------------
--
-- Spawn a new worker by adding it to the workers that will be scheduled.
--
-- Signature:
--             scheduler:spawn(name, function, args...)
--             scheduler:spawn(function, args...)
--
-- Args:
--      `function` is the routine to be called. 
--          eg. recipe.getIngredients
--      `args` are the arguments to pass the routine. 
--          eg. self, 5
--
-- Examples:
--          scheduler:spawn(self.getIngredients, self, 5)
--
function Scheduler:spawn(...)
    local args = {...}
    local name, func, ob
    -- if the first argument is a function then create a name
    if type(args[1]) == "function" then
        repeat
            name = string.format("thread-%d", math.random(1, 0xFF))
        until self.threads[name] == nil
    else
        name = table.remove(args, 1)
        if self:isAlive(name) then
            error("a thread exists with this name: " .. name)
        end
    end
    func = table.remove(args, 1)
    ob = table.remove(args, 1)
    -- Adding an entry to a table while it's being iterated over
    -- causes undefined behavior, so we work on a copy of the table
    -- instead.
    -- See <http://www.lua.org/manual/5.1/manual.html#pdf-next>
    local threads = table.copy(self.threads)
    threads[name] = {
        state="new",
        filters={},
        co=self:_wrapFunction(func),
        ob=ob,
        args=args,
    }
    self.threads = threads
end

function Scheduler:_wrapFunction(func)
    return coroutine.create(function(action, ob, ...)
        local args = {...}
        -- Allow the routine to start suspended
        if action == "suspend" then
            args = self:suspend()
        end
        while 1 do
            local status, err = pcall(func, ob, table.unpack(args)) 
            if not status then
                if err == "terminate" then
--                  print("Been told to terminate.")
                    ob:shutdown()
                    break
                elseif err == "suspend" then
--                  print("Been told to suspend all activity.")
                    ob:shutdown()
                    args = self:suspend()
                else
                    if ob.handleError ~= nil then
                        ob:handleError(err)
                    else
                        self:handleError(err)
                    end
                end
            else
                print("sub-routine exited normally.")
                break
            end
        end
    end)
end

-------------------------------------------------------------------------------
--
-- This is an error handler for displaying or logging errors from the scheduler
-- due to unhandled events or such. This is the fallback handler, you should
-- create a MyOb:handleError(errmsg) on you object that correctly logs or shows
-- errors fromt the scheduler.
--
function Scheduler:handleError(errMsg)
    print("E: "..errMsg)
end

-------------------------------------------------------------------------------
--
-- Check if a thread is alive, used when adding a new thread of the same name,
-- will return false for threads that don't exist but a name of nil is true.
--
-- Signature:
--             scheduler:isAlive(name)
--
function Scheduler:isAlive(name)
    local state = self:getState(name)
    if state == "non-existant" or state == "dead" then
        return false
    else
        return true
    end
end

-------------------------------------------------------------------------------
--
-- Get the current state of a thread, includes 'non-existant' if no thread of
-- that name exists and an automatic "running" is name == nil
--
-- Signature:
--             scheduler:getState(name)
--
function Scheduler:getState(name)
    if name == nil then
        print("** Nonsense call to getState() **")
        return "running"
    elseif self.threads[name] == nil then
        return "non-existant"
    elseif self.threads[name].state == "dead" then
        return "dead"
    elseif coroutine.status(self.threads[name].co) == "dead" then
        self.threads[name].state = "dead"
        return "dead"
    else
        return self.threads[name].state
    end
end

-------------------------------------------------------------------------------
--
-- Return the number of threads that are not dead, this will include suspended
-- and the like, so threads that are not "active" as this time.
--
-- Signature:
--             scheduler:count()
--
function Scheduler:count()
    local num = 0
    for _, thread in pairs(self.threads) do
        if thread.state ~= "dead" then
            num = num + 1
        end
    end
    return num
end

-------------------------------------------------------------------------------
--
-- Terminate this thread or a named thread.
--
-- Signature:
--             scheduler:kill()
--             scheduler:kill(thread_name)
--
function Scheduler:kill(name)
    if name == nil then
        for _, thread in pairs(self.threads) do
            if thread.state ~= "dead" then
                thread.state = "terminate"
            end
        end
    elseif self:isAlive(name) then
        self.threads[name].state = "terminate"
    else
        print("unknown thread: "..name)
    end
    -- Trigger a wait to push through a signal.
    self:wait(1)
end

-------------------------------------------------------------------------------
--
-- Pause the current thread for a number of milliseconds, use instead of
-- os.sleep() or using the timer event directly.
--
-- Signature:
--             scheduler:wait(number of milliseconds to wait)
--
function Scheduler:wait(timeout)
    local ret = {coroutine.yield("wait", timeout)}
    local message = table.remove(ret, 1)
    if message == "go" then
        return table.unpack(ret)
    end
    error(message, 0)
end

-------------------------------------------------------------------------------
--
-- Pause the current thread until a given event type is seen or until timeout
-- seconds have passed, whichever comes first.
--
-- Signature:
--             scheduler:waitForEvent("redstone", 10)
--
function Scheduler:waitForEvent(...)
    local ret = {coroutine.yield("waitForEvent", ...)}
    local message = table.remove(ret, 1)
    if message == "go" then
        return unpack(ret)
    end
    error(message, 0)
end

-------------------------------------------------------------------------------
--
-- Stop the current thread until another event resumes it, this is like wait
-- but useful where the thread is no longer needed until another thread wakes
-- it up. Lets say a thread is used to run a given set of engines, instead of
-- creating and destroying the thread to turn them on and off, you can suspend
-- and resume it.
-- 
-- Note that this will tell the thread it needs to suspend upon the next tick
-- instead of never running the thread again, this allows the thread to perform
-- any suspension actions.
--
-- Signature:
--             scheduler:suspend()      - Suspend the current thread
--             scheduler:suspend(name)  - Suspend a named thread
--
function Scheduler:suspend(name)
    if name ~= nil then
        local thread = self.threads[name]
        if thread ~= nil then
            thread.state = "suspending"
        else
            print("failed to find thread: " .. name)
        end
    else
        local ret = { coroutine.yield("suspend") }
        local message = table.remove(ret, 1)
        if message == "go" then
            return table.unpack(ret)
        end
        error(message, 0)
    end
end

-------------------------------------------------------------------------------
--
-- Resume a given suspended thread by name.
--
-- Signature:
--             scheduler:resume(name, args, ...)
--
-- There is no need to pass the object that the sub-routine is existing on
-- here, just the initial arguments for the routine.
--
function Scheduler:resume(name, ...)
    local args = {...}
    local x = 0
    local state = self:getState(name)
    -- If the thread isn't suspended already (tick may not have changed from
    -- suspending to suspend) then wait 20 for it to finish.
    --
    -- XXX: maybe the wait time should be configurable on the class.
    while x < 100 and state and state ~= "suspend"  do
        self:wait(0.2)
        x = x + 1
        state = self:getState(name)
    end
    if state and state == "suspend" then    
        self.threads[name].state = "resume"
        self.threads[name].args = args
    else
        print("Attempted to resume thread not suspended: "..state)
    end
end

-------------------------------------------------------------------------------
--
-- As there is no "Terminate" signal we need to see if a particular key
-- combination is being held down. Holding the keys down will trigger a key_down
-- signal which will trigger this to see if the combination is a termination
-- event. 
--
-- Overide this to eliminate/control the termination comb or event only allow
-- certain users the ability to terminate your programs.
--
function Scheduler:isShutdownCode(event)
    return keyboard.isControlDown() and keyboard.isAltDown() and keyboard.isKeyDown(keyboard.keys.c)
end

function Scheduler:pullSignal(timeout)
    if timeout == nil then timeout = 0 end
    return computer.pullSignal(timeout)
end

function Scheduler:pushSignal(...)
    local args = {...}
    if type(args[1]) ~= "string" then
        error("First argument to pushSignal must be string.")
    end
    computer.pushSignal(table.unpack(args))
end

-------------------------------------------------------------------------------
--
-- The main scheduler runner, should be incorporated into your main thread.
-- 
-- This is an example runner that runs a number of processes while monitoring
-- the event queue. Your sub-routines get resumed based on the events they are
-- looking for or if wait() has been called when that timer expires.
--
-- In most cases this runer will be enough, you should ideally spawn all your
-- threads and then call the runner:
--
--          scheduler:spawn("ui_listener", uiListener)
--          scheduler:spawn("messageQueue", listenForMessages)
--          scheduler:run()
--
-- The limit says that if the number of running threads hits limit or falls 
-- below limit then exit.
--
function Scheduler:run(limit)
    if limit == nil then
        limit = 0
    elseif limit < 0 then
        limit = limit + self:count()
    end
    --
    -- Run the event loop while there are enough sub-routines alive
    --
    local params
    local timeout = 0.2
    while self:count() > limit do
        if timeout == nil then timeout = 0.2 end
        -- Use raw events so we capture the "terminate" and tell the threads
        -- to shutdown
        params = { self:pullSignal(timeout) }
        -- don't pass our timer through to the sub-routines
        if params[1] == nil then
            timeout = self:feed(nil)
        -- everything else is passed through
        else
            timeout = self:feed(table.unpack(params))
        end
        -- If we got a shutdown code, then tell all threads to terminate and
        -- break out of the loop
        if self:isShutdownCode() then
            print("Shutdown code received..")
            timeout = self:feed("terminate")
            break
        end
    end
    --
    -- Send another terminate just in case
    print("Closing down any remaining threads.")
    self:feed("terminate")
end
--
-- Feed an event to each of the sub-routines, we check the event filter
-- for each thread to see if it wants that event type.
--
function Scheduler:feed(...)
    local evData = {...}
    local evType = evData[1]
    local shortest_wait_time
    
    for thread_name, thread in pairs(self.threads) do
        local time = computer.uptime()
        local ret
        --
        -- Firstly check if the thread should be kicked off, we send the terminate
        -- event to all threads.
        --
        if thread.state ~= "dead" and evType == "terminate" then
            thread.state = "running"
            ret = {coroutine.resume(thread.co, table.unpack(evData))}
        end
        if thread.state == "suspending" then
            thread.state = "running"
            ret = {coroutine.resume(thread.co, "suspend", thread.ob)}
            thread.args = {}
        end
        if thread.state == "terminate" then
            thread.state = "running"
            ret = {coroutine.resume(thread.co, "terminate", thread.ob)}
            thread.args = {}
        end
        if thread.resume_time ~= nil then
            local timeout = thread.resume_time - time
            if timeout <= 0 then
                thread.resume_time = nil
                thread.state = "running"
                ret = {coroutine.resume(thread.co, "go", "resume")}
                thread.args = {}
                thread.suspend_time = nil
                thread.filters = {}
            elseif shortest_wait_time == nil or timeout < shortest_wait_time then
                shortest_wait_time = timeout
            end                
        end
        if thread.state == "new" then
            thread.state = "running"
            ret = {coroutine.resume(thread.co, "go", thread.ob, table.unpack(thread.args))}
            thread.args = {}
        end
        if thread.state == "resume" then
            thread.state = "running"
            ret = {coroutine.resume(thread.co, "go", table.unpack(thread.args))}
            thread.args = {}
        end
        if thread.state == "waitForEvent" then
            for j=1, #thread.filters do
                if thread.filters[j] == evType then
                    thread.state = "running"
                    ret = {coroutine.resume(thread.co, "go", table.unpack(evData))}
                    thread.filters = {}
                    thread.resume_time = nil
                    thread.suspend_time = nil
                    break
                end
            end
        end
        --
        -- Now process the return from the sub-process
        --
        time = computer.uptime()
        if ret then
            local okay = table.remove(ret, 1)
            if okay then
                local action = table.remove(ret, 1)
                local status = coroutine.status(thread.co)
                if status == "dead" then
                    thread.state = "dead"
                elseif action == "suspend" then
                    thread.state = "suspend"
                    thread.suspend_time = time
                elseif action == "wait" then
                    local timeout = tonumber(ret[1])
                    if timeout == nil then
                        print("["..thread_name.."]: invalid timeout: " .. ret[1])
                        thread.state = "suspending"
                    else
                        thread.suspend_time = time
                        thread.resume_time = thread.suspend_time + timeout
                        thread.state = "wait"
                        if shortest_wait_time == nil or timeout < shortest_wait_time then
                            shortest_wait_time = timeout
                        end
                    end
                elseif action == "waitForEvent" then
                    -- Remove the last argument, MUST be a timeout value
                    local timeout = tonumber(table.remove(ret))
                    if timeout == nil then
                        print("["..thread_name.."]: invalid timeout: " .. ret[1])
                        thread.state = "suspending"
                    else
                        thread.suspend_time = time
                        if timeout > 0 then
                            thread.resume_time = thread.suspend_time + timeout
                            if shortest_wait_time == nil or timeout < shortest_wait_time then
                                shortest_wait_time = timeout
                            end
                        end
                        thread.state = "waitForEvent"
                        for _, waitOnType in pairs(ret) do
                            table.insert(thread.filters, 1, waitOnType)
                        end
                    end
                    
                end
            elseif thread.state ~= "dead" then
                print(thread_name .. " has terminated.")
                thread.state = "dead"
            end
        end
    end
    --
    -- Return how long the main loop needs to wait before resuming any 
    -- thread, unless an event occurs, of course
    --
    return shortest_wait_time
end

return Scheduler

