-- Adds coroutine support

local Game = require("src/game")

local time = os.time
local yield = coroutine.yield
local assert = assert
local create = coroutine.create
local resume = coroutine.resume

local waiters = {}
local timeouts = {}
local doneWaiting = {_count = 0}

local function coroutineCall(coro, a1, a2, a3, a4, a5, a6, a7)
	-- one extra argument because it may receive "success" as the first one

	Game.runningCoroutine = true
	local done, r1, r2, r3 = resume(coro, a1, a2, a3, a4, a5, a6, a7)
	Game.runningCoroutine = false
	-- if done is false: r1 is an error message
	-- if done is true:
	-- r1 may be nil or an event name
	-- r2 may be false or a predicate function
	-- r3 may be false or a timeout in ms

	if not done then
		error(__errorMessage(r1))
	end

	if not r1 then
		-- no waiter
		return
	end

	local waiter = {
		event = r1,
		coro = coro,
		pred = r2
	}

	local w = waiters[r1]
	local waiterId
	if not w then
		waiters[r1] = {
			_count = 1,
			_pointer = 1,
			[1] = waiter
		}
		waiterId = 1
	else
		w._count = w._count + 1
		waiterId = w._count
		w[ waiterId ] = waiter
	end
	waiter.id = waiterId

	if r3 then -- timeout
		local timeout = {
			alive = true,
			expire = time() + r3,
			waiter = waiter
		}
		waiter.timeout = timeout

		local list = timeouts[r3]
		if not list then
			timeouts[r3] = {
				_count = 1,
				_pointer = 1,
				[1] = timeout
			}

		else
			list._count = list._count + 1
			list[ list._count ] = timeout
		end
	end
end
Game._coroutineCall = coroutineCall

local function setWaiterResult(waiter, success, a1, a2, a3, a4, a5, a6)
	local list = waiters[ waiter.event ]

	-- remove from list
	if waiter.id == list._count then
		list._count = list._count - 1
	else
		list[ waiter.id ] = nil
	end

	-- set result
	doneWaiting._count = doneWaiting._count + 1
	doneWaiting[ doneWaiting._count ] = {
		coro = waiter.coro, success = success,
		[1] = a1, [2] = a2, [3] = a3, [4] = a4, [5] = a5, [6] = a6
	}

	-- stop timeout (if any)
	if waiter.timeout then
		waiter.timeout.alive = false
	end
end

local function checkWaiters(evtName, a1, a2, a3, a4, a5, a6, justSchedule)
	-- Check if any waiter should run
	local waiterList = waiters[ evtName ]
	if waiterList then
		local pointer, count = waiterList._pointer, waiterList._count

		if pointer <= count then
			-- The list is not empty

			local patchPointers = false
			local waiter
			for i = pointer, count do
				waiter = waiterList[i]
				if waiter and not waiter.pred or waiter.pred(a1, a2, a3, a4, a5, a6) then
					patchPointers = true
					setWaiterResult(waiter, true, a1, a2, a3, a4, a5, a6)
				end
			end

			-- If no waiter has been removed, there's no need to patch the pointers.
			if patchPointers then
				-- Remove first items
				local moved = false
				for i = pointer, count do
					if waiterList[i] then
						waiterList._pointer = i
						moved = true
						break
					end
				end

				if not moved then
					-- The list is empty, we can set the pointers to the first state
					waiterList._count = 0
					waiterList._pointer = 1

				else
					-- Remove last items
					for i = count, pointer, -1 do
						if waiterList[i] then
							waiterList._count = i
							break
						end
					end
				end
			end
		end
	end

	if justSchedule then return end

	local now = time()

	-- Check timeouts
	local timeout
	for _, list in next, timeouts do
		for i = list._pointer, list._count do
			timeout = list[i]

			if now < timeout.expire then
				-- next timeouts must expire later since the list is ordered
				-- no need to even check them!
				break

			else
				-- timeout expired
				list._pointer = i + 1

				if timeout.alive then
					-- if it is alive, the coroutine hasn't been called
					setWaiterResult(timeout.waiter, false)
				end
			end
		end

		if list._pointer > list._count then
			-- quick wipe list to free memory since it's all checked
			list._count = 0
			list._pointer = 1
		end
	end

	local count = doneWaiting._count
	doneWaiting._count = 0

	local waiter
	for i = 1, count do
		waiter = doneWaiting[i]
		coroutineCall(
			waiter.coro, waiter.success,
			waiter[1], waiter[2], waiter[3], waiter[4], waiter[5], waiter[6]
		)
	end
end
Game._checkWaiters = checkWaiters

Game._setListenerTrigger(function(evt, a1, a2, a3, a4, a5, a6, offset)
	local e
	for i = offset, evt._count do
		e = evt[i]
		if e.isCoro then
			coroutineCall(create(e.cb), a1, a2, a3, a4, a5, a6)
		else
			e.cb(a1, a2, a3, a4, a5, a6)
		end
	end

	checkWaiters(evt._name, a1, a2, a3, a4, a5, a6)
end)

Game.runningCoroutine = false
--[[@ Blocks until the given event is fired and a call to pred with the event parameters
	  returns true
	@param evt<string> The event name
	@param ?pred<function(...)> A predicate that is called with the event parameters, if it returns
						   true, then this call to waitFor ends
	@param ?timeout<int> A timeout, in milliseconds.
	@returns boolean If it is false, the timeout passed.
	@returns ... The event parameters
	@available COROUTINE_SUPPORT
]]
function Game.waitFor(evt, pred, timeout)
	if not Game.runningCoroutine then
		error("Awaiting for an event must run inside a coroutine event.", 2)
	end

	yield(evt, pred or false, timeout or false)
end

--[[@ Blocks until the given timeout passes
	@param timeout<int> The timeout, in milliseconds.
	@available COROUTINE_SUPPORT
]]
function Game.waitTimeout(timeout)
	if not Game.runningCoroutine then
		error("Awaiting for a timeout must run inside a coroutine event.", 2)
	end

	yield("", false, timeout)
end