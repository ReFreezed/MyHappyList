--[[============================================================
--=
--=  Release Build Script
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
require"load"

local DIR_ZIP           = DIR_TEMP.."/zip"

local DIR_OUTPUT        = "output"
local DIR_OUTPUT_WIN32  = DIR_OUTPUT.."/Win32"
local DIR_CONTENT_WIN32 = DIR_OUTPUT_WIN32.."/"..APP_NAME

local PATH_7Z           = "utils/7-Zip/7z.exe"
local PATH_IM           = "utils/ImageMagick/convert.exe"
local PATH_RH           = "misc/Build/ResourceHacker.cmd"--"utils/ResourceHacker/ResourceHacker.exe"
local PATH_SR_EXE       = "utils/srlua/wsrlua.exe"
local PATH_SR_GLUE      = "utils/srlua/glue.exe"

local FILES_OUTSIDE_ZIP = {"src/load.lua", "src/loadBasic.lua", "src/script.lua"}

----------------------------------------------------------------

local function outputFile(pathSource, pathTarget)
	pathTarget = pathTarget or pathSource
	logprint("Build", "Output: "..pathTarget)

	local pathOut = DIR_CONTENT_WIN32.."/"..pathTarget
	assert(createDirectory(getDirectory(pathOut)))
	assert(copyFile(pathSource, pathOut))
end

local function outputFileForZip(pathSource, pathTarget)
	pathTarget = pathTarget or pathSource
	logprint("Build", "Output(zip): "..pathTarget)

	local pathOut = DIR_ZIP.."/"..pathTarget
	assert(createDirectory(getDirectory(pathOut)))
	assert(copyFile(pathSource, pathOut))
end

----------------------------------------------------------------

bypassDirectoryProtection = true

----------------------------------------------------------------
logprint("Build", "Preparing folders...")

assert(createDirectory(DIR_TEMP))
assert(createDirectory(DIR_CONTENT_WIN32))

assert(emptyDirectory(DIR_TEMP, false))
assert(emptyDirectory(DIR_CONTENT_WIN32, false))

logprint("Build", "Preparing folders... done!")

----------------------------------------------------------------
logprint("Build", "Making ico...")
run(PATH_IM, "misc/AppIcon/AppIcon0*.png", "gfx/appicon.ico")
logprint("Build", "Making ico... done!")

----------------------------------------------------------------
logprint("Build", "Making exe...")

local UPDATE_EXE_TEMPLATE = [[
[FILENAMES]
Exe    = "${tempDir}\App.exe"
SaveAs = "${tempDir}\App.exe"
Log    = CONSOLE

[COMMANDS]
-delete ,,
-add "${tempDir}\AppInfo.res", ,,
-add "${appDir}\gfx\appicon.ico", ICONGROUP,MAINICON,0
]]

local function utf16(s)
	return (s:gsub(".", "\0%0")) -- Simplified @Hack.
end

local contents = getFileContents"misc/Build/AppInfoTemplate.rc"
contents = contents:gsub("%z%$%z{([%w%z]+)%z}", {
	[utf16"version"]      = utf16(require"version"),
	[utf16"versionComma"] = utf16(require"version":gsub("%.", ",")),
	[utf16"year"]         = utf16(os.date"%Y"),
})
writeFile(DIR_TEMP.."/AppInfo.rc", contents)

local contents = UPDATE_EXE_TEMPLATE:gsub("%${([%w]+)}", {
	["appDir"]  = toWindowsPath(DIR_APP),
	["tempDir"] = toWindowsPath(DIR_TEMP),
})
writeFile(DIR_TEMP.."/UpdateExe.rhs", contents)

assert(copyFile(PATH_SR_EXE, DIR_TEMP.."/App.exe"))
run(PATH_RH, "-open",DIR_TEMP.."/AppInfo.rc", "-save",DIR_TEMP.."/AppInfo.res", "-action","compile", "-log","CONSOLE")
run(PATH_RH, "-script",DIR_TEMP.."/UpdateExe.rhs")
run(PATH_SR_GLUE, DIR_TEMP.."/App.exe", "misc/Build/exe.lua", APP_NAME..".exe")

logprint("Build", "Making exe... done!")

----------------------------------------------------------------
logprint("Build", "Copying files...")

-- Folders.
traverseFiles("src", function(path, pathRel, filename, ext)
	local outputter = indexOf(FILES_OUTSIDE_ZIP, path) and outputFile or outputFileForZip
	outputter(path)
end)
traverseFiles("lib", function(path, pathRel, filename, ext)
	local outputter = indexOf(FILES_OUTSIDE_ZIP, path) and outputFile or outputFileForZip
	outputter(path)
end)
traverseFiles("bin", function(path, pathRel, filename, ext)
	outputFile(path)
end)
traverseFiles("gfx", function(path, pathRel, filename, ext)
	outputFile(path)
end)
traverseFiles("misc/Update", function(path, pathRel, filename, ext)
	if filename ~= "lua5.1.exe" then
		outputFile(path)
	end
end)

-- Various files.
outputFile("misc/AppIcon/AppIcon0128.png") -- Used in readme.
outputFile("utils/rhash.exe")
for name in directoryItems"." do
	if isAny(getExtension(name), "dll","exe","lua","txt","md") and name ~= "lua5.1.exe" then
		outputFile(name)
	end
end

-- App zip file. (Not the distributed one!)
local pathOut = DIR_TEMP.."/app.zip"
if isFile(pathOut) then
	assert(deleteFile(pathOut), pathOut)
end

cwdPush(DIR_ZIP)
run(
	DIR_APP.."/"..PATH_7Z,
	"a",
	"-tzip",
	pathOut,
	"."
)
cwdPop()

outputFile(pathOut, "app")

logprint("Build", "Copying files... done!")

----------------------------------------------------------------
logprint("Build", "Creating zip...")

local pathOut = F("%s/MyHappyList_%s_Win32.zip", DIR_OUTPUT, require"version")
if isFile(pathOut) then
	assert(deleteFile(pathOut), pathOut)
end

logprint("Build", "Zip: "..pathOut)
cwdPush(DIR_OUTPUT_WIN32)
run(
	DIR_APP.."/"..PATH_7Z,
	"a",
	"-tzip",
	DIR_APP.."/"..pathOut,
	APP_NAME
)
cwdPop()

logprint("Build", "Creating zip... done!")

----------------------------------------------------------------

logprint("Build", "All done!")
