--[[============================================================
--=
--=  Anidb Class
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================


	API
	--------------------------------

	clearMessageQueue
	events
	getLogin
	hashFile
	isLoggedIn
	isSendingAnyMessage, getQueuedMessageCount
	update

	-- Server communication.
	addMylistByFile, addMylistByEd2k
	deleteMylist
	getMylistByFile, getMylistByEd2k
	login, logout
	ping


	Status Codes
	--------------------------------

	All:
	505 ILLEGAL INPUT OR ACCESS DENIED
	555 BANNED
	598 UNKNOWN COMMAND
	600 INTERNAL SERVER ERROR
	601 ANIDB OUT OF SERVICE - TRY AGAIN LATER
	602 SERVER BUSY - TRY AGAIN LATER
	604 TIMEOUT - DELAY AND RESUBMIT
	If s=session:
	501 LOGIN FIRST
	502 ACCESS DENIED
	506 INVALID SESSION
	// These are handled in handleServerResponse().

	See the server communication methods for the rest.


	File Structure
	--------------------------------

	Constants
	Local Variables
	Local Functions
	Response Handlers
	Methods
	Constructor


--============================================================]]

local NAT_MODE_UNKNOWN                = 0
local NAT_MODE_ON                     = 1
local NAT_MODE_OFF                    = 2

local MESSAGE_STAGE_QUEUE             = 1
local MESSAGE_STAGE_SENT              = 2
local MESSAGE_STAGE_RESPONDED         = 3
local MESSAGE_STAGE_RESPONSE_TIMEOUT  = 4
local MESSAGE_STAGE_ABORTED           = 5

local BOOL_FALSE                      = "0"
local BOOL_TRUE                       = "1"

local MYLIST_STATE_UNKNOWN            = 0
local MYLIST_STATE_INTERNAL_STORAGE   = 1
local MYLIST_STATE_EXTERNAL_STORAGE   = 2
local MYLIST_STATE_DELETED            = 3
local MYLIST_STATE_REMOTE_STORAGE     = 4

local FILE_STATE_NORMAL_ORIGINAL      = 0   -- normal
local FILE_STATE_CORRUPTED_OR_BAD_CRC = 1   -- normal
local FILE_STATE_SELF_EDITED          = 2   -- normal
local FILE_STATE_SELF_RIPPED          = 10  -- generic
local FILE_STATE_ON_DVD               = 11  -- generic
local FILE_STATE_ON_VHS               = 12  -- generic
local FILE_STATE_ON_TV                = 13  -- generic
local FILE_STATE_IN_THEATERS          = 14  -- generic
local FILE_STATE_STREAMED             = 15  -- normal
local FILE_STATE_ON_BLURAY            = 16  -- generic
local FILE_STATE_OTHER                = 100 -- normal

local ED2K_STATE_IN_PROGRESS          = 1
local ED2K_STATE_SUCCESS              = 2
local ED2K_STATE_ERROR                = 3



--[[local STATUS_CODE_NAMES = {
	[200]="LOGIN_ACCEPTED",                [201]="LOGIN_ACCEPTED_NEW_VERSION",  [203]="LOGGED_OUT",
	[205]="RESOURCE",                      [206]="STATS",                       [207]="TOP",
	[208]="UPTIME",                        [209]="ENCRYPTION_ENABLED",          [210]="MYLIST_ENTRY_ADDED",
	[211]="MYLIST_ENTRY_DELETED",          [214]="ADDED_FILE",                  [215]="ADDED_STREAM",
	[217]="EXPORT_QUEUED",                 [218]="EXPORT_CANCELLED",            [219]="ENCODING_CHANGED",
	[220]="FILE",                          [221]="MYLIST",                      [222]="MYLIST_STATS",
	[223]="WISHLIST",                      [224]="NOTIFICATION",                [225]="GROUP_STATUS",
	[226]="WISHLIST_ENTRY_ADDED",          [227]="WISHLIST_ENTRY_DELETED",      [228]="WISHLIST_ENTRY_UPDATED",
	[229]="MULTIPLE_WISHLIST",             [230]="ANIME",                       [231]="ANIME_BEST_MATCH",
	[232]="RANDOM_ANIME",                  [233]="ANIME_DESCRIPTION",           [234]="REVIEW",
	[235]="CHARACTER",                     [236]="SONG",                        [237]="ANIMETAG",
	[238]="CHARACTERTAG",                  [240]="EPISODE",                     [243]="UPDATED",
	[244]="TITLE",                         [245]="CREATOR",                     [246]="NOTIFICATION_ENTRY_ADDED",
	[247]="NOTIFICATION_ENTRY_DELETED",    [248]="NOTIFICATION_ENTRY_UPDATE",   [249]="MULTIPLE_NOTIFICATION",
	[250]="GROUP",                         [251]="CATEGORY",                    [253]="BUDDY_LIST",
	[254]="BUDDY_STATE",                   [255]="BUDDY_ADDED",                 [256]="BUDDY_DELETED",
	[257]="BUDDY_ACCEPTED",                [258]="BUDDY_DENIED",                [260]="VOTED",
	[261]="VOTE_FOUND",                    [262]="VOTE_UPDATED",                [263]="VOTE_REVOKED",
	[265]="HOT_ANIME",                     [266]="RANDOM_RECOMMENDATION",       [267]="RANDOM_SIMILAR",
	[270]="NOTIFICATION_ENABLED",          [281]="NOTIFYACK_SUCCESSFUL_MESSAGE",[282]="NOTIFYACK_SUCCESSFUL_NOTIFIATION",
	[290]="NOTIFICATION_STATE",            [291]="NOTIFYLIST",                  [292]="NOTIFYGET_MESSAGE",
	[293]="NOTIFYGET_NOTIFY",              [294]="SENDMESSAGE_SUCCESSFUL",      [295]="USER_ID",
	[297]="CALENDAR",                      [300]="PONG",                        [301]="AUTHPONG",
	[305]="NO_SUCH_RESOURCE",              [309]="API_PASSWORD_NOT_DEFINED",    [310]="FILE_ALREADY_IN_MYLIST",
	[311]="MYLIST_ENTRY_EDITED",           [312]="MULTIPLE_MYLIST_ENTRIES",     [313]="WATCHED",
	[314]="SIZE_HASH_EXISTS",              [315]="INVALID_DATA",                [316]="STREAMNOID_USED",
	[317]="EXPORT_NO_SUCH_TEMPLATE",       [318]="EXPORT_ALREADY_IN_QUEUE",     [319]="EXPORT_NO_EXPORT_QUEUED_OR_IS_PROCESSING",
	[320]="NO_SUCH_FILE",                  [321]="NO_SUCH_ENTRY",               [322]="MULTIPLE_FILES_FOUND",
	[323]="NO_SUCH_WISHLIST",              [324]="NO_SUCH_NOTIFICATION",        [325]="NO_GROUPS_FOUND",
	[330]="NO_SUCH_ANIME",                 [333]="NO_SUCH_DESCRIPTION",         [334]="NO_SUCH_REVIEW",
	[335]="NO_SUCH_CHARACTER",             [336]="NO_SUCH_SONG",                [337]="NO_SUCH_ANIMETAG",
	[338]="NO_SUCH_CHARACTERTAG",          [340]="NO_SUCH_EPISODE",             [343]="NO_SUCH_UPDATES",
	[344]="NO_SUCH_TITLES",                [345]="NO_SUCH_CREATOR",             [350]="NO_SUCH_GROUP",
	[351]="NO_SUCH_CATEGORY",              [355]="BUDDY_ALREADY_ADDED",         [356]="NO_SUCH_BUDDY",
	[357]="BUDDY_ALREADY_ACCEPTED",        [358]="BUDDY_ALREADY_DENIED",        [360]="NO_SUCH_VOTE",
	[361]="INVALID_VOTE_TYPE",             [362]="INVALID_VOTE_VALUE",          [363]="PERMVOTE_NOT_ALLOWED",
	[364]="ALREADY_PERMVOTED",             [365]="HOT_ANIME_EMPTY",             [366]="RANDOM_RECOMMENDATION_EMPTY",
	[367]="RANDOM_SIMILAR_EMPTY",          [370]="NOTIFICATION_DISABLED",       [381]="NO_SUCH_ENTRY_MESSAGE",
	[382]="NO_SUCH_ENTRY_NOTIFICATION",    [392]="NO_SUCH_MESSAGE",             [393]="NO_SUCH_NOTIFY",
	[394]="NO_SUCH_USER",                  [397]="CALENDAR_EMPTY",              [399]="NO_CHANGES",
	[403]="NOT_LOGGED_IN",                 [410]="NO_SUCH_MYLIST_FILE",         [411]="NO_SUCH_MYLIST_ENTRY",
	[412]="MYLIST_UNAVAILABLE",            [500]="LOGIN_FAILED",                [501]="LOGIN_FIRST",
	[502]="ACCESS_DENIED",                 [503]="CLIENT_VERSION_OUTDATED",     [504]="CLIENT_BANNED",
	[505]="ILLEGAL_INPUT_OR_ACCESS_DENIED",[506]="INVALID_SESSION",             [509]="NO_SUCH_ENCRYPTION_TYPE",
	[519]="ENCODING_NOT_SUPPORTED",        [555]="BANNED",                      [598]="UNKNOWN_COMMAND",
	[600]="INTERNAL_SERVER_ERROR",         [601]="ANIDB_OUT_OF_SERVICE",        [602]="SERVER_BUSY",
	[603]="NO_DATA",                       [604]="TIMEOUT",                     [666]="API_VIOLATION",
	[701]="PUSHACK_CONFIRMED",             [702]="NO_SUCH_PACKET_PENDING",      [998]="VERSION",
}]]



local Anidb = {
	udp                   = nil,

	messages              = nil,
	theEvents             = nil,
	cache                 = nil,
	cachePartial          = nil,

	sessionKey            = "", -- This indicates whether we're logged in or not.

	blackoutUntil         = -1, -- No fraction!
	isInBlackout          = false,

	natMode               = NAT_MODE_UNKNOWN,
	isActive              = false, -- Active connections should send PINGs. Only used if NAT is on.
	pingDelay             = DEFAULT_PING_DELAY,
	natLimitLower         = -1,
	natLimitUpper         = -1,
	lastPublicPort        = -1, -- Port seen by the server.

	responseTimeLast      = 0.00,
	responseTimePrevious  = 0.00,
	previousResponseTimes = nil,

	mylistDefaults        = nil,

	-- Internal events:
	onLogin           = NOOP,
}
Anidb.__index = Anidb

local responseHandlers



--==============================================================
--= Local Functions ============================================
--==============================================================

local _logprint, _logprinterror
local addEvent
local blackout, loadBlackout
local cacheSave, cacheLoad, cacheDelete
local compress, decompress
local createData
local dropSession
local generateTag
local getEd2k, getPathByEd2k
local getMessage, addMessage, removeMessage
local getNextMessageToSend
local handleServerResponse
local isAnyMessageInTransit, isMessageInQueue
local onInternal
local paramStringEncode, paramStringDecode, paramNumberEncode, paramNumberDecode, paramBooleanEncode, paramBooleanDecode, parseEpisodes
local send, receive
local updateNatInfo



do
	local ENCODES = {
		["&"]  = "&amp;",
		["<"]  = "&lt;",
		[">"]  = "&gt;",
		['"']  = "&quot;",
		["\n"] = "<br />",
	}
	function paramStringEncode(s)
		assert(type(s) == "string", s)
		return (s:gsub("[&<>\"\n]", ENCODES))
	end

	local DECODES = {
		["&amp;"]  = "&",
		["&lt;"]   = "<",
		["&gt;"]   = ">",
		["&quot;"] = '"',
	}
	function paramStringDecode(v)
		return (v:gsub("<br />", "\n"):gsub("&%a+;", DECODES))
	end
end

function paramNumberEncode(n)
	assert(isInt(n) and n >= 0, n)
	return F("%.0f", n)
end
function paramNumberDecode(v)
	if v == "" or v:find"%D" then  return nil  end
	return tonumber(v)
end

function paramBooleanEncode(bool)
	assert(type(bool) == "boolean", bool)
	return bool and BOOL_TRUE or BOOL_FALSE
end
function paramBooleanDecode(v)
	if v == BOOL_TRUE  then  return true   end
	if v == BOOL_FALSE then  return false  end
	return nil
end

function parseEpisodes(epList)
	local eps = {}

	for epSeq in epList:gmatch"[^,]+" do
		local epFrom, epTo = epSeq:match"^([^-]+)%-([^-]+)$"

		-- Single episode.
		if not epFrom then
			table.insert(eps, epSeq)

		-- Episode sequence.
		else
			local prefix, from = epFrom :match"^(%D*)(%d+)$"
			local prefixTo, to = epTo   :match"^(%D*)(%d+)$"

			if not prefix or prefixTo ~= prefix then
				_logprinterror("Canot parse episode list: "..epSeq)

			else
				for ep = tonumber(from), tonumber(to) do
					table.insert(eps, prefix..ep)
				end
			end
		end
	end

	return eps
end



-- Add a message to the send queue.
-- send( anidb, command, params [, first=false ] )
function send(self, command, params, first)
	assertarg(1, self,    "table")
	assertarg(2, command, "string")
	assertarg(3, params,  "table")

	_logprint("Queuing "..command..".")

	local cb = responseHandlers[command] or errorf("No response handler for command '%s'.", command)

	local tag = generateTag()
	params["tag"] = tag

	local msg = {
		tag            = tag,
		stage          = MESSAGE_STAGE_QUEUE,
		tries          = 0,
		dontSendBefore = -1,

		command        = command,
		params         = params,
		callback       = cb,

		timeSent       = -1,
		timeResponded  = -1,
	}
	addMessage(self, msg, first)
end

-- for data in receive( anidb ) do
function receive(self)
	return function()
		local data, err = self.udp:receive()
		if err == "timeout" then  return nil  end

		check(data, err)
		if data then  return data  end
	end
end



function createData(command, params)
	local queryParts = {}

	for param, v in pairsSorted(params) do
		if type(v) == "string" then
			table.insert(queryParts, F("%s=%s", param, paramStringEncode(v)))

		elseif type(v) == "number" then
			table.insert(queryParts, F("%s=%s", param, paramNumberEncode(v)))

		elseif type(v) == "boolean" then
			table.insert(queryParts, F("%s=%s", param, paramBooleanEncode(v)))

		else
			errorf("[AniDB.internal] Cannot encode values of type '%s'.", type(v))
		end
	end

	local data = F("%s %s", command, table.concat(queryParts, "&"))
	return data
end



do
	local tags = {}

	function generateTag()
		local tag
		repeat
			tag = F("#%x", math.random(0xFFFFFFF))
		until not tags[tag]

		tags[tag] = true
		return tag
	end
end



function compress(data)
	error("[AniDB.internal] Cannot compress data yet.")
end

function decompress(data)
	error("[AniDB.internal] Cannot handle compressed data yet.")
end



-- handledResponseProperly = handleServerResponse( anidb, data )
do
	local function decodeResponseField(field)
		return (field:gsub("<br />", "\n"):gsub("`", "'"):gsub("/", "|"))
	end

	local function resendMessage(self, msg, doDelay)
		assert(msg.stage == MESSAGE_STAGE_RESPONDED)

		_logprint("Requeuing "..msg.command..".")

		local tag = generateTag()
		msg.params.tag = tag

		msg.tag   = tag
		msg.stage = MESSAGE_STAGE_QUEUE

		if doDelay then
			msg.dontSendBefore = getTime()+(DELAY_BEFORE_RESENDING[msg.tries] or DELAY_BEFORE_RESENDING.last)
		end

		-- Should 'first' be true? Maybe we should try to preserve the original position? Maybe it doesn't matter.
		-- Actually, since we only send one message at a time, we should indeed insert the message first!
		addMessage(self, msg, true)

		addEvent(self, "resend", msg.command)
	end

	local function loginAndResendMessage(self, msg)
		dropSession(self)

		onInternal(self, "onLogin", function(ok)
			if ok then
				resendMessage(self, msg)
			else
				addEvent(self, "error", "Failed "..msg.command.." command because we couldn't log in.")
			end
		end)

		self:login()
	end

	function handleServerResponse(self, data)
		-- [{str tag} ]{three digit return code} {str return string}\n
		-- {data field 0}|{data field 1}|...|{data field n}

		local time = getTime()
		self.responseTimePrevious = self.responseTimeLast
		self.responseTimeLast     = time

		if self.previousResponseTimes[FLOOD_PROTECTION_WINDOW] then
			table.remove(self.previousResponseTimes, 1)
		end
		table.insert(self.previousResponseTimes, time)

		-- Parse status line.
		--------------------------------

		local lineIter = data:gmatch"[^\n]+"

		local line = lineIter()
		if not line then
			_logprinterror("Server response is empty. (Length: %.0f)", #data)
			return false
		end

		local status = splitString(line, " +")

		local tag = table.remove(status, 1)
		if (tag or ""):sub(1, 1) ~= "#" then
			_logprinterror("Server response misses a tag: %s", makePrintable(data))
			return false
		end

		local msg = getMessage(self, tag)
		if not msg then
			_logprinterror("No message for tag '%s': %s", tag, makePrintable(data))
			return false
		end

		msg.stage         = MESSAGE_STAGE_RESPONDED
		msg.timeResponded = time
		removeMessage(self, msg)

		local statusCode = table.remove(status, 1)
		if not (statusCode or ""):find"^%d%d%d$" then
			_logprinterror("Server response misses a code: %s", makePrintable(data))

			addEvent(self, "error", "Bad format of response from the server for "..msg.command.." command.")
			msg:callback(self, false)
			return false
		end

		local statusText
		statusCode = tonumber(statusCode)
		statusText = table.concat(status, " ")

		-- Parse entries.
		--------------------------------

		local entries = {}

		for line in lineIter do
			local fields = splitString(line, "|")
			if not fields[2] and fields[1] == "" then  fields[1] = nil  end

			for i, field in ipairs(fields) do
				fields[i] = decodeResponseField(field)
			end

			table.insert(entries, fields)
		end

		-- Promise at least one entry to the callback, as some
		-- commands sometimes return one and sometimes none.
		entries[1] = entries[1] or {}

		-- Handle common error codes.
		--------------------------------

		-- LOGIN FIRST
		if statusCode == 501 then
			loginAndResendMessage(self, msg)
			return true

		-- ACCESS DENIED
		elseif statusCode == 502 then
			local err = "AniDB denied access when we sent a "..msg.command.." command."
			_logprinterror(err)
			addEvent(self, "error", err)

		-- ILLEGAL INPUT OR ACCESS DENIED
		elseif statusCode == 505 then
			local err = "AniDB got bad data when we sent a "..msg.command.." command. There may be a bug in MyHappyList."
			_logprinterror(err)
			addEvent(self, "error", err)

		-- INVALID SESSION
		elseif statusCode == 506 then
			loginAndResendMessage(self, msg)

		-- BANNED\n{str reason}  // For developers.
		elseif statusCode == 555 then
			local reason = entries[1][1] or "(no reason given)"
			_logprint("[dev] Banned: "..reason)

			blackout(20*60*60)

		-- UNKNOWN COMMAND
		elseif statusCode == 598 then
			addEvent(self, "error", "AniDB does not recognize a "..msg.command.." command.")

		-- Fatal error.
		-- Note: 6XX messages do not always return the tag given with the command which caused the error!
		elseif statusCode >= 600 and statusCode <= 699 then
			local errServer
				=  statusText:match"%- (.+)"
				or (entries[1][1] or ""):match"^ERROR: (.+)"
				or ""

			local function errorEvent(eName, err)
				if errServer ~= "" then
					err = F("%s\nError message: %s", err, errServer)
				end
				addEvent(self, eName, err)
			end

			local function pleaseReport()
				return F(
					" Please report the error to AniDB (code %d, timestamp %s).",
					statusCode, os.date"!%Y-%m-%dT%H:%M:%SZ"
				)
			end

			local function haltConnections(duration)
				return " Connections halted by MyHappyList for "..duration.."."
			end

			-- INTERNAL SERVER ERROR
			if statusCode == 600 then
				-- Give time to exit the program, in case 600 errors keep happening.
				blackout(self, 10)
				-- @Robustness: We can probably handle this better by keeping track of how
				-- the 600 errors happen - if they happen for all commands etc.

				errorEvent("error", "Internal server error."..pleaseReport()..haltConnections"2 hours")

			-- ANIDB OUT OF SERVICE - TRY AGAIN LATER
			elseif statusCode == 601 then
				dropSession(self) -- We can probably assume all sessions drop during service time.
				blackout(self, 30*60) -- Minimum 30 minutes.

				errorEvent("erroroutofservice", "AniDB temporarily out of service."..haltConnections"30 minutes")

			-- SERVER BUSY - TRY AGAIN LATER
			elseif statusCode == 602 then
				dropSession(self)
				blackout(self, 15*60)

				errorEvent("errorbusy", "AniDB is currently busy."..haltConnections"15 minutes")

			-- TIMEOUT - DELAY AND RESUBMIT
			elseif statusCode == 604 then
				if msg.tries < 5 then
					resendMessage(self, msg, true)
					return true
				end
				errorEvent("errortimeout", "Connection timed out."..pleaseReport())

			else
				errorEvent("error", "Fatal server error."..pleaseReport())
			end
		end

		--------------------------------

		msg:callback(self, true, statusCode, statusText, entries)
		return true
	end
end



function getMessage(self, tag)
	assertarg(1, self, "table")
	assertarg(2, tag,  "string")

	return self.messages[tag]
end

-- addMessage( anidb, message [, first=false ] )
function addMessage(self, msg, first)
	assertarg(1, self, "table")
	assertarg(2, msg,  "table")

	assert(not self.messages[msg.tag], msg.tag)

	local i = first and 1 or #self.messages+1

	self.messages[msg.tag] = msg
	table.insert(self.messages, i, msg)
end

-- Note: We allow removeMessage() to be called more than once, unlike addMessage().
function removeMessage(self, msg)
	assertarg(1, self, "table")
	assertarg(2, msg,  "table")

	self.messages[msg.tag] = nil
	removeItem(self.messages, msg)
end



function addEvent(self, eName, ...)
	assertarg(1, self,  "table")
	assertarg(2, eName, "string")

	table.insert(self.theEvents, {eName, ...})
end



do
	local function getCurrentDelayBetweenRequests(self)
		return
			self.previousResponseTimes[FLOOD_PROTECTION_WINDOW]
			and getTime() < self.previousResponseTimes[1]+FLOOD_PROTECTION_SHORT_TERM
			and DELAY_BETWEEN_REQUESTS_LONG
			or  DELAY_BETWEEN_REQUESTS_SHORT
	end

	function getNextMessageToSend(self, force)
		local time = getTime()

		if not force then
			if self.isInBlackout then  return nil  end

			-- Don't send requests too frequently.
			local timeLast = self.responseTimeLast
			local delay    = getCurrentDelayBetweenRequests(self)
			if timeLast > 0 and time-timeLast < delay then  return nil  end

			-- Make sure no message is in transit.
			if isAnyMessageInTransit(self) then  return nil  end
		end

		-- Alright, next queued message should be good to go (if there is one).
		for _, msg in ipairs(self.messages) do
			if msg.stage == MESSAGE_STAGE_QUEUE and (time >= msg.dontSendBefore or force) then
				return msg
			end
		end

		return nil
	end
end



function blackout(self, duration)
	local durationStr
	if duration < 2*60 then
		durationStr = F("%d seconds", duration)
	elseif duration < 2*3600 then
		durationStr = F("%d minutes", math.floor(duration/60))
	else
		durationStr = F("%d hours", math.floor(duration/3600))
	end
	_logprint("Blackout for %s.", durationStr)

	if not self.isInBlackout then
		addEvent(self, "blackoutstart")
	end

	self.blackoutUntil = math.floor(getTime()+duration)
	self.isInBlackout  = true

	local ok, err = writeFile(CACHE_DIR.."/blackout", F("%d", self.blackoutUntil))
	if not ok then
		_logprinterror("Could not write to file '%s/blackout': %s", CACHE_DIR, err)
	end
end

function loadBlackout(self)
	self.blackoutUntil = tonumber(getFileContents(CACHE_DIR.."/blackout") or 0)
	self.isInBlackout  = getTime() < self.blackoutUntil
end



function updateNatInfo(self, port)
	port = DEBUG_FORCE_NAT_OFF and LOCAL_PORT or port

	if self.natMode == NAT_MODE_UNKNOWN then
		if port == LOCAL_PORT then
			_logprint("NAT seem absent.")
			self.natMode = NAT_MODE_OFF
		else
			_logprint("NAT detected.")
			self.natMode  = NAT_MODE_ON
			self.isActive = true
		end

	elseif self.natMode == NAT_MODE_ON and self.responseTimeLast-self.responseTimePrevious >= self.pingDelay then
		local pingDelay  = self.pingDelay
		local natLimitLo = self.natLimitLower
		local natLimitUp = self.natLimitUpper

		if port ~= self.lastPublicPort then
			-- @Robustness: Make sure we don't end up here too many times within ~1 hour. [LOW]
			_logprint("Port got deallocated. Decreasing ping delay.")

			if natLimitLo > pingDelay then
				natLimitLo = -1
			end

			natLimitUp = pingDelay
			pingDelay  = natLimitLo > 0 and (natLimitLo+natLimitUp)/2 or pingDelay/2

		elseif natLimitLo <= 0 or natLimitUp <= 0 or natLimitUp-natLimitLo >= NAT_LIMIT_TOLERANCE_BEFORE_SETTLING then
			-- Note: After settling, the ping delay will never increase again, even if the actual port expiration
			-- time happen to increase for some reason (i.e. maybe after switching to different router). But it's
			-- not the end of the world...
			_logprint("Port still allocated. Increasing ping delay.")

			if natLimitUp < pingDelay then
				natLimitUp = -1
			end

			natLimitLo = pingDelay
			pingDelay  = natLimitUp > 0 and (natLimitLo+natLimitUp)/2 or pingDelay*1.5
		end

		if not (pingDelay == self.pingDelay and natLimitLo == self.natLimitLower and natLimitUp == self.natLimitUpper) then
			self.pingDelay     = clamp(pingDelay, NAT_LIMIT_MIN, NAT_LIMIT_MAX)
			self.natLimitLower = natLimitLo
			self.natLimitUpper = natLimitUp
			_logprint("Ping delay: %d seconds", self.pingDelay)

			local ok, err = writeFile(CACHE_DIR.."/nat", F("%d %d %d", pingDelay, natLimitLo, natLimitUp))
			if not ok then
				_logprinterror("Could not write to file '%s/nat': %s", CACHE_DIR, err)
			end
		end
	end

	self.lastPublicPort = port
end

function loadNatInfo(self)
	local contents = getFileContents(CACHE_DIR.."/nat")
	if not contents then
		_logprint("Ping delay: %d seconds", self.pingDelay)
		return
	end

	local pingDelay, natLimitLower, natLimitUpper = contents:match"^(%d+) (%-?%d+) (%-?%d+)$"
	if not pingDelay then
		_logprinterror("Bad format of file '%s/nat'.", CACHE_DIR)
		_logprint("Ping delay: %d seconds", self.pingDelay)
		return
	end

	self.pingDelay     = tonumber(pingDelay)
	self.natLimitLower = tonumber(natLimitLower)
	self.natLimitUpper = tonumber(natLimitUpper)

	_logprint("Ping delay: %d seconds", self.pingDelay)
end



function isAnyMessageInTransit(self)
	return itemWith(self.messages, "stage", MESSAGE_STAGE_SENT) ~= nil
end

function isMessageInQueue(self, command)
	return itemWith2(self.messages, "stage",MESSAGE_STAGE_QUEUE, "command",command) ~= nil
end



function _logprint(s, ...)
	logprint("AniDB", s, ...)
end

function _logprinterror(s, ...)
	logprinterror("AniDB", s, ...)
end



function onInternal(self, k, cb)
	local previousWrapper = self[k]

	self[k] = function(...)
		self[k] = previousWrapper

		-- Call the first callbacks in the chain first. This will reset self[k]
		-- completely before any callback potentionally adds another callback.
		previousWrapper(...)

		cb(...)
	end
end



function dropSession(self)
	self.sessionKey = ""
	self.isActive   = false -- Should we stop pinging here?
end



do
	local function deleteEntry(self, pageName, entry, isPartial)
		assertarg(1, self,      "table")
		assertarg(2, pageName,  "string")
		assertarg(3, entry,     "table")
		assertarg(4, isPartial, "boolean")

		local id = assert(entry.id)

		for _, path in ipairs{
			F("%s/%s%d%s",     CACHE_DIR, pageName, id, (isPartial and ".part" or "")),
			F("%s/%s%d%s.bak", CACHE_DIR, pageName, id, (isPartial and ".part" or "")),
		} do
			if isFile(path) and not deleteFile(path) then
				_logprinterror("Could not delete '%s'.", path)
			end
		end

		local page  = (isPartial and self.cachePartial or self.cache)[pageName]
		local entry = page.byId[id]

		if entry then
			if not removeItem(page, entry) then
				errorf("Cache page '%s' is out of sync regarding entry %d.", pageName, id)
			end
			page.byId[id] = nil
			_logprint("Deleted %s '%s' entry %d.", (isPartial and "partial" or "full"), pageName, id)
		end
	end

	-- entry = cacheSave( anidb, pageName, entry, isPartial )
	-- Note: The entry will overwrite any previous one with the same ID.
	function cacheSave(self, pageName, entry, isPartial)
		assertarg(1, self,      "table")
		assertarg(2, pageName,  "string")
		assertarg(3, entry,     "table")
		assertarg(4, isPartial, "boolean")

		local id = assert(entry.id)

		-- Make sure there's no collision between a full and a partial entry.
		----------------------------------------------------------------

		if not isPartial then
			local entryPartial = self.cachePartial[pageName].byId[id]

			if entryPartial then
				deleteEntry(self, pageName, entryPartial, true)
			end

		else
			local entryFull = self.cache[pageName].byId[id]

			if entryFull then
				-- Replace partial with full entry.

				local entryPartial = entry

				for k, v in pairs(entryPartial) do
					entryFull[k] = v
				end

				deleteEntry(self, pageName, entryPartial, true)

				entry     = entryFull
				isPartial = false
			end
		end

		-- Add or edit entry.
		----------------------------------------------------------------

		local page = (isPartial and self.cachePartial or self.cache)[pageName]

		if page.byId[id] then
			local _, i = itemWith(page, "id", entry.id)
			if not i then
				errorf("Cache page '%s' is out of sync regarding entry %d.", pageName, id)
			end

			page.byId[id] = entry
			page[i]       = entry
			_logprint("Updated %s '%s' entry %d.", (isPartial and "partial" or "full"), pageName, id)

		else
			page.byId[id] = entry
			table.insert(page, entry)
			_logprint("Added %s '%s' entry %d.", (isPartial and "partial" or "full"), pageName, id)
		end

		-- Write entry to file.
		----------------------------------------------------------------

		local path = F("%s/%s%d%s", CACHE_DIR, pageName, id, (isPartial and ".part" or ""))

		backupFileIfExists(path)
		local file = assert(openFile(path, "w"))

		for k, v in pairsSorted(entry) do
			writeSimpleKv(file, k, v, path)
		end

		file:close()

		----------------------------------------------------------------
		return entry
	end

	function cacheLoad(self, pageName, id, isPartial)
		assertarg(1, self,      "table")
		assertarg(2, pageName,  "string")
		assertarg(3, id,        "number")
		assertarg(4, isPartial, "boolean")

		local page  = (isPartial and self.cachePartial or self.cache)[pageName]
		local entry = page.byId[id]

		if entry then
			_logprinterror("Tried to load already loaded '%s' entry %d.", pageName, id)
			return entry
		end

		local path = F("%s/%s%d%s", CACHE_DIR, pageName, id, (isPartial and ".part" or ""))

		local file, err = openFile(path, "r")
		if not file then  return nil, err  end

		entry    = {}
		local ln = 0

		for line in file:lines() do
			ln = ln+1

			local k, v = parseSimpleKv(line, path, ln)

			if k then
				if entry[k] ~= nil then
					_logprinterror("%s:%d: Duplicate key '%s'. Overwriting.", path, ln, k)
				end
				entry[k] = v
			end
		end

		file:close()

		page.byId[id] = entry
		table.insert(page, entry)
		_logprint("Loaded %s '%s' entry %d.", (isPartial and "partial" or "full"), pageName, id)

		return entry
	end

	function cacheDelete(self, pageName, entry)
		assertarg(1, self,     "table")
		assertarg(2, pageName, "string")
		assertarg(3, entry,    "table")

		deleteEntry(self, pageName, entry, true)
		deleteEntry(self, pageName, entry, false)
	end

end



do
	local pathEd2ks    = {}
	local pathSizes    = {}
	local ed2kPaths    = {}

	local isLoaded     = false

	local ed2kQueue    = {}
	local isProcessing = false

	local function saveEd2ks()
		local file = assert(openFile(CACHE_DIR.."/ed2ks", "w"))

		for path, ed2kHash in pairsSorted(pathEd2ks) do
			if ed2kHash ~= "" then
				local fileSize = pathSizes[path]
				file:write(F("%s %.0f %s\n", ed2kHash, fileSize, path))
			end
		end

		file:close()
	end

	local function loadEd2ks()
		isLoaded = true

		local file = openFile(CACHE_DIR.."/ed2ks", "r")
		if not file then  return  end

		local ln = 0

		for line in file:lines() do
			ln = ln+1

			local ed2kHash, fileSize, path = line:match"^(%S+) (%d+) (%S.*)$"
			fileSize = tonumber(fileSize)

			if not ed2kHash then
				_logprinterror("%s:%d: Bad line format: %s", CACHE_DIR.."/ed2ks", ln, line)
			else
				pathEd2ks[path]     = ed2kHash
				pathSizes[path]     = fileSize
				ed2kPaths[ed2kHash] = path
			end
		end

		file:close()
	end

	local function processNextQueueItem()
		local queueItem = table.remove(ed2kQueue, 1)
		if not queueItem then  return  end

		isProcessing = true

		local self, path, fileSize, cb = unpack(queueItem)

		scriptCaptureAsync("ed2k", function(output)
			ed2kHash = output:match"^ed2k: ([%da-f]+)"

			if not ed2kHash then
				_logprinterror("Calculating ed2k for '%s' failed: %s", path:match"[^/\\]+$", output)

				pathEd2ks[path] = nil
				pathSizes[path] = nil

				for ed2kHashOther, pathOther in pairs(ed2kPaths) do
					if pathOther == path then
						ed2kPaths[ed2kHashOther] = nil
						break
					end
				end

				saveEd2ks()

				addEvent(self, "ed2kfail", path)
				cb(ED2K_STATE_ERROR)

				isProcessing = false
				processNextQueueItem()
				return
			end

			_logprint("Calculating ed2k for '%s'... %s", path:match"[^/\\]+$", ed2kHash)
			-- printf("ed2k://|file|%s|%d|%s|/", path:match"[^/\\]+$", fileSize, ed2kHash)

			if ed2kPaths[ed2kHash] then
				_logprint("Duplicate hash detected:\n\t%s\n\t%s  (replacement)", ed2kPaths[ed2kHash], path)
			end

			pathEd2ks[path]     = ed2kHash
			pathSizes[path]     = fileSize
			ed2kPaths[ed2kHash] = path

			saveEd2ks()

			addEvent(self, "ed2ksuccess", path, ed2kHash, fileSize)
			cb(ED2K_STATE_SUCCESS, ed2kHash, fileSize)

			isProcessing = false
			processNextQueueItem()
		end, toShortPath(path))
	end

	function getEd2k(self, path, cb)
		if not isLoaded then  loadEd2ks()  end

		local fileSize, err = getFileSize(path)

		if not fileSize then
			_logprinterror("Could not get info about file '%s': %s", path, err)
			addEvent(self, "ed2kfail", path)
			cb(ED2K_STATE_ERROR)
			return
		end

		local ed2kHash = pathEd2ks[path]

		if ed2kHash then
			if ed2kHash == "" then
				cb(ED2K_STATE_IN_PROGRESS)
				return

			elseif pathSizes[path] ~= fileSize then
				_logprinterror(
					"%s: Somehow we have the ed2k but the size is wrong. Recalculating. (expected %.0f, got %.0f)",
					path, pathSizes[path], fileSize
				)

				pathEd2ks[path]     = nil
				pathSizes[path]     = nil
				ed2kPaths[ed2kHash] = nil

			else
				-- Both ed2ks and size match previous values.

				-- This event may be overkill, but solves desync between local file list and ed2k list.
				addEvent(self, "ed2ksuccess", path, ed2kHash, fileSize)

				cb(ED2K_STATE_SUCCESS, ed2kHash, fileSize)
				return
			end
		end

		pathEd2ks[path] = "" -- An empty string means "currently calculating".
		_logprint("Calculating ed2k for '%s'...", path:match"[^/\\]+$")

		table.insert(ed2kQueue, {self, path, fileSize, cb})
		if not isProcessing then  processNextQueueItem()  end
	end

	function getPathByEd2k(ed2kHash)
		if not isLoaded then  loadEd2ks()  end

		return ed2kPaths[ed2kHash]
	end
end



--==============================================================
--= Response Handlers ==========================================
--==============================================================
responseHandlers = {



	["PING"] = function(msg, self, ok, statusCode, statusText, entries)
		if not ok then
			addEvent(self, "pingfail", "Something went wrong while sending ping. Check the log.")

		-- 300 PONG
		elseif statusCode == 300 then
			if self.natMode ~= NAT_MODE_OFF then
				local port = tonumber(entries[1][1])

				if not port then
					_logprinterror("Expected NAT information from PING request.")
				else
					updateNatInfo(self, port)
				end
			end

		-- 505 555 598 600 601 602 604 [501 502 506]
		else
			addEvent(self, "pingfail", "AniDB error "..statusCode..": "..statusText)
		end
	end,



	["AUTH"] = function(msg, self, ok, statusCode, statusText, entries)
		if not ok then
			addEvent(self, "loginfail", "Something went wrong while logging in. Check the log.")
			self.onLogin(false)

		-- 200 session_key LOGIN ACCEPTED
		-- 201 session_key LOGIN ACCEPTED - NEW VERSION AVAILABLE
		-- If nat=1:
		-- 200 session_key ip:port LOGIN ACCEPTED
		-- 201 session_key ip:port LOGIN ACCEPTED - NEW VERSION AVAILABLE
		elseif statusCode == 200 or statusCode == 201 then
			local session, natInfo = statusText:match"^(%S+) (%S+)"
			assert(session, "Bad AUTH status text format.")

			self.sessionKey = session
			_logprint("Started session. (%s)", session)

			if self.natMode ~= NAT_MODE_OFF then
				local ip, port = natInfo:match"^(%d+)%.(%d+)%.(%d+)%.(%d+):(%d+)$"
				port = tonumber(port)

				if not port then
					_logprinterror("Expected NAT information from AUTH request.")
				else
					updateNatInfo(self, port)
				end
			end

			addEvent(self, "loginsuccess")
			if statusCode == 201 then
				addEvent(self, "newversionavailable")
			end
			self.onLogin(true)

		-- 500 LOGIN FAILED
		elseif statusCode == 500 then
			addEvent(self, "loginbadlogin")
			self.onLogin(false)

		-- 503 CLIENT VERSION OUTDATED
		elseif statusCode == 503 then
			addEvent(self, "loginfail", "MyHappyList is outdated. Please download the newest version.")
			self.onLogin(false)

		-- 504 CLIENT BANNED - reason
		elseif statusCode == 504 then
			local reason = trim(statusText:match"%- (.+)" or "")
			reason       = reason == "" and "No reason given." or "Reason: "..reason

			addEvent(self, "loginfail", "The client has been banned from AniDB.\n"..reason)
			self.onLogin(false)

		-- 505 555 598 600 601 602 604 [501 502 506]
		else
			addEvent(self, "loginfail", "AniDB error "..statusCode..": "..statusText)
			self.onLogin(false)
		end
	end,



	["LOGOUT"] = function(msg, self, ok, statusCode, statusText, entries)
		if not ok then
			addEvent(self, "logoutfail", "Something went wrong while logging out. Check the log.")

		-- 203 LOGGED OUT
		elseif statusCode == 203 then
			dropSession(self)
			addEvent(self, "logoutsuccess")

		-- 403 NOT LOGGED IN
		elseif statusCode == 403 then
			_logprinterror("Tried to log out, but we weren't logged in.")
			dropSession(self)
			addEvent(self, "logoutsuccess") -- Still count as success.

		-- 505 555 598 600 601 602 604 [501 502 506]
		else
			addEvent(self, "logoutfail", "AniDB error "..statusCode..": "..statusText)
		end
	end,



	["MYLIST"] = function(msg, self, ok, statusCode, statusText, entries)
		if not ok then
			addEvent(self, "mylistgetfail", "Something went wrong while retrieving mylist entries. Check the log.")

		-- 221 MYLIST\nint4 lid|int fid|int eid|int aid|int gid|int date|int state|int viewdate|str storage|str source|str other|int filestate
		elseif statusCode == 221 then
			local nextField = arrayIterator(entries[1])

			local lid = paramNumberDecode(nextField())

			local mylistEntry = {
				id        = lid,
				lid       = lid,
				fid       = paramNumberDecode(nextField()),
				eid       = paramNumberDecode(nextField()),
				aid       = paramNumberDecode(nextField()),
				gid       = paramNumberDecode(nextField()),
				date      = paramNumberDecode(nextField()),
				state     = paramNumberDecode(nextField()),
				viewdate  = paramNumberDecode(nextField()),
				storage   = paramStringDecode(nextField()),
				source    = paramStringDecode(nextField()),
				other     = paramStringDecode(nextField()),
				filestate = paramNumberDecode(nextField()),
				ed2k      = msg.params.ed2k, -- Extra.
				size      = msg.params.size, -- Extra.
				path      = getPathByEd2k(msg.params.ed2k), -- Extra.
			}
			mylistEntry = cacheSave(self, "l", mylistEntry, false)

			addEvent(self, "mylistgetsuccess", "entry", mylistEntry)

		-- 312 MULTIPLE MYLIST ENTRIES\nstr anime title|int episodes|str eps with state unknown|str eps with state on hhd|str eps with state on cd|str eps with state deleted|str watched eps|str group 1 short name|str eps for group 1|...
		elseif statusCode == 312 then
			local mylistSelection = {
				animeTitle               = paramStringDecode(nextField()), -- 'anime title'
				episodeCount             = paramNumberDecode(nextField()), -- 'episodes'
				episodesWithStateUnknown = parseEpisodes(nextField()),     -- 'eps with state unknown'
				episodesWithStateOnHhd   = parseEpisodes(nextField()),     -- 'eps with state on hhd'
				episodesWithStateOnCd    = parseEpisodes(nextField()),     -- 'eps with state on cd'
				episodesWithStateDeleted = parseEpisodes(nextField()),     -- 'eps with state deleted'
				watchedEpisodes          = parseEpisodes(nextField()),     -- 'watched eps'
				groups                   = {},
			}

			for _ = 1, 10000 do
				local shortName = nextField()
				if not shortName then  break  end

				if shortName == "" then
					_logprinterror("MYLIST 312 can return additional empty fields, apparently.")
					break
				end

				table.insert(mylistSelection.groups, {
					shortName = paramStringDecode(shortName), -- 'group 1 short name'
					episodes  = parseEpisodes(nextField()),   -- 'eps for group 1'
				})
			end

			addEvent(self, "mylistgetsuccess", "selection", mylistSelection)

		-- 321 NO SUCH ENTRY
		elseif statusCode == 321 then
			addEvent(self, "mylistgetsuccess", "none", nil)

		-- 505 555 598 600 601 602 604 [501 502 506]
		else
			addEvent(self, "mylistgetfail", "AniDB error "..statusCode..": "..statusText)
		end
	end,



	["MYLISTADD"] = function(msg, self, ok, statusCode, statusText, entries)
		if not ok then
			addEvent(self, "mylistaddfail", "Something went wrong while adding mylist entries. Check the log.")

		-- 210 MYLIST ENTRY ADDED\nint mylist id of new entry
		-- 210 MYLIST ENTRY ADDED\nint number of entries added
		elseif statusCode == 210 then
			local nextField = arrayIterator(entries[1])

			if msg.params.aid or msg.params.aname then
				local count = paramNumberDecode(nextField())
				addEvent(self, "mylistaddsuccessmultiple", count)
				return
			end

			local lid = paramNumberDecode(nextField())

			local mylistEntryPartial = {
				id        = lid,
				lid       = lid,
				fid       = msg.params.fid, -- May be nil.
				eid       = msg.params.eid, -- May be nil.
				aid       = msg.params.aid, -- May be nil.
				gid       = msg.params.gid, -- May be nil.
				date      = os.time(),
				state     = msg.params.state,
				viewdate  = msg.params.viewdate,
				storage   = msg.params.storage,
				source    = msg.params.source,
				other     = msg.params.other,
				filestate = FILE_STATE_NORMAL_ORIGINAL,
				ed2k      = msg.params.ed2k, -- Extra. May be nil.
				size      = msg.params.size, -- Extra. May be nil.
				path      = getPathByEd2k(msg.params.ed2k), -- Extra. May be nil.
			}
			mylistEntryPartial = cacheSave(self, "l", mylistEntryPartial, true)

			addEvent(self, "mylistaddsuccess", mylistEntryPartial)

		-- 310 FILE ALREADY IN MYLIST\nint lid|int fid|int eid|int aid|int gid|int date|int state|int viewdate|str storage|str source|str other|int filestate
		elseif statusCode == 310 then
			local nextField = arrayIterator(entries[1])

			local lid = paramNumberDecode(nextField())

			local mylistEntry = {
				id        = lid,
				lid       = lid,
				fid       = paramNumberDecode(nextField()),
				eid       = paramNumberDecode(nextField()),
				aid       = paramNumberDecode(nextField()),
				gid       = paramNumberDecode(nextField()),
				date      = paramNumberDecode(nextField()),
				state     = paramNumberDecode(nextField()),
				viewdate  = paramNumberDecode(nextField()),
				storage   = paramStringDecode(nextField()),
				source    = paramStringDecode(nextField()),
				other     = paramStringDecode(nextField()),
				filestate = paramNumberDecode(nextField()),
				ed2k      = msg.params.ed2k, -- Extra.
				size      = msg.params.size, -- Extra.
				path      = getPathByEd2k(msg.params.ed2k), -- Extra.
			}
			mylistEntry = cacheSave(self, "l", mylistEntry, false)

			addEvent(self, "mylistaddsuccess", mylistEntry)

			-- Also trigger a "get" event, as we may only have had a partial entry before, and now we got a full one.
			addEvent(self, "mylistgetsuccess", "entry", mylistEntry)

		-- 311 MYLIST ENTRY EDITED
		-- 311 MYLIST ENTRY EDITED\nint number of entries edited
		elseif statusCode == 311 then
			local nextField = arrayIterator(entries[1])

			if msg.params.aid or msg.params.aname then
				local count = paramNumberDecode(nextField())
				addEvent(self, "mylistaddsuccessmultiple", count)
				return
			end

			local mylistEntryMaybePartial
				=  msg.params.fid and (
					itemWith(self.cache.l,        "fid",msg.params.fid) or
					itemWith(self.cachePartial.l, "fid",msg.params.fid)
				)
				or msg.params.ed2k and (
					itemWith2(self.cache.l,        "ed2k",msg.params.ed2k, "size",msg.params.size) or
					itemWith2(self.cachePartial.l, "ed2k",msg.params.ed2k, "size",msg.params.size)
				)
				or msg.params.lid and (
					itemWith2(self.cache.l,        "lid",msg.params.lid, "size",msg.params.size) or
					itemWith2(self.cachePartial.l, "lid",msg.params.lid, "size",msg.params.size)
				)

			addEvent(self, "mylistaddsuccess", mylistEntryMaybePartial)

		-- 320 NO SUCH FILE
		elseif statusCode == 320 and msg.params.ed2k then
			addEvent(self, "mylistaddfail", "No file on AniDB with size %.0f and hash %s.", msg.params.size, msg.params.ed2k)
		elseif statusCode == 320 and msg.params.fid then
			addEvent(self, "mylistaddfail", "No file on AniDB with ID %d.", msg.params.fid)

		-- 322 MULTIPLE FILES FOUND\nint fid 1|int fid 2|...|int fid n
		elseif statusCode == 322 then
			local fids = {}

			for _, fidStr in ipairs(entries[1]) do
				local fid = paramNumberDecode(fidStr)
				if fid then
					table.insert(fids, fid)
				else
					_logprinterror("Bad file ID value '%s'.", fidStr)
				end
			end

			addEvent(self, "mylistaddfoundmultiplefiles", fids)

		-- 330 NO SUCH ANIME
		elseif statusCode == 330 and msg.params.aid then
			addEvent(self, "mylistaddfail", "No anime on AniDB with ID %d.", msg.params.aid)

		-- 350 NO SUCH GROUP
		elseif statusCode == 350 and msg.params.gid then
			addEvent(self, "mylistaddfail", "No group on AniDB with ID %d.", msg.params.gid)

		-- 411 NO SUCH MYLIST ENTRY
		elseif statusCode == 411 then
			addEvent(self, "mylistaddfail", "No mylist entry with ID %d.", msg.params.lid)

		-- 505 555 598 600 601 602 604 [501 502 506]
		else
			addEvent(self, "mylistaddfail", "AniDB error "..statusCode..": "..statusText)
		end
	end,



	["MYLISTDEL"] = function(msg, self, ok, statusCode, statusText, entries)
		if not ok then
			addEvent(self, "mylistdeletefail", "Something went wrong while deleting mylist entries. Check the log.")

		-- 211 MYLIST ENTRY DELETED\nint number of entries
		elseif statusCode == 211 then
			local nextField = arrayIterator(entries[1])
			local count     = paramNumberDecode(nextField())

			if msg.params.lid then
				local mylistEntryMaybePartial
					=  itemWith(self.cache.l,        "lid", msg.params.lid)
					or itemWith(self.cachePartial.l, "lid", msg.params.lid)

				if mylistEntryMaybePartial then
					cacheDelete(self, "l", mylistEntryMaybePartial)
				end

			elseif msg.params.fid then
				local mylistEntryMaybePartial
					=  itemWith(self.cache.l,        "fid", msg.params.fid)
					or itemWith(self.cachePartial.l, "fid", msg.params.fid)

				if mylistEntryMaybePartial then
					cacheDelete(self, "l", mylistEntryMaybePartial)
				end

			elseif msg.params.ed2k then
				local mylistEntryMaybePartial
					=  itemWith2(self.cache.l,        "ed2k",msg.params.ed2k, "size",msg.params.size)
					or itemWith2(self.cachePartial.l, "ed2k",msg.params.ed2k, "size",msg.params.size)

				if mylistEntryMaybePartial then
					cacheDelete(self, "l", mylistEntryMaybePartial)
				end

			-- elseif msg.params.aname then
				-- @Incomplete: Delete MyList entries by aname.
				-- MYLISTDEL aname={str anime name}[&gname={str group name}&epno={int4 episode number}]
				-- MYLISTDEL aname={str anime name}[&gid={int4 group id}&epno={int4 episode number}]

			-- elseif msg.params.aid then
				-- @Incomplete: Delete MyList entries by aid.
				-- MYLISTDEL aid={int4 anime id}[&gname={str group name}&epno={int4 episode number}]
				-- MYLISTDEL aid={int4 anime id}[&gid={int4 group id}&epno={int4 episode number}]

			else
				_logprinterror("MyList entries were deleted but can't determine what.")
			end

			addEvent(self, "mylistdeletesuccess", count)

		-- 411 NO SUCH MYLIST ENTRY
		elseif statusCode == 411 then
			addEvent(self, "mylistdeletefail", "No mylist entry with ID %d.", msg.params.lid)

		-- 505 555 598 600 601 602 604 [501 502 506]
		else
			addEvent(self, "mylistdeletefail", "AniDB error "..statusCode..": "..statusText)
		end
	end,



}
--==============================================================
--= Methods ====================================================
--==============================================================



function Anidb:init()
	self.messages  = {}
	self.theEvents = {}

	self.previousResponseTimes = {}

	self.cache = {
		l = {byId={}}, -- 'lid' MyList entries.
		f = {byId={}}, -- 'fid' Files.
		e = {byId={}}, -- 'eid' Episodes.
		a = {byId={}}, -- 'aid' Animes.
		g = {byId={}}, -- 'gid' Groups.
	}
	self.cachePartial = {
		l = {byId={}},
		f = {byId={}},
		e = {byId={}},
		a = {byId={}},
		g = {byId={}},
	}

	self.mylistDefaults = {
		state   = nil,--MYLIST_STATE_INTERNAL_STORAGE,
		viewed  = nil,--true,
		source  = nil,--"",
		storage = nil,--"",
		other   = nil,--"",
	}

	self.udp = assert(socket.udp())

	assert(self.udp:setsockname("*", LOCAL_PORT))
	assert(self.udp:setpeername(SERVER_ADDRESS, SERVER_PORT))

	self.udp:settimeout(0)

	assert(createDirectory("local"))
	assert(createDirectory(CACHE_DIR))

	loadBlackout(self)
	loadNatInfo(self)

	for name in directoryItems(CACHE_DIR) do
		local pageName, id = name:match"^(%l)(%d+)$"
		if pageName then
			cacheLoad(self, pageName, tonumber(id), false)

		else
			pageName, id = name:match"^(%l)(%d+)%.part$"
			if pageName then
				cacheLoad(self, pageName, tonumber(id), true)
			end
		end
	end
end



function Anidb:getLogin()
	if DEBUG_LOCAL then  return "MyName", "ABC123"  end

	local file, err = openFile("local/login", "r")
	if not file then
		_logprinterror("Could not open file 'local/login': %s", err)
		return nil
	end

	local iter = file:lines"local/login"
	local user = iter() or ""
	local pass = iter() or ""

	file:close()

	if not (user ~= "" and pass ~= "") then
		_logprinterror("Missing at least one of username or password lines in login file.")
		return nil
	end
	return user, pass
end



-- Should only be called internally!
function Anidb:ping()
	if self.messages[1] then  return  end

	-- PING [nat=1]
	local params = {}

	if self.natMode ~= NAT_MODE_OFF then
		params["nat"] = BOOL_TRUE
	end

	send(self, "PING", params)
end



-- Should only be called internally!
function Anidb:login()
	if self:isLoggedIn() then
		self.onLogin(true)
		return
	end

	if isMessageInQueue(self, "AUTH") then
		return
	end

	local user, pass = self:getLogin()

	-- AUTH user=str&pass=str&protover=int&client=str&clientver=int[&nat=1&comp=1&enc=str&mtu=int&imgserver=1]
	local params = {
		["user"]      = user,
		["pass"]      = pass,
		["protover"]  = PROTOCOL_VERSION,
		["client"]    = CLIENT_NAME,
		["clientver"] = CLIENT_VERSION,
	}

	if self.natMode ~= NAT_MODE_OFF then
		params["nat"] = BOOL_TRUE
	end

	send(self, "AUTH", params, true)
end

function Anidb:logout()
	if not self:isLoggedIn() or isMessageInQueue(self, "LOGOUT") then  return  end

	-- LOGOUT s=str
	local params = {
		["s"] = "",
	}

	send(self, "LOGOUT", params)
end



-- getMylistByFile( path )
-- getMylistByFile( fileId )
function Anidb:getMylistByFile(pathOrFileId)
	assertarg(1, pathOrFileId, "string","number")

	if type(pathOrFileId) == "string" then
		local path = pathOrFileId

		getEd2k(self, path, function(ed2kState, ed2kHash, fileSize)
			if ed2kState == ED2K_STATE_SUCCESS then
				self:getMylistByEd2k(ed2kHash, fileSize)
			end
		end)

	else
		local fileId = pathOrFileId
		_logprinterror("@Incomplete: getMylistByFile(fileId)")
	end
end

function Anidb:getMylistByEd2k(ed2kHash, fileSize)
	assertarg(1, ed2kHash, "string")
	assertarg(2, fileSize, "number")

	for _, msg in ipairs(self.messages) do
		if msg.command == "MYLIST" and msg.params.size == fileSize and msg.params.ed2k == ed2kHash then
			return
		end
	end

	local mylistEntry = itemWith2(self.cache.l, "ed2k",ed2kHash, "size",fileSize)
	if mylistEntry then
		addEvent(self, "mylistgetsuccess", "entry", mylistEntry)
		return
	end

	-- MYLIST size=int&ed2k=str&s=str
	local params = {
		["size"] = fileSize,
		["ed2k"] = ed2kHash,
		["s"]    = "",
	}

	self:login()
	send(self, "MYLIST", params)
end



-- addMylistByFile( path )
-- addMylistByFile( fileId )
function Anidb:addMylistByFile(pathOrFileId)
	assertarg(1, pathOrFileId, "string","number")

	if type(pathOrFileId) == "string" then
		local path = pathOrFileId

		getEd2k(self, path, function(ed2kState, ed2kHash, fileSize)
			if ed2kState == ED2K_STATE_SUCCESS then
				self:addMylistByEd2k(ed2kHash, fileSize)
			end
		end)

	else
		local fileId = pathOrFileId
		_logprinterror("@Incomplete: addMylistByFile(fileId)")
	end
end

function Anidb:addMylistByEd2k(ed2kHash, fileSize)
	assertarg(1, ed2kHash, "string")
	assertarg(2, fileSize, "number")

	for _, msg in ipairs(self.messages) do
		if msg.command == "MYLISTADD" and msg.params.size == fileSize and msg.params.ed2k == ed2kHash then
			return
		end
	end

	local mylistEntryMaybePartial
		=  itemWith2(self.cache.l,        "ed2k",ed2kHash, "size",fileSize)
		or itemWith2(self.cachePartial.l, "ed2k",ed2kHash, "size",fileSize)

	if mylistEntryMaybePartial then
		addEvent(self, "mylistaddsuccess", mylistEntryMaybePartial)
		return
	end

	-- MYLISTADD size=int&ed2k=str&s=str[&state=int&viewed=bool&viewdate=int&source=str&storage=str&other=str]
	local params = {
		["size"] = fileSize,
		["ed2k"] = ed2kHash,
		["s"]    = "",
	}

	local defaults = self.mylistDefaults
	if defaults.state     ~= nil then
		params["state"]    = defaults.state
	end
	if defaults.viewed    ~= nil then
		params["viewed"]   = defaults.viewed
		params["viewdate"] = defaults.viewed and os.time() or nil
	end
	if defaults.source    ~= nil then
		params["source"]   = defaults.source
	end
	if defaults.storage   ~= nil then
		params["storage"]  = defaults.storage
	end
	if defaults.other     ~= nil then
		params["other"]    = defaults.other
	end

	self:login()
	send(self, "MYLISTADD", params)
end



function Anidb:deleteMylist(lid)
	assertarg(1, lid, "number")

	for _, msg in ipairs(self.messages) do
		if msg.command == "MYLISTDEL" and msg.params.lid == lid then
			return
		end
	end

	-- MYLISTDEL lid=int&s=str
	local params = {
		["lid"] = lid,
		["s"]   = "",
	}

	self:login()
	send(self, "MYLISTDEL", params)
end



function Anidb:update(force)
	local time = getTime()

	if self.isInBlackout and time >= self.blackoutUntil then
		self.isInBlackout = false
		addEvent(self, "blackoutstop")
	end

	-- Handle responses.
	for data in receive(self) do
		if data:find"^%z%z" then
			data = decompress(data)
		end

		if DEBUG_LOCAL and not (data:find"^#" or data:find"^%d%d%d") then
			require"fakeServer"(self.udp, data)

		else
			logprint("IO", "<-- "..makePrintable(data))
			handleServerResponse(self, data)
		end
	end

	-- Time-out old messages.
	for _, msg in ipairsr(self.messages) do
		if msg.stage == MESSAGE_STAGE_SENT and time-msg.timeSent > SERVER_RESPONSE_TIMEOUT then
			_logprinterror("%s message timed out.", msg.command)

			msg.stage = MESSAGE_STAGE_RESPONSE_TIMEOUT
			removeMessage(self, msg)

			addEvent(self, "errorresponsetimeout", msg.command)
			msg:callback(self, false)
		end
	end

	-- Send next message.
	local msg = getNextMessageToSend(self, force)
	if msg then
		if msg.params.s then
			msg.params.s = self.sessionKey -- Should we check if sessionKey is empty?
		end

		local data = createData(msg.command, msg.params)

		if #data > MAX_DATA_LENGTH then
			_logprinterror("Data for %s command is too long. (length: %.0f, max: %d)", msg.command, #data, MAX_DATA_LENGTH)
			msg:callback(self, false)

		else
			msg.stage    = MESSAGE_STAGE_SENT
			msg.tries    = msg.tries+1
			msg.timeSent = time

			logprint("IO", "--> "..makePrintable(data))
			check(self.udp:send(data))
		end
	end

	-- Send ping.
	if self.isActive and time > self.responseTimeLast+self.pingDelay and not isAnyMessageInTransit(self) then
		self:ping()
	end
end



-- for eventName, value1, ... in events( anidb ) do
function Anidb:events()
	local es = self.theEvents
	return function()
		if es[1] then  return unpack(table.remove(es, 1))  end
	end
end



function Anidb:isLoggedIn()
	-- Note: The session might have expired on the server.
	return self.sessionKey ~= ""
end



function Anidb:isSendingAnyMessage()
	return isAnyMessageInTransit(self)
end

function Anidb:getQueuedMessageCount()
	local count = 0
	for _, msg in ipairs(self.messages) do
		if msg.stage == MESSAGE_STAGE_QUEUE then
			count = count+1
		end
	end
	return count
end



function Anidb:clearMessageQueue()
	for _, msg in ipairsr(self.messages) do
		if msg.stage == MESSAGE_STAGE_QUEUE then
			_logprint("%s message aborted.", msg.command)

			msg.stage = MESSAGE_STAGE_ABORTED
			removeMessage(self, msg)

			msg:callback(self, false)
		end
	end
end



function Anidb:hashFile(path)
	assertarg(1, path, "string")
	getEd2k(self, path, NOOP)
end



--==============================================================
--==============================================================
--==============================================================

return function(...)
	local anidb = setmetatable({}, Anidb)
	anidb:init(...)
	return anidb
end
