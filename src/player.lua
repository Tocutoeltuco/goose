local Game = require("src/game")

local Player
do
@#IF COROUTINE_SUPPORT
	local yield = coroutine.yield
@#ENDIF
	local loadPlayerData = system.loadPlayerData
	local error = error
	local chatMessage = tfm.exec.chatMessage
	local room = tfm.get.room

	local to_destroy = false
	local players = {}
	local destroying = {}

	--[[@ Represents a player
		@attribute isPartial<boolean> Whether full data of the player is available or not
		@attribute isDestroying<boolean> Whether the player is being destroyed or not
		@attribute name<string> The player's name
		@attribute ?id<int> The player's ID
		@attribute ?community<string> The player's community
		@attribute ?extra<table> Data from tfm.get.room.playerList about this player
	]]
	Player = {}
	Player.__index = Player

	--[[@ Returns a player only if it has been created
		@param name<string> The player's name
		@returns Player The player. May be nil.
	]]
	function Player.load(name)
		-- Get a player
		local dest = destroying[name]
		if dest then
			if os.time() < dest._destroyDate then
				-- The player isn't fully destroyed yet.
				return dest
			end

			-- The player should be destroyed by now.
			destroying[name] = nil
		end

		return players[name]
	end

	--[[@ Partially creates a player
		@param name<string> The player's name
		@returns Player The created player
	]]
	function Player.partial(name)
		-- Create a partial player
		local player = players[name]
		if player then
			error("Trying to recreate a player", 2)
		end

		destroying[name] = nil -- delete old player if needed

		player = setmetatable({
			isPartial = true,

			name = name,

@#IF OVERRIDE_EVENTS
			_scheduledCount = 0,
			_scheduled = nil,
@#ENDIF

			_cache = {}
		}, Player)
		players[name] = player
		return player
	end

@#IF OVERRIDE_EVENTS
	--[[@ Schedule an event for when the player is fully loaded. Usage should be internal.
		@param evt<string> The event name
		@param ... The event parameters
		@available OVERRIDE_EVENTS
	]]
	function Player:schedule(evt, a2, a3, a4, a5, a6)
		-- a1 is skipped because it will be the Player instance

		if not self._scheduled then
			self._scheduled = {}
		end

		self._scheduledCount = self._scheduledCount + 1
		self._scheduled[self._scheduledCount] = {evt, a2, a3, a4, a5, a6}
	end
@#ENDIF

	--[[@ Creates a player or fully loads it if possible. May return a partial player.
		@ Note that this method dispatches the newPlayer event and any subsequent
		  scheduled event if the player fully loads.
		@param name<string> The player's name
		@returns Player The player.
	]]
	function Player.new(name)
		-- Create a player, partially if needed
		local player = players[name]

		if player then
			-- Player already exists
			if player.isPartial then
				player:loadInfo()
				return player
			end
			error("Trying to recreate a player", 2)
		end

		-- Gather information
		local info = room.playerList[name]
		if not info then
@#IF DEBUG
			print("Partial player creation for", name, ": lack of information")
@#ENDIF
			return Player.partial(name)
		end

		-- Create object
		destroying[name] = nil -- delete old player if needed

		player = setmetatable({
			isPartial = false,

			name = name,
			id = info.id,
			community = info.community,

			extra = info,

			_cache = {}
		}, Player)
		players[name] = player
@#IF OVERRIDE_EVENTS
		Game.dispatch("newPlayer", player)
@#ENDIF
		return player
	end

	--[[@ Fully loads a player if it was partially loaded.
		@ Note that this method dispatches the newPlayer event and any subsequent
		  scheduled event if the player fully loads.
		@returns boolean Whether the player could be fully loaded or not.
	]]
	function Player:loadInfo()
		-- If the player is partially loaded, we fully load it
		if not self.isPartial then
			error("Attempt to call Player:loadInfo on a fully loaded player", 2)
		end

		local info = room.playerList[self.name]
		if not info then
			return false
		end

		self.isPartial = false
		self.id = info.id
		self.community = info.community
		self.extra = info

@#IF OVERRIDE_EVENTS
		Game.dispatch("newPlayer", self)

		-- Run scheduled events, if any
		local evt
		for i = 1, self._scheduledCount do
			evt = self._scheduled[i]
			Game.dispatch(evt[1], self, evt[2], evt[3], evt[4], evt[5], evt[6])
		end
		self._scheduled = nil -- free memory
@#ENDIF

		return true
	end

	--[[@ Updates extra information of the player if possible, or fully loads the player if
		  it was partially loaded.
		@ Note that this method dispatches the newPlayer event and any subsequent
		  scheduled event if the player fully loads.
		@returns boolean Whether extra information could be updated or not
	]]
	function Player:update()
		-- Update extra data
		if self.isPartial then
			return self:loadInfo()
		end

		self.extra = room.playerList[self.name]
		return true
	end

	--[[@ Fetch this player's file (wrapper for system.loadPlayerData)
		@ If COROUTINE_SUPPORT is set to true, you can await until the data gets loaded or
		  a timeout passes.
		@param ?await<boolean> Whether or not to await for player data
		@param ?timeout<int> Timeout for the request, in milliseconds
		@returns boolean Whether awaiting has been successful or not
		@returns string The player's data, if you awaited for it and the first return value
						is true.
	]]
	function Player:fetchData(await, timeout)
		loadPlayerData(self.name)
@#IF COROUTINE_SUPPORT
		if await then
			if not Game.runningCoroutine then
				error("Awaiting for an event must run inside a coroutine event.", 2)
			end

			-- If the function already exists, there's no need to recreate it
			local predicate = self._cache.loadDataPredicate
			if not predicate then
				predicate = function(player)
					return player.name == self.name
				end
				self._cache.loadDataPredicate = predicate
			end

			local done, _, data = yield("playerDataLoaded", predicate, timeout or false)
			return done, data
		end
@#ENDIF
	end

	--[[@ Send a chat message to this player
		@param msg<string> The message
	]]
	function Player:chatMessage(msg)
		chatMessage(msg, self.name)
	end

	--[[@ Destroys the player.
		@ Destruction is only scheduled, and it will happen at least 250ms later.
	]]
	function Player:destroy()
		-- Destroy object
		-- This method should be manually triggered if it is needed.
		-- Preferably inside eventPlayerLeft.

		players[self.name] = nil
		destroying[self.name] = self

		-- Sometimes, transformice calls events in a weird manner
		-- If an event about this player is called after eventPlayerLeft,
		-- it should be discarded
		to_destroy = true
		self.isDestroying = true
		self._destroyDate = os.time() + 250
	end

	Game.on("loop", function()
		if to_destroy then -- Only execute when a player gets destroyed.
			local dest, count, total = {}, 0, 0

			local now = os.time()
			for name, player in next, destroying do
				total = total + 1

				if now >= player._destroyDate then
					count = count + 1
					dest[count] = name
				end
			end

			for i = 1, count do
				destroying[ dest[i] ] = nil
			end

			if total == count then
				-- If all players have been destroyed, disable this mechanism.
				to_destroy = false
			end
		end
	end)
end

return Player