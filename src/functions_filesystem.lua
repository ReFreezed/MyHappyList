--[[============================================================
--=
--=  Global Functions - Filesystem
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	backupFileIfExists
	createDirectory, isDirectoryEmpty, removeEmptyDirectories
	directoryItems, traverseDirectory, traverseFiles
	getDirectory, getFilename, getExtension, getBasename
	getFileContents, writeFile
	getFileSize
	getTempFilePath
	isFile, isFileWritable, isDirectory
	mkdir
	openFile, deleteFile
	parseSimpleKv, writeSimpleKv, readSimpleEntryFile, writeSimpleEntryFile
	toNormalPath, toWindowsPath, toShortPath
	writef, writeLine

--============================================================]]



-- success, errorMessage = backupFileIfExists( path )
-- Note: success is true if the file doesn't exist.
function backupFileIfExists(path)
	if isFile(path) then
		return writeFile(path..".bak", assert(getFileContents(path)))
	end
	return true
end



-- success, errorMessage = createDirectory( path )
function createDirectory(path)
	if path == "" then  return  end

	if path:find"^/" or path:find"^%a:" then
		return false, F("[internal] Absolute paths are disabled. (%s)", path)
	end

	if not mkdir(path, true) then
		return false, F("Could not create directory '%s'.", path)
	end

	return true
end

--[[
function isDirectoryEmpty(dirPath)
	for name in directoryItems(dirPath) do
		return false
	end
	return true
end

-- success, errorMessage = removeEmptyDirectories( directory )
function removeEmptyDirectories(dirPath)
	for name in directoryItems(dirPath) do
		local path = dirPath.."/"..name

		if isDirectory(path) then
			removeEmptyDirectories(path)

			if isDirectoryEmpty(path) then
				log("Removing empty folder: %s", path)

				local ok, err = lfs?.rmdir(path) -- Don't use lfs!
				if not ok then
					return false, F("Could not create directory '%s': %s", pathConstructed, err)
				end
			end
		end

	end

	return true
end
]]



-- for name in directoryItems( directoryPath ) do
function directoryItems(dirPath)
	local dirObj = wxDir(dirPath)

	local ok, nameNext = dirObj:GetFirst()
	if not ok then  nameNext = nil  end

	return function()
		local name = nameNext

		ok, nameNext = dirObj:GetNext()
		if not ok then  nameNext = nil  end

		collectgarbage() -- Fixes directories not being removable.
		if name then  return name  end
	end
end

-- traverseDirectory( directoryPath, [ bottomUp=false, ] callback )
-- callback = function( path, relativePath, name, mode )
-- mode     = "file"|"directory"
function traverseDirectory(dirPath, bottomUp, cb, _pathRelStart)
	if type(bottomUp) == "function" then
		bottomUp, cb = false, bottomUp
	end

	_pathRelStart = _pathRelStart or #dirPath+2

	for name in directoryItems(dirPath) do
		local path = dirPath.."/"..name

		if isFile(path) then
			local pathRel = path:sub(_pathRelStart)
			local abort   = cb(path, pathRel, name, "file")
			if abort then  return true  end

		elseif isDirectory(path) then
			if bottomUp then
				local abort = traverseDirectory(path, bottomUp, cb, _pathRelStart)
				if abort then  return true  end
			end

			local pathRel = path:sub(_pathRelStart)
			local abort   = cb(path, pathRel, name, "directory")
			if abort then  return true  end

			if not bottomUp then
				local abort = traverseDirectory(path, bottomUp, cb, _pathRelStart)
				if abort then  return true  end
			end
		end
	end

end

-- traverseFiles( directoryPath, callback )
-- callback = function( path, relativePath, filename, extension )
function traverseFiles(dirPath, cb, _pathRelStart)
	_pathRelStart = _pathRelStart or #dirPath+2

	for name in directoryItems(dirPath) do
		local path = dirPath.."/"..name

		if isFile(path) then
			local pathRel  = path:sub(_pathRelStart)
			local ext      = getExtension(name)
			local abort    = cb(path, pathRel, name, ext)
			if abort then  return true  end

		elseif isDirectory(path) then
			local abort = traverseFiles(path, cb, _pathRelStart)
			if abort then  return true  end
		end
	end

end



function getDirectory(genericPath)
	return (genericPath:gsub("[/\\]?[^/\\]+$", ""))
end

function getFilename(genericPath)
	return genericPath:match"[^/\\]+$"
end

function getExtension(filename)
	return filename:match"%.([^.]+)$" or ""
end

function getBasename(filename)
	local ext = getExtension(filename)
	if ext == "" then  return filename  end

	return filename:sub(1, #filename-#ext-1)
end



-- contents, errorMessage = getFileContents( path [, isText=false ] )
function getFileContents(path, isText)
	local file, err = openFile(path, (isText and "r" or "rb"))
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

	local file, err = openFile(path, (isText and "w" or "wb"))
	if not file then  return nil, err  end

	file:write(contents)
	file:close()

	return true
end



function getFileSize(path)
	-- Note: We can't use wxFileSize() because it returns an int32, which is just unbelievable. Why, people, why? Sigh!

	local file = wxFile(path)
	if not file:IsOpened() then  return nil  end

	local size = file:Length()
	file:Close()

	return size
end



-- path = getTempFilePath( [ asWindowsPath=false ] )
function getTempFilePath(asWindowsPath)
	local path = "temp/"..os.tmpname():gsub("[\\/]+", ""):gsub("%.$", "")
	-- writeFile(path, "") -- May want to do this.

	if asWindowsPath then  path = toWindowsPath(path)  end

	return path
end



function isFile(path)
	return wxFileName.FileExists(path)
end

function isFileWritable(path)
	return wxFileName.IsFileWritable(path)
end

function isDirectory(path)
	return wxFileName.DirExists(path)
end



-- success = mkdir( path [, full=false ] )
function mkdir(path, full)
	local flags = (full and wxPATH_MKDIR_FULL or 0)
	return wxFileName.Mkdir(path, 4095, flags)
end



do
	local modes = {
		["r"]  = wxFile.read,
		["w"]  = wxFile.write,
		["a"]  = wxFile.write_append,
		["r+"] = wxFile.read_write,
		["w+"] = wxFile.read_write,
		["a+"] = wxFile.read_write,
	}

	function openFile(path, modeFull)
		-- Extra protection against wxFileDialog() (and maybe others) changing CWD however they want. Ugh.
		if not (path:find"^[/\\]" or path:find"^%a:[/\\]") then
			path = APPDIR.."/"..path
		end

		local mode, access, update, binary = modeFull:match"^(([rwa]+)(%+?))(b?)$"
		if not mode then
			mode, access, binary, update = modeFull:match"^(([rwa]+)(b?)(%+?))$"
		end
		if not mode then
			return nil, F("Invalid mode '%s'.", modeFull)
		end

		update = (update == "+")
		binary = (binary == "b" or not wxGetOsDescription():find"Windows")

		if mode == "r" and not isFile(path) then
			return nil, path..": File does not exist"
		end

		local file
		local bufferingMode = "full"

		-- @Robustness: Need to test more and stuff here.

		-- Note: The following wxFile() calls may trigger the annoying wxLua error dialog if the
		-- file doesn't exist. Ugh.

		-- read: Open file for input operations. The file must exist.
		if     mode == "r"  then
			file = wxFile(path, wxFile.read)

		-- write: Create an empty file for output operations. If a file with the same name already
		-- exists, its contents are discarded and the file is treated as a new empty file.
		elseif mode == "w"  then
			file = wxFile(path, wxFile.write)

		-- append: Open file for output at the end of a file. Output operations always write data
		-- at the end of the file, expanding it. Repositioning operations (fseek, fsetpos, rewind)
		-- are ignored. The file is created if it does not exist.
		elseif mode == "a"  then
			file = wxFile(path, wxFile.write_append)

		-- read/update: Open a file for update (both for input and output). The file must exist.
		elseif mode == "r+" then
			errorf(2, "Mode '%s' is not implemented or tested yet.", mode) -- @Incomplete

		-- write/update: Create an empty file and open it for update (both for input and output).
		-- If a file with the same name already exists its contents are discarded and the file is
		-- treated as a new empty file.
		elseif mode == "w+" then
			errorf(2, "Mode '%s' is not implemented or tested yet.", mode) -- @Incomplete

		-- append/update: Open a file for update (both for input and output) with all output
		-- operations writing data at the end of the file. Repositioning operations (fseek, fsetpos,
		-- rewind) affects the next input operations, but output operations move the position back
		-- to the end of file. The file is created if it does not exist.
		elseif mode == "a+" then
			file = wxFile(path, wxFile.read_write)
		end

		if not file:IsOpened() then
			return nil, path..": Could not open file"
		end

		if mode == "a+" then
			file:SeekEnd()
		end

		local function checkOpen()
			if not file:IsOpened() then
				error("attempt to use a closed file", 3)
			end
		end

		local fileWrapper = setmetatable({}, {__index={

			-- file:close( )
			close = function(fileWrapper)
				checkOpen()
				file:Close()
			end,

			-- file:flush( )
			flush = function(fileWrapper)
				checkOpen()
				file:Flush()
			end,

			-- for line in file:lines( ) do
			lines = function(fileWrapper)
				checkOpen()

				return function()
					local line = fileWrapper:read"*l"
					if line then  return line  end
				end
			end,

			-- ... = file:read( readFormat1, ... )
			read = function(fileWrapper, readFormat, ...)
				checkOpen()

				readFormat     = readFormat or "*l"
				local argsLeft = 1+select("#", ...)

				local function read(readFormat, ...)
					argsLeft = argsLeft-1
					if argsLeft < 0 then  return  end

					-- Read bytes.
					if type(readFormat) == "number" then
						if file:Eof() then  return nil  end

						local _, s = file:Read(readFormat)
						return s, read(...)

					elseif type(readFormat) ~= "string" then
						errorf("bad type of read format (string or number expected, got %s)", type(offset))

					-- Read line.
					elseif readFormat:find"^*l" then
						if file:Eof() then  return nil  end

						local chars = {}
						local count, c

						while true do
							count, c = file:Read(1)

							-- EOF reached.
							if count == 0 then
								break

							-- EOL reached.
							elseif c == "\n" then
								if not binary and chars[#chars] == "\r" then
									chars[#chars] = nil
								end
								break

							-- Normal character.
							else
								table.insert(chars, c)
							end
						end

						return table.concat(chars)

					-- Read rest of file.
					elseif readFormat:find"^*a" then
						local _, s = file:Read(file:Length()-file:Tell()) -- Length may go past EOF, but that doesn't matter.

						if not binary then
							s = s:gsub("\r\n", "\n")
						end

						return s, read(...)

					-- Read number (and return a number instead of a string).
					elseif readFormat:find"^*n" then
						error("Cannot read numbers - file:read() is not fully implemented.") -- @Incomplete

					else
						errorf("bad read format string '%s'", readFormat)
					end
				end

				return read(readFormat, ...)
			end,

			-- position, errorMessage = file:seek( [ whence ] [, offset ] )
			seek = function(fileWrapper, whence, offset)
				checkOpen()

				if type(whence) == "number" then
					whence, offset = nil, whence
				end

				whence = whence or "cur"
				offset = offset or 0

				if type(whence) ~= "string" then
					return nil, F("bad type of whence (string expected, got %s)", type(whence))
				end
				if type(offset) ~= "number" then
					return nil, F("bad type of offset (number expected, got %s)", type(offset))
				end

				local pos
				if whence == "set" then
					pos = file:Seek(offset, wxSEEK_MODE_FROM_START)
				elseif whence == "cur" then
					pos = file:Seek(offset, wxSEEK_MODE_FROM_CURRENT)
				elseif whence == "end" then
					pos = file:Seek(offset, wxSEEK_MODE_FROM_END)
				else
					return nil, F("bad whence value '%s'.", whence)
				end

				if pos == wxSEEK_MODE_INVALID_OFFSET then
					return nil, F("bad offset %d", offset)
				end

				return file:Tell()
			end,

			-- file:setvbuf( mode [, size ] )
			setvbuf = function(fileWrapper, _bufMode, size)
				checkOpen()
				logprintOnce("FS", "Warning: file:setvbuf() is not fully implemented.") -- @Incomplete

				if _bufMode == "no" then
					bufferingMode = _bufMode
					file:Flush()

				elseif _bufMode == "full" then
					bufferingMode = _bufMode

				elseif _bufMode == "line" then
					bufferingMode = _bufMode

				else
					errorf(2, "bad buffering mode '%s'.", _bufMode)
				end
			end,

			-- file:write( ... )
			write = function(fileWrapper, ...)
				for i = 1, select("#", ...) do
					local v = select(i, ...)

					if type(v) == "string" then
						if not binary then
							v = v:gsub("\n", "\r\n")
						end
						file:Write(v, #v)

					elseif type(v) == "number" then
						v = tostring(v)
						file:Write(v, #v)

					else
						errorf(2, "cannot write values of type '%s'.", type(v))
					end

					if bufferingMode == "no" then
						file:Flush()
					end
				end
			end,

		}})

		return fileWrapper

		--[[ Having the file objects being userdata would be good, but these operations are a bit... questionable.
		local file = wxObject()

		local mt = {__index={
			read = function(file, ...)
			end,
		}}

		debug.setmetatable(file, mt) -- Is this ok? Are we gonna corrupt memory or something?
		]]
	end

	--[=[ Test the modes.
	--[[
	local file = assert(openFile("local/test.txt", "w"))
	-- local file = assert(io.open("local/test.txt", "w"))
	file:write("Hallå!\nJapp nr. ", 5, "\n")
	--]]

	--[[
	local file = assert(openFile("local/test.txt", "a+"))
	-- local file = assert(io.open("local/test.txt", "a+"))
	file:setvbuf("no")
	file:write("Hallå!\nJapp nr. ", 5, "\n")
	file:seek("set")
	print('"'..tostring(file:read"*a")..'"')
	--]]

	-- [[
	local file = assert(openFile("local/test.txt", "r"))
	-- local file = assert(io.open("local/test.txt", "r"))
	-- print('"'..tostring(file:read"*l")..'"')
	-- print('"'..tostring(file:read"*a")..'"')
	-- print('"'..tostring(file:read"*l")..'"')
	-- print('"'..tostring(file:read"*a")..'"')
	for line in file:lines() do
		print('"'..line..'"', line:byte(1, #line))
	end
	--]]

	file:close()
	os.exit(1)
	--]=]
end

function deleteFile(path)
	return wxRemoveFile(path)
end



function toNormalPath(osPath)
	local path = osPath:gsub("\\", "/")
	return path
end

function toWindowsPath(path)
	local winPath = path:gsub("/", "\\")
	return winPath
end

-- path = toShortPath( path [, asWindowsPath=false ] )
-- Note: May return the path as-is if the file doesn't exist.
function toShortPath(path, asWindowsPath)
	path = wxFileName(path):GetShortPath()

	if not asWindowsPath then  path = toNormalPath(path)  end

	return path
end



function writef(file, s, ...)
	file:write(s:format(...))
end

function writeLine(file, ...)
	file:write(...)
	file:write("\n")
end



-- key, value = parseSimpleKv( line, path, lineNumber )
function parseSimpleKv(line, path, ln)
	if line == "" then  return nil  end

	local k, v = line:match"^(%S+) +(%S.*)$"

	if not k then
		logprinterror("FS", "%s:%d: Bad line format: %s", path, ln, line)
		return nil
	end

	local chunk, err = loadstring("return "..v, "")
	if not chunk then
		err = err :gsub('^%[string ""%]:1: ', "") :gsub("<eof>", "<eol>")
		logprinterror("FS", "%s:%d: Malformed value: %s. ('%s')", path, ln, err, line)
		return nil
	end

	return k, (chunk())
end

-- everythingWentOk = writeSimpleKv( file, k, v, path )
function writeSimpleKv(file, k, v, path, _partOfValue)
	local vType = type(v)
	local allOk = true

	-- Number.
	if vType == "number" then
		if not isInt(v) then
			allOk = false
			logprinterror("FS", "%s: Non-integer number disabled. Skipping. (%s, '%s')", path, k, tostring(v))
		else
			if not _partOfValue then  file:write(k, " ")  end
			writef(file, "%.0f", v) -- "%d" messes up large ints, thus the "%.0f".
			if not _partOfValue then  file:write("\n")  end
		end

	-- String.
	elseif vType == "string" then
		local s = F("%q", v) :gsub("\\\n", "\\n")

		if not _partOfValue then  file:write(k, " ")  end
		file:write(s)
		if not _partOfValue then  file:write("\n")  end

	-- Boolean/nil.
	elseif vType == "boolean" or v == nil then
		if not _partOfValue then  file:write(k, " ")  end
		file:write(tostring(v))
		if not _partOfValue then  file:write("\n")  end

	-- Table (flat).
	elseif vType == "table" and not _partOfValue then
		local isKvTable = (type(next(v)) == "string")

		if isKvTable then
			for k in pairs(v) do
				if type(k) ~= "string" then
					allOk = false
					logprinterror("FS", "%s: Table is not a sequence or simple. Skipping. (%s, '%s')", path, k, tostring(v))
					break
				end
			end
		else
			for i in pairs(v) do
				if not isInt(i) or i < 1 or i > #v then
					allOk = false
					logprinterror("FS", "%s: Table is not a sequence or simple. Skipping. (%s, '%s')", path, k, tostring(v))
					break
				end
			end
		end

		if allOk then
			file:write(k, " {") -- Note: _partOfValue is always false here.

			if isKvTable then
				for itemKey, item, i in pairsSorted(v) do
					if i > 1 then  file:write(",")  end

					if itemKey:find"^[%a_][%w_]*$" then
						file:write(itemKey, "=")
					else
						local s = F("[%q]=", itemKey) :gsub("\\\n", "\\n")
						file:write(s)
					end

					if not writeSimpleKv(file, k.."["..itemKey.."]", item, path, true) then
						file:write("nil")
					end
				end

			else
				for i, item in ipairs(v) do
					if i > 1 then  file:write(",")  end

					if not writeSimpleKv(file, k.."["..i.."]", item, path, true) then
						file:write("nil")
					end
				end
			end

			file:write("}\n")
		end

	else
		allOk = false
		logprinterror("FS", "%s: Cannot write type '%s'. Skipping. (%s)", path, vType, k)
	end

	return allOk
end

-- entry, errorMessage = readSimpleEntryFile( path [, entry={}, onlyUpdateExistingFields=false ] )
function readSimpleEntryFile(path, t, onlyUpdateExistingFields)
	local file, err = openFile(path, "r")
	if not file then  return nil, err  end

	t = t or {}
	local ln = 0

	for line in file:lines() do
		ln = ln+1
		local k, v = parseSimpleKv(line, path, ln)

		if k and not (onlyUpdateExistingFields and type(v) ~= type(t[k])) then
			if t[k] ~= nil and not onlyUpdateExistingFields then
				logprinterror("FS", "%s:%d: Duplicate key '%s'. Overwriting.", path, ln, k)
			end
			t[k] = v
		end
	end

	file:close()
	return t
end

-- success, errorMessage = writeSimpleEntryFile( path, entry [, backup=true ] )
function writeSimpleEntryFile(path, t, backup)
	assertarg(1, path,   "string")
	assertarg(2, t,      "table")
	assertarg(3, backup, "boolean","nil")

	if backup ~= false then  backupFileIfExists(path)  end

	local file, err = openFile(path, "w")
	if not file then  return false, err  end

	for k, v in pairsSorted(t) do
		writeSimpleKv(file, k, v, path)
	end

	file:close()
	return true
end


