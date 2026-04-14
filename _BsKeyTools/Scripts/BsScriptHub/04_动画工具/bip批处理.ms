-- ===========================================================================
-- 3dsmax Biped 动画批量导出/导入工具
-- 标题: 3dsmax_bip批处理
-- 作者: CG大猫哥
-- 版本: 1.1
-- 完成时间：2026.2.13
-- 联系作者：873709594@qq.com
-- 功能: 
--   1. 递归扫描文件夹，按关键词过滤 MAX 文件（自动排除 *skin.max）
--   2. 批量导出 Biped 动画为 BIP 文件（支持滑动关键点转自由关键点）
--   3. 批量导入 BIP 动画到蒙皮模板，另存为新的 MAX 文件
--   4. 支持自定义 BIP 源文件夹、手动添加/删除文件、右键重置导出路径等
-- 更新说明：
--   - 统一质心定位策略（父节点undefined + 名称关键词双保险）
--   - 修复隐藏Biped无法导出问题（强制显示所有对象）
--   - 删除所有非必要且易报错的代码（如trackSelection）
--   - 优化处理速度，回归objects集合
--   - 实时读取质心关键词框，支持空格多选、不区分大小写
--   - 增加了z=0
-- ===========================================================================

rollout bip导出 "3dsmax_bip批处理" width:170 height:430
(
    -- #######################################################################
    -- 1. 全局变量声明
    -- #######################################################################
    local 选中的路径 = ""                -- 用户选择的 MAX 文件根目录
    local 导出根路径 = ""               -- 导出时选择的根路径（其下创建 bip 文件夹）
    local 导出根路径已设置 = false      -- 是否已记忆导出根路径（避免重复弹窗）
    local 当前BIP来源路径 = ""          -- 当前使用的 BIP 文件夹路径（默认或自定义）
    local 所有MAX文件路径 = #()         -- 存储待处理 MAX 文件的完整路径数组
    local ui宽度状态 = 0               -- 右侧面板展开状态（0=折叠，1=展开）
    local 调试状态 = 1                -- 自定义模式开关（1=关闭，0=启用）
    local 导入功能状态 = 1            -- 批量导入功能开关（1=关闭，0=启用）
    local 蒙皮文件路径 = ""           -- 用户拾取的蒙皮模板文件完整路径

    -- #######################################################################
    -- 2. 左侧控件（文件列表 + 导出 + BIP来源显示）
    -- #######################################################################
    button 选择路径按钮 "获取MAX文件到列表" width:150 height:30 pos:[10,10]
    edittext 过滤输入框 "过滤词条:" width:150 height:20 pos:[10,50] enabled:false toolTip:"支持多个关键词，按空格键隔开"
    button 遍历文件按钮 "更新列表 (0个文件)" width:150 height:30 pos:[10,80] enabled:false
    listbox 文件列表框 "找到的MAX文件:" width:150 height:15 pos:[10,120] enabled:false
    button 保存路径按钮 "创建Bip文件夹并导出" width:150 height:30 pos:[10,380] enabled:false

    -- 当前BIP来源显示（只读）
    label BIP来源标签 "当前BIP路径:" pos:[10,330] width:80 height:20
    edittext BIP来源显示框 "" width:320 height:20 pos:[10,350] enabled:false

    -- 作者超链接（跳转B站空间）
    hyperLink 签名 "CG大猫哥，用心做好产品" \
        address:"https://space.bilibili.com/603091?spm_id_from=333.1007.0.0" \
        color:(color 255 255 255) \
        hoverColor:(color 200 200 255) \
        visitedColor:(color 220 220 220) \
        pos:[180,195] width:150 height:20

    -- 批量导入功能总开关
    button 导入功能 "批量导入功能(点击)" width:150 height:30 pos:[180,220]

    -- #######################################################################
    -- 3. 右侧控件（调试 + 关键点处理 + 质心关键词 + 蒙皮拾取 + BIP导入）
    -- #######################################################################
    button 调试按钮 "自定义模式(点击)" width:150 height:30 pos:[180,10]

    -- 质心关键词多选框（支持空格多选，不区分大小写）
    edittext 质心关键词多选 "质心名:" width:150 height:20 pos:[180,50] enabled:false toolTip:"支持多个关键词，按空格键隔开"

    -- 手动添加/删除文件（仅在自定义模式下可用）
    button 添加单个文件按钮 "新增文件" width:70 height:30 pos:[180,80] enabled:false
    button 删除选中文件按钮 "删除选中" width:70 height:30 pos:[260,80] enabled:false

    -- 滑动关键点转自由关键点策略选择
	label 关键点处理标签 "滑动关键点=>自由关键点" pos:[180,120] width:140 height:20 enabled:false
    radiobuttons 关键点处理模式 "" \
        labels:#("手脚", "仅手", "不变") \
        columns:3 offsets:#([0,0],[0,0],[0,0]) pos:[180,140] enabled:false

    -- 自定义 BIP 来源设置
    button 使用其他bip文件 "选择其他bip文件路径" width:150 height:30 pos:[180,160] enabled:false
    label 下划线 "最低起脚高度设置" pos:[180,330] enabled:false
	checkbox 最低高度勾选 "Z=0" pos:[280,325] width:150 height:20 enabled:false

    -- 蒙皮模板拾取与显示
    button 拾取蒙皮文件 "拾取蒙皮文件" width:150 height:30 pos:[180,290] enabled:false
    edittext 蒙皮文件显示框 "" width:150 height:20 pos:[180,260] enabled:false

    -- 批量导入执行按钮
    button 批量导入BIP "创建max文件夹并导入" width:150 height:30 pos:[180,380] enabled:false

    -- #######################################################################
    -- 4. 初始化事件
    -- #######################################################################
    on bip导出 open do
    (
        关键点处理模式.state = 3                     -- 默认选择“保留全部（不转换）”
        遍历文件按钮.text = "更新列表 (0个文件)"      -- 初始化按钮文字
    )

    -- #######################################################################
    -- 5. 通用功能函数
    -- #######################################################################

    -- ----------------------------------------------------------------------
    -- 设置左侧控件启用状态（根据是否已选择路径）
    -- ----------------------------------------------------------------------
    fn 设置左侧控件状态 启用标志 =
    (
        过滤输入框.enabled = 启用标志
        遍历文件按钮.enabled = 启用标志
        文件列表框.enabled = 启用标志
        保存路径按钮.enabled = 启用标志
    )

    -- ----------------------------------------------------------------------
    -- 更新 BIP 来源显示框的内容
    -- ----------------------------------------------------------------------
    fn 更新BIP来源显示 =
    (
        if 当前BIP来源路径 == "" then
            BIP来源显示框.text = "未设置"
        else if 导出根路径 != "" and 当前BIP来源路径 == (pathConfig.appendPath 导出根路径 "bip") then
            BIP来源显示框.text = 当前BIP来源路径 + " (默认)"
        else
            BIP来源显示框.text = 当前BIP来源路径 + " (自定义)"
    )

    -- ----------------------------------------------------------------------
    -- 切换“自定义模式”状态
    -- ----------------------------------------------------------------------
    fn 调试按钮状态 调试启用状态 =
    (
        if 调试启用状态 == 1 then
        (
            调试按钮.text = "自定义模式（启用）"
            质心关键词多选.enabled = true 
            使用其他bip文件.enabled = true 
            添加单个文件按钮.enabled = true
            删除选中文件按钮.enabled = true
            关键点处理标签.enabled = true
            关键点处理模式.enabled = true
            调试状态 = 0      -- 记录当前为启用状态
        )
        else
        (
            调试按钮.text = "自定义模式（关闭）"
            质心关键词多选.enabled = false 
            使用其他bip文件.enabled = false 
            添加单个文件按钮.enabled = false
            删除选中文件按钮.enabled = false
            关键点处理标签.enabled = false
            关键点处理模式.enabled = false
            调试状态 = 1      -- 记录当前为关闭状态
        )
    )

    -- ----------------------------------------------------------------------
    -- 切换“批量导入功能”状态
    -- ----------------------------------------------------------------------
    fn 导入功能按钮状态 导入功能启用状态 =
    (
        if 导入功能启用状态 == 1 then
        (
            导入功能.text = "批量导入功能(启用)"
            拾取蒙皮文件.enabled = true 
            批量导入BIP.enabled = true
			最低高度勾选.enabled = true
			下划线.enabled = true
            导入功能状态 = 0      -- 记录当前为启用状态
        )
        else
        (
            导入功能.text = "批量导入功能(关闭)"
            拾取蒙皮文件.enabled = false 
            批量导入BIP.enabled = false
			最低高度勾选.enabled = false
			下划线.enabled = false
            导入功能状态 = 1      -- 记录当前为关闭状态
        )
    )

    -- ----------------------------------------------------------------------
    -- 递归获取指定根目录下所有 .max 文件，自动排除文件名以 "skin" 结尾的文件
    -- ----------------------------------------------------------------------
    fn 递归获取所有MAX文件 根路径 =
    (
        if 根路径 == undefined or 根路径 == "" or not doesDirectoryExist(根路径) do return #()
        local 文件收集列表 = #()
        join 文件收集列表 (getFiles (根路径 + "\\*.max"))
        for 子文件夹 in getDirectories (根路径 + "\\*") do
            join 文件收集列表 (递归获取所有MAX文件 子文件夹)

        local 过滤后列表 = for 文件 in 文件收集列表 \
            where not matchPattern (getFilenameFile 文件) pattern:"*skin" ignoreCase:true \
            collect 文件
        return 过滤后列表
    )

    -- ----------------------------------------------------------------------
    -- 根据过滤输入框中的关键词（空格分隔）对文件列表进行 OR 逻辑过滤
    -- ----------------------------------------------------------------------
    fn 按条件过滤文件 文件列表 =
    (
        local 过滤文本 = 过滤输入框.text
        if 过滤文本 == "" do return 文件列表
        
        local 关键词列表 = filterString 过滤文本 " "
        if 关键词列表.count == 0 do return 文件列表
        
        local 匹配文件列表 = #()
        for 文件 in 文件列表 do
        (
            local 文件名 = getFilenameFile 文件
            for 关键词 in 关键词列表 do
            (
                if matchPattern 文件名 pattern:("*" + 关键词 + "*") ignoreCase:true then
                (
                    append 匹配文件列表 文件
                    exit
                )
            )
        )
        return 匹配文件列表
    )

    -- ----------------------------------------------------------------------
    -- 更新文件列表框的显示内容
    -- ----------------------------------------------------------------------
    fn 更新文件列表 重新扫描:false =
    (
        if 重新扫描 then
        (
            if 选中的路径 != undefined and 选中的路径 != "" do
            (
                所有MAX文件路径 = 按条件过滤文件 (递归获取所有MAX文件 选中的路径)
            )
        )
        
        local 文件名显示列表 = #()
        for 文件 in 所有MAX文件路径 do
            append 文件名显示列表 (getFilenameFile 文件)
        文件列表框.items = 文件名显示列表
        
        遍历文件按钮.text = "更新列表 (" + (所有MAX文件路径.count as string) + "个文件)"
    )

    -- ----------------------------------------------------------------------
    -- 手动添加单个 MAX 文件到处理列表
    -- ----------------------------------------------------------------------
    fn 添加单个文件到列表 单个文件路径 =
    (
        if 单个文件路径 == undefined or 单个文件路径 == "" do return false
        if not (doesFileExist 单个文件路径) do return false
        if getFilenameType 单个文件路径 != ".max" do return false

        if matchPattern (getFilenameFile 单个文件路径) pattern:"*skin" ignoreCase:true do
        (
            messageBox "该文件是蒙皮文件，已被自动排除（不导出BIP）" title:"提示"
            return false
        )

        if findItem 所有MAX文件路径 单个文件路径 != 0 do return false

        append 所有MAX文件路径 单个文件路径
        更新文件列表 重新扫描:false
        return true
    )

    -- ----------------------------------------------------------------------
    -- 删除列表框中当前选中的文件
    -- ----------------------------------------------------------------------
    fn 删除选中文件 =
    (
        local 选中项索引 = 文件列表框.selection
        if 选中项索引 == undefined or 选中项索引 < 1 do
        (
            messageBox "请先选中列表中的文件！" title:"提示"
            return false
        )
        deleteItem 所有MAX文件路径 选中项索引
        更新文件列表 重新扫描:false
        return true
    )

    -- ----------------------------------------------------------------------
    -- 调整主窗口宽度以显示/隐藏右侧面板
    -- ----------------------------------------------------------------------
    fn 调整UI宽度 状态值 =
    (
        bip导出.width = if 状态值 == 1 then 340 else 170
        ui宽度状态 = 状态值
    )

    -- #######################################################################
    -- 6. 核心功能：质心定位（双策略，导出导入共用）
    -- #######################################################################

        -- ----------------------------------------------------------------------
    -- ?? 终极修复版：定位Biped质心节点（严格遵循用户关键词意图）
    -- 参数: 关键词文本 (string) - 来自质心关键词多选.text，支持空格多选
    -- 返回: 质心节点 或 undefined
    -- 逻辑:
    --   1. 若用户输入非空关键词 → 仅按名称匹配关键词，不执行任何自动回退
    --   2. 若用户未输入关键词 → 采用默认策略：
    --        a. 父节点为undefined的Biped节点（标准根）
    --        b. 名称包含"bip"的第一个节点
    -- ----------------------------------------------------------------------
    fn 定位Biped质心 关键词文本 =
    (
        -- 强制显示所有对象
        max unhide all
        max unfreeze all
        
        -- 收集所有Biped对象（排除脚步控制器）
        local 所有Biped对象 = for 对象 in objects \
            where (classof 对象 == Biped_Object and (对象.controller as string) != "Controller:Footsteps") \
            collect 对象
        if 所有Biped对象.count == 0 do return undefined

        -- ===== 用户输入非空关键词 → 仅名称匹配，无回退 =====
        if 关键词文本 != undefined and 关键词文本 != "" then
        (
            local 关键词列表 = filterString 关键词文本 " "
            if 关键词列表.count > 0 then
            (
                for 节点 in 所有Biped对象 do
                (
                    local 节点名 = 节点.name
                    for 关键词 in 关键词列表 do
                        if matchPattern 节点名 pattern:("*" + 关键词 + "*") ignoreCase:true then
                            return 节点
                )
                return undefined  -- 严格匹配，找不到即返回undefined
            )
        )

        -- ===== 用户未输入关键词 → 执行默认自动策略 =====
        -- 策略A：父节点为undefined（标准Biped根）
        for 节点 in 所有Biped对象 do
            if 节点.parent == undefined then
                return 节点
        
        -- 策略B：名称包含"bip"（兜底）
        for 节点 in 所有Biped对象 do
        (
            local 节点名 = 节点.name
            if matchPattern 节点名 pattern:"*bip*" ignoreCase:true then
                return 节点
        )
        
        return undefined
    )

    -- #######################################################################
    -- 7. 按钮事件处理
    -- #######################################################################

    -- ----------------------------------------------------------------------
    -- 选择路径按钮
    -- ----------------------------------------------------------------------
    on 选择路径按钮 pressed do
    (
        选中的路径 = getSavePath caption:"选择文件夹"
        if 选中的路径 == undefined or 选中的路径 == "" then
        (
            选择路径按钮.text = "获取MAX文件到列表"
            调整UI宽度(0)
            设置左侧控件状态 false
        )
        else
        (
            选择路径按钮.text = "重新选择获取路径"
            调整UI宽度(1)
            更新文件列表 重新扫描:true
            设置左侧控件状态 true
        )
    )

    -- ----------------------------------------------------------------------
    -- 遍历文件按钮
    -- ----------------------------------------------------------------------
    on 遍历文件按钮 pressed do (更新文件列表 重新扫描:true)

    -- ----------------------------------------------------------------------
    -- 添加单个文件按钮
    -- ----------------------------------------------------------------------
    on 添加单个文件按钮 pressed do
    (
        local 选中文件 = getOpenFileName caption:"选择单个MAX文件" types:"MAX文件 (*.max)|*.max|"
        if 选中文件 != undefined and 选中文件 != "" do
            添加单个文件到列表 选中文件
    )

    -- ----------------------------------------------------------------------
    -- 删除选中文件按钮
    -- ----------------------------------------------------------------------
    on 删除选中文件按钮 pressed do (删除选中文件())

    -- ----------------------------------------------------------------------
    -- 保存路径按钮（左键）：批量导出BIP
    -- ----------------------------------------------------------------------
    on 保存路径按钮 pressed do
    (
        if 所有MAX文件路径.count == 0 do
        (
            messageBox "请先添加要处理的MAX文件！" title:"提示"
            return false
        )

        -- 导出根路径记忆逻辑
        local 需要选择路径 = true
        if 导出根路径 != "" and 导出根路径已设置 == true and doesDirectoryExist (pathConfig.appendPath 导出根路径 "bip") then
            需要选择路径 = false

        if 需要选择路径 then
        (
            local 目标根路径 = getSavePath caption:"选择你要创建BIP文件夹的路径"
            if 目标根路径 == undefined or 目标根路径 == "" do
            (
                messageBox "请选择保存路径！" title:"提示"
                return false
            )
            导出根路径 = 目标根路径
            导出根路径已设置 = true
            format "导出根路径已记录: %\n" 导出根路径
        )
        else
            format "使用已有导出根路径: %\n" 导出根路径

        -- 自动设置默认BIP来源
        if 当前BIP来源路径 == "" then
        (
            当前BIP来源路径 = pathConfig.appendPath 导出根路径 "bip"
            更新BIP来源显示()
            format "已自动设置默认BIP来源: %\n" 当前BIP来源路径
        )

        -- 确保 bip 输出文件夹存在
        local BIP输出文件夹 = pathConfig.appendPath 导出根路径 "bip"
        if not doesDirectoryExist BIP输出文件夹 do
        (
            try (makeDir BIP输出文件夹) catch
            (
                messageBox ("无法创建文件夹: " + BIP输出文件夹) title:"错误"
                return false
            )
        )

        -- 首次导出提醒
        if 需要选择路径 then
        (
            local 文件数量 = 所有MAX文件路径.count
            local 是否立即导出 = queryBox ("? bip文件夹已创建：\n" + BIP输出文件夹 + "\n\n即将处理 " + (文件数量 as string) + " 个MAX文件！\n\n是否立即开始批量导出？") title:"本窗口提醒一次，下次将直接执行导出"
            if not 是否立即导出 then
            (
                保存路径按钮.text = "可以导出(已有文件夹)"
                format "用户选择暂不导出，bip文件夹已创建。\n"
                return true
            )
        )

        -- ========== 批量导出主循环 ==========
        local 成功计数 = 0
        local 失败计数 = 0

        for 文件序号 = 1 to 所有MAX文件路径.count do
        (
            local 当前文件 = 所有MAX文件路径[文件序号]
            format "=== 处理文件 %: % ===\n" 文件序号 当前文件

            try
            (
                -- 加载MAX文件
                loadMaxFile 当前文件 useFileUnit:true quiet:true
                
                -- 定位质心（实时读取质心关键词框）
                local 质心节点 = 定位Biped质心 质心关键词多选.text
                if 质心节点 == undefined do throw "质心名称不匹配"
                
                select 质心节点
                local Biped控制器 = 质心节点.controller
                
                -- 获取动画范围（日志）
                local 当前动画范围 = animationRange
                local 当前开始帧 = 当前动画范围.start.frame as integer
                local 当前结束帧 = 当前动画范围.end.frame as integer
                format "  文件帧范围: % 到 % (帧速率: %)\n" 当前开始帧 当前结束帧 frameRate

                -- 关键点转换模式
                local 处理模式 = 关键点处理模式.state
                local 模式文本 = case 处理模式 of
                (
                    1: "转换全部（手脚）"
                    2: "仅转换手部"
                    3: "不转换"
                )
                format "  处理模式: %\n" 模式文本

                -- 关键点转换（通配符 hand/foot）
                if 处理模式 != 3 then
                (
                    -- 重新收集Biped对象（此时场景已完全可见）
                    local 所有Biped对象 = for 对象 in objects \
                        where (classof 对象 == Biped_Object and (对象.controller as string) != "Controller:Footsteps") \
                        collect 对象
                    
                    local 待转换部位集 = #()
                    for 节点 in 所有Biped对象 do
                    (
                        local 节点名 = 节点.name
                        case 处理模式 of
                        (
                            1: ( -- All
                                if matchPattern 节点名 pattern:"*hand*" ignoreCase:true or \
                                   matchPattern 节点名 pattern:"*foot*" ignoreCase:true then
                                    append 待转换部位集 节点
                            )
                            2: ( -- Hand
                                if matchPattern 节点名 pattern:"*hand*" ignoreCase:true then
                                    append 待转换部位集 节点
                            )
                        )
                    )
                    format "  找到 % 个待转换部位\n" 待转换部位集.count
                    
                    for 部位骨骼 in 待转换部位集 do
                    (
                        local 控制器 = 部位骨骼.transform.controller
                        if 控制器 != undefined and 控制器.numKeys > 0 then
                            for i = 1 to 控制器.numKeys do
                                biped.setFreeKey 部位骨骼 (控制器.getKeyTime i)
                    )
                )
                else
                    format "  不转换任何关键点，直接导出\n"

                -- 导出BIP
                local 文件名 = getFilenameFile 当前文件
                local BIP导出路径 = BIP输出文件夹 + "\\" + 文件名 + ".bip"
                biped.saveBipFile Biped控制器 BIP导出路径
                format "  成功导出: %\n" BIP导出路径
                成功计数 += 1
            )
            catch
            (
                local 错误信息 = getCurrentException()
                format "  处理失败: %\n" 错误信息
                失败计数 += 1
            )
            format "\n"
        )

        local 结果信息 = "处理完成！\n成功: " + (成功计数 as string) + " 个文件\n失败: " + (失败计数 as string) + " 个文件"
        if 成功计数 > 0 then 结果信息 += "\nBIP文件保存在: " + BIP输出文件夹
        messageBox 结果信息 title:"导出完成"
    )

    -- ----------------------------------------------------------------------
    -- 保存路径按钮（右键）：重置导出根路径
    -- ----------------------------------------------------------------------
    on 保存路径按钮 rightclick do
    (
        local 新路径 = getSavePath caption:"右键重置：选择BIP文件夹的存放位置"
        if 新路径 == undefined or 新路径 == "" do return false

        local 旧导出根路径 = 导出根路径
        导出根路径 = 新路径
        导出根路径已设置 = true

        local BIP输出文件夹 = pathConfig.appendPath 导出根路径 "bip"
        if not doesDirectoryExist BIP输出文件夹 do
        (
            try (makeDir BIP输出文件夹) catch
            (
                messageBox ("无法创建文件夹: " + BIP输出文件夹) title:"错误"
                return false
            )
        )

        if 当前BIP来源路径 != "" and 旧导出根路径 != "" and 当前BIP来源路径 == (pathConfig.appendPath 旧导出根路径 "bip") then
        (
            当前BIP来源路径 = BIP输出文件夹
            更新BIP来源显示()
        )
        else if 当前BIP来源路径 == "" then
        (
            当前BIP来源路径 = BIP输出文件夹
            更新BIP来源显示()
        )

        format "右键操作：导出根路径已重置为 %\n" 导出根路径
        messageBox ("导出路径已重置为：\n" + 导出根路径 + "\nBIP文件夹已准备就绪") title:"路径已更新"
    )

    -- ----------------------------------------------------------------------
    -- 拾取蒙皮文件
    -- ----------------------------------------------------------------------
    on 拾取蒙皮文件 pressed do
    (
        local 文件对话框 = dotNetObject "System.Windows.Forms.OpenFileDialog"
        文件对话框.title = "请选择蒙皮文件（作为BIP导入的模板）"
        文件对话框.Multiselect = false
        文件对话框.Filter = "MAX文件 (*.max)|*.max|所有文件 (*.*)|*.*"
        文件对话框.FilterIndex = 1

        local 对话框结果 = 文件对话框.showDialog()
        if 对话框结果.Equals (dotNetClass "System.Windows.Forms.DialogResult").OK then
        (
            蒙皮文件路径 = 文件对话框.FileName
            蒙皮文件显示框.text = filenameFromPath 蒙皮文件路径
            format "已选择蒙皮文件: %\n" 蒙皮文件路径
        )
    )

    -- ----------------------------------------------------------------------
    -- 使用其他bip文件
    -- ----------------------------------------------------------------------
    on 使用其他bip文件 pressed do
    (
        local 选择的文件夹 = getSavePath caption:"请选择包含BIP文件的文件夹（将设置为当前BIP来源）"
        if 选择的文件夹 == undefined or 选择的文件夹 == "" do
        (
            messageBox "已取消操作" title:"提示"
            return false
        )

        local BIP文件列表 = getFiles (选择的文件夹 + "\\*.bip")
        if BIP文件列表.count == 0 do
        (
            messageBox ("所选文件夹中没有找到任何 .bip 文件，请重新选择！") title:"提示"
            return false
        )

        当前BIP来源路径 = 选择的文件夹
        更新BIP来源显示()
        format "已设置自定义BIP来源: %\n" 当前BIP来源路径
        messageBox ("BIP来源已切换至：\n" + 当前BIP来源路径) title:"来源已设置"
    )

    -- ----------------------------------------------------------------------
    -- 批量导入BIP（使用与导出完全一致的质心定位）
    -- ----------------------------------------------------------------------
    on 批量导入BIP pressed do
    (
        -- 检查蒙皮文件
        if 蒙皮文件路径 == "" or not doesFileExist 蒙皮文件路径 do
        (
            messageBox "请先拾取一个有效的蒙皮文件！" title:"提示"
            return false
        )

        -- 检查BIP来源
        if 当前BIP来源路径 == "" then
        (
            if 导出根路径 != "" and doesDirectoryExist 导出根路径 then
            (
                当前BIP来源路径 = pathConfig.appendPath 导出根路径 "bip"
                更新BIP来源显示()
                format "已自动恢复默认BIP来源: %\n" 当前BIP来源路径
            )
            else
            (
                messageBox "未设置BIP来源，请先导出BIP文件或使用【使用其他bip文件】按钮选择BIP文件夹！" title:"提示"
                return false
            )
        )

        if not doesDirectoryExist 当前BIP来源路径 do
        (
            messageBox ("BIP来源文件夹不存在: " + 当前BIP来源路径 + "\n请重新设置BIP来源。") title:"错误"
            return false
        )

        local BIP文件列表 = getFiles (当前BIP来源路径 + "\\*.bip")
        if BIP文件列表.count == 0 do
        (
            messageBox ("当前BIP来源文件夹中没有找到任何 .bip 文件") title:"提示"
            return false
        )

        -- 选择输出根路径
        local 输出根路径 = getSavePath caption:"请选择导入后MAX文件的保存根路径（将在此路径下创建 蒙皮文件名@max 文件夹）"
        if 输出根路径 == undefined or 输出根路径 == "" do
        (
            messageBox "已取消操作" title:"提示"
            return false
        )

        local 蒙皮文件名 = getFilenameFile 蒙皮文件路径
        local 目标文件夹 = pathConfig.appendPath 输出根路径 (蒙皮文件名 + "@max")
        if not doesDirectoryExist 目标文件夹 do
        (
            try (makeDir 目标文件夹) catch
            (
                messageBox ("无法创建文件夹: " + 目标文件夹) title:"错误"
                return false
            )
        )

        -- ========== 批量导入主循环 ==========
        local 成功计数 = 0
        local 失败计数 = 0

        for 序号 = 1 to BIP文件列表.count do
        (
            local 当前BIP文件 = BIP文件列表[序号]
            format "=== 导入BIP %: % ===\n" 序号 当前BIP文件

            try
            (
                -- 加载蒙皮模板
                loadMaxFile 蒙皮文件路径 useFileUnit:true quiet:true
                
                -- 定位质心（与导出完全相同的函数，实时读取质心关键词框）
                local 质心节点 = 定位Biped质心 质心关键词多选.text
                if 质心节点 == undefined do throw "蒙皮文件中未找到Biped质心节点"
                
                select 质心节点
                local Biped控制器 = 质心节点.controller

                -- 导入BIP动画
				if 最低高度勾选.checked then
                    biped.loadBipFile Biped控制器 当前BIP文件 #zeroHgt
                else
                    biped.loadBipFile Biped控制器 当前BIP文件

                -- 保存MAX文件
                local BIP文件名 = getFilenameFile 当前BIP文件
                local 保存路径 = 目标文件夹 + "\\" + BIP文件名 + ".max"
                saveMaxFile 保存路径

                format "  成功导入并保存: %\n" 保存路径
                成功计数 += 1
            )
            catch
            (
                local 错误信息 = getCurrentException()
                format "  导入失败: %\n" 错误信息
                失败计数 += 1
            )
            format "\n"
        )

        local 结果信息 = "批量导入完成！\n成功: " + (成功计数 as string) + " 个文件\n失败: " + (失败计数 as string) + " 个文件"
        if 成功计数 > 0 then 结果信息 += "\nMAX文件保存在: " + 目标文件夹
        messageBox 结果信息 title:"导入完成"
    )

    -- ----------------------------------------------------------------------
    -- 调试按钮
    -- ----------------------------------------------------------------------
    on 调试按钮 pressed do (调试按钮状态 调试状态)

    -- ----------------------------------------------------------------------
    -- 导入功能按钮
    -- ----------------------------------------------------------------------
    on 导入功能 pressed do (导入功能按钮状态 导入功能状态)
)

-- #########################################################################
-- 创建对话框
-- #########################################################################
createDialog bip导出

-- ===========================================================================
-- 脚本结束
-- ===========================================================================