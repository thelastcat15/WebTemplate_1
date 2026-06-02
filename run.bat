@echo off
setlocal

cd /d "%~dp0"

set CMD=%1
set ARG2=%2

if "%CMD%"=="run" goto run
if "%CMD%"=="clean" goto clean
if "%CMD%"=="setup" goto setup

echo Usage: run.bat run
echo Usage: run.bat clean
echo Usage: run.bat setup
echo Usage: run.bat setup --flat
goto end

:run
echo Starting services...
if not exist .pids mkdir .pids
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$p=Start-Process cmd.exe -ArgumentList '/k','call backend\run.bat run' -PassThru; $p.Id | Set-Content '.pids\backend.pid'"
if not exist db mkdir db
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$p=Start-Process cmd.exe -ArgumentList '/k','mongod --dbpath=./db' -PassThru; $p.Id | Set-Content '.pids\mongo.pid'"
powershell -NoProfile -ExecutionPolicy Bypass ^
  "$p=Start-Process cmd.exe -WorkingDirectory '%CD%\frontend' -ArgumentList '/k','npm run dev' -PassThru; $p.Id | Set-Content '.pids\frontend.pid'"
echo Done.
goto end

:clean
echo Stopping services...
for %%F in (backend mongo frontend) do (
    if exist .pids\%%F.pid (
        set /p PID=<.pids\%%F.pid
        call taskkill /F /PID %%PID%% /T >nul 2>&1
    )
)
if exist .pids rmdir /S /Q .pids
echo Done.
goto end

:setup
echo Setting up project...
if "%ARG2%"=="--flat" goto flatmode
goto normalsetup

:flatmode
echo [FLAT MODE] Detaching submodule...
set /p CONF=This will convert submodule to normal folder. Continue? (y/n): 
if /I not "%CONF%"=="y" (
    echo Cancelled.
    goto end
)
if exist library\.git (
    rmdir /S /Q library\.git
)
if exist .gitmodules del /F /Q .gitmodules
if exist .git\modules\library rmdir /S /Q .git\modules\library
git rm -r --cached library >nul 2>&1
echo Submodule converted to normal folder.
goto setupdeps

:normalsetup
echo Normal setup (keeping submodules)

:setupdeps
cd backend
call go mod tidy
cd ..
cd frontend
call npm install
cd ..
echo Setup complete.
goto end

:end
endlocal