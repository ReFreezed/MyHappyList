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

local BOOL_FALSE = "0"
local BOOL_TRUE  = "1"



local function _logprint(s, ...)
	logprint("FakeServer", s, ...)
end
local function _logprinterror(s, ...)
	logprinterror("FakeServer", "Error: "..s, ...)
end



local function parseDataFromClient(data)
	local command, query = data:match"^([A-Z]+) (.*)$"
	if not command then
		_logprinterror("Invalid data format: %s", data)
		return nil
	end

	local params = {}
	local ptr    = 1

	while ptr <= #query do
		local ptrDivider = query:find("=", ptr, true)
		if not ptrDivider then
			_logprinterror("Expected param at position %d.", ptr)
			return nil
		end

		local param = query:sub(ptr, ptrDivider-1)
		ptr = ptrDivider+1
		if param == "" then
			_logprinterror("Param name is empty at position %d.", ptr)
			return nil
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
					_logprinterror("Param '%s' has no value.", param)
					return nil
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
	local command, params = parseDataFromClient(data)
	if not command then  return  end

	-- printobj(command, params)

	-- PING [nat=1]
	if command == "PING" then
		local b = newServerResponseBuilder(params)
		b("300 PONG\n")

		if params["nat"] == BOOL_TRUE then
			b("%d", LOCAL_PORT)
		end
		check(udp:send(b()))

	-- AUTH user={str}&pass={str}&protover={int4}&client={str}&clientver={int4}[&nat=1&comp=1&enc={str}&mtu={int4}&imgserver=1]
	elseif command == "AUTH" then
		local b = newServerResponseBuilder(params)

		local session = "S7WdA"
		local natStr  = params["nat"] == BOOL_TRUE and F(" %s:%d", "192.0.2.0", LOCAL_PORT) or ""

		b("200 %s%s LOGIN ACCEPTED\n", session, natStr)
		-- b("201 %s%s LOGIN ACCEPTED - NEW VERSION AVAILABLE\n", session, natStr)
		-- b("500 LOGIN FAILED\n")
		-- b("503 CLIENT VERSION OUTDATED\n")
		-- b("504 CLIENT BANNED - insert reason here\n")
		-- b("505 ILLEGAL INPUT OR ACCESS DENIED\n")
		-- b("601 ANIDB OUT OF SERVICE - TRY AGAIN LATER\n")

		check(udp:send(b()))

	else
		_logprinterror("Unknown command '%s'.", command)
	end
end



return simulateServerResponse
