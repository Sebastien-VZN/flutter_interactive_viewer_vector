@echo off
setlocal

:: --- Copie miroir du repo vers sa destination E: ---
set "SRC=C:\Devs\01_client_project\interactive_viewer_vector"
set "DST=E:\Projets Dev\plugin_flutter\interactive_viewer_vector"

echo.
echo === Copie miroir : interactive_viewer_vector ===
echo   Source : %SRC%
echo   Cible  : %DST%
echo.

for %%I in ("%DST%") do if not exist "%%~dpI" mkdir "%%~dpI"

robocopy "%SRC%" "%DST%" /MIR /XF "nul" /R:1 /W:1 /NFL /NDL /NJH /NJS
set "RC=%errorlevel%"

if %RC% LSS 8 (
    echo [interactive_viewer_vector] : OK ^(robocopy code %RC%^)
) else (
    echo [interactive_viewer_vector] : ECHEC ^(robocopy code %RC%^)
)

echo ---
echo Termine.
endlocal
pause