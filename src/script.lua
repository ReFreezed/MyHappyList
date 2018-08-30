--[[============================================================
--=
--=  Script Runner
--=
--=  Args: scriptName scriptArg1 ...
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

DIR_EXE = DIR_EXE or "."

require"src.loadBasic"
require"load"

_G.args = {...}
local scriptName = table.remove(args, 1)

xpcall(
	function()
		require("scripts."..scriptName)
	end,
	handleError
)
