-- 全局变量声明
global BoneEditToolsFloater              -- 浮动窗口对象
global BoneEditToolsRollout               -- Rollout对象
global updateTRFlag = true                -- UI更新标志
global boneEditModeTurnedOnByMe = false   -- 记录是否由脚本开启骨骼编辑模式
global tmparrayforbipsel = #()            -- 临时数组，用于存储选择的骨骼

global boneDivider = false                -- 骨骼分割器窗口
global BoneMirror = false                 -- 骨骼镜像窗口
-- ============================================================================
-- 辅助函数：获取骨骼的端点位置
-- 参数：a - 骨骼对象
-- 返回：骨骼端点的世界坐标
fn getEndPoint a =
(
    if (classOf(a) == BoneGeometry) then
    (
        -- 如果是骨骼对象，返回骨骼长度方向的端点
        [a.Length,0,0] * a.objectTransform
    )
    else
    (
        -- 如果不是骨骼，返回对象的位置
        return (a.transform).translation
    )
)
-- 辅助函数：移除对象上的IK解算器 参数：a - 需要移除IK的对象
fn removeIKsolvers a =
(
    if ((not IsProperty a "pos") or (not IsProperty a "rotation")) do
    (
        HDIKSys.RemoveChain a
    )
)
-- 辅助函数：将子对象放入装配体 -- 参数：a - 子对象
fn putChildIntoAssembly a =
(
    if ((a.parent != undefined) and (a.parent.assemblyMember)) do
    (
        a.assemblyMember = true
        a.assemblyMemberOpen = true
    )
)

-- 辅助函数：获取装配体的头节点 参数：a - 对象 返回：装配体头节点，如果不在装配体中返回undefined
fn getAssemblyHead a =
(
    b = a
    while (b != undefined) do
    (
        if (b.assemblyHead) do return b
        if (not b.assemblyMember) do exit
        b = b.parent
    )
    return undefined
)
-- 辅助函数：复制骨骼的宽度和高度 参数：destination - 目标骨骼 source - 源骨骼    
fn copyBoneHeightWidth destination source =
(
    if ((source != undefined) and (classOf(source) == BoneGeometry)) do
    (
        destination.width = source.width
        destination.height = source.height
    )
)
-- 辅助函数：递归选择所有子物体 参数：sel - 父对象
fn SelChildren sel =
(
    if sel.children.count >= 1 then
    (
        for i = 1 to sel.children.count do
        (
            tempsel = sel.children[i]
            append tmparrayforbipsel tempsel  -- 把子物体加进选择集
            if tempsel != undefined do SelChildren tempsel
        )
    )
    return tmparrayforbipsel  -- 返回：所有子对象的数组
)

-- 辅助函数：选择自己和所有子物体 参数：sel - 对象
fn SelMeAndChildren sel =
(
    append tmparrayforbipsel sel  -- 把自己加进选择集
    SelChildren sel
)

rollout BoneEditToolsRollout "骨骼编辑工具" width:260 height:190
(
    group "骨骼轴心位置"
    (
        checkbutton BoneEdit_btn "骨骼编辑模式" width:200 height:20 align:#center
    )
    group "骨骼工具"
    (
        checkbutton CreateBone_btn "创建骨骼" width:105 height:20 across:2 align:#left highlightColor:(color ((colorman.getcolor #activecommand).x *255) ((colorman.getcolor #activecommand).y *255)((colorman.getcolor #activecommand).z *255))
        button CreateEnd_btn "创建末端" width:105 height:20 align:#right
        button RemoveBone_btn "移除骨骼" width:105 height:20 across:2 align:#left
        button ConnectBones_btn "连接骨骼" width:105 height:20 align:#right
        button DeleteBone_btn "删除骨骼" width:105 height:20 across:2 align:#left
        button ReassignRoot_btn "重设根骨骼" width:105 height:20 align:#right
        checkbutton RefineBone_btn "细化骨骼" width:105 height:20 across:2 align:#left highlightColor:(color ((colorman.getcolor #activecommand).x *255) ((colorman.getcolor #activecommand).y *255)((colorman.getcolor #activecommand).z *255)) \
        toolTip:"左键自带细化，右键等分细化脚本"
        button Mirror_btn "骨骼镜像" width:105 height:20 align:#right
    )   


	-- ========================================================================
    -- 函数：更新UI状态
    -- 功能：根据当前选择更新按钮的启用/禁用状态
    -- ========================================================================
	fn UpdateUI =
    ( 
        if updateTRFlag == true do
        ( 
            -- 同步骨骼编辑模式按钮状态
            if (maxops.affectchildren == false) then BoneEdit_btn.state = true
            else BoneEdit_btn.state = false
            
            updateTRFlag = false
            
            -- 检查选择集中是否有骨骼对象 --新增检查-- 
            local hasBone = false
            for obj in selection do
            ( 
                if classOf obj == BoneGeometry do
                ( 
                    hasBone = true
                    exit
                ) 
            ) 
            --新增检查结束-- 
            
            -- 根据选择数量更新UI
            case selection.count of
            ( 
                0: ( 
                    -- 没有选择任何对象
                    ReassignRoot_btn.enabled = false
                    RemoveBone_btn.enabled = false
                    CreateEnd_btn.enabled = false
                    DeleteBone_btn.enabled = false
                    ConnectBones_btn.enabled = false
                    Mirror_btn.enabled = false
                    CreateBone_btn.checked = false
                ) 
                1: ( 
                    -- 选择了一个对象
                    local b = selection[1] 
                    local isBone = (classOf b == BoneGeometry) 
                    
                    ReassignRoot_btn.enabled = isBone
                    RemoveBone_btn.enabled = isBone
                    CreateEnd_btn.enabled = isBone and (selection[1].children.count < 1) 
                    DeleteBone_btn.enabled = isBone
                    ConnectBones_btn.enabled = isBone
                    Mirror_btn.enabled = isBone
                    CreateBone_btn.checked = mcrUtils.IsCreating Bones
                    -- 移除这两行 --
                    -- createBoneTimer.active = CreateBone_btn.checked
                ) 
                default: ( 
                    -- 选择了多个对象
                    ReassignRoot_btn.enabled = false
                    RemoveBone_btn.enabled = false
                    CreateEnd_btn.enabled = false
                    DeleteBone_btn.enabled = false
                    ConnectBones_btn.enabled = false
                    Mirror_btn.enabled = hasBone
                    CreateBone_btn.checked = mcrUtils.IsCreating Bones
                    -- 移除这两行 --
                    -- createBoneTimer.active = CreateBone_btn.checked
                ) 
            ) 
        ) 
    )
    
    -- 事件：骨骼编辑模式按钮状态改变
    on BoneEdit_btn changed state do
    (
        if (BoneEdit_btn.state == true) then
        (
            -- 开启骨骼编辑模式
            boneEditModeTurnedOnByMe = true
            maxops.affectchildren = false  -- 设置为不影响子物体
            if isCreatingObject Bones do
            (
                StopCreating()  -- 停止创建骨骼
            )
        )
        else
        (
            -- 关闭骨骼编辑模式
            boneEditModeTurnedOnByMe = false
            maxops.affectchildren = true  -- 恢复影响子物体
        )
    )
    timer boneEditModeTimer interval:100 active:true
    -- 事件：骨骼编辑模式定时器 --功能：同步按钮状态与系统状态
    on boneEditModeTimer tick do
    ( 
        -- 如果按钮状态与系统状态不一致，则同步
        if (BoneEdit_btn.state == maxops.affectChildren) do
        ( 
            BoneEdit_btn.state = (not maxops.affectChildren) 
        ) 
        -- 根据动画按钮状态启用/禁用编辑模式按钮
        if (BoneEdit_btn.enabled == animButtonState) do
        ( 
            BoneEdit_btn.enabled = (not animButtonState) 
        ) 
        
        -- 实时更新按钮状态 --新增--
        updateTRFlag = true
        UpdateUI()
        --新增结束--
    )
    
    -- ========================================================================
    -- 事件：创建末端骨骼按钮
    -- 功能：在选中骨骼的末端创建一个新的末端骨骼
    -- ========================================================================
    on CreateEnd_btn pressed do
    (
        undo "创建末端" on
        (
            if (selection.count == 1) do  -- 只有选中一个对象时才执行
            (
                with Animate Off  -- 关闭动画记录
                (
                    local parentBone = selection[1]  -- 获取选中的父骨骼
                    local parentTrans = parentBone.transform  -- 获取父骨骼的变换矩阵
                    local parentPos = parentTrans.translation  -- 获取父骨骼的位置
                    local newbone
                    
                    with redraw off  -- 关闭视图重绘以提高性能
                    (
                        -- 创建新骨骼
                        newBone = BoneSys.createBone parentPos (parentPos+6) parentBone.dir
                        newBone.transform = parentTrans
                        
                        -- 将新骨骼移动到父骨骼的末端
                        in coordSys Local move newBone [parentBone.Length,0,0]
                        
                        -- 设置父子关系
                        newBone.parent = parentBone
                        putChildIntoAssembly newBone
                        
                        -- 复制父骨骼的属性
                        newBone.width = parentBone.width
                        newBone.height = parentBone.height
                        newBone.taper = 90  -- 设置锥度为90（末端骨骼）
                        newBone.Length = (parentBone.width+parentBone.height)/2
                        newBone.wirecolor = parentBone.wirecolor
                        
                        -- 选中新创建的骨骼
                        select newBone
                    )
                    
                    redrawViews()  -- 刷新视图
                )
            )
        )
    )
    
    -- ========================================================================
    -- 事件：重新指定根骨骼按钮
    -- 功能：反转骨骼链的层级关系，将选中的骨骼变为根骨骼
    -- ========================================================================
    on ReassignRoot_btn pressed do
    (
        undo "重设根骨骼" on
        (
            with redraw off
            (
                with animate off
                (
                    local deleteBoneArr = #()  -- 要删除的骨骼数组
                    local currentBone = selection[1]  -- 当前选中的骨骼
                    local selBone = undefined  -- 最终要选中的骨骼
                    local chlBone = undefined  -- 子骨骼
                    local parentBone = currentBone.parent  -- 父骨骼
                    local prevBone = undefined  -- 前一个骨骼
                    local newBone = undefined  -- 新创建的骨骼
                    local newBoneArr = #()  -- 新骨骼数组
                    local endBone = undefined
                    local revReset
                    local exPrevBone = undefined
                    local i
                    
                    -- ============================================================
                    -- 内部函数：判断两个位置是否相同（带容差）
                    -- ============================================================
                    fn isPosSame a b =
                    (
                        local posTol = 5  -- 位置容差
                        v1=a
                        v2=b
                        vi=0
                        
                        -- 检查X、Y、Z三个轴的差值是否在容差范围内
                        if ((v1.x) <= (v2.x + posTol)) and ((v1.x) >= (v2.x - posTol)) then vi +=1
                        if ((v1.y) <= (v2.y + posTol)) and ((v1.y) >= (v2.y - posTol)) then vi +=1
                        if ((v1.z) <= (v2.z + posTol)) and ((v1.z) >= (v2.z - posTol)) then vi +=1
                        
                        if vi > 1 then return true else return false
                    )
                    
                    append deleteBoneArr currentBone
                    removeIKsolvers currentBone
                    
                    -- 保存子骨骼
                    if currentBone.children.count > 0 then
                    (
                        chlBone = currentBone.children
                        revReset = true
                    )
                    
                    -- 检查是否为末端骨骼
                    if (classOf(currentBone) == BoneGeometry) and (currentBone.Length == 10) and (currentBone.children.count == 0) then
                    (
                        currentBone = parentBone
                        parentBone = currentBone.parent
                        append deleteBoneArr currentBone
                    )
                    
                    if (parentBone != undefined) then
                    (
                        -- 开始骨骼创建循环，反转层级
                        do
                        (
                            removeIKsolvers currentBone
                            
                            if (classOf(currentBone) == BoneGeometry) then
                            (
                                -- 创建新骨骼（方向相反）
                                newBone = boneSys.createBone (getEndPoint currentBone) currentBone.transform.translation currentBone.dir
                                copyBoneHeightWidth newBone currentBone
                                newBone.name = currentBone.name
                                newBone.wirecolor = currentBone.wirecolor
                                newBone.parent = prevBone
                                newBone.resetBoneStretch()
                                
                                -- 处理多个子节点的情况
                                if (parentBone.children.count > 1) and (parentBone.parent != undefined) then
                                (
                                    parentBone.children.parent = newBone
                                )
                                
                                -- 删除长度为10的末端骨骼
                                if (newBone.children == 0) and (newBone.Length == 10) then
                                (
                                    delete newBone
                                )
                                
                                -- 重新连接原来的子骨骼
                                if chlBone != undefined then
                                (
                                    chlBone.parent = newBone
                                )
                                
                                -- 记录要选中的骨骼
                                if prevBone == undefined then
                                (
                                    selBone = newbone
                                )
                                
                                prevBone = newBone
                                currentBone = parentBone
                                parentBone = currentBone.parent
                                
                                if (classOf(currentBone) == BoneGeometry) do append deleteBoneArr currentBone
                                append newBoneArr newBone
                            )
                            else
                            (
                                -- 处理非骨骼对象
                                if (parentBone.children.count > 1) and (parentBone.parent != undefined) then
                                (
                                    local siblings = #()
                                    for b in parentBone.children do
                                    (
                                        if b != currentBone then
                                        (
                                            append siblings b
                                        )
                                    )
                                    for i = 1 to siblings.count do
                                    (
                                        (siblings[i]).parent = currentBone
                                    )
                                )
                                
                                if chlBone != undefined then
                                (
                                    chlBone.parent = currentBone
                                )
                                
                                if prevBone == undefined then
                                (
                                    selBone = currentBone
                                )
                                
                                exPrevBone = prevBone
                                prevBone = currentBone
                                currentBone = parentBone
                                parentBone = currentBone.parent
                                prevBone.parent = exPrevBone
                                if (classOf(currentBone) == BoneGeometry) do append deleteBoneArr currentBone
                            )
                        ) while (parentBone != undefined)  -- 骨骼创建循环结束
                        
                        -- 处理根骨骼
                        if currentBone.children.count > 1 then
                        (
                            if (classOf(currentBone) == BoneGeometry) then
                            (
                                local chlVar = #()
                                
                                for b in currentBone.children do
                                (
                                    append chlVar b
                                    b.parent = undefined
                                )
                                
                                newBone = boneSys.createBone (getEndPoint currentBone) currentBone.transform.translation currentBone.dir
                                copyBoneHeightWidth newBone currentBone
                                newBone.name = currentBone.name
                                newBone.wirecolor = currentBone.wirecolor
                                newBone.parent = prevBone
                                
                                chlVar.parent = newBone
                                
                                newBone.realignBoneToChild()
                                newBone.resetBoneStretch()
                                append newBoneArr newBone
                            )
                            else
                            (
                                currentBone.parent = prevBone
                                append newBoneArr currentBone
                            )
                        )
                        else
                        (
                            if (classOf(currentBone) == BoneGeometry) then
                            (
                                newBone = boneSys.createBone (getEndPoint currentBone) currentBone.transform.translation currentBone.dir
                                copyBoneHeightWidth newBone currentBone
                                newBone.name = currentBone.name
                                newBone.wirecolor = currentBone.wirecolor
                                newBone.parent = prevBone
                                append newBoneArr newBone
                                
                                parentBone = newBone
                                
                                -- 创建新的末端骨骼
                                newBone = BoneSys.createBone parentBone.transform.translation (parentBone.transform.translation+6) parentBone.dir
                                copyBoneHeightWidth newBone parentBone
                                newBone.rotation = parentBone.rotation
                                newBone.pos = parentBone.transform.translation
                                in coordSys Local move newBone [parentBone.Length,0,0]
                                newBone.parent = parentBone
                                newBone.width = parentBone.width
                                newBone.height = parentBone.height
                                newBone.taper = 90
                                newBone.Length = (parentBone.width+parentBone.height)/2
                                newBone.wirecolor = parentBone.wirecolor
                            )
                            else
                            (
                                currentBone.parent = prevBone
                            )
                        )
                        
                        -- 删除旧骨骼
                        for b in deleteBoneArr do
                        (
                            if not isDeleted b do delete b
                        )
                        
                        -- 重置骨骼拉伸
                        if (revReset != true) then
                        (
                            for i=1 to newBoneArr.count do
                            (
                                (newBoneArr[i]).resetBoneStretch()
                            )
                        )
                        else
                        (
                            for i=newBoneArr.count to 2 by -1 do
                            (
                                (newBoneArr[i]).resetBoneStretch()
                            )
                        )
                        
                        -- 选中新的根骨骼
                        select selBone
                    )
                )
            )
        )
    )
    
    -- ========================================================================
    -- 事件：移除骨骼按钮
    -- 功能：移除选中的骨骼，但保持层级连接
    --       普通模式：子骨骼连接到父骨骼
    --       Shift模式：父骨骼延伸到子骨骼位置
    -- ========================================================================
    on RemoveBone_btn pressed do
    (
        undo "移除骨骼" on(
            if (selection.count == 1) do
            (
                with Animate Off
                (
                    with redraw off
                    (
                        removeIKsolvers $
                        
                        if keyboard.shiftPressed == false then
                        (
                            -- 普通模式：移除骨骼，子骨骼连接到父骨骼
                            local parent = $.parent
                            
                            if parent != undefined do
                            (
                                parent.ResetBoneStretch()
                            )
                            
                            -- 将所有子骨骼重新连接到父骨骼
                            for i=1 to $.children.count do
                            (
                                local chl = $.children[1]
                                removeIKsolvers chl
                                if (classOf chl == BoneGeometry) do chl.pivot = $.transform.translation
                                chl.parent = parent
                                chl.ResetBoneStretch()
                            )
                            
                            $.parent = undefined
                            delete $
                        )
                        else
                        (
                            -- Shift模式：移除骨骼，父骨骼延伸到子骨骼
                            local chlArr = #()
                            local chlAsm = #()
                            
                            -- 保存子骨骼信息
                            for i=1 to $.children.count do
                            (
                                append chlArr $.children[i]
                                append chlAsm $.children[i].assemblyMember
                                removeIKsolvers $.children[i]
                            )
                            
                            local chl = $.children[1]
                            local prt = $.parent
                            
                            local asmMbr = $.assemblyMember
                            $.pivot = chl.transform.translation
                            
                            -- 重新连接子骨骼
                            for i=1 to chlArr.count do
                            (
                                chlArr[i].parent = prt
                                if (asmMbr and chlAsm[i]) do
                                (
                                    putChildIntoAssembly chlArr[i]
                                )
                            )
                            delete $
                            
                            -- 重新对齐父骨骼
                            if (prt != undefined) do
                            (
                                prt.realignBoneToChild()
                                prt.ResetBoneStretch()
                            )
                        )
                    )
                    redrawviews()
                )
            )
        )
    )
    
    -- ========================================================================
    -- 事件：连接骨骼按钮
    -- 功能：在两个骨骼之间创建一个连接骨骼
    -- ========================================================================
    on ConnectBones_btn pressed do
    (
        undo "连接骨骼" on
        (
            local parentBone, childBone, newBone
            with Animate Off
            (
                parentBone = selection[1]
                parentTip = [parentBone.Length,0,0] * parentBone.objectTransform
                
                -- 骨骼过滤函数
                fn boneFilt o = Filters.Is_Bone o
                
                if parentbone.children.count != 0 and keyboard.shiftPressed == false then
                (
                    -- 普通模式：选择末端骨骼
                    childBone = PickObject count:1 select:false filter:boneFilt count:1 Message:"选择末端骨骼" Rubberband:parentTip ForceListenerFocus:False
                    
                    if childbone != undefined then
                    (
                        zaxis = parentBone.dir
                        newbone = BoneSys.createbone parentTip childBone.transform.translation zaxis
                    )
                )
                else
                (
                    -- Shift模式：选择末端骨骼（平均方向）
                    childBone = PickObject count:1 select:false filter:boneFilt count:1 Message:"选择末端骨骼" Rubberband:parentTip ForceListenerFocus:False
                    
                    if childbone != undefined then
                    (
                        zaxis = (parentBone.dir+childBone.dir)/2  -- 使用平均方向
                        newbone = BoneSys.createbone parentTip childBone.transform.translation zaxis
                    )
                )
                
                try
                (
                    parentBone.ResetBoneStretch()
                    
                    -- 设置新骨骼的属性（取两个骨骼的平均值）
                    newbone.width = (parentbone.width+childbone.width)/2
                    newbone.height = (parentbone.height+childbone.height)/2
                    newbone.taper = (parentbone.taper+childbone.taper)/2
                    newbone.name = uniqueName "connectBone"
                    
                    -- 建立层级关系
                    newBone.parent = parentBone
                    if (childBone.assemblyMember) do
                    (
                        putChildIntoAssembly newBone
                    )
                    childBone.parent = newbone
                )
                catch()
            )
        )
    )
    
    -- ========================================================================
    -- 事件：删除骨骼按钮
    -- 功能：删除选中的骨骼及其所有子骨骼
    -- ========================================================================
    on DeleteBone_btn pressed do
    (
        undo "删除骨骼" on(
            if (selection.count == 1) do
            (
                with Animate Off
                (
                    local parentBone = $.parent
                    if (parentBone != undefined) then
                    (
                        parentBone.ResetBoneStretch()
                        if parentBone.children.count == 1 then
                        (
                            -- 如果父骨骼只有一个子骨骼，且被删除的骨骼还有子骨骼
                            if ($.children.count > 0) and (classOf selection[1] == BoneGeometry) then
                            (
                                local selTrans = $.transform
                                local selPos = selTrans.translation
                                
                                -- 创建一个新的末端骨骼
                                newbone = BoneSys.createBone selPos (selPos+6) ($.dir)
                                newbone.transform = parentBone.transform
                                newbone.pos = selPos
                                newbone.name = $.name
                                newbone.wirecolor = $.wirecolor
                                newbone.parent = parentBone
                                newBone.width = $.width
                                newBone.height = $.height
                                newBone.taper = 90
                                newBone.Length = ($.width+$.height)/2
                            )
                            removeIKsolvers $
                            delete $
                        )
                        else
                        (
                            removeIKsolvers $
                            delete $
                        )
                    )
                    else
                    (
                        -- 如果没有父骨骼，直接删除
                        removeIKsolvers $
                        delete $
                    )
                )
            )
        )
    )
    
    -- ========================================================================
    -- 定时器：监控创建骨骼状态
    -- ========================================================================
    timer createBoneTimer interval:100 active:true
    
    -- ========================================================================
    -- 事件：创建骨骼按钮状态改变
    -- 功能：开启或关闭骨骼创建模式
    -- ========================================================================
    on CreateBone_btn changed state do
    (
        if state then
        (
            StartObjectCreation Bones  -- 开始创建骨骼
            createBoneTimer.active = true
        )
        else
        (
            if isCreatingObject Bones do
            (
                StopCreating()  -- 停止创建
            )
        )
    )
    
    -- ========================================================================
    -- 事件：创建骨骼定时器
    -- 功能：同步按钮状态与创建状态
    -- ========================================================================
    on createBoneTimer tick do
    (
        if not isCreatingObject Bones then
        (
            CreateBone_btn.checked = false
        )
        else
        (
            CreateBone_btn.checked = true
        )
    )
    
    -- ========================================================================
    -- 定时器：监控细化骨骼状态
    -- ========================================================================
    timer refineBoneTimer interval:100 active:false
    
    -- ========================================================================
    -- 事件：细化骨骼按钮状态改变
    -- 功能：在现有骨骼上添加新的骨骼节点
    -- ========================================================================
    on RefineBone_btn changed state do
    (
        bonesys.RefineBone()  -- 调用系统的细化骨骼功能
        
        if state do
        (
            refineBoneTimer.active = true
        )
    )

    on RefineBone_btn rightclick do
    (
    	try(destroyDialog boneDivider)catch()
    	createDialog boneDivider 
    )
    
    -- ========================================================================
    -- 事件：细化骨骼定时器
    -- 功能：监控细化操作是否完成
    -- ========================================================================
    on refineBoneTimer tick do
    (
        if toolmode.commandmode != #pick and toolmode.commandmode != #viewport do
        (
            RefineBone_btn.checked = false
            refineBoneTimer.active = false
        )
    )

    -- 事件：骨骼镜像按钮
    on Mirror_btn pressed do
    (
		local boneSelection = for obj in selection where classof obj == BoneGeometry collect obj
		
		if boneSelection.count == selection.count then
	    (
	        createdialog BoneMirror modal:true pos:mouse.screenpos
	    )
	    else
	    (
	    	messageBox "请选择Bone骨骼"
	    )
    )
    -- ========================================================================
    -- 事件：Rollout打开时
    -- 功能：注册回调函数，初始化UI
    -- ========================================================================
    on BoneEditToolsRollout open do
    (
        -- 添加回调：选择集改变时更新UI
        callbacks.addScript #selectionSetChanged "updateTRFlag = true" id:#BoneEditUpdate
        -- 添加回调：撤销操作时更新UI
        callbacks.addScript #sceneUndo "updateTRFlag = true" id:#BoneEditUpdate
        -- 添加回调：重做操作时更新UI
        callbacks.addScript #sceneRedo "updateTRFlag = true" id:#BoneEditUpdate
        -- 注册视图重绘回调
        registerRedrawViewsCallback BoneEditToolsRollout.UpdateUI
        updateTRFlag = true
        UpdateUI()
    )
    
    -- ========================================================================
    -- 事件：Rollout关闭时
    -- 功能：移除回调函数，清理资源
    -- ========================================================================
    on BoneEditToolsRollout close do
    (
        -- 移除视图重绘回调
        unregisterRedrawViewsCallback BoneEditToolsRollout.UpdateUI
        -- 移除所有相关回调
        callbacks.removeScripts id:#BoneEditUpdate
        
        -- 如果骨骼编辑模式是由脚本开启的，则关闭它
        if (boneEditModeTurnedOnByMe == true) do
        (
            boneEditModeTurnedOnByMe = false
            maxops.affectchildren = true
        )
    )
)
--============================================================================
-- Rollout：骨骼分割器对话框
rollout boneDivider "骨骼分割器 0.1" width:165 height:185
(   
  -- UI控件定义
  GroupBox grp_ops "层级选项:" pos:[5,5] width:155 height:80
  checkbox chk_hier "创建层级关系" pos:[10,20] width:105 height:15 checked:true enabled:true 
  checkbox chk_par "父级到原骨骼" pos:[10,35] width:105 height:15 checked:true
  checkbox chk_retB "保留子物体" pos:[10,65] width:105 height:15 checked:false
  checkbox chk_retA "保留父级关系" pos:[10,50] width:105 height:15 checked:false
  checkbox chk_rep "替换原骨骼" pos:[10,100] width:145 height:15 checked:false
  GroupBox grp_set "设置:" pos:[5,85] width:155 height:55
  label lbl_div "分段数:" pos:[20,120] width:50 height:15
  spinner spn_div "" pos:[75,120] width:80 height:16 range:[2,999,3] type:#integer
  button btn_div "分割" pos:[5,145] width:155 height:25
  
  -- 核心分割函数
  fn divideBone2 b num axis:1 =
  ( 
    d = b.transform[axis]     
    pos1 = b.pos
    pos2 = d * b.length -- 使用变换矩阵的X轴作为方向
    
    lastPos = pos1
    newBones = #() 
    for i in 1 to num do
    ( 
      nextPos = pos1 + (d  * ((b.length/num)*i)) 
      x = boneSys.createBone lastPos nextPos b.dir
      append newBones x
      lastPos = nextPos
    ) 
    newBones
  ) 
  
  -- 分割按钮事件
  on btn_div pressed do
  ( 
    sel = for i in selection where classOf i == BoneGeometry collect i
    
    segs = spn_div.value
    txt = "分割骨骼:" + segs as string
    undo txt on
    ( 
      for i in sel do
      ( 
        nb = divideBone2 i segs
        count = nb.count
        
        -- 创建层级关系
        if chk_hier.enabled and chk_hier.checked do
        ( 
          for h in 1 to count do
          ( 
            if h != count do nb[h+1].parent = nb[h] 
          ) 
        ) 
        
        -- 保留父级关系
        if chk_retA.checked do
        ( 
          nb[1].parent = i.parent
        ) 
        
        -- 保留子物体
        if chk_retB.checked do
        ( 
          c = for h in i.children collect h
          for h in c do h.parent = nb[count] 
        ) 
        
        -- 替换或父级到原骨骼
        if chk_rep.checked then
        ( 
          delete i
        ) 
        else if chk_par.enabled and chk_par.checked do
        ( 
          for b in nb do b.parent = i
        ) 
      ) 
    ) 
  ) 
  
  -- UI状态控制
  fn initUI =
  ( 
    chk_par.enabled = not chk_retA.checked and not chk_rep.checked
  ) 
  
  -- 复选框事件
  on chk_par changed state do initUI() 
  on chk_rep changed state do initUI()   
  on chk_retA changed state do initUI() 
  
) 

-- ========================================================================
-- Rollout：骨骼镜像对话框
-- 功能：提供骨骼镜像的参数设置和预览
-- ========================================================================
rollout BoneMirror "骨骼镜像" width:200 height:110
(
    radiobuttons mirrorAxis "镜像轴" pos:[4,4] width:90 height:80 labels:#("X", "XY", "Y", "YZ", "Z", "ZX") columns:2
    radiobuttons mirrorFlip "翻转骨骼轴" pos:[104,4] width:90 height:40 labels:#("Y", "Z") columns:2 default:2
    spinner mirrorOffset "偏移" pos:[104,40] width:90 height:24 type:#worldunits range:[-10000,10000,0] fieldwidth:50 scale:1
    button mirrorOK "确定" pos:[4,80] width:60 height:20
    button mirrorCancel "取消" pos:[72,80] width:60 height:20
    
    -- 局部变量
    local created = #()           -- 创建的镜像骨骼数组
    local selected = #()          -- 原始选择的骨骼数组
    local checkNonBones = true    -- 是否检查非骨骼对象
    
    -- ====================================================================
    -- 函数：递归选择所有子物体
    -- ====================================================================
    fn SelChildren sel =
    (
        if sel.children.count >= 1 then
        (
            for i = 1 to sel.children.count do
            (
                tempsel = sel.children[i]
                append tmparrayforbipsel tempsel
                if tempsel != undefined do SelChildren tempsel
            )
        )
        return tmparrayforbipsel
    )
    
    -- ====================================================================
    -- 函数：选择自己和所有子物体
    -- ====================================================================
    fn SelMeAndChildren sel =
    (
        append tmparrayforbipsel sel
        SelChildren sel
    )
    
    -- ====================================================================
    -- 函数：取消镜像（删除创建的镜像骨骼）
    -- ====================================================================
    fn UnMirror =
    (
        with redraw off
        (
            for i = 1 to created.count do
            (
                delete created[i]
            )
            created.count = 0
            select selected
        )
    )
    
    -- ====================================================================
    -- 函数：替换字符串中的左右标识
    -- 功能：将骨骼名称中的 " L " 和 " R " 互换
    -- ====================================================================
    fn fl_replacestring sourcestr str_L str_R =
    (
        strlength = str_L.count
        if strlength != 0 then
        (
            -- 查找并替换 L 为 R
            if (idx = findstring sourcestr str_L) != undefined then
            (
                sourcestr = replace sourcestr idx strlength str_R
            )
            -- 查找并替换 R 为 L
            else if (idx = findstring sourcestr str_R) != undefined then
            (
                sourcestr = replace sourcestr idx strlength str_L
            )
            else
            (
                -- 如果没有找到，添加镜像标记
                sourcestr += "(mirrored)"
            )
        )
        sourcestr
    )
    
    -- ====================================================================
    -- 函数：镜像选中的骨骼
    -- 参数：axisFactor - 轴向因子（控制哪些轴需要镜像）
    --       flipZ - 是否翻转Z轴
    --       offset - 镜像偏移值
    -- ====================================================================
    fn MirrorSelectedBones axisFactor flipZ offset =
    (
        -- 检查选择集是否为空 --新增检查--
        if selection.count == 0 do return undefined
        -- 定义骨骼结构，包含索引和层级
        struct BoneLevel (index, level)
        local bones = #()
        
        -- 填充骨骼数组，初始化层级为0
        for i = 1 to selection.count do
        (
            bones[i] = BoneLevel i 0
        )
        
        -- 计算每个骨骼的层级深度
        for i = 1 to bones.count do
        (
            local node = selection[bones[i].index]
            local n = 0
            do
            (
                n = n + 1
                node = node.parent
            ) while (node != undefined)
            bones[i].level = n
        )
        
        -- 按层级排序（从根到叶）
        qsort bones (fn myLevel v1 v2 = (v1.level - v2.level))
        
        -- 准备存储新骨骼和父骨骼的数组
        local parents = #()
        local root = selection[bones[1].index].transform.translation
        created.count = 0
        
        -- 遍历排序后的选择集，从上到下浏览层级
        for i = 1 to bones.count do
        (
            local original = selection[bones[i].index]
            if (classof original != BoneGeometry) do
            (
                -- 不是真正的骨骼对象，跳过
                append parents undefined
                continue
            )
            
            -- 获取原始骨骼的起点、终点和Z轴
            local boneStart = original.pos
            local boneEnd = getEndPoint original
            local boneZ = original.dir
            
            -- 对起点和终点应用镜像
            for k = 1 to 3 do
            (
                if (axisFactor[k] < 0) do
                (
                    boneStart[k] = 2.0*root[k] - boneStart[k] + offset
                    boneEnd[k] = 2.0*root[k] - boneEnd[k] + offset
                    boneZ[k] = -boneZ[k]
                )
            )
            
            -- 如果需要，翻转骨骼的Z轴
            if (flipZ) do boneZ = -boneZ
            
            -- 创建原始骨骼的镜像
            local reflection = bonesys.createbone boneStart boneEnd boneZ
            
            -- 从原始骨骼复制所有适用的参数到镜像骨骼
            reflection.backfin = original.backfin
            reflection.backfinendtaper = original.backfinendtaper
            reflection.backfinsize = original.backfinsize
            reflection.backfinstarttaper = original.backfinstarttaper
            reflection.frontfin = original.frontfin
            reflection.frontfinendtaper = original.frontfinendtaper
            reflection.frontfinsize = original.frontfinsize
            reflection.frontfinstarttaper = original.frontfinstarttaper
            reflection.height = original.height
            reflection.name = fl_replacestring original.name " L " " R "
            reflection.sidefins = original.sidefins
            reflection.sidefinsendtaper = original.sidefinsendtaper
            reflection.sidefinssize = original.sidefinssize
            reflection.sidefinsstarttaper = original.sidefinsstarttaper
            reflection.taper = original.taper
            reflection.width = original.width
            reflection.wirecolor = original.wirecolor
            
            -- 将创建的骨骼添加到列表
            append parents reflection
            append created reflection
            
            -- 开始父级分配
            if (original.parent == undefined) do continue
            
            local parent = original.parent
            
            -- 检查父级是否在选中的节点中
            if (not parent.isSelected) then
            (
                -- 如果不在，让原始骨骼和创建的骨骼共享父级
                reflection.parent = parent
            )
            else
            (
                -- 在创建的父级列表中找到适当的父级并分配
                for p = i-1 to 1 by -1 do
                (
                    if (parent == selection[bones[p].index]) do
                    (
                        reflection.parent = parents[p]
                        exit
                    )
                )
            )
        )
        
        -- 选择新创建的骨骼
        if (created.count > 0) do
        (
            clearSelection()
            select created
        )
    )
    
    -- ====================================================================
    -- 函数：调用镜像功能
    -- 参数：u - 是否使用撤销
    -- ====================================================================
    fn CallMirror u =
    (
        -- 从对话框获取参数
        local mirrorAxisValue = mirrorAxis.state
        local mirrorFlipValue = mirrorFlip.state
        local mirrorOffsetValue = mirrorOffset.value
        
        if checkNonBones do
        (
            -- 检查所有选中的节点是否都是骨骼，如果不是则显示警告
            for bone in selection do
            (
                if (classof bone != BoneGeometry) do
                (
                    goOn = queryBox "继续执行吗？" title:"一个或多个选中的节点不是骨骼"
                    if (not goOn) then return undefined
                    checkNonBones = false
                )
            )
        )
        
        -- 设置轴向的负向乘数
        local axisFactor = [1,1,1]
        if (mirrorAxisValue<=2 or mirrorAxisValue==6) do axisFactor.x = -1
        if (mirrorAxisValue>=2 and mirrorAxisValue<=4) do axisFactor.y = -1
        if (mirrorAxisValue>=4) do axisFactor.z = -1
        
        -- 调用镜像函数
        with redraw off
        (
            if u then
            (
                undo "骨骼镜像" on
                (
                    MirrorSelectedBones axisFactor (mirrorFlipValue==2) mirrorOffsetValue
                )
            )
            else
            (
                MirrorSelectedBones axisFactor (mirrorFlipValue==2) mirrorOffsetValue
            )
        )
        
        -- 调整根骨骼位置（如果没有父级）
        for i in selection do
        (
            if i.parent == undefined then
                i.pos.x = -i.pos.x
        )
    )
    
    -- ====================================================================
    -- 事件：对话框打开时
    -- ====================================================================
    on BoneMirror open do
    (
        created.count = 0
        selected.count = 0
        
        -- 保存原始选择
        for i = 1 to selection.count do
        (
            selected[i] = selection[i]
        )
        
        -- 执行预览镜像
        CallMirror false
    )
    
    -- ====================================================================
    -- 事件：镜像轴改变
    -- ====================================================================
    on mirrorAxis changed state do
    (
        UnMirror()
        CallMirror false
    )
    
    -- ====================================================================
    -- 事件：翻转轴改变
    -- ====================================================================
    on mirrorFlip changed state do
    (
        UnMirror()
        CallMirror false
    )
    
    -- ====================================================================
    -- 事件：偏移值改变
    -- ====================================================================
    on mirrorOffset changed state do
    (
        UnMirror()
        CallMirror false
    )
    
    -- ====================================================================
    -- 事件：确定按钮
    -- ====================================================================
    on mirrorOK pressed do
    (
        UnMirror()
        CallMirror true
        destroydialog BoneMirror
    )
    
    -- ====================================================================
    -- 事件：取消按钮
    -- ====================================================================
    on mirrorCancel pressed do
    (
        UnMirror()
        destroydialog BoneMirror
    )
)

--====================================================================
--=======================骨骼属性修改================================
--====================================================================
rollout Modify_Bone_Attributes "骨骼对象修改" width:260 height:500
( 
    -- 存储当前值的变量
    local currentWidth = 0.05
    local currentHeight = 0.05
    local currentLength = 0.05
    local currentTaper = 20

    --------------- 变量 ------------------------------------ 
    local updateFTRFlag = false
    local updateSpinners
    local setSpinnersToZero 
    local EnableAllSpinners
    local DisableAllSpinners 
    local Abs_Rel_State = 1  -- 1为绝对值，0为相对值

    ---- 复制粘贴操作的临时变量 ------------ 
    local tempSideSize,tempSideStartT, tempSideEndT
    local tempFrontSize,tempFrontStartT,tempFrontEndT
    local tempBackSize,tempBackStartT,tempBackEndT
    local tempSideFinState,tempFrontFinState,tempBackFinState
    local tempBufferValid=false

    ---- 撤销操作的临时变量 ------------ 
    local undSideSize=#(),undSideStartT=#(), undSideEndT=#() 
    local undFrontSize=#(),undFrontStartT=#(),undFrontEndT=#() 
    local undBackSize=#(),undBackStartT=#(),undBackEndT=#() 
    local undSideFinState=#(),undFrontFinState=#(),undBackFinState=#() 

    ---- 绝对值和相对值操作的临时变量 ------------ 
    local absSideSize=#(),absSideStartT=#(), absSideEndT=#() 
    local absFrontSize=#(),absFrontStartT=#(),absFrontEndT=#() 
    local absBackSize=#(),absBackStartT=#(),absBackEndT=#() 
    local absSideFinState=#(),absFrontFinState=#(),absBackFinState=#() 
    local locVar1=0
    local locVar2=0

    group "Bone属性修改_精度可自己调节" 
    ( 
        -- 0.001 精度的spinner
        spinner 'spn1_001' "宽度:" pos:[40,25] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.001 align:#left
        spinner 'spn2_001' "高度:" pos:[40,47] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.001 align:#left
        spinner 'spn3_001' "长度:" pos:[40,69] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.001 align:#left
        spinner 'spn4_001' "锥化:" pos:[40,91] width:110 height:16 range:[-9999,100,20] type:#worldunits scale:0.001 align:#left
        
        -- 0.01 精度的spinner
        spinner 'spn1_01' "宽度:" pos:[40,25] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.01 visible:false align:#left
        spinner 'spn2_01' "高度:" pos:[40,47] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.01 visible:false align:#left
        spinner 'spn3_01' "长度:" pos:[40,69] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.01 visible:false align:#left
        spinner 'spn4_01' "锥化:" pos:[40,91] width:110 height:16 range:[-9999,100,20] type:#worldunits scale:0.01 visible:false align:#left
            
        -- 0.1 精度的spinner
        spinner 'spn1_1' "宽度:" pos:[40,25] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.1 visible:false align:#left
        spinner 'spn2_1' "高度:" pos:[40,47] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.1 visible:false align:#left
        spinner 'spn3_1' "长度:" pos:[40,69] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:0.1 visible:false align:#left
        spinner 'spn4_1' "锥化:" pos:[40,91] width:110 height:16 range:[-9999,100,20] type:#worldunits scale:0.1 visible:false align:#left
            
        -- 1 精度的spinner
        spinner 'spn1_10' "宽度:" pos:[40,25] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:1 visible:false align:#left
        spinner 'spn2_10' "高度:" pos:[40,47] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:1 visible:false align:#left
        spinner 'spn3_10' "长度:" pos:[40,69] width:110 height:16 range:[0,9999,0.05] type:#worldunits scale:1 visible:false align:#left
        spinner 'spn4_10' "锥化:" pos:[40,91] width:110 height:16 range:[-9999,100,20] type:#worldunits scale:1 visible:false align:#left
        
        radiobuttons rdo1 "精度:" pos:[180,26] width:55 height:80 labels:#("0.001", "0.01", "0.1", "1") default:1 columns:1
    )  

    group "百分比调整" 
    (
        spinner spnSizePercent "尺寸%:" range:[1,500,20] type:#integer fieldWidth:25 across:6 align:#left offset:[0,5]
        button btnIncreaseSize "+" width:21 height:21 align:#center offset:[25,1] toolTip:"按百分比增大(宽度和高度)"
        button btnDecreaseSize "-" width:21 height:21 align:#center offset:[8,1] toolTip:"按百分比减小(宽度和高度)"
        
        spinner spnLengthPercent "长度%:" range:[1,500,20] type:#integer fieldWidth:25 align:#center offset:[22,5]
        button btnIncreaseLength "+" width:21 height:21 align:#center offset:[32,1] toolTip:"按百分比增大(长度)"
        button btnDecreaseLength "-" width:21 height:21 align:#right offset:[8,1] toolTip:"按百分比减小(长度)"
    )
    
    group "鳍调整工具" 
    ( 
        radiobuttons Abs_Rel_rad "" width:156 height:16 offset:[10,0] labels:#("绝对", "相对") columns:2 align:#left
        
        button Copy_btn "复制" width:67 height:20 across:2 offset:[25,0] align:#left
        button Paste_btn "粘贴" width:67 height:20 offset:[-20,0] align:#right
        
        --label lbl1 "--- 侧鳍 ---" align:#center 
        checkbox Side_Fin_chk "侧鳍启用" width:65 height:18 align:#left
        spinner side_size_spn "尺寸:" width:98 height:16 range:[-9999,9999,5] fieldwidth:60 align:#center
        spinner side_start_spn "起始锥化:" width:131 height:16 range:[-9999,9999,0.1] fieldwidth:60 align:#center offset:[-17,0]
        spinner side_end_spn "末端锥化:" width:125 height:16 range:[-9999,9999,0.1] fieldwidth:60 align:#left offset:[34,0]
        
        --label lbl2 "--- 前鳍 ---" align:#center
        checkbox Front_Fin_chk "前鳍启用" width:65 height:18 align:#left
        spinner front_size_spn "尺寸:" width:98 height:16 range:[-9999,9999,5] fieldwidth:60 align:#center
        spinner front_start_spn "起始锥化:" width:131 height:16 range:[-9999,9999,0.1] fieldwidth:60 align:#center offset:[-17,0]
        spinner front_end_spn "末端锥化:" width:125 height:16 range:[-9999,9999,0.1] fieldwidth:60 align:#left offset:[34,0]
        
        --label lbl3 "--- 后鳍 ---" align:#center
        checkbox Back_Fin_chk "后鳍启用" width:65 height:18 align:#left
        spinner back_size_spn "尺寸:" width:98 height:16 range:[-9999,9999,5] fieldwidth:60 align:#center
        spinner back_start_spn "起始锥化:" width:131 height:16 range:[-9999,9999,0.1] fieldwidth:60 align:#center offset:[-17,0]
        spinner back_end_spn "末端锥化:" width:125 height:16 range:[-9999,9999,0.1] fieldwidth:60 align:#left offset:[34,0]
    )

    -------函数设置------------------
    ----------- Bone属性函数----------------------
    -- 应用到选择集的函数
    fn applyToSelection prop val =
    (
        for obj in selection do
        (
            try (setProperty obj prop val)
            catch (format "错误：% 无此%属性\n" obj.name (prop as string))
        )
    )
    -- 更新可见spinner的函数
    fn updateVisibleSpinners =
    (
        case rdo1.state of
        (
            1: 
            (
                spn1_001.value = currentWidth
                spn2_001.value = currentHeight
                spn3_001.value = currentLength
                spn4_001.value = currentTaper
            )
            2: 
            (
                spn1_01.value = currentWidth
                spn2_01.value = currentHeight
                spn3_01.value = currentLength
                spn4_01.value = currentTaper
            )
            3: 
            (
                spn1_1.value = currentWidth
                spn2_1.value = currentHeight
                spn3_1.value = currentLength
                spn4_1.value = currentTaper
            )
            4: 
            (
                spn1_10.value = currentWidth
                spn2_10.value = currentHeight
                spn3_10.value = currentLength
                spn4_10.value = currentTaper
            )
        )
    )
    -- 切换spinner可见性的函数
    fn updateSpinnerVisibility =
    ( 
        case rdo1.state of
        ( 
            1: 
            ( 
                spn1_001.visible = true
                spn2_001.visible = true
                spn3_001.visible = true
                spn4_001.visible = true  --新增--
                spn1_01.visible = false
                spn2_01.visible = false
                spn3_01.visible = false
                spn4_01.visible = false  --新增--
                spn1_1.visible = false
                spn2_1.visible = false
                spn3_1.visible = false
                spn4_1.visible = false  --新增--
                spn1_10.visible = false
                spn2_10.visible = false
                spn3_10.visible = false
                spn4_10.visible = false  --新增--
            ) 
            2: 
            ( 
                spn1_001.visible = false
                spn2_001.visible = false
                spn3_001.visible = false
                spn4_001.visible = false  --新增--
                spn1_01.visible = true
                spn2_01.visible = true
                spn3_01.visible = true
                spn4_01.visible = true  --新增--
                spn1_1.visible = false
                spn2_1.visible = false
                spn3_1.visible = false
                spn4_1.visible = false  --新增--
                spn1_10.visible = false
                spn2_10.visible = false
                spn3_10.visible = false
                spn4_10.visible = false  --新增--
            ) 
            3: 
            ( 
                spn1_001.visible = false
                spn2_001.visible = false
                spn3_001.visible = false
                spn4_001.visible = false  --新增--
                spn1_01.visible = false
                spn2_01.visible = false
                spn3_01.visible = false
                spn4_01.visible = false  --新增--
                spn1_1.visible = true
                spn2_1.visible = true
                spn3_1.visible = true
                spn4_1.visible = true  --新增--
                spn1_10.visible = false
                spn2_10.visible = false
                spn3_10.visible = false
                spn4_10.visible = false  --新增--
            ) 
            4: 
            ( 
                spn1_001.visible = false
                spn2_001.visible = false
                spn3_001.visible = false
                spn4_001.visible = false  --新增--
                spn1_01.visible = false
                spn2_01.visible = false
                spn3_01.visible = false
                spn4_01.visible = false  --新增--
                spn1_1.visible = false
                spn2_1.visible = false
                spn3_1.visible = false
                spn4_1.visible = false  --新增--
                spn1_10.visible = true
                spn2_10.visible = true
                spn3_10.visible = true
                spn4_10.visible = true  --新增--
            ) 
        ) 
        updateVisibleSpinners() 
    )
    -- 更新微调器数值的函数
    fn updateSpinners = 
    (
        if selection.count > 0 then
        (
            local firstObj = selection[1]
            try
            (
                -- 检查第一个选中对象是否有这些属性
                if hasProperty firstObj #width then
                    currentWidth = firstObj.width
                if hasProperty firstObj #height then
                    currentHeight = firstObj.height
                if hasProperty firstObj #length then
                    currentLength = firstObj.length
                if hasProperty firstObj #taper then  --新增--
                    currentTaper = firstObj.taper  --新增--                    
            )
            catch
            (
                format "无法读取选中对象的属性\n"
            )
        )
        else
        (
            -- 如果没有选中对象，重置为默认值
            currentWidth = 0.05
            currentHeight = 0.05
            currentLength = 0.05
            currentTaper = 20  --新增--
        )
        -- 更新所有可见的spinner
        updateVisibleSpinners()
    )
    
    -- 选择变化回调函数
    fn selectionChanged = 
    (
        updateSpinners()
    )
    
    ----------- 百分比调整属性函数----------------------
    -- 判断是否为标准骨骼
    fn isStandardBone obj = (
        classOf obj == BoneGeometry and (superClassOf obj == GeometryClass) and not (matchPattern (classOf obj as string) pattern:"*Biped*")
    )
    
    -- 按百分比调整尺寸
    fn adjustSizeByPercent increase:true = (
        if selection.count == 0 do return false
        
        undo "调整骨骼大小" on (
            local percent = spnSizePercent.value / 100.0
            local multiplier = 1 + percent
            
            for b in selection where isStandardBone b do (
                try(
                    if isProperty b #width do (
                        local newWidth = if increase then (b.width * multiplier) else (b.width / multiplier)
                        b.width = if b.width >= 10 then (newWidth as integer) as float else newWidth
                    )
                    if isProperty b #height do (
                        local newHeight = if increase then (b.height * multiplier) else (b.height / multiplier)
                        b.height = if b.height >= 10 then (newHeight as integer) as float else newHeight
                    )
                )catch()
            )
        )
    )
    
    -- 按百分比调整长度
    fn adjustLengthByPercent increase:true = (
        if selection.count == 0 do return false
        
        undo "调整骨骼长度" on (
            local percent = spnLengthPercent.value / 100.0
            local multiplier = 1 + percent
            
            for b in selection where isStandardBone b do (
                try(
                    if isProperty b #length do (
                        if increase then b.length = b.length * multiplier
                        else b.length = b.length / multiplier
                    )
                )catch()
            )
        )
    )
    --------鳍调整工具函数--------------------
    ------- 记住绝对值微调器数值的函数 ------------- 
    fn RememberAbsSpinnerValues =
    (
        a = 1
        For i in Selection do
        (     
            absSideSize[a]       =   i.sidefinssize
            absSideStartT[a]     =   i.sidefinsstarttaper
            absSideEndT[a]       =   i.sidefinsendtaper
            absFrontSize[a]     =   i.frontfinsize
            absFrontStartT[a]     =   i.frontfinstarttaper
            absFrontEndT[a]     =   i.frontfinendtaper
            absBackSize[a]       =   i.backfinsize
            absBackStartT[a]     =   i.backfinstarttaper
            absBackEndT[a]       =   i.backfinendtaper
            absSideFinState[a]     =   i.sidefins
            absFrontFinState[a]   =   i.frontfin
            absBackFinState[a]     =   i.backfin
            a = a + 1
        )
    )   

    fn RememberThisSpinnerValue paramOne =
    (
        a = 1
        For i in Selection do
        (     
            case paramOne of 
            (
                #sidefinssize       : absSideSize[a] = i.sidefinssize
                #sidefinsstarttaper    : absSideStartT[a] = i.sidefinsstarttaper
                #sidefinsendtaper    : absSideEndT[a] = i.sidefinsendtaper
                #frontfinsize      : absFrontSize[a] = i.frontfinsize
                #frontfinstarttaper    : absFrontStartT[a] = i.frontfinstarttaper
                #frontfinendtaper    : absFrontEndT[a] = i.frontfinendtaper
                #backfinsize      : absBackSize[a] = i.backfinsize  
                #backfinstarttaper    : absBackStartT[a] = i.backfinstarttaper  
                #backfinendtaper    : absBackEndT[a] = i.backfinendtaper
            )
            a = a + 1
        )
    )           

    ------- 记住撤销数值的函数 ------------- 
    fn RememberUndSpinnerValues =
    (
        a = 1
        For i in Selection do
        (     
            undSideSize[a]       =   i.sidefinssize
            undSideStartT[a]     =   i.sidefinsstarttaper
            undSideEndT[a]       =   i.sidefinsendtaper
            undFrontSize[a]     =   i.frontfinsize
            undFrontStartT[a]     =   i.frontfinstarttaper
            undFrontEndT[a]     =   i.frontfinendtaper
            undBackSize[a]       =   i.backfinsize
            undBackStartT[a]     =   i.backfinstarttaper
            undBackEndT[a]       =   i.backfinendtaper
            undSideFinState[a]     =   i.sidefins
            undFrontFinState[a]   =   i.frontfin
            undBackFinState[a]     =   i.backfin
            a = a + 1
        )
    )   

    fn EqualsThisUndValue paramOne =
    (
        a = 1
        For i in Selection do
        (     
            case paramOne of 
            (
                #sidefinssize       : if ( undSideSize[a] != i.sidefinssize ) then return false
                #sidefinsstarttaper    : if ( undSideStartT[a] != i.sidefinsstarttaper ) then return false
                #sidefinsendtaper    : if ( undSideEndT[a] != i.sidefinsendtaper ) then return false
                #frontfinsize      : if ( undFrontSize[a] != i.frontfinsize ) then return false
                #frontfinstarttaper    : if ( undFrontStartT[a] != i.frontfinstarttaper ) then return false
                #frontfinendtaper    : if ( undFrontEndT[a] != i.frontfinendtaper ) then return false
                #backfinsize      : if ( undBackSize[a] != i.backfinsize   ) then return false
                #backfinstarttaper    : if ( undBackStartT[a] != i.backfinstarttaper   ) then return false
                #backfinendtaper    : if ( undBackEndT[a] != i.backfinendtaper ) then return false
            )
            a = a + 1
        )
        return true
    )           

    fn RememberThisUndValue paramOne =
    (
        a = 1
        For i in Selection do
        (     
            case paramOne of 
            (
                #sidefinssize       : undSideSize[a] = i.sidefinssize
                #sidefinsstarttaper    : undSideStartT[a] = i.sidefinsstarttaper
                #sidefinsendtaper    : undSideEndT[a] = i.sidefinsendtaper
                #frontfinsize      : undFrontSize[a] = i.frontfinsize
                #frontfinstarttaper    : undFrontStartT[a] = i.frontfinstarttaper
                #frontfinendtaper    : undFrontEndT[a] = i.frontfinendtaper
                #backfinsize      : undBackSize[a] = i.backfinsize  
                #backfinstarttaper    : undBackStartT[a] = i.backfinstarttaper  
                #backfinendtaper    : undBackEndT[a] = i.backfinendtaper
            )
            a = a + 1
        )
    )       
    
    ------- 修改复选框的函数 ------------- 
    fn changeChkB paramOne paramState =
    (
          local a = 1
        For i in Selection do
        (
            setProperty i paramOne paramState
            a = a + 1
        )
    )
    
    ------- 修改微调器的函数 ------------- 
    fn changeSpn paramOne paramState rec =
    (   
          local recording = false
        local a = 1
        For i in Selection do
        (       
            flagForeground i true
            if Abs_Rel_State == 1 then
            (
                setProperty i paramOne paramState
            )
            else
            (
                case paramOne of 
                (
                    #sidefinssize       : locVar1 = absSideSize[a] 
                    #sidefinsstarttaper    : locVar1 = absSideStartT[a] 
                    #sidefinsendtaper    : locVar1 = absSideEndT[a] 
                    #frontfinsize      : locVar1 = absFrontSize[a] 
                    #frontfinstarttaper    : locVar1 = absFrontStartT[a] 
                    #frontfinendtaper    : locVar1 = absFrontEndT[a] 
                    #backfinsize      : locVar1 = absBackSize[a] 
                    #backfinstarttaper    : locVar1 = absBackStartT[a] 
                    #backfinendtaper    : locVar1 = absBackEndT[a] 
                )
                
                locVar2 = paramState + locVar1
                setProperty i paramOne locVar2
            )
            flagForeground i false
            a =  a + 1
        )
    )
    ------- 更新Fin组框中3个复选框的函数 ------- 
    fn updateChkBox chkB paramOne =
    (
        local ChkBStateBoneOne = getProperty selection[1] paramOne    
        local FoundDifferent = false  
        for i = 2 to selection.count do
        (
            if ChkBStateBoneOne != (getProperty selection[i] paramOne) do 
            (
                FoundDifferent = true
                exit
            )
        )
        
        chkB.enabled = true
        if FoundDifferent then
        (
            chkB.triState = 2
        )
        else 
        (
            chkB.state = ChkBStateBoneOne
        )   
    )
    
    fn EnableAllSpinners = 
    (
        ------- 侧鳍 -------- 
        Side_Fin_chk.enabled   = true
        side_size_spn.enabled   = true
        side_start_spn.enabled   = true
        side_end_spn.enabled   = true
        
        ------- 前鳍 -------- 
        Front_Fin_chk.enabled   = true
        front_size_spn.enabled   = true
        front_start_spn.enabled = true
        front_end_spn.enabled   = true
        
        ------- 后鳍 -------- 
        Back_Fin_chk.enabled   = true          
        back_size_spn.enabled   = true
        back_start_spn.enabled   = true
        back_end_spn.enabled   = true
    )
    
    fn DisableAllSpinners = 
    (
        ---- 禁用微调器复选框 ----- 
        Front_Fin_chk.state   = false
        Side_Fin_chk.state     = false
        Back_Fin_chk.state     = false
                
        ------- 侧鳍 -------- 
        Side_Fin_chk.enabled   = false
        side_size_spn.enabled   = false
        side_start_spn.enabled   = false
        side_end_spn.enabled   = false
        
        ------- 前鳍 -------- 
        Front_Fin_chk.enabled   = false
        front_size_spn.enabled   = false
        front_start_spn.enabled = false
        front_end_spn.enabled   = false
        
        ------- 后鳍 -------- 
        Back_Fin_chk.enabled   = false          
        back_size_spn.enabled   = false
        back_start_spn.enabled   = false
        back_end_spn.enabled   = false
        
        --- 禁用其他一起操作的内容 -------------- 
        Copy_btn.enabled     = false
        Paste_btn.enabled     = false
        Abs_Rel_Rad.enabled   = false
    )

    ------- 更新Fin组框中12个微调器的函数 ------- 
    fn updateSpn spn paramOne =
    (
        local SpnValueBoneOne = getProperty selection[1] paramOne
        local FoundDifferent = false
        local average = SpnValueBoneOne 
        
        if Abs_Rel_State == 1 then ( 
            for i = 2 to selection.count do
            (
                average = average + (getProperty selection[i] paramOne) 
                if SpnValueBoneOne != (getProperty selection[i] paramOne) do 
                (
                    FoundDifferent = true
                )
            )
            average = average/selection.count

            if FoundDifferent then
            (
                spn.value = average 
            )
            else 
            (
                spn.value = SpnValueBoneOne 
            )
        )
        else ( 
            RememberAbsSpinnerValues() 
            setSpinnersToZero() 
        )
    
    )

    fn setSpinnersToZero =
    (
        For i in selection do
        (
            ------- 侧鳍微调器 -------- 
            Side_Fin_chk.state     = i.sidefins
            side_size_spn.value   = 0.0
            side_start_spn.value   = 0.0
            side_end_spn.value     = 0.0
                
            ------- 前鳍微调器 -------- 
            Front_Fin_chk.state   = i.frontfin
            front_size_spn.value   = 0.0
            front_start_spn.value   = 0.0
            front_end_spn.value   = 0.0

            ------- 后鳍微调器 -------- 
            Back_Fin_chk.state     = i.backfin            
            back_size_spn.value   = 0.0
            back_start_spn.value   = 0.0
            back_end_spn.value     = 0.0
        )
    )

    fn updateFinSpinners =
    (   
        case selection.count of
        (
            0 : 
            (
                DisableAllSpinners() 
            )
            
            1 : 
            (
                if classof selection[1] != BoneGeometry then
                (
                    DisableAllSpinners() 
                )
                else
                (
                    EnableAllSpinners() 
                    
                    Side_Fin_chk.state     = selection[1].sidefins
                    Front_Fin_chk.state   = selection[1].frontfin
                    Back_Fin_chk.state     = selection[1].backfin
            
                    ------- 侧鳍微调器 -------- 
                    side_size_spn.value   = selection[1].sidefinssize
                    side_start_spn.value   = selection[1].sidefinsstarttaper
                    side_end_spn.value     = selection[1].sidefinsendtaper
                        
                    ------- 前鳍微调器 -------- 
                    front_size_spn.value   = selection[1].frontfinsize
                    front_start_spn.value   = selection[1].frontfinstarttaper
                    front_end_spn.value   = selection[1].frontfinendtaper
                    
                    ------- 后鳍微调器 --------         
                    back_size_spn.value   = selection[1].backfinsize
                    back_start_spn.value   = selection[1].backfinstarttaper
                    back_end_spn.value     = selection[1].backfinendtaper
                )     
            )
            default: 
            (           
                updateSpn side_size_spn #sidefinssize
                updateSpn side_start_spn #sidefinsstarttaper            
                updateSpn side_end_spn #sidefinsendtaper                        
                updateSpn front_size_spn #frontfinsize    
                updateSpn front_start_spn #frontfinstarttaper
                updateSpn front_end_spn #frontfinendtaper                                  
                updateSpn back_size_spn #backfinsize          
                updateSpn back_start_spn #backfinstarttaper                
                updateSpn back_end_spn #backfinendtaper
            )
        )
    )
    
    fn UpdateFTRUIforce =
    (
        updateFTRFlag = true
        UpdateFTRUI() 
    )
    
    fn UpdateFTRUI =
    ( 
        if updateFTRFlag == true do
        ( 
            updateFTRFlag = false
            case selection.count of
            ( 
                0 : ( 
                    DisableAllSpinners() 
                  ) 
                1 : ( 
                    if classof selection[1] != BoneGeometry then
                    ( 
                        DisableAllSpinners() 
                    ) 
                    else
                    ( 
                        EnableAllSpinners()     
                        Paste_btn.enabled     = tempBufferValid              
                        Abs_Rel_Rad.enabled   = true
                        RememberUndSpinnerValues() 

                        if Abs_Rel_State == 1 then
                        ( 
                            updateFinSpinners()  -- 修改这里
                            RememberAbsSpinnerValues() 
                            Copy_btn.enabled     = true
                        ) 
                        else
                        ( 
                            RememberAbsSpinnerValues() 
                            setSpinnersToZero() 
                            Copy_btn.enabled     = false
                        ) 
                    ) 
                ) 
                default: 
                (             
                    local foundNonBone = false
                    for i = 1 to selection.count do
                    ( 
                        if classof selection[i] != BoneGeometry then
                        ( 
                            foundNonBone = true
                            exit
                        ) 
                    ) 
                    if foundNonBone == true then
                    ( 
                        DisableAllSpinners() 
                    ) 
                    else
                    ( 
                        Copy_btn.enabled     = false
                        Paste_btn.enabled     = tempBufferValid
                        Abs_Rel_Rad.enabled   = true
                        EnableAllSpinners()                   
                        RememberAbsSpinnerValues() 
                        RememberUndSpinnerValues() 
                        
                        updateChkBox Side_Fin_chk #sidefins
                        updateSpn side_size_spn #sidefinssize
                        updateSpn side_start_spn #sidefinsstarttaper            
                        updateSpn side_end_spn #sidefinsendtaper            
                        updateChkBox Front_Fin_chk #frontfin            
                        updateSpn front_size_spn #frontfinsize    
                        updateSpn front_start_spn #frontfinstarttaper
                        updateSpn front_end_spn #frontfinendtaper                                  
                        updateChkBox Back_Fin_chk #backfin 
                        updateSpn back_size_spn #backfinsize          
                        updateSpn back_start_spn #backfinstarttaper          
                        updateSpn back_end_spn #backfinendtaper
                    ) 
                ) 
            ) 
        ) 
    )

    fn ProcessUndoSpinner paramOne spv =
    (
        if ( not EqualsThisUndValue paramOne ) then
        (
            with redraw off
            (
                local a = 1
                For i in Selection do
                (     
                    flagForeground i true

                    case paramOne of 
                    (
                        #sidefinssize       : setProperty i paramOne          undSideSize[a]
                        #sidefinsstarttaper    : setProperty i paramOne      undSideStartT[a]
                        #sidefinsendtaper    : setProperty i paramOne       undSideEndT[a]
                        #frontfinsize      : setProperty i paramOne         undFrontSize[a]
                        #frontfinstarttaper    : setProperty i paramOne     undFrontStartT[a]
                        #frontfinendtaper    : setProperty i paramOne       undFrontEndT[a]
                        #backfinsize      : setProperty i paramOne         undBackSize[a]
                        #backfinstarttaper    : setProperty i paramOne       undBackStartT[a]
                        #backfinendtaper    : setProperty i paramOne       undBackEndT[a]
                    )
                    flagForeground i false
                    a = a + 1
                )
            )

            undo "修改Fin参数" on
            (
                changeSpn paramOne spv true
            )

            RememberThisUndValue paramOne
        )
    )           

    on Modify_Bone_Attributes open do
    ( 
        -- 注册选择变化回调
        callbacks.addScript #selectionSetChanged "Modify_Bone_Attributes.selectionChanged()" id:#boneAttrCallback
        -- 注册撤销回调
        callbacks.addScript #sceneUndo "Modify_Bone_Attributes.updateSpinners()" id:#boneAttrCallback
        -- 注册重做回调
        callbacks.addScript #sceneRedo "Modify_Bone_Attributes.updateSpinners()" id:#boneAttrCallback
        -- 初始化微调器数值
        updateSpinners() 

        Abs_Rel_State = 1
        Abs_Rel_Rad.state = 1  
        Copy_btn.enabled     = true  
        
        callbacks.addScript #selectionSetChanged "try(Modify_Bone_Attributes.UpdateFTRUIforce())catch()" id:#agFTRUpdate  -- 修改这里
        callbacks.addScript #sceneUndo "try(Modify_Bone_Attributes.UpdateFTRUIforce())catch()" id:#agFTRUpdate  -- 修改这里
        callbacks.addScript #SceneRedo "try(Modify_Bone_Attributes.UpdateFTRUIforce())catch()" id:#agFTRUpdate  -- 修改这里
        registerRedrawViewsCallback Modify_Bone_Attributes.UpdateFTRUI  -- 修改这里
        updateFTRFlag = true
        UpdateFTRUI() 
    )
    on Modify_Bone_Attributes close do
    ( 
        callbacks.removeScripts id:#boneAttrCallback
        unregisterRedrawViewsCallback Modify_Bone_Attributes.UpdateFTRUI  -- 修改这里
        callbacks.removeScripts id:#agFTRUpdate
    )
    -- 所有spinner的change事件
    on spn1_001 buttonDown do undo "修改骨骼宽度" on (currentWidth = spn1_001.value; applyToSelection #width spn1_001.value)
    on spn2_001 buttonDown do undo "修改骨骼高度" on (currentHeight = spn2_001.value; applyToSelection #height spn2_001.value)
    on spn3_001 buttonDown do undo "修改骨骼长度" on (currentLength = spn3_001.value; applyToSelection #length spn3_001.value)
    on spn4_001 buttonDown do undo "修改骨骼锥化" on (currentTaper = spn4_001.value; applyToSelection #taper spn4_001.value)

    on spn1_01 buttonDown do undo "修改骨骼宽度" on (currentWidth = spn1_01.value; applyToSelection #width spn1_01.value)
    on spn2_01 buttonDown do undo "修改骨骼高度" on (currentHeight = spn2_01.value; applyToSelection #height spn2_01.value)
    on spn3_01 buttonDown do undo "修改骨骼长度" on (currentLength = spn3_01.value; applyToSelection #length spn3_01.value)
    on spn4_01 buttonDown do undo "修改骨骼锥化" on (currentTaper = spn4_01.value; applyToSelection #taper spn4_01.value)

    on spn1_1 buttonDown do undo "修改骨骼宽度" on (currentWidth = spn1_1.value; applyToSelection #width spn1_1.value)
    on spn2_1 buttonDown do undo "修改骨骼高度" on (currentHeight = spn2_1.value; applyToSelection #height spn2_1.value)
    on spn3_1 buttonDown do undo "修改骨骼长度" on (currentLength = spn3_1.value; applyToSelection #length spn3_1.value)
    on spn4_1 buttonDown do undo "修改骨骼锥化" on (currentTaper = spn4_1.value; applyToSelection #taper spn4_1.value)

    on spn1_10 buttonDown do undo "修改骨骼宽度" on (currentWidth = spn1_10.value; applyToSelection #width spn1_10.value)
    on spn2_10 buttonDown do undo "修改骨骼高度" on (currentHeight = spn2_10.value; applyToSelection #height spn2_10.value)
    on spn3_10 buttonDown do undo "修改骨骼长度" on (currentLength = spn3_10.value; applyToSelection #length spn3_10.value)
    on spn4_10 buttonDown do undo "修改骨骼锥化" on (currentTaper = spn4_10.value; applyToSelection #taper spn4_10.value)
    -- 所有spinner的changed事件（实时更新，不记录撤销）
    on spn1_001 changed val do (currentWidth = val; applyToSelection #width val)
    on spn2_001 changed val do (currentHeight = val; applyToSelection #height val)
    on spn3_001 changed val do (currentLength = val; applyToSelection #length val)
    on spn4_001 changed val do (currentTaper = val; applyToSelection #taper val)
    
    on spn1_01 changed val do (currentWidth = val; applyToSelection #width val)
    on spn2_01 changed val do (currentHeight = val; applyToSelection #height val)
    on spn3_01 changed val do (currentLength = val; applyToSelection #length val)
    on spn4_01 changed val do (currentTaper = val; applyToSelection #taper val)

    on spn1_1 changed val do (currentWidth = val; applyToSelection #width val)
    on spn2_1 changed val do (currentHeight = val; applyToSelection #height val)
    on spn3_1 changed val do (currentLength = val; applyToSelection #length val)
    on spn4_1 changed val do (currentTaper = val; applyToSelection #taper val)

    on spn1_10 changed val do (currentWidth = val; applyToSelection #width val)
    on spn2_10 changed val do (currentHeight = val; applyToSelection #height val)
    on spn3_10 changed val do (currentLength = val; applyToSelection #height val)
    on spn4_10 changed val do (currentTaper = val; applyToSelection #taper val)

    -- 精度切换事件
    on rdo1 changed stat do
    (
        updateSpinnerVisibility()
    ) 

    --百分比调整控件
    on btnIncreaseSize pressed do (adjustSizeByPercent increase:true)
    on btnDecreaseSize pressed do (adjustSizeByPercent increase:false)
    on btnIncreaseLength pressed do (adjustLengthByPercent increase:true)
    on btnDecreaseLength pressed do (adjustLengthByPercent increase:false)   

    --鳍调整工具按钮事件
    on Abs_Rel_rad changed state do
    (
        undo "绝对值/相对值" on ( 
            EnableAllSpinners() 
            case Abs_Rel_rad.state of 
            (
                1: -- 绝对值
                (
                    Abs_Rel_State = 1
                    updateFinSpinners() 
                    Copy_btn.enabled     = true
                )
                
                2: -- 相对值
                (
                    Abs_Rel_State = 0
                    RememberAbsSpinnerValues() 
                    setSpinnersToZero() 
                    Copy_btn.enabled     = false
                )
            )
        )
    )
    on Side_Fin_chk changed state do
    (
        undo "侧鳍开/关" on
        (
            changeChkB #sidefins state
        )
    )

    on side_size_spn changed state do
        changeSpn #sidefinssize state false
        
    on side_size_spn entered do 
    (
        ProcessUndoSpinner #sidefinssize side_size_spn.value
        if Abs_Rel_State == 0 then 
        (
            side_size_spn.value = 0
            RememberThisSpinnerValue #sidefinssize
        )
    )
    
    on side_start_spn changed state do
        changeSpn #sidefinsstarttaper state false
    
    on side_start_spn entered do 
    (
        ProcessUndoSpinner #sidefinsstarttaper side_start_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #sidefinsstarttaper
            side_start_spn.value = 0
        )
    )

    on side_end_spn changed state do
        changeSpn #sidefinsendtaper state false
    
    on side_end_spn entered do 
    (
        ProcessUndoSpinner #sidefinsendtaper side_end_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #sidefinsendtaper
            side_end_spn.value = 0
        )
    )

    on Front_Fin_chk changed state do
    (
        undo "前鳍开/关" on
        (
            changeChkB #frontfin state
        )
    )
        
    on front_size_spn changed state do
        changeSpn #frontfinsize state false
    
    on front_size_spn entered do 
    (
        ProcessUndoSpinner #frontfinsize front_size_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #frontfinsize
            front_size_spn.value = 0
        )
    )

    on front_start_spn changed state do
        changeSpn #frontfinstarttaper state false
    
    on front_start_spn entered do 
    (
        ProcessUndoSpinner #frontfinstarttaper front_start_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #frontfinstarttaper
            front_start_spn.value = 0
        )
    )

    on front_end_spn changed state do
        changeSpn #frontfinendtaper state false
    
    on front_end_spn entered do 
    (
        ProcessUndoSpinner #frontfinendtaper front_end_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #frontfinendtaper
            front_end_spn.value = 0
        )
    )

    on Back_Fin_chk changed state do
    (
        undo "后鳍开/关" on
        (
            changeChkB #backfin state
        )
    )

    on back_size_spn changed state do
        changeSpn #backfinsize state false
    
    on back_size_spn entered do 
    (
        ProcessUndoSpinner #backfinsize back_size_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #backfinsize
            back_size_spn.value = 0
        )
    )

    on back_start_spn changed state do
        changeSpn #backfinstarttaper state false
    
    on back_start_spn entered do 
    (
        ProcessUndoSpinner #backfinstarttaper back_start_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #backfinstarttaper
            back_start_spn.value = 0
        )
    )

    on back_end_spn changed state do
        changeSpn #backfinendtaper state false
    
    on back_end_spn entered do 
    (
        ProcessUndoSpinner #backfinendtaper back_end_spn.value
        if Abs_Rel_State == 0 then 
        (
            RememberThisSpinnerValue #backfinendtaper
            back_end_spn.value = 0
        )
    )

    on Copy_btn pressed do
    (
        undo "复制" on 
        (   
            tempSideSize       =   side_size_spn.value
            tempSideStartT       =   side_start_spn.value
            tempSideEndT       =   side_end_spn.value
            tempFrontSize       =   front_size_spn.value
            tempFrontStartT     =   front_start_spn.value
            tempFrontEndT       =   front_end_spn.value
            tempBackSize       =   back_size_spn.value
            tempBackStartT       =   back_start_spn.value
            tempBackEndT       =   back_end_spn.value
            tempSideFinState     =   Side_Fin_chk.state
            tempFrontFinState     =   Front_Fin_chk.state
            tempBackFinState     =   Back_Fin_chk.state
            tempBufferValid         =   true
            Paste_btn.enabled       =   tempBufferValid
        )
    )
    
    on Paste_btn pressed do
    (
        undo "粘贴" on 
        (
            For i in Selection do
            (
                i.sidefinssize       =   tempSideSize 
                i.sidefinsstarttaper   =   tempSideStartT 
                i.sidefinsendtaper     =   tempSideEndT 
                i.frontfinsize       =   tempFrontSize 
                i.frontfinstarttaper   =   tempFrontStartT 
                i.frontfinendtaper     =   tempFrontEndT 
                i.backfinsize       =   tempBackSize 
                i.backfinstarttaper   =   tempBackStartT 
                i.backfinendtaper     =   tempBackEndT 
                i.sidefins         =   tempSideFinState 
                i.frontfin         =   tempFrontFinState 
                i.backfin         =   tempBackFinState 
            )
            EnableAllSpinners() 
            updateFinSpinners() 
        )
    )
) 
--================================================================================
--================================================================================
--================================================================================
rollout BoneAdjustmentTool "Bone选择调整工具" width:260 height:270
(
    group "选择控制"
    (
        button 'btnSelectAllBones' "选所有骨" width:55 height:24  toolTip:"选择所有标准骨骼(排除Biped骨骼)" across:4 align:#left
        button 'btnSelectRootBones' "选择根骨" width:55 height:24 offset:[1,0] toolTip:"选择所有Bone骨骼链中的最父级根骨(包括有父对象的Bone骨骼)" align:#left
        button 'btnSelectEndBones' "选末端骨" width:55 height:24 offset:[2,0] toolTip:"选择所有层级中的末端骨骼" align:#left
        button 'btnSelectByColor' "按颜色选" width:55 height:24 offset:[3,0] toolTip:"选择与当前选中骨骼颜色相同的骨骼" align:#left

        button 'btnBoxMode' "外框显示" width:55 height:24 toolTip:"切换外框显示模式" across:4 align:#left
        button 'btnCreateSelEnds' "选建末端" width:55 height:24 offset:[1,0] toolTip:"为当前选择的骨骼创建末端" align:#left
        button 'btnCreateAllEnds' "创建末端" width:55 height:24 offset:[2,0] toolTip:"为所有骨骼创建末端骨骼" align:#left
        button 'btnStraighten' "骨骼打直" width:55 height:24 offset:[3,0] toolTip:"将选择的骨骼链旋转至与父骨骼相同的方向" align:#left

        button 'btnOneKeyEnd' "一键End"  width:55 height:24 toolTip:"批量修改所选骨骼的末端属性" across:4 align:#left
        button 'btnDeleteSelEnds' "删选末端"  width:55 height:24 offset:[1,0] toolTip:"删除当前选择的末端骨骼" align:#left
        button 'btnDeleteAllEnds' "删全末端" width:55 height:24 offset:[2,0] toolTip:"删除所有骨骼的末端骨骼" align:#left
        button 'btnResetDefault' "重置默认"  width:55 height:24 offset:[3,0] toolTip:"恢复默认设置" align:#left
    )
    group "颜色控制" 
    (
        colorPicker cpBoneColor "骨骼颜色:" color:(color 255 210 150) fieldWidth:38 align:#left offset:[0,3]
        button btnApplyColor "应用色" width:42 height:24 across:2 align:#left offset:[96,-26]
        button btnResetColor "重置色" width:42 height:24 align:#right offset:[4,-26] toolTip:"智能重置骨骼颜色(区分BIP和Bone骨骼)"
        button btnGradientColor "渐变色" width:42 height:24 align:#right offset:[-40,-29] toolTip:"从根骨骼到末端骨骼渐变着色，非骨骼根据第一个选中和最后选中对象进行渐变"
        
        label lblPreset "预设颜色:" align:#left offset:[0,0]
        
        -- 第一行预设颜色
        button btnColorRed "春" width:32 height:22 across:6 align:#left offset:[6,1] toolTip:"春绿色" 
        button btnColorGreen "绿" width:32 height:22 align:#left offset:[5,1] toolTip:"绿色"
        button btnColorBlue "蓝" width:32 height:22 align:#left offset:[5,1] toolTip:"蓝色"
        button btnColorYellow "黄" width:32 height:22 align:#left offset:[5,1] toolTip:"黄色"
        button btnColorCyan "青" width:32 height:22 align:#left offset:[5,1] toolTip:"青色"
        button btnColorWhite "粉" width:32 height:22 align:#left offset:[5,1] toolTip:"粉色"
        
        -- 第二行预设颜色
        button btnColorOrange "橙" width:32 height:22 across:6 align:#left offset:[6,1] toolTip:"橙色"
        button btnColorPurple "紫" width:32 height:22 align:#left offset:[5,1] toolTip:"紫色"
        button btnColorLime "柠" width:32 height:22 align:#left offset:[5,1] toolTip:"柠檬绿"
        button btnColorMagenta "品" width:32 height:22 align:#left offset:[5,1] toolTip:"品红色"
        button btnColorTeal "靛" width:32 height:22 align:#left offset:[5,1] toolTip:"靛蓝色"
        button btnColorMaroon "褐" width:32 height:22 align:#left offset:[5,1] toolTip:"褐红色"
        
        -- 第三行预设颜色
        button btnColorViolet "紫" width:32 height:22 across:6 align:#left offset:[6,1] toolTip:"紫红色" 
        button btnColorRoyalBlue "皇" width:32 height:22 align:#left offset:[5,1] toolTip:"纯蓝色"
        button btnColorTurquoise "青" width:32 height:22 align:#left offset:[5,1] toolTip:"青色"
        button btnColorLimeGreen "柠" width:32 height:22 align:#left offset:[5,1] toolTip:"亮绿色"
        button btnColorGold "金" width:32 height:22 align:#left offset:[5,1] toolTip:"金色"
        button btnColorBrightRed "亮" width:32 height:22 align:#left offset:[5,1] toolTip:"亮红色"
    )

    -- ========== 内部变量 ==========
    local boxModeState = false
    local defaultBoneColor = color 174 186 203    
    -- ========== 函数定义 ==========
    
    -- 判断是否为标准骨骼（排除Biped）
    fn isStandardBone obj = (
        classOf obj == BoneGeometry and (superClassOf obj == GeometryClass) and not (matchPattern (classOf obj as string) pattern:"*Biped*")
    )
    
    -- 判断是否为未隐藏的标准骨骼
    fn isStandardBoneNotHidden obj = (
        isStandardBone obj and not obj.isHidden
    )
    
    -- 获取所有标准骨骼
    fn getAllBones = (
        for o in objects where isStandardBoneNotHidden o collect o
    )
    
    -- 获取根骨骼
    fn getRootBones = (
        local roots = #()
        local allBones = getAllBones()
        
        for b in allBones do (
            local isRoot = true
            local parent = b.parent
            
            while parent != undefined and isRoot do (
                if findItem allBones parent > 0 do (
                    isRoot = false
                )
                parent = parent.parent
            )
            
            if isRoot do append roots b
        )
        roots
    )
    
    -- 获取末端骨骼
    fn getEndBones = (
        for o in objects where isStandardBone o and o.children.count == 0 collect o
    )
    
    -- 按颜色获取骨骼
    fn getBonesByColor color = (
        local bones = #()
        for o in objects where isStandardBoneNotHidden o do (
            try(if o.wirecolor == color do append bones o)catch()
        )
        bones
    )
    
    -- 切换外框显示状态
    fn toggleBoxMode = (
        if selection.count == 0 do return false
        
        undo "切换外框显示" on (
            boxModeState = not boxModeState
            btnBoxMode.text = if boxModeState then "取消外框" else "外框显示"
            
            for obj in selection do (
                try(obj.boxmode = boxModeState)catch()
            )
        )
    )
    
    -- 创建所有末端控制
    fn createAllEndControls = (
        undo "Create All Bone Ends" on
        (
            with Animate Off
            (   
                local endbones = #()
                for i in geometry where classof i == BoneGeometry and i.children.count == 0 do
                    append endbones i
                
                for i in endbones do
                (
                    local parentBone = i
                    local parentTrans = parentBone.transform
                    local parentPos = parentTrans.translation
                    local newbone
                    
                    with redraw off
                    (
                        newBone = BoneSys.createBone parentPos (parentPos+6) parentBone.dir
                        newBone.transform = parentTrans
                        in coordSys Local move newBone [parentBone.length,0,0]
        
                        newBone.parent = parentBone
                        newBone.width = parentBone.width * 0.35
                        newBone.height = parentBone.height * 0.4
                        newBone.length = parentBone.length * 0.15
                        newBone.taper = 25
                        newBone.wirecolor = color 228 153 184
                        newBone.boxmode = true
                        newBone.name = parentBone.name + "_End"
                    )
                    redrawViews()
                )
            )
        )
        completeRedraw()
    )
    
    -- 删除所有末端控制
    fn deleteAllEndControls = (
        undo "Delete All Bone Ends" on
        (
            with Animate Off
            (   
                local endbones = for i in geometry where classof i == BoneGeometry and i.children.count == 0 collect i
                
                with redraw off
                (
                    delete endbones
                )
                redrawViews()
            )
        )
        completeRedraw()
    )
    
    -- 创建选择的末端控制
    fn createSelectedEndControls = (
        undo "Create Selected Bone Ends" on
        (
            with Animate Off
            (
                local selBones = for obj in selection where classof obj == BoneGeometry collect obj
                if selBones.count == 0 do return (messageBox "请选择骨骼!" title:"提示")
                
                for bone in selBones do
                (
                    local parentTrans = bone.transform
                    local parentPos = parentTrans.translation
                    local newbone
                    
                    with redraw off
                    (
                        newBone = BoneSys.createBone parentPos (parentPos+6) bone.dir
                        newBone.transform = parentTrans
                        in coordSys Local move newBone [bone.length,0,0]
        
                        newBone.parent = bone
                        newBone.width = bone.width * 0.35
                        newBone.height = bone.height * 0.4
                        newBone.length = bone.length * 0.25
                        newBone.taper = 25
                        newBone.wirecolor = color 228 153 184
                        newBone.boxmode = true
                        newBone.name = bone.name + "_End"
                    )
                    redrawViews()
                )
            )
        )
        completeRedraw()
    )
    
    -- 删除选择的末端控制（修改版：从选中骨骼检索末端）
    fn deleteSelectedEndControls = (
        undo "Delete Selected Bone Ends" on
        (
            with Animate Off
            (
                local selBones = for obj in selection where classof obj == BoneGeometry collect obj
                if selBones.count == 0 do return (messageBox "请选择骨骼!" title:"提示")
                
                -- 收集所有末端骨骼
                local endBonesToDelete = #()
                local bonesToCheck = #()
                
                -- 初始化待检查列表
                for bone in selBones do append bonesToCheck bone
                
                -- 遍历所有骨骼及其子骨骼
                while bonesToCheck.count > 0 do (
                    local currentBone = bonesToCheck[1]
                    deleteItem bonesToCheck 1
                    
                    if currentBone.children.count == 0 then (
                        -- 找到末端骨骼
                        append endBonesToDelete currentBone
                    ) else (
                        -- 添加子骨骼到检查列表
                        for child in currentBone.children where classof child == BoneGeometry do (
                            append bonesToCheck child
                        )
                    )
                )
                
                -- 删除收集到的末端骨骼
                if endBonesToDelete.count > 0 then (
                    with redraw off (
                        delete endBonesToDelete
                    )
                    redrawViews()
                ) else (
                    messageBox "未找到末端骨骼!" title:"提示"
                )
            )
        )
        completeRedraw()
    )
    
    -- 一键末端属性
    fn oneKeyEndProperties = (
        undo "One Key End" on
        (
            with Animate Off
            (
                local selBones = for obj in selection where classof obj == BoneGeometry collect obj
                if selBones.count == 0 do return (messageBox "请选择骨骼!" title:"提示")
                
                for bone in selBones do
                (
                    with redraw off
                    (
                        bone.width = bone.width * 0.35
                        bone.height = bone.height * 0.4
                        bone.length = bone.length * 0.30
                        bone.taper = 25
                        bone.wirecolor = color 228 153 184
                        bone.boxmode = true
                        if findString bone.name "_End" == undefined do (
                            bone.name = bone.name + "_End"
                        )
                    )
                    redrawViews()
                )
            )
        )
        completeRedraw()
    )
    
    -- 骨骼直线化功能
    fn straightenBones = 
    (
        undo "Straighten Bones" on
        (
            if selection.count == 0 do return (messageBox "请先选择骨骼!" title:"提示")
            
            for bone in selection where bone.children.count > 0 do
            (
                local childBone = bone.children[1]
                local bonetype = classof childBone
                
                while childBone != undefined do
                (
                    if keyboard.escPressed do exit
                    
                    if bonetype == Biped_Object then 
                    (
                        biped.setTransform childBone #rotation childBone.parent.transform.rotation true
                    )
                    else 
                    (
                        local newTransform = copy childBone.parent.transform
                        newTransform.pos = childBone.transform.position
                        childBone.transform = newTransform
                    )
                    
                    childBone = if childBone.children.count > 0 then childBone.children[1] else undefined
                    if childBone != undefined do bonetype = classof childBone
                )
            )
            
            completeRedraw()
        )
    )
    -- 应用颜色到选择集
    fn applyColorToSelection col = (
        if selection.count > 0 do (
            undo "修改骨骼颜色" on (
                for obj in selection do (
                    try(obj.wirecolor = col)catch()
                )
            )
            cpBoneColor.color = col
        )
    )
    
    -- 智能重置颜色 - 识别BIP和Bone骨骼并分别重置
    fn intelligentResetColor = (
        if selection.count == 0 do return false
        
        undo "智能重置颜色" on (
            local sel = selection as array
            
            for obj in sel do (
                try (
                    -- 检查是否为Biped骨骼
                    if classof obj == Biped_Object then (
                        local boneName = obj.name as string
                        
                        -- 匹配左右侧（支持空格和下划线分隔符）
                        local isLeftSide = (matchPattern boneName pattern:"* L *") or (matchPattern boneName pattern:"*_L_*") or (matchPattern boneName pattern:"* L") or (matchPattern boneName pattern:"*_L")
                        local isRightSide = (matchPattern boneName pattern:"* R *") or (matchPattern boneName pattern:"*_R_*") or (matchPattern boneName pattern:"* R") or (matchPattern boneName pattern:"*_R")
                        
                        -- 特殊骨骼检测
                        local isSpine = (matchPattern boneName pattern:"*Spine*")
                        local isPelvis = (matchPattern boneName pattern:"*Pelvis*")
                        local isNeck = (matchPattern boneName pattern:"*Neck*")
                        local isHead = (matchPattern boneName pattern:"*Head*")
                        local isFinger0 = (matchPattern boneName pattern:"*Finger0*")
                        local isFinger = (matchPattern boneName pattern:"*Finger*")
                        local isToe = (matchPattern boneName pattern:"*Toe*")
                        local isProp = (matchPattern boneName pattern:"*Prop1*") or (matchPattern boneName pattern:"*Prop2*") or (matchPattern boneName pattern:"*Prop3*")
                        
                        -- 根据骨骼类型分配颜色
                        if isSpine then (
                            obj.wirecolor = (color 8 110 132)
                        )
                        else if isPelvis then (
                            obj.wirecolor = (color 224 198 87)
                        )
                        else if isNeck then (
                            obj.wirecolor = (color 8 110 132)
                        )
                        else if isHead then (
                            obj.wirecolor = (color 166 202 240)
                        )
                        else if isProp then (
                            obj.wirecolor = (color 8 110 132)
                        )
                        else if isLeftSide then (
                            if isFinger0 then (
                                obj.wirecolor = (color 132 6 6)
                            )
                            else if isFinger then (
                                obj.wirecolor = (color 108 8 136)
                            )
                            else if isToe then (
                                obj.wirecolor = (color 108 8 136)
                            )
                            else (
                                obj.wirecolor = (color 28 28 177)
                            )
                        )
                        else if isRightSide then (
                            if isFinger0 then (
                                obj.wirecolor = (color 224 198 87)
                            )
                            else if isFinger then (
                                obj.wirecolor = (color 113 132 6)
                            )
                            else if isToe then (
                                obj.wirecolor = (color 113 132 6)
                            )
                            else (
                                obj.wirecolor = (color 6 132 6)
                            )
                        )
                        else (
                            obj.wirecolor = (color 166 202 240)
                        )
                    )
                    -- 如果是普通骨骼
                    else if classof obj == BoneGeometry then (
                        obj.wirecolor = defaultBoneColor
                    )
                    -- 其他对象类型
                    else (
                        obj.wirecolor = defaultBoneColor
                    )
                ) catch ()
            )
            
            -- 更新颜色选择器显示第一个选中对象的颜色
            try(cpBoneColor.color = sel[1].wirecolor)catch()
        )
        
        true
    )
    
    -- 应用渐变颜色
    fn applyGradientColor = ( 
        if selection.count < 2 do return false  -- 改为至少2个对象
        
        undo "渐变着色" on ( 
            local selArray = selection as array
            
            -- 检查是否存在bone骨骼链
            local hasBoneChain = false
            for b in selArray where isStandardBone b and 
                (b.parent == undefined or (findItem selArray b.parent == 0)) do ( 
                hasBoneChain = true
                exit
            )
            
            -- 如果没有bone骨骼链，按选择顺序渐变
            if not hasBoneChain then (
                local colorStart = selArray[1].wirecolor
                local colorEnd = selArray[selArray.count].wirecolor
                
                -- 对中间对象进行渐变
                for i = 2 to selArray.count-1 do ( 
                    local ratio = (i-1.0)/(selArray.count-1.0) 
                    local r = colorStart.r * (1-ratio) + colorEnd.r * ratio
                    local g = colorStart.g * (1-ratio) + colorEnd.g * ratio
                    local b = colorStart.b * (1-ratio) + colorEnd.b * ratio
                    try(selArray[i].wirecolor = (color r g b))catch() 
                )
            )
            else (
                -- 原有bone骨骼链逻辑
                local processedChains = 0
                
                for b in selArray where isStandardBone b and 
                    (b.parent == undefined or (findItem selArray b.parent == 0)) do ( 
                    
                    local boneChain = #(b) 
                    local currentBone = b
                    
                    while currentBone.children.count > 0 and isStandardBone currentBone.children[1] and 
                        (findItem selArray currentBone.children[1] > 0) do ( 
                        currentBone = currentBone.children[1] 
                        append boneChain currentBone
                    ) 
                    
                    if boneChain.count >= 3 do ( 
                        local colorStart = boneChain[1].wirecolor
                        local colorEnd = boneChain[boneChain.count].wirecolor
                        
                        for i = 2 to boneChain.count-1 do ( 
                            local ratio = (i-1.0)/(boneChain.count-1.0) 
                            local r = colorStart.r * (1-ratio) + colorEnd.r * ratio
                            local g = colorStart.g * (1-ratio) + colorEnd.g * ratio
                            local b = colorStart.b * (1-ratio) + colorEnd.b * ratio
                            try(boneChain[i].wirecolor = (color r g b))catch() 
                        ) 
                        
                        processedChains += 1
                    ) 
                ) 
            )
        ) 
    )
    
    -- ========== 事件处理 ==========
    
    on btnSelectAllBones pressed do (
        local bones = getAllBones()
        select (if bones.count > 0 then bones else #())
    )
    
    on btnSelectRootBones pressed do (
        local bones = getRootBones()
        select (if bones.count > 0 then bones else #())
    )
    
    on btnSelectEndBones pressed do (
        local bones = getEndBones()
        select (if bones.count > 0 then bones else #())
    )
    
    on btnSelectByColor pressed do (
        if selection.count > 0 then (
            try (
                local bones = getBonesByColor selection[1].wirecolor
                select (if bones.count > 0 then bones else #())
            ) catch (
                messageBox "按颜色选择时出错，请确保选择的是有效骨骼对象" title:"错误"
            )
        ) else (
            messageBox "请先选择一个有效的骨骼对象！" title:"提示"
        )
    )
    
    on btnBoxMode pressed do (toggleBoxMode())
    on btnCreateAllEnds pressed do (createAllEndControls())
    on btnDeleteAllEnds pressed do (deleteAllEndControls())
    on btnCreateSelEnds pressed do (createSelectedEndControls())
    on btnDeleteSelEnds pressed do (deleteSelectedEndControls())
    on btnOneKeyEnd pressed do (oneKeyEndProperties())
    on btnStraighten pressed do (straightenBones())
    
    on btnResetDefault pressed do (
        boxModeState = false
        btnBoxMode.text = "外框显示"
    )

        on btnApplyColor pressed do (
        applyColorToSelection cpBoneColor.color
    )
    
    on btnResetColor pressed do (
        intelligentResetColor()
    )
    
    on btnGradientColor pressed do (
        applyGradientColor()
    )
    
    on cpBoneColor changed col do ()
    
    -- 第一行预设颜色按钮事件
    on btnColorRed pressed do (applyColorToSelection (color 0 255 127))
    on btnColorGreen pressed do (applyColorToSelection (color 50 255 50))
    on btnColorBlue pressed do (applyColorToSelection (color 50 50 255))
    on btnColorYellow pressed do (applyColorToSelection (color 32 139 32))
    on btnColorCyan pressed do (applyColorToSelection (color 152 255 152))
    on btnColorWhite pressed do (applyColorToSelection (color 228 153 184))
    
    -- 第二行预设颜色按钮事件
    on btnColorOrange pressed do (applyColorToSelection (color 255 128 0))
    on btnColorPurple pressed do (applyColorToSelection (color 128 0 255))
    on btnColorLime pressed do (applyColorToSelection (color 191 255 0))
    on btnColorMagenta pressed do (applyColorToSelection (color 255 0 128))
    on btnColorTeal pressed do (applyColorToSelection (color 0 128 128))
    on btnColorMaroon pressed do (applyColorToSelection (color 128 0 0))
    
    -- 第三行预设颜色按钮事件
    on btnColorViolet pressed do (applyColorToSelection (color 252 0 252))
    on btnColorRoyalBlue pressed do (applyColorToSelection (color 0 0 252))
    on btnColorTurquoise pressed do (applyColorToSelection (color 0 252 252))
    on btnColorLimeGreen pressed do (applyColorToSelection (color 0 252 0))
    on btnColorGold pressed do (applyColorToSelection (color 252 252 0))
    on btnColorBrightRed pressed do (applyColorToSelection (color 252 0 0))
    
    -- ========== 对话框打开事件 ==========
    on BoneAdjustmentTool open do 
    (        
        -- 设置第一行颜色按钮图像 (缩小尺寸)
        btnColorRed.images = #((bitmap 34 22 color:(color 0 255 127)), undefined, 1, 1, 1, 1, 1)
        btnColorGreen.images = #((bitmap 34 22 color:(color 50 255 50)), undefined, 1, 1, 1, 1, 1)
        btnColorBlue.images = #((bitmap 34 22 color:(color 50 50 255)), undefined, 1, 1, 1, 1, 1)
        btnColorYellow.images = #((bitmap 34 22 color:(color 34 139 34)), undefined, 1, 1, 1, 1, 1)      -- 森林绿
        btnColorCyan.images = #((bitmap 34 22 color:(color 152 255 152)), undefined, 1, 1, 1, 1, 1)      -- 薄荷绿
        btnColorWhite.images = #((bitmap 34 22 color:(color 228 153 184)), undefined, 1, 1, 1, 1, 1)
        
        -- 设置第二行颜色按钮图像
        btnColorOrange.images = #((bitmap 34 22 color:(color 255 128 0)), undefined, 1, 1, 1, 1, 1)
        btnColorPurple.images = #((bitmap 34 22 color:(color 128 0 255)), undefined, 1, 1, 1, 1, 1)
        btnColorLime.images = #((bitmap 34 22 color:(color 191 255 0)), undefined, 1, 1, 1, 1, 1)
        btnColorMagenta.images = #((bitmap 34 22 color:(color 255 0 128)), undefined, 1, 1, 1, 1, 1)
        btnColorTeal.images = #((bitmap 34 22 color:(color 0 128 128)), undefined, 1, 1, 1, 1, 1)
        btnColorMaroon.images = #((bitmap 34 22 color:(color 128 0 0)), undefined, 1, 1, 1, 1, 1)
        
        -- 设置第三行颜色按钮图像 (调整为指定的高对比度颜色)
        btnColorViolet.images = #((bitmap 34 22 color:(color 252 0 252)), undefined, 1, 1, 1, 1, 1)     -- 紫红色
        btnColorRoyalBlue.images = #((bitmap 34 22 color:(color 0 0 252)), undefined, 1, 1, 1, 1, 1)    -- 纯蓝色
        btnColorTurquoise.images = #((bitmap 34 22 color:(color 0 252 252)), undefined, 1, 1, 1, 1, 1)  -- 青色
        btnColorLimeGreen.images = #((bitmap 34 22 color:(color 0 252 0)), undefined, 1, 1, 1, 1, 1)    -- 亮绿色
        btnColorGold.images = #((bitmap 34 22 color:(color 252 252 0)), undefined, 1, 1, 1, 1, 1)       -- 金色
        btnColorBrightRed.images = #((bitmap 34 22 color:(color 252 0 0)), undefined, 1, 1, 1, 1, 1)    -- 亮红色
    )
)
--================================================================================
--=======================骨骼对象属性==========================================
--================================================================================
-- 单独的Object Properties窗口
-- 骨骼对象属性工具

global ObjectPropsFloater
global ObjectPropsFloater_updateFlag = false

global opfSize = [225, 240], opfPos = [300, 200]
global iniFile = "$plugcfg/BoneObjectProperties.ini"

-- 获取INI配置数据
function GetINIConfigData filename section key default =
(
    local res = getINISetting filename section key
    if res == "" then default
    else readValue (stringStream res) 
)

-- 设置INI配置数据
function SetINIConfigData filename section key value =
(
    setINISetting filename section key (value as string) 
)

-- 检查宏录制器是否启用
function isMacroRecorderEnabled = 
(
    (getINISetting (GetMAXIniFile()) "MAXScript" "EnableMacroRecorder") == "1"
) 

------------------------------------------------------------------------- 
-- 骨骼对象属性面板
rollout ObjectPropsRollout "骨骼对象属性" width:260 height:200
(
    --------------- 变量 ------------------------------------ 
    local UpdateOPRUI    -- 声明函数为本地变量

    -------------- 骨骼属性组框元素 ------------------------- 
    group "骨骼属性" 
    (
        checkbox BoneOn_chk "启用骨骼" width:100 height:16 across:2
        button Realign_btn "重新对齐" width:72 height:20

        checkbox Freeze_chk "冻结长度" width:100 height:16 across:2
        button ResetStretch_btn "重置拉伸" width:72 height:20
        
        checkbox AutoAlign_chk "自动对齐" width:100 height:16 across:2  
        button ResetScale_btn "重置缩放" width:72 height:20
        
        checkbox CorrNegStretch_chk "校正负拉伸" width:170 height:16
        
        label MultiLabel "选择了多个骨骼" width:160 height:16 align:#left
        label StretchFactor "拉伸系数: 未定义" width:160 height:16 align:#left
        
        radiobuttons Stretch_rdo "拉伸" width:100  labels:#("无", "缩放", "挤压") columns:1 across:3 offset:[1,0] align:#left
        radiobuttons Axis_rdo "轴向" width:100 labels:#("X", "Y", "Z") columns:1 offset:[50,0] align:#center
        checkbox BoneFlip_chk "翻转" width:50 height:16 offset:[-5,0] align:#right
    )
    ------- 修正负拉伸的函数 ------- 
    fn correctNegativeStretch bone ask =
    (
        local axisIndex, ooscale
        case bone.boneAxis of
        (
            #X: axisIndex = 1
            #Y: axisIndex = 2
            #Z: axisIndex = 3
        )
        
        ooscale = bone.objectOffsetScale
        if (ooscale[axisIndex] < 0) and ((not ask) or (queryBox "修正负拉伸?" title:bone.Name)) do
        (
            ooscale[axisIndex] = -ooscale[axisIndex] 
            axisIndex = axisIndex+2
            if axisIndex > 3 do axisIndex = axisIndex-3
            ooscale[axisIndex] = -ooscale[axisIndex] 
            bone.objectOffsetScale = ooscale
        )
    )

    ------- 重置选中骨骼缩放的函数 ------ 
    fn ResetScaleOfSelectedBones ask =
    (
        -- 定义包含骨骼及其层级的骨骼结构
        struct BoneLevel (index, level) 
        local bones = #() 

        -- 填充骨骼结构数组，初始化层级为0
        for i = 1 to selection.count do
        (
            bones[i] = BoneLevel i 0    
        )

        -- 计算bones数组中每个骨骼的层级，层级是当前骨骼到根节点之间的祖先数量
        for i = 1 to bones.count do
        (
            local node = selection[bones[i].index] 
            local n = 0
            do
            (
                n = n + 1
                node = node.parent
            ) while (node != undefined) 
            bones[i].level = n
        )

        -- 按层级排序bones数组
        qsort bones (fn myLevel v1 v2 = (v1.level - v2.level)) 

        -- 重置bones数组中所有骨骼的缩放
        for i = 1 to bones.count do
        (
            ResetScale selection[bones[i].index] 
            if ask do correctNegativeStretch selection[bones[i].index] false
        )
    )

    on BoneOn_chk changed state do
    (
        undo "启用骨骼" on 
        (
            selection.boneEnable = state
            Freeze_chk.enabled = state    
            AutoAlign_chk.enabled = state
            Stretch_rdo.enabled = state
            Axis_rdo.enabled = state
            ResetStretch_btn.enabled = state
            BoneFlip_chk.enabled = state
            Realign_btn.enabled = state 
            ResetScale_btn.enabled = state
            CorrNegStretch_chk.enabled = state
        )
        if isMacroRecorderEnabled() do format "$.boneEnable=%\n" state to:MacroRecorder
    )

    on Freeze_chk changed state do
    (
        undo "冻结长度" on 
        (
            selection.boneFreezeLength = state
        )
        if isMacroRecorderEnabled() do format "$.boneFreezeLength=%\n" state to:MacroRecorder
    )

    on AutoAlign_chk changed state do
    (
        undo "自动对齐" on 
        (
            selection.boneAutoAlign = state
        )
        if isMacroRecorderEnabled() do format "$ boneAutoAlign=%\n" state to:MacroRecorder
    )

    on Realign_btn pressed do
    (
        undo "重新对齐" on 
        (
            for i in selection do
            (
                i.realignBoneToChild() 
            )
        )
    )

    on ResetStretch_btn pressed do
    (
        undo "重置拉伸" on 
        (
            if CorrNegStretch_chk.state then for b in selection do correctNegativeStretch b false
            for b in selection do b.resetBoneStretch() 
        )
    )

    
    on ResetScale_btn pressed do
    (
        undo "重置缩放" on 
        (
            ResetScaleOfSelectedBones CorrNegStretch_chk.state
        )
    )
    
    on Stretch_rdo changed state do
    (
        undo "拉伸" on 
        (
            local val = #None
            case Stretch_rdo.state of 
            (
                1: val = #None
                2: val = #Scale
                3: val = #Squash
            )
            selection.boneScaleType = val
            if isMacroRecorderEnabled() do format "$.boneScaleType=%\n" val to:MacroRecorder
        )
    )
    
    on Axis_rdo changed state do
    (
        undo "轴向" on 
        (
            local val = #X
            case Axis_rdo.state of 
            (
                1: val = #X
                2: val = #Y
                3: val = #Z
            )
            selection.boneAxis = val
            if isMacroRecorderEnabled() do format "$.boneAxis=%\n" val to:MacroRecorder
        )
    )
    
    on BoneFlip_chk changed state do
    (
        undo "骨骼翻转开关" on 
        (
            selection.boneAxisFlip = state
            if isMacroRecorderEnabled() do format "$.boneAxisFlip=%\n" state to:MacroRecorder
        )
    )

    ------- 更新骨骼属性组框中3个复选框的函数 ------- 
    fn updateChkBox chkB paramOne =
    (
        local ChkBStateBoneOne = getProperty selection[1] paramOne    
        local FoundDifferent = false  
        for i = 2 to selection.count do
        (
            if ChkBStateBoneOne != (getProperty selection[i] paramOne) do 
            (
                FoundDifferent = true
                exit
            )
        )
        
        if FoundDifferent then
        (
            chkB.triState = 2
        )
        else 
        (
            chkB.state = ChkBStateBoneOne
        )   
    )

    fn GetRadioButton paramOne =
    (
        local RdoStateOne = getProperty selection[1] paramOne    
        local FoundDifferent = false  
        for i = 2 to selection.count do
        (
            if RdoStateOne != (getProperty selection[i] paramOne) do 
            (
                FoundDifferent = true
                exit
            )
        )
        
        if FoundDifferent then
        (
            return #nondet
        )
        else 
        (
            return RdoStateOne
        )   
    )

    fn UpdateStretch_rdo x =
    (
        case x of
        (
            #nondet : Stretch_rdo.state = 0
            #None : Stretch_rdo.state = 1
            #Scale : Stretch_rdo.state = 2
            #Squash : Stretch_rdo.state = 3
        )
    )
    
    fn UpdateAxis_rdo x =
    (
        case x of
        (
            #nondet : Axis_rdo.state = 0
            #X : Axis_rdo.state = 1
            #Y : Axis_rdo.state = 2
            #Z : Axis_rdo.state = 3
        )
    )

    fn EnableBoneProperties x =
    (
        Freeze_chk.enabled = x
        AutoAlign_chk.enabled = x
        Realign_btn.enabled = x
        ResetStretch_btn.enabled = x
        ResetScale_btn.enabled = x
        Stretch_rdo.enabled = x
        Axis_rdo.enabled = x
        BoneFlip_chk.enabled = x
        CorrNegStretch_chk.enabled = x
    )
    
    fn GetStretchFactor bone =
    (
        local axisIndex, tm, p
        case bone.boneAxis of
        (
            #X: axisIndex = 1
            #Y: axisIndex = 2
            #Z: axisIndex = 3
        )
        tm = bone.stretchTM
        p = [0,0,0]   
        tm[4] = p
        p[axisIndex] = 1  
        p = p * tm
        return p[axisIndex] 
    )

    fn UpdateOPRUI =
    (
        if ObjectPropsFloater_updateFlag == true do
        (
            ObjectPropsFloater_updateFlag = false
            case selection.count of
            (
                0 : 
                (
                    MultiLabel.text = selection.count as string + " 个骨骼被选择" 
                    StretchFactor.text = "拉伸系数: 未定义" 
                    BoneOn_chk.enabled = false
                    EnableBoneProperties false

                    BoneOn_chk.state = false
                    Freeze_chk.state = true
                    AutoAlign_chk.state = true
                    UpdateStretch_rdo #Scale
                    UpdateAxis_rdo #X
                    BoneFlip_chk.state = false
                )
                1 : 
                (
                    BoneOn_chk.enabled = true
                    BoneOn_chk.state = selection[1].boneEnable
                    EnableBoneProperties BoneOn_chk.state

                    Freeze_chk.state = selection[1].boneFreezeLength
                    AutoAlign_chk.state = selection[1].boneAutoAlign
                    UpdateStretch_rdo selection[1].boneScaleType
                    UpdateAxis_rdo selection[1].boneAxis
                    BoneFlip_chk.state = selection[1].boneAxisFlip

                    if classof selection[1] != BoneGeometry then
                    (
                        MultiLabel.text = "选择的不是骨骼对象" as string
                        StretchFactor.text = "拉伸系数: 未定义" 
                    )
                    else
                    (
                        MultiLabel.text = selection.count as string + " 个骨骼被选择" 
                        StretchFactor.text = "拉伸系数: "+(GetStretchFactor(selection[1]) as string) 
                    )
                )
                default: 
                (
                    local foundNonBone = false
                    for i = 1 to selection.count do
                    (
                        if classof selection[i] != BoneGeometry then
                        (
                            foundNonBone = true
                            exit
                        )
                    )
                    
                    if foundNonBone == true then
                    (
                        MultiLabel.text = "选择中包含非骨骼对象" as string
                    )
                    else
                    (
                        MultiLabel.text = selection.count as string + " 个骨骼被选择" 
                    )
                    StretchFactor.text = "拉伸系数: 未定义" 
                    
                    ---- 处理"启用骨骼"按钮的状态 -- 
                    BoneOn_chk.enabled = true
                    updateChkBox BoneOn_chk #boneEnable

                    if BoneOn_chk.triState == 1 then
                    (
                        EnableBoneProperties true
                    )
                    else
                    (
                        EnableBoneProperties false
                    )

                    ---- 处理"冻结长度"复选框的状态 -- 
                    updateChkBox Freeze_chk #boneFreezeLength
            
                    ---- 处理"自动对齐"复选框的状态 --- 
                    updateChkBox AutoAlign_chk #boneAutoAlign

                    ---- 处理"拉伸"单选按钮的状态 --- 
                    UpdateStretch_rdo (GetRadioButton #boneScaleType) 

                    ---- 处理"轴向"单选按钮的状态 --- 
                    UpdateAxis_rdo (GetRadioButton #boneAxis) 

                    ---- 处理"翻转"复选框的状态 --- 
                    updateChkBox BoneFlip_chk #boneAxisFlip
                )
            )
        )
    )
    
    fn UpdateOPRUINow =
    (
        ObjectPropsFloater_updateFlag = true
        UpdateOPRUI() 
    )
    
    on ObjectPropsRollout open do
    ( 
        CorrNegStretch_chk.state = true
        
        -- 从INI读取窗口位置
        local posX = GetINIConfigData iniFile "Dialog" "Left" 300  
        local posY = GetINIConfigData iniFile "Dialog" "Top" 200
        SetDialogPos ObjectPropsRollout [posX, posY]
        
        -- 添加回调以更新UI
        callbacks.addScript #selectionSetChanged "ObjectPropsFloater_updateFlag = true" id:#OPUpdate
        callbacks.addScript #sceneUndo "ObjectPropsFloater_updateFlag = true" id:#OPUpdate
        callbacks.addScript #sceneRedo "ObjectPropsFloater_updateFlag = true" id:#OPUpdate
        registerRedrawViewsCallback ObjectPropsRollout.UpdateOPRUINow 
        registerTimeCallback ObjectPropsRollout.UpdateOPRUINow 
        ObjectPropsFloater_updateFlag = true -- 设置为更新面板UI
        UpdateOPRUI() 
    ) 

    on ObjectPropsRollout close do
    ( 
        -- 保存窗口位置到INI
        local dialogPos = GetDialogPos ObjectPropsRollout
        SetINIConfigData iniFile "Dialog" "Left" dialogPos.x 
        SetINIConfigData iniFile "Dialog" "Top" dialogPos.y 
        
        -- 关闭面板后不需要回调，删除它们
        unregisterTimeCallback ObjectPropsRollout.UpdateOPRUINow 
        unregisterRedrawViewsCallback ObjectPropsRollout.UpdateOPRUINow
        callbacks.removeScripts id:#OPUpdate
    )
)
--================================================================================
--====================轴向锁定===========================================
--================================================================================
rollout TransformLocksRollout "轴向锁定" width:260 height:170
(
    local lockFlags = #{}
    
    group "位置锁定"
    (
        checkbox 'chkPosAll' "全选" width:50 height:15 align:#left across:4
        checkbox 'chkPosX' "X" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkPosY' "Y" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkPosZ' "Z" width:30 height:15 checked:false align:#left offset:[20,0]
    )

    group "旋转锁定"
    (
        checkbox 'chkRotAll' "全选" width:50 height:15 align:#left align:#left across:4
        checkbox 'chkRotX' "X" width:30 height:15 checked:false align:#left align:#left offset:[20,0]
        checkbox 'chkRotY' "Y" width:30 height:15 checked:false align:#left align:#left offset:[20,0]
        checkbox 'chkRotZ' "Z" width:30 height:15 checked:false align:#left align:#left offset:[20,0]
    )
    
    group "缩放锁定"
    (
        checkbox 'chkSclAll' "全选" width:50 height:15 align:#left across:4
        checkbox 'chkSclX' "X" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkSclY' "Y" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkSclZ' "Z" width:30 height:15 checked:false align:#left offset:[20,0]
    )
    button 'btnApply' "应用锁定" width:201 height:25 align:#center
    
    -- 函数定义必须放在控件声明之后 --
    fn UpdateAllCheck type state = 
    (
        local posX = 90, posY = 140, posZ = 190
        case type of
        (
            #position: (
                chkPosX.checked = state
                chkPosY.checked = state
                chkPosZ.checked = state
                chkPosX.enabled = not state
                chkPosY.enabled = not state
                chkPosZ.enabled = not state
            )
            #rotation: (
                chkRotX.checked = state
                chkRotY.checked = state
                chkRotZ.checked = state
                chkRotX.enabled = not state
                chkRotY.enabled = not state
                chkRotZ.enabled = not state
            )
            #scale: (
                chkSclX.checked = state
                chkSclY.checked = state
                chkSclZ.checked = state
                chkSclX.enabled = not state
                chkSclY.enabled = not state
                chkSclZ.enabled = not state
            )
        )
    )
    
    fn CalculateLockFlags = 
    (
        lockFlags = #{}
        if chkPosAll.checked then lockFlags += #{1..3} else (
            if chkPosX.checked do lockFlags += #{1}
            if chkPosY.checked do lockFlags += #{2}
            if chkPosZ.checked do lockFlags += #{3}
        )
        if chkRotAll.checked then lockFlags += #{4..6} else (
            if chkRotX.checked do lockFlags += #{4}
            if chkRotY.checked do lockFlags += #{5}
            if chkRotZ.checked do lockFlags += #{6}
        )
        if chkSclAll.checked then lockFlags += #{7..9} else (
            if chkSclX.checked do lockFlags += #{7}
            if chkSclY.checked do lockFlags += #{8}
            if chkSclZ.checked do lockFlags += #{9}
        )
    )
    
    fn UpdateLocks = 
    (
        if selection.count == 0 do (
            messagebox "请先选择至少一个对象！" title:"警告"
            return false
        )
        CalculateLockFlags()
        for obj in selection do setTransformLockFlags obj lockFlags
        true
    )
    
    -- 事件处理 --
    
    on chkPosAll changed state do
        UpdateAllCheck #position state
    on chkRotAll changed state do
        UpdateAllCheck #rotation state
    on chkSclAll changed state do
        UpdateAllCheck #scale state
    on btnApply pressed do
    (
        if UpdateLocks() do
            messagebox "锁定设置已成功应用！" title:"操作完成"
    )
)
--================================================================================
--====================轴向继承===========================================
--================================================================================
rollout InheritanceLocksRollout "继承关系" width:260 height:170
(
    local inheritFlags = #{}
    
    Group "位置继承"
    (
        checkbox 'chkPosAll' "全选" width:50 height:15 align:#left across:4
        checkbox 'chkPosX' "X" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkPosY' "Y" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkPosZ' "Z" width:30 height:15 checked:false align:#left offset:[20,0]
    )
    
    Group "旋转继承"
    (
        checkbox 'chkRotAll' "全选" width:50 height:15 align:#left across:4
        checkbox 'chkRotX' "X" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkRotY' "Y" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkRotZ' "Z" width:30 height:15 checked:false align:#left offset:[20,0]
    )
    
    Group "缩放继承"
    (
        checkbox 'chkSclAll' "全选" width:50 height:15 align:#left across:4
        checkbox 'chkSclX' "X" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkSclY' "Y" width:30 height:15 checked:false align:#left offset:[20,0]
        checkbox 'chkSclZ' "Z" width:30 height:15 checked:false align:#left offset:[20,0]
    )
    button 'btnApply' "应用继承设置" width:201 height:25 align:#center
    
    -- 继承关系位掩码定义 --
    fn GetInheritBitArray = 
    (
        /*
        Max继承关系位掩码：
        位置X:1  位置Y:2  位置Z:3
        旋转X:4  旋转Y:5  旋转Z:6
        缩放X:7  缩放Y:8  缩放Z:9
        */
        inheritFlags = #{}
        
        -- 位置继承 --
        if chkPosAll.checked then 
            inheritFlags += #{1..3}
        else (
            if chkPosX.checked do inheritFlags += #{1}
            if chkPosY.checked do inheritFlags += #{2}
            if chkPosZ.checked do inheritFlags += #{3}
        )
        
        -- 旋转继承 --
        if chkRotAll.checked then 
            inheritFlags += #{4..6}
        else (
            if chkRotX.checked do inheritFlags += #{4}
            if chkRotY.checked do inheritFlags += #{5}
            if chkRotZ.checked do inheritFlags += #{6}
        )
        
        -- 缩放继承 --
        if chkSclAll.checked then 
            inheritFlags += #{7..9}
        else (
            if chkSclX.checked do inheritFlags += #{7}
            if chkSclY.checked do inheritFlags += #{8}
            if chkSclZ.checked do inheritFlags += #{9}
        )
        
        inheritFlags
    )
    
    -- 全选/取消逻辑 --
    fn UpdateAllCheck type state = 
    (
        case type of
        (
            #position: (
                chkPosX.checked = state
                chkPosY.checked = state
                chkPosZ.checked = state
                chkPosX.enabled = not state
                chkPosY.enabled = not state
                chkPosZ.enabled = not state
            )
            #rotation: (
                chkRotX.checked = state
                chkRotY.checked = state
                chkRotZ.checked = state
                chkRotX.enabled = not state
                chkRotY.enabled = not state
                chkRotZ.enabled = not state
            )
            #scale: (
                chkSclX.checked = state
                chkSclY.checked = state
                chkSclZ.checked = state
                chkSclX.enabled = not state
                chkSclY.enabled = not state
                chkSclZ.enabled = not state
            )
        )
    )
    
    -- 应用继承设置 --
    fn ApplyInheritance = 
    (
        if selection.count == 0 do (
            messagebox "请先选择至少一个对象！" title:"警告"
            return false
        )
        
        local flags = GetInheritBitArray()
        for obj in selection do setInheritanceFlags obj flags
        
        true
    )
    
    -- 事件处理 --
    on chkPosAll changed state do UpdateAllCheck #position state
    on chkRotAll changed state do UpdateAllCheck #rotation state
    on chkSclAll changed state do UpdateAllCheck #scale state
    
    on btnApply pressed do
    (
        if ApplyInheritance() do
            messagebox "继承设置已成功应用！" title:"操作完成"
    )
)
--================================================================================
--=====================选择生成骨骼=============================================
--================================================================================
rollout boneGeneratorRollout "选择骨骼生成工具" width:260 height:143
(
    group "选择生成骨骼方式"
    (
        button 'btnObjSingleBone' "选对象生成单独骨骼"  width:114 height:28 align:#left offset:[-5,0] across:2 toolTip:"选中对象生成独立的Bone骨骼" 
        button 'btnObjBoneChain' "选对象生成骨骼链条"  width:114 height:28 align:#right offset:[5,0] toolTip:"选中对象按顺序生成骨骼链"
        button 'btnVertSingleBone' "选顶点生成单独骨骼"  width:114 height:28 align:#left offset:[-5,0] across:2 toolTip:"选中模型顶点生成独立的Bone骨骼"
        button 'btnVertBoneChain' "选顶点生成骨骼链条" width:114 height:28 align:#right offset:[5,0] toolTip:"选中模型顶点按顺序生成骨骼链"
        spinner 'spnBoneSize' "骨骼大小" width:100 height:16 align:#center range:[0.01,9999,4] toolTip:"修改需要的骨骼大小，之后生成对应的大小"
    )
    
	on btnObjSingleBone pressed do
	(
	    if selection.count == 0 then
	    (
	        messageBox "请先选择对象！" title:"提示"
	        return false
	    )
	    
	    tempBone = #()
	    boneSize = spnBoneSize.value
	    boneLength = boneSize * 1.5
	    
	    for i = 1 to selection.count do
	    (
	        tempBone[i] = BoneSys.createBone [0,0,0] [0,boneLength,0] [0,0,0]
	        tempBone[i].width = boneSize
	        tempBone[i].height = boneSize
	        tempBone[i].frontfin = true
	        tempBone[i].frontfinsize = 1
	        tempBone[i].transform = selection[i].transform
	        tempBone[i].name = uniquename "Bone"
	        tempBone[i].BoneScaleType = #squash
	    )
	)
	on btnObjBoneChain pressed do
	(
	    if selection.count < 2 then
	    (
	        messageBox "请至少选择2个对象！" title:"提示"
	        return false
	    )
	    
	    tempBone = #()
	    boneSize = spnBoneSize.value
	    
	    tempBone[1] = BoneSys.createBone selection[1].pos selection[2].pos [0,1,0]
	    tempBone[1].width = boneSize
	    tempBone[1].height = boneSize
	    tempBone[1].frontfin = true
	    tempBone[1].frontfinsize = 1
	    
	    for i = 2 to selection.count - 1 do
	    (
	        tempBone[i] = BoneSys.createBone selection[i].pos selection[i+1].pos [0,1,0]
	        tempBone[i].width = boneSize
	        tempBone[i].height = boneSize
	        tempBone[i].frontfin = true
	        tempBone[i].frontfinsize = 1
	        tempBone[i].parent = tempBone[i-1]
	    )
	)
	on btnVertSingleBone pressed do
	(
	    if selection.count != 1 then
	    (
	        messageBox "请只选择一个对象！" title:"错误"
	        return false
	    )
	    
	    local obj = selection[1]
	    local vertPositions = #()
	    local vertNormals = #()
	    local vertIndices = #()
	    local boneSize = spnBoneSize.value
	    local boneLength = boneSize * 1.5
	    
	    -- 判断对象类型并获取选中点
	    if classOf obj == Editable_Poly then
	    (
	        vertIndices = (polyop.getVertSelection obj) as array
	        
	        if vertIndices.count == 0 then
	        (
	            messageBox "请先选择顶点！" title:"错误"
	            return false
	        )
	        
	        for i in vertIndices do
	        (
	            local vertPos = polyop.getVert obj i
	            -- 计算顶点法线：获取关联面的法线平均值
	            local faceList = (polyop.getFacesUsingVert obj #{i}) as array
	            local normalSum = [0,0,0]
	            for fIdx in faceList do
	            (
	                normalSum += polyop.getFaceNormal obj fIdx
	            )
	            local vertNormal = normalize normalSum
	            
	            append vertPositions vertPos
	            append vertNormals vertNormal
	        )
	    )
	    else if classOf obj == Editable_mesh then
	    (
	        vertIndices = (getVertSelection obj) as array
	        
	        if vertIndices.count == 0 then
	        (
	            messageBox "请先选择顶点！" title:"错误"
	            return false
	        )
	        
	        for i in vertIndices do
	        (
	            local vertPos = getVert obj i
	            -- 计算顶点法线：获取关联面的法线平均值
	            local faceList = (meshop.getFacesUsingVert obj #{i}) as array
	            local normalSum = [0,0,0]
	            for fIdx in faceList do
	            (
	                normalSum += getFaceNormal obj fIdx
	            )
	            local vertNormal = normalize normalSum
	            
	            append vertPositions vertPos
	            append vertNormals vertNormal
	        )
	    )
		else if classOf obj == SplineShape or classOf obj == Line then
	    (
	        local splineCount = numSplines obj
	        for s = 1 to splineCount do
	        (
	            local knotSel = getKnotSelection obj s
	            local knotIndices = knotSel as array
	            for k in knotIndices do
	            (
	                local knotPos = getKnotPoint obj s k
	                local fixedNormal = [0,0,1]  -- 固定Y轴朝向
	                append vertPositions knotPos
	                append vertNormals fixedNormal
	            )
	        )
	        
	        if vertPositions.count == 0 then
	        (
	            messageBox "请先选择样条线顶点！" title:"错误"
	            return false
	        )
	    )
	    else
	    (
	        messageBox "请选择可编辑多边形、可编辑网格或样条线对象！" title:"错误"
	        return false
	    )
	    
	    -- 创建单独骨骼
	    local tempBone = #()
	    for i = 1 to vertPositions.count do
	    (
	        local boneStart = vertPositions[i]
	        local boneEnd = boneStart + (normalize vertNormals[i]) * boneLength
	        
	        tempBone[i] = BoneSys.createBone boneStart boneEnd [0,0,1]
	        tempBone[i].width = boneSize
	        tempBone[i].height = boneSize
	        tempBone[i].frontfin = true
	        tempBone[i].frontfinsize = 1
	        tempBone[i].name = uniquename "Bone"
	        tempBone[i].BoneScaleType = #squash
	    )
	    
	    select tempBone
	)
	on btnVertBoneChain pressed do
	(
	    if selection.count != 1 then
	    (
	        messageBox "请只选择一个对象！" title:"错误"
	        return false
	    )
	    
	    local obj = selection[1]
	    local vertPositions = #()
	    local vertIndices = #()
	    local boneSize = spnBoneSize.value
	    
	    -- 判断对象类型并获取选中点
	    if classOf obj == Editable_Poly then
	    (
	        vertIndices = (polyop.getVertSelection obj) as array
	        
	        if vertIndices.count < 2 then
	        (
	            messageBox "请至少选择2个顶点！" title:"错误"
	            return false
	        )
	        
	        for i in vertIndices do
	        (
	            append vertPositions (polyop.getVert obj i)
	        )
	    )
	    else if classOf obj == Editable_mesh then
	    (
	        vertIndices = (getVertSelection obj) as array
	        
	        if vertIndices.count < 2 then
	        (
	            messageBox "请至少选择2个顶点！" title:"错误"
	            return false
	        )
	        
	        for i in vertIndices do
	        (
	            append vertPositions (getVert obj i)
	        )
	    )
	    else if classOf obj == SplineShape then
	    (
	        local splineCount = numSplines obj
	        for s = 1 to splineCount do
	        (
	            local knotSel = getKnotSelection obj s
	            local knotIndices = knotSel as array
	            for k in knotIndices do
	            (
	                append vertPositions (getKnotPoint obj s k)
	            )
	        )
	        
	        if vertPositions.count < 2 then
	        (
	            messageBox "请至少选择2个样条线顶点！" title:"错误"
	            return false
	        )
	    )
	    else
	    (
	        messageBox "请选择可编辑多边形、可编辑网格或样条线对象！" title:"错误"
	        return false
	    )
	    
	    -- 创建骨骼链
	    local tempBone = #()
	    
	    for i = 1 to vertPositions.count do
	    (
	        local boneStart = vertPositions[i]
	        local boneEnd
	        
	        if i < vertPositions.count then
	            boneEnd = vertPositions[i+1]
	        else
	            boneEnd = boneStart + (boneStart - vertPositions[i-1])
	        
	        tempBone[i] = BoneSys.createBone boneStart boneEnd [0,0,1]
	        tempBone[i].width = boneSize
	        tempBone[i].height = boneSize
	        tempBone[i].frontfin = true
	        tempBone[i].frontfinsize = 1
	        tempBone[i].name = uniquename "Bone"
	        tempBone[i].BoneScaleType = #squash
	    )
	    
	    -- 设置父子关系
	    for i = 2 to tempBone.count do
	    (
	        local worldTM = tempBone[i].transform
	        tempBone[i].parent = tempBone[i-1]
	        tempBone[i].transform = worldTM
	    )
	    
	    select tempBone
	)
)
--================================================================================
--===================绘制样条线创建骨骼===========================================
--================================================================================
rollout BoneChainTool "绘制样条线创建骨骼" width:260 height:450
(
    -- UI控件定义
    group "骨骼设置"
    (
        spinner spn_boneCount "骨骼数量:" range:[2,50,8] type:#integer fieldwidth:50 align:#center
        spinner spn_boneSize "骨骼大小:" range:[1,100,5] type:#integer fieldwidth:50 align:#center
        spinner spn_boneTaper "骨骼锥化:" range:[0,100,0] type:#integer fieldwidth:50 align:#center
    )
    
    group "绘制选项"
    (
        radiobuttons rad_drawMode labels:#("绘制于对象", "绘制于栅格") default:1 columns:1
    )
    
    group "操作"
    (
        button btn_draw "开始绘制线条" width:200 height:26
        button btn_select "选择最新样条线" width:200 height:26
        button btn_create "创建骨骼链" width:200 height:26
        button btn_delete "删除所有线条" width:200 height:26
    )
            
    -- 开始绘制线条
    on btn_draw pressed do
    (
        try
        (
            if rad_drawMode.state == 1 then
            (
                if selection.count == 1 then
                (
                    print "在对象上绘制线条"
                    macros.run "PolyTools" "PolyDrawTypeSelection"
                    PolyToolsPolyDraw.Splines()
                )
                else
                (
                    messageBox "请选择一个对象" title:"警告"
                )
            )
            else
            (
                print "在栅格上绘制线条"
                macros.run "PolyTools" "PolyDrawTypeGrid"
                PolyToolsPolyDraw.Splines()
            )
        )
        catch
        (
            print ("绘制线条出错: " + (getCurrentException()))
        )
    )
    -- 选择最新创建的样条线
    on btn_select pressed do
    (
        try
        (
            splines = for obj in objects where superclassof obj == shape collect obj
            if splines.count > 0 then
            (
                -- 按创建时间排序，选择最新的
                qsort splines (fn compareFn a b = if a.handle > b.handle then -1 else 1)
                select splines[1]
                print ("已选中样条线: " + splines[1].name)
            )
            else
            (
                print "场景中没有样条线"
            )
        )
        catch
        (
            print ("选择样条线出错: " + (getCurrentException()))
        )
    )
    -- 删除所有线条
    on btn_delete pressed do
    ( 
        try
        ( 
            -- 只删除名称包含特定前缀的样条线
            splines = for obj in objects where (superclassof obj == shape and matchPattern obj.name pattern:"Line*") collect obj
            if splines.count > 0 then
            ( 
                select splines
                delete selection
                print ("删除了 " + splines.count as string + " 个样条线对象") 
            ) 
            else
            ( 
                print "场景中没有找到脚本创建的样条线对象" 
            ) 
            redrawViews() 
        ) 
        catch
        ( 
            print ("删除线条出错: " + (getCurrentException())) 
        ) 
    )
    
    -- 创建骨骼链
    on btn_create pressed do
    ( 
        try
        ( 
            if selection.count != 1 then
            ( 
                messageBox "请选择一个样条线对象" title:"警告" 
                return false
            ) 
            
            spline = selection[1] 
            if superclassof spline != shape then
            ( 
                messageBox "选中的对象不是样条线" title:"警告" 
                return false
            ) 
            
            boneCount = spn_boneCount.value
            boneSize = spn_boneSize.value
            boneTaper = spn_boneTaper.value
            
            print ("开始创建骨骼链: " + boneCount as string + " 个骨骼") 
            
            disableSceneRedraw()
            
            try
            (
                -- 第一步：在样条线上创建等间距Dummy
                dummies = #()
                dummyCount = boneCount + 1
                
                for i = 0 to (dummyCount - 1) do
                (
                    d = Dummy()
                    d.boxsize = [boneSize * 0.3, boneSize * 0.3, boneSize * 0.3]
                    d.name = "BoneTool_Temp_" + (i as string)
                    
                    pc = Path_Constraint()
                    d.position.controller = pc
                    pc.path = spline
                    pc.follow = true
                    
                    percent = (i as float / (dummyCount - 1)) * 100.0
                    pc.percent = percent
                    
                    append dummies d
                )
                
                redrawViews()
                
                -- 第二步：根据Dummy创建骨骼链
                bones = #()
                
                bones[1] = BoneSys.createBone dummies[1].pos dummies[2].pos [0,0,1]
                bones[1].name = "Bone_01"
                bones[1].width = boneSize
                bones[1].height = boneSize
                bones[1].taper = boneTaper
                
                for i = 2 to boneCount do
                (
                    bones[i] = BoneSys.createBone dummies[i].pos dummies[i+1].pos [0,0,1]
                    bones[i].name = "Bone_" + (if i < 10 then "0" else "") + (i as string)
                    bones[i].width = boneSize
                    bones[i].height = boneSize
                    bones[i].taper = boneTaper
                    bones[i].parent = bones[i-1]
                )
                
                -- 删除临时Dummy
                for d in dummies do
                    delete d
                
                select bones
                print ("成功创建 " + bones.count as string + " 个骨骼")
            )
            catch
            (
                enableSceneRedraw()
                messageBox ("创建骨骼失败：" + (getCurrentException())) title:"错误"
            )
            
            enableSceneRedraw()
            redrawViews()
        ) 
        catch
        ( 
            enableSceneRedraw() 
            print ("创建骨骼出错: " + (getCurrentException())) 
        ) 
    )
)
--================================================================================
--==================生成内嵌Bone===============================================
--================================================================================
rollout YJSCNQB "一键生成内嵌Bone" width:260 height:90
( 
    group "生成内嵌Bone" 
    (
        button 'btn1' "全部生成内嵌Bone" width:105 height:29 align:#center across:2 toolTip:"选中质心后再点击按钮一键生成" 
        button 'btn2' "选定生成内嵌Bone" width:105 height:29 align:#center toolTip:"单独选中bip骨骼后再点击按钮一键生成" 
        checkbox 'chk_useLinkConstraint' "Link约束" width:100 height:20 align:#left checked:true across:2 offset:[-4,0] toolTip:"切换Bone的约束方式" 
        -- 新增尺寸调整滑块 --
        spinner 'spn_boneScale' "Bone大小:" width:130 height:16 range:[0.01,100.0,1.0] align:#right type:#float scale:0.1 offset:[2,3] toolTip:"调整刚生成Bone的宽高"
    )

    local lastGeneratedBones = #() 
    local originalBoneSizes = #()
-----------------函数部分-------------------------------------------------------
-----------------全部生成内嵌Bone-----------------------------------------------  
    fn Create_Counter_Bone = 
    (
        if selection.count == 0 then 
        (
            messageBox "请选中一个Biped骨骼的质心对象" title:"提示"
            return false
        )

        local selObj = selection[1]
        if not (isKindOf selObj Biped_Object) do
        (
            messageBox "选中的对象不是Biped骨骼！" title:"错误" beep:false
            return false
        )   
        local bipNamePattern = @"^Bip\d{3}$"  -- 名称必须严格为 Bip + 3位数字
        local regex = dotNetObject "System.Text.RegularExpressions.Regex" bipNamePattern

        if not (regex.IsMatch selObj.name) do
        (
            messageBox "选中的Biped骨骼不是质心（名称不符合 Bip### 格式）！" title:"错误" beep:false
            return false
        )

        -- 收集骨骼 ---- 精准过滤Footsteps --
        local bipPrefix = selObj.name
        local bipedBones = for obj in objects where 
        isKindOf obj Biped_Object and 
        matchPattern obj.name pattern:(bipPrefix + " *") and 
        obj != selObj and 
        not (matchPattern obj.name pattern:"*Footsteps*") and  -- 过滤Footsteps
        not (isProperty obj #footstep) collect obj  -- 双重过滤
        
        -- 第二部分：安全结构体定义 --
        local structName = uniqueName "BoneStruct_"
        execute ("struct " + structName + " (srcBiped, boneNode, parentName)")
        
        -- 第三部分：骨骼创建函数 --
        fn createBoneFromBiped bipedBone boneStructType = 
        (
            -- 安全位置计算 --
            local startPos = bipedBone.transform.translation
            local endPos = if bipedBone.children.count > 0 then 
                bipedBone.children[1].transform.translation 
            else 
                startPos + (bipedBone.transform.row3 * 15)  -- 默认延长
            
            -- 创建骨骼 --
            local newBone = BoneSys.createBone startPos endPos [0,1,0]
            newBone.name = "Bone_" + bipedBone.name
            try(newBone.width = bipedBone.width)catch(newBone.width = 5)
            try(newBone.height = bipedBone.height)catch(newBone.height = 5)
            newBone.boneEnable=false
            newBone.transform = bipedBone.transform
            
            -- 返回结构体实例 --
            boneStructType srcBiped:bipedBone boneNode:newBone parentName:(if bipedBone.parent != undefined then bipedBone.parent.name else "")
        )
    
        -- 第四部分：主处理流程 --
        local boneDataArray = #()
        
        for b in bipedBones do
        (
            try (
                -- 创建结构体实例（使用动态类型）--
                local boneData = createBoneFromBiped b (execute structName)
                append boneDataArray boneData
            ) catch (
                format "[ERROR] 无法处理骨骼 %：%\n" b.name (getCurrentException())
            )
        )
        
        -- 建立层级关系 --
        for data in boneDataArray do
        (
            if data.parentName != "" do
            (
                local parentBoneName = "Bone_" + data.parentName
                local parentBone = getNodeByName parentBoneName
                if parentBone != undefined do data.boneNode.parent = parentBone
            )
        )
        
        -- 第五部分：动态约束系统 -- 
        if boneDataArray.count > 0 do
        ( 
            local constraintSuccess = 0
          
            for data in boneDataArray do
            ( 
                try 
                ( 
                    local targetBiped = data.srcBiped
                    local boneNode = data.boneNode
              
                    -- 根据开关选择约束类型 --
                    if chk_useLinkConstraint.checked then
                    (
                        -- Link约束 --
                        if classOf boneNode.transform.controller != Link_Constraint do
                        ( 
                          linkConstraint = Link_Constraint() 
                          boneNode.transform.controller = linkConstraint
                          linkConstraint.addTarget targetBiped 0
                          boneNode.transform = targetBiped.transform
                        ) 
                    )
                    else
                    (
                        -- 位置+方向约束 --
                        if classOf boneNode.pos.controller != Position_Constraint do
                        ( 
                          posConstraint = Position_Constraint() 
                          posConstraint.relative = off
                          posConstraint.appendTarget targetBiped 100.0
                          boneNode.pos.controller = posConstraint
                        ) 
                        
                        if classOf boneNode.rotation.controller != Orientation_Constraint do
                        ( 
                          rotConstraint = Orientation_Constraint() 
                          rotConstraint.appendTarget targetBiped 100.0
                          boneNode.rotation.controller = rotConstraint
                        ) 
                    )
                    constraintSuccess += 1
                ) 
                catch  
                ( 
                    format "[约束错误] %：%\n" boneNode.name (getCurrentException()) 
                ) 
            ) 
        )
        
        -- 第六部分：最终处理 --
        if boneDataArray.count > 0 then
        (
            lastGeneratedBones = for d in boneDataArray collect d.boneNode
            originalBoneSizes = for bone in lastGeneratedBones collect [bone.width, bone.height]
            select (for d in boneDataArray collect d.boneNode)
            messageBox ("成功创建,约束完成：成功添加" + boneDataArray.count as string + " 个Bone骨骼") title:"完成"
            
        )
        else
        (
            messageBox "未创建任何骨骼，请检查过滤条件！" title:"警告"
        )
    )
-------------------局部选定生成内嵌Bone--------------------------------------
    fn Create_Local_Bone = 
    (
            -- 第一步：增强类型检查 --
        fn isBipedBone obj = 
        (
            isKindOf obj Biped_Object and 
            not matchPattern obj.name pattern:"*Footsteps*" and
            classOf obj.controller == BipSlave_Control
        )

        -- 第二步：选择验证 --
        if selection.count == 0 then 
        (
            messageBox "请选中一个Biped骨骼对象" title:"提示"
            return #()
        )

        local selBipeds = #()
        for obj in selection do 
        (
            if isBipedBone obj then 
            (
                append selBipeds obj
            ) 
            else
            (
                messageBox ("选中的对象 '" + obj.name + "' 不是有效Biped骨骼！") title:"错误"
                return #()
            )
        )

        -- 第三步：安全创建骨骼 --
        struct BoneInfo (biped, bone)
        local boneDataArr = #()

        with redraw off undo off 
        (
            for biped in selBipeds do 
            (
                try 
                (
                    -- 获取Biped变换矩阵 --
                    local bipedTM = biped.transform
                    local startPos = bipedTM.translation
                    local zAxis = bipedTM.row3
                    
                    -- 智能计算末端位置 --
                    local endPos = startPos + zAxis * 10  -- 默认长度10单位
                    if biped.children.count > 0 and isBipedBone biped.children[1] do 
                    (
                        endPos = biped.children[1].transform.translation
                    )
                    
                    -- 创建骨骼并匹配属性 --
                    local newBone = BoneSys.createBone startPos endPos [0,1,0]
                    newBone.name = "Bone_" + biped.name
                    newBone.transform = bipedTM
                    newBone.parent = biped
                    -- 尺寸适配 --
                    try(newBone.width = biped.controller.width)catch(newBone.width = 5.0)
                    try(newBone.height = biped.controller.height)catch(newBone.height = 5.0)
                    
                    append boneDataArr (BoneInfo biped:biped bone:newBone)
                )
                catch 
                (
                    format "[创建错误] %：%\n" biped.name (getCurrentException())
                )
            )
        )

        -- 第四部分：动态约束 -- 
        if boneDataArr.count > 0 do 
        ( 
            for data in boneDataArr do 
            ( 
                try 
                ( 
                    -- 根据开关选择约束类型 --
                    if chk_useLinkConstraint.checked then
                    (
                        -- Link约束 --
                        if classOf data.bone.transform.controller != Link_Constraint do 
                        ( 
                          data.bone.transform.controller = Link_Constraint() 
                          data.bone.transform.controller.addTarget data.biped 0
                        ) 
                    )
                    else
                    (
                        -- 位置+方向约束 --
                        if classOf data.bone.pos.controller != Position_Constraint do 
                        ( 
                        data.bone.pos.controller = Position_Constraint() 
                        data.bone.pos.controller.appendTarget data.biped 100.0
                        ) 
                    
                        if classOf data.bone.rotation.controller != Orientation_Constraint do 
                        ( 
                            data.bone.rotation.controller = Orientation_Constraint() 
                            data.bone.rotation.controller.appendTarget data.biped 100.0
                        ) 
                    )
                ) 
                catch 
                ( 
                format "[约束错误] %：%\n" data.bone.name (getCurrentException()) 
                ) 
            ) 
        )

        -- 完成处理 --
        enableSceneRedraw()
        resumeEditing()

        if boneDataArr.count > 0 then 
        (
            lastGeneratedBones = for d in boneDataArr collect d.bone
            originalBoneSizes = for bone in lastGeneratedBones collect [bone.width, bone.height]
            select (for d in boneDataArr collect d.bone)
            messageBox ("成功生成 " + boneDataArr.count as string + " 个Bone骨骼") title:"完成"
        ) 
        else 
        (
            messageBox "没有生成任何骨骼！" title:"警告"
        )

        gc()

    )       
----------------层集分类-----------------------------------------------------------------   
    fn autoSortBipedBone = 
    (
        -- 自动收集所有符合名称规则的物体
        local targetObjs = for o in objects where matchPattern o.name pattern:"*Bone_Bip*" collect o
        
        -- 创建/更新层
        local layer = LayerManager.getLayerFromName "Bone_Bip"
        if layer == undefined then 
        (
            layer = LayerManager.newLayerFromName "Bone_Bip"
           
        )
         -- 逐个添加物体到层（兼容 3ds Max 2016）
        for obj in targetObjs do
        (
            layer.addNode obj
        )
        
        -- 创建/覆盖选择集
        selectionSets["Bone_Bip"] = targetObjs
        
        redrawViews()
        format "已分类 % 个Face_ExPoint物体\n" targetObjs.count
        true
    )
    
-----------------按钮事件---------------------------------------------------------
    on btn1 pressed  do
    (
        undo on
        (
            Create_Counter_Bone()
            autoSortBipedBone()
        )
    )
    on btn2 pressed  do
    (
        undo on
        (
            Create_Local_Bone()
            autoSortBipedBone()
        )
    )
    on chk_useLinkConstraint changed state do
    ( 
        if state then
          chk_useLinkConstraint.text = "Link约束"
        else
          chk_useLinkConstraint.text = "位置+方向约束"
    ) 
    on spn_boneScale changed val do
    (
        if lastGeneratedBones.count > 0 do
        (
            for i = 1 to lastGeneratedBones.count where isValidNode lastGeneratedBones[i] do
            (
                try
                (
                    lastGeneratedBones[i].width = originalBoneSizes[i][1] * val
                    lastGeneratedBones[i].height = originalBoneSizes[i][2] * val
                )
                catch()
            )
        )
    )
)
--================================================================================
--===========================距离测量工具===============================================
--================================================================================
rollout DistanceMeasurer "距离测量工具" width:260 height:110
(
    group "测距" 
    (
        edittext 'distanceResult' "距离:" width:210 height:18 readonly:true align:#center
        button 'measureBtn' "测量距离" width:100 height:24 across:2
        button 'copyBtn' "复制结果" width:100 height:24
        label 'infoLbl' "请先选中两个对象" width:100 height:20 align:#center
    )

    fn calculateDistance = (
        if selection.count >= 2 then (
            -- 计算距离（单位与场景设置一致）
            dist = distance $[1] $[2]
            
            -- 格式化显示（保留4位小数）
            formattedDist = formattedPrint dist format:".4f"
            distanceResult.text = formattedDist 
            infoLbl.text = "测量完成！"
            
            -- 在视口中绘制连线（可选）
            try (
                deleteObjects (for obj in objects where matchPattern obj.name pattern:"DistanceLine*" collect obj)
                lineObj = line name:(uniqueName "DistanceLine") vertices:#($[1].pos, $[2].pos)
                setUserProp lineObj "Distance" dist
            ) catch ()
            
            true
        ) else (
            distanceResult.text = ""
            infoLbl.text = "需要选中至少两个对象！"
            false
        )
    )
    
    on measureBtn pressed do (
        calculateDistance()
    )
    
    on copyBtn pressed do (
        if distanceResult.text != "" then (
            setClipboardText distanceResult.text
            infoLbl.text = "结果已复制到剪贴板！"
        ) else (
            infoLbl.text = "请先测量距离！"
        )
    )
    
    -- 自动测量（选中两个对象时）
    on selection changed do (
        if selection.count == 2 do (
            calculateDistance()
        )
    )
)
--================================================================================
--======================命名-层集-检查-工具===========================================
--================================================================================
global mainPos = [97,561]

global prefix_item = #("Bip001", "Bone")
global positon_item = #("没有", "F（前）", "B（后）", "L（左）", "R（右）", "FL（左前）", "FR（右前）", "BL（左后）", "BR（右后）", "T（顶部）", "BT（底部）", "M（中间）")
global boneName_item = #("Ribbon（飘带）", "Cloth（衣服）", "Jianjia（肩甲）","Yaodai（腰带）", "Sleeve（袖子）", "Mouth（嘴巴）", "Hair（头发）", "Eye（眼睛）", "Eehuan（耳环）", "Skirt（裙子）", "Zhuangshi（装饰）", "Tail（尾巴）", "Beard（胡子）", "chibang（翅膀）", "Weapon（武器）")
global prefix = prefix_item[1]
global position = ""
global boneName = boneName_item[1]
global presetNum = 1

global self_prefix = ""
global self_position = ""
global self_boneName = ""
global self_Num = 1

global space = true
global underLine = false

global breakWord = " "

global all_sub = #()
global current_selected = #()
global a = 0

global sameNameOBJ = #()
global sameNameArray = #()
global sameNameListPos = mainPos + [415,83]

fn result =
(
	if sameNameOBJ.count == 0 then
	(
		MessageBox ("OK，场景中没有重名的物体！" ) 
	)
	else
	(
		createDialog sameNameList pos:sameNameListPos
	)
)

fn checkSameName =
(
	sameNameOBJ = #()
	sameNameArray = #()
	for i=1 to objects.count do
	(
		for j=i+1 to objects.count do
		(
			if objects[i].name == objects[j].name then
			(
				if (findItem sameNameOBJ objects[i]) == 0 then
				(
					append sameNameOBJ objects[i]
				)
				
				if (findItem sameNameOBJ objects[j]) == 0 then
				(
					append sameNameOBJ objects[j]
				)
			)
		)
	)
	
	for i in sameNameOBJ do
	(
		append sameNameArray i.name
	)
)

--------------------以上都是renameBone命名工具的变量和函数---------------------
rollout sameNameList "重名物体" width:120 height:145
(
	Group "双击选中物体"
	(
		multiListBox list "" width:95 Height:6 items:sameNameArray
		button refrash "刷新" width:80 Height:20
	)
		
	on list doubleClicked val do
	(
		select sameNameOBJ[val] 
	)
	
	on refrash pressed do
	(
		checkSameName()
		sameNameListPos = getDialogpos sameNameList
		destroyDialog sameNameList
		result()
	)
)
rollout rename "骨骼重命名" width:402 height:228
(
	groupBox grp1 "预设" pos:[7,4] width:386 height:80
	dropDownList ddl1 "前缀" pos:[18,31] width:69 height:41 items:prefix_item selection:2
	dropDownList ddl2 "方位" pos:[96,31] width:69 height:41 items:positon_item
	dropDownList ddl3 "名称" pos:[175,31] width:69 height:41 items:boneName_item
	spinner spn1 "" pos:[256,52] width:43 height:16 range:[0,999,1] type:#integer scale:1
	label lbl11 "序号" pos:[257,32] width:32 height:15
	button btn1 "重置" pos:[313,19] width:70 height:22
	button btn2 "重命名" pos:[313,52] width:70 height:22
	
	groupBox grp2 "自定义" pos:[7,85] width:386 height:80
	label lbl1 "前缀" pos:[18,116] width:46 height:17
	label lbl2 "方位" pos:[96,116] width:46 height:17
	label lbl4 "名称" pos:[175,116] width:46 height:17	
	editText edt1 "" pos:[15,136] width:67 height:20
	editText edt2 "" pos:[93,136] width:67 height:20
	editText edt3 "" pos:[175,136] width:67 height:20
	spinner spn2 "" pos:[256,139] width:43 height:16 range:[0,999,1] type:#integer scale:1
	label lbl12 "序号" pos:[257,119] width:32 height:15
	button btn3 "重置" pos:[313,99] width:70 height:22
	button btn4 "重命名" pos:[313,132] width:70 height:22
	
	groupBox grp3 "分隔符" pos:[7,169] width:125 height:52
	checkbox chk1 "空格" pos:[16,192] width:50 height:18 
	checkbox chk2 "下划线" pos:[67,192] width:58 height:18 checked:true
	
	button btn5 "选择所有子骨骼" pos:[137,176] width:97 height:43 enabled:false
	button btn6 "检查是否有重名" pos:[240,176] width:97 height:43
	
	fn break_with =
	(
		if space and underLine then (breakWord = " _")
		else if space and underLine == false then (breakWord = " ")
		else if space==false and underLine then (breakWord = "_")
		else (breakWord = "")
	)
	
	fn clearUpNote word =
	(
		if word == "没有" or word == "" then (word = "")
		else 
		(
			noteBegin = findString word "（"
			noteEnd = word.count
			word = replace word noteBegin (noteEnd - noteBegin + 1) ""
		)
		return word
	)
	
	fn numToStr num =
	(
		if num==0 then (num = "")
		else if num>0 and num<10 then (num ="0" + (num as string))
		else (num = num as string) 
	)
	
	fn posCheck pos =
	(
		if pos=="没有" or pos=="" then(pos = "")
		else
		(
			break_with()
			pos = breakWord + pos
		)
		return pos
	)
	

	
	on rename close do
	(
		try (destroyDialog sameNameList) catch()
	)

	on rename moved pos do (mainPos = pos)	
	
	on ddl1 selected val do (prefix = prefix_item[val])
	
	on ddl2 selected val do (position = positon_item[val])
	
	on ddl3 selected val do (boneName = boneName_item[val])
	
	on edt1 changed txt do (self_prefix = txt;edt1.text = txt)
	
	on edt2 changed txt do (self_position = txt;edt2.text = txt)
	
	on edt3 changed txt do (self_boneName = txt;edt3.text = txt)
	
	on spn1 changed val do (presetNum = val)
	
	on spn2 changed val do(self_Num = val)
	
	on chk1 changed state do (if state then (space = true) else (space = false))
	
	on chk2 changed state do (if state then (underLine = true) else(underLine = false))
	
	on btn1 pressed do
	(
		ddl1.selection = ddl2.selection = ddl3.selection =1
		spn1.range = [0,999,1]
	)
	
	on btn2 pressed do
	(
		break_with()
		count = presetNum
		for i=1 to selection.count do
		(
			selection[i].name = prefix +
								posCheck(clearUpNote(position)) + 
								breakWord + clearUpNote(boneName) + 
								numToStr(count)
			count += 1
		)
	)
	
	on btn3 pressed do
	(
		edt1.text = edt2.text = edt3.text = ""
		spn2.range = [0,999,1]
	)
	
	on btn4 pressed do
	(
		break_with()
		count = self_Num
		for i=1 to selection.count do
		(
			selection[i].name = self_prefix +
								posCheck(self_position) +
								breakWord + self_boneName +
								numToStr(count)
			count += 1
		)
	)
	
	on btn5 pressed do
	(

	)
	
	on btn6 pressed do
	(
		checkSameName()
		result()
	)
)
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
rollout NLCheckTool "命名-层集-检查-工具" width:260 height:360
(
	Group "对象命名"
	(
		label 'lab1' "选中的对象" width:64 height:18 align:#left across:3 offset:[-2,3]
		edittext 'edt1' "" width:105 height:18 align:#center  offset:[-4,0]
		button 'btn1' "重命名" width:63 height:28 align:#right offset:[7,-6] toolTip:"选中对象开始重命名，命名前缀输入框内容，后缀从001开始排序" align:#left
	) 
	Group "层级命名"
	(
		label 'lab2' "层级" width:47 height:18 align:#left across:3 offset:[16,3]
		edittext 'edt2' "" width:105 height:18 align:#center  offset:[-4,0]
		button 'btn2' "生成层" width:63 height:28 align:#right offset:[7,-6] toolTip:"选中对象开始自动创建层，层命名为输入框内容" align:#left
	)
	Group "选择集命名"
	(
		label 'lab3' "选择集" width:47 height:18 align:#left across:3 offset:[10,3]
		edittext 'edt3' "" width:105 height:18 align:#center  offset:[-4,0]
		button 'btn3' "生成集" width:63 height:28 align:#right offset:[7,-6] toolTip:"选中对象开始自动创建集合，集合命名为输入框内容" align:#left
	)
	Group "命名缩放修复工具——检查命名缩放"
	(
		button 'btn4' "清空层" width:100 height:28 across:2 toolTip:"点击按钮后，删除所有空的层" 
		button 'btn5' "清空集" width:100 height:28 toolTip:"点击按钮后，删除所有的集合" 

		button 'renameBone' "命名工具" width:100 height:28 across:2
		button 'btnRename' "骨骼镜像重命" width:100 height:28 toolTip:"
		-- 骨骼镜像重命名插件
		-- 作者: 一方狂三
		-- 功能: 自动重命名镜像骨骼，处理Mirror后缀和L/R方向标识
		-- 使用说明:
		-- 1. 点击重命名镜像骨骼执行所有操作
		-- 2. 插件会自动检测带有Mirror的骨骼
		-- 3. 自动处理L/R方向转换 (R->L, L->R)
		-- 4. 自动移除括号()和ed后缀
		-- 5. 对于没有方向标识的骨骼，会按序号继续命名
		-- 6. 完成后自动清理所有ed后缀，确保命名整洁" 

		button 'btn12' "检查重命名" width:100 height:28 across:2 toolTip:"点击按钮，自动检查场景内部所有的物体命名" 
		button 'CheckBoneScale' "检查骨骼缩放" width:100 height:28  toolTip:"点击按钮，自动检查场景内部Bone的缩放" 

		button 'ResetBoneScale' "重置缩放为1" width:100 height:28 across:2  toolTip:"将选中物体，三个轴向的缩放还原为100%" 
		button 'btn_fix' "完美重置缩放" width:100 height:28 toolTip:"解决【形状变胖/变扁】问题，解决【末端骨骼变短】问题，解决【-100 负缩放】问题" 
	
		label 'JC' "检查命名" width:140 height:18  align:#center offset:[40,0]
		label 'lbl17' "检查缩放" width:140 height:16 align:#center offset:[40,0]
	)

---------------------------------------------------------------------------------------------------------------
---------------------------------骨骼镜像重命名函数-----------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
    -- 清理函数：移除括号和多余空格
    fn cleanBoneName boneName =
    (
        local cleanName = boneName
        -- 移除所有括号及其内容
        cleanName = substituteString cleanName "(" ""
        cleanName = substituteString cleanName ")" ""
        -- 移除多余空格
        cleanName = trimLeft (trimRight cleanName)
        return cleanName
    )
    
    -- 检测并转换L/R方向
    fn convertLRDirection boneName =
    (
        local newName = boneName
        local hasR = false
        local hasL = false
        
        -- 检测各种R的模式
        if matchPattern newName pattern:"*_R_*" or matchPattern newName pattern:"*_R" or \
           matchPattern newName pattern:"*R_*" or matchPattern newName pattern:"*R" then
        (
            hasR = true
        )
        
        -- 检测各种L的模式  
        if matchPattern newName pattern:"*_L_*" or matchPattern newName pattern:"*_L" or \
           matchPattern newName pattern:"*L_*" or matchPattern newName pattern:"*L" then
        (
            hasL = true
        )
        
        -- 转换R到L
        if hasR then
        (
            newName = substituteString newName "_R_" "_L_"
            newName = substituteString newName "_R" "_L"
            newName = substituteString newName "R_" "L_"
            -- 处理末尾的R
            if newName[newName.count] == "R" then
                newName = substring newName 1 (newName.count-1) + "L"
        )
        -- 转换L到R
        else if hasL then
        (
            newName = substituteString newName "_L_" "_R_"
            newName = substituteString newName "_L" "_R"
            newName = substituteString newName "L_" "R_"
            -- 处理末尾的L
            if newName[newName.count] == "L" then
                newName = substring newName 1 (newName.count-1) + "R"
        )
        
        return newName
    )
    
    -- 检查原始名称是否包含L/R标识
    fn hasLRIdentifier boneName =
    (
        if matchPattern boneName pattern:"*_R_*" or matchPattern boneName pattern:"*_R" or \
           matchPattern boneName pattern:"*R_*" or matchPattern boneName pattern:"*R" or \
           matchPattern boneName pattern:"*_L_*" or matchPattern boneName pattern:"*_L" or \
           matchPattern boneName pattern:"*L_*" or matchPattern boneName pattern:"*L" then
            return true
        else
            return false
    )
    
    -- 获取骨骼在层级中的序号
    fn getBoneIndex bone allBones =
    (
        for i = 1 to allBones.count do
        (
            if allBones[i] == bone then
                return i
        )
        return -1
    )
    
    -- 生成连续命名
    fn generateSequentialName baseName index =
    (
        -- 移除原有数字后缀
        local cleanBase = baseName
        local lastUnderscore = 0
        
        -- 找到最后一个下划线的位置
        for i = baseName.count to 1 by -1 do
        (
            if baseName[i] == "_" then
            (
                lastUnderscore = i
                exit
            )
        )
        
        -- 检查下划线后是否是数字
        if lastUnderscore > 0 and lastUnderscore < baseName.count then
        (
            local afterUnderscore = substring baseName (lastUnderscore + 1) -1
            local isNumber = true
            
            for j = 1 to afterUnderscore.count do
            (
                local char = afterUnderscore[j]
                if char < "0" or char > "9" then
                (
                    isNumber = false
                    exit
                )
            )
            
            if isNumber then
                cleanBase = substring baseName 1 lastUnderscore
        )
        
        return cleanBase + (index as string)
    )
    
    -- 检查名称是否已存在
    fn isNameExists targetName excludeObj =
    (
        for obj in objects do
        (
            if obj != excludeObj and obj.name == targetName then
                return true
        )
        return false
    )
    
    -- 清理ed后缀的函数
	fn cleanEdSuffix boneName =
	(
		local cleanName = boneName
		
		-- 检查是否以"ed"结尾（后面可能跟数字也可能不跟）
		local nameLen = cleanName.count
		if nameLen > 2 then
		(
			-- 检查是否以"ed"结尾
			if cleanName[nameLen-1] == "e" and cleanName[nameLen] == "d" then
			(
				-- 直接删除ed
				cleanName = substring cleanName 1 (nameLen-2)
			)
			-- 检查是否以"ed"+数字结尾
			else
			(
				for i = nameLen to 3 by -1 do
				(
					if i >= 3 and cleanName[i-2] == "e" and cleanName[i-1] == "d" then
					(
						-- 检查ed后面是否都是数字
						local numberPart = substring cleanName i -1
						local isNumber = true
						
						if numberPart.count > 0 then
						(
							for j = 1 to numberPart.count do
							(
								local char = numberPart[j]
								if char < "0" or char > "9" then
								(
									isNumber = false
									exit
								)
							)
							
							if isNumber then
							(
								cleanName = substring cleanName 1 (i-3)
								exit
							)
						)
					)
				)
			)
		)
		
		return cleanName
	)    
    -- 批量清理所有骨骼的ed后缀
    fn cleanAllEdSuffixes =
    (
        local cleanedCount = 0
        
        undo "清理骨骼ed后缀" on
        (
            for obj in objects do
            (
                if classOf obj == BoneGeometry then
                (
                    local oldName = obj.name
                    local cleanName = cleanEdSuffix oldName
                    
                    if cleanName != oldName then
                    (
                        -- 确保清理后的名称是唯一的
                        local finalName = uniqueName cleanName
                        obj.name = finalName
                        cleanedCount += 1
                    )
                )
            )
        )
        
        return cleanedCount
    )
    
    -- 执行重命名
	fn executeRename =
	(
		local mirrorBones = #()
		local renameCount = 0
		local allBones = #()
		
		-- 收集所有骨骼（用于序号排序）
		for obj in objects do
		(
			if classOf obj == BoneGeometry then
				append allBones obj
		)
		
		-- 收集所有镜像骨骼
		for obj in objects do
		(
			if classOf obj == BoneGeometry then
			(
				if matchPattern obj.name pattern:"*Mirror*" or matchPattern obj.name pattern:"*mirror*" or \
				   matchPattern obj.name pattern:"*mirrored*" or matchPattern obj.name pattern:"*Mirrored*" then
				(
					append mirrorBones obj
				)
			)
		)
		
		if mirrorBones.count == 0 then
		(
			messagebox "未找到带有Mirror的骨骼" title:"提示"
		)
		else
		(
			undo "骨骼镜像重命名" on
			(
				-- 第一步：直接重命名
				for bone in mirrorBones do
				(
					local originalName = bone.name
					local newName = originalName
					
					-- 清理括号
					newName = cleanBoneName newName
					
					-- 移除Mirror/mirrored
					newName = substituteString newName "Mirror" ""
					newName = substituteString newName "mirror" ""
					newName = substituteString newName "Mirrored" ""
					newName = substituteString newName "mirrored" ""
					
					-- 检查原始名称是否有L/R标识
					local hasLR = hasLRIdentifier originalName
					
					if hasLR then
					(
						-- 转换L/R方向
						newName = convertLRDirection newName
						
						-- 清理多余空格和下划线
						newName = trimLeft (trimRight newName)
						while matchPattern newName pattern:"*__*" do
							newName = substituteString newName "__" "_"
						
						-- 直接赋值，可能会产生ed后缀
						bone.name = newName
					)
					else
					(
						-- 没有L/R标识的，使用序号排序逻辑
						newName = trimLeft (trimRight newName)
						while matchPattern newName pattern:"*__*" do
							newName = substituteString newName "__" "_"
						
						-- 获取骨骼序号并生成连续命名
						local boneIndex = getBoneIndex bone allBones
						if boneIndex > 0 then
							bone.name = generateSequentialName newName boneIndex
						else
							bone.name = uniqueName newName
					)
					
					renameCount += 1
				)
				
				-- 第二步：只清理有L/R标识的骨骼的ed后缀
				for bone in mirrorBones do
				(
					-- 检查这个骨骼原始是否有L/R（需要重新检查原始名称）
					local needClean = false
					
					-- 通过当前名称判断是否需要清理（包含L或R的才清理）
					if matchPattern bone.name pattern:"*_L_*" or matchPattern bone.name pattern:"*_L" or \
					   matchPattern bone.name pattern:"*L_*" or matchPattern bone.name pattern:"*_R_*" or \
					   matchPattern bone.name pattern:"*_R" or matchPattern bone.name pattern:"*R_*" then
					(
						needClean = true
					)
					
					if needClean then
					(
						local currentName = bone.name
						local cleanName = cleanEdSuffix currentName
						
						if cleanName != currentName then
						(
							bone.name = cleanName
						)
					)
				)
				
				-- 第三步：清理所有骨骼的ed后缀（包括没有L/R的）
				local cleanedCount = cleanAllEdSuffixes()
			)
			
			messagebox ("总共重命名了 " + renameCount as string + " 个骨骼") title:"完成"
		)
	)

	on btn1 pressed do
	(
	    if selection.count == 0 then     -- 检查是否选中对象
		(
			messagebox "请选中一个以上的物体" beep:false
		)
		else
		(
			local prefixObj = edt1.text   -- 获取用户输入的对象名称，prefix翻译:前缀
			
			if prefixObj == "" then messagebox "命名为空" beep:false   -- 验证输入框内容是否为空
				
			for i = 1 to selection.count do   
			(
				if i < 10 then 
				(
					selection[i].name = prefixObj + "00" +(i as string)
				)
				else if i < 100 then
				(
					selection[i].name = prefixObj + "0" +(i as string)
				)
				else
				(
					selection[i].name = prefixObj + (i as string)
				)
			)
		)
	)

	on btn2 pressed do
	(
	    if selection.count == 0 then     -- 检查是否选中对象
		(
			messagebox "请选中一个以上的物体" beep:false
		)
		else
		(
			local prefixlayer = edt2.text   -- 获取用户输入的对象名称，prefix翻译:前缀
			local layer = layermanager.getLayerFromName prefixLayer -- 创建并获取指定名称的图层
			local layerObj = #()
			
			if prefixlayer == "" then messagebox "命名为空" beep:false   -- 验证输入框内容是否为空
			
			if layer == undefined then
	         (
	             layer = layermanager.newLayerFromName prefixLayer
	         )
			
			for i = 1 to selection.count do
			(
				layer.addNode selection[i]     
				append layerObj selection[i]   -- 将对象添加到图层
			)
		
		)
	)

	on btn3 pressed do
	(
	    if selection.count == 0 then     -- 检查是否选中对象
		(
			messagebox "请选中一个以上的物体" beep:false
		)
		else
		(
			local prefixsets = edt3.text     -- 获取用户输入的对象名称，prefix翻译:前缀
			local setsObj = #()             
			--local sets = SAelectionsets.getNamedSelSet prefixsets
			if prefixsets == "" then messagebox "命名为空" beep:false   -- 验证输入框内容是否为空
			
			for i = 1 to selection.count do
			(
				append setsObj selection[i]
			)
			selectionSets[prefixsets] = setsObj
		)
	)

	on btn4 pressed do
	(
		local TemlayerName =#()        -- 初始化一个空数组用于存放所有层的名称
		for i = 1 to LayerManager.count-1 do  -- 遍历所有层，获取每个层的名称
		(
			ilayer = layermanager.getlayer i   -- 获取当前层对象
			layerName = ilayer.name            -- 获取当前层的名称
			append TemlayerName layerName	   -- 将当前层的名称加入临时数组	
		) 
		for j = 1 to TemlayerName.count do 
		(
			LayerManager.deleteLayerByName TemlayerName[j]--按照层的命名去删除
		)
	)

	on btn5 pressed do
	(
		for n = selectionSets.count to 1 by -1 do 
		(
			deleteItem selectionSets selectionSets[n] --删除所有集合
		)
	)

	on renameBone pressed do
	(
		try(destroyDialog rename)catch()
		CreateDialog rename
	)

	on btnRename pressed do
	(
		executeRename()
	)

	on btn12 pressed do
	(
		local SameNameNode = #()  -- 定义一个空集合，用于存储所有有重名物体 
	    
		AllNodes = for i in objects collect i -- 收集场景中所有物体，包括模型、灯光、摄像机等
		
		SameNameNode = #()    -- 清空 SameNameNode 集合（准备重新检查）
		
		for i = 1 to AllNodes.count do
		(
			for x = i + 1 to AllNodes.count do  -- 遍历场景中剩余的物体，检查是否有和当前物体同名的其他物体
		   (
			   if AllNodes[i].name == AllNodes[x].name do  -- 如果当前物体和其他物体的名字相同，将当前物体添加到 SameNameNode 集合中
			   (
				   if findItem SameNameNode AllNodes[i] == 0 do  -- 如果物体还没有加入集合
				   (
					   append SameNameNode AllNodes[i]  -- 将当前物体添加到 SameNameNode 集合中
				   )
				   if findItem SameNameNode AllNodes[x] == 0 do   -- 如果 AllNodes[x] 也没在 SameNameNode 中加入，则也加入
				   (
					   append SameNameNode AllNodes[x]   -- 将重名物体加入集合
				   )
			   )
			
	    	)
		)
		clearselection() -- 清空当前选中的对象
		if SameNameNode.count != 0 do  -- 如果 SameNameNode 集合中有重名物体，则更新标签文本并选中所有重名物体
		(
			-- 更新标签显示重名的数量
			JC.text = "有 " + (SameNameNode.count as string) + " 个重名物体"
			
			-- 选中所有有重名的物体
			select SameNameNode
		)
	)

	on CheckBoneScale pressed do
	(
		local scaledBones = #()  -- 存储有缩放的骨骼
	    
	    -- 遍历场景中所有对象
	    for obj in objects do
	    (
	        -- 检查对象是否为骨骼
	        if (classOf obj.baseObject == boneGeometry) or 
	           ((classOf obj == XRefObject) and (classOf obj.actualBaseObject == BoneGeometry)) then
	        (
	            -- 使用容差判断缩放是否为1 (100%)
	            local tolerance = 0.001  -- 设置一个小的容差值
	            if (abs(obj.scale.x - 1.0) > tolerance) or 
	               (abs(obj.scale.y - 1.0) > tolerance) or 
	               (abs(obj.scale.z - 1.0) > tolerance) then
	            (
	                append scaledBones obj  -- 将有缩放的骨骼加入数组
	            )
	        )
	    )
	    
	    clearSelection()  -- 清空当前选择
	    
	    if scaledBones.count != 0 then
	    (
	        -- 选中所有有缩放的骨骼
	        select scaledBones
	        -- 更新标签显示数量
	        lbl17.text = "有 " + (scaledBones.count as string) + " 个缩放bone"
	    )
	    else
	    (
	        lbl17.text = "没有发现缩放bone"
	        messagebox "所有骨骼缩放均为100%" beep:false
	    )
	)

	on ResetBoneScale pressed do
	(
	    if selection.count == 0 then
	    (
	        messagebox "请选中一个以上的物体" beep:false
	    )
	    else
	    (
	        for obj in selection do
	        (
	            obj.scale = [1,1,1]  -- 重置缩放为100%
	        )
	    )
	)

    on btn_fix pressed do
    ( 
        undo "Fix Bone Scale" on
        ( 
            local processedCount = 0
            local sel = selection as array
            if sel.count == 0 then
            ( 
                messageBox "请先选择骨骼！" title:"提示" 
                return false
            ) 
            
            -- 批量记录所有骨骼的父子关系
            local hierarchyData = #()
            for o in sel do
            (
                if classof o == BoneGeometry then
                (
                    -- 修正：先转成数组再存储
                    local childArray = for c in o.children collect c
                    local data = #(o, o.parent, childArray)
                    append hierarchyData data
                    format "[记录] 骨骼:% | 父:% | 子数量:%\n" o.name (if o.parent != undefined then o.parent.name else "无") childArray.count
                )
            )
            
            with redraw off
            ( 
                for dataSet in hierarchyData do
                ( 
                    local o = dataSet[1]
                    local savedParent = dataSet[2]
                    local savedChilds = dataSet[3]
                    
                    try
                    ( 
                        local s = o.scale
                        format "[处理] 骨骼:% | 缩放:%\n" o.name s
                        
                        if (distance s [1,1,1] > 0.001) do
                        ( 
                            -- 1. 断开父子关系
                            format "[断开] 骨骼:% 的所有连接\n" o.name
                            o.parent = undefined
                            for c in savedChilds do c.parent = undefined
                            
                            -- 2. 修正参数
                            if isProperty o #width do o.width *= abs(s.z) 
                            if isProperty o #height do o.height *= abs(s.y) 
                            if isProperty o #length do o.length *= abs(s.x) 
                            
                            -- 3. 修正鳍
                            if isProperty o #sideFins and isProperty o #sideFinSize do
                            ( 
                                if o.sideFins == true do o.sideFinSize *= abs(s.z) 
                            ) 
                            if isProperty o #frontFins and isProperty o #frontFinSize do
                            ( 
                                if o.frontFins == true do o.frontFinSize *= abs(s.y) 
                            ) 
                            if isProperty o #backFins and isProperty o #backFinSize do
                            ( 
                                if o.backFins == true do o.backFinSize *= abs(s.y) 
                            ) 
                            
                            -- 4. 重置缩放
                            o.scale = [1,1,1]
                            format "[重置] 骨骼:% 缩放已归1\n" o.name
                            
                            -- 5. 强制刷新
                            if isProperty o #realignBoneToChild do o.realignBoneToChild()
                            
                            processedCount += 1
                        ) 
                    ) 
                    catch
                    ( 
                        format "[错误] 处理骨骼:% 失败\n" o.name
                    ) 
                ) 
            )
            
            -- 统一恢复所有父子关系
            format "\n[开始恢复层级关系]\n"
            for dataSet in hierarchyData do
            (
                local o = dataSet[1]
                local savedParent = dataSet[2]
                local savedChilds = dataSet[3]
                
                try
                (
                    -- 恢复父节点
                    o.parent = savedParent
                    format "[恢复父] 骨骼:% -> 父:%\n" o.name (if savedParent != undefined then savedParent.name else "无")
                    
                    -- 恢复子节点
                    for c in savedChilds do
                    (
                        c.parent = o
                        format "[恢复子] 骨骼:% <- 子:%\n" o.name c.name
                    )
                )
                catch
                (
                    format "[恢复失败] 骨骼:%\n" o.name
                )
            )
        ) 
        redrawViews()
        if processedCount > 0 then
        	messageBox ("成功修复 " + (processedCount as string) + " 根骨骼。\n轴向逻辑已修正！") title:"搞定" 
        else
        	print "所选对象无需修复或不是骨骼。" 
    )	
)
--================================================================================
--========================约束联动和IKFK链条===========================================
--================================================================================
rollout IKFK链条生成无 "IKFK链条生成v4.56(无缩放)" width:231 height:500
(
    
    global g_IKHelpers = #()  -- 存储所有IK控制器
    global g_FKChain = #()    -- 存储所有FK骨骼
    global g_IKBone = #()  
    global g_pts = #()
    
    GroupBox '样条线创建' "样条线创建" pos:[9,12] width:212 height:131 align:#left
    radiobuttons 'rdoMode' "生成模式：" pos:[15,36] width:211 height:30 labels:#("自动骨骼链", "手动选择骨骼") default:1 columns:2 align:#left
    button 'btnCreate' "创建样条线" pos:[55,70] width:120 height:30 align:#left
    button 'btnHelp' "使用说明" pos:[128,114] width:80 height:20 align:#left
    label 'lblInfo' "状态：等待操作" pos:[16,119] width:77 height:13 align:#left
    
    GroupBox 'IKFK链创建' "IKFK链创建" pos:[9,152] width:212 height:67 align:#left
    button 'chuangjianIK' "创建IK" pos:[36,172] width:58 height:30 align:#left toolTip:"选中SkinBone，创建IK骨骼链条，记得都设置下蒙皮姿势"
    button 'chuangjianFK' "创建FK" pos:[126,172] width:58 height:30 align:#left toolTip:"选中SkinBone，创建FK骨骼"
    
    GroupBox 'IKFK对齐' "IKFK对齐" pos:[9,228] width:212 height:67 align:#left
    button 'btn9' "创建切换属性" pos:[23,250] width:77 height:30 align:#left toolTip:"点击按钮自动生成IKFK切换"
    button 'btn10' "创建对齐属性" pos:[120,250] width:77 height:30 align:#left toolTip:"这个按钮是单独分离开的，可以用在其他文件里面，点击前请确保物体是有在属性承载器的，然后会报错"

    GroupBox '大小修改' "大小修改" pos:[9,304] width:212 height:172 align:#left
    label '虚拟点' "虚拟点" pos:[26,326] width:54 height:17 align:#left
    label 'lbl8' "Bone骨骼" pos:[143,326] width:54 height:17 align:#left
    checkbox 'chk1' "Center Marker" pos:[22,346] width:93 height:21 align:#left
    checkbox 'chk2' "Axis Tripod" pos:[22,371] width:78 height:21 align:#left
    checkbox 'chk3' "Cross" pos:[23,396] width:72 height:21 align:#left
    checkbox 'chk4' "Box" pos:[22,420] width:72 height:21 align:#left
    spinner 'pSize' "" pos:[57,447] width:71 height:16 range:[0,100,6] align:#left
    label 'lbl14' "大小：" pos:[20,448] width:32 height:16 range:[0,100,4] align:#left
    label 'lbl15' "宽度" pos:[153,350] width:32 height:16 range:[0,100,4] align:#left
    spinner 'Bkuandu' "" pos:[135,374] width:76 height:16 range:[0,100,4] align:#left
    label 'lbl16' "高度" pos:[153,400] width:32 height:16 range:[0,100,6] align:#left
    spinner 'Bgaodu' "" pos:[135,424] width:76 height:16 range:[0,100,4] align:#left
    label 'lbl4' "by：一方狂三" pos:[13,480] width:101 height:15 align:#left  
  
    --变量定义-----
    local splineObj  -- 存储创建的样条线对象
    local originalBones = #()  -- 新增：存储原始骨骼引用（所有按钮可访问）
    local clonedBonesArray   = #()  -- 可选：存储克隆骨骼引用
    local IKCTR = #()
    local FKBONE = #()

    
    

    -- 函数定义 --
    fn createAutoSpline = (
        if selection.count == 0 do (messageBox "请先选择根骨骼！"; return undefined)
        rootBone = selection[1]
        if classOf rootBone != BoneGeometry do (messageBox "所选对象不是Bone骨骼！"; return undefined)
        
        boneChain = #()
        currentBone = rootBone
        while currentBone != undefined do (
            append boneChain currentBone
            currentBone = if currentBone.children.count > 0 then currentBone.children[1] else undefined
        )
        
        if boneChain.count < 2 do (messageBox "骨骼链需要至少两个骨骼！"; return undefined)
        return boneChain
    )
    
    fn createManualSpline = (
        if selection.count < 2 do (messageBox "请至少选择两个骨骼！"; return undefined)
        validBones = for obj in selection where classOf obj == BoneGeometry collect obj
        if validBones.count < 2 do (messageBox "需要至少选择两个有效骨骼！"; return undefined)
        return validBones
    )

    fn createOptimizedSpline ptArray = (
        local spline = SplineShape()
        spline.name = uniqueName "BoneSpline_"
        spline.steps = 12
        
        addNewSpline spline
        for pos in ptArray do (
            addKnot spline 1 #smooth #curve pos
        )
        
        updateShape spline
        convertToSplineShape spline
        
        spline.wirecolor = color 255 128 0
        spline.render_displayRenderMesh = false
        spline.render_thickness = 0.0
        spline.xray = true
        
        spline
    )

    fn AddPoints = (
        global g_pts = #()
        local pts = #()
        for obj in selection do (
            local pt = point size:4 centermarker:false axistripod:false cross:false box:true wirecolor:[84,255,0]
            pt.name = uniqueName "PT_FZ_"  -- 关键命名规则
            pt.transform = obj.transform
            append g_pts pt
            append pts pt
        )
        
        for i = 1 to selection.count do (
            local obj = selection[i]
            local posCon = position_constraint()
            obj.pos.controller = posCon
            posCon.appendTarget pts[i] 100
            
            if i < selection.count do (
                local lookAtCon = LookAt_constraint()
                obj.rotation.controller = lookAtCon
                lookAtCon.appendTarget pts[i+1] 100
                lookAtCon.lookAt_vector_length = 0
                lookAtCon.upnode_world = false
                lookAtCon.pickupNode = pts[i]
            )
        )
        
        pts  -- 返回创建的虚拟点数组
    )

    
    -- 按钮事件 ----------

    
    on btnCreate pressed do
    (
            local bonesArray, spline
            
            case rdoMode.state of (
                1: (bonesArray = createAutoSpline())
                2: (bonesArray = createManualSpline())
            )
            
            if bonesArray == undefined then (
                lblInfo.text = "状态：创建失败"
                return false
            )
            
            try 
            (
                positions = for bone in bonesArray collect bone.pos
                spline = createOptimizedSpline positions
                IKFK链条生成无.splineObj = spline  -- 存储样条线引用
                select spline
                max zoomext sel
                lblInfo.text = "状态：创建成功 - " + spline.name
            )
            catch (
                messageBox ("错误: " + getCurrentException())
                lblInfo.text = "状态：发生错误"
            )
        )
    on btnHelp pressed do
    (
        helpText = "使用说明：\n\n"
        helpText += "【自动模式】\n"
        helpText += "1. 选择骨骼链的根骨骼\n"
        helpText += "2. 点击创建按钮\n"
        helpText += "3. 自动沿子骨骼层级创建样条线\n\n"
        helpText += "【手动模式】\n"
        helpText += "1. 按顺序选择至少2个骨骼\n"
        helpText += "2. 点击创建按钮\n"
        helpText += "3. 按选择顺序创建样条线\n\n"
        helpText += "★ 高级功能：\n"
        helpText += "- 自动平滑曲线（steps=12）\n"
        helpText += "- 橙色Xray显示\n"
        helpText += "- 关闭视口渲染网格\n"
        helpText += "- 自动命名和聚焦"
        
        messageBox helpText title:"帮助信息" width:300
    )
    on chuangjianIK pressed do
    (
        if IKFK链条生成无.splineObj == undefined do (
            messageBox "请先创建样条线！"
            return undefined
        )
        $.boneFreezeLength=false
         IKFK链条生成无.originalBones = for obj in selection where isValidNode obj collect obj
            format "已存储IK原始骨骼：%\n" originalBones
        
        if originalBones.count < 2 do (
            messageBox "需要至少选择两个骨骼！" title:"错误"
            return undefined
        )
        
        maxOps.cloneNodes $ cloneType:#copy newNodes:&nnl
        g_IKBone = nnl
        
        g_IKBone.wireColor = color 252 252 0
        g_IKBone.sidefins=true

       
        for a = 1 to g_IKBone.count do
        (
            g_IKBone[a].name = uniqueName "IK_"
        )
           
        format "已存储g_IKBone: %\n" g_IKBone
        -- 为原始骨骼添加约束到克隆骨骼
        for i = 1 to originalBones.count do 
        (
            try 
            (
                originalBones[i].pos.controller = Position_Constraint()
                originalBones[i].pos.controller.appendTarget g_IKBone[i] 100.0
                
                originalBones[i].rotation.controller = Orientation_Constraint()
                originalBones[i].rotation.controller.appendTarget g_IKBone[i] 100.0
            ) 
            catch 
            (
                format "第 % 根骨骼约束失败: %\n" i (getCurrentException())
            )
        )
        
        if g_IKBone.count >= 2 then (
            select g_IKBone
            local pts = AddPoints()
            local myline = IKFK链条生成无.splineObj
            
            -- 添加Spline IK Control修改器
            addModifier myline (Spline_IK_Control())
            local splineIKMod = myline.modifiers[#Spline_IK_Control]
            
            -- 正确设置初始链接模式（使用文档定义的linkTypes属性）
            splineIKMod.linkTypes = 2  -- 0=Link All In Hierarchy, 1=Link All to Root, 2=No Linking
            
            --- 创建Helpers（使用正确方法签名）
            local knotCount = g_IKBone.count
            if not (splineIKMod.createHelper knotCount) do (
            messageBox "控制器创建失败！"
            return false
            )

            -- 正确获取Helpers的方法（通过helper_list属性）
            g_IKHelpers = splineIKMod.helper_list  -- 官方定义的数组参数
            format "已存储Helpers: %\n" g_IKHelpers
            
            -- 验证Helpers数量
            if g_IKHelpers.count != g_IKBone.count do (
            messageBox "控制器数量不匹配！\n实际创建：" + g_IKHelpers.count as string + "个\n需要：" + g_IKBone.count as string
            return false
            )
            
            -- 对齐控制器方向（使用矩阵变换）
            for i = 1 to g_IKHelpers.count do (
                boneTM = g_IKBone[i].transform
                in coordsys world (
                g_IKHelpers[i].transform = boneTM
                g_IKHelpers[i].rotation = inverse boneTM.rotationPart
                )
            )
            
            -- 设置最终链接模式（使用专用方法）
            splineIKMod.linkToRoot()  -- 等效于linkTypes = 1
            
            -- 应用路径约束
            with animate off (
                for i = 1 to pts.count do (
                    -- 新增：创建位置列表控制器 --
                    pts[i].parent = g_IKHelpers[i]
                    pts[i].setSkinPose()
                    pts[i].position.controller = position_list()
                    ptsTF = pts[i].transform 
                    
                    -- 保留原始路径约束逻辑（修改为添加到可用控制器）--
                    pc = Path_Constraint()
                    pts[i].pos.controller.Available.controller = pc  -- 修改此处
                    pc.appendTarget myline 100.0
                    pc.percent = 100.0 * (i-1)/(pts.count-1)
                )
            )
            -- 修改删除动画关键帧的代码 --
            try (
                -- 保存当前选择 --
                oldSel = selection as array
                
                -- 选择所有路径点 --
                select pts
                
                -- 运行删除动画命令 --
                macros.run "Animation Tools" "DeleteSelectedAnimation"
                
                -- 恢复原始选择 --
                select oldSel
                

            ) catch (
                messageBox ("删除动画失败: " + getCurrentException())
            )
            
            -- 修改绑定后的部分 --
            for i=1 to pts.count do (
                if isValidNode g_IKHelpers[i] do (
                    
                    pts[i].pos.controller.value = pts[i].pos
                    
                    -- 新增：添加位置XYZ控制器 --
                    pts[i].pos.controller.Available.controller = Position_XYZ()
                    
                    -- 激活到最后添加的位置XYZ --
                    try (
                        pts[i].pos.controller.active = 3  -- 可能需要根据实际层级调整索引
                        pts[i].AssumeSkinPose()
                        
                    ) catch (
                        format "控制器激活失败: %\n" (getCurrentException())
                    )
                )
            )   
            select originalBones
            
        )
        else (
            messageBox "请至少选择两个skin骨骼。" title:"错误"
        )
    )
    on chuangjianFK pressed do
    (
        try (
        
            if selection.count == 0 do throw "请先选择骨骼"
            
        
        -- 保存原始骨骼引用
        IKFK链条生成无.originalBones = for obj in selection where isValidNode obj collect obj
        format "已存储FK原始骨骼：%\n" originalBones
        
        maxOps.cloneNodes $ cloneType:#copy newNodes:&nnl
        clonedBones = nnl
        
        
        select clonedBones
        clonedBones.wireColor = color 0 252 252
        $.boneFreezeLength=false
        $.frontfin = on 
        $.backfin = on
        

        
        for b = 1 to clonedBones.count do 
        (
            clonedBones[b].name = uniqueName "FK_"
        )
        g_FKChain = clonedBones
        format "已存储全局FK骨骼: %\n" g_FKChain
        
         -- 记录克隆骨骼的初始变换信息（关键步骤）
        initialTransforms = for bone in clonedBones collect bone.transform
        initialPositions = for bone in clonedBones collect bone.pos
        initialRotations = for bone in clonedBones collect bone.rotation
        
        -- 清除克隆骨骼的约束（关键步骤）
        for bone in clonedBones do
        (
            -- 重置位置控制器
            if classOf bone.pos.controller != Bezier_Position do
                bone.pos.controller = Bezier_Position()
            
            -- 重置旋转控制器
            if classOf bone.rotation.controller != Euler_XYZ do
                bone.rotation.controller = Euler_XYZ()
        )
        
         -- 清除约束并恢复位置（关键修改）
        for i = 1 to clonedBones.count do
        (
            bone = clonedBones[i]
            
            -- 保存初始状态
            originalTM = initialTransforms[i]
            originalPos = initialPositions[i]
            originalRot = initialRotations[i]
            
            -- 重置控制器前冻结变换
            with animate off
            (
                -- 重置位置控制器
                if classOf bone.pos.controller != Bezier_Position do
                (
                    bone.pos.controller = Bezier_Position()
                    bone.pos.controller.value = originalPos  -- 直接赋值位置
                )
                
                -- 重置旋转控制器
                if classOf bone.rotation.controller != Euler_XYZ do
                (
                    bone.rotation.controller = Euler_XYZ()
                    bone.rotation.controller.value = originalRot  -- 直接赋值旋转
                )
                
                -- 强制更新变换
                bone.transform = originalTM
            )
        )
        
         -- 为原始骨骼添加约束到FK骨骼（权重0）
        for i = 1 to originalBones.count do
        (
            try (
                -- 位置约束
                posConstr = Position_Constraint()
                originalBones[i].pos.controller = posConstr
                posConstr.appendTarget clonedBones[i] 0.0  -- 初始权重0
                
                -- 方向约束
                rotConstr = Orientation_Constraint()
                originalBones[i].rotation.controller = rotConstr
                rotConstr.appendTarget clonedBones[i] 0.0  -- 初始权重0
            ) catch (
                format "第 % 根骨骼约束失败: %\n" i (getCurrentException())
            )
        )
        
        -- 保持FK骨骼的选择状态
        select clonedBones
        )
        catch
        (
             messageBox "请至少选择两个skin骨骼。" title:"错误"
        )
    )
    on btn9 pressed do
    (
        -- 保持原有文本创建逻辑
        local Mytext = text text:"IK_FK" size:10 kerning:0 leading:0 transform:(matrix3 [1,0,0] [0,-1.62921e-07,1] [0,-1,-1.62921e-07] [0,0,0]) isSelected:on
                
        try (
            -- 添加空修改器
            modPanel.addModToSelection (EmptyModifier()) ui:on
        
            -- 获取最新添加的修改器
            local attrMod = $.modifiers[1]
            attrMod.name = "IKFK_Switch"
        
            -- 属性定义
            local ca = attributes "IKFK切换"
            (
                parameters main rollout:params (
                    IK_FK type:#float animatable:true default:0.0 ui:spnIKFK
                )
                rollout params "IKFK切换" width:162 height:48 
                (
                    spinner spnIKFK "IK_FK:" range:[0,100,0] type:#float scale:1
                )
            )
        
            -- 直接添加属性
            custAttributes.add attrMod ca
        
            -- 初始化参数值
            attrMod.IK_FK = 0.0
        
            -- 刷新界面
            modPanel.setCurrentObject attrMod

            for i = 1 to originalBones.count do
            (
                -- 调试信息
                format "处理骨骼: %\n" originalBones[i].name
                format "位置控制器类型: %\n" (classOf originalBones[i].pos.controller)
                format "旋转控制器类型: %\n" (classOf originalBones[i].rotation.controller)
                
                -- 位置约束权重设置
                try (
                    if classOf originalBones[i].pos.controller == Position_Constraint then (
                        -- 权重1: 100 - IK_FK
                        originalBones[i].pos.controller.weight[1].controller = Float_Expression()
                        originalBones[i].pos.controller.weight[1].controller.AddScalarTarget "IK_FK" Mytext.modifiers[#IKFK_Switch].IKFK切换[#IK_FK]
                        originalBones[i].pos.controller.weight[1].controller.setExpression "100 - IK_FK"
                        
                        -- 权重2: IK_FK
                        originalBones[i].pos.controller.weight[2].controller = Float_Expression()
                        originalBones[i].pos.controller.weight[2].controller.AddScalarTarget "IK_FK" Mytext.modifiers[#IKFK_Switch].IKFK切换[#IK_FK]
                        originalBones[i].pos.controller.weight[2].controller.setExpression "IK_FK"
                        
                        format "位置约束设置成功\n"
                    ) else (
                        format "警告: 骨骼 % 的位置控制器不是Position_Constraint\n" originalBones[i].name
                    )
                ) catch (
                    format "位置约束设置失败: %\n" (getCurrentException())
                )
                
                -- 旋转约束权重设置
                try (
                    if classOf originalBones[i].rotation.controller == Orientation_Constraint then (
                        -- 权重1: 100 - IK_FK
                        originalBones[i].rotation.controller.weight[1].controller = Float_Expression()
                        originalBones[i].rotation.controller.weight[1].controller.AddScalarTarget "IK_FK" Mytext.modifiers[#IKFK_Switch].IKFK切换[#IK_FK]
                        originalBones[i].rotation.controller.weight[1].controller.setExpression "100 - IK_FK"
                        
                        -- 权重2: IK_FK
                        originalBones[i].rotation.controller.weight[2].controller = Float_Expression()
                        originalBones[i].rotation.controller.weight[2].controller.AddScalarTarget "IK_FK" Mytext.modifiers[#IKFK_Switch].IKFK切换[#IK_FK]
                        originalBones[i].rotation.controller.weight[2].controller.setExpression "IK_FK"
                        
                        format "旋转约束设置成功\n"
                    ) else (
                        format "警告: 骨骼 % 的旋转控制器不是Orientation_Constraint\n" originalBones[i].name
                    )
                ) catch (
                    format "旋转约束设置失败: %\n" (getCurrentException())
                )
            )
        
            messageBox ("成功链接" + (originalBones.count as string) + "个约束参数") title:"操作成功"
        )
        catch (
            messageBox ("操作失败: " + getCurrentException()) title:"错误"
        )
    )

    
    
    
    on btn10 pressed do
    (
        -- 定义动态属性名称（唯一） --
        local attrName = "IKFAKMatch_" + (random 1 99999) as string
        -- 定义持久化属性 --
        ca = attributes attrName version:4  -- 版本号升级到4
        (
            parameters main 
            (
                fk_bones type:#stringTab tabSizeVariable:true
                ik_bones type:#stringTab tabSizeVariable:true
                helpers type:#stringTab tabSizeVariable:true
                pts_names type:#stringTab tabSizeVariable:true
                -- 新增帧范围参数 --
                start_frame type:#integer default:0
                end_frame type:#integer default:100
            )
            
            rollout params "IK/FK 对齐控制" width:162 height:210
            (
                group "单帧对齐"
                (
                    button 'btn_fk2ik' "FK→IK对齐" pos:[12,26] width:65 height:30 across:2 align:#left
                    button 'btn_ik2fk' "IK→FK对齐" pos:[82,26] width:65 height:30 align:#left
                )
                
                group "批量帧对齐"
                (
                    spinner 'spn_start' "起始帧:" pos:[40,87] width:50 height:16 range:[-9999,9999,0] type:#integer fieldwidth:40 align:#left
                    spinner 'spn_end' "结束帧:" pos:[40,108] width:50 height:16 range:[-9999,9999,100] type:#integer fieldwidth:40 align:#left
                    button 'btn_batch_fk2ik' "批量FK→IK" pos:[12,128] width:65 height:30 across:2 align:#left
                    button 'btn_batch_ik2fk' "批量IK→FK" pos:[82,128] width:65 height:30 align:#left
                )
                
                on params open do
                (
                    spn_start.value = $.modifiers[1].start_frame
                    spn_end.value = $.modifiers[1].end_frame
                )
                
                on spn_start changed val do $.modifiers[1].start_frame = val
                on spn_end changed val do $.modifiers[1].end_frame = val
                
                -- 原有单帧对齐功能保持不变 --
                on btn_fk2ik pressed do
                (
                    undo "FK→IK对齐" on
                    (
                        local mod = $.modifiers[1]
                        for i=1 to mod.fk_bones.count do
                        (
                            local fkBone = getNodeByName mod.fk_bones[i]
                            local ikBone = getNodeByName mod.ik_bones[i]
                            if isValidNode fkBone and isValidNode ikBone do
                                fkBone.transform = ikBone.transform
                        )
                    )
                )
                
                on btn_ik2fk pressed do
                (
                    undo "IK→FK对齐" on 
                    (
                        local mod = $.modifiers[1]
                        local pts = for name in mod.pts_names where (getNodeByName name) != undefined collect (getNodeByName name)
                        
                        for i=1 to mod.helpers.count do
                        (
                            local helper = getNodeByName mod.helpers[i]
                            local fkBone = getNodeByName mod.fk_bones[i]
                            if isValidNode helper and isValidNode fkBone do
                                helper.transform = fkBone.transform
                                select pts
                                macros.run "Characters" "AssumeSkinPose"
                        )
                        completeRedraw()
                    )
                )
                
                -- 新增批量对齐功能 --
                on btn_batch_fk2ik pressed do
                (
                    undo "批量FK→IK对齐" on
                    (
                        local mod = $.modifiers[1]
                        local oldTime = sliderTime
                        local startF = mod.start_frame
                        local endF = mod.end_frame
                        
                        disableSceneRedraw()
                        try (
                            for t = startF to endF do
                            (
                                sliderTime = t
                                for i=1 to mod.fk_bones.count do
                                (
                                    local fkBone = getNodeByName mod.fk_bones[i]
                                    local ikBone = getNodeByName mod.ik_bones[i]
                                    if isValidNode fkBone and isValidNode ikBone do
                                        with animate on fkBone.transform = ikBone.transform
                                )
                            )
                        )
                        catch (
                            format "批量FK→IK对齐出错: %\n" (getCurrentException())
                        )
                        sliderTime = oldTime
                        enableSceneRedraw()
                        completeRedraw()
                        messageBox ("已完成从帧"+startF as string+"到"+endF as string+"的批量FK→IK对齐") title:"完成"
                    )
                )
                
                on btn_batch_ik2fk pressed do
                (
                    undo "批量IK→FK对齐" on
                    (
                        local mod = $.modifiers[1]
                        local oldTime = sliderTime
                        local startF = mod.start_frame
                        local endF = mod.end_frame
                        local pts = for name in mod.pts_names where (getNodeByName name) != undefined collect (getNodeByName name)
                        
                        disableSceneRedraw()
                        try (
                            for t = startF to endF do
                            (
                                sliderTime = t
                                for i=1 to mod.helpers.count do
                                (
                                    local helper = getNodeByName mod.helpers[i]
                                    local fkBone = getNodeByName mod.fk_bones[i]
                                    if isValidNode helper and isValidNode fkBone do
                                        with animate on (
                                            helper.transform = fkBone.transform
                                            select pts
                                            macros.run "Characters" "AssumeSkinPose"
                                        )
                                )
                            )
                        )
                        catch (
                            format "批量IK→FK对齐出错: %\n" (getCurrentException())
                        )
                        sliderTime = oldTime
                        enableSceneRedraw()
                        completeRedraw()
                        messageBox ("已完成从帧"+startF as string+"到"+endF as string+"的批量IK→FK对齐") title:"完成"
                    )
                )
            )
        )
        

        -- 应用属性到当前对象 --
        if selection.count == 1 then
        (
            local obj = $
            
            -- 自动收集数据 --
            local fkChain = for o in g_FKChain where isValidNode o and matchPattern o.name pattern:"FK_*" collect o.name
            local ikChain = for o in g_IKBone where isValidNode o and matchPattern o.name pattern:"IK_*" collect o.name
             -- 关键修改：实时获取Helpers列表 --
            local helperNames = for h in g_IKHelpers where isValidNode h collect h.name  -- 直接引用当前IK控制器
            -- 关键修复4：验证数据有效性 --
             
            -- 收集当前虚拟点名称 --
            local ptsNames = for pt in g_pts where isValidNode pt collect pt.name
            
            -- 验证数据有效性 --
            if fkChain.count == 0 or ikChain.count == 0 or helperNames.count == 0 do 
            (
                messageBox "数据收集失败，请确保已正确创建IK和FK链！"
                return false
            )
            
            -- 添加/更新属性 --
            local attrMod = obj.modifiers[1]
            attrMod.name =  attrName  -- 唯一修改器名称
                
            custAttributes.add attrMod ca
            attrMod.fk_bones = deepCopy fkChain
            attrMod.ik_bones = deepCopy ikChain
            attrMod.helpers = deepCopy helperNames
            attrMod.pts_names = deepCopy ptsNames  -- 关键：存储名称而非引用
            
            -- 设置默认帧范围为时间线范围 --
            attrMod.start_frame = animationRange.start.frame as integer
            attrMod.end_frame = animationRange.end.frame as integer
            
            -- 清空全局变量（关键！） --
            g_IKHelpers = #()
            g_FKChain = #()
            g_IKBone = #()
            g_pts = #()
            
            -- 修正后的字符串拼接 --
            local msg = "对齐数据已捕获！\n"
            msg += "FK骨骼：" + (fkChain.count as string) + "个\n"
            msg += "IK骨骼：" + (ikChain.count as string) + "个\n" 
            msg += "IK控制器：" + (helperNames.count as string) + "个\n"
            msg += "支持批量对齐功能！"
            messageBox msg
            
            select obj
        )
        else
        (
            messageBox "请选择承载属性的对象！" title:"提示"
        )
    )
    
        
    on chk1 changed state do
    (
        for obj in selection do
        (
             try (obj.centermarker = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )

    )
    on chk2 changed state do
    (
        for obj in selection do
        (
             try (obj.axistripod = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on chk3 changed state do
    (
        for obj in selection do
        (
             try (obj.cross = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on chk4 changed state do
    (
        for obj in selection do
        (
             try (obj.Box = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on pSize changed val do
    (
        for obj in selection do
        (
             try (obj.size = val)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on Bkuandu changed val do
    (
        for obj in selection do
        (
             try (obj.width = val)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on Bgaodu changed val do
    (
        for obj in selection do
        (
             try (obj.height = val)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    
)
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
rollout IKFK链条生成有 "IKFK链条生成v4.81(有缩放)" width:231 height:500
(
    global g_IKHelpers = #()  -- 存储所有IK控制器
    global g_FKChain = #()    -- 存储所有FK骨骼
    global g_IKBone = #()  
    global g_pts = #()

    local currentChainPoints = #()  -- 存储当前骨骼链的虚拟点
    local currentChainSPoints = #() -- 存储当前骨骼链的SPoint虚拟点
    
    GroupBox '样条线创建' "样条线创建" pos:[9,12] width:212 height:131 align:#left
    radiobuttons 'rdoMode' "生成模式：" pos:[15,36] width:211 height:30 labels:#("自动骨骼链", "手动选择骨骼") default:1 columns:2 align:#left
    button 'btnCreate' "创建样条线" pos:[55,70] width:120 height:30 align:#left
    button 'btnHelp' "使用说明" pos:[128,114] width:80 height:20 align:#left
    label 'lblInfo' "状态：等待操作" pos:[16,119] width:77 height:13 align:#left
    
    GroupBox 'IKFK链创建' "IKFK链创建" pos:[9,152] width:212 height:67 align:#left
    button 'chuangjianIK' "创建IK" pos:[36,172] width:58 height:30 align:#left toolTip:"选中SkinBone，创建IK骨骼链条，记得都设置下蒙皮姿势"
    button 'chuangjianFK' "创建FK" pos:[126,172] width:58 height:30 align:#left toolTip:"选中SkinBone，创建FK骨骼"
    
    GroupBox 'IKFK对齐' "IKFK对齐" pos:[9,228] width:212 height:67 align:#left
    button 'btn9' "创建切换属性" pos:[23,250] width:77 height:30 align:#left toolTip:"点击按钮自动生成IKFK切换"
    button 'btn10' "创建对齐属性" pos:[120,250] width:77 height:30 align:#left toolTip:"这个按钮是单独分离开的，可以用在其他文件里面，点击前请确保物体是有在属性承载器的，然后会报错"

    GroupBox '大小修改' "大小修改" pos:[9,304] width:212 height:172 align:#left
    label '虚拟点' "虚拟点" pos:[26,326] width:54 height:17 align:#left
    label 'lbl8' "Bone骨骼" pos:[143,326] width:54 height:17 align:#left
    checkbox 'chk1' "Center Marker" pos:[22,346] width:93 height:21 align:#left
    checkbox 'chk2' "Axis Tripod" pos:[22,371] width:78 height:21 align:#left
    checkbox 'chk3' "Cross" pos:[23,396] width:72 height:21 align:#left
    checkbox 'chk4' "Box" pos:[22,420] width:72 height:21 align:#left
    spinner 'pSize' "" pos:[57,447] width:71 height:16 range:[0,100,6] align:#left
    label 'lbl14' "大小：" pos:[20,448] width:32 height:16 range:[0,100,4] align:#left
    label 'lbl15' "宽度" pos:[153,350] width:32 height:16 range:[0,100,4] align:#left
    spinner 'Bkuandu' "" pos:[135,374] width:76 height:16 range:[0,100,4] align:#left
    label 'lbl16' "高度" pos:[153,400] width:32 height:16 range:[0,100,6] align:#left
    spinner 'Bgaodu' "" pos:[135,424] width:76 height:16 range:[0,100,4] align:#left
    label 'lbl4' "by：一方狂三" pos:[13,480] width:101 height:15 align:#left  
  
    --变量定义-----
    local splineObj  -- 存储创建的样条线对象
    local originalBones = #()  -- 新增：存储原始骨骼引用（所有按钮可访问）
    local clonedBonesArray   = #()  -- 可选：存储克隆骨骼引用
    local IKCTR = #()
    local FKBONE = #()

    
    

    -- 函数定义 --
    fn createAutoSpline = (
        if selection.count == 0 do (messageBox "请先选择根骨骼！"; return undefined)
        rootBone = selection[1]
        if classOf rootBone != BoneGeometry do (messageBox "所选对象不是Bone骨骼！"; return undefined )
        
        boneChain = #()
        currentBone = rootBone
        while currentBone != undefined do (
            append boneChain currentBone
            currentBone = if currentBone.children.count > 0 then currentBone.children[1] else undefined
        )
        
        if boneChain.count < 2 do (messageBox "骨骼链需要至少两个骨骼！"; return undefined)
        return boneChain
    )
    
    fn createManualSpline = (
        if selection.count < 2 do (messageBox "请至少选择两个骨骼！"; return undefined)
        validBones = for obj in selection where classOf obj == BoneGeometry collect obj
        if validBones.count < 2 do (messageBox "需要至少选择两个有效骨骼！"; return undefined)
        return validBones
    )

    fn createOptimizedSpline ptArray = (
        local spline = SplineShape()
        spline.name = uniqueName "BoneSpline_"
        spline.steps = 12
        
        addNewSpline spline
        for pos in ptArray do (
            addKnot spline 1 #smooth #curve pos
        )
        
        updateShape spline
        convertToSplineShape spline
        
        spline.wirecolor = color 255 128 0
        spline.render_displayRenderMesh = false
        spline.render_thickness = 0.0
        spline.xray = true
        
        spline
    )

    fn AddPoints = (
        global g_pts = #()
        local pts = #()
        for obj in selection do (
            local pt = point size:4 centermarker:false axistripod:false cross:false box:true wirecolor:[84,255,0]
            pt.name = uniqueName "PT_FZ_"  -- 关键命名规则
            pt.transform = obj.transform
            append g_pts pt
            append pts pt
        )
        
        for i = 1 to selection.count do (
            local obj = selection[i]
            local posCon = position_constraint()
            obj.pos.controller = posCon
            posCon.appendTarget pts[i] 100
            
            if i < selection.count do (
                local lookAtCon = LookAt_constraint()
                obj.rotation.controller = lookAtCon
                lookAtCon.appendTarget pts[i+1] 100
                lookAtCon.lookAt_vector_length = 0
                lookAtCon.upnode_world = false
                lookAtCon.pickupNode = pts[i]
            )
        )
        
        pts  -- 返回创建的虚拟点数组
    )
    
    
    fn AddSPoints = 
    (
        tempSPoints = #()
        boneLengths = #()
        
        -- 第一遍循环：创建Points并计算骨骼长度
        for obj in selection where classOf obj == BoneGeometry do 
        (
            local boneWidth = try(obj.width)catch(5.0)
            local newPoint = Point name:(uniqueName "SPoint_") size:boneWidth
            newPoint.transform = obj.transform
            newPoint.Box = off
            newPoint.cross = on
            newPoint.AxisTripod = off
            newPoint.centermarker = off
            append tempSPoints newPoint
            
            -- 计算骨骼长度（末端骨骼返回undefined）
            local boneLength = if obj.children.count > 0 then (
                distance obj obj.children[1]
            ) else (
                undefined -- 标记为末端骨骼
            )
            append boneLengths boneLength
        )
        
        -- 第二遍循环：添加约束和表达式
        for i = 1 to selection.count where classOf selection[i] == BoneGeometry do 
        (
            try (
                local bone = selection[i]
                local point1 = tempSPoints[i]
                local point2 = if i < tempSPoints.count then tempSPoints[i+1] else point1
                
                -- 标准方法关闭X轴向继承
                local currentFlags = getInheritanceFlags bone
                setInheritanceFlags bone (currentFlags - #{7}) keepPos:true
                
                -- 位置和旋转约束（所有骨骼都需要）
                bone.pos.controller = Position_Constraint()
                bone.pos.controller.appendTarget point1 100.0
                bone.rotation.controller = Orientation_Constraint()
                bone.rotation.controller.appendTarget point1 100.0
                
                -- 仅对非末端骨骼添加缩放表达式
                if boneLengths[i] != undefined do 
                (
                    bone.scale.controller = ScaleXYZ()
                    bone.scale.controller.X_Scale.controller = Float_Expression()
                    local exprCtrl = bone.scale.controller.X_Scale.controller
                    
                    try(exprCtrl.DeleteAllTargets())catch()
                    exprCtrl.AddVectorTarget "a" point1.pos.controller
                    exprCtrl.AddVectorTarget "b" point2.pos.controller
                    exprCtrl.SetExpression ("length(a-b)/" + boneLengths[i] as string)
                    
                )
                
                -- 调试输出
                format "骨骼[%] % 设置完成:\n" i bone.name
                format "  末端骨骼: %\n" (boneLengths[i] == undefined)
                format "  继承标志: %\n" (getInheritanceFlags bone)
                if boneLengths[i] != undefined do (
                    format "  表达式: %\n" (bone.scale.controller.X_Scale.controller.GetExpression())
                    format "  初始长度: %\n" boneLengths[i]
                )
                
            ) catch (
                format "!! 处理骨骼 % 时出错: %\n" bone.name (getCurrentException())
            )
        )
        
        #(tempSPoints, boneLengths)
    )

    
    -- 按钮事件 ----------

    
    on btnCreate pressed do
    (
            local bonesArray, spline
            
            case rdoMode.state of (
                1: (bonesArray = createAutoSpline())
                2: (bonesArray = createManualSpline())
            )
            
            if bonesArray == undefined then (
                lblInfo.text = "状态：创建失败"
                return false
            )
            
            try 
            (
                positions = for bone in bonesArray collect bone.pos
                spline = createOptimizedSpline positions
                IKFK链条生成有.splineObj = spline  -- 存储样条线引用
                select spline
                max zoomext sel
                lblInfo.text = "状态：创建成功 - " + spline.name
            )
            catch (
                messageBox ("错误: " + getCurrentException())
                lblInfo.text = "状态：发生错误"
            )
        )
    on btnHelp pressed do
    (
        helpText = "使用说明：\n\n"
        helpText += "【自动模式】\n"
        helpText += "1. 选择骨骼链的根骨骼\n"
        helpText += "2. 点击创建按钮\n"
        helpText += "3. 自动沿子骨骼层级创建样条线\n\n"
        helpText += "【手动模式】\n"
        helpText += "1. 按顺序选择至少2个骨骼\n"
        helpText += "2. 点击创建按钮\n"
        helpText += "3. 按选择顺序创建样条线\n\n"
        helpText += "★ 高级功能：\n"
        helpText += "- 自动平滑曲线（steps=12）\n"
        helpText += "- 橙色Xray显示\n"
        helpText += "- 关闭视口渲染网格\n"
        helpText += "- 自动命名和聚焦"
        
        messageBox helpText title:"帮助信息" width:300
    )
    on chuangjianIK pressed do
    (
        IKFK链条生成有.currentChainPoints = #()  -- 清空当前链的虚拟点
        IKFK链条生成有.currentChainSPoints = #() -- 清空当前链的SPoint
        
        if IKFK链条生成有.splineObj == undefined do (
            messageBox "请先创建样条线！"
            return undefined
        )
        $.boneFreezeLength=false
         IKFK链条生成有.originalBones = for obj in selection where isValidNode obj collect obj
            format "已存储IK原始骨骼：%\n" originalBones
        
        if originalBones.count < 2 do (
            messageBox "需要至少选择两个骨骼！" title:"错误"
            return undefined
        )
        
        maxOps.cloneNodes $ cloneType:#copy newNodes:&nnl
        g_IKBone = nnl
        g_IKBone.wireColor = color 252 252 0
        g_IKBone.sidefins=true

       
        for a = 1 to g_IKBone.count do
        (
            g_IKBone[a].name = uniqueName "IK_"
        )
           
        format "已存储g_IKBone: %\n" g_IKBone
        -- 为原始骨骼添加约束到克隆骨骼
        
        -- 一次性为原始骨骼创建虚拟点系统
        select originalBones
        result = AddSPoints()
        local virtualPoints = result[1]  -- 获取创建的虚拟点数组
        IKFK链条生成有.currentChainSPoints = virtualPoints
        
        for i = 1 to virtualPoints.count do 
        (
            try 
            (
                virtualPoints[i].pos.controller = Position_Constraint()
                virtualPoints[i].pos.controller.appendTarget g_IKBone[i] 100.0
                
                virtualPoints[i].rotation.controller = Orientation_Constraint()
                virtualPoints[i].rotation.controller.appendTarget g_IKBone[i] 100.0
            ) 
            catch 
            (
                format "第 % 根骨骼约束失败: %\n" i (getCurrentException())
            )
        )
        
        if g_IKBone.count >= 2 then (
            select g_IKBone
            local pts = AddPoints()
            local myline = IKFK链条生成有.splineObj

            IKFK链条生成有.currentChainPoints = pts
            
            -- 添加Spline IK Control修改器
            addModifier myline (Spline_IK_Control())
            local splineIKMod = myline.modifiers[#Spline_IK_Control]
            
            -- 正确设置初始链接模式（使用文档定义的linkTypes属性）
            splineIKMod.linkTypes = 2  -- 0=Link All In Hierarchy, 1=Link All to Root, 2=No Linking
            
            --- 创建Helpers（使用正确方法签名）
            local knotCount = g_IKBone.count
            if not (splineIKMod.createHelper knotCount) do (
            messageBox "控制器创建失败！"
            return false
            )

            -- 正确获取Helpers的方法（通过helper_list属性）
            g_IKHelpers = splineIKMod.helper_list  -- 官方定义的数组参数
            format "已存储Helpers: %\n" g_IKHelpers
            
            -- 验证Helpers数量
            if g_IKHelpers.count != g_IKBone.count do (
            messageBox "控制器数量不匹配！\n实际创建：" + g_IKHelpers.count as string + "个\n需要：" + g_IKBone.count as string
            return false
            )
            
            -- 对齐控制器方向（使用矩阵变换）
            for i = 1 to g_IKHelpers.count do (
                boneTM = g_IKBone[i].transform
                in coordsys world (
                g_IKHelpers[i].transform = boneTM
                g_IKHelpers[i].rotation = inverse boneTM.rotationPart
                )
            )
            
            -- 设置最终链接模式（使用专用方法）
            splineIKMod.linkToRoot()  -- 等效于linkTypes = 1
            
            -- 应用路径约束
            with animate off (
                for i = 1 to pts.count do (
                    -- 新增：创建位置列表控制器 --
                    pts[i].parent = g_IKHelpers[i]
                    pts[i].setSkinPose()
                    pts[i].position.controller = position_list()
                    
                    -- 保留原始路径约束逻辑（修改为添加到可用控制器）--
                    pc = Path_Constraint()
                    pts[i].pos.controller.Available.controller = pc  -- 修改此处
                    pc.appendTarget myline 100.0
                    pc.percent = 100.0 * (i-1)/(pts.count-1)
                )
            )
            -- 修改删除动画关键帧的代码 --
            try (
                -- 保存当前选择 --
                oldSel = selection as array
                
                -- 选择所有路径点 --
                select pts
                
                -- 运行删除动画命令 --
                macros.run "Animation Tools" "DeleteSelectedAnimation"
                
                -- 恢复原始选择 --
                select oldSel
                

            ) catch (
                messageBox ("删除动画失败: " + getCurrentException())
            )
            
            -- 修改绑定后的部分 --
            for i=1 to pts.count do (
                if isValidNode g_IKHelpers[i] do (
                    pts[i].parent = g_IKHelpers[i]
                    pts[i].pos.controller.value = pts[i].pos
                    
                    -- 新增：添加位置XYZ控制器 --
                    pts[i].pos.controller.Available.controller = Position_XYZ()
                    
                    -- 激活到最后添加的位置XYZ --
                    try (
                        pts[i].pos.controller.active = 3  -- 可能需要根据实际层级调整索引
                        pts[i].AssumeSkinPose()

                    ) catch (
                        format "控制器激活失败: %\n" (getCurrentException())
                    )
                )
            )   
            select originalBones
            
        )
        else (
            messageBox "请至少选择两个skin骨骼。" title:"错误"
        )
    )
-- 修改chuangjianFK函数中的虚拟点处理
on chuangjianFK pressed do
(
    try (
        if selection.count == 0 do throw "请先选择骨骼"
        
        -- 保存原始骨骼引用
        IKFK链条生成有.originalBones = for obj in selection where isValidNode obj collect obj
        format "已存储FK原始骨骼：%\n" originalBones
        
        -- 使用当前骨骼链的SPoint虚拟点（而不是全局搜索）
        local currentChainVirtualPoints = IKFK链条生成有.currentChainSPoints
        
        if currentChainVirtualPoints == undefined or currentChainVirtualPoints.count == 0 do (
            messageBox "未找到对应的虚拟点！请先创建IK链。" title:"错误"
            return undefined
        )
        
        maxOps.cloneNodes $ cloneType:#copy newNodes:&nnl
        clonedBones = nnl
        
        select clonedBones
        clonedBones.wireColor = color 0 252 252
        $.boneFreezeLength=false
        $.frontfin = on    
        $.backfin = on
        
        for b = 1 to clonedBones.count do 
        (
            clonedBones[b].name = uniqueName "FK_"
        )
        g_FKChain = clonedBones
        format "已存储全局FK骨骼: %\n" g_FKChain
        
        -- 记录克隆骨骼的初始变换信息
        initialTransforms = for bone in clonedBones collect bone.transform
        initialPositions = for bone in clonedBones collect bone.pos
        initialRotations = for bone in clonedBones collect bone.rotation
        
        -- 清除克隆骨骼的约束
        for bone in clonedBones do
        (
            -- 重置位置控制器
            if classOf bone.pos.controller != Position_XYZ do
                bone.pos.controller = Position_XYZ()
            
            -- 重置旋转控制器
            if classOf bone.rotation.controller != Euler_XYZ do
                bone.rotation.controller = Euler_XYZ()
                
            -- 重置缩放控制器
            if classOf bone.scale.controller != tcb_scale do
                bone.scale.controller = tcb_scale()
        )
        
        -- 清除约束并恢复位置
        for i = 1 to clonedBones.count do
        (
            bone = clonedBones[i]
            
            -- 保存初始状态
            originalTM = initialTransforms[i]
            originalPos = initialPositions[i]
            originalRot = initialRotations[i]
            
            -- 重置控制器前冻结变换
            with animate off
            (
                -- 重置位置控制器
                if classOf bone.pos.controller != Bezier_Position do
                (
                    bone.pos.controller = Bezier_Position()
                    bone.pos.controller.value = originalPos
                )
                
                -- 重置旋转控制器
                if classOf bone.rotation.controller != Euler_XYZ do
                (
                    bone.rotation.controller = Euler_XYZ()
                    bone.rotation.controller.value = originalRot
                )
                
                -- 强制更新变换
                bone.transform = originalTM
            )
        )
        
        -- 关键修改：只为当前链的虚拟点添加约束到FK骨骼
        for i = 1 to currentChainVirtualPoints.count do
        (
            try (
                local vPoint = currentChainVirtualPoints[i]
                local fkBone = clonedBones[i]
                
                -- 检查虚拟点是否已有约束
                if classOf vPoint.pos.controller == Position_Constraint then (
                    -- 如果已有约束，添加新目标
                    vPoint.pos.controller.appendTarget fkBone 0.0
                    format "为虚拟点 % 添加FK目标：%\n" vPoint.name fkBone.name
                ) else (
                    format "警告：虚拟点 % 没有位置约束控制器\n" vPoint.name
                )
                
                if classOf vPoint.rotation.controller == Orientation_Constraint then (
                    -- 如果已有约束，添加新目标
                    vPoint.rotation.controller.appendTarget fkBone 0.0
                    format "为虚拟点 % 添加FK旋转目标：%\n" vPoint.name fkBone.name
                ) else (
                    format "警告：虚拟点 % 没有旋转约束控制器\n" vPoint.name
                )
                
            ) catch (
                format "第 % 个虚拟点约束失败: %\n" i (getCurrentException())
            )
        )
        
        -- 保持FK骨骼的选择状态
        select clonedBones
    )
    catch
    (
        messageBox ("FK创建失败: " + getCurrentException()) title:"错误"
    )
)
    -- 修复btn9函数，使用当前链的虚拟点
    on btn9 pressed do
    (
        try (
            -- 检查是否有选择的原始骨骼
            if originalBones == undefined or originalBones.count == 0 do (
                messageBox "未找到原始骨骼！请先创建IK和FK系统。" title:"错误"
                return undefined
            )
            
            -- 关键修改：直接使用当前骨骼链的虚拟点
            local currentChainVirtualPoints = IKFK链条生成有.currentChainSPoints
            
            if currentChainVirtualPoints == undefined or currentChainVirtualPoints.count == 0 do (
                messageBox "未找到当前骨骼链的虚拟点！" title:"错误"
                return undefined
            )
            
            -- 验证虚拟点数量
            if currentChainVirtualPoints.count != originalBones.count do (
                messageBox ("虚拟点数量不匹配！\n原始骨骼：" + originalBones.count as string + "\n虚拟点：" + currentChainVirtualPoints.count as string) title:"警告"
            )

            -- 创建文本对象
            local textName = uniqueName "IK_FK_Switch_"
            local Mytext = text text:textName size:10 kerning:0 leading:0 transform:(matrix3 [1,0,0] [0,-1.62921e-07,1] [0,-1,-1.62921e-07] [0,0,0]) isSelected:on
                
            -- 添加空修改器
            modPanel.addModToSelection (EmptyModifier()) ui:on
        
            -- 获取最新添加的修改器
            local attrMod = $.modifiers[1]
            attrMod.name = uniqueName "IKFK_Switch_" 
        
            -- 属性定义
            local ca = attributes "IKFK切换"
            (
                parameters main rollout:params (
                    IK_FK type:#float animatable:true default:0.0 ui:spnIKFK
                )
                
                rollout params "IKFK切换" width:162 height:48 
                (
                    spinner spnIKFK "IK_FK:" range:[0,100,0] type:#float scale:1
                )
            )
        
            -- 直接添加属性
            custAttributes.add attrMod ca
            
            -- 初始化参数值
            attrMod.IK_FK = 0.0
            
            -- 刷新界面
            modPanel.setCurrentObject attrMod
                
            -- 关键修复：使用表达式控制器连接当前骨骼链的虚拟点
            local successCount = 0
            for i = 1 to currentChainVirtualPoints.count do
            (
                try (
                    local vPoint = currentChainVirtualPoints[i]
                    
                    -- 检查并连接位置约束权重
                    if classOf vPoint.pos.controller == Position_Constraint then (
                        local posCtrl = vPoint.pos.controller
                        local targetCount = posCtrl.getNumTargets()
                        
                        if targetCount >= 2 then (
                            -- 使用表达式控制器替代paramWire
                            try (
                                -- 权重0: 100 - IK_FK
                                posCtrl.weight[1].controller = Float_Expression()
                                posCtrl.weight[1].controller.AddScalarTarget "IK_FK" Mytext.modifiers[attrMod.name].IKFK切换[#IK_FK]
                                posCtrl.weight[1].controller.setExpression "100 - IK_FK"
                                
                                -- 权重1: IK_FK
                                posCtrl.weight[2].controller = Float_Expression()
                                posCtrl.weight[2].controller.AddScalarTarget "IK_FK" Mytext.modifiers[attrMod.name].IKFK切换[#IK_FK]
                                posCtrl.weight[2].controller.setExpression "IK_FK"
                                
                                format "成功连接虚拟点 % 的位置约束\n" vPoint.name
                            ) catch (
                                format "位置约束表达式设置失败: %\n" (getCurrentException())
                            )
                        )
                    )
                    
                    -- 检查并连接旋转约束权重
                    if classOf vPoint.rotation.controller == Orientation_Constraint then 
                    (
                        local rotCtrl = vPoint.rotation.controller
                        local targetCount = rotCtrl.getNumTargets()
                        
                        if targetCount >= 2 then 
                        (
                            -- 使用表达式控制器替代paramWire
                            try (
                                -- 权重0: 100 - IK_FK
                                rotCtrl.weight[1].controller = Float_Expression()
                                rotCtrl.weight[1].controller.AddScalarTarget "IK_FK" Mytext.modifiers[attrMod.name].IKFK切换[#IK_FK]
                                rotCtrl.weight[1].controller.setExpression "100 - IK_FK"
                                
                                -- 权重1: IK_FK
                                rotCtrl.weight[2].controller = Float_Expression()
                                rotCtrl.weight[2].controller.AddScalarTarget "IK_FK" Mytext.modifiers[attrMod.name].IKFK切换[#IK_FK]
                                rotCtrl.weight[2].controller.setExpression "IK_FK"
                                
                                format "成功连接虚拟点 % 的旋转约束\n" vPoint.name
                            ) catch (
                                format "旋转约束表达式设置失败: %\n" (getCurrentException())
                            )
                        )
                    )
                    
                    successCount += 1
                    
                ) catch (
                    format "连接虚拟点 % 的约束时失败: %\n" vPoint.name (getCurrentException())
                )
            )
            
            if successCount > 0 then (
                messageBox ("成功为 " + successCount as string + " 个虚拟点创建IKFK切换控制") title:"操作成功"
            ) else (
                messageBox "没有成功连接任何约束！" title:"警告"
            )
            
        ) catch (
            messageBox ("创建切换属性失败: " + getCurrentException()) title:"错误"
        )
    )



    
    
    
    on btn10 pressed do
    (
        -- 定义动态属性名称（唯一） --
        local attrName = "IKFAKMatch_" + (random 1 99999) as string
        -- 定义持久化属性 --
        ca = attributes "attrName" version:4  -- 版本号升级到4
    (
        parameters main 
        (
            fk_bones type:#stringTab tabSizeVariable:true
            ik_bones type:#stringTab tabSizeVariable:true
            helpers type:#stringTab tabSizeVariable:true
            pts_names type:#stringTab tabSizeVariable:true
            -- 新增帧范围参数 --
            start_frame type:#integer default:0
            end_frame type:#integer default:100
        )
        
        rollout params "IK/FK 对齐控制" 
        (
            group "单帧对齐"
            (
                button 'btn_fk2ik' "FK→IK对齐" pos:[12,26] width:65 height:30 across:2 align:#left
                button 'btn_ik2fk' "IK→FK对齐" pos:[82,26] width:65 height:30 align:#left
            )
            
            group "批量帧对齐"
            (
               spinner 'spn_start' "起始帧:" pos:[40,87] width:50 height:16 range:[-9999,9999,0] type:#integer fieldwidth:40 align:#left
                spinner 'spn_end' "结束帧:" pos:[40,108] width:50 height:16 range:[-9999,9999,100] type:#integer fieldwidth:40 align:#left
                button 'btn_batch_fk2ik' "批量FK→IK" pos:[12,128] width:65 height:30 across:2 align:#left
                button 'btn_batch_ik2fk' "批量IK→FK" pos:[82,128] width:65 height:30 align:#left
            )
            
            on params open do
            (
                spn_start.value = $.modifiers[1].start_frame
                spn_end.value = $.modifiers[1].end_frame
            )
            
            on spn_start changed val do $.modifiers[1].start_frame = val
            on spn_end changed val do $.modifiers[1].end_frame = val
            
            -- 原有单帧对齐功能保持不变 --
            on btn_fk2ik pressed do
            (
                undo "FK→IK对齐" on
                (
                    local mod = $.modifiers[1]
                    for i=1 to mod.fk_bones.count do
                    (
                        local fkBone = getNodeByName mod.fk_bones[i]
                        local ikBone = getNodeByName mod.ik_bones[i]
                        if isValidNode fkBone and isValidNode ikBone do
                            fkBone.transform = ikBone.transform
                    )
                )
            )
            
            on btn_ik2fk pressed do
            (
                undo "IK→FK对齐" on 
                (
                    local mod = $.modifiers[1]
                    local pts = for name in mod.pts_names where (getNodeByName name) != undefined collect (getNodeByName name)
                    
                    for i=1 to mod.helpers.count do
                    (
                        local helper = getNodeByName mod.helpers[i]
                        local fkBone = getNodeByName mod.fk_bones[i]
                        if isValidNode helper and isValidNode fkBone do
                            helper.transform = fkBone.transform
                            select pts
                            macros.run "Characters" "AssumeSkinPose"
                    )
                    completeRedraw()
                )
            )
            
            -- 新增批量对齐功能 --
             -- 修正后的批量对齐功能 --
            on btn_batch_fk2ik pressed do
            (
                undo "批量FK→IK对齐" on
                (
                    local mod = $.modifiers[1]
                    local oldTime = sliderTime
                    local startF = mod.start_frame
                    local endF = mod.end_frame
                    
                    disableSceneRedraw()
                    try (
                        for t = startF to endF do
                        (
                            sliderTime = t
                            for i=1 to mod.fk_bones.count do
                            (
                                local fkBone = getNodeByName mod.fk_bones[i]
                                local ikBone = getNodeByName mod.ik_bones[i]
                                if isValidNode fkBone and isValidNode ikBone do
                                    with animate on fkBone.transform = ikBone.transform
                            )
                        )
                    )
                    catch (
                        format "批量FK→IK对齐出错: %\n" (getCurrentException())
                    )
                    sliderTime = oldTime
                    enableSceneRedraw()
                    completeRedraw()
                    messageBox ("已完成从帧"+startF as string+"到"+endF as string+"的批量FK→IK对齐") title:"完成"
                )
            )
            
            on btn_batch_ik2fk pressed do
            (
                undo "批量IK→FK对齐" on
                (
                    local mod = $.modifiers[1]
                    local oldTime = sliderTime
                    local startF = mod.start_frame
                    local endF = mod.end_frame
                    local pts = for name in mod.pts_names where (getNodeByName name) != undefined collect (getNodeByName name)
                    
                    disableSceneRedraw()
                    try (
                        for t = startF to endF do
                        (
                            sliderTime = t
                            for i=1 to mod.helpers.count do
                            (
                                local helper = getNodeByName mod.helpers[i]
                                local fkBone = getNodeByName mod.fk_bones[i]
                                if isValidNode helper and isValidNode fkBone do
                                    with animate on (
                                        helper.transform = fkBone.transform
                                        select pts
                                        macros.run "Characters" "AssumeSkinPose"
                                    )
                            )
                        )
                    )
                    catch (
                        format "批量IK→FK对齐出错: %\n" (getCurrentException())
                    )
                    sliderTime = oldTime
                    enableSceneRedraw()
                    completeRedraw()
                    messageBox ("已完成从帧"+startF as string+"到"+endF as string+"的批量IK→FK对齐") title:"完成"
                )
            )
        )
    )
        

        -- 应用属性到当前对象 --
        if selection.count == 1 then
        (
            local obj = $
            
            -- 自动收集数据 --
            local fkChain = for o in g_FKChain where isValidNode o and matchPattern o.name pattern:"FK_*" collect o.name
            local ikChain = for o in g_IKBone where isValidNode o and matchPattern o.name pattern:"IK_*" collect o.name
             -- 关键修改：实时获取Helpers列表 --
            local helperNames = for h in g_IKHelpers where isValidNode h collect h.name  -- 直接引用当前IK控制器
            -- 关键修复4：验证数据有效性 --
             
            -- 收集当前虚拟点名称 --
            local ptsNames = for pt in g_pts where isValidNode pt collect pt.name
            
            -- 验证数据有效性 --
            if fkChain.count == 0 or ikChain.count == 0 or helperNames.count == 0 do 
            (
                messageBox "数据收集失败，请确保已正确创建IK和FK链！"
                return false
            )
            
            -- 添加/更新属性 --
            local attrMod = obj.modifiers[1]
            attrMod.name =  attrName  -- 唯一修改器名称
                
            custAttributes.add attrMod ca
            attrMod.fk_bones = deepCopy fkChain
            attrMod.ik_bones = deepCopy ikChain
            attrMod.helpers = deepCopy helperNames
            attrMod.pts_names = deepCopy ptsNames  -- 关键：存储名称而非引用
            
            -- 清空全局变量（关键！） --
            g_IKHelpers = #()
            g_FKChain = #()
            g_IKBone = #()
            g_pts = #()
            messageBox "对齐数据已持久化存储！"
            
            
            -- 修正后的字符串拼接 --
            local msg = "对齐数据已捕获！\n"
            msg += "FK骨骼：" + (fkChain.count as string) + "个\n"
            msg += "IK骨骼：" + (ikChain.count as string) + "个\n" 
            msg += "IK控制器：" + (helperNames.count as string) + "个"
            messageBox msg
            
            select obj
        )
        else
        (
            messageBox "请选择承载属性的对象！" title:"提示"
        )
    )
    
        
    on chk1 changed state do
    (
        for obj in selection do
        (
             try (obj.centermarker = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )

    )
    on chk2 changed state do
    (
        for obj in selection do
        (
             try (obj.axistripod = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on chk3 changed state do
    (
        for obj in selection do
        (
             try (obj.cross = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on chk4 changed state do
    (
        for obj in selection do
        (
             try (obj.Box = state)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on pSize changed val do
    (
        for obj in selection do
        (
             try (obj.size = val)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on Bkuandu changed val do
    (
        for obj in selection do
        (
             try (obj.width = val)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    on Bgaodu changed val do
    (
        for obj in selection do
        (
             try (obj.height = val)
            catch (format "错误：% 无此属性\n" obj.name)
        )
    )
    
)



rollout CL_IKFK_Tools "约束联动和IKFK链条" width:260 height:138
(
    group "约束联动和IKFK链条"
    (
        button 'Pos_Con' "位置约束联动" width:100 height:26  across:2 toolTip:"依次选取三个物体,第二个选的对象将被第一第二个选择的对象控制一半" 
        button 'Rot_Con' "方向约束联动" width:100 height:26  toolTip:"依次选取三个物体,第二个选的对象将被第一第二个选择的对象控制一半" 
        button 'btn3' "IKFK链条无缩放" width:100 height:26  across:2  toolTip:"IKFK链条无缩放的版本"
        button 'btn4' "IKFK链条有缩放" width:100 height:26 toolTip:"IKFK链条有缩放的版本，如果导出有问题，请把所有skinBone的父对象个到一个新的root上导出"
    )

    on Pos_Con pressed do
    (
        if selection.count ==3 then
        (
            for i = 2 to selection.count-1 do
            (
                a=selection[i]
                a.pos.controller=position_list ()   
                PosCon=position_constraint()  ---创建位置约束
                a.pos.controller.Available.controller=PosCon            
                PosCon.appendTarget selection[i-1] 50   
                PosCon.appendTarget selection[i+1] 50   
                PosCon.relative = on
                a.pos.controller.Available.controller= Position_XYZ ()
                lst = a.pos.controller
                lst.SetActive 3
            )
        )
        else
        (
            messagebox "请依次选择三个物体" beep:false
        )
    )

    on Rot_Con pressed do
    (
        if selection.count ==3 then
        (
            for i=2 to selection.count-1 do
            (
                a=selection[i]
                a.rotation.controller=rotation_list ()  
                RotCon=Orientation_Constraint()  ---创建方向约束
                a.rotation.controller.Available.controller=RotCon           
                RotCon.appendTarget selection[i-1] 50   
                RotCon.appendTarget selection[i+1] 50   
                RotCon.relative = on
                a.rotation.controller.Available.controller= Euler_XYZ ()
                lst = a.rotation.controller
                lst.SetActive 3
            )
        )
        else
        (
            messagebox "请依次选择三个物体" beep:false
        )   
    )

    on btn3 pressed do
    (
        try DestroyDialog IKFK链条生成无 catch()
        createDialog IKFK链条生成无
    )

    on btn4 pressed do
    (
        try DestroyDialog IKFK链条生成有 catch()
        createDialog IKFK链条生成有
    )


)
--================================================================================
--================================================================================
--================================================================================

rollout About_Sign "About" width:165
(
	hyperlink 'cust5' "by：一方狂三" width:80 height:13 align:#center address:"https://space.bilibili.com/192845689?spm_id_from=333.788.0.0" color:(color 0 255 112)
	label b "整合了很多脚本，有些是朋友的"
	label cb "如果有新的需要添加的功能可以滴滴我"
	label ce "整合无敌版"
	label c "1256604813@qq.com"
	label ee "2026.01.23"
)

-- 如果窗口已存在，先关闭它
if AllRollout != undefined do
(
    try closerolloutfloater AllRollout catch()
)

-- 创建新的浮动窗口
AllRollout = newRolloutFloater "Bone_Tools_v0.4(整合版)" 260 600
-- 将Rollout添加到浮动窗口
addRollout BoneEditToolsRollout AllRollout
addRollout boneGeneratorRollout AllRollout
addRollout BoneChainTool AllRollout
addRollout Modify_Bone_Attributes AllRollout
addRollout BoneAdjustmentTool AllRollout
addRollout ObjectPropsRollout AllRollout
addRollout TransformLocksRollout AllRollout
addRollout InheritanceLocksRollout AllRollout
addRollout YJSCNQB AllRollout
addRollout NLCheckTool AllRollout
addRollout DistanceMeasurer AllRollout
addRollout CL_IKFK_Tools AllRollout
addRollout About_Sign AllRollout

BoneEditToolsRollout.open = on 
Modify_Bone_Attributes.open = off 
BoneAdjustmentTool.open = off
ObjectPropsRollout.open = off
TransformLocksRollout.open = off
InheritanceLocksRollout.open = off
boneGeneratorRollout.open = off 
BoneChainTool.open = off 
YJSCNQB.open = off 
NLCheckTool.open = off 
DistanceMeasurer.open = off 
About_Sign.open = off 
CL_IKFK_Tools.open = off 