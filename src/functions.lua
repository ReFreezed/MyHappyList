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
	createDirectory, isDirectoryEmpty, removeEmptyDirectories
	encodeHtmlEntities
	errorf, fileerror
	F, formatBytes
	getDirectory, getFilename, getExtension, getBasename
	getFileContents, writeFile
	getKeys
	getLineNumber
	getTempFilePath
	getTime
	getTimezone, getTimezoneOffsetString, getTimezoneOffset
	gsub2
	handleError, wrapCall
	iff
	indexOf, itemWith, itemWith2, itemWithAll
	ipairsr, iprev
	isAny
	isFile, isDirectory
	isInt
	isStringMatchingAnyPattern
	makePrintable
	newStringBuilder
	pack
	pairsSorted
	print, printOnce, printf, printfOnce, log, logprint, logprinterror, logprintOnce, printobj
	removeItem
	round
	serializeLua
	showMessage, showError
	sort
	sortNatural, compareNatural
	splitString
	toNormalPath, toWindowsPath
	traverseDirectory, traverseFiles
	trim, trimNewlines

	WX:
	newMenuItem, newButton, newText, newTimer, setTimerDummyOwner
	on, onAccelerator

--============================================================]]



function traverseDirectory(dirPath, cb, _pathRelStart)
	_pathRelStart = _pathRelStart or #dirPath+2

	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." then
			local mode = lfs.attributes(path, "mode")

			if mode == "file" then
				local pathRel = path:sub(_pathRelStart)
				local abort   = cb(path, pathRel, name, "file")
				if abort then  return true  end

			elseif mode == "directory" then
				local pathRel = path:sub(_pathRelStart)
				local abort   = cb(path, pathRel, name, "directory")
				if abort then  return true  end

				local abort = traverseDirectory(path, cb, _pathRelStart)
				if abort then  return true  end
			end

		end
	end

end

function traverseFiles(dirPath, cb, _pathRelStart)
	_pathRelStart = _pathRelStart or #dirPath+2

	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." then
			local mode = lfs.attributes(path, "mode")

			if mode == "file" then
				local pathRel  = path:sub(_pathRelStart)
				local ext      = getExtension(name)
				local abort    = cb(path, pathRel, name, ext)
				if abort then  return true  end

			elseif mode == "directory" then
				local abort = traverseFiles(path, cb, _pathRelStart)
				if abort then  return true  end
			end

		end
	end

end



function isStringMatchingAnyPattern(s, patterns)
	for _, pat in ipairs(patterns) do
		if s:find(pat) then  return true  end
	end
	return false
end



-- contents, errorMessage = getFileContents( path [, isText=false ] )
function getFileContents(path, isText)
	local file, err = io.open(path, (isText and "r" or "rb"))
	if not file then  return nil, err  end

	local contents = file:read"*a"
	file:close()

	return contents
end

-- success, errorMessage = writeFile( path, [ isText=false, ] contents )
function writeFile(path, isText, contents)
	if type(isText) == "string" then
		isText, contents = false, isText
	end

	local file, err = io.open(path, (isText and "w" or "wb"))
	if not file then  return nil, err  end

	file:write(contents)
	file:close()

	return true
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



-- success, errorMessage = createDirectory( path )
function createDirectory(path)
	if path:find"^/" or path:find"^%a:" then
		return false, F("[internal] Absolute paths are disabled. (%s)", path)
	end

	local pathConstructed = ""

	for folder in path:gmatch"[^/]+" do
		pathConstructed = (pathConstructed == "" and folder or pathConstructed.."/"..folder)

		if not isDirectory(pathConstructed) then
			local ok, err = lfs.mkdir(pathConstructed)
			if not ok then
				return false, F("Could not create directory '%s': %s", pathConstructed, err)
			end
		end
	end

	return true
end

function isDirectoryEmpty(dirPath)
	for name in lfs.dir(dirPath) do
		if name ~= "." and name ~= ".." then  return false  end
	end
	return true
end

-- success, errorMessage = removeEmptyDirectories( directory )
function removeEmptyDirectories(dirPath)
	for name in lfs.dir(dirPath) do
		local path = dirPath.."/"..name

		if name ~= "." and name ~= ".." and isDirectory(path) then
			removeEmptyDirectories(path)

			if isDirectoryEmpty(path) then
				log("Removing empty folder: %s", path)

				local ok, err = lfs.rmdir(path)
				if not ok then
					return false, F("Could not create directory '%s': %s", pathConstructed, err)
				end
			end
		end

	end

	return true
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
			logFile:write(s, "\n")
			logBuffer[i] = nil
		end

		logFile:write(s, "\n")
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



function isFile(path)
	return lfs.attributes(path, "mode") == "file"
end

function isDirectory(path)
	return lfs.attributes(path, "mode") == "directory"
end



F = string.format

function formatBytes(n)
	if n > (1024*1024*1024)/100 then
		return F("%.2f GB", n/(1024*1024*1024))
	elseif n > (1024*1024)/100 then
		return F("%.2f MB", n/(1024*1024))
	elseif n > (1024)/100 then
		return F("%.2f KB", n/(1024))
	end
	return F("%d bytes", n)
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



function toNormalPath(osPath)
	local path = osPath:gsub("\\", "/")
	return path
end

function toWindowsPath(path)
	local winPath = path:gsub("/", "\\")
	return winPath
end



function getDirectory(genericPath)
	return (genericPath:gsub("/?[^/]+$", ""))
end

function getFilename(genericPath)
	return genericPath:match"[^/]+$"
end

function getExtension(filename)
	return filename:match"%.([^.]+)$" or ""
end

function getBasename(filename)
	local ext = getExtension(filename)
	if ext == "" then  return filename  end

	return filename:sub(1, #filename-#ext-1)
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



-- removeItem( array, value1, ... )
function removeItem(t, ...)
	for i = 1, select("#", ...) do
		local iToRemove = indexOf(t, select(i, ...))

		if iToRemove then  table.remove(t, iToRemove)  end
	end
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



-- on( wxObject, [ id, ] eventType, callback )
do
	local eventExpanders = {
		["KEY_DOWN"] = function(e)
			return e:GetKeyCode()
		end,
	}

	function on(obj, id, eType, cb)
		if type(id) == "string" then
			id, eType, cb = nil, id, eType
		end

		local k     = "wxEVT_"..eType
		local eCode = wx[k] or wxlua[k] or wxaui[k] or wxstc[k] or errorf("Unknown event type '%s'.", eType)

		local expander = eventExpanders[eType] or NOOP

		if id then
			obj:Connect(id, eCode, wrapCall(function(e)  cb(e, expander(e))  end))
		else
			obj:Connect(    eCode, wrapCall(function(e)  cb(e, expander(e))  end))
		end
	end
end

-- id = onAccelerator( wxObject, accelerators, modKeys, keyCode, onPress )
function onAccelerator(obj, accelerators, modKeys, kc, onPress)
	assertarg(1, obj,          "userdata")
	assertarg(2, accelerators, "table")
	assertarg(3, modKeys,      "string")
	assertarg(4, kc,           "number")
	assertarg(5, onPress,      "function")

	local id    = wx.wxNewId()
	local flags = 0

	if modKeys:find("a", 1, true) then  flags = flags+WX_ACCEL_ALT    end
	if modKeys:find("c", 1, true) then  flags = flags+WX_ACCEL_CTRL   end
	if modKeys:find("s", 1, true) then  flags = flags+WX_ACCEL_SHIFT  end

	on(obj, id, "COMMAND_MENU_SELECTED", onPress)
	table.insert(accelerators, {flags, kc, id})

	return id
end



function newMenuItem(eHandler, menu, id, caption, info, onPress)
	menu:Append(id, caption, info)
	on(eHandler, id, "COMMAND_MENU_SELECTED", onPress)
end

-- button = newButton( parent, [ id, ] caption, [ position, size, ] onPress )
function newButton(parent, id, caption, pos, size, onPress)
	if type(id) == "string" then
		id, caption, pos, size, onPress = nil, id, caption, pos, size
	end
	if type(pos) == "function" then
		pos, size, onPress = nil, nil, pos
	elseif type(size) == "function" then
		size, onPress = nil, size
	end

	id   = id   or WX_ID_ANY
	pos  = pos  or WX_DEFAULT_POSITION
	size = size or WX_DEFAULT_SIZE

	local button = wx.wxButton(parent, id, caption, pos, size)
	on(button, "COMMAND_BUTTON_CLICKED", onPress)

	return button
end

-- textObject = newText( parent, [ id, ] label [, position, size ] )
function newText(parent, id, label, pos, size)
	if type(id) == "string" then
		id, label, pos, size = nil, id, label, pos
	end

	id   = id   or WX_ID_ANY
	pos  = pos  or WX_DEFAULT_POSITION
	size = size or WX_DEFAULT_SIZE

	local textObj = wx.wxStaticText(parent, id, label, pos, size)
	return textObj
end

do
	local dummyOwner = nil

	function setTimerDummyOwner(obj)
		dummyOwner = obj
	end

	-- timer = newTimer( [ milliseconds, oneShot=false, ] callback )
	function newTimer(milliseconds, oneShot, cb)
		if type(milliseconds) ~= "number" then
			milliseconds, oneShot, cb = nil, milliseconds, oneShot
		end
		if type(oneShot) ~= "boolean" then
			oneShot, cb = false, oneShot
		end

		local timer = wx.wxTimer(dummyOwner)
		timer:SetOwner(timer)

		on(timer, "TIMER", cb)

		if milliseconds then
			timer:Start(milliseconds, oneShot)
		end

		return timer
	end
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
	)
end



function iff(v, a, b)
	if v then
		return a
	else
		return b
	end
end



function showMessage(window, caption, message)
	wx.wxMessageBox(message, caption, WX_OK + WX_ICON_INFORMATION + WX_CENTRE, window)
end

function showError(window, caption, message)
	wx.wxMessageBox(message, caption, WX_OK + WX_ICON_ERROR + WX_CENTRE, window)
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

	local outputPath = getTempFilePath(true)

	if not cmdAsync(cmd.." > "..outputPath) then
		return nil, "Could not execute command: "..cmd
	end

	-- Dunno how long cmdAsync() takes to execute, so let's
	-- start the timeout timer afterwards instead of before.
	local timeStart   = getTime()
	local timeoutTime = timeStart+timeout

	-- Wait until the output file exists.
	while true do
		local time = getTime()
		socket.sleep(time < timeStart+5 and 1/30  or time < timeStart+10 and 1/5  or 1)

		if lfs.attributes(outputPath, "mode") == "file" then
			break
		end

		if time > timeoutTime then
			return nil, "Timeout while capturing output: "..cmd
		end
	end

	local file

	-- Wait until the output file is done writing.
	while true do
		local time = getTime()

		file = io.open(outputPath, "a+b")
		if file then  break  end

		if time > timeoutTime then
			return nil, "Timeout while capturing output: "..cmd
		end

		socket.sleep(time < timeStart+5 and 1/30  or time < timeStart+10 and 1/5  or 1)
	end

	file:seek("set", 0)
	local output = file:read"*a"
	file:close()

	os.remove(outputPath) -- Could fail, but we'll cleanup later.
	return output
end

-- scriptCaptureAsync( scriptName, callback, arg1, ... )
function scriptCaptureAsync(scriptName, cb, ...)
	local scriptPath = "src/scripts/"..scriptName..".lua"
	local outputPath = getTempFilePath(true)
	local cmd        = cmdEscapeArgs("bin\\wlua5.1.exe", scriptPath, ...)

	if not cmdAsync(cmd.." > "..outputPath) then
		return nil, "Could not execute command: "..cmd
	end

	local timer; timer = newTimer(1000/10, function(e)
		if not lfs.attributes(outputPath, "mode") then return end

		local file = io.open(outputPath, "a+")
		if not file then return end

		timer:Stop()

		file:seek("set", 0)
		local output = file:read"*a"
		file:close()

		os.remove(outputPath) -- Could fail, but we'll cleanup later.
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



-- path = getTempFilePath( [ asWindowsPath=false ] )
function getTempFilePath(asWindowsPath)
	assert(createDirectory("temp"))

	local path
	repeat
		path = F("temp/%06x%06x%04x", math.random(0, 0xFFFFFF), math.random(0, 0xFFFFFF), math.random(0, 0xFFFF))
	until not lfs.attributes(path, "mode")

	if asWindowsPath then
		path = path:gsub("/", "\\")
	end

	return path
end



function arrayIterator(t)
	local i = 0

	return function()
		i = i+1
		local v = t[i]

		if v ~= n then  return v  end
	end
end


