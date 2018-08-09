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

DEBUG                             = false
DEBUG_LOCAL                       = false and DEBUG
DEBUG_FORCE_NAT_OFF               = false and DEBUG_LOCAL
DEBUG_DISABLE_VARIOUS_FILE_SAVING = false and DEBUG_LOCAL
DEBUG_EXPIRATION_TIME_PORT        = 30
DEBUG_EXPIRATION_TIME_SESSION     = 3*60 -- Only useful is NAT is off.

-- Allow overriding DEBUG settings through a local file.
local chunk = loadfile"local/debug.lua"
if chunk then  chunk()  end



-- Settings, app/general.

APP_VERSION       = require"version"
CACHE_DIR         = DEBUG_LOCAL and "cacheDebug" or "cache"
MAX_DROPPED_FILES = 1000
SAVE_DELAY        = DEBUG and 1000 or 2000 -- Affects saving of settings, etc.

MARGIN_L          = 20
MARGIN_M          = 8
MARGIN_S          = 4
MARGIN_XS         = 2



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
NAT_LIMIT_TOLERANCE_BEFORE_SETTLING = 15

MAX_DATA_LENGTH                     = 1400 -- Must be between 400 and 1400. (MTU, PPPoE etc.)

FLOOD_PROTECTION_SHORT_TERM         = 20
FLOOD_PROTECTION_WINDOW             = 10   -- Saved amount of lastResponseTimes.



-- Constants.
require(... .."_keys") -- Extra stuff that WX don't add.
require(... .."_wx")

EMPTY_TABLE             = {}
NOOP                    = function()end

PROCESS_METHOD_ASYNC    = 1
PROCESS_METHOD_SYNC     = 2
PROCESS_METHOD_DETACHED = 3

APPDIR                  = wx.wxGetCwd() -- Hopefully the program isn't launched from another folder...

-- AniDB.

MYLIST_STATE_UNKNOWN                  = 0
MYLIST_STATE_INTERNAL_STORAGE         = 1
MYLIST_STATE_EXTERNAL_STORAGE         = 2
MYLIST_STATE_DELETED                  = 3
MYLIST_STATE_REMOTE_STORAGE           = 4

MYLIST_FILESTATE_NORMAL_ORIGINAL      = 0   -- normal
MYLIST_FILESTATE_CORRUPTED_OR_BAD_CRC = 1   -- normal
MYLIST_FILESTATE_SELF_EDITED          = 2   -- normal
MYLIST_FILESTATE_SELF_RIPPED          = 10  -- generic
MYLIST_FILESTATE_ON_DVD               = 11  -- generic
MYLIST_FILESTATE_ON_VHS               = 12  -- generic
MYLIST_FILESTATE_ON_TV                = 13  -- generic
MYLIST_FILESTATE_IN_THEATERS          = 14  -- generic
MYLIST_FILESTATE_STREAMED             = 15  -- normal
MYLIST_FILESTATE_ON_BLURAY            = 16  -- generic
MYLIST_FILESTATE_OTHER                = 100 -- normal



-- Modules.

socket = require"socket"

_print = print -- We define our own print().



-- Variables and objects.

logFile           = nil
processes         = {}
settingsAreFrozen = true


