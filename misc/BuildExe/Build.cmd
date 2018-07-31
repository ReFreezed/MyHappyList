@ECHO OFF
CD ..\..

ECHO Making ico...
utils\ImageMagick\convert.exe "misc\AppIcon\AppIcon0*.png" "gfx\appicon.ico"
ECHO Making ico... done!

ECHO Making exe...
COPY "utils\srlua\wsrlua.exe" "temp\App.exe"
utils\ResourceHacker\ResourceHacker.exe -open "misc\BuildExe\AppInfo.rc" -save "temp\AppInfo.res" -action compile -log CONSOLE
utils\ResourceHacker\ResourceHacker.exe -script "misc\BuildExe\UpdateExe.rhs" -log CONSOLE
utils\srlua\glue.exe "temp\App.exe" "misc\BuildExe\exe.lua" "MyHappyList.exe"
ECHO Making exe... done!
