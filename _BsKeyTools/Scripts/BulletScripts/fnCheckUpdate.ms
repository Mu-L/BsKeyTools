/*
* @Description: BsKeyTools 版本检查模块
* @Author: Bullet.S
* @Date: 2026-05-16
* @Version: 1.4.0
*
* 对外接口:
*   fnCheckUpdate versionDatUrl [force:false] -- 手动触发检查（始终显示结果）
*   fnAutoCheckVersion versionDatUrl          -- 启动时自动检查（仅发现新版本时弹窗）
*
* version.dat 格式（两行）：
*   第一行：BsKeyTools 版本，如 "1.4.0"
*   第二行：BsCleanVirus 版本，如 "2.2"
*/

-- ── TLS 设置（国内 Gitee 需要 TLS 1.2）────────────────────────────────
global spm = (dotNetClass "System.Net.ServicePointManager")
spm.SecurityProtocol = spm.SecurityProtocol.Tls12

-- ── version.dat 拉取 ──────────────────────────────────────────────────
-- 返回 #(bsktVer, bscvVer)，网络失败或内容无效返回 undefined
fn fnFetchVersionDat versionDatUrl =
(
    local wc = dotNetObject "System.Net.WebClient"
    wc.Encoding = (dotNetClass "System.Text.Encoding").UTF8

    local content = undefined
    try (content = wc.DownloadString versionDatUrl)
    catch (format "[BsKeyTools] 拉取 version.dat 失败: %\n" (getCurrentException()))
    wc.Dispose() -- 保证释放，无论是否异常

    if content == undefined then return undefined

    local lines    = filterString content "\r\n"
    local bsktVer  = if lines.count >= 1 then (trimRight (trimLeft lines[1])) else ""
    local bscvVer  = if lines.count >= 2 then (trimRight (trimLeft lines[2])) else ""

    -- 空字符串视为无效（防止网络返回残缺内容导致误触发更新）
    if bsktVer == "" do bsktVer = undefined
    if bscvVer == "" do bscvVer = undefined

    #(bsktVer, bscvVer)
)

-- ── 跳过版本辅助 ──────────────────────────────────────────────────────
fn fnGetSkipVersion key =
(
    GetINISetting BulletConfig "BulletKeyToolsSet" key
)

fn fnSetSkipVersion key ver =
(
    SetINISetting BulletConfig "BulletKeyToolsSet" key ver
)

-- ── 单工具更新弹窗 ────────────────────────────────────────────────────
-- 弹出"发现新版本"对话框，Yes=下载安装包，No=稍后提醒，Cancel=跳过此版本
fn fnPromptUpdate toolName localVer onlineVer installerUrl fallbackUrl skipKey =
(
    local bodyText = "发现新版本 " + onlineVer + \
        "\r\n当前版本：" + localVer + \
        "\r\n\r\n[是] 立即下载安装包   [否] 稍后提醒   [取消] 跳过此版本"

    local MsgBox  = dotNetClass "System.Windows.Forms.MessageBox"
    local MsgBtns = dotNetClass "System.Windows.Forms.MessageBoxButtons"
    local MsgIcon = dotNetClass "System.Windows.Forms.MessageBoxIcon"
    local DlgRes  = dotNetClass "System.Windows.Forms.DialogResult"

    local dr = MsgBox.Show bodyText \
        (toolName + " 发现新版本 " + onlineVer) \
        MsgBtns.YesNoCancel \
        MsgIcon.Information

    if dr == DlgRes.Yes then
        fnUpdaterDownloadInstaller installerUrl fallbackUrl
    else if dr == DlgRes.Cancel do
    (
        fnSetSkipVersion skipKey onlineVer
        format "[BsKeyTools] 已跳过 % 版本 %\n" toolName onlineVer
    )
)

-- ── 对外接口 ──────────────────────────────────────────────────────────

-- 手动检查更新（菜单项触发）：始终显示两个工具的结果
-- force:true 时跳过版本比较，强制提示下载（用于"强制更新"菜单项）
fn fnCheckUpdate versionDatUrl force:false =
(
    local versions = fnFetchVersionDat versionDatUrl
    if versions == undefined then
    (
        messageBox "获取版本信息失败，请检查网络连接或稍后重试。                    " \
            title:"BsKeyTools 检查更新" beep:false
        return undefined
    )

    local onlineBskt = versions[1]
    local onlineBscv = versions[2]
    local hasUpdate  = false

    -- BsKeyTools
    if onlineBskt != undefined then
    (
        if force or onlineBskt != curVerBsKeyTools then
        (
            hasUpdate = true
            local url  = "https://gitee.com/acebullet/BsKeyTools/releases/download/v" + onlineBskt + "/BsKeyTools_v" + onlineBskt + ".exe"
            local back = "https://anibullet.github.io/"
            fnPromptUpdate "BsKeyTools" curVerBsKeyTools onlineBskt url back "SkipVersionBskt"
        )
    )

    -- BsCleanVirus（仅当已安装且 BsKeyTools 版本已知时检查；onlineBskt 用作 release tag）
    if onlineBscv != undefined and onlineBskt != undefined then
    (
        local localBscv = try(curVerBsCleanVirus) catch(undefined)
        if localBscv != undefined and localBscv != onlineBscv then
        (
            hasUpdate = true
            local url  = "https://gitee.com/acebullet/BsKeyTools/releases/download/v" + onlineBskt + "/BsCleanVirus_v" + onlineBscv + ".exe"
            local back = "https://anibullet.github.io/"
            fnPromptUpdate "BsCleanVirus" localBscv onlineBscv url back "SkipVersionBscv"
        )
    )

    if not hasUpdate do
    (
        if force then
            -- force 模式但 version.dat 第一行为空（网络返回残缺）
            messageBox "无法确认在线版本信息，请前往下载页手动检查。                    " \
                title:"BsKeyTools 强制更新" beep:false
        else
            messageBox ("所有工具均为最新版本：BsKeyTools " + curVerBsKeyTools + "                    ") \
                title:"BsKeyTools 检查更新" beep:false
    )
    OK
)

-- 启动时自动检查：只在发现新版本且未被跳过时弹窗
fn fnAutoCheckVersion versionDatUrl =
(
    local versions = fnFetchVersionDat versionDatUrl
    if versions == undefined then return undefined

    local onlineBskt = versions[1]
    local onlineBscv = versions[2]

    -- BsKeyTools
    if onlineBskt != undefined and onlineBskt != curVerBsKeyTools then
    (
        if (fnGetSkipVersion "SkipVersionBskt") != onlineBskt then
        (
            local url  = "https://gitee.com/acebullet/BsKeyTools/releases/download/v" + onlineBskt + "/BsKeyTools_v" + onlineBskt + ".exe"
            local back = "https://anibullet.github.io/"
            fnPromptUpdate "BsKeyTools" curVerBsKeyTools onlineBskt url back "SkipVersionBskt"
        )
        else
            format "[BsKeyTools] 跳过 BsKeyTools 版本 %\n" onlineBskt
    )

    -- BsCleanVirus（onlineBskt 用作 release tag，两者均须已知）
    if onlineBscv != undefined and onlineBskt != undefined then
    (
        local localBscv = try(curVerBsCleanVirus) catch(undefined)
        if localBscv != undefined and localBscv != onlineBscv then
        (
            if (fnGetSkipVersion "SkipVersionBscv") != onlineBscv then
            (
                local url  = "https://gitee.com/acebullet/BsKeyTools/releases/download/v" + onlineBskt + "/BsCleanVirus_v" + onlineBscv + ".exe"
                local back = "https://anibullet.github.io/"
                fnPromptUpdate "BsCleanVirus" localBscv onlineBscv url back "SkipVersionBscv"
            )
            else
                format "[BsKeyTools] 跳过 BsCleanVirus 版本 %\n" onlineBscv
        )
    )
)
