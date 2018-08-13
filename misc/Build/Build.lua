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

assert(loadfile"src/load.lua")()

local EXE_NAME          = "MyHappyList"

local DIR_TEMP          = "temp"

local DIR_OUTPUT        = "output"
local DIR_OUTPUT_WIN32  = DIR_OUTPUT.."/Win32"
local DIR_CONTENT_WIN32 = DIR_OUTPUT_WIN32.."/"..EXE_NAME

local PATH_7Z           = "utils/7-Zip/7z.exe"
local PATH_IM           = "utils/ImageMagick/convert.exe"
local PATH_RH           = "misc/Build/ResourceHacker.cmd"--"utils/ResourceHacker/ResourceHacker.exe"
local PATH_SR_EXE       = "utils/srlua/wsrlua.exe"
local PATH_SR_GLUE      = "utils/srlua/glue.exe"

local FULLPATH_ROOT     = toNormalPath(wxGetCwd())

----------------------------------------------------------------

local function outputFile(pathSource, pathTarget)
	pathTarget = pathTarget or pathSource
	print("Output: "..pathTarget)

	local pathOut = DIR_CONTENT_WIN32.."/"..pathTarget
	assert(createDirectory(getDirectory(pathOut)))
	assert(copyFile(pathSource, pathOut))
end

----------------------------------------------------------------

assert(createDirectory(DIR_TEMP))
assert(createDirectory(DIR_CONTENT_WIN32))

----------------------------------------------------------------
print("Updating readme...")

local contents0 = getFileContents"README.md"
local contents  = contents0:gsub(
	"!%[version %d+%.%d+%.%d+%]%(https://img%.shields%.io/badge/version%-%d+%.%d+%.%d+%-green%.svg%)",
	function(badge)
		return (badge:gsub("%d+%.%d+%.%d+", require"version"))
	end
)
if contents ~= contents0 then
	writeFile("README.md", contents)
end

print("Updating readme... done!")

----------------------------------------------------------------
print("Making ico...")
run(PATH_IM, "misc/AppIcon/AppIcon0*.png", "gfx/appicon.ico")
print("Making ico... done!")

----------------------------------------------------------------
print("Making exe...")

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

assert(copyFile(PATH_SR_EXE, DIR_TEMP.."/App.exe"))
run(PATH_RH, "-open", DIR_TEMP.."/AppInfo.rc", "-save", DIR_TEMP.."/AppInfo.res", "-action", "compile", "-log", "CONSOLE")
run(PATH_RH, "-script", "misc/Build/UpdateExe.rhs", "-log", "CONSOLE")
run(PATH_SR_GLUE, DIR_TEMP.."/App.exe", "misc/Build/exe.lua", EXE_NAME..".exe")

print("Making exe... done!")

----------------------------------------------------------------
print("Preparing content folder...")

traverseDirectory(DIR_CONTENT_WIN32, true, function(path, pathRel, name, mode)
	if mode == "directory" then
		assert(wxRmdir(path), path)
	else
		assert(deleteFile(path), path)
	end
end)

print("Preparing content folder... done!")

----------------------------------------------------------------
print("Copying files...")

-- Folders.
traverseFiles("src", function(path, pathRel, name, ext)
	outputFile(path)
end)
traverseFiles("lib", function(path, pathRel, name, ext)
	outputFile(path)
end)
traverseFiles("bin", function(path, pathRel, name, ext)
	outputFile(path)
end)
traverseFiles("gfx", function(path, pathRel, name, ext)
	outputFile(path)
end)

-- Various files.
outputFile("utils/rhash.exe")
for name in directoryItems"." do
	if isAny(getExtension(name), "dll","exe","lua","txt","md") then
		outputFile(name)
	end
end

print("Copying files... done!")

----------------------------------------------------------------
print("Creating zip...")

local pathOut = F("%s/MyHappyList_%s_Win32.zip", DIR_OUTPUT, require"version")
if isFile(pathOut) then
	assert(deleteFile(pathOut), pathOut)
end

print("Zip: "..pathOut)
cwdPush(DIR_OUTPUT_WIN32)
run(
	FULLPATH_ROOT.."/"..PATH_7Z,
	"a", "-tzip",
	FULLPATH_ROOT.."/"..pathOut,
	EXE_NAME
)
cwdPop()

print("Creating zip... done!")
