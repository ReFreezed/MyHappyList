--[[============================================================
--=
--=  Program Updater
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

DIR_EXE = "."

require"src.loadBasic"

package.cpath
	= DIR_EXE.."/misc/Update/?.dll;"
	..DIR_EXE.."/misc/Update/?51.dll;"

require"load"

_G.args  = {...}
_G.isApp = true

local function update()
	logStart("update")
	logHeader()

	local path, pid = unpack(args)
	assert(path, "no path")

	pid = tonumber(pid)

	if pid then
		logprint(nil, "Waiting for process %d to stop.", pid)

		local timeout = os.time()+10
		while wxProcess.Exists(pid) and os.time() < timeout do
			wxMilliSleep(100)
		end
	end

	-- path = "D:/Projects/Lua/MyHappyList/local/archive/MyHappyList_1.0.4_Win32.zip" -- DEBUG
	local unzipDir = updater_getUnzipDir()
	if isDirectory(unzipDir) then
		assert(removeDirectoryAndChildren(unzipDir, false))
	end
	assert(unzip(path, unzipDir, true))

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
		"app",
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
		"misc/AppIcon", -- Don't try to remove misc/Update!
		"src",
		"utils",
	} do
		dirPath = DIR_APP.."/"..dirPath

		if isDirectory(dirPath) then
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
	end

	-- Move new files.
	--------------------------------

	updater_moveFilesAfterUnzipMain(dangerModeActive)

	--==============================================================

	if not cmdDetached("MyHappyList.exe", "--afterupdate", wxGetProcessId()) then
		error("Could not start MyHappyList.exe.")
	end

	logprint(nil, "All done.")
	logEnd()
	os.exit(0)
end

xpcall(update, handleError)
os.exit(9) -- We should never get here!
