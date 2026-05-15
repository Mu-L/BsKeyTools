/*
* @Description: BsKeyTools 版本检查模块（v2.0 重写）
* @Author: Bullet.S
* @Date: 2026-05-16
* @Version: 2.0.0
*
* 对外接口:
*   fnCheckUpdate currentVer manifestUrl      -- 手动触发检查（始终显示当前状态）
*   fnAutoCheckVersion currentVer manifestUrl -- 启动时自动检查（仅发现新版本时弹窗）
*/

-- ── TLS 设置（国内 Gitee 需要 TLS 1.2）────────────────────────────────
global spm = (dotNetClass "System.Net.ServicePointManager")
spm.SecurityProtocol = spm.SecurityProtocol.Tls12

-- ── 数据结构 ──────────────────────────────────────────────────────────
struct BsManifest
(
    version,           -- string: "2.0.0"
    requireReinstall,  -- bool: true 时走重装流程
    releaseNote,       -- string: 更新说明，直接显示在弹窗中
    baseUrl,           -- string: 文件下载基础 URL（Gitee raw）
    files,             -- array of BsManifestFile
    installerUrl,      -- string: 安装包直链
    fallbackUrl        -- string: 下载失败时打开的网页
)

struct BsManifestFile
(
    path,    -- string: 相对路径，使用 /，如 "BulletScripts/BsBipedTools.ms"
    since,   -- string: 该文件最后修改的版本，如 "2.0.0"
    size     -- integer: 字节数，0 表示跳过校验
)

-- ── JSON 轻量解析工具 ─────────────────────────────────────────────────
-- 以下函数基于 System.Text.RegularExpressions，仅覆盖 manifest 所需的简单结构

-- 提取 key 对应的 string 值：  "key": "value"
fn fnJsonGetStr json key =
(
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" \
        ("\"" + key + "\"\\s*:\\s*\"([^\"]+)\"")
    local m = rx.Match json
    if m.Success then m.Groups.Item[1].Value else undefined
)

-- 提取 key 对应的 bool 值：  "key": true/false
fn fnJsonGetBool json key =
(
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" \
        ("\"" + key + "\"\\s*:\\s*(true|false)")
    local m = rx.Match json
    if m.Success then (m.Groups.Item[1].Value == "true") else false
)

-- 提取 key 对应的 integer 值：  "key": 12345
fn fnJsonGetInt json key =
(
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" \
        ("\"" + key + "\"\\s*:\\s*(\\d+)")
    local m = rx.Match json
    if m.Success then (m.Groups.Item[1].Value as integer) else 0
)

-- 解析 files 数组，返回 BsManifestFile 数组
fn fnParseManifestFiles json =
(
    local result = #()

    -- 提取 "files": [ ... ] 中括号内的内容
    local arrRx = dotNetObject "System.Text.RegularExpressions.Regex" \
        "\"files\"\\s*:\\s*\\[([\\s\\S]*?)\\]"
    local arrMatch = arrRx.Match json
    if not arrMatch.Success then return result

    local arrContent = arrMatch.Groups.Item[1].Value

    -- 逐个匹配 { ... } 对象
    local objRx = dotNetObject "System.Text.RegularExpressions.Regex" "\\{([^}]+)\\}"
    local matches = objRx.Matches arrContent
    local en = matches.GetEnumerator()
    while en.MoveNext() do
    (
        local obj = "{" + en.Current.Groups.Item[1].Value + "}"
        local path  = fnJsonGetStr obj "path"
        local since = fnJsonGetStr obj "since"
        local size  = fnJsonGetInt obj "size"
        if path != undefined and since != undefined do
            append result (BsManifestFile path:path since:since size:size)
    )
    result
)

-- 解析完整 manifest JSON，返回 BsManifest；格式错误返回 undefined
fn fnParseManifest json =
(
    local version = fnJsonGetStr json "version"
    if version == undefined then return undefined

    local requireReinstall = fnJsonGetBool json "requireReinstall"
    local releaseNote      = fnJsonGetStr  json "releaseNote"
    local baseUrl          = fnJsonGetStr  json "baseUrl"

    -- 解析 installer: { "url": "...", "fallbackUrl": "..." }
    local instRx = dotNetObject "System.Text.RegularExpressions.Regex" \
        "\"installer\"\\s*:\\s*\\{([^}]+)\\}"
    local instMatch = instRx.Match json
    local installerUrl = undefined
    local fallbackUrl  = undefined
    if instMatch.Success do
    (
        local instBlock = "{" + instMatch.Groups.Item[1].Value + "}"
        installerUrl = fnJsonGetStr instBlock "url"
        fallbackUrl  = fnJsonGetStr instBlock "fallbackUrl"
    )

    BsManifest \
        version:version \
        requireReinstall:requireReinstall \
        releaseNote:(if releaseNote != undefined then releaseNote else "") \
        baseUrl:(if baseUrl != undefined then baseUrl else "") \
        files:(fnParseManifestFiles json) \
        installerUrl:installerUrl \
        fallbackUrl:fallbackUrl
)

-- 从远端下载并解析 manifest，返回 BsManifest 或 undefined（网络/解析失败）
fn fnFetchManifest manifestUrl =
(
    try
    (
        local wc = dotNetObject "System.Net.WebClient"
        wc.Encoding = (dotNetClass "System.Text.Encoding").UTF8
        local json = wc.DownloadString manifestUrl
        wc.Dispose()
        fnParseManifest json
    )
    catch
    (
        format "[BsKeyTools] 拉取 manifest 失败: %\n" (getCurrentException())
        undefined
    )
)

-- ── 跳过版本辅助 ──────────────────────────────────────────────────────

fn fnGetSkipVersion =
(
    GetINISetting BulletConfig "BulletKeyToolsSet" "SkipVersion"
)

fn fnSetSkipVersion ver =
(
    SetINISetting BulletConfig "BulletKeyToolsSet" "SkipVersion" ver
)

-- ── 对外接口 ──────────────────────────────────────────────────────────

-- 手动检查更新（菜单项触发）：始终显示结果
-- currentVer: 本地版本字符串，如 "1.3.7"
-- manifestUrl: Gitee raw manifest.json URL
fn fnCheckUpdate currentVer manifestUrl =
(
    -- 拉取 manifest（失败时 try/catch 内已打印，直接弹提示）
    local manifest = fnFetchManifest manifestUrl
    if manifest == undefined then
    (
        messageBox "获取版本信息失败，请检查网络连接或稍后重试。                    " \
            title:"BsKeyTools 检查更新" beep:false
        return undefined
    )

    -- 已是最新
    if manifest.version == currentVer then
    (
        messageBox ("已是最新版本：" + currentVer + "                    ") \
            title:"BsKeyTools 检查更新" beep:false
        return OK
    )

    -- 构建提示文本
    local updateType = if manifest.requireReinstall then "（需重新安装）" else ""
    local bodyText = "发现新版本 " + manifest.version + updateType + \
        "\r\n当前版本：" + currentVer + "\r\n\r\n" + manifest.releaseNote

    if manifest.requireReinstall then
    (
        -- 重装流程：Yes/No
        local msg = bodyText + "\r\n\r\n此版本包含较大改动，需要重新运行安装包，是否立即下载？"
        if queryBox msg title:("BsKeyTools 发现新版本 " + manifest.version) then
            fnUpdaterDownloadInstaller manifest.installerUrl manifest.fallbackUrl
    )
    else
    (
        -- 增量更新：三按钮 Yes=立即更新 / No=稍后提醒 / Cancel=跳过此版本
        local msg = bodyText + "\r\n\r\n[是] 立即更新   [否] 稍后提醒   [取消] 跳过此版本"
        local MsgBox   = dotNetClass "System.Windows.Forms.MessageBox"
        local MsgBtns  = dotNetClass "System.Windows.Forms.MessageBoxButtons"
        local MsgIcon  = dotNetClass "System.Windows.Forms.MessageBoxIcon"
        local DlgRes   = dotNetClass "System.Windows.Forms.DialogResult"

        local dr = MsgBox.Show msg \
            ("BsKeyTools 发现新版本 " + manifest.version) \
            MsgBtns.YesNoCancel \
            MsgIcon.Information

        if dr == DlgRes.Yes then
        (
            local counts = fnUpdaterDownloadFiles manifest currentVer
            local doneMsg = "更新完成！成功下载 " + (counts[1] as string) + " 个文件。"
            if counts[2] > 0 do
                doneMsg += "\r\n" + (counts[2] as string) + " 个文件下载失败，下次启动将重试。"
            doneMsg += "\r\n\r\n请重新打开 3ds Max 以使更新生效。"
            messageBox doneMsg title:"BsKeyTools 更新完成" beep:false
        )
        else if dr == DlgRes.Cancel do
        (
            fnSetSkipVersion manifest.version
            format "[BsKeyTools] 已跳过版本 %\n" manifest.version
        )
        -- DlgRes.No：稍后提醒，什么都不做
    )
    OK
)

-- 启动时自动检查：发现新版本且用户未跳过时才弹窗
fn fnAutoCheckVersion currentVer manifestUrl =
(
    local manifest = fnFetchManifest manifestUrl
    if manifest == undefined then return undefined
    if manifest.version == currentVer then return undefined

    -- 用户已跳过此版本则静默退出
    if (fnGetSkipVersion()) == manifest.version then
    (
        format "[BsKeyTools] 跳过版本 %（用户已选择跳过）\n" manifest.version
        return undefined
    )

    -- 有更新，复用手动检查的弹窗逻辑
    fnCheckUpdate currentVer manifestUrl
)
