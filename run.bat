@echo off
setlocal

cd /d "%~dp0"

set CMD=%1
set ARG2=%2

if "%CMD%"=="run" goto run_with_clean
if "%CMD%"=="clean" goto clean
if "%CMD%"=="setup" goto setup

echo Usage: run.bat run
echo Usage: run.bat clean
echo Usage: run.bat setup
echo Usage: run.bat setup --flat
goto end

:run_with_clean
call :clean
goto run

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
goto setupdeps

:flatmode
echo [FLAT MODE] Converting submodule...

set /p CONF=This will convert submodule to normal folder. Continue? (y/n): 
if /I not "%CONF%"=="y" (
    echo Cancelled.
    goto end
)

REM 1. make sure submodule content exists
git submodule update --init --recursive

REM 2. detach git linkage safely
git rm --cached library >nul 2>&1

REM 3. remove submodule metadata
if exist .gitmodules del /F /Q .gitmodules
if exist .git\modules\library rmdir /S /Q .git\modules\library

REM 4. remove inner git ONLY after ensuring files exist
if exist library\.git rmdir /S /Q library\.git

echo Submodule converted to normal folder (safe mode).
goto setupdeps

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