cd "C:\Games\Steam\steamapps\common\Sven Co-op\svencoop\addons\metamod\dlls"

if exist MapChangeMsg_old.dll (
    del MapChangeMsg_old.dll
)
if exist MapChangeMsg.dll (
    rename MapChangeMsg.dll MapChangeMsg_old.dll 
)

exit /b 0