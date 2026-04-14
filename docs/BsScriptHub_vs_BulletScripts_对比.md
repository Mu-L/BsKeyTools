# BsScriptHub 与 BulletScripts 脚本对比分析

## 概述

本项目包含两套脚本管理系统，它们有不同的定位和用途：

| 系统 | 定位 | 管理方式 |
|------|------|----------|
| **BulletScripts** | 核心工具集 (本地) | 随 BsKeyTools 安装，本地运行 |
| **BsScriptHub** | 远程脚本平台 | 从 GitHub 下载，按需获取 |

---

## 目录结构

### BulletScripts (核心工具)
```
_BsKeyTools/Scripts/BulletScripts/
├── BulletKeyTools.ms          # 主程序入口 (5014行)
├── BsScriptHub.py             # 远程脚本管理器
├── BsScriptHub.ms             # 远程脚本管理器启动器
├── Bs*.ms                     # 各功能模块
├── fn*.ms                     # 公共函数库
├── st*.ms                     # 结构体定义
├── Quote/                     # 第三方/引用脚本
├── Icons/                     # 图标资源
├── Lang/                      # 多语言文件
├── Res/                       # 资源文件
├── ScanVirus/                 # 病毒特征库
└── StartupMS/                 # 可选启动脚本
```

### BsScriptHub (远程脚本仓库)
```
_BsKeyTools/Scripts/BsScriptHub/
├── scripts_index.json         # 脚本索引文件
├── generate_index.py          # 索引生成工具
├── 01_选择工具/
├── 02_建模工具/
├── 03_材质工具/
├── 04_动画工具/
├── 05_骨骼绑定/
├── 06_场景管理/
├── 07_导入导出/
├── 08_镜头相关/
├── 09_蒙皮权重/
├── 10_特效渲染/
├── 11_开发工具/
├── 98_动作逆向/
└── 99_测试工具/
```

---

## BulletScripts 脚本清单

### 主程序与核心模块

| 脚本路径 | 功能描述 |
|----------|----------|
| `BulletScripts/BulletKeyTools.ms` | **主程序** - BsKeyTools 核心界面和功能 |
| `BulletScripts/BsScriptHub.py` | 远程脚本管理平台 (PySide2/6) |
| `BulletScripts/BsScriptHub.ms` | BsScriptHub 启动器 |
| `BulletScripts/BsAnimLib.py` | 动画库工具 |
| `BulletScripts/BsBipedTools.ms` | Biped 骨骼工具 |
| `BulletScripts/BsBoxMan.ms` | 盒子人工具 |
| `BulletScripts/BsCleanVirus.ms` | 病毒清理工具 |
| `BulletScripts/BsFnKeys.ms` | 功能键工具 |
| `BulletScripts/BsKeyStepMode.ms` | 关键帧步进模式 |
| `BulletScripts/BsLayerManager.ms` | 图层管理器 |
| `BulletScripts/BsOpenTools.ms` | 打开工具集 |
| `BulletScripts/BsQuickSave.ms` | 快速保存 |
| `BulletScripts/BsRefTools.ms` | 参考工具 |
| `BulletScripts/BsResetConfig.ms` | 重置配置 |
| `BulletScripts/BsRetargetTools.ms` | 重定向工具 |
| `BulletScripts/BsRootMotionTools.ms` | 根运动工具 |
| `BulletScripts/BsScriptMenu.ms` | 脚本菜单 |
| `BulletScripts/BsScriptsSet.ms` | 脚本集设置 |
| `BulletScripts/BsSelSetTools.ms` | 选择集工具 |
| `BulletScripts/BsTogglePanel.ms` | 面板切换 |
| `BulletScripts/BsTrackBarTools.ms` | 时间轴工具 |
| `BulletScripts/BsVportTools.ms` | 视口工具 |
| `BulletScripts/BsBatchRescaleWU.ms` | 批量缩放世界单位 |
| `BulletScripts/BsAnimDemoTools.ms` | 动画演示工具 |

### 公共函数库

| 脚本路径 | 功能描述 |
|----------|----------|
| `BulletScripts/fnCheckUpdate.ms` | 检查更新 |
| `BulletScripts/fnFileAndDirIO.ms` | 文件目录操作 |
| `BulletScripts/fnGetColorTheme.ms` | 获取颜色主题 |
| `BulletScripts/fnSaveLoadConfig.ms` | 配置保存加载 |
| `BulletScripts/fnSelectKeys.ms` | 选择关键帧 |
| `BulletScripts/fnSetFps.ms` | 设置帧率 |
| `BulletScripts/fnSetPlaybackSpeed.ms` | 设置播放速度 |
| `BulletScripts/stLangManager.ms` | 语言管理器 |
| `BulletScripts/BsSwitchBtnString.ms` | 按钮文字切换 |

### Quote 目录 (第三方/引用脚本)

| 脚本路径 | 功能描述 |
|----------|----------|
| `Quote/Anim_mirror.ms` | 动画镜像 |
| `Quote/AnimaRange.ms` | 动画范围工具 |
| `Quote/BakeAnim.ms` | 烘焙动画 |
| `Quote/Bone_Tools.ms` | 骨骼工具 |
| `Quote/CPTools_New.ms` | 动画复制粘贴 |
| `Quote/ChainsTools.ms` | 链条工具 |
| `Quote/ChangeSkinBones.ms` | 修改蒙皮骨骼 |
| `Quote/Collider.ms` | 碰撞器工具 |
| `Quote/DTrajEdit_New.ms` | 轨迹编辑器 |
| `Quote/DarkScintilla.mzp` | 暗黑代码编辑器 |
| `Quote/FractureVoronoi.ms` | Voronoi破碎 |
| `Quote/ImageCompHelper.ms` | 构图辅助工具 |
| `Quote/LayerManagerAlternative.ms` | 图层管理替代版 |
| `Quote/LightTable.ms` | 灯光台 |
| `Quote/MassFX.ms` | MassFX物理工具 |
| `Quote/MorphSliders_11.ms` | 变形滑块 |
| `Quote/P_ObjectRenamer.ms` | 对象批量重命名 |
| `Quote/P_SkinWeightTool.ms` | 蒙皮权重工具 |
| `Quote/ProColor.ms` | 专业颜色工具 |
| `Quote/ProTrajectoryHandles.ms` | 专业轨迹控制 |
| `Quote/RescaleWU.ms` | 世界单位缩放 |
| `Quote/Rigging_CombineSkin.ms` | 合并蒙皮 |
| `Quote/RolloutBuilder.ms` | Rollout构建器 |
| `Quote/Show.NetProperty.ms` | .NET属性查看器 |
| `Quote/SkinTools.ms` | 蒙皮工具集 |
| `Quote/SpringMagic_Enhanced.ms` | 飘带解算增强版 |
| `Quote/TweenMachine.ms` | 补间动画工具 |
| `Quote/UILayout_V1.01_HPK.ms` | UI布局工具 |
| `Quote/WinBox.ms` | 窗口工具箱 |
| `Quote/Xr_SkinTool.ms` | XR蒙皮工具 |
| `Quote/alexanimalign_0.ms` | 动画对齐工具 |
| `Quote/cstools.ms` | CS工具集 |
| `Quote/lod_creator.ms` | LOD创建器 |
| `Quote/mirrormorph.ms` | 镜像变形 |
| `Quote/nestedLayerManager.mzp` | 嵌套图层管理 |
| `Quote/objectPicker.ms` | 对象选择器 |
| `Quote/pxMorphSliders.ms` | 变形滑块 |
| `Quote/simple_hwnd_viewer.ms` | 窗口句柄查看器 |
| `Quote/Batch Import Convert.ms` | 批量导入转换 |
| `Quote/Batch version down.ms` | 批量降版本 |

---

## BsScriptHub 脚本清单 (远程仓库)

### 01_选择工具
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| InvertSelection | `BsScriptHub/01_选择工具/InvertSelection.ms` | 独立脚本 |
| SelectByName | `BsScriptHub/01_选择工具/SelectByName.ms` | 独立脚本 |

### 02_建模工具
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| CenterPivot | `BsScriptHub/02_建模工具/CenterPivot.ms` | 独立脚本 |
| ResetXForm | `BsScriptHub/02_建模工具/ResetXForm.ms` | 独立脚本 |
| LOD创建器 | `BulletScripts/Quote/lod_creator.ms` | **共享** |
| 变形滑块 | `BulletScripts/Quote/pxMorphSliders.ms` | **共享** |
| 镜像变形 | `BulletScripts/Quote/mirrormorph.ms` | **共享** |

### 03_材质工具
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| SelectByMaterial | `BsScriptHub/03_材质工具/SelectByMaterial.ms` | 独立脚本 |

### 04_动画工具
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| BakeAnimation | `BsScriptHub/04_动画工具/BakeAnimation.ms` | 独立脚本 |
| DeleteAllKeys | `BsScriptHub/04_动画工具/DeleteAllKeys.ms` | 独立脚本 |
| 专业轨迹控制 | `BulletScripts/Quote/ProTrajectoryHandles.ms` | **共享** |
| 动画复制粘贴 | `BulletScripts/Quote/CPTools_New.ms` | **共享** |
| 动画对齐工具 | `BulletScripts/Quote/alexanimalign_0.ms` | **共享** |
| 动画范围工具 | `BulletScripts/Quote/AnimaRange.ms` | **共享** |
| 动画镜像 | `BulletScripts/Quote/Anim_mirror.ms` | **共享** |
| 烘焙动画 | `BulletScripts/Quote/BakeAnim.ms` | **共享** |
| 补间动画工具 | `BulletScripts/Quote/TweenMachine.ms` | **共享** |
| 轨迹编辑器 | `BulletScripts/Quote/DTrajEdit_New.ms` | **共享** |

### 05_骨骼绑定
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| SelectAllBones | `BsScriptHub/05_骨骼绑定/SelectAllBones.ms` | 独立脚本 |
| 蒙皮飞点检查 | `BsScriptHub/05_骨骼绑定/SkinIslandChecker.ms` | 独立脚本 |
| 弹簧控制器 | `BulletScripts/Quote/springcontroller.ms` | **共享** |
| 扭曲骨骼 | `BulletScripts/Quote/twistbones.ms` | **共享** |
| 链条工具 | `BulletScripts/Quote/ChainsTools.ms` | **共享** |
| 飘带解算 | `BulletScripts/Quote/飘带解算.mse` | **共享** |
| 飘带解算增强版 | `BulletScripts/Quote/SpringMagic_Enhanced.ms` | **共享** |
| 骨骼工具 | `BulletScripts/Quote/Bone_Tools.ms` | **共享** |

### 06_场景管理
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| CleanScene | `BsScriptHub/06_场景管理/CleanScene.ms` | 独立脚本 |
| PrintSceneInfo | `BsScriptHub/06_场景管理/PrintSceneInfo.ms` | 独立脚本 |
| 专业颜色工具 | `BulletScripts/Quote/ProColor.ms` | **共享** |
| 图层管理替代版 | `BulletScripts/Quote/LayerManagerAlternative.ms` | **共享** |
| 对象批量重命名 | `BulletScripts/Quote/P_ObjectRenamer.ms` | **共享** |
| 对象选择器 | `BulletScripts/Quote/objectPicker.ms` | **共享** |
| 嵌套图层管理 | `BulletScripts/Quote/nestedLayerManager.mzp` | **共享** |

### 07_导入导出
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| ExportSelectedFBX | `BsScriptHub/07_导入导出/ExportSelectedFBX.ms` | 独立脚本 |
| 批量导入转换 | `BulletScripts/Quote/Batch Import Convert.ms` | **共享** |
| 批量降版本 | `BulletScripts/Quote/Batch version down.ms` | **共享** |

### 08_镜头相关
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| 构图辅助工具 | `BulletScripts/Quote/ImageCompHelper.ms` | **共享** |

### 09_蒙皮权重
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| XR蒙皮工具 | `BulletScripts/Quote/Xr_SkinTool.ms` | **共享** |
| 修改蒙皮骨骼 | `BulletScripts/Quote/ChangeSkinBones.ms` | **共享** |
| 合并蒙皮 | `BulletScripts/Quote/Rigging_CombineSkin.ms` | **共享** |
| 替换蒙皮骨骼 | `BulletScripts/Quote/sox_replacebonefromskin.ms` | **共享** |
| 权重分区平滑 | `BulletScripts/Quote/权重分区平滑.ms` | **共享** |
| 蒙皮工具集 | `BulletScripts/Quote/SkinTools.ms` | **共享** |
| 蒙皮权重工具 | `BulletScripts/Quote/P_SkinWeightTool.ms` | **共享** |

### 10_特效渲染
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| MassFX物理工具 | `BulletScripts/Quote/MassFX.ms` | **共享** |
| Voronoi破碎 | `BulletScripts/Quote/FractureVoronoi.ms` | **共享** |
| 参考大师 | `BulletScripts/Quote/参考大师.mse` | **共享** |
| 多方向渲染工具 | `BulletScripts/Quote/多方向渲染工具（集成修改版）.ms` | **共享** |
| 灯光台 | `BulletScripts/Quote/LightTable.ms` | **共享** |
| 碰撞器工具 | `BulletScripts/Quote/Collider.ms` | **共享** |

### 11_开发工具
| 脚本名 | 路径 | 来源 |
|--------|------|------|
| .NET属性查看器 | `BulletScripts/Quote/Show.NetProperty.ms` | **共享** |
| CS工具集 | `BulletScripts/Quote/cstools.ms` | **共享** |
| Rollout构建器 | `BulletScripts/Quote/RolloutBuilder.ms` | **共享** |
| UI布局工具 | `BulletScripts/Quote/UILayout_V1.01_HPK.ms` | **共享** |
| 世界单位缩放 | `BulletScripts/Quote/RescaleWU.ms` | **共享** |
| 暗黑代码编辑器 | `BulletScripts/Quote/DarkScintilla.mzp` | **共享** |
| 窗口句柄查看器 | `BulletScripts/Quote/simple_hwnd_viewer.ms` | **共享** |
| 窗口工具箱 | `BulletScripts/Quote/WinBox.ms` | **共享** |

### 98_动作逆向 (BsScriptHub 独有)
| 脚本名 | 路径 |
|--------|------|
| ActorX 导入器 | `BsScriptHub/98_动作逆向/ActorXImporter_BulletS.ms` |
| 鬼泣5动画导出 | `BsScriptHub/98_动作逆向/DMC5_Export_BulletS.ms` |
| ActorX 批量转FBX | `BsScriptHub/98_动作逆向/ExportFBX_BulletS.ms` |
| Havok 动画导出 | `BsScriptHub/98_动作逆向/Havok_Export_BulletS.ms` |
| 怪猎崛起曙光导出 | `BsScriptHub/98_动作逆向/MHRS_Export_BulletS.ms` |
| RE引擎动画工具 | `BsScriptHub/98_动作逆向/RE_AnimTools_BulletS.ms` |
| 街霸6动画导出 | `BsScriptHub/98_动作逆向/SF6_Export_BulletS.ms` |
| XnaLara/XPS转换器 | `BsScriptHub/98_动作逆向/XnaLara_Converter.ms` |

### 99_测试工具
| 脚本名 | 路径 |
|--------|------|
| HelloWorld | `BsScriptHub/99_测试工具/HelloWorld.ms` |

---

## 重合分析

### 共享脚本统计

BsScriptHub 中有大量脚本实际上是**引用** `BulletScripts/Quote/` 目录下的脚本：

| 分类 | 独立脚本 | 共享脚本 (引用Quote) |
|------|----------|---------------------|
| 01_选择工具 | 2 | 0 |
| 02_建模工具 | 2 | 3 |
| 03_材质工具 | 1 | 0 |
| 04_动画工具 | 2 | 8 |
| 05_骨骼绑定 | 2 | 6 |
| 06_场景管理 | 2 | 5 |
| 07_导入导出 | 1 | 2 |
| 08_镜头相关 | 0 | 1 |
| 09_蒙皮权重 | 0 | 7 |
| 10_特效渲染 | 0 | 6 |
| 11_开发工具 | 0 | 8 |
| 98_动作逆向 | 8 | 0 |
| 99_测试工具 | 1 | 0 |
| **合计** | **21** | **46** |

### 关键发现

1. **BsScriptHub 大量引用 Quote 目录**
   - 约 **69%** 的 BsScriptHub 脚本实际指向 `BulletScripts/Quote/` 目录
   - 这些脚本在 `scripts_index.json` 中通过 `"script": "BulletScripts/Quote/xxx.ms"` 引用

2. **独立脚本主要在以下分类**
   - 基础工具 (选择、建模、材质、场景管理)
   - 动作逆向工具 (98_动作逆向 全部独立)

3. **完全共享的分类**
   - 08_镜头相关、09_蒙皮权重、10_特效渲染、11_开发工具
   - 这些分类的脚本 100% 来自 Quote 目录

---

## 两套系统的关系

```
┌─────────────────────────────────────────────────────────────────┐
│                        BsKeyTools 项目                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────┐    ┌──────────────────────────────┐   │
│  │    BulletScripts     │    │        BsScriptHub           │   │
│  │    (核心工具集)       │    │      (远程脚本平台)           │   │
│  ├──────────────────────┤    ├──────────────────────────────┤   │
│  │ • BulletKeyTools.ms  │    │ • BsScriptHub.py (管理器)    │   │
│  │   (主程序 5014行)     │    │ • scripts_index.json        │   │
│  │ • Bs*.ms (功能模块)   │    │ • 分类目录 (01-99)           │   │
│  │ • fn*.ms (函数库)     │    │                              │   │
│  │ • Quote/ (第三方脚本) │◄───┤ 大量脚本引用 Quote 目录       │   │
│  └──────────────────────┘    └──────────────────────────────┘   │
│                                                                  │
│  启动流程:                                                        │
│  Startup/BulletKeyTools.ms ──► BulletScripts/BulletKeyTools.ms  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 总结

| 对比项 | BulletScripts | BsScriptHub |
|--------|---------------|-------------|
| **定位** | 核心工具集 | 远程脚本平台 |
| **安装方式** | 随 BsKeyTools 安装 | 按需从 GitHub 下载 |
| **主程序** | BulletKeyTools.ms (5014行) | BsScriptHub.py (2822行) |
| **脚本数量** | ~50+ 核心脚本 | 67 个脚本条目 |
| **独立性** | 完全独立 | 69% 引用 Quote 目录 |
| **更新方式** | 整体更新 | 单脚本独立更新 |
| **版本管理** | 统一版本号 | 每个脚本独立版本 |
| **特色功能** | 主界面、快捷键、配置 | 分类浏览、搜索、预览 |

### 建议

1. **Quote 目录是共享核心** - 维护时需同时考虑两套系统
2. **BsScriptHub 适合扩展** - 新增独立脚本可放入对应分类
3. **动作逆向工具独立** - 98_动作逆向 是 BsScriptHub 独有内容

---

## 版本更新记录

### v1.4 (2026-02-24)

#### 新增功能：目录类型脚本支持

BsScriptHub 现在支持下载包含多个文件的脚本目录（如 `final_auto_animator`）。

**特性：**
- 自动识别目录类型脚本（路径包含子目录结构）
- 递归下载目录内所有文件，保持原始目录结构
- 显示下载进度（当前/总数）
- 支持运行和仅下载两种模式

**目录类型脚本配置示例：**
```json
{
    "name": "自己动动画",
    "script": "BulletScripts/Quote/final_auto_animator/autoAnim_main.ms"
}
```

**技术实现：**
- `DirectoryDownloadWorker`: 新增的异步目录下载器
- `_is_directory_script()`: 判断脚本是否为目录类型
- `_get_directory_local_path()`: 获取目录本地缓存路径
- `_start_directory_download()`: 启动目录下载流程

#### 修复问题

- **UnicodeEncodeError**: 修复在 3ds Max 环境中执行脚本时，异常消息包含中文字符导致的编码错误
- 新增 `_safe_exception_str()` 方法安全处理异常消息

