--[[============================================================
--=
--=  Script Runner
--=
--=  Args: scriptName, scriptArg1, ...
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

assert(loadfile"src/load.lua")()

_G.args = {...}
local scriptName = table.remove(args, 1)

xpcall(
	function()
		require("scripts."..scriptName)
	end,
	handleError
)
