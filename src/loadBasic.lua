--[[============================================================
--=
--=  Basic Loading
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

package.relpath
	= "?.lua;"
	.."src/?.lua;"
	.."lib/?.lua;"
	.."lib/?/init.lua;"

package.path = package.relpath:gsub("[^;]+", DIR_EXE.."/%0")

package.cpath
	= DIR_EXE.."/bin/?.dll;"
	..DIR_EXE.."/bin/?51.dll;"

io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
