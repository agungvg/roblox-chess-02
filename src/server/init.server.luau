-- Server bootstrap: build the world, start the game loops.
-- NOTE: this file IS the Server script (Rojo init semantics), so the
-- sibling modules are children of this script, not of its parent.
local GameServer = require(script.GameServer)
GameServer.start()
print("[ChessBrainrot] Battle Royale server started — 48 pieces, 6 boards, 6 events.")
