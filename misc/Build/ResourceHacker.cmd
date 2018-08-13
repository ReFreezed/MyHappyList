@ECHO OFF
utils\ResourceHacker\ResourceHacker.exe %*
IF %ERRORLEVEL% NEQ 0  EXIT 1
