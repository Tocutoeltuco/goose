-- Adds a runtime handler for the events

local config = require("config")

local Game = require("src/game")
local events = Game._getEvents()
local handleError = Game._handleError

local time = os.time
local floor = math.floor

local cycleDuration = config.cycleDuration or 4100
local runtimeLimit = config.runtimeLimit or 30
local dontSchedule = config.dontSchedule or {["loop"] = true}

local inEvent = false
local initializingModule = true
local pausedCycles = 0
local cycleId = 0
local usedRuntime = 0
local stoppingAt = 0
local paused = false
local scheduled = {_count = 0, _pointer = 1}

@#IF COROUTINE_SUPPORT
local create = coroutine.create
local coroutineCall = Game._coroutineCall
local checkWaiters = Game._checkWaiters
@#ENDIF

local function callListeners(evt, a1, a2, a3, a4, a5, a6, offset)
	-- call event callbacks/listeners
	if initializingModule then
		-- when initializing we don't care about runtime at all
@#IF COROUTINE_SUPPORT
		local e
		for i = offset, evt._count do
			e = evt[i]
			if e.isCoro then
				coroutineCall(create(e.cb), a1, a2, a3, a4, a5, a6)
			else
				e.cb(a1, a2, a3, a4, a5, a6)
			end
		end

		checkWaiters()
@#ELSE
		for i = offset, evt._count do
			evt[i](a1, a2, a3, a4, a5, a6)
		end
@#ENDIF
		return
	end

@#IF COROUTINE_SUPPORT
	local e
	for i = offset, evt._count do
		e = evt[i]
		if e.isCoro then
			coroutineCall(create(e.cb), a1, a2, a3, a4, a5, a6)
		else
			e.cb(a1, a2, a3, a4, a5, a6)
		end
@#ELSE
	for i = offset, evt._count do
		evt[i](a1, a2, a3, a4, a5, a6)
@#ENDIF

		if time() >= stoppingAt then
			-- runtime exceeded, pausing events

			if i < evt._count then
				-- the event didn't finish executing, resuming later
				scheduled._count = scheduled._count + 1
				scheduled[ scheduled._count ] = {evt, a1, a2, a3, a4, a5, a6, i + 1}
			end

			paused = true
			pausedCycles = pausedCycles + 1
			cycleId = cycleId + 1
			break
		end
	end

@#IF COROUTINE_SUPPORT
	checkWaiters(evt._name, a1, a2, a3, a4, a5, a6, paused)
@#ENDIF
end

local function resume()
	paused = false
	local count = scheduled._count

	local evt
	for i = scheduled._pointer, count do
		evt = scheduled[i]
		callListeners(
			evt[1], -- callbacks
			evt[2], evt[3], evt[4], evt[5], evt[6], evt[7], -- args
			evt[8] -- offset
		)

		if paused then
			if pausedCycles > 3 then
				error("4 attempts have been done to resume the module. Deadlock?")
@#IF DEBUG
			else
				print("Attempt " .. pausedCycles .. " to resume has failed.")
@#ENDIF
			end

			-- the module exceeded runtime again
			if scheduled._count > count then
				-- new event(s) have been scheduled
				-- the last scheduled event may be this one
				local last = scheduled[ scheduled._count ]

				if last[1] == evt[1] then
					-- it is this event, execute it first
					evt[8] = last[8] -- set execution offset
					scheduled._pointer = i -- start from here
					scheduled._count = scheduled._count - 1 -- delete last item
					return
				end
			end
			-- this event has successfully ended, attempt to resume from next event
			scheduled._pointer = i + 1
		end
	end

	pausedCycles = 0
end

function Game.dispatch(evtName, a1, a2, a3, a4, a5, a6)
	-- Dispatch a specific event with up to 6 arguments
	local evt = events[evtName]
	if not evt then
		-- if the event hasn't been registered, do nothing
		return
	end

	local start = time()
	local wasInEvent = inEvent
	if not inEvent then
		-- entering the event, no error handler
		inEvent = true

		if initializingModule then
			-- if we are initializing, we have 4000ms of runtime. we just ignore the usage.
			-- plus, there is already an error handler
			callListeners(evt, a1, a2, a3, a4, a5, a6, 1)
			inEvent = false
			return
		end

		local thisCycle = floor(start / cycleDuration)

		if thisCycle > cycleId then
			-- new cycle: runtime reset
			cycleId = thisCycle
			usedRuntime = 0
			stoppingAt = start + runtimeLimit

			if paused then
				-- this was paused, resuming
				local done, result = pcall(resume)
				if not done then
					handleError(result)
					inEvent = false
					return
				end
			end

		else
			-- no new cycle: continue normally
			stoppingAt = start + runtimeLimit - usedRuntime
		end

	elseif initializingModule then
		return callListeners(evt, a1, a2, a3, a4, a5, a6, 1)
	end

	if paused then
		-- the event is not meant to run yet
		if not dontSchedule[evtName] then
			scheduled._count = scheduled._count + 1
			scheduled[ scheduled._count ] = {evt, a1, a2, a3, a4, a5, a6, 1}
		end

		if not wasInEvent then
			-- tear down event handler
			inEvent = false
			usedRuntime = usedRuntime + time() - start
		end
		return
	end

	if wasInEvent then
		-- we were already in an event, so error handler is already on
		callListeners(evt, a1, a2, a3, a4, a5, a6, 1)

	else
		-- first event call, turn on error handler and measure runtime usage
		local done, result = pcall(callListeners, evt, a1, a2, a3, a4, a5, a6, 1)
		if not done then
			handleError(result)
		end

		inEvent = false
		usedRuntime = usedRuntime + time() - start
	end
end

--[[@ Signals the initialization of the module has ended and starts handling runtime.
	@available HANDLE_RUNTIME
]]
function Game.stopInitialization()
	initializingModule = false
end