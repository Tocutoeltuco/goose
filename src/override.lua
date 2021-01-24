-- Override TFM events for the API

local Game = require("src/game")
local Player = require("src/player")

local sub = string.sub
local upper = string.upper
local dispatch = Game.dispatch

local playerEvents = {
	-- Events with a player as the first argument
	-- 1 arg
	["newPlayer"] = true, -- (player)
	["playerDied"] = true, -- (player)
	["playerGetCheese"] = true, -- (player)
	["playerLeft"] = true, -- (player)
	["playerRespawn"] = true, -- (player)
	["summoningCancel"] = true, -- (player)

	-- 2 args
	["chatCommand"] = true, -- (player, cmd)
	["chatMessage"] = true, -- (player, msg)
	["playerBonusGrabbed"] = true, -- (player, bonusId)
	["playerDataLoaded"] = true, -- (player, data)
	["playerVampire"] = true, -- (player, vampire)
	["playerWon"] = true, -- (player, elapsed)

	-- 3 args
	["mouse"] = true, -- (player, x, y)
	["playerMeep"] = true, -- (player, x, y)
	["emotePlayed"] = true, -- (player, emoteId, emoteParam)

	-- 5 args
	["keyboard"] = true, -- (player, k, d, x, y)
	["summoningStart"] = true, -- (player, objType, x, y, angle)

	-- 6 args
	["summoningEnd"] = true, -- (player, objType, x, y, angle, obj)
}
local idEvents = {
	-- Events with a player as the second argument
	-- 3 args
	["colorPicked"] = true, -- (id, player, color)
	["popupAnswer"] = true, -- (id, player, answer)
	["textAreaCallback"] = true, -- (id, player, callback)
}
local internalEvents = {
	-- Events that do not involve players
	-- 0 args
	["newGame"] = true, -- ()

	-- 1 arg
	["fileSaved"] = true, -- (fileId)

	-- 2 args
	["fileLoaded"] = true, -- (fileId, data)
	["loop"] = true, -- (elapsed, remaining)
}
local customSetup = {
	["newPlayer"] = function()
		-- Most of the logic is handled by Player.new, but sometimes we have the player already created.
		-- That case may be due to something inside the script we're running.
		return function(name)
			local player = Player.load(name)

			if not player then
				-- Player doesn't exist, so .new will handle all the logic.
				return Player.new(name)
			elseif player.isPartial then
				-- If we aren't successful at loading player info, we don't need to do anything.
				-- Extra logic will be handled by future events.
				if not player:loadInfo() then
					return
				end
			end

			return dispatch("newPlayer", player)
		end
	end,
	["playerDataLoaded"] = function()
		-- This event can be called even if the player is not in the room, so we have to add an edge case for it.
		return function(name, data)
			-- All we need is just a Player instance. Doesn't matter if it is partial or not.
			local player = Player.load(name)

			if not player then
				player = Player.new(name)
			end

			return dispatch("playerDataLoaded", player, data)
		end
	end,
}

local setup = {}

local function setupEvent(evt)
	-- Set up global variables for tfm to call events
	local method = "event" .. upper(sub(evt, 1, 1)) .. sub(evt, 2)
	setup[evt] = true

	if customSetup[evt] then
		-- The event has a custom setup, run it instead.
		_G[method] = customSetup[evt]()

	elseif internalEvents[evt] then
		-- Internal event: directly dispatch event
		_G[method] = function(a1, a2)
			return dispatch(evt, a1, a2)
		end

	elseif idEvents[evt] then
		-- Event with player as 2nd: load it, make it 1st and schedule if needed
		_G[method] = function(id, name, a3)
			local player = Player.load(name)

			-- Sometimes, transformice calls events in a weird manner.

			if not player then
				-- In case this event is called before eventNewPlayer:
				-- This may return a full player and if so,
				-- it called eventNewPlayer during creation.
				player = Player.new(name)
			end

			if player.isDestroying then
				-- In case this event is called right after eventPlayerLeft (<250ms)
				-- we just cancel it
				return

			elseif player.isPartial then
				-- If the player is partial, we try to load it
				if not player:loadInfo() then
					-- if we can't load it, schedule the event to run after creation
					return player:schedule(evt, id, a3)
				end
			end

			-- If the player is fully loaded AND it was not being destroyed,
			-- we continue normally.
			return dispatch(evt, player, id, a3)
		end

	elseif playerEvents[evt] then
		-- Event with player as 1st: load it and schedule if needed
		_G[method] = function(name, a2, a3, a4, a5, a6)
			local player = Player.load(name)

			-- Same reasoning as the previous handler (more args and no argument flipping)
			if not player then
				player = Player.new(name)
			end

			if player.isDestroying then
				return
			elseif player.isPartial then
				if not player:loadInfo() then
					return player:schedule(evt, a2, a3, a4, a5, a6)
				end
			end

			return dispatch(evt, player, a2, a3, a4, a5, a6)
		end

	else
		-- Not a transformice event, but a custom one.
		_G[method] = function(a1, a2, a3, a4, a5, a6)
			return dispatch(evt, a1, a2, a3, a4, a5, a6)
		end
	end
end

local doSetup = Game.on
function Game.on(evt, callback, coro)
	-- Overwrite .on function
	if not setup[evt] then
		setupEvent(evt)
	end

	return doSetup(evt, callback, coro)
end

local events = Game._getEvents()

-- Allow the script to allocate transformice events. Useful for waiting on events using coroutines
--[[@ Allocates a global variable that dispatches the given event
	@param evt<string> The event name (newPlayer, loop, textAreaCallback, ...)
	@available OVERRIDE_EVENTS
]]
function Game.allocate(evt)
	if not setup[evt] then
		if not events[evt] then
			-- If we don't add this, Game.dispatch will ignore the event as it wasn't registered
			events[evt] = {
				_name = evt,
				_count = 0
			}
		end
		setupEvent(evt)
	end
end

-- Set up all events that have been created before this moment
for evt in next, events do
	setupEvent(evt)
end