# Goose Documentation

## Player
Represents a player

| Attribute | Type | Can be nil | Description |
| :-: | :-: | :-: | :-- |
| isPartial | `boolean` | ✕ | Whether full data of the player is available or not |
| isDestroying | `boolean` | ✕ | Whether the player is being destroyed or not |
| name | `string` | ✕ | The player's name |
| id | `int` | ✔ | The player's ID |
| community | `string` | ✔ | The player's community |
| extra | `table` | ✔ | Data from tfm.get.room.playerList about this player |

### Methods
Player.**load**(_name_) <a id="Player.load" href="#Player.load">¶</a>
>
>Returns a player only if it has been created
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| name | `string` | ✕ | The player's name |
>
>| Returns | Description |
>| :-: | :-- |
>| [`Player`](Player.md#Player) | The player. May be nil. |

---

Player.**partial**(_name_) <a id="Player.partial" href="#Player.partial">¶</a>
>
>Partially creates a player
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| name | `string` | ✕ | The player's name |
>
>| Returns | Description |
>| :-: | :-- |
>| [`Player`](Player.md#Player) | The created player |

---

Player:**schedule**(_evt, ..._) <a id="Player.schedule" href="#Player.schedule">¶</a>
>
>Schedule an event for when the player is fully loaded. Usage should be internal.
>
>This method is only available when the following preprocessing variables are true: `OVERRIDE_EVENTS`
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| evt | `string` | ✕ | The event name |
>| ... | `any` | ✕ | The event parameters |

---

Player.**new**(_name_) <a id="Player.new" href="#Player.new">¶</a>
>
>Creates a player or fully loads it if possible. May return a partial player.
>
>Note that this method dispatches the newPlayer event and any subsequent scheduled event if the player fully loads.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| name | `string` | ✕ | The player's name |
>
>| Returns | Description |
>| :-: | :-- |
>| [`Player`](Player.md#Player) | The player. |

---

Player:**loadInfo**() <a id="Player.loadInfo" href="#Player.loadInfo">¶</a>
>
>Fully loads a player if it was partially loaded.
>
>Note that this method dispatches the newPlayer event and any subsequent scheduled event if the player fully loads.
>
>| Returns | Description |
>| :-: | :-- |
>| `boolean` | Whether the player could be fully loaded or not. |

---

Player:**update**() <a id="Player.update" href="#Player.update">¶</a>
>
>Updates extra information of the player if possible, or fully loads the player if it was partially loaded.
>
>Note that this method dispatches the newPlayer event and any subsequent scheduled event if the player fully loads.
>
>| Returns | Description |
>| :-: | :-- |
>| `boolean` | Whether extra information could be updated or not |

---

Player:**fetchData**(_await, timeout_) <a id="Player.fetchData" href="#Player.fetchData">¶</a>
>
>Fetch this player's file (wrapper for system.loadPlayerData)
>
>If COROUTINE_SUPPORT is set to true, you can await until the data gets loaded or a timeout passes.
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| await | `boolean` | ✔ | Whether or not to await for player data |
>| timeout | `int` | ✔ | Timeout for the request, in milliseconds |
>
>| Returns | Description |
>| :-: | :-- |
>| `boolean` | Whether awaiting has been successful or not |
>| `string` | The player's data, if you awaited for it and the first return value is true. |

---

Player:**chatMessage**(_msg_) <a id="Player.chatMessage" href="#Player.chatMessage">¶</a>
>
>Send a chat message to this player
>
>| Parameter | Type | Can be nil | Description |
>| :-: | :-: | :-: | :-- |
>| msg | `string` | ✕ | The message |

---

Player:**destroy**() <a id="Player.destroy" href="#Player.destroy">¶</a>
>
>Destroys the player.
>
>Destruction is only scheduled, and it will happen at least 250ms later.

---
