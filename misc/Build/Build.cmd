@ECHO OFF
CD %~dp0..\..
lua5.1.exe misc\Build\Build.lua || (
	ECHO.
	ECHO !!!!!!!!!!!!!!!!!!!!!!!!!
	ECHO !! ERROR: BUILD FAILED !!
	ECHO !!!!!!!!!!!!!!!!!!!!!!!!!
	ECHO.
	PAUSE
	EXIT 1
)
