--[[============================================================
--=
--=  ed2k Hash Calculation Script
--=
--=  Args: pathToFileToHash
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

local path = unpack(args)

local output, err = cmdCapture("utils/rhash.exe", "--ed2k", path)
if not output then
	errorf("%s: Could not run rhash: %s", path, err)
end
if output == "" then
	errorf("%s: %s", path, "No output from rhash.")
end

local ed2kHash = output:match"%S+"
if not ed2kHash or #ed2kHash ~= 32 or ed2kHash:find"[^%da-f]" then
	errorf("%s: %s", path, "rhash: "..output)
end

print("ed2k: "..ed2kHash)
