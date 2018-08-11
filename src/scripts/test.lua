--[[============================================================
--=
--=  Test Script
--=
--=  Args: none
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

print("...Testing...")

assert(loadfile"src/load.lua")()

io.stdout:write("Hello,")
wxSleep(10)
io.stdout:write(" world!\n")
