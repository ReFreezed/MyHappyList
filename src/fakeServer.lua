--[[============================================================
--=
--=  Server Simulation Module (for debugging)
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

local BOOL_FALSE    = "0"
local BOOL_TRUE     = "1"

local SESSION_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWZYZabcdefghijklmnopqrstuvwzyz"



local port               = -1
local session            = ""
local lastConnectionTime = 0



local function _logprint(s, ...)
	logprint("FakeServer", s, ...)
end
local function _logprinterror(s, ...)
	logprinterror("FakeServer", s, ...)
end



local function startNewSession()
	session = {}

	for i = 1, math.random(4, 8) do
		local j    = math.random(1, #SESSION_CHARS)
		session[i] = SESSION_CHARS:sub(j, j)
	end

	session = table.concat(session)
	_logprint("Started session. (%s)", session)
end

local function checkSession(params, b)
	if session == "" then
		b("501 LOGIN FIRST\n")
		return false

	elseif params["s"] ~= session then
		b("506 INVALID SESSION\n")
		return false

	-- elseif ? then
	-- 	b("502 ACCESS DENIED\n")
	-- 	return false

	else
		return true -- All good.
	end
end



local function parseDataFromClient(data)
	local command, query = data:match"^([A-Z]+) (.*)$"
	if not command then
		_logprinterror("Invalid data format: %s", data)
		return nil, nil
	end

	local params = {}
	local ptr    = 1

	while ptr <= #query do
		local ptrDivider = query:find("=", ptr, true)
		if not ptrDivider then
			_logprinterror("Expected param at position %d.", ptr)
			return command, nil
		end

		local param = query:sub(ptr, ptrDivider-1)
		ptr = ptrDivider+1
		if param == "" then
			_logprinterror("Param name is empty at position %d.", ptr)
			return command, nil
		end

		local ptrValStart = ptr

		while true do
			ptrDivider = query:find("&", ptr, true) or #query+1

			local _, htmlEntityEnd = query:find("^&%a+;", ptrDivider)

			if htmlEntityEnd then
				ptr = htmlEntityEnd+1

			else
				local v = query:sub(ptrValStart, ptrDivider-1)
				ptr = ptrDivider+1
				if v == "" then
					_logprint("Warning: Param '%s' has no value.", param)
				end

				params[param] = v
				break
			end
		end
	end

	return command, params
end



local function newServerResponseBuilder(params)
	local b = newStringBuilder()

	if params["tag"] then
		b(params["tag"])
		b(" ")
	end

	return b
end



local function simulateServerResponse(udp, data)
	local time = getTime()

	if port == -1 then
		-- Simulate NAT.
		port = DEBUG_FORCE_NAT_OFF and LOCAL_PORT or math.random(1025, 50000)

	elseif time > lastConnectionTime+DEBUG_EXPIRATION_TIME_PORT and not DEBUG_FORCE_NAT_OFF then
		-- Simulate NAT.
		_logprint("Port (and session) reset.")
		port    = DEBUG_FORCE_NAT_OFF and LOCAL_PORT or math.random(1025, 50000)
		session = ""

	elseif time > lastConnectionTime+DEBUG_EXPIRATION_TIME_SESSION then
		_logprint("Session reset.")
		session = ""
	end

	lastConnectionTime = time

	local command, params = parseDataFromClient(data)
	-- printobj(command, params)

	if command and not params then
		local b = newServerResponseBuilder(params)
		b("505 ILLEGAL INPUT OR ACCESS DENIED\n")
		check(udp:send(b()))

	-- PING [nat=1]
	elseif command == "PING" then
		local b = newServerResponseBuilder(params)
		b("300 PONG\n")

		if params["nat"] == BOOL_TRUE then
			b("%d", port)
		end
		check(udp:send(b()))

	-- AUTH user={str}&pass={str}&protover={int4}&client={str}&clientver={int4}[&nat=1&comp=1&enc={str}&mtu={int4}&imgserver=1]
	elseif command == "AUTH" then
		startNewSession()

		local b      = newServerResponseBuilder(params)
		local natStr = params["nat"] == BOOL_TRUE and F(" %s:%d", "192.0.2.0", port) or ""

		b("200 %s%s LOGIN ACCEPTED\n", session, natStr)
		-- b("201 %s%s LOGIN ACCEPTED - NEW VERSION AVAILABLE\n", session, natStr)
		-- b("500 LOGIN FAILED\n")
		-- b("503 CLIENT VERSION OUTDATED\n")
		-- b("504 CLIENT BANNED - insert reason here\n")
		-- b("505 ILLEGAL INPUT OR ACCESS DENIED\n")
		-- b("601 ANIDB OUT OF SERVICE - TRY AGAIN LATER\n")

		check(udp:send(b()))

	-- MYLIST lid={int4 lid}
	-- MYLIST fid={int4 fid}
	-- MYLIST size={int4 size}&ed2k={str ed2khash}
	-- MYLIST aname={str anime name}[&gname={str group name}&epno={int4 episode number}]
	-- MYLIST aname={str anime name}[&gid={int4 group id}&epno={int4 episode number}]
	-- MYLIST aid={int4 anime id}[&gname={str group name}&epno={int4 episode number}]
	-- MYLIST aid={int4 anime id}[&gid={int4 group id}&epno={int4 episode number}]
	-- Must have s={str session_key}.
	elseif command == "MYLIST" then
		local b = newServerResponseBuilder(params)

		if checkSession(params, b) then
			if params.lid or params.fid or (params.ed2khash and params.size) then
				b("221 MYLIST\n115|417417|33333|410|810|1234000|4|1234567|Somewhere|Outer Space|Nothing to say...|2")
			elseif params.aname or params.aid then
				b("322 MULTIPLE FILES FOUND\nKoukaku Kidoutai STAND ALONE COMPLEX|26||1-26|1-26,S2-S27|||V-A|S2-S27|LMF|20-26|KAA|1-26|AonE|1-19|Anime-MX|1-3,9-20")
			else
				b("321 NO SUCH ENTRY\n")
			end
		end

		check(udp:send(b()))

	else
		_logprinterror("Unknown command '%s'.", command)

		local b = newServerResponseBuilder(params)
		b("598 UNKNOWN COMMAND\n")
		check(udp:send(b()))
	end
end



return simulateServerResponse
