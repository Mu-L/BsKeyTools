@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ============================================
echo   BsKeyTools NSIS Build Script
echo ============================================
echo.

:: 查找 NSIS makensis.exe
set "MAKENSIS="

:: 优先使用 PATH 中的
where makensis.exe >nul 2>&1 && (
    for /f "delims=" %%i in ('where makensis.exe') do set "MAKENSIS=%%i"
)

:: 常见安装路径
if not defined MAKENSIS (
    if exist "C:\Program Files (x86)\NSIS\makensis.exe" (
        set "MAKENSIS=C:\Program Files (x86)\NSIS\makensis.exe"
    )
)
if not defined MAKENSIS (
    if exist "C:\Program Files\NSIS\makensis.exe" (
        set "MAKENSIS=C:\Program Files\NSIS\makensis.exe"
    )
)

if not defined MAKENSIS (
    echo [ERROR] 找不到 makensis.exe
    echo.
    echo   NSIS 未安装，请通过以下任一方式安装:
    echo.
    echo   方式1 - 手动下载安装:
    echo     https://nsis.sourceforge.io/Download
    echo.
    echo   方式2 - winget 命令安装:
    echo     winget install NSIS.NSIS
    echo.
    echo   方式3 - scoop 命令安装:
    echo     scoop install nsis
    echo.
    set /p "OPEN_URL=是否打开下载页面? (Y/N): "
    if /i "!OPEN_URL!"=="Y" start https://nsis.sourceforge.io/Download
    pause
    exit /b 1
)

echo [INFO] 使用 NSIS: %MAKENSIS%
echo.

:: 切换到脚本所在目录
cd /d "%~dp0"

:: 检查必要的插件文件
if not exist "NsisPlugins\x86-unicode\nsProcess.dll" (
    echo [WARN] 缺少 NsisPlugins\x86-unicode\nsProcess.dll
    echo        请将 nsProcess.dll 放入 NsisPlugins\x86-unicode\ 目录
)
if not exist "NsisPlugins\x86-unicode\INetC.dll" (
    echo [WARN] 缺少 NsisPlugins\x86-unicode\INetC.dll
    echo        请将 INetC.dll 放入 NsisPlugins\x86-unicode\ 目录
)

set "FAIL=0"

:: 编译 BsKeyTools 安装包
echo --------------------------------------------
echo [1/2] 编译 Setup_BsKeyTools.nsi ...
echo --------------------------------------------
"%MAKENSIS%" /V2 "Setup_BsKeyTools.nsi"
if errorlevel 1 (
    echo [FAIL] Setup_BsKeyTools.nsi 编译失败!
    set "FAIL=1"
) else (
    echo [OK]   _BsKeyTools.exe 生成成功
)
echo.

:: 编译 BsCleanVirus 安装包
echo --------------------------------------------
echo [2/2] 编译 Setup_BsCleanVirus.nsi ...
echo --------------------------------------------
"%MAKENSIS%" /V2 "Setup_BsCleanVirus.nsi"
if errorlevel 1 (
    echo [FAIL] Setup_BsCleanVirus.nsi 编译失败!
    set "FAIL=1"
) else (
    echo [OK]   BsCleanVirus_Standalone.exe 生成成功
)
echo.

:: 汇总
echo ============================================
if "!FAIL!"=="1" (
    echo   构建完成（有错误），请检查上方日志
) else (
    echo   全部构建成功!
    echo   输出文件:
    echo     _BsKeyTools.exe
    echo     BsCleanVirus_Standalone.exe
)
echo ============================================
echo.
pause
