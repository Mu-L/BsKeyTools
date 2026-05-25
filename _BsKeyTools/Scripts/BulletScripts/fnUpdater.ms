/*
* @Description: BsKeyTools 安装包下载模块
* @Author: Bullet.S
* @Date: 2026-05-16
* @Version: 1.4.0
*
* 对外接口（由 fnCheckUpdate.ms 调用）:
*   fnUpdaterDownloadInstaller installerUrl fallbackUrl
*/

-- 尝试下载 installerUrl 到临时目录并启动安装程序
-- 注意：DownloadFile 为同步调用，下载期间 Max 界面暂时无响应，属正常现象
-- 下载失败或文件太小（疑为 HTML 错误页）则弹提示并打开 fallbackUrl
fn fnUpdaterDownloadInstaller installerUrl fallbackUrl =
(
    local dlOk    = false
    local exePath = ""

    if installerUrl != undefined and installerUrl != "" do
    (
        -- 从 URL 末尾提取文件名，避免 BsKeyTools 与 BsCleanVirus 下载路径冲突
        local urlParts = filterString installerUrl "/"
        local exeName  = if urlParts.count > 0 then urlParts[urlParts.count] else "BsKeyTools_Setup.exe"
        exePath = (getDir #temp) + "\\" + exeName

        try
        (
            local wc  = dotNetObject "System.Net.WebClient"
            local uri = dotNetObject "System.Uri" installerUrl
            wc.DownloadFile uri exePath
            wc.Dispose()

            if doesFileExist exePath then
            (
                local fi = dotNetObject "System.IO.FileInfo" exePath
                -- 大于 500KB 才视为有效 exe（排除 Gitee HTML 错误页）
                if (fi.Length as integer) > 512000 then
                    dlOk = true
                else
                (
                    try(deleteFile exePath) catch()
                    format "[BsUpdater] 下载文件太小，可能是 Gitee 错误页，将打开备用链接\n"
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
            else "https://anibullet.github.io/"
        format "[BsUpdater] 安装包下载失败，打开备用下载页: %\n" url
        messageBox "安装包下载失败，已为你打开备用下载页。\r\n请在浏览器中手动下载安装。" \
            title:"BsKeyTools 更新" beep:false
        ShellLaunch url ""
    )
)
