--[[============================================================
--=
--=  Release File Creation Script
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

assert(loadfile"src/load.lua")()

assert(createDirectory("output"))
assert(createDirectory("temp"))

local DIR_OUTPUT_WIN32 = "output/Win32/MyHappyList"
assert(createDirectory(DIR_OUTPUT_WIN32))

-- Remove old outputted files.
----------------------------------------------------------------

traverseDirectory(DIR_OUTPUT_WIN32, true, function(path, pathRel, name, mode)
	if mode == "directory" then
		assert(wx.wxRmdir(path), path)
	else
		assert(deleteFile(path), path)
	end
end)

-- Copy files to output.
----------------------------------------------------------------

local function outputFile(path)
	print("Output: "..path)
	local pathOut = DIR_OUTPUT_WIN32.."/"..path
	assert(createDirectory(getDirectory(pathOut)))
	assert(wx.wxCopyFile(path, pathOut), pathOut)
end

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

-- Zip it up!
----------------------------------------------------------------

local pathOut = F([[output\MyHappyList_%s_Win32.zip]], require"version")
if isFile(pathOut) then
	assert(deleteFile(pathOut), pathOut)
end

local cmd = cmdEscapeArgs(
	wx.wxGetCwd()..[[\utils\7-Zip\7z.exe]],
	[[a]],
	[[-tzip]],
	wx.wxGetCwd()..[[\]]..pathOut,
	[[MyHappyList]]
)

wx.wxSetWorkingDirectory("output/Win32")

print("Zip: "..pathOut)
assert(processStart(cmd, PROCESS_METHOD_SYNC, function(process, exitCode)
	assert(exitCode == 0)
end))

wx.wxSetWorkingDirectory("../..")
