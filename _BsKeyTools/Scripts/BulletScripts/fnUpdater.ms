/*
* @Description: BsKeyTools 增量更新下载模块
* @Author: Bullet.S
* @Date: 2026-05-16
* @Version: 1.4.0
*
* 对外接口（由 fnCheckUpdate.ms 调用）:
*   fnUpdaterDownloadFiles manifest currentVer  -- 增量下载 since > currentVer 的脚本文件
*   fnUpdaterDownloadInstaller installerUrl fallbackUrl  -- 下载安装包或打开备用网页
*/

-- ── 语义版本比较 ──────────────────────────────────────────────────────
-- 返回 true 当且仅当 v1 严格大于 v2（如 "2.0.0" > "1.3.7"）
fn fnVersionGt v1 v2 =
(
    local p1 = filterString v1 "."
    local p2 = filterString v2 "."
    local len = if p1.count < p2.count then p1.count else p2.count
    local i = 1
    while i <= len do
    (
        local n1 = (p1[i] as integer)
        local n2 = (p2[i] as integer)
        if n1 > n2 then return true
        if n1 < n2 then return false
        i = i + 1
    )
    -- 相等时：段数更多视为更大（如 "2.0.0.1" > "2.0.0"），否则相等
    p1.count > p2.count
)

-- ── 临时目录 ──────────────────────────────────────────────────────────
-- 获取（并按需创建）下载临时目录 %TEMP%\BsUpdate\
fn fnUpdaterGetTempDir =
(
    local tempDir = (getDir #temp) + "\\BsUpdate\\"
    if not (doesDirectoryExist tempDir) do
        try((dotNetClass "System.IO.Directory").CreateDirectory tempDir)catch()
    tempDir
)

-- ── 单文件下载 ────────────────────────────────────────────────────────
-- 下载 url 到临时目录，文件名为 filename + ".tmp"
-- 成功返回临时文件完整路径，失败返回 undefined
fn fnUpdaterDownloadToTemp url filename =
(
    local tempDir = fnUpdaterGetTempDir()
    local tmpPath = tempDir + filename + ".tmp"
    try
    (
        local wc = dotNetObject "System.Net.WebClient"
        wc.Encoding = (dotNetClass "System.Text.Encoding").UTF8
        local uri = dotNetObject "System.Uri" url  -- System.Uri 自动处理特殊字符编码
        wc.DownloadFile uri tmpPath
        wc.Dispose()
        tmpPath
    )
    catch
    (
        format "[BsUpdater] 下载失败: % | %\n" filename (getCurrentException())
        undefined
    )
)

-- ── 文件校验 ──────────────────────────────────────────────────────────
-- 校验临时文件大小是否与 manifest 记录一致
-- expectedSize = 0 时跳过校验（直接返回 true）
fn fnUpdaterVerifyFile path expectedSize =
(
    if not (doesFileExist path) then return false
    if expectedSize == 0 then return true  -- size=0 表示信任，不校验
    try
    (
        local fi = dotNetObject "System.IO.FileInfo" path
        (fi.Length as integer) == expectedSize
    )
    catch
    (
        false
    )
)

-- ── 安全覆盖 ──────────────────────────────────────────────────────────
-- 将临时文件覆盖写入目标路径，自动创建缺失的父目录
-- 返回 true/false
fn fnUpdaterSafeCopy src dst =
(
    try
    (
        local dstDir = getFileNamePath dst
        if not (doesDirectoryExist dstDir) do
            (dotNetClass "System.IO.Directory").CreateDirectory dstDir
        (dotNetClass "System.IO.File").Copy src dst true  -- true = 允许覆盖
        true
    )
    catch
    (
        format "[BsUpdater] 覆盖失败: % -> %\n  %\n" src dst (getCurrentException())
        false
    )
)

-- ── 清除 Python 缓存 ──────────────────────────────────────────────────
-- 删除 scriptsDir\BulletScripts\__pycache__\ 目录下的所有文件
-- 在更新 .py 文件后调用，避免旧 .pyc 缓存干扰
fn fnUpdaterClearPycache scriptsDir =
(
    local cacheDir = scriptsDir + "\\BulletScripts\\__pycache__\\"
    if doesDirectoryExist cacheDir do
    (
        try
        (
            local pyDir = dotNetObject "System.IO.DirectoryInfo" cacheDir
            local pyFiles = pyDir.GetFiles()
            for f in pyFiles do
            (
                try(f.Delete())catch()
            )
            format "[BsUpdater] 已清除 __pycache__\n"
        )
        catch
        (
            format "[BsUpdater] 清除 __pycache__ 失败: %\n" (getCurrentException())
        )
    )
)

-- ── 批量下载脚本文件（对外接口）──────────────────────────────────────
-- 下载 manifest.files 中 since > currentVer 的所有文件
-- manifest: BsManifest struct（由 fnCheckUpdate.ms 解析传入）
-- currentVer: 用户本地版本字符串
-- 返回 #(成功数, 失败数)
fn fnUpdaterDownloadFiles manifest currentVer =
(
    local scriptsDir = getDir #scripts
    local successCount = 0
    local failCount = 0
    local hasPyUpdate = false

    for f in manifest.files do
    (
        if fnVersionGt f.since currentVer do
        (
            -- 构建远端 URL
            local url = manifest.baseUrl + f.path

            -- 取最后一段作为临时文件名（避免目录分隔符问题）
            local segments = filterString f.path "/"
            local filename = segments[segments.count]

            -- 构建本地目标路径
            local dstPath = scriptsDir + "\\" + (substituteString f.path "/" "\\")

            format "[BsUpdater] 下载: %\n" f.path

            -- 下载 → 校验 → 覆盖
            local tmpPath = fnUpdaterDownloadToTemp url filename
            if tmpPath != undefined then
            (
                if fnUpdaterVerifyFile tmpPath f.size then
                (
                    if fnUpdaterSafeCopy tmpPath dstPath then
                    (
                        successCount += 1
                        -- 标记是否有 Python 文件更新
                        if (matchPattern filename pattern:"*.py") do
                            hasPyUpdate = true
                    )
                    else
                        failCount += 1
                )
                else
                (
                    format "[BsUpdater] 大小校验失败（可能下载不完整或 Gitee 限流）: %\n" f.path
                    failCount += 1
                )
                try(deleteFile tmpPath)catch()  -- 清理临时文件
            )
            else
                failCount += 1
        )
    )

    -- 有 .py 文件更新时清除 pycache
    if hasPyUpdate do fnUpdaterClearPycache scriptsDir

    format "[BsUpdater] 完成: 成功 %，失败 %\n" successCount failCount
    #(successCount, failCount)
)

-- ── 下载安装包（对外接口）────────────────────────────────────────────
-- 尝试下载 installerUrl 到临时目录并启动
-- 下载失败或文件太小（疑为 HTML 错误页）则打开 fallbackUrl
fn fnUpdaterDownloadInstaller installerUrl fallbackUrl =
(
    local exePath = (getDir #temp) + "\\BsKeyTools_Setup.exe"
    local dlOk = false

    if installerUrl != undefined and installerUrl != "" do
    (
        try
        (
            local wc = dotNetObject "System.Net.WebClient"
            local uri = dotNetObject "System.Uri" installerUrl
            wc.DownloadFile uri exePath
            wc.Dispose()

            if doesFileExist exePath then
            (
                local fi = dotNetObject "System.IO.FileInfo" exePath
                -- 大于 500KB 才视为有效 exe（排除 HTML 错误页）
                if (fi.Length as integer) > 512000 then
                    dlOk = true
                else
                (
                    try(deleteFile exePath)catch()
                    format "[BsUpdater] 下载的文件太小，可能是 Gitee 错误页，将打开备用链接\n"
                )
            )
        )
        catch
        (
            format "[BsUpdater] 安装包下载失败: %\n" (getCurrentException())
        )
    )

    if dlOk then
    (
        format "[BsUpdater] 启动安装程序: %\n" exePath
        ShellLaunch exePath ""
    )
    else
    (
        local url = if (fallbackUrl != undefined and fallbackUrl != "") \
            then fallbackUrl \
            else "https://anibullet.github.io/guide/"
        format "[BsUpdater] 打开备用下载页: %\n" url
        ShellLaunch url ""
    )
)
