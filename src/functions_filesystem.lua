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
	createDirectory, isDirectoryEmpty, removeEmptyDirectories, emptyDirectory
	directoryItems, traverseDirectory, traverseFiles
	getDirectory, getFilename, getExtension, getBasename
	getFileContents, writeFile, copyFile
	getFileSize
	getTempFilePath
	isFile, isDirectory
	isFileWritable, isDirectoryWritable, isDirectoryRemovable
	mkdir
	openFile, deleteFile, deleteFileIfExists, removeDirectory, removeDirectoryAndChildren
	parseSimpleKv, writeSimpleKv, readSimpleEntryFile, writeSimpleEntryFile
	renameFile, renameDirectory, renameFileIfExists, renameDirectoryIfExists
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



-- success, errorMessage = createDirectory( directoryPath )
function createDirectory(dirPath)
	if not isDirectoryWritable(dirPath) then
		return false, dirPath..": Directory is not writable."
	end

	if dirPath == "" then  return false, "Empty directory path."  end

	if not mkdir(dirPath, true) then
		return false, F("Could not create directory '%s'.", dirPath)
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

-- success = emptyDirectory( directoryPath, continueOnError )
function emptyDirectory(dirPath, continueOnError)
	assertarg(1, dirPath,         "string")
	assertarg(2, continueOnError, "boolean")

	if not isDirectoryWritable(dirPath) then  return false  end

	local ok = true

	traverseDirectory(dirPath, true, function(path, pathRel, name, mode)
		local remove = (mode == "directory" and removeDirectory or deleteFile)

		if not remove(path) then
			ok = false
			logprinterror("FS", "Could not remove '%s'.", path)

			if not continueOnError then  return true  end
		end
	end)

	return ok
end



-- for name in directoryItems( directoryPath ) do
function directoryItems(dirPath)
	local dirObj = wxDir(dirPath)

	local ok, nameNext = dirObj:GetFirst("", wxDIR_FILES)
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
-- abort = callback( path, relativePath, name, mode )
-- mode  = "file"|"directory"|"other"
function traverseDirectory(dirPath, bottomUp, cb, _pathRelStart)
	if type(bottomUp) == "function" then
		bottomUp, cb = false, bottomUp
	end

	_pathRelStart = _pathRelStart or #dirPath+2

	for name in directoryItems(dirPath) do
		local path    = dirPath.."/"..name
		local pathRel = path:sub(_pathRelStart)
		local abort

		if isFile(path) then
			abort = cb(path, pathRel, name, "file")
			if abort then  return true  end

		elseif isDirectory(path) then
			if bottomUp then
				abort = traverseDirectory(path, bottomUp, cb, _pathRelStart)
				if abort then  return true  end
			end

			abort = cb(path, pathRel, name, "directory")
			if abort then  return true  end

			if not bottomUp then
				abort = traverseDirectory(path, bottomUp, cb, _pathRelStart)
				if abort then  return true  end
			end

		else
			abort = cb(path, pathRel, name, "other")
			if abort then  return true  end
		end
	end

end

-- traverseFiles( directoryPath, callback )
-- abort = callback( path, relativePath, filename, extension )
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

-- success, errorMessage = copyFile( fromPath, toPath )
function copyFile(pathFrom, pathTo)
	local dirPath = getDirectory(pathTo)
	if not isDirectoryWritable(dirPath) then
		return false, dirPath..": Directory is not writable."
	end

	if not wxCopyFile(pathFrom, pathTo) then
		return false, F("Could not copy '%s' to '%s'.", pathFrom, pathTo)
	end
	return true
end



-- fileSize, errorMessage = getFileSize( path )
function getFileSize(path)
	-- Note: We can't use wxFileSize() because it returns an int32, which is too
	-- small and just unbelievable. Why, people, why?! Sigh!

	local file = wxFile(path)
	if not file:IsOpened() then  return nil, F("Could not open '%s'.", path)  end

	local size = file:Length()
	file:Close()

	return size
end



--[[ path = getTempFilePath( [ asWindowsPath=false ] )
function getTempFilePath(asWindowsPath)
	local path = DIR_TEMP.."/"..os.tmpname():gsub("[\\/]+", ""):gsub("%.$", "")
	-- writeFile(path, "") -- May want to do this.

	if asWindowsPath then  path = toWindowsPath(path)  end

	return path
end
-- ]]



function isFile(path)
	return wxFileName.FileExists(path)
end

function isDirectory(path)
	return wxFileName.DirExists(path)
end



function isFileWritable(path)
	if not isDirectoryWritable(getDirectory(path)) then  return false  end

	return wxFileName.IsFileWritable(path)
end

function isDirectoryWritable(dirPath)
	if bypassDirectoryProtection then  return true  end

	for _, writableDir in ipairs(WRITABLE_DIRS) do
		local len = #writableDir
		local c   = dirPath:sub(len+1, len+1)

		if (c == "/" or c == "") and dirPath:sub(1, len) == writableDir then
			return true
		end
	end

	return false
end

function isDirectoryRemovable(dirPath)
	if bypassDirectoryProtection then  return true  end

	for _, writableDir in ipairs(WRITABLE_DIRS) do
		local len = #writableDir

		if dirPath:sub(len+1, len+1) == "/" and dirPath:sub(1, len) == writableDir then
			return true
		end
	end

	return false
end



-- success = mkdir( directoryPath [, full=false ] )
function mkdir(dirPath, full)
	if not isDirectoryWritable(dirPath) then  return false  end

	if dirPath == "" then  return true  end

	local flags = (full and wxPATH_MKDIR_FULL or 0)
	return wxFileName.Mkdir(dirPath, 4095, flags)
end



function openFile(path, modeFull)
	-- Extra protection against wxFileDialog() (and maybe others) changing CWD however they want. Ugh.
	if not (path:find"^[/\\]" or path:find"^%a:[/\\]") then
		path = DIR_APP.."/"..path
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

	local dirPath = getDirectory(path)
	if mode ~= "r" and not isDirectoryWritable(dirPath) then
		return nil, dirPath..": Directory is not writable."
	end

	local file
	local bufferingMode = "full"

	-- @Robustness: Need to test more and stuff here.

	-- Note: The following wxFile() calls may trigger the annoying wxLua error dialog if the
	-- file doesn't exist. Ugh.

	-- read: Open file for input operations. The file must exist.
	if     mode == "r"  then
		file = wxFile(path, wxFILE_MODE_READ)

	-- write: Create an empty file for output operations. If a file with the same name already
	-- exists, its contents are discarded and the file is treated as a new empty file.
	elseif mode == "w"  then
		file = wxFile(path, wxFILE_MODE_WRITE)

	-- append: Open file for output at the end of a file. Output operations always write data
	-- at the end of the file, expanding it. Repositioning operations (fseek, fsetpos, rewind)
	-- are ignored. The file is created if it does not exist.
	elseif mode == "a"  then
		file = wxFile(path, wxFILE_MODE_APPEND)

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
		file = wxFile(path, wxFILE_MODE_READWRITE)
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

	-- http://www.lua.org/manual/5.1/manual.html#5.7
	local fileWrapper = setmetatable({}, {__index={

		-- success, errorMessage = file:close( )
		close = function(fileWrapper)
			-- Allow multiple calls to close().
			if not file:IsOpened() then  return nil, "File is already closed."  end

			file:Close()
			if file:IsOpened() then
				return nil, "Could not close file."
			end

			collectgarbage() -- Seems to fix "Program stopped working" on exit.
			return true
		end,

		-- success, errorMessage = file:flush( )
		flush = function(fileWrapper)
			checkOpen()
			if not file:Flush() then
				return nil, "Could not flush the file buffer."
			end
			return true
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
					errorf("Bad type of read format (string or number expected, got %s)", type(offset))

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
					errorf("Bad read format string '%s'", readFormat)
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
				return nil, F("Bad type of whence (string expected, got %s)", type(whence))
			end
			if type(offset) ~= "number" then
				return nil, F("Bad type of offset (number expected, got %s)", type(offset))
			end

			local pos
			if whence == "set" then
				pos = file:Seek(offset, wxSEEK_MODE_FROM_START)
			elseif whence == "cur" then
				pos = file:Seek(offset, wxSEEK_MODE_FROM_CURRENT)
			elseif whence == "end" then
				pos = file:Seek(offset, wxSEEK_MODE_FROM_END)
			else
				return nil, F("Bad whence value '%s'.", whence)
			end

			if pos == wxSEEK_MODE_INVALID_OFFSET then
				return nil, F("Bad offset %d", offset)
			end

			return file:Tell()
		end,

		-- success, errorMessage = file:setvbuf( mode [, size ] )
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
				errorf(2, "Bad buffering mode '%s'.", _bufMode)
			end

			return true
		end,

		-- file:write( ... )
		write = function(fileWrapper, ...)
			checkOpen()

			for i = 1, select("#", ...) do
				local v = select(i, ...)

				if type(v) == "string" then
					if not binary then
						v = v:gsub("\n", "\r\n")
					end

				elseif type(v) == "number" then
					v = tostring(v)

				else
					errorf(2, "Cannot write values of type '%s'.", type(v))
				end

				local sizeToWrite = #v
				local sizeWritten = file:Write(v, sizeToWrite)

				if sizeWritten ~= sizeToWrite then
					errorf(2, "Could not write to file.")
				end

				if bufferingMode == "no" then
					file:Flush()
				end
			end

			return true
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

-- success = deleteFile( path )
function deleteFile(path)
	if not isDirectoryWritable(getDirectory(path)) then  return false  end

	return wxRemoveFile(path)
end

-- success = deleteFileIfExists( path )
function deleteFileIfExists(path)
	if not isFile(path) then  return true  end

	return deleteFile(path)
end

-- success = removeDirectory( directoryPath )
-- Only works on empty directories.
function removeDirectory(dirPath)
	if not isDirectoryRemovable(dirPath) then  return false  end

	local ok = wxRmdir(dirPath)
	collectgarbage() -- @Ugh

	return ok
end

-- success = removeDirectoryAndChildren( directoryPath, continueOnError )
function removeDirectoryAndChildren(dirPath, continueOnError)
	assertarg(1, dirPath,         "string")
	assertarg(2, continueOnError, "boolean")

	if not isDirectoryRemovable(dirPath) then  return false  end

	emptyDirectory(dirPath, continueOnError)
	return removeDirectory(dirPath)
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
	path = wxFileName(path).ShortPath

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



-- success, errorMessage = renameFile( oldPath, newPath [, overwrite=false ] )
function renameFile(pathOld, pathNew, overwrite)
	overwrite = overwrite or false

	if not isDirectoryWritable(getDirectory(pathOld)) then
		return false, getDirectory(pathOld)..": Directory contents are not movable."
	end
	if not isDirectoryWritable(getDirectory(pathNew)) then
		return false, getDirectory(pathNew)..": Directory is not writable."
	end

	if wxRenameFile(pathOld, pathNew, overwrite) then  return true  end

	-- The paths may point to different drives, in which case wxRenameFile() fails (I think).
	-- Try copying the file manually instead.

	if wxCopyFile(pathOld, pathNew, overwrite) then  return true  end

	-- @Incomplete: Preserve timestamps.

	local ok = deleteFile(pathOld)
	if not ok then
		err = F("Could not delete '%s' while moving.", pathOld)
		return false
	end

	return false, F("Could not rename '%s' to '%s'.", pathOld, pathNew)
end

-- success, errorMessage = renameDirectory( oldPath, newPath [, overwrite=false ] )
-- Note: If newPath exists then the old and new directories are merged.
function renameDirectory(dirSource, dirTarget, overwrite)
	overwrite = overwrite or false

	if not isDirectoryRemovable(dirSource) then
		return false, dirSource..": Directory is not movable."
	end
	if not isDirectoryRemovable(dirTarget) then
		return false, dirTarget..": Directory is not writable."
	end

	local ok, err = wxRenameFile(dirSource, dirTarget, overwrite)
	if ok then  return true  end

	-- The paths may point to different drives, in which case wxRenameFile() fails (I think).
	-- Try moving each file manually instead.

	-- @Robustness: Maybe undo previous operations on error?

	local ok, err = createDirectory(dirSource)
	if not ok then  return false, err  end

	local createdDirs = {}

	traverseDirectory(dirSource, true, function(pathOld, pathRel, name, mode)
		if mode == "directory" then
			ok = removeDirectory(pathOld)
			if not ok then
				err = F("Could not delete '%s' while moving.", pathOld)
				return true
			end

		else
			local pathNew = dirTarget.."/"..pathRel
			local dirNew  = getDirectory(pathNew)

			if not createdDirs[dirNew] then
				ok, err = createDirectory(dirNew)
				if not ok then  return true  end -- Break.

				createdDirs[dirNew] = true
			end

			ok = wxCopyFile(pathOld, pathNew, overwrite)
			if not ok then
				err = F("Could not copy '%s' to '%s' while moving.", pathOld, pathNew)
				return true
			end

			-- @Incomplete: Preserve timestamps.

			ok = deleteFile(pathOld)
			if not ok then
				err = F("Could not delete '%s' while moving.", pathOld)
				return true
			end
		end
	end)
	if not ok then  return false, err  end

	ok = removeDirectory(dirSource)
	if not ok then
		err = F("Could not delete '%s' while moving.", dirSource)
		return true
	end

	return true
end

-- success, errorMessage = renameFileIfExists( oldPath, newPath [, overwrite=false ] )
-- success is true if the file does not exist.
function renameFileIfExists(pathOld, pathNew, overwrite)
	if not isFile(pathOld) then  return true  end

	return renameFile(pathOld, pathNew, overwrite)
end

-- success, errorMessage = renameDirectoryIfExists( oldPath, newPath [, overwrite=false ] )
-- success is true if the directory does not exist.
-- Note: If newPath exists then the old and new directories are merged.
function renameDirectoryIfExists(dirSource, dirTarget, overwrite)
	if not isDirectory(dirSource) then  return true  end

	return renameDirectory(dirSource, dirTarget, overwrite)
end


