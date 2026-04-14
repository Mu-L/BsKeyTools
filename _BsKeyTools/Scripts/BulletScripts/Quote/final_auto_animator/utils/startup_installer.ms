-- ============================================================================
-- Auto Animation Tool - Startup Script Installer
-- ============================================================================
-- This module handles automatic installation of startup scripts to ensure
-- global functions are available when 3ds Max opens a scene.
--
-- Features:
--   - Auto-detect 3ds Max version and startup directory
--   - Install loader script to startup folder
--   - Register scene callbacks for function reloading
--   - Immediate fix for current session
--
-- Version: 2.0.0
-- ============================================================================

-- # region Global Variables

global AA_STARTUP_SCRIPT_NAME = "aa_autoanim_startup.ms"
global AA_CALLBACK_ID = #AA_AutoAnimSceneLoad

-- # endregion

-- # region Utility Functions

-- Normalize path separators to forward slashes
fn AA_NormalizePath pathStr = (
    substituteString pathStr "\\" "/"
)

-- Get 3ds Max version string for display
fn AA_GetMaxVersionString = (
    local ver = (maxVersion())[1]
    local year = 1998 + (ver / 1000)
    return ("3ds Max " + (year as string))
)

-- # endregion

-- # region Core Installation Functions

-- Get the best startup directory (prefer user directory over system directory)
fn AA_GetBestStartupDir = (
    -- Try user startup scripts first (AppData, no admin required)
    local userStartup = getDir #userStartupScripts
    if userStartup != undefined and userStartup != "" do (
        format "[AA]   User startup dir available: %\n" userStartup
        return userStartup
    )

    -- Fallback to system startup scripts (may need admin)
    local sysStartup = getDir #startupScripts
    format "[AA]   Using system startup dir: %\n" sysStartup
    return sysStartup
)

-- Check if startup script is already installed (check both locations)
fn AA_IsStartupInstalled = (
    local userStartup = getDir #userStartupScripts
    local sysStartup = getDir #startupScripts

    -- Check user startup first
    if userStartup != undefined and userStartup != "" do (
        local userFile = userStartup + "\\" + AA_STARTUP_SCRIPT_NAME
        if doesFileExist userFile do return true
    )

    -- Check system startup
    local sysFile = sysStartup + "\\" + AA_STARTUP_SCRIPT_NAME
    return (doesFileExist sysFile)
)

-- Create the startup loader script content
fn AA_CreateLoaderContent corePath = (
    local normalizedPath = AA_NormalizePath corePath
    local content = ""
    content += "-- ============================================================================\n"
    content += "-- Auto Animation Tool - Startup Loader\n"
    content += "-- ============================================================================\n"
    content += "-- Auto-generated file. Do not edit manually.\n"
    content += "-- This script loads core functions when 3ds Max starts.\n"
    content += "-- Version: " + AA_VERSION + "\n"
    content += "-- Generated: " + (localTime) + "\n"
    content += "-- ============================================================================\n\n"
    content += "(\n"
    content += "    local corePath = @\"" + normalizedPath + "\"\n"
    content += "    if doesFileExist corePath then (\n"
    content += "        fileIn corePath quiet:true\n"
    content += "    ) else (\n"
    content += "        format \"[AA Warning] Core file not found: \\%\\n\" corePath\n"
    content += "    )\n"
    content += ")\n"
    return content
)

-- Install startup script to 3ds Max startup directory
fn AA_InstallStartupScript scriptDir = (
    local startupDir = AA_GetBestStartupDir()
    local targetFile = startupDir + "\\" + AA_STARTUP_SCRIPT_NAME
    local corePath = scriptDir + "core\\spline_curve_sampler.ms"

    format "[AA] Installing startup script...\n"
    format "[AA]   3ds Max Version: %\n" (AA_GetMaxVersionString())
    format "[AA]   Target Directory: %\n" startupDir
    format "[AA]   Target File: %\n" targetFile

    -- Check if core file exists
    if not doesFileExist corePath do (
        format "[AA] ERROR: Core file not found: %\n" corePath
        return false
    )

    -- Ensure target directory exists
    if not doesDirectoryExist startupDir do (
        makeDir startupDir all:true
    )

    -- Create loader content
    local loaderContent = AA_CreateLoaderContent corePath

    -- Write to startup directory
    local f = createFile targetFile
    if f != undefined then (
        format "%" loaderContent to:f
        close f
        format "[AA] ✓ Startup script installed successfully!\n"
        return true
    ) else (
        -- Failed to write - permission issue, show detailed help
        format "[AA] ERROR: Failed to write startup script (permission denied?)\n"
        format "[AA] Trying alternative solutions...\n"

        local msg = "无法安装启动脚本到:\n" + targetFile + "\n\n"
        msg += "原因: 可能没有写入权限 (Program Files 目录需要管理员权限)\n\n"
        msg += "解决方案:\n"
        msg += "1. 以管理员身份运行 3ds Max 后再试一次\n"
        msg += "2. 或手动创建以下文件:\n\n"
        msg += "文件路径: " + targetFile + "\n\n"
        msg += "文件内容 (复制下面代码):\n"
        msg += "fileIn @\"" + (AA_NormalizePath corePath) + "\"\n\n"
        msg += "注意: 回调机制仍然有效，只是没有启动脚本。"
        messageBox msg title:"AA 安装需要手动操作"
        return false
    )
)

-- Register scene load callback
fn AA_RegisterSceneCallback scriptDir = (
    local corePath = scriptDir + "core\\spline_curve_sampler.ms"
    local normalizedPath = AA_NormalizePath corePath
    
    -- Remove existing callback
    callbacks.removeScripts id:AA_CALLBACK_ID
    
    -- Create callback script
    local callbackScript = "if doesFileExist @\"" + normalizedPath + "\" do fileIn @\"" + normalizedPath + "\" quiet:true"
    
    -- Register with persistent flag
    callbacks.addScript #filePostOpen callbackScript id:AA_CALLBACK_ID persistent:true
    callbacks.addScript #filePostMerge callbackScript id:AA_CALLBACK_ID persistent:true
    
    format "[AA] ✓ Scene load callbacks registered\n"
)

-- Load core module immediately (quick fix for current session)
fn AA_LoadCoreImmediate scriptDir = (
    local corePath = scriptDir + "core\\spline_curve_sampler.ms"
    if doesFileExist corePath do (
        fileIn corePath quiet:true
        format "[AA] ✓ Core module loaded for current session\n"
        return true
    )
    return false
)

-- # endregion

-- # region Main Installation Entry Point

-- Main function to ensure startup script is properly installed
fn AA_EnsureStartupInstalled scriptDir = (
    format "\n[AA] Checking startup script installation...\n"
    
    -- Step 1: Check if already installed
    local isInstalled = AA_IsStartupInstalled()
    
    if not isInstalled then (
        format "[AA] Startup script not found, installing...\n"
        AA_InstallStartupScript scriptDir
    ) else (
        format "[AA] ✓ Startup script already installed\n"
    )
    
    -- Step 2: Register scene callbacks (always do this)
    AA_RegisterSceneCallback scriptDir
    
    -- Step 3: Load core module immediately (quick fix)
    AA_LoadCoreImmediate scriptDir
    
    format "[AA] Startup check complete\n\n"
)

-- # endregion

-- # region Module Info

format "[OK] utils/startup_installer.ms loaded\n"

-- # endregion

