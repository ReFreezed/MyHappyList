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

package.cpath
	= "./bin/?.dll;"
	.."./bin/?51.dll;"

package.path
	= "./src/?.lua;"
	.."./lib/?.lua;"
	.."./lib/?/init.lua;"

io.stdout:setvbuf("no")
io.stderr:setvbuf("no")
