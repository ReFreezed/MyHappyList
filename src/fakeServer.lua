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



--==============================================================
--==============================================================
--==============================================================

local _logprint, _logprinterror
local encodeEntry, encodeString
local getCacheSharp, getMylistSharp
local newServerResponseBuilder
local parseDataFromClient
local simulateServerResponse
local startNewSession, checkSession



function _logprint(s, ...)
	logprint("FakeServer", s, ...)
end
function _logprinterror(s, ...)
	logprinterror("FakeServer", s, ...)
end



function startNewSession()
	local chars = {}

	for i = 1, math.random(4, 8) do
		local j  = math.random(1, #SESSION_CHARS)
		chars[i] = SESSION_CHARS:sub(j, j)
	end

	session = table.concat(chars)
	_logprint("Started session. (%s)", session)
end

function checkSession(params, b)
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



function parseDataFromClient(data)
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

				-- if v == "" then  _logprint("Warning: Param '%s' has no value.", param)  end

				params[param] = v
				break
			end
		end
	end

	return command, params
end



function newServerResponseBuilder(params)
	local b = newStringBuilder()

	if params["tag"] then
		b(params["tag"])
		b(" ")
	end

	return b
end



function getCacheSharp(pageName, id)
	local path = F("cache/%s%d", pageName, id)

	local file, err = openFile(path, "r")
	if not file then  return nil, err  end

	entry    = {}
	local ln = 0

	for line in file:lines() do
		ln = ln+1

		local k, v = parseSimpleKv(line, path, ln)

		if k then  entry[k] = v  end
	end

	file:close()
	return entry
end

function getMylistSharp(params)
	if     tonumber(params.lid) == 252003620 or params.ed2k == "9244372db8b1e10c5882d5e0ad814a35" and tonumber(params.size) == 367902232 then
		return getCacheSharp("l", 252003620)
	elseif tonumber(params.lid) == 252003625 or params.ed2k == "a9666994b3b6f78c9ab515593bab92e4" and tonumber(params.size) == 368372033 then
		return getCacheSharp("l", 252003625)
	elseif tonumber(params.lid) == 252003636 or params.ed2k == "c467896913f3ca92bc7b6b49db8775fe" and tonumber(params.size) == 367675087 then
		return getCacheSharp("l", 252003636)
	end
	return nil
end



function encodeEntry(...)
	local values = {...}

	for i, v in ipairs(values) do
		if type(v) == "string" then
			values[i] = encodeString(v)

		elseif type(v) == "number" then
			values[i] = F("%.0f", v)

		else
			values[i] = tostring(v)
		end
	end

	return table.concat(values, "|")
end

function encodeString(s)
	return (s:gsub("[\n'|]", {
		["\n"] = "<br />",
		["'"]  = "`",
		["|"]  = "/",
	}))
end



function simulateServerResponse(udp, data)
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
			b("%d\n", port)
		end
		check(udp:send(b()))

	-- AUTH user=str&pass=str&protover=int&client=str&clientver=int[&nat=1&comp=1&enc=str&mtu=int&imgserver=1]
	elseif command == "AUTH" then
		session = ""
		local b = newServerResponseBuilder(params)

		if params["user"]:lower() == "myname" and params["pass"] == "abc123" then
			startNewSession()

			local natStr = params["nat"] == BOOL_TRUE and F(" %s:%d", "192.0.2.0", port) or ""
			b("200 %s%s LOGIN ACCEPTED\n", session, natStr)
			-- b("201 %s%s LOGIN ACCEPTED - NEW VERSION AVAILABLE\n", session, natStr)
		else
			b("500 LOGIN FAILED\n")
		end
		-- b("503 CLIENT VERSION OUTDATED\n")
		-- b("504 CLIENT BANNED - insert reason here\n")
		-- b("505 ILLEGAL INPUT OR ACCESS DENIED\n")
		-- b("601 ANIDB OUT OF SERVICE - TRY AGAIN LATER\n")

		check(udp:send(b()))

	-- MYLIST lid=int
	-- MYLIST fid=int
	-- MYLIST size=int&ed2k=str
	-- MYLIST aname=str anime name[&gname=str group name&epno=int episode number]
	-- MYLIST aname=str anime name[&gid=int group id&epno=int episode number]
	-- MYLIST aid=int anime id[&gname=str group name&epno=int episode number]
	-- MYLIST aid=int anime id[&gid=int group id&epno=int episode number]
	-- Must have s=str session key.
	elseif command == "MYLIST" then
		local b = newServerResponseBuilder(params)

		if checkSession(params, b) then
			local mylistEntry = getMylistSharp(params)

			if mylistEntry then
				b("221 MYLIST\n")
				b(encodeEntry(
					mylistEntry.lid, mylistEntry.fid, mylistEntry.eid, mylistEntry.aid, mylistEntry.gid, mylistEntry.date,
					mylistEntry.state, mylistEntry.viewdate, mylistEntry.storage, mylistEntry.source, mylistEntry.other,
					mylistEntry.filestate
				))

			elseif params.lid or params.fid or params.ed2k then
				b("321 NO SUCH ENTRY\n")

			elseif params.aname or params.aid then
				b("322 MULTIPLE FILES FOUND\n")
				b(encodeEntry( -- int fid 1|...|int fid n
					25, 748, 1468

					-- The stuff below seem to be an incorrect example from the wiki. Doesn't seem
					-- to match any reply from any existing command. I dunno... 2018-07-31

					-- "Koukaku Kidoutai STAND ALONE COMPLEX", 26, "", "1-26", "1-26,S2-S27", "", "", "V-A", "S2-S27",
					-- "LMF", "20-26", "KAA", "1-26", "AonE", "1-19", "Anime-MX", "1-3,9-20"
				))
			else
				b("321 NO SUCH ENTRY\n")
			end
		end

		check(udp:send(b()))

	-- MYLISTADD fid=int
	-- MYLISTADD size=int&ed2k=str
	-- MYLISTADD lid=int&edit=1
    -- MYLISTADD aid=int&gid=int&epno=int episode number
    -- MYLISTADD aid=int&gname=str group_name&epno=int episode number
    -- MYLISTADD aid=int&generic=1&epno=int episode number
    -- MYLISTADD aname=str anime name&gid=int&epno=int episode number
    -- MYLISTADD aname=str anime name&gname=str group name&epno=int episode number
    -- MYLISTADD aname=str anime name&generic=1&epno=int episode number
	-- Can have state=int state.
	-- Can have viewed=bool viewed.
	-- Can have viewdate=int viewdate.
	-- Can have source=str source.
	-- Can have storage=str storage.
	-- Can have other=str other.
	-- Can have edit=1.
	-- Must have s=str session key.
	elseif command == "MYLISTADD" then
		local b = newServerResponseBuilder(params)

		if checkSession(params, b) then
			if params.edit ~= BOOL_TRUE then
				if params.aname or params.aid then
					b("210 MYLIST ENTRY ADDED\n22")
					-- b("310 FILE ALREADY IN MYLIST\n115|417417|33333|410|810|1234000|4|1234567|Somewhere|Outer Space|Hmm...<br />Nothing to say.|2")
					-- b("322 MULTIPLE FILES FOUND\n{int4 fid 1}|{int4 fid 2}|...|{int4 fid n}")
				else
					local mylistEntry = getMylistSharp(params)
					if mylistEntry then
						b("210 MYLIST ENTRY ADDED\n%d", tonumber(mylistEntry.lid))
					else
						b("320 NO SUCH FILE\n")
					end
				end
			else
				b("311 MYLIST ENTRY EDITED\n%s", ((params.aname or params.aid) and "5" or ""))
			end
			-- b("330 NO SUCH ANIME\n")
			-- b("330 NO SUCH GROUP\n")
		end

		check(udp:send(b()))

	-- MYLISTDEL lid=int
	-- MYLISTDEL fid=int
	-- MYLISTDEL size=int&ed2k=str
	-- MYLISTDEL aname=str anime name[&gname=str group name&epno=int episode number]
	-- MYLISTDEL aname=str anime name[&gid=int group id&epno=int episode number]
	-- MYLISTDEL aid=int anime id[&gname=str group name&epno=int episode number]
	-- MYLISTDEL aid=int anime id[&gid=int group id&epno=int episode number]
	-- Must have s=str session key.
	elseif command == "MYLISTDEL" then
		local b = newServerResponseBuilder(params)

		if checkSession(params, b) then
			b("211 MYLIST ENTRY DELETED\n%d", ((params.aname or params.aid) and 5 or 1))
			-- b("411 NO SUCH MYLIST ENTRY\n")
		end

		check(udp:send(b()))

	-- LOGOUT
	-- Must have s=str session key.
	elseif command == "LOGOUT" then
		local b = newServerResponseBuilder(params)

		if session ~= "" and params["s"] == session then
			b("203 LOGGED OUT\n")
		else
			b("403 NOT LOGGED IN\n")
		end

		check(udp:send(b()))

	else
		_logprinterror("Unknown command '%s'.", command)

		local b = newServerResponseBuilder(params)
		b("598 UNKNOWN COMMAND\n")
		check(udp:send(b()))
	end
end



--==============================================================
--==============================================================
--==============================================================

return simulateServerResponse
