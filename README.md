# Goose

This project is a wrapper for the Transformice's API that is focused in efficiency and development.
It is meant to provide tools for the developer to make it easier to work on the code without needing to add complex logic to it.

## Name

idk i just wanted to call it goose

## How to use

This project requires [Modular](https://github.com/Tocutoeltuco/modular). In your module source code, all you need to do to require this library is:
```lua
local api = require("github+Tocutoeltuco/goose")
```

### Notes

This library also has some preprocessing directives available, you can add them to your `bundle-config.lua`:
- `OVERRIDE_EVENTS` (boolean) makes the wrapper generate transformice events to start working automatically, so you just need to register them with a call to `Game.on`
- `HANDLE_RUNTIME` (boolean) makes the wrapper handle module runtime whenever `Game.dispatch` is called
- `COROUTINE_SUPPORT` (boolean) adds basic coroutine support such as `Game.waitFor` and `Game.waitTimeout`

In the case `OVERRIDE_EVENTS` is set to `true`:
- All transformice events are automatically dispatched with `Game.dispatch`, and their name is transformed: `eventNewPlayer` => `newPlayer`
- Events that have `playerName` as a parameter, automatically trigger their callbacks with an instance of `Player`, representing that player.
- All the events have `player` as their first parameter (`textAreaCallback` for example)

In the case `HANDLE_RUNTIME` is set to `true`, your `src/config.lua` may have the following variables:
- `cycleDuration` (integer) sets the cycle duration in milliseconds, default: `4100`
- `runtimeLimit` (integer) sets the maximum runtime usage per cycle in milliseconds, default: `30`
- `dontSchedule` (table) tells which events to avoid scheduling when the module is paused, default: `{["loop"] = true}`

## Advantages

- Fixes many bugs you didn't even know about in Transformice's API
- Customizable
- Fast
- Keeps API functions consistent
- Has a nice documentation
- Object Oriented
- Coroutine support
- Error and runtime handling

## Documentation

You can build the documentation by running [this script](docgen.py), and you can read it [here](docs)