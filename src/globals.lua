--[[============================================================
--=
--=  Global Values
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]



-- Settings, debug.
DEBUG                               = true
DEBUG_LOCAL                         = true and DEBUG
DEBUG_FORCE_NAT_OFF                 = true and DEBUG_LOCAL
DEBUG_EXPIRATION_TIME_PORT          = 60
DEBUG_EXPIRATION_TIME_SESSION       = 3*60 -- Only useful is NAT is off.

-- Settings, AniDB.
SERVER_ADDRESS                      = DEBUG_LOCAL and "localhost" or "api.anidb.net"
SERVER_PORT                         = 9000
LOCAL_PORT                          = DEBUG_LOCAL and 9000 or 24040

PROTOCOL_VERSION                    = 3
CLIENT_NAME                         = "myhappylist"
CLIENT_VERSION                      = 1

DEFAULT_PING_DELAY                  = DEBUG_LOCAL and 20 or 60
DELAY_BETWEEN_REQUESTS_LONG         = 4
DELAY_BETWEEN_REQUESTS_SHORT        = 2
SERVER_RESPONSE_TIMEOUT             = 90   -- Firefox's default HTTP connection timeout is 90 seconds.
DELAY_BEFORE_RESENDING              = {30, 2*60, 5*60, 10*60, 30*60, 1*60*60, 2*60*60, last=3*60*60}

NAT_LIMIT_MIN                       = 10
NAT_LIMIT_MAX                       = 15*60
NAT_LIMIT_TOLERANCE_BEFORE_SETTLING = 10

MAX_DATA_LENGTH                     = 1400 -- Must be between 400 and 1400. (MTU, PPPoE etc.)

FLOOD_PROTECTION_SHORT_TERM         = 20
FLOOD_PROTECTION_WINDOW             = 10   -- Saved amount of lastResponseTimes.

-- Settings, MyHappyList.
MAX_DROPPED_FILES                   = 1000



-- Constants.
require(... .."_keys") -- Extra stuff that WX don't add.
require(... .."_wx")

NOOP   = function()end

lfs    = require"lfs"
socket = require"socket"

_print = print



-- Variables.
logFile = nil


