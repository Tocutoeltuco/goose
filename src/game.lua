local Game
do
	--[[@ Represents the game/module.
		@ This is not a class, but an instance. You should not create multiple Game instances.
	]]
	Game = {}
	Game.__index = Game
	setmetatable(Game, Game)

@#IF COROUTINE_SUPPORT
	local yield = coroutine.yield
@#ENDIF
	local time = os.time
	local newGame = tfm.exec.newGame

	local events = {}
	local inEvent = false
	local errorCallbacks = {_count = 0}

	--[[@ Appends a callback to the error handler.
		@ These callbacks are called on any error with the error message as a parameter,
		  with the exception of syntax errors.
		@param callback<function(string)> The callback to append to error handling
	]]
	function Game.onError(callback)
		-- set up an error callback
		errorCallbacks._count = errorCallbacks._count + 1
		errorCallbacks[ errorCallbacks._count ] = callback
	end

	local function handleError(msg)
		-- call onError callbacks
		msg = __errorMessage(msg)

		for i = 1, errorCallbacks._count do
			errorCallbacks[i](msg)
		end
	end

@#IF OVERRIDE_EVENTS | HANDLE_RUNTIME
	--[[@ Returns the table with the registered events. Usage should only be internal.
		@returns table The events table
		@available OVERRIDE_EVENTS | HANDLE_RUNTIME
	]]
	function Game._getEvents()
		-- we share the events to Game modifications
		return events
	end

	--[[@ Triggers the error callbacks. Usage should only be internal.
		@available OVERRIDE_EVENTS | HANDLE_RUNTIME
		@name Game._handleError
		@param msg<string> The error message
	]]
	-- we also share the error handler
	Game._handleError = handleError
@#ENDIF

	--[[@ Sets up a callback to be triggered everytime an event is dispatched.
		@param evt<string> The event name (newPlayer, loop, textAreaCallback, ...)
		@param callback<function(...)> The callback to be triggered.
		@param ?coro<boolean> Whether the callback should be treated as a coroutine or not.
							 Only available when COROUTINE_SUPPORT is true
	]]
	function Game.on(evt, callback, coro)
		-- Register a callback on a specific event

		if not events[evt] then
			-- if the event was never registered, register it
			events[evt] = {
				_name = evt,
				_count = 1,
@#IF COROUTINE_SUPPORT
				[1] = {cb = callback, isCoro = coro}
@#ELSE
				[1] = callback
@#ENDIF
			}
			return

		else
			-- if the event was registered, just append the callback
			evt = events[evt]
			evt._count = evt._count + 1
@#IF COROUTINE_SUPPORT
			evt[ evt._count ] = {cb = callback, isCoro = coro}
@#ELSE
			evt[ evt._count ] = callback
@#ENDIF
		end
	end

	local function callListeners(evt, a1, a2, a3, a4, a5, a6, offset)
		-- call event callbacks/listeners
		for i = offset, evt._count do
			evt[i](a1, a2, a3, a4, a5, a6)
		end
	end

	--[[@ Triggers event callbacks
		@param evtName<string> The event name
		@param ... The event parameters
	]]
	function Game.dispatch(evtName, a1, a2, a3, a4, a5, a6)
		-- Dispatch a specific event with up to 6 arguments
		local evt = events[evtName]
		if not evt then
			-- if the event hasn't been registered, do nothing
			return
		end

		if not inEvent then
			inEvent = true

			-- first event handler call, set up error handler
			local done, result = pcall(callListeners, evt, a1, a2, a3, a4, a5, a6, 1)
			if not done then
				handleError(result)
			end

			inEvent = false
		else
			-- we were already in an event, so error handler is already on
			callListeners(evt, a1, a2, a3, a4, a5, a6, 1)
		end
	end

	local nextMapLoad = 0
	--[[@ Loads a new map in the room. Has a cooldown of 3 seconds.
		@param map<string|int> The map code, xml or perm
		@param ?flipped<boolean> Whether the map should be flipped or not
		@param ?await<boolean> Whether the function should block until the cooldown resets
		@returns boolean Whether the map load has been started or not
	]]
	function Game.loadMap(map, flipped, await)
		-- Load a map
		local now = time()
		local cooldown = nextMapLoad - now

		if cooldown > 0 then
@#IF COROUTINE_SUPPORT
			if await then
				-- Await until the cooldown passes
				if not Game.runningCoroutine then
					error("Awaiting for a timeout must run inside a coroutine event.", 2)
				end

				yield("", false, cooldown)
				-- await set to false to avoid deadlocks
				return Game.loadMap(map, flipped, false)
			end
@#ENDIF
@#IF DEBUG
			print("Attempt to load two maps in " .. cooldown .. "/3000ms.")
@#ENDIF
			return false
		end

		nextMapLoad = now + 3000
		newGame(map, flipped)
		return true
	end

@#IF COROUTINE_SUPPORT
	--[[@ Sets the function to trigger callbacks. Usable should only be internal.
		@param trigger<function> The new function
	]]
	function Game._setListenerTrigger(trigger)
		callListeners = trigger
	end
@#ENDIF
end

return Game