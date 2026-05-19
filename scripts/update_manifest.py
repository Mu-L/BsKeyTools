#!/usr/bin/env python3
"""
update_manifest.py — BsKeyTools manifest.json 自动更新脚本
运行时机：GitHub Actions push-to-main workflow 中，git commit 之前
功能：
  1. 从 BulletKeyTools.ms 读取当前版本号（curVerBsKeyTools）
  2. 扫描 _BsKeyTools/Scripts/ 下的受管文件
  3. 通过 git diff 找出本次 push 变动的文件 → since = 当前版本
  4. 未变动的文件保留 manifest 中已有的 since
  5. 重新计算文件大小（LF 字节数，与 Gitee raw 一致）
  6. 若变动中含 .dlm 文件 → 自动设置 requireReinstall = true
  7. releaseNote 保留现有值（开发者自行填写后 push）
  8. 更新 version.dat（兼容 v1.3.7 旧客户端检测版本变更）
  9. 更新 NSIS installer 版本号（如有需要）
  10. 写回 manifest.json
"""

import json
import hashlib
import os
import re
import subprocess
import sys

# ── 路径配置 ──────────────────────────────────────────────────────────
REPO_ROOT      = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST_PATH  = os.path.join(REPO_ROOT, "_BsKeyTools", "manifest.json")
VERSION_DAT    = os.path.join(REPO_ROOT, "_BsKeyTools", "version.dat")
MAIN_MS        = os.path.join(REPO_ROOT, "_BsKeyTools", "Scripts", "BulletScripts", "BulletKeyTools.ms")
NSIS_SCRIPT    = os.path.join(REPO_ROOT, "_BsKeyTools", "Setup_BsKeyTools.nsi")
SCRIPTS_BASE   = os.path.join(REPO_ROOT, "_BsKeyTools", "Scripts")
DEFAULT_BASE_URL = "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/Scripts/"
DEFAULT_FALLBACK_BASE_URL = "https://raw.githubusercontent.com/AniBullet/BsKeyTools/main/_BsKeyTools/Scripts/"

# 受管文件列表（相对于 _BsKeyTools/Scripts/，使用正斜杠）
MANAGED_FILES = [
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
    "BulletScripts/Lang/ENG.lng",
    # StartupMS 加载器（安装到 Scripts\BulletScripts\StartupMS\）
    "BulletScripts/StartupMS/BsCleanVirusStartup.ms",
    "BulletScripts/StartupMS/BsCustomScriptsStartup.ms",
    "BulletScripts/StartupMS/BsTrackBarToolsStartup.ms",
    "BulletScripts/StartupMS/BulletKeyTools.ms",
    "BulletScripts/StartupMS/EXTimelineStartup.ms",
    # Startup 启动脚本（安装到 Scripts\Startup\，即 getDir #StartupScripts）
    "Startup/00.ms",
    "Startup/BsCleanVirusStartup.ms",
    "Startup/BsKeyToolsMacro.ms",
    "Startup/BsKeyToolsMenuBar.ms",
    "Startup/BsScriptMenuStartup.ms",
    "Startup/BulletKeyTools.ms",
]


def read_version_from_ms(ms_path: str) -> str:
    """从 BulletKeyTools.ms 中读取 curVerBsKeyTools 的值"""
    with open(ms_path, encoding="utf-8", errors="replace") as f:
        content = f.read()
    m = re.search(r'global\s+curVerBsKeyTools\s*=\s*"([^"]+)"', content)
    if not m:
        raise RuntimeError(f"无法在 {ms_path} 中找到 curVerBsKeyTools")
    return m.group(1)


def validate_release_tag_matches_version(version: str) -> None:
    """在 GitHub tag workflow 中，确保 tag 与脚本内版本一致。"""
    ref_name = os.environ.get("GITHUB_REF_NAME", "")
    if not ref_name.startswith("v"):
        return

    tag_version = ref_name[1:]
    if tag_version != version:
        raise RuntimeError(
            f"release tag 版本不一致: tag={tag_version}, BulletKeyTools.ms={version}"
        )


def get_changed_files_in_scripts() -> set:
    """
    通过 git diff HEAD^ HEAD 获取本次 commit 中变动的文件路径集合。
    返回的路径格式为相对于 repo root 的 POSIX 路径（正斜杠）。
    """
    changed = set()
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD^", "HEAD"],
            capture_output=True, text=True, check=True, cwd=REPO_ROOT
        )
        changed.update(result.stdout.strip().splitlines())
    except subprocess.CalledProcessError:
        # 首次 commit 或无历史时 fallback：视所有文件为变动
        print("[update_manifest] 警告：git diff 失败（可能是首次 commit），视所有受管文件为变动")
        return None

    if os.environ.get("UPDATE_MANIFEST_INCLUDE_WORKTREE") == "1":
        for args in (
            ["git", "diff", "--name-only", "HEAD"],
            ["git", "diff", "--name-only", "--cached"],
        ):
            result = subprocess.run(
                args,
                capture_output=True,
                text=True,
                check=True,
                cwd=REPO_ROOT,
            )
            changed.update(result.stdout.strip().splitlines())

    return changed


def file_lf_size(file_path: str) -> int:
    """
    计算文件以 LF 行尾存储时的字节数。
    在 Ubuntu CI 上文件已是 LF，直接返回实际大小；
    但为保险起见，统一做 LF 归一化计算。
    """
    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"受管文件不存在: {file_path}")
    try:
        with open(file_path, "rb") as f:
            raw = f.read()
        # 将 CRLF → LF 后计算大小
        normalized = raw.replace(b"\r\n", b"\n")
        return len(normalized)
    except OSError as exc:
        raise RuntimeError(f"无法读取受管文件: {file_path}") from exc


def file_lf_sha256(file_path: str) -> str:
    """计算文件以 LF 行尾存储时的 SHA-256。"""
    if not os.path.isfile(file_path):
        raise FileNotFoundError(f"受管文件不存在: {file_path}")
    try:
        with open(file_path, "rb") as f:
            raw = f.read()
        normalized = raw.replace(b"\r\n", b"\n")
        return hashlib.sha256(normalized).hexdigest()
    except OSError as exc:
        raise RuntimeError(f"无法读取受管文件: {file_path}") from exc


def load_existing_manifest(manifest_path: str) -> dict:
    """读取现有 manifest.json，返回 dict；文件不存在则返回空结构"""
    if not os.path.isfile(manifest_path):
        return {"files": []}
    with open(manifest_path, encoding="utf-8") as f:
        return json.load(f)


def build_existing_since_map(existing: dict) -> dict:
    """从现有 manifest 中建立 path -> since 的映射"""
    result = {}
    for item in existing.get("files", []):
        result[item["path"]] = item.get("since", "1.0.0")
    return result


def validate_release_note_for_maxscript(release_note: str) -> None:
    """当前 MaxScript 轻量 JSON 解析器不支持 JSON 字符串转义。"""
    blocked = ['"', "\\", "\r", "\n"]
    if any(ch in release_note for ch in blocked):
        raise RuntimeError('releaseNote 含 MaxScript 解析器不支持的字符: " \\ 或换行')


def detect_requires_reinstall(changed_files: set) -> bool:
    """若变动文件包含 .dlm 文件则需要重装"""
    if changed_files is None:
        return False
    return any(f.endswith(".dlm") for f in changed_files)


def default_installer(version: str) -> dict:
    return {
        "url": f"https://gitee.com/acebullet/BsKeyTools/releases/download/v{version}/BsKeyTools_v{version}.exe",
        "fallbackUrl": f"https://github.com/AniBullet/BsKeyTools/releases/download/v{version}/BsKeyTools_v{version}.exe",
    }


def build_manifest(
    version: str,
    changed_scripts: set,
    existing: dict,
    requires_reinstall: bool,
) -> dict:
    since_map = build_existing_since_map(existing)
    release_note = existing.get("releaseNote", "")
    validate_release_note_for_maxscript(release_note)

    new_files = []
    for rel_path in MANAGED_FILES:
        abs_path = os.path.join(SCRIPTS_BASE, rel_path.replace("/", os.sep))
        size = file_lf_size(abs_path)
        sha256 = file_lf_sha256(abs_path)

        if rel_path in changed_scripts:
            since = version
        else:
            since = since_map.get(rel_path, version)

        new_files.append(
            {"path": rel_path, "since": since, "size": size, "sha256": sha256}
        )

    return {
        "version": version,
        "requireReinstall": requires_reinstall,
        "releaseNote": release_note,
        "baseUrl": existing.get("baseUrl", DEFAULT_BASE_URL),
        "fallbackBaseUrl": existing.get("fallbackBaseUrl", DEFAULT_FALLBACK_BASE_URL),
        "files": new_files,
        "installer": default_installer(version),
    }


def update_version_dat(version: str) -> None:
    """写入 version.dat（兼容旧版 1.3.7 客户端检测更新）"""
    with open(VERSION_DAT, "w", encoding="utf-8", newline="\n") as f:
        f.write(version)
    print(f"[update_manifest] version.dat 已更新为: {version}")


def update_nsis_version(version: str) -> None:
    """更新 NSIS 脚本中的 PRODUCT_VERSION_NUM（如文件存在）"""
    if not os.path.isfile(NSIS_SCRIPT):
        return
    with open(NSIS_SCRIPT, encoding="utf-8", errors="replace") as f:
        content = f.read()
    new_content = re.sub(
        r'(!define\s+PRODUCT_VERSION_NUM\s+")[^"]*(")',
        lambda m: m.group(1) + version + m.group(2),
        content
    )
    if new_content != content:
        with open(NSIS_SCRIPT, "w", encoding="utf-8", newline="\n") as f:
            f.write(new_content)
        print(f"[update_manifest] Setup_BsKeyTools.nsi PRODUCT_VERSION_NUM → {version}")


def validate_manifest_sizes(manifest: dict) -> None:
    """确认 manifest 中的 size / sha256 与本地文件的 LF 内容一致。"""
    errors = []
    for item in manifest.get("files", []):
        rel_path = item.get("path")
        expected_size = item.get("size")
        expected_sha256 = item.get("sha256")
        abs_path = os.path.join(SCRIPTS_BASE, rel_path.replace("/", os.sep))
        actual_size = file_lf_size(abs_path)
        actual_sha256 = file_lf_sha256(abs_path)
        if expected_size != actual_size:
            errors.append(f"{rel_path}: manifest={expected_size}, actual={actual_size}")
        if expected_sha256 != actual_sha256:
            errors.append(f"{rel_path}: sha256 mismatch")

    if errors:
        details = "\n  ".join(errors)
        raise RuntimeError(f"manifest 校验失败:\n  {details}")


def main():
    print("[update_manifest] 开始更新 manifest.json ...")

    # 1. 读取当前版本号
    version = read_version_from_ms(MAIN_MS)
    validate_release_tag_matches_version(version)
    print(f"[update_manifest] 当前版本: {version}")

    # 2. 获取变动文件集合（相对于 repo root 的路径）
    changed_repo_paths = get_changed_files_in_scripts()

    # 将变动路径转换为「相对于 _BsKeyTools/Scripts/」的格式，方便匹配 MANAGED_FILES
    scripts_prefix = "_BsKeyTools/Scripts/"  # repo root 相对路径前缀（正斜杠）
    if changed_repo_paths is not None:
        changed_scripts = {
            p[len(scripts_prefix):].replace("\\", "/")
            for p in changed_repo_paths
            if p.replace("\\", "/").startswith(scripts_prefix)
        }
    else:
        changed_scripts = set(MANAGED_FILES)  # fallback：全部视为变动

    print(f"[update_manifest] 本次变动的受管文件: {changed_scripts or '(无)'}")

    # 3. 读取现有 manifest（保留 since 和 releaseNote）
    existing = load_existing_manifest(MANIFEST_PATH)

    # 4. 检测是否需要重装
    requires_reinstall = detect_requires_reinstall(changed_repo_paths)
    if requires_reinstall:
        print("[update_manifest] 检测到 .dlm 文件变动，requireReinstall = true")

    # 5. 组装新 manifest
    new_manifest = build_manifest(version, changed_scripts, existing, requires_reinstall)

    # 7. 写回 manifest.json（LF 行尾，UTF-8，缩进 2）
    with open(MANIFEST_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(new_manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")  # 文件末尾换行
    print(
        f"[update_manifest] manifest.json 已更新: "
        f"version={version}, files={len(new_manifest['files'])}"
    )

    validate_manifest_sizes(new_manifest)
    print("[update_manifest] manifest size 校验通过")

    # 8. 更新 version.dat（兼容旧客户端）
    update_version_dat(version)

    # 9. 更新 NSIS 版本号
    update_nsis_version(version)

    print("[update_manifest] 完成 OK")


if __name__ == "__main__":
    main()
