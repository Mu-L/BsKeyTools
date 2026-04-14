#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
BsKeyTools 贡献者数据生成工具

功能:
    1. 从 GitHub API 获取代码贡献者列表和头像
    2. 从 README.md 解析社区贡献者名单
    3. 生成 contributors.ini (MaxScript getINISetting 读取)
    4. 生成 contributors.bmp (头像合并图)

使用:
    python download_contributors.py            # 完整模式 (联网+README)
    python download_contributors.py --offline   # 离线模式 (仅解析 README)
"""

import os
import sys
import json
import re
import time
import locale
import urllib.request
import ssl
import io
import subprocess
import argparse

GITHUB_API_URL = "https://api.github.com/repos/AniBullet/BsKeyTools/contributors"
MAX_AVATAR_COUNT = 12
AVATAR_SIZE = 48

DEFAULT_THANKS = [
    "Crazyone", "包包", "东见云", "祥子", "SiChun Yuan", "动画大白",
    "哈库呐玛哒哒", "z.ven 子墨", "一方狂三", "夏奈", "虹", "CG大猫哥",
]


def install_pillow():
    """自动安装 Pillow"""
    print("[INFO] Installing Pillow...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "-q"])
        print("[OK] Pillow installed successfully!")
        return True
    except Exception as e:
        print(f"[FAIL] Failed to install Pillow: {e}")
        return False


def _make_ssl_context():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx


def _make_request(url):
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Mozilla/5.0")
    req.add_header("Accept", "application/vnd.github.v3+json")
    return req


# ---------------------------------------------------------------------------
# 1. GitHub API
# ---------------------------------------------------------------------------
def fetch_github_contributors():
    """从 GitHub API 获取代码贡献者列表，失败返回空列表"""
    print("Fetching contributors from GitHub API...")
    try:
        ctx = _make_ssl_context()
        with urllib.request.urlopen(
            _make_request(GITHUB_API_URL), context=ctx, timeout=30
        ) as resp:
            contributors = json.loads(resp.read().decode("utf-8"))
        print(f"  Found {len(contributors)} code contributors")
        return contributors
    except Exception as e:
        print(f"[WARN] GitHub API failed: {e}")
        return []


def download_avatars(contributors):
    """下载贡献者头像，返回 [(username, bytes), ...]"""
    ctx = _make_ssl_context()
    avatars = []
    total = min(len(contributors), MAX_AVATAR_COUNT)
    for i, c in enumerate(contributors[:total]):
        username = c["login"]
        url = c["avatar_url"] + f"&s={AVATAR_SIZE}"
        print(f"  Downloading [{i+1}/{total}] {username}...", end=" ")
        try:
            with urllib.request.urlopen(
                _make_request(url), context=ctx, timeout=30
            ) as resp:
                avatars.append((username, resp.read()))
            print("[OK]")
        except Exception as e:
            print(f"[FAIL] {e}")
    return avatars


def merge_avatar_bmp(avatars, output_path):
    """合并头像为单张 BMP (MaxScript 友好格式)"""
    if not avatars:
        print("[SKIP] No avatars to merge")
        return False

    try:
        from PIL import Image
    except ImportError:
        print("\n[WARN] Pillow not installed, trying to install...")
        if not install_pillow():
            print("[FAIL] Cannot merge without Pillow")
            return False
        from PIL import Image

    cols = min(len(avatars), 6)
    rows = (len(avatars) + cols - 1) // cols
    gap = 4
    w = cols * AVATAR_SIZE + (cols - 1) * gap
    h = rows * AVATAR_SIZE + (rows - 1) * gap
    merged = Image.new("RGB", (w, h), (45, 45, 45))

    for idx, (username, data) in enumerate(avatars):
        try:
            img = Image.open(io.BytesIO(data)).convert("RGB")
            img = img.resize((AVATAR_SIZE, AVATAR_SIZE), Image.Resampling.LANCZOS)
            col, row = idx % cols, idx // cols
            merged.paste(img, (col * (AVATAR_SIZE + gap), row * (AVATAR_SIZE + gap)))
        except Exception as e:
            print(f"  [WARN] Failed to process {username}: {e}")

    merged.save(output_path, "BMP")
    print(f"\n[OK] Avatar BMP saved: {output_path}  ({w}x{h})")
    return True


# ---------------------------------------------------------------------------
# 2. README 解析
# ---------------------------------------------------------------------------
def find_readme(start_dir):
    """从脚本所在目录向上逐级查找 README.md"""
    current = os.path.abspath(start_dir)
    for _ in range(10):
        candidate = os.path.join(current, "README.md")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent
    return None


def parse_readme_thanks(readme_path):
    """从 README.md 提取 '社区贡献者' 名单 (以 ' · ' 分隔)"""
    if not readme_path:
        return []
    try:
        with open(readme_path, "r", encoding="utf-8") as f:
            content = f.read()
        m = re.search(r"社区贡献者[^\n]*\n+([^\n]*·[^\n]+)", content)
        if m:
            names = [n.strip() for n in m.group(1).split("·") if n.strip()]
            print(f"  Parsed {len(names)} thanks names from README")
            return names
    except Exception as e:
        print(f"[WARN] Failed to parse README: {e}")
    return []


# ---------------------------------------------------------------------------
# 3. INI 生成 (MaxScript getINISetting 兼容)
# ---------------------------------------------------------------------------
def write_contributors_ini(output_path, code_names=None, thanks_names=None):
    """
    生成 contributors.ini (UTF-8 编码)。
    MaxScript 端使用 .NET System.IO.StreamReader 以 UTF-8 读取，
    兼容所有 3ds Max 2014-2026 版本且编辑器显示正常。
    """
    code_names = code_names or []
    thanks_names = thanks_names or []
    enc = "utf-8"

    try:
        with open(output_path, "w", encoding=enc) as f:
            f.write("[Code]\n")
            f.write(f"count={len(code_names)}\n")
            for i, name in enumerate(code_names, 1):
                f.write(f"{i}={name}\n")

            f.write("\n[Thanks]\n")
            f.write(f"count={len(thanks_names)}\n")
            for i, name in enumerate(thanks_names, 1):
                f.write(f"{i}={name}\n")

            f.write(f"\n[Meta]\n")
            f.write(f"updated={time.strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"encoding={enc}\n")

        print(f"\n[OK] INI saved: {output_path}")
        print(f"     Encoding: {enc}")
        print(f"     Code contributors: {len(code_names)}")
        print(f"     Thanks: {len(thanks_names)}")
        return True
    except Exception as e:
        print(f"[FAIL] Failed to write INI: {e}")
        return False


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="BsKeyTools Contributors Data Generator")
    parser.add_argument(
        "--offline",
        action="store_true",
        help="Offline mode: only parse README.md, skip GitHub API & avatar download",
    )
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))

    print("=" * 55)
    print("  BsKeyTools Contributors Data Generator")
    print("=" * 55)
    print()

    # --- README ---
    readme_path = find_readme(script_dir)
    if readme_path:
        print(f"[INFO] README found: {readme_path}")
    else:
        print("[WARN] README.md not found")
    thanks_names = parse_readme_thanks(readme_path)
    if not thanks_names:
        print("[WARN] Using default thanks list")
        thanks_names = list(DEFAULT_THANKS)

    code_names = []

    if not args.offline:
        # --- GitHub API ---
        contributors = fetch_github_contributors()
        code_names = [c["login"] for c in contributors[:MAX_AVATAR_COUNT]]

        # --- Avatar BMP ---
        if contributors:
            avatars = download_avatars(contributors)
            bmp_path = os.path.join(script_dir, "contributors.bmp")
            merge_avatar_bmp(avatars, bmp_path)
    else:
        print("[INFO] Offline mode — skipping GitHub API & avatars")

    # --- INI ---
    ini_path = os.path.join(script_dir, "contributors.ini")
    write_contributors_ini(ini_path, code_names, thanks_names)

    print()
    print("=" * 55)
    print("  Done!")
    print("=" * 55)


if __name__ == "__main__":
    main()
