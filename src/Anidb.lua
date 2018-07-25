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
	isLoggedIn
	isSendingAnyMessage, getQueuedMessageCount
	update

	-- Server communication.
	fetchMylistByFile, fetchMylistByEd2k
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

local CACHE_DIR                       = DEBUG_LOCAL and "cacheDebug" or "cache"



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

	-- Internal events:
	onLogin           = NOOP,
}
Anidb.__index = Anidb



--==============================================================
--= Local Functions ============================================
--==============================================================

local _logprint, _logprinterror
local addEvent
local addParamPair
local addToSendQueue, receive
local blackout, loadBlackout
local cacheSave, cacheLoad
local compress, decompress
local createParamsAndData
local dropSession
local generateTag
local getMessage, addMessage, removeMessage
local getNextMessageToSend
local handleServerResponse
local isAnyMessageInTransit, isMessageInQueue
local onInternal
local paramStringEncode, paramStringDecode, paramNumberEncode, paramNumberDecode, paramBooleanEncode, paramBooleanDecode, parseEpisodes
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
	return F("%d", n)
end
function paramNumberDecode(v)
	if v:find"%D" then  return nil  end
	return tonumber(v) -- Returns nil if the value is "".
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

function parseEpisodes(s)
	local eps = {}

	for epSeq in s:gmatch"[^,]+" do
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



function addToSendQueue(self, command, paramPairs, cb)
	assertarg(1, self,       "table")
	assertarg(2, command,    "string")
	assertarg(3, paramPairs, "table")
	assertarg(4, cb,         "function")

	_logprint("Queuing "..command..".")

	local tag = generateTag()
	addParamPair(paramPairs, "tag", tag)

	local params, data = createParamsAndData(command, paramPairs)

	if #data > MAX_DATA_LENGTH then
		_logprinterror("Data for %s command is too long. (length: %d, max: %d)", command, #data, MAX_DATA_LENGTH)
		cb(false)
		return
	end

	local msg = {
		tag            = tag,
		stage          = MESSAGE_STAGE_QUEUE,
		tries          = 0,
		dontSendBefore = -1,

		command        = command,
		params         = params,
		paramPairs     = paramPairs,
		callback       = cb,

		data           = data,

		timeSent       = -1,
		timeResponded  = -1,
	}
	addMessage(self, msg)
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



function createParamsAndData(command, paramPairs)
	local queryParts = {}
	local params     = {}

	for i = 1, #paramPairs, 2 do
		local param = paramPairs[i]
		local v     = paramPairs[i+1]

		if type(v) == "string" then
			table.insert(queryParts, F("%s=%s", param, paramStringEncode(v)))

		elseif type(v) == "number" then
			table.insert(queryParts, F("%s=%s", param, paramNumberEncode(v)))

		elseif type(v) == "boolean" then
			table.insert(queryParts, F("%s=%s", param, paramBooleanEncode(v)))

		else
			errorf("[AniDB.internal] Cannot encode values of type '%s'.", type(v))
		end

		params[param] = v
	end

	local data = F("%s %s", command, table.concat(queryParts, "&"))

	return params, data
end



do
	local tags = {}

	function generateTag()
		local tag
		repeat
			tag = F("#%07x", math.random(0xFFFFFFF))
		until not tags[tag]

		tags[tag] = true
		return tag
	end
end



function compress(s)
	error("[AniDB.internal] Cannot handle compression yet.")
end

function decompress(s)
	error("[AniDB.internal] Cannot handle compression yet.")
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

		for i = 1, #msg.paramPairs, 2 do
			if msg.paramPairs[i] == "tag" then
				msg.paramPairs[i+1] = tag
			elseif msg.paramPairs[i] == "s" then
				msg.paramPairs[i+1] = self.sessionKey
			end
		end

		local params, data = createParamsAndData(msg.command, msg.paramPairs)

		if #data > MAX_DATA_LENGTH then
			_logprinterror("Data for %s command is too long. (length: %d, max: %d)", msg.command, #data, MAX_DATA_LENGTH)
			msg.callback(false)
			return
		end

		msg.tag    = tag
		msg.stage  = MESSAGE_STAGE_QUEUE

		msg.params = params
		msg.data   = data

		if doDelay then
			msg.dontSendBefore = getTime()+(DELAY_BEFORE_RESENDING[msg.tries] or DELAY_BEFORE_RESENDING.last)
		end

		-- Should 'first' be true? Maybe we should try to preserve the original position? Maybe it doesn't matter.
		addMessage(self, msg, true)

		addEvent(self, "resend", msg.command)
	end

	local function loginAndResendMessage(self, msg)
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
			_logprinterror("Server response is empty. (Length: %d)", #data)
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
			msg.callback(false)
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
			dropSession(self)
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
			local err
				=  statusText:match"%- (.+)"
				or (entries[1][1] or ""):match"^ERROR: (.+)"
				or ""

			local function errorEvent(eName, s)
				if err ~= "" then
					s = F("%s\nError message: ", s)
				end
				addEvent(self, eName, s)
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

		msg.callback(true, statusCode, statusText, entries)
		return true
	end
end



function addParamPair(paramPairs, param, v)
	table.insert(paramPairs, param)
	table.insert(paramPairs, v)
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

	assert(not self.messages[msg.tag])

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
		local pingDelay = self.pingDelay
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
	if not contents then return end

	local pingDelay, natLimitLower, natLimitUpper = contents:match"^(%d+) (%-?%d+) (%-?%d+)$"
	if not pingDelay then
		_logprinterror("Bad format of file '%s/nat'.", CACHE_DIR)
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



-- Note: The entry will overwrite any previous one with the same ID.
function cacheSave(self, pageName, entry)
	local id   = entry.id
	local path = F("%s/%s%d", CACHE_DIR, pageName, id)

	-- Backup old entry.
	if isFile(path) then
		writeFile(path..".bak", getFileContents(path))
	end

	local keys      = sortNatural(getKeys(entry))
	local maxKeyLen = 0

	for _, k in ipairs(keys) do
		maxKeyLen = math.max(maxKeyLen, #k)
	end

	local file = assert(io.open(path, "w"))

	for _, k in ipairs(keys) do
		local v = entry[k]

		if type(v) == "number" then
			if not isInt(v) then
				_logprinterror("%s: Cannot write non-integer numbers. Skipping. (%s, entry.%s)", path, tostring(v), k)
			else
				file:write(k, (" "):rep(maxKeyLen - #k + 1))
				file:write(F("%d\n", v))
			end

		elseif type(v) == "string" then
			local s = F("%q", v) :gsub("\\\n", "\\n")
			file:write(k, (" "):rep(maxKeyLen - #k + 1))
			file:write(s, "\n")

		elseif type(v) == "boolean" then
			file:write(k, (" "):rep(maxKeyLen - #k + 1))
			file:write(tostring(v), "\n")

		else
			_logprinterror("%s: Cannot write type '%s'. Skipping. (entry.%s)", path, type(v), k)
		end
	end

	file:close()

	local page = self.cache[pageName]

	if page.byId[id] then
		local i = indexWith(page, "id", entry.id)

		if not i then
			errorf("Cache page '%s' is out of sync regarding entry %d.", pageName, id)
		else
			page.byId[id] = entry
			page[i]       = entry
		end

	else
		page.byId[id] = entry
		table.insert(page, entry)
	end
end

do
	local function parseValue(path, ln, v)
		local c = v:sub(1, 1)

		-- Number.
		if ("0123456789"):find(c, 1, true) then
			local n = tonumber(v)
			if not n then
				_logprinterror("%s:%d: Malformed number: %s", path, ln, v)
				return nil
			end
			return n

		-- String.
		elseif c == '"' then
			local chunk, err = loadstring("return"..v)
			if not chunk then
				_logprinterror("%s:%d: Malformed string: %s: %s", path, ln, err, v)
				return nil
			end

			local s = chunk()
			if type(s) ~= "string" then
				_logprinterror("%s:%d: Malformed string: %s", path, ln, v)
				return nil
			end
			return s

		-- Boolean.
		elseif v == "true" then
			return true
		elseif v == "false" then
			return false

		else
			_logprinterror("%s:%d: Unknown value type: %s", path, ln, v)
			return nil
		end
	end

	function cacheLoad(self, pageName, id)
		local page  = self.cache[pageName]
		local entry = page.byId[id]

		if entry then
			_logprinterror("Tried to load already loaded '%s' entry %d.", pageName, id)
			return entry
		end

		local path = F("%s/%s%d", CACHE_DIR, pageName, id)

		local file, err = io.open(path, "r")
		if not file then  return nil, err  end

		entry    = {}
		local ln = 0

		for line in file:lines() do
			ln = ln+1

			if line ~= "" then
				local k, v = line:match"^(%S+) +(%S.*)$"

				if not k then
					_logprinterror("%s:%d: Bad line format: %s", path, ln, line)

				else
					if entry[k] ~= nil then
						_logprinterror("%s:%d: Duplicate key '%s'. Overwriting.", path, ln, k)
					end
					entry[k] = parseValue(path, ln, v)
				end
			end
		end

		file:close()

		page.byId[id] = entry
		table.insert(page, entry)

		return entry
	end
end



--==============================================================
--= Methods ====================================================
--==============================================================



function Anidb:init()
	self.messages  = {}
	self.theEvents = {}

	self.cache = {
		l = {byId={}}, -- 'lid' MyList entries.
		f = {byId={}}, -- 'fid' Files.
		e = {byId={}}, -- 'eid' Episodes.
		a = {byId={}}, -- 'aid' Animes.
		g = {byId={}}, -- 'gid' Groups.
	}

	self.previousResponseTimes = {}

	self.udp = assert(socket.udp())

	assert(self.udp:setsockname("*", LOCAL_PORT))
	assert(self.udp:setpeername(SERVER_ADDRESS, SERVER_PORT))

	self.udp:settimeout(0)

	assert(createDirectory("local"))
	assert(createDirectory(CACHE_DIR))

	loadBlackout(self)
	loadNatInfo(self)

	for name in lfs.dir(CACHE_DIR) do
		local pageName, id = name:match"^(%l)(%d+)$"
		if pageName then
			cacheLoad(self, pageName, tonumber(id))
		end
	end
end



function Anidb:getLogin()
	if DEBUG_LOCAL then  return "MyName", "ABC123"  end

	local file, err = io.open("local/login", "r")
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
	local paramPairs = {}

	if self.natMode ~= NAT_MODE_OFF then
		addParamPair(paramPairs, "nat", BOOL_TRUE)
	end

	addToSendQueue(self, "PING", paramPairs, function(ok, statusCode, statusText, entries)
		-- 300 PONG
		-- Also 505 555 598 600 601 602 604 [501 502 506].

		if not ok then
			addEvent(self, "pingfail", "Something went wrong while sending ping. Check the log.")

		elseif statusCode == 300 then
			if self.natMode ~= NAT_MODE_OFF then
				local port = tonumber(entries[1][1])

				if not port then
					_logprinterror("Expected NAT information from PING request.")
				else
					updateNatInfo(self, port)
				end
			end

		else
			addEvent(self, "pingfail", "AniDB error "..statusCode..": "..statusText)
		end
	end)
end

-- Should only be called internally!
function Anidb:login()
	if self.sessionKey ~= "" then
		-- Already logged in.
		self.onLogin(true)
		return
	end
	if isMessageInQueue(self, "AUTH") then
		return
	end

	local user, pass = self:getLogin()

	-- AUTH user={str}&pass={str}&protover={int4}&client={str}&clientver={int4}[&nat=1&comp=1&enc={str}&mtu={int4}&imgserver=1]
	local paramPairs = {
		"user",      user,
		"pass",      pass,
		"protover",  PROTOCOL_VERSION,
		"client",    CLIENT_NAME,
		"clientver", CLIENT_VERSION,
	}

	if self.natMode ~= NAT_MODE_OFF then
		addParamPair(paramPairs, "nat", BOOL_TRUE)
	end

	addToSendQueue(self, "AUTH", paramPairs, function(ok, statusCode, statusText, entries)
		-- 200 {str session_key} LOGIN ACCEPTED
		-- 201 {str session_key} LOGIN ACCEPTED - NEW VERSION AVAILABLE
		-- 500 LOGIN FAILED
		-- 503 CLIENT VERSION OUTDATED
		-- 504 CLIENT BANNED - {str reason}
		-- If nat=1:
		-- 200 {str session_key} {str ip}:{int2 port} LOGIN ACCEPTED
		-- 201 {str session_key} {str ip}:{int2 port} LOGIN ACCEPTED - NEW VERSION AVAILABLE
		-- Also 505 555 598 600 601 602 604 [501 502 506].

		if not ok then
			addEvent(self, "loginfail", "Something went wrong while logging in. Check the log.")
			self.onLogin(false)

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

		elseif statusCode == 500 then
			addEvent(self, "loginbadlogin")
			self.onLogin(false)

		elseif statusCode == 503 then
			addEvent(self, "loginfail", "MyHappyList is outdated. Please download the newest version.")
			self.onLogin(false)

		elseif statusCode == 504 then
			local reason = trim(statusText:match"%- (.+)" or "")
			reason       = reason == "" and "No reason given." or "Reason: "..reason

			addEvent(self, "loginfail", "The client has been banned from AniDB.\n"..reason)
			self.onLogin(false)

		else
			addEvent(self, "loginfail", "AniDB error "..statusCode..": "..statusText)
			self.onLogin(false)
		end
	end)
end

function Anidb:logout()
	if not self:isLoggedIn() or isMessageInQueue(self, "LOGOUT") then  return  end

	-- LOGOUT s={str session_key}
	local paramPairs = {
		"s", self.sessionKey,
	}

	addToSendQueue(self, "LOGOUT", paramPairs, function(ok, statusCode, statusText, entries)
		-- 203 LOGGED OUT
		-- 403 NOT LOGGED IN
		-- Also 505 555 598 600 601 602 604 [501 502 506].

		if not ok then
			addEvent(self, "logoutfail", "Something went wrong while logging out. Check the log.")

		elseif statusCode == 203 then
			dropSession(self)
			addEvent(self, "logoutsuccess")

		elseif statusCode == 403 then
			_logprinterror("Tried to log out, but we weren't logged in.")
			dropSession(self)
			addEvent(self, "logoutsuccess") -- Still count as success.

		else
			addEvent(self, "logoutfail", "AniDB error "..statusCode..": "..statusText)
		end
	end)
end

-- fetchMylistByFile( path )
-- fetchMylistByFile( fileId )
local pathEd2ks = {}
local pathSizes = {}
function Anidb:fetchMylistByFile(pathOrFileId)
	assertarg(1, pathOrFileId, "string","number")

	if type(pathOrFileId) == "string" then
		local path     = pathOrFileId
		local fileSize = lfs.attributes(path, "size")

		if not fileSize then
			_logprinterror("No file at path '%s' (or could not get the file size).", path)
			return
		end

		local ed2kHash = pathEd2ks[path]

		if ed2kHash then
			if ed2kHash == "" then
				-- The ed2k is already being calculated.
				return

			elseif pathSizes[path] ~= fileSize then
				_logprinterror(
					"%s: Somehow we have the ed2k but the size is wrong. Recalculating. (expected %d, got %d)",
					path, pathSizes[path], fileSize
				)
				pathEd2ks[path] = nil
				pathSizes[path] = nil

			else
				-- Both ed2ks and size match previous values.
				self:fetchMylistByEd2k(ed2kHash, fileSize)
				return
			end
		end

		pathEd2ks[path] = "" -- An empty string means "currently calculating".
		_logprint("Calculating ed2k for '%s'...", path:match"[^/\\]+$")

		scriptCaptureAsync("ed2k", function(output)
			ed2kHash = output:match"^ed2k: ([%da-f]+)"

			if not ed2kHash then
				_logprinterror("Calculating ed2k for '%s' failed: %s", path:match"[^/\\]+$", output)

				pathEd2ks[path] = nil
				pathSizes[path] = nil

				return
			end

			_logprint("Calculating ed2k for '%s'... %s", path:match"[^/\\]+$", ed2kHash)
			-- printf("ed2k://|file|%s|%d|%s|/", path:match"[^/\\]+$", fileSize, ed2kHash)

			pathEd2ks[path] = ed2kHash
			pathSizes[path] = fileSize

			self:fetchMylistByEd2k(ed2kHash, fileSize)
		end, path)

	else--if type(pathOrFileId) == "number" then
		local fileId = pathOrFileId
		_logprinterror("@Incomplete: fetchMylistByFile(fileId)")
	end
end

function Anidb:fetchMylistByEd2k(ed2kHash, fileSize)
	assertarg(1, ed2kHash, "string")
	assertarg(2, fileSize, "number")

	for _, msg in ipairs(self.messages) do
		if msg.command == "MYLIST" and msg.params.size == fileSize and msg.params.ed2khash == ed2kHash then
			return
		end
	end

	local mylistEntry = itemWith2(self.cache.l, "ed2k",ed2kHash, "size",fileSize)
	if mylistEntry then
		addEvent(self, "mylistsuccess", "entry", mylistEntry)
		return
	end

	-- MYLIST size={int4 size}&ed2k={str ed2khash}&s={str session_key}
	local paramPairs = {
		"size",     fileSize,
		"ed2khash", ed2kHash,
		"s",        self.sessionKey,
	}

	addToSendQueue(self, "MYLIST", paramPairs, function(ok, statusCode, statusText, entries)
		-- 221 MYLIST\n{int4 lid}|{int4 fid}|{int4 eid}|{int4 aid}|{int4 gid}|{int4 date}|{int2 state}|{int4 viewdate}|{str storage}|{str source}|{str other}|{int2 filestate}
		-- 312 MULTIPLE MYLIST ENTRIES\n{str anime title}|{int episodes}|{str eps with state unknown}|{str eps with state on hhd}|{str eps with state on cd}|{str eps with state deleted}|{str watched eps}|{str group 1 short name}|{str eps for group 1}|...
		-- 321 NO SUCH ENTRY
		-- Also 505 555 598 600 601 602 604 [501 502 506].

		if not ok then
			addEvent(self, "mylistfail", "Something went wrong while retrieving mylist entries. Check the log.")

		elseif statusCode == 221 then
			local nextField = arrayIterator(entries[1])

			local mylistEntry = {
				id        = paramNumberDecode(nextField()), -- 'lid'       MyList entry ID.
				fileId    = paramNumberDecode(nextField()), -- 'fid'
				episodeId = paramNumberDecode(nextField()), -- 'eid'
				animeId   = paramNumberDecode(nextField()), -- 'aid'
				groupId   = paramNumberDecode(nextField()), -- 'gid'
				addedDate = paramNumberDecode(nextField()), -- 'date'      Unix time.
				state     = paramNumberDecode(nextField()), -- 'state'     State of entry (NOT file state).
				viewDate  = paramNumberDecode(nextField()), -- 'viewdate'
				storage   = paramStringDecode(nextField()), -- 'storage'   Text, i.e. label of cd with this file.
				source    = paramStringDecode(nextField()), -- 'source'    Text, i.e. ed2k, dc, ftp, irc...
				other     = paramStringDecode(nextField()), -- 'other'     Note.
				fileState = paramNumberDecode(nextField()), -- 'filestate'
				-- Extra:
				ed2k      = ed2kHash,
				size      = fileSize,
			}
			printobj("mylistEntry", mylistEntry)
			cacheSave(self, "l", mylistEntry)

			addEvent(self, "mylistsuccess", "entry", mylistEntry)

		elseif statusCode == 312 then
			local mylistSelection = {
				animeTitle               = paramStringDecode(nextField()),
				episodeCount             = paramNumberDecode(nextField()),
				episodesWithStateUnknown = parseEpisodes(nextField()),
				episodesWithStateOnHhd   = parseEpisodes(nextField()),
				episodesWithStateOnCd    = parseEpisodes(nextField()),
				episodesWithStateDeleted = parseEpisodes(nextField()),
				watchedEpisodes          = parseEpisodes(nextField()),
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
					shortName = paramStringDecode(shortName),
					episodes  = parseEpisodes(nextField()),
				})
			end

			printobj("mylistSelection", mylistSelection)

			addEvent(self, "mylistsuccess", "selection", mylistSelection)

		elseif statusCode == 321 then
			addEvent(self, "mylistsuccess", "none", nil)

		else
			addEvent(self, "mylistfail", "AniDB error "..statusCode..": "..statusText)
		end
	end)
end



function Anidb:update(force)
	local time = getTime()

	if self.isInBlackout and time >= self.blackoutUntil then
		self.isInBlackout = false
		addEvent(self, "blackoutstop")
	end

	-- Get responses.
	for data in receive(self) do
		if data:find"^%z%z" then
			data = decompress(data)
		end

		if DEBUG_LOCAL and not (data:find"^#" or data:find"^%d%d%d") then
			require"fakeServer"(self.udp, data)

		else
			if DEBUG then  print("<-- "..makePrintable(data))  end

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
			msg.callback(false)
		end
	end

	-- Send next message.
	local msg = getNextMessageToSend(self, force)
	if msg then
		_logprint("Sending "..msg.command..".")
		if DEBUG then  print("--> "..makePrintable(msg.data))  end

		msg.stage    = MESSAGE_STAGE_SENT
		msg.tries    = msg.tries+1
		msg.timeSent = time

		check(self.udp:send(msg.data))
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

			msg.callback(false)
		end
	end
end



--==============================================================
--==============================================================
--==============================================================

return function(...)
	local anidb = setmetatable({}, Anidb)
	anidb:init(...)
	return anidb
end
