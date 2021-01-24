# Goose Documentation

## Game
Represents the game/module.

This is not a class, but an instance. You should not create multiple Game instances.

| Attribute | Type | Can be nil | Description |
| :-: | :-: | :-: | :-- |

### Methods
Game.**waitFor**(_evt, pred, timeout_) <a id="Game.waitFor" href="#Game.waitFor">¶</a>
>
>Blocks until the given event is fired and a call to pred with the event parameters returns true
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| evt | `string` | ✕ | The event name |
>| pred | `function(...)` | ✔ | A predicate that is called with the event parameters, if it returns true, then this call to waitFor ends |
>| timeout | `int` | ✔ | A timeout, in milliseconds. |
>
>| Returns | Description |
>| :-: | :-- |
>| boolean | If it is false, the timeout passed. |
>| ... | The event parameters |

---

Game.**waitTimeout**(_timeout_) <a id="Game.waitTimeout" href="#Game.waitTimeout">¶</a>
>
>Blocks until the given timeout passes
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| timeout | `int` | ✕ | The timeout, in milliseconds. |

---

Game.**onError**(_callback_) <a id="Game.onError" href="#Game.onError">¶</a>
>
>Appends a callback to the error handler.
>
>These callbacks are called on any error with the error message as a parameter, with the exception of syntax errors.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| callback | `function(string)` | ✕ | The callback to append to error handling |

---

Game.**\_getEvents**() <a id="Game._getEvents" href="#Game._getEvents">¶</a>
>
>Returns the table with the registered events. Usage should only be internal.
>
>| Returns | Description |
>| :-: | :-- |
>| table | The events table |

---

Game.**\_handleError**(_msg_) <a id="Game._handleError" href="#Game._handleError">¶</a>
>
>Triggers the error callbacks. Usage should only be internal.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| msg | `string` | ✕ | The error message |

---

Game.**on**(_evt, callback, coro_) <a id="Game.on" href="#Game.on">¶</a>
>
>Sets up a callback to be triggered everytime an event is dispatched.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| evt | `string` | ✕ | The event name (newPlayer, loop, textAreaCallback, ...) |
>| callback | `function(...)` | ✕ | The callback to be triggered. |
>| coro | `boolean` | ✔ | Whether the callback should be treated as a coroutine or not. Only available when COROUTINE_SUPPORT is true |

---

Game.**dispatch**(_evtName, ..._) <a id="Game.dispatch" href="#Game.dispatch">¶</a>
>
>Triggers event callbacks
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| evtName | `string` | ✕ | The event name |
>| ... | `any` | ✕ | The event parameters |

---

Game.**loadMap**(_map, flipped, await_) <a id="Game.loadMap" href="#Game.loadMap">¶</a>
>
>Loads a new map in the room. Has a cooldown of 3 seconds.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| map | `string|int` | ✕ | The map code, xml or perm |
>| flipped | `boolean` | ✔ | Whether the map should be flipped or not |
>| await | `boolean` | ✔ | Whether the function should block until the cooldown resets |
>
>| Returns | Description |
>| :-: | :-- |
>| boolean | Whether the map load has been started or not |

---

Game.**\_setListenerTrigger**(_trigger_) <a id="Game._setListenerTrigger" href="#Game._setListenerTrigger">¶</a>
>
>Sets the function to trigger callbacks. Usable should only be internal.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| trigger | `function` | ✕ | The new function |

---

Game.**allocate**(_evt_) <a id="Game.allocate" href="#Game.allocate">¶</a>
>
>Allocates a global variable that dispatches the given event
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| evt | `string` | ✕ | The event name (newPlayer, loop, textAreaCallback, ...) |

---

Game.**stopInitialization**() <a id="Game.stopInitialization" href="#Game.stopInitialization">¶</a>
>
>Signals the initialization of the module has ended and starts handling runtime.

---
