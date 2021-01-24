-- Entry point of the library

@#IF COROUTINE_SUPPORT
require("src/coroutines")
@#ENDIF
@#IF HANDLE_RUNTIME
require("src/runtime")
@#ENDIF
@#IF OVERRIDE_EVENTS
require("src/override")
@#ENDIF

return {
	Game = require("src/game"),

	Player = require("src/player")
}