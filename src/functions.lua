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

	assertf, assertarg, check
	clamp
	cleanupPath
	cmdAsync, cmdSync, cmdDetached, cmdCapture, scriptCaptureAsync, scriptRunDetached, isScriptRunning, cmdEscapeArgs, run
	compareTables
	copyTable
	cwdPush, cwdPop
	eatSpaces
	encodeHtmlEntities
	errorf, fileerror
	F, formatBytes
	findPreviousChar
	getColumn
	getKeys
	getLineNumber
	getStored, store, storeItem, getStorage
	getStoredEventCallback, getStoredEventCallbackAll, storeEventCallbacks
	getTime
	getTimezone, getTimezoneOffsetString, getTimezoneOffset
	gsub2
	handleError, wrapCall
	iff
	indexOf, itemWith, itemWithAll, indexWith
	ipairsr, iprev
	isAny
	isHost
	isInt
	isStringMatchingAnyPattern
	iterate, arrayIterator
	logStart, logEnd, logHeader, log, logprint, logprinterror, logprintOnce
	makePrintable
	matchLines
	newSet
	newStringBuilder
	openFileExternally, openFileInNotepad, showFileInExplorer
	pack
	pairsSorted
	print, printOnce, printf, printfOnce, printobj
	quit, maybeQuit
	range
	removeItem
	round
	serializeLua
	setAndInsert, setAndInsertIfNew, unsetAndRemove
	sort
	sortNatural, compareNatural
	splitString
	T, getText, getTranslations
	tablePathGet, tablePathSet
	trim, trimNewlines
	unzip
	updater_getUnzipDir, updater_moveFilesAfterUnzipMain, updater_moveFilesAfterUnzipUpdater

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
	local errWithStack = debug.traceback(tostring(err), 2)
	print(errWithStack)

	logEnd()

	if isApp and not DEBUG then
	 	local dialog = wxTextEntryDialog(
	 		wxNULL,
	 		F(
	 			"%s\n%s\n\n%s: %s\n\n%s:",
	 			T"error_appCrash1", T"error_appCrash2", T"label_logFile", logFilePath, T"label_message"
	 		),
	 		"Error",
	 		errWithStack,
	 		wxOK + wxCENTRE + wxTE_MULTILINE + wxTE_DONTWRAP
 		)
 		showModalAndDestroy(dialog)
	end

	os.exit(1)
end

function wrapCall(f)
	return function(...)
		local args         = pack(...)
		local returnValues = nil

		xpcall(
			function()
				returnValues = pack(f(unpack(args, 1, args.n)))
			end,
			handleError
		)

		if returnValues then
			return unpack(returnValues, 1, returnValues.n)
		end
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



do
	local logBuffer = {}

	local function logEmptyBuffer()
		for i, s in ipairs(logBuffer) do
			writeLine(logFile, s)
			logBuffer[i] = nil
		end
	end

	function logStart(basename)
		if logFile then
			errorf(2, "Log file already started. (new: '%s', old: '%s')", basename, logFilePath)
		end

		logFilePath = F("%s/%s.log", DIR_LOGS, basename)
		logFile     = assert(openFile(logFilePath, "a"))

		logEmptyBuffer()
	end

	function logEnd()
		if not logFile then  return  end

		logFile:close()
		logFile = nil
	end

	function logHeader()
		log("~~~ MyHappyList ~~~")
		log(os.date"%Y-%m-%d %H:%M:%S")

		if DEBUG_LOCAL then
			print("!! DEBUG (local) !!")
		elseif DEBUG then
			print("!!!!!! DEBUG !!!!!!")
		end
	end

	-- log( string )
	-- log( formatString, ... )
	function log(s, ...)
		if select("#", ...) > 0 then  s = s:format(...)  end

		if not logFile then
			table.insert(logBuffer, s)
			return
		end

		logEmptyBuffer()
		writeLine(logFile, s)
	end

	-- logprint( agent, string )
	-- logprint( agent, formatString, ... )
	-- agent can be nil.
	function logprint(agent, s, ...)
		if select("#", ...) > 0 then  s = s:format(...)  end

		local time = getTime()
		if agent then
			printf("%s.%03d|%s| %s", os.date("%H:%M:%S", time), 1000*(time%1), agent, s)
		else
			printf("%s.%03d| %s", os.date("%H:%M:%S", time), 1000*(time%1), s)
		end
	end

	-- logprinterror( agent, string )
	-- logprinterror( agent, formatString, ... )
	-- agent can be nil.
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

	-- logprintOnce( agent, string )
	-- logprintOnce( agent, formatString, ... )
	-- agent can be nil.
	function logprintOnce(agent, s, ...)
		if select("#", ...) > 0 then  s = s:format(...)  end

		local time = getTime()
		if agent then
			printfOnce("%s.%03d|%s| %s", os.date("%H:%M:%S", time), 1000*(time%1), agent, s)
		else
			printfOnce("%s.%03d| %s", os.date("%H:%M:%S", time), 1000*(time%1), s)
		end
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
		return T("label_numBytes", {n=n})
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

-- item, index = itemWith( array, key1, value1, ...)
function itemWith(t, ...)
	for i, item in ipairs(t) do
		local isMatch = true

		for argIndex = 1, select("#", ...), 2 do
			local k, v = select(argIndex, ...)
			if item[k] ~= v then
				isMatch = false
				break
			end
		end

		if isMatch then
			return item, i
		end
	end

	return nil
end

-- items = itemWithAll( array, key1, value1, ...)
function itemWithAll(t, ...)
	local items = {}

	for i, item in ipairs(t) do
		local isMatch = true

		for argIndex = 1, select("#", ...), 2 do
			local k, v = select(argIndex, ...)
			if item[k] ~= v then
				isMatch = false
				break
			end
		end

		if isMatch then
			table.insert(items, item)
		end
	end

	return items
end

-- index = indexWith( array, key1, value1, ...)
function indexWith(t, ...)
	local _, i = itemWith(t, ...)
	return i
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
	return socket and socket.gettime() or os.time()
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



-- for key, value, index in pairsSorted( table ) do
function pairsSorted(t)
	local keys = sortNatural(getKeys(t))
	local i    = 0

	return function()
		i = i+1
		local k = keys[i]
		if k ~= nil then  return k, t[k], i  end
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
		:gsub("\r", "\\r")
		:gsub("\n", "\\n")
		:gsub("\t", "\\t")
		:gsub("[%z\1-\31]", function(c)
			return "\\"..c:byte()
		end)
		:gsub("(pass=).-(&[^a])", "%1***%2") -- Simple password hiding. Note: "&" should be encoded as "&amp;".
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



-- processStarted = cmdAsync( ... )
function cmdAsync(pathToApp, ...)
	local cmd = cmdEscapeArgs(toWindowsPath(pathToApp), ...)
	return processStart(cmd, PROCESS_METHOD_ASYNC)
end

-- success, exitCode = cmdSync( ... )
function cmdSync(pathToApp, ...)
	local cmd = cmdEscapeArgs(toWindowsPath(pathToApp), ...)
	local exitCode = -1

	local ok = processStart(cmd, PROCESS_METHOD_SYNC, function(process, _exitCode)
		exitCode = _exitCode
	end)

	return (ok and exitCode == 0), exitCode
end

-- processStarted = cmdDetached( ... )
function cmdDetached(pathToApp, ...)
	local cmd = cmdEscapeArgs(toWindowsPath(pathToApp), ...)
	return processStart(cmd, PROCESS_METHOD_DETACHED)
end

-- output, errorMessage = cmdCapture( ... )
-- Note: output may be the contents of stderr.
function cmdCapture(pathToApp, ...)
	local cmd = cmdEscapeArgs(toWindowsPath(pathToApp), ...)
	local output

	local ok = processStart(cmd, PROCESS_METHOD_SYNC, function(process, exitCode)
		output = processReadEnded(process, exitCode, true)
	end)

	if not ok then  return nil, "Could not start process."  end

	return output
end

do
	local scriptsRunning = {}

	-- processStarted = scriptCaptureAsync( scriptName, callback, arg1, ... )
	-- callback = function( output )
	function scriptCaptureAsync(scriptName, cb, ...)
		local cmd = cmdEscapeArgs("wlua5.1.exe", "src/script.lua", scriptName, ...)

		local ok = processStart(cmd, PROCESS_METHOD_ASYNC, function(process, exitCode)
			scriptsRunning[scriptName] = false
			cb(processReadEnded(process, exitCode, true))
		end)

		if not ok then  return false  end

		scriptsRunning[scriptName] = true
		return true
	end

	-- processStarted = scriptRunDetached( scriptName, arg1, ... )
	function scriptRunDetached(scriptName, ...)
		return cmdDetached("wlua5.1.exe", "src/script.lua", scriptName, ...)
	end

	function isScriptRunning(scriptName)
		return scriptsRunning[scriptName] or false
	end
end

function cmdEscapeArgs(...)
	local buffer = {}

	for i = 1, select('#', ...) do
		local arg = select(i, ...)

		if type(arg) == "number" then
			arg = tostring(arg)

		elseif arg:find'[%z\n\r]' then
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

function run(pathToApp, ...)
	local ok, exitCode = cmdSync(pathToApp, ...)
	if not ok then
		local cmd = cmdEscapeArgs(toWindowsPath(pathToApp), ...)
		errorf("Command returned %d: %s", exitCode, cmd)
	end
end



-- for value... in iterate( callback, argument... ) do
-- 'value...' is whatever the callback yields.
do
	local coroutine_create = coroutine.create
	local coroutine_resume = coroutine.resume
	local coroutine_wrap   = coroutine.wrap
	local coroutine_yield  = coroutine.yield

	local function initiator(cb, ...)
		coroutine_yield()
		return cb(...)
	end

	local function iterator(co)
		return select(2, assert(coroutine_resume(co)))
	end

	function iterate(cb, ...)
		if select('#', ...) <= 2 then
			return coroutine_wrap(cb), ...
		end

		local co = coroutine_create(initiator)
		assert(coroutine_resume(co, cb, ...))

		return iterator, co
	end
end

-- for item in arrayIterator( array ) do
function arrayIterator(t)
	local i = 0

	return function()
		i = i+1
		local v = t[i]

		if v ~= nil then  return v  end
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



-- success = openFileExternally( path )
function openFileExternally(path)
	return cmdDetached("explorer", toShortPath(path, true))
end

-- success = openFileInNotepad( path )
function openFileInNotepad(path)
	return cmdDetached("notepad", toShortPath(path, true))
end

-- success = showFileInExplorer( path )
function showFileInExplorer(path)
	-- This *sometimes* seem to leave a lingering explorer process for some reason, even
	-- after MyHappyList closes. Need confirmation on this. Most of the time the process
	-- stops after some time though. The command looks something like this:
	-- C:\Windows\explorer.exe /factory,{75(...)4b} -Embedding
	return cmdDetached("explorer", "/select,"..toShortPath(path, true))
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



-- values = getColumn( array, key )
function getColumn(t, k)
	local values = {}

	for i, item in ipairs(t) do
		values[i] = item[k]
	end

	return values
end



do
	local allStorage = setmetatable({}, {__mode="k"})

	-- storage = getStorage( object [, doNotCreate=false ] )
	function getStorage(obj, doNotCreate)
		local storage = allStorage[obj]

		if not (storage or doNotCreate) then
			storage = {}
			allStorage[obj] = storage
		end

		return storage
	end

	function getStored(obj, k)
		local storage = allStorage[obj]
		return storage and storage[k]
	end

	function store(obj, k, v)
		getStorage(obj)[k] = v
	end

	-- storeItem( object, item )      -- Store directly in storage.
	-- storeItem( object, key, item ) -- Store in an array field.
	function storeItem(obj, kOrItem, item)
		local storage = getStorage(obj)

		if item ~= nil then
			local k = kOrItem
			local t = storage[k]

			if not t then
				storage[k] = {item}
			else
				table.insert(t, item)
			end

		else
			item = kOrItem
			assert(item ~= nil)
			table.insert(storage, item)
		end
	end
end



function getStoredEventCallback(eHolder, eType, id)
	local storage = getStorage(eHolder, true)
	return storage and tablePathGet(storage, "events", eType, id)
end

-- callbacks = getStoredEventCallbackAll( eventHolder, eventType )
-- callbacks = { [id1]=callback1, ... }
function getStoredEventCallbackAll(eHolder, eType)
	local storage = getStorage(eHolder, true)
	return storage and tablePathGet(storage, "events", eType)
end

function storeEventCallbacks(eHolder, eType, id, cb)
	tablePathSet(getStorage(eHolder), "events", eType, id, cb)
end



-- value = tablePathGet( table, key1, ... )
function tablePathGet(t, k, ...)
	for i = 1, select("#", ...) do
		if not t[k] then  return nil  end

		t = t[k]
		k = select(i, ...)
	end

	return t[k]
end

-- tablePathSet( table, key1, ..., value )
function tablePathSet(t, k, ...)
	local argCount = select("#", ...)

	for i = 1, argCount-1 do
		if not t[k] then
			t[k] = {}
		end

		t = t[k]
		k = select(i, ...)
	end

	t[k] = select(argCount, ...)
end



function eatSpaces(s, ptr)
	local _, to = s:find(" *", ptr)
	return to+1
end



do
	local cwds = {}

	function cwdPush(path)
		table.insert(cwds, wxGetCwd())
		wxSetWorkingDirectory(path)
	end

	function cwdPop()
		wxSetWorkingDirectory(table.remove(cwds))
	end
end



-- line1, ... [, rest ] = matchLines( string, lineCount [, returnRest=false ] )
function matchLines(s, count, rest)
	if count < 1 then
		if rest then  return s  end
		return
	end

	local pat = "^([^\n]+)" .. ("\n([^\n]+)"):rep(count-1)
	if rest then
		pat = pat.."\n?(.*)"
	end

	return s:match(pat)
end



function isHost(host, wantedHost)
	return
		host == wantedHost
		or #host > #wantedHost and ("."..host):sub(#host+1-#wantedHost) == "."..wantedHost
end



function quit()
	topFrame:Close(true)
	wxGetApp():ExitMainLoop()
end

function maybeQuit()
	if topFrame:Close() then
		wxGetApp():ExitMainLoop()
	end
end



-- success, errorMessage = unzip( zipFilePath, targetDirectory [, unwrapRootDirectoryInZipFile=false ] [, filter ] )
-- doUnzip = filter( relativePath )
-- Note: relativePath can be a directory or file.
function unzip(zipPath, targetDir, unwrapRoot, filter)
	if type(unwrapRoot) == "function" then
		unwrapRoot, filter = false, unwrapRoot
	end

	if not isDirectoryWritable(targetDir) then
		return false, targetDir..": Directory is not writable."
	end

	local zip = assert(require"zip".open(zipPath))

	assert(createDirectory(targetDir))

	for archivedFile in zip:files() do
		local pathRel = archivedFile.filename

		if unwrapRoot and pathRel:find"^[^/]+/$" then
			-- void

		-- Directory.
		elseif pathRel:find"/$" then
			pathRel            = pathRel:sub(1, #pathRel-1)
			local pathRelFinal = unwrapRoot and pathRel:gsub("^[^/]+/", "") or pathRel

			if not filter or filter(pathRelFinal) then
				local path = targetDir.."/"..pathRelFinal
				assert(createDirectory(path))
			end

		-- File.
		else
			local pathRelFinal = unwrapRoot and pathRel:gsub("^[^/]+/", "") or pathRel

			if not filter or filter(pathRelFinal) then
				local file     = assert(zip:open(pathRel))
				local contents = file:read"*a"
				file:close()

				local path = targetDir.."/"..pathRelFinal
				assert(writeFile(path, contents))
			end
		end
	end

	zip:close()
	return true
end



function updater_getUnzipDir()
	return DIR_TEMP.."/LatestVersion"
end

do
	local function moveFiles(isMain, dangerModeActive)
		traverseDirectory(updater_getUnzipDir(), function(pathOld, pathRel, name, mode)
			local pathNew = DIR_APP.."/"..pathRel

			if (pathRel == "misc/Update" or pathRel:find"^misc/Update/" ~= nil) == isMain then
				-- Skip for now.

			elseif mode == "directory" then
				if dangerModeActive then
					logprint(nil, "Creating %s", pathNew)
					assert(createDirectory(pathNew))
				else
					logprint("Sim", "Create directory: %s", pathNew)
				end

			else
				if dangerModeActive then
					logprint(nil, "Moving %s", pathNew)
					assert(renameFile(pathOld, pathNew, true))
				else
					logprint("Sim", "Move file to: %s", pathNew)
				end
			end
		end)
	end

	function updater_moveFilesAfterUnzipMain(dangerModeActive)
		moveFiles(true, dangerModeActive)
	end

	function updater_moveFilesAfterUnzipUpdater(dangerModeActive)
		moveFiles(false, dangerModeActive)
	end
end



local DEFAULT_LANGUAGE = "en-US"
local textTables       = nil

local function loadTexts()
	textTables = {}

	traverseFiles("languages", function(path, pathRel, filename, ext)
		if ext ~= "txt" then  return  end

		local file = assert(openFile(path, "r"))
		local ln   = 0

		local langCode = filename:sub(1, -5) -- Remove ".txt"
		assert(langCode ~= "")

		local textTable = {language_code=langCode}

		table.insert(textTables, textTable)
		textTables[langCode] = textTable

		for line in file:lines() do
			ln   = ln+1
			line = trim(line)

			if line == "" or line:find"^#" then
				-- void
			else
				local textKey, text = line:match"^([%w_]+)%s*=%s*(.*)$"

				if not textKey then
					logprinterror("i18n", "%s:%d: Bad line format: %s", path, ln, line)
				elseif text ~= "" then
					textTable[textKey] = text
				end
			end
		end

		file:close()
		textTable.language_title = textTable.language_title or langCode
	end)
end

function T(textKey, values)
	return getText(appSettings.language, textKey, values, DEFAULT_LANGUAGE)
end

-- text = getText( languageCode, textKey [, values, fallbackLanguageCode ] )
function getText(langCode, textKey, values, fallback)
	if not textTables then
		loadTexts()
	end

	local text
		=  textTables[langCode][textKey]
		or fallback and textTables[fallback][textKey]
		or F("<%s>", textKey)

	if values then
		text = text:gsub("{([%w_.]+)}", function(k)
			return values[k] or "{UNKNOWN_VALUE}"
		end)
	end

	return text
end

-- translations = getTranslations( )
-- translation = { code=languageCode, title=languageTitle }
function getTranslations()
	if not textTables then
		loadTexts()
	end

	local translations = {}

	for _, textTable in ipairs(textTables) do
		table.insert(translations, {code=textTable.language_code, title=textTable.language_title})
	end

	return translations
end



-- copy = copyTable( table [, deep=false ] )
do
	local function deepCopy(t, copy, tableCopies)
		for k, v in pairs(t) do
			if type(v) == "table" then
				local vCopy = tableCopies[v]

				if vCopy then
					copy[k] = vCopy
				else
					vCopy          = {}
					tableCopies[v] = vCopy
					copy[k]        = deepCopy(v, vCopy, tableCopies)
				end

			else
				copy[k] = v
			end
		end
		return copy
	end

	function copyTable(t, deep)
		if deep then
			return deepCopy(t, {}, {})
		end

		local copy = {}
		for k, v in pairs(t) do  copy[k] = v  end

		return copy
	end
end



-- tablesAreEqual = compareTables( table1, table2 [, deep=false ] )
function compareTables(t1, t2, deep)
	for k, v1 in pairs(t1) do
		local v2 = t2[k]
		if v1 ~= v2 and not (deep and type(v1) == "table" and type(v2) == "table" and compareTables(v1, v2, true)) then
			return false
		end
	end
	for k, v2 in pairs(t2) do
		if t1[k] == nil then  return false  end
	end
	return true
end


