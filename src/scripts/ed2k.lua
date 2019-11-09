--[[============================================================
--=
--=  ed2k Hash Calculation Script
--=
--=  Args: pathToTempFileWithPathToFileToHash, pathForErrorMessage
--=
--=  Outputs:
--=    ed2k: <ed2kHash>
--=
--=    <error>
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

local tempPath, pathForError = unpack(args)

-- Using RHash 1.3.8.
local output, err = cmdCapture("utils/rhash.exe", "--ed2k", "--file-list="..tempPath)

if not output then
	errorf("%s: Could not run rhash: %s", pathForError, err)
elseif output == "" then
	errorf("%s: %s", pathForError, "No output from rhash.")
end

local ed2kHash = output:match"%S+"
if not ed2kHash or #ed2kHash ~= 32 or ed2kHash:find"[^%da-f]" then
	errorf("%s: rhash: %s", pathForError, output)
end

print("ed2k: "..ed2kHash)
