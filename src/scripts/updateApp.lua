--[[============================================================
--=
--=  Update App Script
--=
--=  Args: pathToZip [ processToWaitForBeforeUpdating ]
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

_G.isApp = true

logStart("update")
logHeader()

local path, pid = unpack(args)
assert(path, "no path")

if pid then
	pid = tonumber(pid)

	-- @Robustness: Timeout the wait.
	while wxProcess.Exists(pid) do
		wxMilliSleep(100)
	end
end

-- path = "D:/Projects/Lua/MyHappyList/local/archive/MyHappyList_1.0.4_Win32.zip" -- DEBUG
local UNZIP_DIR = DIR_TEMP.."/LatestVersion"
if isDirectory(UNZIP_DIR) then
	assert(removeDirectoryAndChildren(UNZIP_DIR, false))
end
unzip(path, UNZIP_DIR, true)

-- Start doing dangerous stuff.
--==============================================================

-- !!! IMPORTANT !!!
local dangerModeActive = (appZip ~= nil)
-- !!! IMPORTANT !!!

if appZip then
	appZip:close()
	appZip = nil
end

if dangerModeActive then
	table.insert(WRITABLE_DIRS, DIR_APP)
end

collectgarbage() -- In case wx is doing something silly.

-- Remove old files.
-- We make sure to not delete files that will be moved to %APPDATA% etc.
--------------------------------

for _, path in ipairs{
	"Changelog.txt",
	"LICENSE - 3rd parties.txt",
	"LICENSE.txt",
	"LICENSES.txt",
	"lua5.1.dll",
	"lua5.1.exe",
	"lua51.dll",
	"main.lua",
	"MyHappyList.exe",
	"README.md",
	"wlua5.1.exe",
} do
	path = DIR_APP.."/"..path

	if dangerModeActive then
		logprint(nil, "Removing %s", path)
		assert(deleteFileIfExists(path))
	else
		if isFile(path) then  logprint("Sim", "Remove file: %s", path)  end
	end
end

for _, dirPath in ipairs{
	"bin",
	"gfx",
	"lib",
	"src",
	"utils",
} do
	dirPath = DIR_APP.."/"..dirPath

	if dangerModeActive then
		logprint(nil, "Removing %s", dirPath)
		assert(removeDirectoryAndChildren(dirPath, false))
	else
		traverseDirectory(dirPath, true, function(path, pathRel, name, mode)
			logprint("Sim", "  Remove %s: %s", mode, path)
		end)
		logprint("Sim", "Remove directory: %s", dirPath)
	end
end

-- Move new files.
--------------------------------

traverseDirectory(UNZIP_DIR, function(pathOld, pathRel, name, mode)
	local pathNew = DIR_APP.."/"..pathRel

	if mode == "directory" then
		if dangerModeActive then
			logprint(nil, "Creating %s", pathNew)
			assert(createDirectory(pathNew))
		else
			logprint("Sim", "Create directory: %s", pathNew)
		end

	else
		if dangerModeActive then
			logprint(nil, "Moving %s", pathNew)
			assert(renameFile(pathOld, pathNew))
		else
			logprint("Sim", "Move file to: %s", pathNew)
		end
	end
end)

--==============================================================

local cmd = cmdEscapeArgs("MyHappyList.exe", "--updated")

if not processStart(cmd, PROCESS_METHOD_DETACHED) then
	error("Could not start MyHappyList.exe.")
end

logprint(nil, "All done.")
logEnd()
