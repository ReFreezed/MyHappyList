--[[============================================================
--=
--=  Global Functions
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	arrayIterator
	assertf, assertarg, check
	clamp
	cleanupPath
	cmdAsync, cmdCapture, scriptCaptureAsync, cmdEscapeArgs
	encodeHtmlEntities
	errorf, fileerror
	F, formatBytes
	findPreviousChar
	getKeys
	getLineNumber
	getTime
	getTimezone, getTimezoneOffsetString, getTimezoneOffset
	gsub2
	handleError, wrapCall
	iff
	indexOf, itemWith, itemWith2, itemWithAll
	ipairsr, iprev
	isAny
	isInt
	isStringMatchingAnyPattern
	makePrintable
	newSet
	newStringBuilder
	openFileExternally
	pack
	pairsSorted
	print, printOnce, printf, printfOnce, log, logprint, logprinterror, logprintOnce, printobj
	range
	removeItem
	round
	serializeLua
	setAndInsert, setAndInsertIfNew, unsetAndRemove
	sort
	sortNatural, compareNatural
	splitString
	trim, trimNewlines

--============================================================]]

require(... .."_filesystem")
require(... .."_wx")



function isStringMatchingAnyPattern(s, patterns)
	for _, pat in ipairs(patterns) do
		if s:find(pat) then  return true  end
	end
	return false
end



-- errorf( [ level=1, ] formatString, ...)
function errorf(level, s, ...)
	if type(level) == "number" then
		error(F(s, ...), level+1)
	else
		error(F(level, s, ...), 2)
	end
end

-- fileerror( path, contents, position,   formatString, ... )
-- fileerror( path, nil,      lineNumber, formatString, ... )
function fileerror(path, contents, pos, s, ...)
	local ln = contents and getLineNumber(contents, pos) or pos
	if type(s) ~= "string" then
		s = F("%s:%d: %s", path, ln, tostring(s))
	else
		s = F("%s:%d: "..s, path, ln, ...)
	end
	error(s, 2)
end



function handleError(err)
	print(debug.traceback(tostring(err), 2))

	if logFile then
		logFile:close()
	end

	os.exit(1)
end

function wrapCall(f)
	return function(...)
		local args = pack(...)

		xpcall(
			function()
				f(unpack(args, 1, args.n))
			end,
			handleError
		)
	end
end



function getLineNumber(s, pos)
	local lineCount = 1
	for posCurrent in s:gmatch"()\n" do
		if posCurrent < pos then
			lineCount = lineCount+1
		else
			break
		end
	end
	return lineCount
end



do
	local values     = {}
	local oncePrints = {}

	function print(...)
		_print(...)

		local argCount = select("#", ...)
		for i = 1, argCount do
			values[i] = tostring(select(i, ...))
		end

		log(table.concat(values, "\t", 1, argCount))
	end

	function printOnce(...)
		local argCount = select("#", ...)
		for i = 1, argCount do
			values[i] = tostring(select(i, ...))
		end

		local s = table.concat(values, "\t", 1, argCount)

		if oncePrints[s] then  return  end
		oncePrints[s] = true

		_print(...)
		log(s)
	end
end

function printf(s, ...)
	print(s:format(...))
end

function printfOnce(s, ...)
	printOnce(s:format(...))
end

-- log( string )
-- log( formatString, ... )
do
	local logBuffer = {}

	function log(s, ...)
		if select("#", ...) > 0 then  s = s:format(...)  end

		if not logFile then
			table.insert(logBuffer, s)
			return
		end

		for i, s in ipairs(logBuffer) do
			writeLine(logFile, s)
			logBuffer[i] = nil
		end

		writeLine(logFile, s)
	end
end

function logprint(agent, s, ...)
	if select("#", ...) > 0 then  s = s:format(...)  end

	local time = getTime()
	if agent then
		printf("%s.%03d|%s| %s", os.date("%H:%M:%S", time), 1000*(time%1), agent, s)
	else
		printf("%s.%03d| %s", os.date("%H:%M:%S", time), 1000*(time%1), s)
	end
end

function logprinterror(agent, s, ...)
	if select("#", ...) > 0 then  s = s:format(...)  end

	local time = getTime()
	-- io.stdout:write("\27[91m") -- Bright red. (No support in Sublime. :/ )
	if agent then
		printf("%s.%03d|%s| Error: %s", os.date("%H:%M:%S", time), 1000*(time%1), agent, s)
	else
		printf("%s.%03d| Error: %s", os.date("%H:%M:%S", time), 1000*(time%1), s)
	end
	-- io.stdout:write("\27[0m")  -- Clean.
end

function logprintOnce(agent, s, ...)
	if select("#", ...) > 0 then  s = s:format(...)  end

	local time = getTime()
	if agent then
		printfOnce("%s.%03d|%s| %s", os.date("%H:%M:%S", time), 1000*(time%1), agent, s)
	else
		printfOnce("%s.%03d| %s", os.date("%H:%M:%S", time), 1000*(time%1), s)
	end
end

-- printobj( ... )
-- Note: Does not write to log.
do
	local out = io.stdout

	local _tostring = tostring
	local function tostring(v)
		return (_tostring(v):gsub('^table: ', ''))
	end

	local function compareKeys(a, b)
		return compareNatural(tostring(a), tostring(b))
	end

	local function _printobj(v, tables)
		local vType = type(v)

		if vType == "table" then
			if tables[v] then
				out:write(tostring(v), " ")
				return
			end

			out:write(tostring(v), "{ ")
			tables[v] = true

			local indices = {}
			for i = 1, #v do  indices[i] = true  end

			for _, k in ipairs(sort(getKeys(v), compareKeys)) do
				if not indices[k] then
					out:write(tostring(k), "=")
					_printobj(v[k], tables)
				end
			end

			for i = 1, #v do
				out:write(i, "=")
				_printobj(v[i], tables)
			end

			out:write("} ")

		elseif vType == "number" then
			out:write(F("%g ", v))

		elseif vType == "string" then
			out:write('"', v:gsub("%z", "\\0"):gsub("\n", "\\n"), '" ')

		else
			out:write(tostring(v), " ")
		end

	end

	function printobj(...)
		for i = 1, select("#", ...) do
			if i > 1 then  out:write("\t")  end

			_printobj(select(i, ...), {})
		end
		out:write("\n")
	end

end



F = string.format

function formatBytes(n)
	if     n >= 1024*1024*1024 then
		return F("%.2f GB",  n/(1024*1024*1024))
	elseif n >= 1024*1024      then
		return F("%.2f MB",  n/(1024*1024))
	elseif n >= 1024           then
		return F("%.2f KB",  n/(1024))
	else
		return F("%d bytes", n)
	end
end



function trim(s)
	s = s :gsub("^%s+", "") :gsub("%s+$", "")
	return s
end

function trimNewlines(s)
	s = s :gsub("^\n+", "") :gsub("\n+$", "")
	return s
end



-- array = sortNatural( array [, attribute ] )
do
	local function pad(numStr)
		return F("%03d%s", #numStr, numStr)
	end
	function compareNatural(a, b)
		return tostring(a):gsub("%d+", pad) < tostring(b):gsub("%d+", pad)
	end

	function sortNatural(t, k)
		if k then
			table.sort(t, function(a, b)
				return compareNatural(a[k], b[k])
			end)
		else
			table.sort(t, compareNatural)
		end
		return t
	end
end



function assertf(v, err, ...)
	if not v then
		if select("#", ...) > 0 then  err = err:format(...)  end
		assert(false, err)
	end
	return v
end

-- value = assertarg( [ functionName=auto, ] argumentNumber, value, expectedValueType... [, depth=2 ] )
do
	local function _assertarg(fName, n, v, ...)
		local vType       = type(v)
		local varargCount = select("#", ...)
		local lastArg     = select(varargCount, ...)
		local hasDepthArg = (type(lastArg) == "number")
		local typeCount   = varargCount+(hasDepthArg and -1 or 0)

		for i = 1, typeCount do
			if vType == select(i, ...) then  return v  end
		end

		local depth = 2+(hasDepthArg and lastArg or 2)

		if not fName then
			fName = debug.traceback("", depth-1):match": in function '(.-)'" or "?"
		end

		local expects = table.concat({...}, " or ", 1, typeCount)

		error(F("bad argument #%d to '%s' (%s expected, got %s)", n, fName, expects, vType), depth)
	end

	function assertarg(fNameOrArgNum, ...)
		if type(fNameOrArgNum) == "string" then
			return _assertarg(fNameOrArgNum, ...)
		else
			return _assertarg(nil, fNameOrArgNum, ...)
		end
	end
end

function check(v, ...)
	if not v then
		local err = "Error: "..tostring((...))
		print(debug.traceback(err, 2))
	end
	return v, ...
end



function indexOf(t, v)
	for i, item in ipairs(t) do
		if item == v then  return i  end
	end
	return nil
end

function itemWith(t, k, v)
	for i, item in ipairs(t) do
		if item[k] == v then  return item, i  end
	end
	return nil
end
function itemWith2(t, k1,v1, k2,v2)
	for i, item in ipairs(t) do
		if item[k1] == v1 and item[k2] == v2 then  return item, i  end
	end
	return nil
end

function itemWithAll(t, k, v)
	local items = {}
	for _, item in ipairs(t) do
		if item[k] == v then  table.insert(items, item)  end
	end
	return items
end



-- html = encodeHtmlEntities( string [, excludeApostrophe=false ] )
do
	local ENTITIES = {
		["&"] = "&amp;",
		["<"] = "&lt;",
		[">"] = "&gt;",
		['"'] = "&quot;",
		["'"] = "&#39;",
	}

	function encodeHtmlEntities(s, excludeApostrophe)
		return (s:gsub((excludeApostrophe and "[&<>\"]" or "[&<>\"']"), ENTITIES))
	end
end



function pack(...)
	return {n=select("#", ...), ...}
end



-- parts = splitString( string, separatorPattern [, startIndex=1, plain=false ] )
function splitString(s, sep, i, plain)
	i = i or 1
	local parts = {}

	while true do
		local i1, i2 = s:find(sep, i, plain)
		if not i1 then  break  end

		table.insert(parts, s:sub(i, i1-1))
		i = i2+1
	end

	table.insert(parts, s:sub(i))
	return parts
end



function round(n)
	return math.floor(n+0.5)
end



-- builder = newStringBuilder( )
do
	local mt = {
		__call = function(b, ...)
			local len = select("#", ...)
			if len == 0 then  return table.concat(b)  end

			local s = len == 1 and tostring(...) or F(...)
			table.insert(b, s)
		end,
	}

	function newStringBuilder()
		return setmetatable({}, mt)
	end
end



function getKeys(t)
	local keys = {}
	for k in pairs(t) do  table.insert(keys, k)  end
	return keys
end



-- bool = isAny( valueToCompare, value1, ... )
-- bool = isAny( valueToCompare, arrayOfValues )
function isAny(v, ...)
	local len = select("#", ...)

	if len == 1 and type(...) == "table" then
		for _, item in ipairs(...) do
			if v == item then  return true  end
		end

	else
		for i = 1, len do
			if v == select(i, ...) then  return true  end
		end
	end

	return false
end



-- anyItemGotRemoved = removeItem( array, value1, ... )
function removeItem(t, ...)
	local anyItemGotRemoved = false

	for argIndex = 1, select("#", ...) do
		local i = indexOf(t, select(argIndex, ...))

		if i then
			table.remove(t, i)
			anyItemGotRemoved = true
		end
	end

	return anyItemGotRemoved
end



-- Same as string.gsub(), but "%" has no meaning in the replacement.
function gsub2(s, pat, repl, ...)
	return s:gsub(pat, repl:gsub("%%", "%%%%"), ...)
end



function getTime()
	return socket.gettime()
end



-- Compute the difference in seconds between local time and UTC. (Normal time.)
-- http://lua-users.org/wiki/TimeZone
function getTimezone()
	local now = os.time()
	return os.difftime(now, os.time(os.date("!*t", now)))
end

-- Return a timezone string in ISO 8601:2000 standard form (+hhmm or -hhmm).
function getTimezoneOffsetString(tz)
	local h, m = math.modf(tz/3600)
	return F("%+.4d", 100*h+60*m)
end

-- Return the timezone offset in seconds, as it was on the given time. (DST obeyed.)
-- timezoneOffset = getTimezoneOffset( [ time=now ] )
function getTimezoneOffset(time)
	time = time or os.time()
	local dateUtc   = os.date("!*t", time)
	local dateLocal = os.date("*t",  time)
	dateLocal.isdst = false -- This is the trick.
	return os.difftime(os.time(dateLocal), os.time(dateUtc))
end



function cleanupPath(someKindOfPath)
	local path = toNormalPath(someKindOfPath)

	local count
	repeat
		path, count = path:gsub("/[^/]+/%.%./", "/", 1) -- Not completely fool proof!
	until count == 0

	return path
end



function ipairsr(t)
	return iprev, t, #t+1
end

function iprev(t, i)
	i = i-1
	local v = t[i]
	if v ~= nil then  return i, v  end
end



function pairsSorted(t)
	local keys = sortNatural(getKeys(t))
	local i    = 0

	return function()
		i = i+1
		local k = keys[i]
		if k ~= nil then  return k, t[k]  end
	end
end



function sort(t, ...)
	table.sort(t, ...)
	return t
end



function isInt(v)
	return
		type(v) == "number"
		and v == v -- Not NaN.
		and v == math.floor(v)
		and math.abs(v) ~= math.huge
end



function makePrintable(v)
	return (tostring(v)
		:gsub("\n", "\\n")
		:gsub("[%z\1-\31]", function(c)
			return "\\"..c:byte()
		end)
		:gsub("(pass=).*(&[^a])", "%1***%2") -- Simple password hiding. Note: "&" should be encoded as "&amp;".
	)
end



function iff(v, a, b)
	if v then
		return a
	else
		return b
	end
end



function clamp(n, min, max)
	return math.min(math.max(n, min), max)
end



-- Return any data as a Lua code string.
-- luaString = serializeLua( value )
do
	local SIMPLE_TYPES = {["boolean"]=true,["nil"]=true,["number"]=true}
	local KEYWORDS = {
		["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
		["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,
		["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,["repeat"]=true,
		["return"]=true,["then"]=true,["true"]=true,["until"]=true,["while"]=true,
	}

	local function _serializeLua(out, data)
		local dataType = type(data)

		if dataType == "table" then
			local first   = true
			local i       = 0
			local indices = {}

			local insert = table.insert
			insert(out, "{")

			while true do
				i = i+1

				if data[i] == nil then
					i = i+1
					if data[i] == nil then  break  end

					if not first then  insert(out, ",")  end
					insert(out, "nil")
					first = false
				end

				if not first then  insert(out, ",")  end
				first = false

				_serializeLua(out, data[i])
				indices[i] = true
			end

			for k, v in pairs(data) do
				if not indices[k] then
					if not first then  insert(out, ",")  end
					first = false

					if not KEYWORDS[k] and type(k) == "string" and k:find"^[a-zA-Z_][a-zA-Z0-9_]*$" then
						insert(out, k)
					else
						insert(out, "[")
						_serializeLua(out, k)
						insert(out, "]")
					end

					insert(out, "=")
					_serializeLua(out, v)
				end
			end

			insert(out, "}")

		elseif dataType == "string" then
			table.insert(out, F("%q", data))

		elseif SIMPLE_TYPES[dataType] then
			table.insert(out, tostring(data))

		else
			errorf("Cannot serialize value type '%s'. (%s)", dataType, tostring(data))
		end

		return out
	end

	function serializeLua(data)
		return (table.concat(_serializeLua({}, data)))
	end
end



-- success = cmdAsync( cmd )
-- @Robustness: Make sure other processes don't continue running after we exit.
do
	local execute = nil

	function cmdAsync(cmd)
		if not execute then
			-- Instead of using io.popen() which pops up an ugly console window we use ShellExecuteA().
			-- We may have to fall back to io.popen() if we're adding support for *nix in the future. 2018-07-24
			-- https://stackoverflow.com/a/29678230
			--
			-- HINSTANCE ShellExecuteA(
			--    HWND hwnd, LPCSTR lpOperation, LPCSTR lpFile, LPCSTR lpParameters, LPCSTR lpDirectory, INT nShowCmd
			-- )
			--
			-- Note: HINSTANCE is actually an int - reason being backwards compatability.
			-- https://docs.microsoft.com/en-us/windows/desktop/api/shellapi/nf-shellapi-shellexecutea

			execute = require"alien".load"Shell32.dll".ShellExecuteA
			execute:types("pointer","pointer","pointer","pointer","pointer","pointer","int")
		end

		-- Note: The returned value is actually an int disguised as a pointer.
		local int    = execute(0, "open", "cmd.exe", "/W /C "..cmd, 0, 0)
		local status = tonumber(tostring(int):match"(0[%dA-F]*)", 16) -- @Hack: Not sure if this is 100% reliable.

		return status > 32
	end
end

-- string, errorMessage = cmdCapture( cmd [, timeoutInSeconds=600 ] )
function cmdCapture(cmd, timeout)
	timeout = timeout or 600

	local outputPath = getTempFilePath()

	if not cmdAsync(cmd.." > "..toWindowsPath(outputPath)) then
		return nil, "Could not execute command: "..cmd
	end

	-- Dunno how long cmdAsync() takes to execute, so let's
	-- start the timeout timer afterwards instead of before.
	local timeStart   = getTime()
	local timeoutTime = timeStart+timeout

	-- Wait until the output file exists and is done writing.
	while true do
		local time = getTime()
		socket.sleep(time < timeStart+5 and 1/30  or time < timeStart+10 and 1/5  or 1)

		if isFileWritable(outputPath) then
			break
		end

		if time > timeoutTime then
			return nil, "Timeout while capturing output: "..cmd
		end
	end

	local output = assert(getFileContents(outputPath, true))

	deleteFile(outputPath) -- Could fail, but we'll cleanup later.
	return output
end

-- scriptCaptureAsync( scriptName, callback, arg1, ... )
function scriptCaptureAsync(scriptName, cb, ...)
	local scriptPath = "src/scripts/"..scriptName..".lua"
	local cmd        = cmdEscapeArgs("bin\\wlua5.1.exe", scriptPath, ...)

	local outputPath = getTempFilePath()

	if not cmdAsync(cmd.." > "..toWindowsPath(outputPath)) then
		return nil, "Could not execute command: "..cmd
	end

	local timer; timer = newTimer(1000/10, function(e)
		if not isFileWritable(outputPath) then  return  end

		timer:Stop()

		local output = assert(getFileContents(outputPath, true))

		deleteFile(outputPath) -- Could fail, but we'll cleanup later.
		cb(output)
	end)
end

function cmdEscapeArgs(...)
	local buffer = {}

	for i = 1, select('#', ...) do
		local arg = select(i, ...)

		if arg:find'[%z\n\r]' then
			print("Arg "..i..": "..arg)
			error("Argument contains invalid characters.")
		end

		if i > 1 then
			table.insert(buffer, ' ')
		end

		if arg == '' then
			table.insert(buffer, '""')
		elseif not arg:find'[%s"]' then
			table.insert(buffer, arg)
		else
			arg = arg
				:gsub('(\\*)"', '%1%1\\"')
				:gsub('(\\+)$', '%1%1')
			table.insert(buffer, '"')
			table.insert(buffer, arg)
			table.insert(buffer, '"')
		end
	end

	return table.concat(buffer)
end



function arrayIterator(t)
	local i = 0

	return function()
		i = i+1
		local v = t[i]

		if v ~= n then  return v  end
	end
end



function newSet(t)
	local set = {}
	for _, v in ipairs(t) do  set[v] = true  end
	return set
end



-- success = setAndInsert( table, key [, item=key ] )
function setAndInsert(t, k, item)
	if isAny(type(k), "number","nil") then
		errorf(2, "The key cannot be a number or nil. (Got %s)", type(k))
	end

	if t[k]        then  return false  end
	if item == nil then  item = k      end

	t[k] = item
	table.insert(t, item)

	return true
end

-- resultingItemInTable = setAndInsertIfNew( table, key, item )
function setAndInsertIfNew(t, k, item)
	setAndInsert(t, k, item)
	return t[k]
end

-- success = unsetAndRemove( table, key )
function unsetAndRemove(t, k)
	assert(type(k) ~= "number", "The key cannot be a number.")

	local item = t[k]
	if not item then  return false  end

	t[k] = nil
	removeItem(t, item)

	return true
end



-- position = findPreviousChar( string, char, startPosition )
function findPreviousChar(s, c, i)
	local byte = c:byte()

	for ptr = i, 1, -1 do
		if s:byte(ptr) == byte then  return ptr  end
	end

	return nil
end



function openFileExternally(path)
	cmdAsync(cmdEscapeArgs("start", "", path))
end



-- array = range( [ from=1, ] to )
function range(from, to)
	if not to then
		from, to = 1, from
	end

	local t = {}
	local i = 0

	for n = from, to do
		i    = i+1
		t[i] = n
	end

	return t
end


