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
]


def read_version_from_ms(ms_path: str) -> str:
    """从 BulletKeyTools.ms 中读取 curVerBsKeyTools 的值"""
    with open(ms_path, encoding="utf-8", errors="replace") as f:
        content = f.read()
    m = re.search(r'global\s+curVerBsKeyTools\s*=\s*"([^"]+)"', content)
    if not m:
        raise RuntimeError(f"无法在 {ms_path} 中找到 curVerBsKeyTools")
    return m.group(1)


def get_changed_files_in_scripts() -> set:
    """
    通过 git diff HEAD^ HEAD 获取本次 commit 中变动的文件路径集合。
    返回的路径格式为相对于 repo root 的 POSIX 路径（正斜杠）。
    """
    try:
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD^", "HEAD"],
            capture_output=True, text=True, check=True, cwd=REPO_ROOT
        )
        return set(result.stdout.strip().splitlines())
    except subprocess.CalledProcessError:
        # 首次 commit 或无历史时 fallback：视所有文件为变动
        print("[update_manifest] 警告：git diff 失败（可能是首次 commit），视所有受管文件为变动")
        return None


def file_lf_size(file_path: str) -> int:
    """
    计算文件以 LF 行尾存储时的字节数。
    在 Ubuntu CI 上文件已是 LF，直接返回实际大小；
    但为保险起见，统一做 LF 归一化计算。
    """
    if not os.path.isfile(file_path):
        return 0
    try:
        with open(file_path, "rb") as f:
            raw = f.read()
        # 将 CRLF → LF 后计算大小
        normalized = raw.replace(b"\r\n", b"\n")
        return len(normalized)
    except Exception:
        return 0


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


def detect_requires_reinstall(changed_files: set) -> bool:
    """若变动文件包含 .dlm 文件则需要重装"""
    if changed_files is None:
        return False
    return any(f.endswith(".dlm") for f in changed_files)


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


def main():
    print("[update_manifest] 开始更新 manifest.json ...")

    # 1. 读取当前版本号
    version = read_version_from_ms(MAIN_MS)
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
    since_map = build_existing_since_map(existing)
    release_note = existing.get("releaseNote", "")

    # 4. 检测是否需要重装
    requires_reinstall = detect_requires_reinstall(changed_repo_paths)
    if requires_reinstall:
        print("[update_manifest] 检测到 .dlm 文件变动，requireReinstall = true")

    # 5. 构建新的 files 列表
    new_files = []
    for rel_path in MANAGED_FILES:
        abs_path = os.path.join(SCRIPTS_BASE, rel_path.replace("/", os.sep))
        size = file_lf_size(abs_path)

        # 该文件是否在本次 commit 中变动？
        if rel_path in changed_scripts:
            since = version  # 变动 → since = 当前版本
        else:
            since = since_map.get(rel_path, version)  # 未变动 → 保留旧 since

        new_files.append({"path": rel_path, "since": since, "size": size})

    # 6. 组装新 manifest
    new_manifest = {
        "version": version,
        "requireReinstall": requires_reinstall,
        "releaseNote": release_note,
        "baseUrl": existing.get(
            "baseUrl",
            "https://gitee.com/acebullet/BsKeyTools/raw/main/_BsKeyTools/Scripts/"
        ),
        "files": new_files,
        "installer": existing.get("installer", {
            "url": f"https://gitee.com/acebullet/BsKeyTools/releases/download/v{version}/BsKeyTools_v{version}.exe",
            "fallbackUrl": "https://anibullet.github.io/guide/"
        }),
    }

    # 7. 写回 manifest.json（LF 行尾，UTF-8，缩进 2）
    with open(MANIFEST_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(new_manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")  # 文件末尾换行
    print(f"[update_manifest] manifest.json 已更新: version={version}, files={len(new_files)}")

    # 8. 更新 version.dat（兼容旧客户端）
    update_version_dat(version)

    # 9. 更新 NSIS 版本号
    update_nsis_version(version)

    print("[update_manifest] 完成 ✓")


if __name__ == "__main__":
    main()
