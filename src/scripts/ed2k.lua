--[[============================================================
--=
--=  ed2k Hash Calculation Script
--=
--=  Args: pathToFileToHash
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

assert(loadfile("src/load.lua"))()

local path = ...

xpcall(
	function()
		local output, err = cmdCapture(F([[bin\rhash.exe --ed2k "%s"]], path))
		if not output then
			errorf("%s: Could not run rhash: %s", path, err)
		end

		local ed2kHash = output:match"%S+"
		if not ed2kHash or #ed2kHash ~= 32 or ed2kHash:find"[^%da-f]" then
			errorf("%s: %s", path, (output == "" and "No output from rhash." or "rhash: "..output))
		end

		io.stdout:write("ed2k: ", ed2kHash, "\n")
	end,
	handleError
)
