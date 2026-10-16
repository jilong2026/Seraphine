@echo off
chcp 936 >nul
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ==========================================
echo   Seraphine 一键打包
echo ==========================================
echo.

set "VENV=%~dp0.venv"
set "VENV_PY=%VENV%\Scripts\python.exe"
set "PY_VER=3.11.9"
set "PY_ARCH=amd64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "PY_ARCH=arm64"
set "PY_SETUP=%TEMP%\python-%PY_VER%-%PY_ARCH%.exe"
set "PY_PROBE=%TEMP%\seraphine_py_probe.txt"
set "PF86=%ProgramFiles(x86)%"
set "SEVENZIP_HOME=%LOCALAPPDATA%\Seraphine\tools"

call :findPython
if not defined PYEXE (
    echo [提示] 未找到兼容的 Python（需要 3.8 - 3.11），开始自动安装 Python 3.11 ...
    echo.
    call :installPython
    call :findPython
)
if not defined PYEXE (
    echo.
    echo [错误] 自动安装 Python 失败，请确认网络可用后重新运行本脚本。
    echo        也可以手动安装 Python 3.11：
    echo        https://www.python.org/downloads/release/python-3119/
    echo        安装时请勾选 "Add Python to PATH"。
    echo.
    pause
    exit /b 1
)
echo [1/4] 使用的 Python：!PYEXE!

if not exist "%VENV_PY%" (
    echo [2/4] 创建虚拟环境 .venv ...
    "!PYEXE!" -m venv "%VENV%"
    if errorlevel 1 (
        echo.
        echo [错误] 创建虚拟环境失败。
        pause
        exit /b 1
    )
)

call :ensureDeps
if errorlevel 1 (
    pause
    exit /b 1
)

echo [3/4] 检查 PyInstaller ...
"%VENV_PY%" -c "import PyInstaller" >nul 2>&1
if errorlevel 1 (
    echo       未安装，正在安装 PyInstaller ...
    "%VENV_PY%" -m pip install pyinstaller -i https://pypi.tuna.tsinghua.edu.cn/simple
    if errorlevel 1 (
        echo.
        echo [错误] PyInstaller 安装失败，请确认网络可用后重新运行本脚本。
        pause
        exit /b 1
    )
)

set "MAKE_ARGS="
call :ensure7z
if errorlevel 1 (
    echo       没能准备好 7-Zip，将跳过压缩，产物位于 .\dist\Seraphine
    set "MAKE_ARGS=-dbg"
) else (
    echo       使用 7-Zip：!SEVENZIP!
)

echo [4/4] 开始打包 ...
echo.
call "%VENV%\Scripts\activate.bat"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\make.ps1" !MAKE_ARGS!

if errorlevel 1 (
    echo.
    echo [错误] 打包失败，请查看上方信息。
    pause
    exit /b 1
)

echo.
echo 打包完成！产物位于 .\dist\Seraphine
if not defined MAKE_ARGS echo 压缩包：.\Seraphine.7z
echo.
pause
exit /b 0


:findPython
set "PYEXE="

rem 1) Python 启动器 py（PythonCore 运行时；同时涵盖新版 Python 安装管理器）
call :tryPyLauncher -3.11
call :tryPyLauncher -3.10
call :tryPyLauncher -3.9
call :tryPyLauncher -3.8

rem 2) PATH 上的 python / python3
call :tryPath python
call :tryPath python3

rem 3) WindowsApps 里的别名（按绝对路径探测，不依赖 PATH）
call :tryPath "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe"
call :tryPath "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe"

rem 4) 常见安装位置
for %%V in (311 310 39 38) do (
    call :tryPath "%LOCALAPPDATA%\Programs\Python\Python%%V\python.exe"
    call :tryPath "%ProgramFiles%\Python%%V\python.exe"
)

rem 5) 目录扫描：uv / Astral 独立版、Python 安装管理器的运行时等
call :scanTree "%APPDATA%\uv\python"
call :scanTree "%LOCALAPPDATA%\uv\python"
call :scanTree "%LOCALAPPDATA%\Python"
call :scanTree "%LOCALAPPDATA%\Programs\Python"

exit /b 0


:tryPath
rem 参数：python.exe 的路径，或只是一个命令名（如 python）
call :probePython "%~1"
exit /b 0


:tryPyLauncher
rem 参数：版本开关，如 -3.11
call :havePyLauncher
if defined PY_LAUNCHER call :probePython "!PY_LAUNCHER!" "%~1"
exit /b 0


:scanTree
rem 在 %~1 及其一级子目录里找 python.exe
if defined PYEXE exit /b 0
if not exist "%~1" exit /b 0

call :tryPath "%~1\python.exe"
for /d %%D in ("%~1\*") do (
    if not defined PYEXE call :tryPath "%%~D\python.exe"
)

exit /b 0


:probePython
rem 运行候选解释器，要求版本落在 3.8 - 3.11，并把 sys.executable 回读出来
if defined PYEXE exit /b 0
if "%~1"=="" exit /b 0

if exist "%PY_PROBE%" del "%PY_PROBE%" >nul 2>&1

"%~1" %~2 -c "import sys;assert sys.version_info[:2] in [(3,8),(3,9),(3,10),(3,11)];print(sys.executable)" > "%PY_PROBE%" 2>nul
if errorlevel 1 exit /b 0

set "TRY_PY="
set /p TRY_PY=<"%PY_PROBE%"
del "%PY_PROBE%" >nul 2>&1

rem 必须是真实存在的文件，避免把错误提示当成路径
if not defined TRY_PY exit /b 0
if not exist "!TRY_PY!" exit /b 0

set "PYEXE=!TRY_PY!"
exit /b 0


:installPython
rem 优先用 Python 安装管理器：它不经过 MSI，可绕过 C:\Windows\Installer 权限故障
call :havePyLauncher
if defined PY_LAUNCHER (
    echo       第一步：用 Python 安装管理器安装 3.11 ...
    "!PY_LAUNCHER!" install 3.11 -y

    call :findPython
    if defined PYEXE (
        echo [提示] Python 安装完成。
        exit /b 0
    )
    echo       安装管理器没有装上，继续尝试其它方式 ...
)

call :haveWinget
if defined WINGET_EXE (
    echo       第二步：尝试用 winget 安装 ...
    "!WINGET_EXE!" install -e --id Python.Python.3.11 --accept-source-agreements --accept-package-agreements

    call :findPython
    if defined PYEXE (
        echo [提示] Python 安装完成。
        exit /b 0
    )
    echo       winget 没有装上，改用直接下载官方安装包 ...
)

if exist "%PY_SETUP%" del "%PY_SETUP%" >nul 2>&1

echo       第三步：下载 Python %PY_VER% ...
call :download "https://www.python.org/ftp/python/%PY_VER%/python-%PY_VER%-%PY_ARCH%.exe" "%PY_SETUP%"

if not exist "%PY_SETUP%" (
    echo       官方地址下载失败，改用镜像重试 ...
    call :download "https://mirrors.huaweicloud.com/python/%PY_VER%/python-%PY_VER%-%PY_ARCH%.exe" "%PY_SETUP%"
)

if not exist "%PY_SETUP%" (
    echo [提示] 下载 Python 安装包失败。
    exit /b 1
)

echo       正在静默安装（不需要管理员权限，请稍候）...
"%PY_SETUP%" /quiet InstallAllUsers=0 PrependPath=1 Include_launcher=1 Include_test=0 Include_doc=0

call :findPython
if defined PYEXE (
    del "%PY_SETUP%" >nul 2>&1
    echo [提示] Python %PY_VER% 安装完成。
    exit /b 0
)

echo [提示] 官方安装包没能装上。若安装日志里出现错误 2503，
echo        说明 C:\Windows\Installer 目录权限异常，需以管理员身份修复该目录权限后再试。
exit /b 1


:ensureDeps
"%VENV_PY%" -c "import PyQt5, aiohttp, qfluentwidgets, qasync, py7zr, psutil, pyperclip, requests" >nul 2>&1
if not errorlevel 1 (
    echo [2/4] 依赖已就绪。
    exit /b 0
)

echo [2/4] 安装依赖（首次运行需要几分钟，请耐心等待）...
"%VENV_PY%" -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
"%VENV_PY%" -m pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
if errorlevel 1 (
    echo.
    echo [错误] 依赖安装失败，请确认网络可用后重新运行本脚本。
    exit /b 1
)

exit /b 0


:havePyLauncher
set "PY_LAUNCHER="

for /f "delims=" %%P in ('where py 2^>nul') do (
    if not defined PY_LAUNCHER set "PY_LAUNCHER=%%P"
)
if not defined PY_LAUNCHER (
    if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\py.exe" set "PY_LAUNCHER=%LOCALAPPDATA%\Microsoft\WindowsApps\py.exe"
)

exit /b 0


:haveWinget
set "WINGET_EXE="

for /f "delims=" %%W in ('where winget 2^>nul') do (
    if not defined WINGET_EXE set "WINGET_EXE=%%W"
)
if not defined WINGET_EXE (
    if exist "%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe" set "WINGET_EXE=%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe"
)

exit /b 0


:download
set "DL_URL=%~1"
set "DL_OUT=%~2"

where curl >nul 2>&1
if not errorlevel 1 (
    curl -L --fail --silent --show-error -o "%DL_OUT%" "!DL_URL!"
) else (
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!DL_URL!' -OutFile '%DL_OUT%'"
)

if not exist "%DL_OUT%" exit /b 1

for %%F in ("%DL_OUT%") do if %%~zF LSS 1024 (
    del "%DL_OUT%" >nul 2>&1
    exit /b 1
)

exit /b 0


:ensure7z
set "SEVENZIP="

for /f "delims=" %%Z in ('where 7z 2^>nul') do (
    if not defined SEVENZIP set "SEVENZIP=%%Z"
)
if not defined SEVENZIP (
    if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
)
if not defined SEVENZIP (
    if exist "!PF86!\7-Zip\7z.exe" set "SEVENZIP=!PF86!\7-Zip\7z.exe"
)
if not defined SEVENZIP (
    if exist "!SEVENZIP_HOME!\7z.exe" set "SEVENZIP=!SEVENZIP_HOME!\7z.exe"
)

if not defined SEVENZIP (
    call :haveWinget
    if defined WINGET_EXE (
        echo       未检测到 7-Zip，尝试用 winget 安装 ...
        "!WINGET_EXE!" install -e --id 7zip.7zip --accept-source-agreements --accept-package-agreements
        if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
    )
)

if not defined SEVENZIP (
    echo       未检测到 7-Zip，正在下载免安装版 ...
    if not exist "!SEVENZIP_HOME!" md "!SEVENZIP_HOME!" >nul 2>&1
    call :download "https://www.7-zip.org/a/7zr.exe" "!SEVENZIP_HOME!\7z.exe"
    if exist "!SEVENZIP_HOME!\7z.exe" set "SEVENZIP=!SEVENZIP_HOME!\7z.exe"
)

if not defined SEVENZIP exit /b 1

for %%D in ("!SEVENZIP!") do set "SEVENZIP_DIR=%%~dpD"
set "PATH=!PATH!;!SEVENZIP_DIR!"

exit /b 0
