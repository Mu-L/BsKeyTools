# BsKeyTools 增量自动更新系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 BsKeyTools 的更新流程从「下载完整安装包」升级为「按需差量下载脚本文件」，同时配置 GitHub → Gitee 自动镜像。

**Architecture:** 新增 `fnUpdater.ms` 模块负责所有文件下载逻辑；重构 `fnCheckUpdate.ms` 专职版本比对与弹窗；`manifest.json` 托管在 Gitee，记录各文件版本与大小；GitHub Actions 在 push main 后自动镜像到 Gitee。增量更新完成后提示重启 Max，重装场景则尝试下载 exe，失败则打开备用网页。

**Tech Stack:** MAXScript, dotNet (System.Net.WebClient / System.IO.File / System.Text.RegularExpressions), GitHub Actions, Gitee raw file hosting

---

## 文件结构

| 文件 | 变化 | 职责 |
|------|------|------|
| `_BsKeyTools/manifest.json` | **新增** | 远端版本清单，Gitee raw 访问，用户不需本地副本 |
| `_BsKeyTools/Scripts/BulletScripts/fnUpdater.ms` | **新增** | 版本比较、下载到 temp、校验、覆盖、exe 下载 |
| `_BsKeyTools/Scripts/BulletScripts/fnCheckUpdate.ms` | **重写** | manifest 拉取解析、弹窗、调用 fnUpdater |
| `_BsKeyTools/Scripts/BulletScripts/BulletKeyTools.ms` | **修改** | 更新全局 URL、添加 fnUpdater.ms FileIn、更新调用签名 |
| `.github/workflows/sync-gitee.yml` | **新增** | push main 后自动镜像到 Gitee |

**NSIS 无需改动**：安装脚本已用 `File /r "Scripts\*.*"` 递归安装，`fnUpdater.ms` 自动被包含。`manifest.json` 始终从 Gitee 远端拉取，不需要安装到用户本地。

---

## Task 1: 创建 manifest.json

**Files:**
- Create: `_BsKeyTools/manifest.json`

- [ ] **Step 1: 在 Max Listener 运行以下代码获取所有脚本文件大小**

```maxscript
local scriptsDir = getDir #scripts
local files = #(
    "BulletScripts/BsAnimDemoTools.ms",
    "BulletScripts/BsBatchRescaleWU.ms",
    "BulletScripts/BsBipedTools.ms",
    "BulletScripts/BsBoxMan.ms",
    "BulletScripts/BsCleanVirus.ms",
    "BulletScripts/BsFnKeys.ms",
    "BulletScripts/BsKeyStepMode.ms",
    "BulletScripts/BsLayerManager.ms",
    "BulletScripts/BsOpenTools.ms",
    "BulletScripts/BsOpenToolsPy.ms",
    "BulletScripts/BsQuickSave.ms",
    "BulletScripts/BsRefTools.ms",
    "BulletScripts/BsResetConfig.ms",
    "BulletScripts/BsRetargetTools.ms",
    "BulletScripts/BsRootMotionTools.ms",
    "BulletScripts/BsScriptHub.ms",
    "BulletScripts/BsScriptMenu.ms",
    "BulletScripts/BsScriptMenuMacro.ms",
    "BulletScripts/BsScriptsSet.ms",
    "BulletScripts/BsSelSetTools.ms",
    "BulletScripts/BsSwitchBtnString.ms",
    "BulletScripts/BsTogglePanel.ms",
    "BulletScripts/BsTrackBarTools.ms",
    "BulletScripts/BsVportTools.ms",
    "BulletScripts/BulletKeyTools.ms",
    "BulletScripts/fnCheckUpdate.ms",
    "BulletScripts/fnFileAndDirIO.ms",
    "BulletScripts/fnGetColorTheme.ms",
    "BulletScripts/fnSaveLoadConfig.ms",
    "BulletScripts/fnSelectKeys.ms",
    "BulletScripts/fnSetFps.ms",
    "BulletScripts/fnSetPlaybackSpeed.ms",
    "BulletScripts/fnUpdater.ms",
    "BulletScripts/stLangManager.ms",
    "BulletScripts/BsAnimLib.py",
    "BulletScripts/BsOpenToolsPy_PySide2.py",
    "BulletScripts/BsOpenToolsPy_PySide6.py",
    "BulletScripts/BsScriptHub.py",
    "BulletScripts/Lang/CHS.lng",
    "BulletScripts/Lang/ENG.lng"
)
for f in files do
(
    local fullPath = scriptsDir + "\\" + (substituteString f "/" "\\")
    local sz = if doesFileExist fullPath then (getFileSize fullPath) else 0
    format "    { \"path\": \"%\", \"since\": \"1.3.7\", \"size\": % },\n" f sz
)
```

记录输出结果，下一步用到。

- [ ] **Step 2: 创建 `_BsKeyTools/manifest.json`**

用 Step 1 的输出填充 `files` 数组中每项的 `size`。`fnCheckUpdate.ms` 和 `fnUpdater.ms` 是本次新增/重写的文件，将它们的 `since` 改为 `"2.0.0"`（其余保持 `"1.3.7"`）：

```json
{
  "version": "2.0.0",
  "requireReinstall": false,
  "releaseNote": "新增增量自动更新，无需重下安装包即可获取脚本更新",
  "baseUrl": "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/Scripts/",
  "files": [
    { "path": "BulletScripts/BsAnimDemoTools.ms",      "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsBatchRescaleWU.ms",     "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsBipedTools.ms",         "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsBoxMan.ms",             "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsCleanVirus.ms",         "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsFnKeys.ms",             "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsKeyStepMode.ms",        "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsLayerManager.ms",       "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsOpenTools.ms",          "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsOpenToolsPy.ms",        "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsQuickSave.ms",          "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsRefTools.ms",           "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsResetConfig.ms",        "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsRetargetTools.ms",      "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsRootMotionTools.ms",    "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsScriptHub.ms",          "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsScriptMenu.ms",         "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsScriptMenuMacro.ms",    "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsScriptsSet.ms",         "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsSelSetTools.ms",        "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsSwitchBtnString.ms",    "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsTogglePanel.ms",        "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsTrackBarTools.ms",      "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsVportTools.ms",         "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BulletKeyTools.ms",       "since": "2.0.0", "size": 0 },
    { "path": "BulletScripts/fnCheckUpdate.ms",        "since": "2.0.0", "size": 0 },
    { "path": "BulletScripts/fnFileAndDirIO.ms",       "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/fnGetColorTheme.ms",      "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/fnSaveLoadConfig.ms",     "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/fnSelectKeys.ms",         "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/fnSetFps.ms",             "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/fnSetPlaybackSpeed.ms",   "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/fnUpdater.ms",            "since": "2.0.0", "size": 0 },
    { "path": "BulletScripts/stLangManager.ms",        "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsAnimLib.py",            "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsOpenToolsPy_PySide2.py","since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsOpenToolsPy_PySide6.py","since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/BsScriptHub.py",          "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/Lang/CHS.lng",            "since": "1.3.7", "size": 0 },
    { "path": "BulletScripts/Lang/ENG.lng",            "since": "1.3.7", "size": 0 }
  ],
  "installer": {
    "url": "https://gitee.com/acebullet/BsKeyTools/releases/download/v2.0.0/BsKeyTools_v2.0.0.exe",
    "fallbackUrl": "https://anibullet.github.io/guide/"
  }
}
```

将 `"size": 0` 替换为 Step 1 输出的实际字节数（`size: 0` 表示跳过校验，实际值更安全）。

- [ ] **Step 3: 验证 JSON 格式**

用在线 JSON 校验器（如 jsonlint.com）或在 Max Listener 执行：
```maxscript
local wc = dotNetObject "System.Net.WebClient"
-- 先读本地文件验证格式（临时用）
local content = (dotNetClass "System.IO.File").ReadAllText @"D:\_Scripts\GitHub\BsKeyTools\_BsKeyTools\manifest.json"
print (content.Length as string)  -- 应大于 100
```

- [ ] **Step 4: 提交**

```bash
git add _BsKeyTools/manifest.json
git commit -m "feat: add manifest.json for incremental update system"
```

---

## Task 2: 创建 GitHub Actions 自动同步

**Files:**
- Create: `.github/workflows/sync-gitee.yml`

- [ ] **Step 1: 在本机生成 SSH 密钥对（如已有可跳过）**

```bash
ssh-keygen -t ed25519 -C "github-to-gitee-bskeytools" -f ~/.ssh/gitee_sync
```

生成两个文件：`~/.ssh/gitee_sync`（私钥）和 `~/.ssh/gitee_sync.pub`（公钥）。

- [ ] **Step 2: 将公钥添加到 Gitee**

登录 Gitee → 右上角头像 → 设置 → SSH 公钥 → 添加公钥。
标题填 `github-sync`，内容粘贴 `~/.ssh/gitee_sync.pub` 的内容。

- [ ] **Step 3: 将私钥添加到 GitHub Secrets**

登录 GitHub → 仓库 Settings → Secrets and variables → Actions → New repository secret。
Name: `GITEE_SSH_PRIVATE_KEY`，Value: 粘贴 `~/.ssh/gitee_sync` 的完整内容（包含 `-----BEGIN...` 行）。

- [ ] **Step 4: 创建 workflow 文件**

```yaml
# .github/workflows/sync-gitee.yml
name: Sync to Gitee

on:
  push:
    branches: [ main ]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Mirror to Gitee
        uses: wearerequired/git-mirror-action@master
        env:
          SSH_PRIVATE_KEY: ${{ secrets.GITEE_SSH_PRIVATE_KEY }}
        with:
          source-repo: "git@github.com:AniBullet/BsKeyTools.git"
          destination-repo: "git@gitee.com:acebullet/BsKeyTools.git"
```

- [ ] **Step 5: 提交并验证**

```bash
git add .github/workflows/sync-gitee.yml
git commit -m "ci: add GitHub Actions auto-sync to Gitee"
git push origin dev
```

合并到 main 后，在 GitHub → Actions 页面确认 workflow 运行成功，然后访问：
`https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/manifest.json`
应能看到 manifest 内容（若 Gitee 同步完成）。

---

## Task 3: 创建 fnUpdater.ms

**Files:**
- Create: `_BsKeyTools/Scripts/BulletScripts/fnUpdater.ms`

- [ ] **Step 1: 创建文件，写入版本比较函数**

```maxscript
/*
* @Description: BsKeyTools 更新下载模块
* @Author: Bullet.S
* @Version: 2.0.0
* 对外接口:
*   fnUpdaterDownloadFiles manifest currentVer  -- 增量下载脚本文件
*   fnUpdaterDownloadInstaller installerUrl fallbackUrl  -- 下载安装包或打开网页
*/

-- 语义版本比较：v1 是否大于 v2（如 "2.0.0" > "1.3.7"）
fn fnVersionGt v1 v2 =
(
    local p1 = filterString v1 "."
    local p2 = filterString v2 "."
    local len = (min p1.count p2.count)
    local i = 1
    while i <= len do
    (
        local n1 = (p1[i] as integer)
        local n2 = (p2[i] as integer)
        if n1 > n2 then return true
        if n1 < n2 then return false
        i += 1
    )
    false  -- 相等或 v1 段数更少视为不大于
)
```

- [ ] **Step 2: 在 Max Listener 验证版本比较**

```maxscript
fileIn ((getDir #scripts) + "\\BulletScripts\\fnUpdater.ms")
print (fnVersionGt "2.0.0" "1.3.7")   -- 应输出 true
print (fnVersionGt "1.3.7" "2.0.0")   -- 应输出 false
print (fnVersionGt "1.3.7" "1.3.7")   -- 应输出 false
print (fnVersionGt "1.3.10" "1.3.9")  -- 应输出 true
```

期望：依次输出 `true` `false` `false` `true`

- [ ] **Step 3: 添加临时目录和下载函数**

在 `fnVersionGt` 之后追加：

```maxscript
-- 获取/创建下载临时目录
fn fnUpdaterGetTempDir =
(
    local tempDir = (getDir #temp) + "\\BsUpdate\\"
    if not (doesDirectoryExist tempDir) then
        (dotNetClass "System.IO.Directory").CreateDirectory tempDir
    tempDir
)

-- 下载单个文件到临时目录，返回临时文件路径，失败返回 undefined
fn fnUpdaterDownloadToTemp url filename =
(
    local tempDir = fnUpdaterGetTempDir()
    local tmpPath = tempDir + filename + ".tmp"
    try
    (
        local wc = dotNetObject "System.Net.WebClient"
        wc.Encoding = (dotNetClass "System.Text.Encoding").UTF8
        local uri = dotNetObject "System.Uri" url  -- 自动处理 URL 编码
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
```

- [ ] **Step 4: 在 Max Listener 验证下载函数**

```maxscript
fileIn ((getDir #scripts) + "\\BulletScripts\\fnUpdater.ms")
-- 下载一个小文件测试（用 manifest.json 本身测试）
local tmpPath = fnUpdaterDownloadToTemp \
    "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/manifest.json" \
    "test_manifest"
print tmpPath  -- 应输出临时文件路径
print (doesFileExist tmpPath)  -- 应输出 true
```

- [ ] **Step 5: 添加文件校验和安全复制函数**

追加：

```maxscript
-- 校验临时文件大小是否与 manifest 一致，size=0 时跳过校验直接返回 true
fn fnUpdaterVerifyFile path expectedSize =
(
    if not (doesFileExist path) then return false
    if expectedSize == 0 then return true  -- size=0 表示不校验
    local fi = dotNetObject "System.IO.FileInfo" path
    (fi.Length as integer) == expectedSize
)

-- 将临时文件安全覆盖到目标路径，返回 true/false
fn fnUpdaterSafeCopy src dst =
(
    try
    (
        -- 确保目标目录存在（处理新增文件场景）
        local dstDir = getFileNamePath dst
        if not (doesDirectoryExist dstDir) then
            (dotNetClass "System.IO.Directory").CreateDirectory dstDir
        -- 覆盖写入
        (dotNetClass "System.IO.File").Copy src dst true
        true
    )
    catch
    (
        format "[BsUpdater] 复制失败: % -> %\n  %\n" src dst (getCurrentException())
        false
    )
)
```

- [ ] **Step 6: 添加批量下载脚本文件函数**

追加：

```maxscript
-- 下载所有 since > currentVer 的文件
-- manifest 为 BsManifest struct（由 fnCheckUpdate.ms 解析后传入）
-- 返回 #(成功数, 失败数)
fn fnUpdaterDownloadFiles manifest currentVer =
(
    local scriptsDir = getDir #scripts
    local successCount = 0
    local failCount = 0

    for f in manifest.files do
    (
        if fnVersionGt f.since currentVer then
        (
            -- 构建 URL 和本地路径
            local url = manifest.baseUrl + f.path
            -- 取文件名作为临时文件名（如 BsBipedTools.ms）
            local segments = filterString f.path "/"
            local filename = segments[segments.count]
            local dstPath = scriptsDir + "\\" + (substituteString f.path "/" "\\")

            format "[BsUpdater] 下载: %\n" f.path

            local tmpPath = fnUpdaterDownloadToTemp url filename
            if tmpPath != undefined then
            (
                if fnUpdaterVerifyFile tmpPath f.size then
                (
                    if fnUpdaterSafeCopy tmpPath dstPath then
                        (successCount += 1)
                    else
                        (failCount += 1)
                )
                else
                (
                    format "[BsUpdater] 文件校验失败（大小不匹配）: %\n" f.path
                    failCount += 1
                )
                try(deleteFile tmpPath)catch()  -- 清理临时文件
            )
            else
                (failCount += 1)
        )
    )
    format "[BsUpdater] 完成: 成功 %，失败 %\n" successCount failCount
    #(successCount, failCount)
)
```

- [ ] **Step 7: 添加下载安装包函数**

追加：

```maxscript
-- 尝试下载并启动安装包 exe，失败则打开 fallbackUrl
fn fnUpdaterDownloadInstaller installerUrl fallbackUrl =
(
    local exePath = (getDir #temp) + "\\BsKeyTools_Setup.exe"
    local dlOk = false

    -- 尝试下载 exe
    if installerUrl != undefined and installerUrl != "" then
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
                -- 若文件大于 500KB 视为有效 exe（排除 HTML 错误页）
                if (fi.Length as integer) > 512000 then
                    dlOk = true
                else
                (
                    deleteFile exePath
                    format "[BsUpdater] 下载的文件太小，可能是错误页\n"
                )
            )
        )
        catch
        (
            format "[BsUpdater] exe 下载失败: %\n" (getCurrentException())
        )
    )

    if dlOk then
    (
        format "[BsUpdater] 启动安装程序: %\n" exePath
        ShellLaunch exePath ""
    )
    else
    (
        -- Fallback：打开下载网页
        local url = if (fallbackUrl != undefined and fallbackUrl != "") \
            then fallbackUrl \
            else "https://anibullet.github.io/guide/"
        format "[BsUpdater] 打开下载页: %\n" url
        ShellLaunch url ""
    )
)
```

- [ ] **Step 8: 提交**

```bash
git add "_BsKeyTools/Scripts/BulletScripts/fnUpdater.ms"
git commit -m "feat: add fnUpdater.ms incremental download module"
```

---

## Task 4: 重写 fnCheckUpdate.ms

**Files:**
- Modify: `_BsKeyTools/Scripts/BulletScripts/fnCheckUpdate.ms`

- [ ] **Step 1: 用以下内容完整替换 fnCheckUpdate.ms**

```maxscript
/*
* @Description: BsKeyTools 版本检查模块（v2.0 重写）
* @Author: Bullet.S
* @Version: 2.0.0
* 对外接口:
*   fnCheckUpdate currentVer manifestUrl           -- 手动触发检查（始终显示结果）
*   fnAutoCheckVersion currentVer manifestUrl      -- 自动检查（仅发现更新时显示）
*/

-- ── TLS 设置（保持与旧版一致）──────────────────────────────────────
global spm = (dotNetclass "System.Net.ServicePointManager")
spm.SecurityProtocol = spm.SecurityProtocol.Tls12

-- ── Manifest 数据结构 ─────────────────────────────────────────────
struct BsManifest
(
    version,          -- string: "2.0.0"
    requireReinstall, -- bool
    releaseNote,      -- string
    baseUrl,          -- string: raw 文件基础 URL
    files,            -- array of BsManifestFile
    installerUrl,     -- string
    fallbackUrl       -- string
)

struct BsManifestFile
(
    path,   -- string: 相对于 scripts dir 的路径，用 /
    since,  -- string: "2.0.0"
    size    -- integer: 字节数，0 表示不校验
)

-- ── JSON 解析工具函数 ─────────────────────────────────────────────

-- 从 JSON 字符串中提取 key 对应的 string 值，失败返回 undefined
fn fnJsonGetStr json key =
(
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" \
        ("\"" + key + "\"\\s*:\\s*\"([^\"]+)\"")
    local m = rx.Match json
    if m.Success then m.Groups.Item[1].Value else undefined
)

-- 从 JSON 字符串中提取 key 对应的 bool 值，失败返回 false
fn fnJsonGetBool json key =
(
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" \
        ("\"" + key + "\"\\s*:\\s*(true|false)")
    local m = rx.Match json
    if m.Success then (m.Groups.Item[1].Value == "true") else false
)

-- 从 JSON 字符串中提取 key 对应的 integer 值，失败返回 0
fn fnJsonGetInt json key =
(
    local rx = dotNetObject "System.Text.RegularExpressions.Regex" \
        ("\"" + key + "\"\\s*:\\s*(\\d+)")
    local m = rx.Match json
    if m.Success then (m.Groups.Item[1].Value as integer) else 0
)

-- 解析 manifest JSON 中的 files 数组，返回 BsManifestFile 数组
fn fnParseManifestFiles json =
(
    local result = #()
    -- 提取 files: [ ... ] 内的内容
    local arrRx = dotNetObject "System.Text.RegularExpressions.Regex" \
        "\"files\"\\s*:\\s*\\[([\\s\\S]*?)\\]"
    local arrMatch = arrRx.Match json
    if not arrMatch.Success then return result
    local arrContent = arrMatch.Groups.Item[1].Value

    -- 匹配每个文件对象 { ... }
    local objRx = dotNetObject "System.Text.RegularExpressions.Regex" "\\{([^}]+)\\}"
    local matches = objRx.Matches arrContent
    local en = matches.GetEnumerator()
    while en.MoveNext() do
    (
        local obj = "{" + en.Current.Groups.Item[1].Value + "}"
        local path  = fnJsonGetStr obj "path"
        local since = fnJsonGetStr obj "since"
        local size  = fnJsonGetInt obj "size"
        if path != undefined and since != undefined then
            append result (BsManifestFile path:path since:since size:size)
    )
    result
)

-- 解析完整 manifest JSON，返回 BsManifest 或 undefined（格式错误时）
fn fnParseManifest json =
(
    local version = fnJsonGetStr json "version"
    if version == undefined then return undefined

    local requireReinstall = fnJsonGetBool json "requireReinstall"
    local releaseNote      = fnJsonGetStr  json "releaseNote"
    local baseUrl          = fnJsonGetStr  json "baseUrl"

    -- 提取 installer: { url, fallbackUrl }
    local instRx = dotNetObject "System.Text.RegularExpressions.Regex" \
        "\"installer\"\\s*:\\s*\\{([^}]+)\\}"
    local instMatch = instRx.Match json
    local installerUrl = undefined
    local fallbackUrl  = undefined
    if instMatch.Success then
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

-- 从远端拉取并解析 manifest，返回 BsManifest 或 undefined（网络/解析失败）
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

-- ── 跳过版本工具 ──────────────────────────────────────────────────

fn fnGetSkipVersion =
(
    GetINISetting BulletConfig "BulletKeyToolsSet" "SkipVersion"
)

fn fnSetSkipVersion ver =
(
    SetINISetting BulletConfig "BulletKeyToolsSet" "SkipVersion" ver
)

-- ── 主要对外接口 ──────────────────────────────────────────────────

-- 手动检查更新（始终显示当前状态）
-- currentVer: string，如 "1.3.7"
-- manifestUrl: Gitee raw URL
fn fnCheckUpdate currentVer manifestUrl =
(
    if not (internet.CheckConnection url:"https://gitee.com" force:true) then
    (
        messageBox "无法连接到 Gitee，请检查网络连接。                    " \
            title:"BsKeyTools 检查更新" beep:false
        return undefined
    )

    local manifest = fnFetchManifest manifestUrl
    if manifest == undefined then
    (
        messageBox "获取版本信息失败，请稍后重试。                    " \
            title:"BsKeyTools 检查更新" beep:false
        return undefined
    )

    if manifest.version == currentVer then
    (
        messageBox ("已是最新版本：" + currentVer + "                    ") \
            title:"BsKeyTools 检查更新" beep:false
        return OK
    )

    -- 有更新，构建提示文本
    local updateType = if manifest.requireReinstall then "（需重新安装）" else ""
    local msg = "发现新版本 " + manifest.version + updateType + "\r\n" + \
                "当前版本：" + currentVer + "\r\n\r\n" + \
                manifest.releaseNote + "\r\n\r\n" + \
                (if manifest.requireReinstall \
                    then "此版本需要重新安装，是否立即下载安装包？" \
                    else "是否立即下载更新？（完成后需重开 Max）")

    if manifest.requireReinstall then
    (
        -- 重装流程
        if queryBox msg title:"BsKeyTools 发现新版本" then
            fnUpdaterDownloadInstaller manifest.installerUrl manifest.fallbackUrl
    )
    else
    (
        -- 增量更新流程：Yes/No/Cancel（跳过此版本）
        local dr = (dotNetClass "System.Windows.Forms.MessageBox").Show \
            (msg + "\r\n\r\n[是] 立即更新  [否] 稍后提醒  [取消] 跳过此版本") \
            ("BsKeyTools 发现新版本 " + manifest.version) \
            ((dotNetClass "System.Windows.Forms.MessageBoxButtons").YesNoCancel) \
            ((dotNetClass "System.Windows.Forms.MessageBoxIcon").Information)

        local drYes    = (dotNetClass "System.Windows.Forms.DialogResult").Yes
        local drCancel = (dotNetClass "System.Windows.Forms.DialogResult").Cancel

        if dr == drYes then
        (
            local counts = fnUpdaterDownloadFiles manifest currentVer
            local msg2 = "更新完成！成功下载 " + (counts[1] as string) + " 个文件。"
            if counts[2] > 0 then msg2 += "\r\n" + (counts[2] as string) + " 个文件下载失败，下次启动时将重试。"
            msg2 += "\r\n\r\n请重新打开 3ds Max 以使更新生效。"
            messageBox msg2 title:"BsKeyTools 更新完成" beep:false
        )
        else if dr == drCancel then
        (
            fnSetSkipVersion manifest.version
            format "[BsKeyTools] 已跳过版本 %\n" manifest.version
        )
    )
    OK
)

-- 自动检查（启动时调用），仅在发现更新时弹窗
-- 若用户已跳过该版本则静默退出
fn fnAutoCheckVersion currentVer manifestUrl =
(
    if not (internet.CheckConnection url:"https://gitee.com" force:true) then
        return undefined

    local manifest = fnFetchManifest manifestUrl
    if manifest == undefined then return undefined
    if manifest.version == currentVer then return undefined

    -- 检查用户是否跳过了该版本
    if (fnGetSkipVersion()) == manifest.version then
    (
        format "[BsKeyTools] 跳过版本 %（用户已选择跳过）\n" manifest.version
        return undefined
    )

    -- 有更新且未跳过，复用 fnCheckUpdate 的弹窗逻辑
    fnCheckUpdate currentVer manifestUrl
)
```

- [ ] **Step 2: 在 Max Listener 验证 JSON 解析**

先确保 manifest.json 已推送到 Gitee 可访问，然后：

```maxscript
fileIn ((getDir #scripts) + "\\BulletScripts\\fnCheckUpdate.ms")

local testJson = "{\"version\":\"2.0.0\",\"requireReinstall\":false,\"releaseNote\":\"测试\",\"baseUrl\":\"https://example.com/\",\"files\":[{\"path\":\"BulletScripts/BsBipedTools.ms\",\"since\":\"2.0.0\",\"size\":12345}],\"installer\":{\"url\":\"https://example.com/a.exe\",\"fallbackUrl\":\"https://example.com/guide\"}}"

local m = fnParseManifest testJson
print m.version          -- 应输出 "2.0.0"
print m.requireReinstall -- 应输出 false
print m.files.count      -- 应输出 1
print m.files[1].path    -- 应输出 "BulletScripts/BsBipedTools.ms"
print m.files[1].since   -- 应输出 "2.0.0"
print m.files[1].size    -- 应输出 12345
print m.installerUrl     -- 应输出 "https://example.com/a.exe"
```

- [ ] **Step 3: 验证 manifest 拉取（需要 manifest.json 已在 Gitee 上）**

```maxscript
fileIn ((getDir #scripts) + "\\BulletScripts\\fnCheckUpdate.ms")
local m = fnFetchManifest "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/manifest.json"
if m != undefined then (
    print m.version
    print m.files.count
) else (
    print "拉取失败"
)
```

期望：输出 `"2.0.0"` 和文件数量（约 40）。

- [ ] **Step 4: 提交**

```bash
git add "_BsKeyTools/Scripts/BulletScripts/fnCheckUpdate.ms"
git commit -m "feat: rewrite fnCheckUpdate.ms with manifest-based incremental update"
```

---

## Task 5: 更新 BulletKeyTools.ms

**Files:**
- Modify: `_BsKeyTools/Scripts/BulletScripts/BulletKeyTools.ms`

- [ ] **Step 1: 更新 manifest URL 全局变量（第 30 行附近）**

将：
```maxscript
global verUrlBsKeyTools  = "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/version.dat"
```

改为：
```maxscript
global manifestUrlBsKeyTools = "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/manifest.json"
```

同时将版本号第 29 行：
```maxscript
global curVerBsKeyTools  = "1.3.7"
```
改为：
```maxscript
global curVerBsKeyTools  = "2.0.0"
```

- [ ] **Step 2: 在 fnCheckUpdate.ms 的 FileIn 之前，添加 fnUpdater.ms 的 FileIn（第 64 行附近）**

现有代码（第 61-65 行）：
```maxscript
try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnSaveLoadConfig.ms"))
catch(...)
stLoadConfigAll.fnLoadConfigBsKeyToolsAll()
try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnCheckUpdate.ms"))
catch(...)
```

改为：
```maxscript
try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnSaveLoadConfig.ms"))
catch(try(massagebox (getCurrentException()));catch();messagebox "加载配置失败，\r\n\r\n建议查看设置中的帮助或重新安装，还有问题烦请联系我...                            " beep:false title:"BsKeyTools")
stLoadConfigAll.fnLoadConfigBsKeyToolsAll()
try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnUpdater.ms"))
catch(try(massagebox (getCurrentException()));catch();messagebox "打开 fnUpdater.ms 失败，可能脚本错误或安装不完全，\r\n\r\n建议查看设置中的帮助或重新安装，还有问题烦请联系我...                            " beep:false title:"BsKeyTools")
try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnCheckUpdate.ms"))
catch(try(massagebox (getCurrentException()));catch();messagebox "打开 fnCheckUpdate.ms 失败，可能脚本错误或安装不完全，\r\n\r\n建议查看设置中的帮助或重新安装，还有问题烦请联系我...                            " beep:false title:"BsKeyTools")
```

- [ ] **Step 3: 更新手动检查更新的调用（第 1834 行附近）**

将：
```maxscript
on mItemCheckUpdate picked do 
(fnCheckUpdate curVerBsKeyTools verUrlBsKeyTools dlUrlBsKeyTools dlFileBsKeyTools isForceUpdate:false)
```

改为：
```maxscript
on mItemCheckUpdate picked do 
(fnCheckUpdate curVerBsKeyTools manifestUrlBsKeyTools)
```

- [ ] **Step 4: 更新强制检查的调用（第 1837 行附近）**

将：
```maxscript
on mItemForceUpdate picked do 
(fnCheckUpdate curVerBsKeyTools verUrlBsKeyTools dlUrlBsKeyTools dlFileBsKeyTools isForceUpdate:true)
```

改为：
```maxscript
on mItemForceUpdate picked do 
(fnCheckUpdate curVerBsKeyTools manifestUrlBsKeyTools)
```

（新版本 `fnCheckUpdate` 始终检查远端，不需要 `isForceUpdate` 参数。）

- [ ] **Step 5: 更新启动时自动检查的调用（第 3772 行附近）**

将：
```maxscript
if (iniBsAutoCheckUpdate == true) then 
(fnAutoCheckVersion curVerBsKeyTools verUrlBsKeyTools dlUrlBsKeyTools dlFileBsKeyTools)
```

改为：
```maxscript
if (iniBsAutoCheckUpdate == true) then 
(fnAutoCheckVersion curVerBsKeyTools manifestUrlBsKeyTools)
```

- [ ] **Step 6: 端到端手动测试**

重启 Max，在 Listener 运行：
```maxscript
-- 临时把本地版本改低，触发更新弹窗
global curVerBsKeyTools = "1.3.7"
fnCheckUpdate curVerBsKeyTools manifestUrlBsKeyTools
```

期望：弹出「发现新版本 2.0.0」对话框，点「是」后下载文件，弹出完成提示。

- [ ] **Step 7: 验证「已是最新」情况**

```maxscript
global curVerBsKeyTools = "2.0.0"
fnCheckUpdate curVerBsKeyTools manifestUrlBsKeyTools
```

期望：弹出「已是最新版本：2.0.0」提示框。

- [ ] **Step 8: 验证「跳过此版本」**

```maxscript
global curVerBsKeyTools = "1.3.7"
-- 第一次：点取消（跳过此版本）
fnCheckUpdate curVerBsKeyTools manifestUrlBsKeyTools
-- 第二次：自动检查，应静默不弹窗
fnAutoCheckVersion curVerBsKeyTools manifestUrlBsKeyTools
```

期望：第二次调用无弹窗，Listener 输出 `[BsKeyTools] 跳过版本 2.0.0（用户已选择跳过）`。

- [ ] **Step 9: 提交**

```bash
git add "_BsKeyTools/Scripts/BulletScripts/BulletKeyTools.ms"
git commit -m "feat: wire up manifest-based update in BulletKeyTools.ms (v2.0.0)"
```

---

## Task 6: 更新 manifest.json 中的实际文件大小

> 此 Task 在 Task 3-5 完成、所有脚本文件最终定稿后执行。

**Files:**
- Modify: `_BsKeyTools/manifest.json`

- [ ] **Step 1: 在 Max 中（已安装最新版本的机器上）运行以下脚本**

```maxscript
-- 生成 manifest files 数组（带实际大小），复制输出结果
local scriptsDir = getDir #scripts
local files = #(
    "BulletScripts/BsAnimDemoTools.ms",
    "BulletScripts/BsBatchRescaleWU.ms",
    "BulletScripts/BsBipedTools.ms",
    "BulletScripts/BsBoxMan.ms",
    "BulletScripts/BsCleanVirus.ms",
    "BulletScripts/BsFnKeys.ms",
    "BulletScripts/BsKeyStepMode.ms",
    "BulletScripts/BsLayerManager.ms",
    "BulletScripts/BsOpenTools.ms",
    "BulletScripts/BsOpenToolsPy.ms",
    "BulletScripts/BsQuickSave.ms",
    "BulletScripts/BsRefTools.ms",
    "BulletScripts/BsResetConfig.ms",
    "BulletScripts/BsRetargetTools.ms",
    "BulletScripts/BsRootMotionTools.ms",
    "BulletScripts/BsScriptHub.ms",
    "BulletScripts/BsScriptMenu.ms",
    "BulletScripts/BsScriptMenuMacro.ms",
    "BulletScripts/BsScriptsSet.ms",
    "BulletScripts/BsSelSetTools.ms",
    "BulletScripts/BsSwitchBtnString.ms",
    "BulletScripts/BsTogglePanel.ms",
    "BulletScripts/BsTrackBarTools.ms",
    "BulletScripts/BsVportTools.ms",
    "BulletScripts/BulletKeyTools.ms",
    "BulletScripts/fnCheckUpdate.ms",
    "BulletScripts/fnFileAndDirIO.ms",
    "BulletScripts/fnGetColorTheme.ms",
    "BulletScripts/fnSaveLoadConfig.ms",
    "BulletScripts/fnSelectKeys.ms",
    "BulletScripts/fnSetFps.ms",
    "BulletScripts/fnSetPlaybackSpeed.ms",
    "BulletScripts/fnUpdater.ms",
    "BulletScripts/stLangManager.ms",
    "BulletScripts/BsAnimLib.py",
    "BulletScripts/BsOpenToolsPy_PySide2.py",
    "BulletScripts/BsOpenToolsPy_PySide6.py",
    "BulletScripts/BsScriptHub.py",
    "BulletScripts/Lang/CHS.lng",
    "BulletScripts/Lang/ENG.lng"
)
clearListener()
for f in files do
(
    local fullPath = scriptsDir + "\\" + (substituteString f "/" "\\")
    local sz = if doesFileExist fullPath then (getFileSize fullPath) else 0
    format "    { \"path\": \"%\", \"since\": \"???\", \"size\": % },\n" f sz
)
```

- [ ] **Step 2: 将输出中的 size 值更新到 manifest.json**

保持每个文件的 `since` 值不变，只更新 `size` 字段。

- [ ] **Step 3: 提交**

```bash
git add _BsKeyTools/manifest.json
git commit -m "chore: update manifest.json with accurate file sizes"
```

---

## 发版流程备忘（写给自己）

每次发版时的操作：

```
1. 修改代码文件
2. 更新 manifest.json：
   - version 字段改为新版本号
   - 修改过的文件的 since 改为新版本号
   - requireReinstall 按需设为 true/false
   - releaseNote 写更新说明
   - 如有大小变化较多，重跑 Task 6 更新 size
3. 更新 BulletKeyTools.ms 第 29 行 curVerBsKeyTools
4. 如果需要重新打包 exe：更新 Setup_BsKeyTools.nsi 第 9 行 PRODUCT_VERSION_NUM
5. git push dev → PR → merge main
6. GitHub Actions 自动同步到 Gitee
7. 用户下次打开 Max 自动收到提示
```
