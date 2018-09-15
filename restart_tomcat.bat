
@echo off
setlocal
set "CATALINA_HOME=C:\ServerWeb\Tomcat"
set "DELLOGS=%CATALINA_HOME%\logs\*.log"
set "DELTXTS=%CATALINA_HOME%\logs\*.txt"
set "DELALLS=%CATALINA_HOME%\logs\*.*"
rem  C:\ServerWeb\Tomcat\bin\tomcat7.exe //SS//Tomcat7.0.50
set "STOP=%CATALINA_HOME%\bin\shutdown.bat"
rem  C:\ServerWeb\Tomcat\bin\tomcat7.exe //RS//Tomcat7.0.50  (Doesn't work!)
set "START=%CATALINA_HOME%\bin\startup.bat"
 
 
set "serviceCheck=Tomcat"
rem serviceCheck: Tomcat7 or Tomcat8
set "processCheck=Tomcat"
rem processCheck: tomcat7.exe or tomcat8.exe
set "executorPort=8080"
set "shutdownPort=8005"
 
set "serviceName="
set "serviceRunning="
set "processPID="
 
if "x%1x" == "xx" goto beginRestart
set firstArg=%1
if "x%2x" == "xx" goto check_firstArg
set secndArg=%2
 
set "deleting="
set "bverbose="
 
rem Only 2 arguments are allowed
if not "x%3x" == "xx" goto displayUsage
 
if %firstArg% == %secndArg% goto displayUsage
 
:check_secndArg
if "%secndArg%" == "dellogs" (
  set deleting=%secndArg%
) else (
  if "%secndArg%" == "verbose" (
    set "bverbose=%secndArg%"
  ) else (
    goto displayUsage
  )
)
:check_firstArg
if "%firstArg%" == "dellogs" (
  set "deleting=%firstArg%"
) else (
  if "%firstArg%" == "verbose" (
    set "bverbose=%firstArg%"
  ) else (
    goto displayUsage
  )
)
 
:beginRestart
call :getServiceName
if defined serviceName (
  rem call :checkServiceRunning
  call :serviceAvailableStop
  if defined serviceRunning (
    rem the service is running, stop the service
    if defined bverbose (
      echo.
      echo Stopping %serviceCheck%, like %serviceName% service...
      echo.
    )
    call :getPID
    call :Restarting
  ) else (
    rem the service was not running, trying with the port like process
    call :getPID
    if defined processPID (
      for /f "delims=" %%i in ('netstat -nao ^| find /i ":%executorPort% " ^| find /i "LISTENING"') do (
        for /f "tokens=2" %%o in ("%%i") do (
          echo.%%o | findstr /C:":%executorPort% " 1>nul
          if not ERRORLEVEL 1 (
            for /f "tokens=5" %%u in ("%%i") do (
              if defined bverbose (
                echo.
                echo Stopping the %serviceCheck% like %%u PID process...
                echo.
              )
            )
          )
        )
      )
      call :Restarting
    ) else (
      if defined bverbose (
        echo.
        echo %serviceCheck% was not running.
        echo.
      )
      call :Starting
    )
  )
)
 
 
:getServiceName
rem To obtain the real (exact) name of service.
for /f "tokens=2" %%s in ('sc query state^= all ^| find /I "%serviceCheck%"') do (
  set "serviceName=%%s"
)
exit /b 0
 
 
:checkServiceRunning
rem To check if real service is running...
if defined serviceName (
  sc query %serviceName%| find /i "RUNNING">nul
  if not ERRORLEVEL 1 (
    rem service was found running
    set "serviceRunning=%serviceName%"
  )
)
exit /b 0
 
 
:serviceAvailableStop
tasklist /FI "SessionName eq services" | find /I "%processCheck%" | find /I ".exe">nul
if not ERRORLEVEL 1 (
  rem %processCheck% is running, is needed if shutdown port is available
  netstat -nao | find /i ":%shutdownPort% " | find /i "LISTENING">nul
  if not ERRORLEVEL 1 (
    set "serviceRunning=%serviceName%"
    exit /b 0
  ) else (
    rem service was found running, but is not available to stop
    goto :serviceAvailableStop
  )
) else (
  rem verify is starting
  sc query %serviceName%| find /i "START_PENDING">nul
  if not ERRORLEVEL 1 (
    rem service was found starting
    goto :serviceAvailableStop
  )
  rem verify is running
  sc query %serviceName%| find /i "RUNNING">nul
  if not ERRORLEVEL 1 (
    rem service was found running
    goto :serviceAvailableStop
  )
)
exit /b 0
 
:serviceIsOff
rem Wait until Service ends
tasklist /FI "SessionName eq services" | find /I "%processCheck%" | find /I ".exe">nul
if ERRORLEVEL 1 (
  sc query %serviceName%| find /i "STOPPED">nul
  if not ERRORLEVEL 1 (
    netstat -nao | find /i ":%executorPort% " | find /i "LISTENING">nul
    if ERRORLEVEL 1 (
      exit /b 0
    )
  )
)
ping 127.0.0.1 -n 1 >nul 2>&1 || PING ::1 -n 1 >nul 2>&1
goto :serviceIsOff
 
:processIsOff
netstat -nao | find /i ":%executorPort% " | find /i "LISTENING">nul
if ERRORLEVEL 1 (
  exit /b 0
)
ping 127.0.0.1 -n 1 >nul 2>&1 || PING ::1 -n 1 >nul 2>&1
goto :processIsOff
 
 
:serviceIsOn
rem Wait until service starts completely
sc query %serviceName%| find /i "RUNNING">nul
if not ERRORLEVEL 1 (
  netstat -nao | find /i ":%executorPort% " | find /i "LISTENING">nul
  if not ERRORLEVEL 1 (
    netstat -nao | find /i ":%shutdownPort% " | find /i "LISTENING">nul
    if not ERRORLEVEL 1 (
      exit /b 0
    )
  )
)
ping 127.0.0.1 -n 1 >nul 2>&1 || PING ::1 -n 1 >nul 2>&1
goto :serviceIsOn
 
 
:processIsOn
rem Wait until process starts completely
netstat -nao | find /i ":%executorPort% " | find /i "LISTENING">nul
if not ERRORLEVEL 1 (
  netstat -nao | find /i ":%shutdownPort% " | find /i "LISTENING">nul
  if not ERRORLEVEL 1 (
    exit /b 0
  )
)
ping 127.0.0.1 -n 1 >nul 2>&1 || PING ::1 -n 1 >nul 2>&1
goto :processIsOn
 
:getPID
rem Obtain the PID of process using the 8080 port
set "intPID="
for /f "delims=" %%s in ('netstat -nao ^| find /i ":%executorPort% " ^| find /i "LISTENING"') do (
  for /f "tokens=2" %%# in ("%%s") do (
    echo.%%# | findstr /C:":%executorPort% " 1>nul
    if not ERRORLEVEL 1 (
      for /f "tokens=5" %%p in ("%%s") do (
        if not defined intPID (
          set intPID=%%p
          goto stopGetPID
        )
      )
    )
  )
)
:stopGetPID
set "processPID=%intPID%"
exit /b 0
 
 
:Restarting
rem if process or services is running, then call stop
rem after wait until 8080 TIME_WAIT was finished,
rem later call process to start again
 
rem avoid call STOP if server is starting then wait...
 
if defined serviceRunning (
  call :serviceIsOn
  if defined bverbose (
    net session>nul 2>&1
    if not ERRORLEVEL 1 (
      net stop %serviceName%
    ) else (
      call %STOP%
    )
  ) else (
    call %STOP%>nul
  )
  call :serviceIsOff
  call :processIsOff
  if defined bverbose (
    echo.
    echo The %serviceCheck% like %serviceName% service was stopped.
    echo.
  )
) else (
  call :processIsOn
  if defined bverbose (
    call %STOP%
  ) else (
    call %STOP%>nul
  )
  call :serviceIsOff
  call :processIsOff
  if defined bverbose (
    echo.
    echo The %serviceCheck% with %processPID% PID was stopped.
    echo.
  )
)
 
call :Starting
goto:eof
 
 
:Starting
rem The Start process or service take a time, this in charge to do it.
rem before check if deleted logs file is requested
if not defined deleting goto nodellogs
if defined bverbose (
  echo Deleting the log files...
  echo.
)
del %DELALLS% /q
:nodellogs
net session>nul 2>&1
if not ERRORLEVEL 1 (
  if defined bverbose (
    echo Starting the %serviceCheck% service...
    echo.
    net start %serviceName%
  ) else (
    net start %serviceName%>nul
  )
  call :serviceIsOn
  if defined bverbose (
    echo.
    echo The %serviceCheck% was started like %serviceName% service.
  )
) else (
  if defined bverbose (
    echo Starting the %serviceCheck% process...
    echo.
    call %START%
  ) else (
    call %START%>nul
  )
  call :processIsOn
  set "processPID="
  call :getPID
  if defined bverbose (
    echo.
    echo The %serviceCheck% was started like process with %processPID% PID.
  )
)
goto:eof
 
 
:displayUsage
echo.
echo Usage: %~n0.bat [dellogs] [verbose]
 
 
:end