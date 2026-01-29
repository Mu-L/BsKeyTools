/*26.1.22 
    待解决：
        1.速度慢
        2.判断逻辑待优化
        3.是不是要添加修复功能
        4.UI      */
/*26.1.23 
    更新：
        1.使用bitary对比优化了速度
        2.使用dotnet丰富了UI
        3.添加日志框功能
        4.判断逻辑优化：只有一块岛的骨骼不算飞点
        5.问许峥：如果不在modfiy界面获取蒙皮点内容（使用skinOps一定要在对应的界面下，否则获取的内容为空），        skinUtils.ShrinkSelection currentObj可不在modfiy下获取  fn_quickGetSelectedVerts
        6.添加初版 右键菜单《修复》功能
        7.添加画圈标记功能
        8.修改左上角ICON
        9.添加进度条提示功能
     */
/*26.1.26 
    更新：
        1.使用预缓存功能优化了速度
        2.使用dotnet进一步丰富了UI
        3.添加日志框避免弹错脚本终止
        4.修复空选节点报错问题
     */
/*26.1.27 fn_
    更新：
        1.日志框改为富文本框，用不同的颜色提示不同的日志
     */
/*26.1.28 
    更新：
        1.兼容低版本，使用不同的Api处理以20为分界的文件   低版本(以20往下)后面不能跟参数，识别错误：skinOps.GetNumberBones currentSkinMod node:currentObj
        待处理：需要整合一下这个两个API文件
     */
try (DestroyDialog ::SkinIslandChecker) catch()
rollout SkinIslandChecker "SkinIslateChecker v1.02" width:300 height:460
(
    GroupBox 'grp_object' "" pos:[10,10] width:280 height:43 
    dotNetControl 'edt_selection' "System.Windows.Forms.TextBox" pos:[20,23] width:260 height:23
    GroupBox 'grp_problems' "" pos:[10,55] width:280 height:250 
    dotNetControl 'lst_problems' "System.Windows.Forms.ListView" pos:[20,67] width:260 height:225
    progressBar 'pb3' "" pos:[10,305] width:280 height:4 color:red
    GroupBox 'grp_log' "" pos:[10,310] width:280 height:120 
    dotNetControl 'edt_log' "System.Windows.Forms.RichTextBox" pos:[20,323] width:260 height:95
    dotNetControl 'contextMenu' "System.Windows.Forms.ContextMenuStrip"
    button 'btn_check' "检查" pos:[20,435] width:120 height:20 
    button 'btn_clear' "清除" pos:[160,435] width:120 height:20 
    local problemBones = #()
    local logText = ""
    local currentObj = undefined
    local currentSkinMod = undefined
    local vertexDataMap = #()
    local markedVertices = #()
    local roundInfoList = #()
    local fixedItems = #()  
    fn fn_string2Bmp string = (
        clipboardClass = dotNetClass "System.Windows.Forms.Clipboard"
        ConvertClass = dotnetclass "system.convert"
        imageclass = dotNetclass "System.Drawing.image"
        bytearr = convertclass.FromBase64String string
        memstream = dotnetobject "System.IO.MemoryStream" bytearr
        DecodedImg = ImageClass.fromstream memstream
        memstream.close()
        DecodedImg
    )
    fn fn_getMaxVersion =(
        maxVes = ((maxVersion())[1] / 1000 + 1998)
        return (maxVes as integer)
    )
    fn fn_loadMyLogoAsTitlebarIcon = (
        logoIcon = "iVBORw0KGgoAAAANSUhEUgAAABIAAAAVCAYAAABLy77vAAABMElEQVQ4jZ2U4XGDMAyFP3pdgP5gAK/ACmSEdARWICNkhayQjuCO0BWygH+kI6hHkIntyget77gDJD89vSeb6griCHIhyJ0gos8XQXpry4uJE2QEbsBR/5yAN333BGnrDHKggSCTMvLFf3nEdjHqmk/AAT1dc0gi37XatdbmigNwKCLOYG4ynINHFdgZsatu7PXbqwFtmegUZDRAWgW51dpLk/2jqh0719vIE0dNtFpyGrtvWz9TrlVbdJC15ajjH9lM61ST6Wg65YujcEkqi+GUt0CiG16/o6jnBGTS2JCBFkB90X+bACyAOXODDbwC0YVYJe39g645rdos0/5uAVkMZLX6t+iGU3nSmABcE6fMu2f/erLcmOI9axF2x7naWk+r40wtl90/wVLtKtMMAD8S802PdM+s/QAAAABJRU5ErkJggg=="
        d = (windows.getChildHWND 0 ::SkinIslandChecker.title)[1]
        WM_SETICON = 0x0080
        ICON_SMALL = 0
        bm = dotnetobject "System.Drawing.Bitmap" (fn_string2Bmp logoIcon)         
        ptr = bm.GetHicon()
        icon = (dotnetclass "System.Drawing.Icon").FromHandle (dotnetobject "IntPtr" ptr)           
        windows.SendMessage d WM_SETICON ICON_SMALL icon.handle
    )
    -- 初始化选择对象文本框
    fn fn_initSelectionControl = (
        edt_selection.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 43 43 43
        edt_selection.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 255 180 180
        edt_selection.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
        edt_selection.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei UI" 10
        edt_selection.ReadOnly = true
        edt_selection.Text = "未选择对象..."
        edt_selection.TextAlign = (dotNetClass "System.Windows.Forms.HorizontalAlignment").Left
        
    )
    
    -- 修改初始化列表控件函数
    fn fn_initListControl = (
        lst_problems.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 43 43 43
        lst_problems.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 200 200 200
        lst_problems.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").None
        lst_problems.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei UI" 10
        lst_problems.View = (dotNetClass "System.Windows.Forms.View").Details
        lst_problems.FullRowSelect = true
        lst_problems.GridLines = false
        lst_problems.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
        lst_problems.OwnerDraw = true             
        lst_problems.Columns.Add "" 360
        local menuItem = contextMenu.Items.Add "修复"
        menuItem.Font = dotNetObject "System.Drawing.Font" "Microsoft YaHei UI" 9
    )
    -- 初始化日志控件
    fn fn_initLogControl = (
        edt_log.Multiline = true
        edt_log.ReadOnly = true
        edt_log.ScrollBars = (dotNetClass "System.Windows.Forms.RichTextBoxScrollBars").Vertical
        edt_log.BackColor = (dotNetClass "System.Drawing.Color").FromArgb 43 43 43
        edt_log.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 144 238 144
        edt_log.BorderStyle = (dotNetClass "System.Windows.Forms.BorderStyle").none
        edt_log.Font = dotNetObject "System.Drawing.Font" "Consolas" 9
        edt_log.DetectUrls = false

        --edt_log.WordWrap = false  -- 不自动换行
    )
    fn fn_addLog msg level:#info = ( --level:#success
        try 
        (
            local colorClass = dotNetClass "System.Drawing.Color"
            local color = case level of (
                #error:   colorClass.FromArgb 255 10 10
                #warning: colorClass.FromArgb 255 100 100
                #success: colorClass.FromArgb 144 238 144
                #info:    colorClass.FromArgb 90 200 200
            )
            
            local t = getLocalTime()
            local timeStr = "[" + (formattedPrint t[5] format:"02d") + ":" + (formattedPrint t[6] format:"02d") + ":" + (formattedPrint t[7] format:"02d") + "]"
            local logEntry = timeStr + "•" + msg
        
            local startPos = edt_log.TextLength

            edt_log.AppendText logEntry

            local actualLength = edt_log.TextLength - startPos
            edt_log.Select startPos actualLength
            edt_log.SelectionColor = color

            edt_log.AppendText "\r\n"
            
            edt_log.SelectionStart = edt_log.TextLength
            edt_log.ScrollToCaret()
            
        ) 
        catch 
        (
            format "日志错误: %\n" (getCurrentException())
        )
    )
    
    fn fn_clearIni = (
        edt_log.Clear()
        lst_problems.Items.Clear()
        problemBones = #()
        vertexDataMap = #()
        markedVertices = #()
        roundInfoList = #()
        fixedItems = #() 
        edt_selection.Text = "未选择对象..."
        currentObj = undefined
        currentSkinMod = undefined
        pb3.value = 0
        completeRedraw()
        fn_addLog "已清除所有数据, \n 选择蒙皮对象,点击检查按钮开始" level:#success 
    )
    --获取点周
    fn fn_getVertexRing obj vertIndex = 
    (
        local neighborVerts = #()
        local edges = meshop.getEdgesUsingVert obj vertIndex as array
        
        for e in edges do
        (
            local verts = meshop.getVertsUsingEdge obj #{e} as array

            if verts[1] == vertIndex then
                append neighborVerts verts[2]
            else
                append neighborVerts verts[1]
        )
        append neighborVerts vertIndex
        
        return neighborVerts
    )

    -- 求和数组
    fn fn_sumArray arr = (
        local total = 0.0
        for v in arr do total += v
        return total
    )
    -- 获取顶点权重
    fn fn_getVertexWeights vid = (
        local boneList = #()
        local weightList = #()
        local numWeights = skinOps.GetVertexWeightCount currentSkinMod vid
        
        for i = 1 to numWeights do 
        (
            local boneID = skinOps.GetVertexWeightBoneID currentSkinMod vid i
            local weight = skinOps.GetVertexWeight currentSkinMod vid i
            if weight > 0.0001 then
            (
                append boneList boneID
                append weightList weight
            )
        )
        return #(boneList, weightList)
    )
    -- 快速获取选中顶点 ID 数组 （兼容低版本
    fn fn_quickGetSelectedVerts skinMod =
    (
        local sel = #()
        local n = skinOps.GetNumberVertices skinMod
        for i = 1 to n where skinOps.IsVertexSelected skinMod i do
            append sel i
        return sel
    )
    -- 获取受影响的顶点（包括周围顶点）
    fn fn_meshGetAffectedVerts vidList = (
        local result = deepCopy vidList
        for vid in vidList do 
        (
            local ringVerts = fn_getVertexRing currentObj vid
            for rv in ringVerts do 
            (
                if findItem result rv == 0 do
                    append result rv
            )
        )
        return result
    )
   -- 获取顶点周围信息
    fn fn_getVertRoundDisWeightsInfo vid = (
        local ringVerts = fn_getVertexRing currentObj vid
        local idx = findItem ringVerts vid
        if idx > 0 do deleteItem ringVerts idx
        return #(ringVerts)
    )
    
   -- 替换顶点权重
    fn fn_skinReplaceVertexWeights skinMod vid boneList weightList = (
        local total = fn_sumArray weightList
        if total > 0.0001 then 
        (
            for i = 1 to weightList.count do
                weightList[i] = weightList[i] / total
            skinOps.ReplaceVertexWeights skinMod vid boneList weightList
        )
    )
    
   -- 混合顶点权重函数
    fn fn_blendVerticesWeight vidList valList = (
        if vidList.count > 0 do 
        (
            local affectedVerts = fn_meshGetAffectedVerts vidList
            local affectedVertsWeightsList = #()
            
            for vid in affectedVerts do
            (
                affectedVertsWeightsList[vid] = fn_getVertexWeights vid
            )

            for i = 1 to vidList.count do 
            (
                local vid = vidList[i]
                local val = valList[i]
                
                if val > 0.001 do 
                (
                    local dval = 1 - val
                    local selfWeights = affectedVertsWeightsList[vid]
                    local selfBoneList = selfWeights[1]
                    local selfWeightList = selfWeights[2]
                    
                    if roundInfoList[vid] == undefined do
                        roundInfoList[vid] = fn_getVertRoundDisWeightsInfo vid
                    
                    local newBones = #()
                    local newWeights = #()
                    local roundInfo = roundInfoList[vid]
                    local roundVid = roundInfo[1]
                    
                    for j = 1 to roundVid.count do (
                        local rid = roundVid[j]
                        local disW = 1.0 / roundVid.count
                        local rWeights = affectedVertsWeightsList[rid]
                        local rvb = rWeights[1]
                        local rvw = rWeights[2]
                        
                        for id = 1 to rvb.count do (
                            local w = rvw[id] * disW
                            local blid = findItem newBones rvb[id]
                            if blid > 0 then
                                newWeights[blid] += w
                            else (
                                append newBones rvb[id]
                                append newWeights w
                            )
                        )
                    )
                    
                    if newWeights.count > 0 do 
                    (
                        local totalWeight = fn_sumArray newWeights
                        
                        for j = 1 to newWeights.count do
                            newWeights[j] = (newWeights[j] / totalWeight) * val
                        
                        for id = 1 to selfBoneList.count do 
                        (
                            local bid = selfBoneList[id]
                            local w = selfWeightList[id] * dval
                            local blid = findItem newBones bid
                            if blid > 0 then
                                newWeights[blid] += w
                            else 
                            (
                                append newBones bid
                                append newWeights w
                            )
                        )
                        
                        fn_skinReplaceVertexWeights currentSkinMod vid newBones newWeights
                    )
                )
            )
        )
    )
    /*
    -- 圆圈绘制函数
    fn fn_CircleLine axisPoint angle radius width = (
        cnt = (360 / (angle as float)) as integer
        scaleRadius = (getViewFOV() / 10.0 * radius)
        radius_W = scaleRadius
        radius_N = scaleRadius - (getViewFOV() / 10.0 * width)
            
        gw.setRndLimits #(#colorVerts)
        
        x = (cos 0) * radius_W
        y = (sin 0) * radius_W
        lastpoint_W = [x, y, 0]
            
        x = (cos 0) * radius_N
        y = (sin 0) * radius_N
        lastpoint_N = [x, y, 0]
            
        for i = 1 to cnt do 
        (
            theangle = i * angle
            
            x = (cos theangle) * radius_W
            y = (sin theangle) * radius_W
            endPoint_W = [x, y, 0]
            
            x = (cos theangle) * radius_N
            y = (sin theangle) * radius_N
            endPoint_N = [x, y, 0]
            
            tran = Inverse(getViewTM())
            tran.row4 = axisPoint
            gw.settransform tran
            gw.startTriangles()
            gw.triangle #(lastpoint_N, lastpoint_W, endPoint_W) #(red, red, red)
            gw.triangle #(lastpoint_N, endPoint_N, endPoint_W) #(red, red, red)
            gw.endTriangles()
            
            lastpoint_W = endPoint_W
            lastpoint_N = endPoint_N
        )
    )*/
fn fn_CircleLine axisPoint angle radius width = (
    local scaleRadius = (getViewFOV() / 10.0 * radius)
    local halfSize = scaleRadius
    local lineWidth = (getViewFOV() / 10.0 * width)
    
    gw.setRndLimits #(#colorVerts)
    
    local tran = Inverse(getViewTM())
    tran.row4 = axisPoint
    gw.settransform tran
    
    local topLeft = [-halfSize, halfSize, 0]
    local topRight = [halfSize, halfSize, 0]
    local bottomLeft = [-halfSize, -halfSize, 0]
    local bottomRight = [halfSize, -halfSize, 0]
    
    local offset1 = normalize(topRight - bottomLeft)
    local perpOffset1 = [-offset1.y, offset1.x, 0] * lineWidth * 0.5
    
    local offset2 = normalize(topLeft - bottomRight)
    local perpOffset2 = [-offset2.y, offset2.x, 0] * lineWidth * 0.5
    
    gw.startTriangles()
    
    local line1_p1 = topLeft + perpOffset2
    local line1_p2 = topLeft - perpOffset2
    local line1_p3 = bottomRight + perpOffset2
    local line1_p4 = bottomRight - perpOffset2
    
    gw.triangle #(line1_p1, line1_p2, line1_p3) #(green, green, green)
    gw.triangle #(line1_p2, line1_p4, line1_p3) #(green, green, green)
    
    local line2_p1 = topRight + perpOffset1
    local line2_p2 = topRight - perpOffset1
    local line2_p3 = bottomLeft + perpOffset1
    local line2_p4 = bottomLeft - perpOffset1
    
    gw.triangle #(line2_p1, line2_p2, line2_p3) #(green, green, green)
    gw.triangle #(line2_p2, line2_p4, line2_p3) #(green, green, green)
    
    gw.endTriangles()

    gw.settransform (matrix3 1)
)

-- 视口绘制回调函数
fn fn_drawMarkers = (
    try (
        if markedVertices.count > 0 and currentObj != undefined and isValidNode currentObj then (
            for vertData in markedVertices do (
                local vertIndex = vertData[1]
                local obj = vertData[2]
                if isValidNode obj then (
                    try (
                        local vertPos = polyop.getVert obj vertIndex
                        fn_CircleLine vertPos 90 0.3 0.1 
                        -- 参数说明：
                        -- 0.5 = X 的大小
                        -- 0.1 = 线条粗细（数值越大越粗）
                    ) catch()
                )
            )
            gw.enlargeUpdateRect #whole
            gw.updateScreen()
        )
    ) catch (
        markedVertices = #()
    )
)

    fn registerViewportCallback = (
        unregisterRedrawViewsCallback fn_drawMarkers
        registerRedrawViewsCallback fn_drawMarkers
    )
    fn unregisterViewportCallback = (
        unregisterRedrawViewsCallback fn_drawMarkers
    )
    -- 获取两个数组的交集
    fn fn_getIntersection arr1 arr2 = (
        if arr1.count == 0 or arr2.count == 0 then return #()
        
        local result = #()
        local ba2 = arr2 as BitArray
        
        for item in arr1 do (
            if ba2[item] do
                append result item
        )
        return result
    )
    
    fn fn_getDifference arr1 arr2 = (
        if arr1.count == 0 then return #()
        if arr2.count == 0 then return deepCopy arr1
        
        local result = #()
        local ba2 = arr2 as BitArray
        
        for item in arr1 do (
            if not ba2[item] do
                append result item
        )
        return result
    )
    
    -- 比较两个数组是否相同
    fn fn_arraysEqual arr1 arr2 = (
        if arr1.count != arr2.count then return false
        
        local ba1 = arr1 as BitArray
        local ba2 = arr2 as BitArray
        
        return (ba1 == ba2)
    )
    on SkinIslandChecker open do
    (
        fn_loadMyLogoAsTitlebarIcon()
        fn_initSelectionControl()
        fn_initListControl()
        fn_initLogControl()
        fn_addLog "选择蒙皮对象,点击检查按钮开始" level:#success
        fn_addLog "可使用左键/右键两种检查方式。" level:#success
        registerViewportCallback()
        pb3.value = 0

    )

    on lst_problems DrawSubItem sender args do
    (
        local colorClass = dotNetClass "System.Drawing.Color"
        local itemIndex = args.Item.Index + 1
        
        local backColor = colorClass.FromArgb 43 43 43
        local textColor = colorClass.FromArgb 200 200 200
        
        if args.Item.Text == "✓ 没有发现问题" then
        (
            textColor = colorClass.FromArgb 144 238 144 
        )
        -- 已修复 -> 绿色
        else if findItem fixedItems itemIndex > 0 then 
        (
            textColor = colorClass.FromArgb 144 238 144
        )
        -- 骨骼标题 -> 红色
        else if itemIndex <= vertexDataMap.count then 
        (
            local data = vertexDataMap[itemIndex]
            if data[2] > 0 and data[3] == undefined then 
                textColor = colorClass.FromArgb 255 100 100
        )
        if args.Item.Selected then 
        (
            backColor = colorClass.FromArgb 100 100 100
        )

        local backBrush = dotNetObject "System.Drawing.SolidBrush" backColor
        args.Graphics.FillRectangle backBrush args.Bounds
        backBrush.Dispose()
        
        local textBrush = dotNetObject "System.Drawing.SolidBrush" textColor
        local sf = dotNetObject "System.Drawing.StringFormat"
        sf.LineAlignment = (dotNetClass "System.Drawing.StringAlignment").Center
        
        local rect = dotNetObject "System.Drawing.RectangleF" (args.Bounds.X + 3) args.Bounds.Y (args.Bounds.Width - 3) args.Bounds.Height
        args.Graphics.DrawString args.SubItem.Text args.Item.Font textBrush rect sf
        
        textBrush.Dispose()
    )
    on SkinIslandChecker close do
    (
        unregisterViewportCallback()
    )
    on lst_problems MouseUp sender args do
    (
        try 
        (
            if args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Right then 
            (
                local hitTest = lst_problems.HitTest (dotNetObject "System.Drawing.Point" args.X args.Y)
                
                if hitTest.Item != undefined then 
                (
                    local index = hitTest.Item.Index
                    lst_problems.SelectedIndices.Clear()
                    lst_problems.Items.Item[index].Selected = true
                    
                    if index < vertexDataMap.count then 
                    (
                        local dataEntry = vertexDataMap[index + 1]
                        if dataEntry[3] != undefined and dataEntry[2] > 0 then 
                        (
                            contextMenu.Show lst_problems (dotNetObject "System.Drawing.Point" args.X args.Y)
                        ) 
                        else 
                        (
                            fn_addLog "请右键点击具体的问题区域" level:#warning
                        )
                    )
                )
            )
        ) catch 
        (
            fn_addLog ("右键菜单错误: " + (getCurrentException())) level:#error
        )
    )

    on contextMenu ItemClicked sender args do
    (
        if args.ClickedItem.Text == "修复" then 
        (
            if currentObj == undefined or currentSkinMod == undefined then 
            (
                fn_addLog "错误: 请先执行检查" level:#error
                return()
            )
            
            if lst_problems.SelectedIndices.Count == 0 then (
                fn_addLog "错误: 未选择有效项" level:#error
                return()
            )
            
            local sel = lst_problems.SelectedIndices.Item[0] + 1
            
            if sel <= 0 or sel > vertexDataMap.count then (
                fn_addLog "错误: 未选择有效项" level:#error
                return()
            )
            
            local dataEntry = vertexDataMap[sel]
            local boneName = dataEntry[1]
            local boneID = dataEntry[2]
            local verts = dataEntry[3]
            
            if verts == undefined or boneID == 0 then (
                fn_addLog "错误: 请选择具体的区域进行修复" level:#error
                return()
            )
            
            fn_addLog ("开始修复【" + boneName + "】的问题区域...") 

            -- 创建临时 snapshot 用于获取拓扑关系
            local tempMesh = snapshotasmesh currentObj
            local originalObj = currentObj
            currentObj = tempMesh
            local vidList = verts
            local valList = #()
            for i = 1 to vidList.count do
                append valList 1.0
            for n = 1 to 50 do 
            (
                fn_blendVerticesWeight vidList valList
            )
            currentObj = originalObj
            delete tempMesh
        
            if findItem fixedItems sel == 0 do
                append fixedItems sel
            
            lst_problems.Refresh()
            local boneHeaderIndex = -1
            local allRegionsFixed = true
            
            for i = (sel - 1) to 1 by -1 do
            (
                if i <= vertexDataMap.count then (
                    if vertexDataMap[i][2] > 0 and vertexDataMap[i][3] == undefined then
                    (
                        boneHeaderIndex = i
                        exit
                    )
                )
            )
            if boneHeaderIndex > 0 then
            (
                for i = (boneHeaderIndex + 1) to vertexDataMap.count do
                (
                    local checkData = vertexDataMap[i]
                    
                    if checkData[1] != boneName or checkData[3] == undefined then
                        exit
                    
                    if findItem fixedItems i == 0 then
                    (
                        allRegionsFixed = false
                        exit
                    )
                )
                if allRegionsFixed then
                (
                    if findItem fixedItems boneHeaderIndex == 0 do
                        append fixedItems boneHeaderIndex
                    lst_problems.Refresh()
                    fn_addLog ("【" + boneName + "】的所有问题区域已修复完成！") level:#success
                )
            )
            fn_addLog ("已修复 " + verts.count as string + " 个顶点") level:#success
        )
    )
    
    on lst_problems DoubleClick sender args do
    (
        try
        (
            if currentObj == undefined or currentSkinMod == undefined then 
            (
                fn_addLog "错误:请先执行检查" level:#error
                return()
            )
            
            if lst_problems.SelectedItems.Count == 0 then return()
            local sel = lst_problems.SelectedItems.Item[0].Index + 1
            
            if sel <= 0 or sel > vertexDataMap.count then return()
            
            local dataEntry = vertexDataMap[sel]
            local boneName = dataEntry[1]
            local boneID = dataEntry[2]
            local verts = dataEntry[3]
            
            if verts == undefined or boneID == 0 then 
            (
                fn_addLog "选择了骨骼标题或空行,无法跳转" level:#error
                return()
            )
            select currentObj
            max modify mode
            modPanel.setCurrentObject currentSkinMod
            subobjectLevel = 1
            skinOps.SelectBone currentSkinMod boneID 
            
            local vertBitArray = verts as BitArray
            skinOps.SelectVertices currentSkinMod vertBitArray
            markedVertices = #()
            for v in verts do 
            (
                append markedVertices #(v, currentObj)
            )
            completeRedraw()
            fn_addLog ("已跳转到【" + boneName + "】并选择了 " + verts.count as string + " 个顶点") level:#success
            
        ) 
        catch 
        (
            local errMsg = "跳转失败: " + (getCurrentException()) 
            fn_addLog errMsg level:#error
        )
    )

    fn fn_orderCheck useHighVersion:true = 
    (
        try 
        (
            if selection.count == 0 then 
            (
                fn_addLog "错误: 未选择对象" level:#error
                return()
            )
            fn_clearIni()
            
            local startTime = timestamp()
            try 
            (
                if selection[1].modifiers[#Skin] != undefined then
                (
                    if useHighVersion then
                        skinOps.closeWeightTool selection[1].modifiers[#Skin] node:selection[1]
                    else
                        skinOps.closeWeightTool selection[1].modifiers[#Skin]
                )
            )
            catch()
            
            currentObj = selection[1]
            edt_selection.Text = currentObj.name
            windows.processPostedMessages()

            fn_addLog ("使用概率检查,精确度默认为1") level:#success
            fn_addLog ("开始检查对象: " + currentObj.name) level:#success
            
            markedVertices = #()
            roundInfoList = #()
            completeRedraw()
            pb3.value = 0
            pb3.color = yellow
            
            -- 低版本需要设置选择模式
            if not useHighVersion then
                select currentObj
            else
                max create mode
            
            currentSkinMod = undefined
            for m in currentObj.modifiers do 
            (
                if classOf m == Skin then 
                (
                    currentSkinMod = m
                    exit
                )
            )
            if currentSkinMod == undefined then 
            (
                fn_addLog "错误: 对象没有Skin修改器" level:#error
                return()
            )
            
            pb3.value = 0
            fn_addLog "创建网格快照..." level:#success
            local snapshotMesh = snapshotasmesh currentObj
            pb3.value = 5
            windows.processPostedMessages()
            
            local numVerts = meshop.getNumVerts snapshotMesh
            local numFaces = meshop.getNumFaces snapshotMesh
            local vertexRingBitArrays = #()
            for i = 1 to numVerts do 
                vertexRingBitArrays[i] = #{}
            
            for f = 1 to numFaces do
            (
                if mod f 500 == 0 then 
                (
                    pb3.value = 5 + (20.0 * f / numFaces) as integer
                    windows.processPostedMessages()
                )
                
                local face = meshop.getFace snapshotMesh f
                local v1 = face.x as integer
                local v2 = face.y as integer
                local v3 = face.z as integer
                
                vertexRingBitArrays[v1][v2] = true
                vertexRingBitArrays[v1][v3] = true
                vertexRingBitArrays[v2][v1] = true
                vertexRingBitArrays[v2][v3] = true
                vertexRingBitArrays[v3][v1] = true
                vertexRingBitArrays[v3][v2] = true
            )
            
            pb3.value = 25
            windows.processPostedMessages()
            
            local vertexRingCache = #()
            for v = 1 to numVerts do
            (
                vertexRingCache[v] = vertexRingBitArrays[v] as array
                append vertexRingCache[v] v
            )
            vertexRingBitArrays = undefined
            
            fn_addLog "预处理完成，开始检查骨骼..." level:#success
            problemBones = #()
            lst_problems.Items.Clear()
            vertexDataMap = #()
            
            -- 低版本需要设置修改面板
            if not useHighVersion then
            (
                max modify mode
                modPanel.setCurrentObject currentSkinMod
                subobjectLevel = 1
            )
            
            local numSkinBone = if useHighVersion then 
                skinOps.GetNumberBones currentSkinMod node:currentObj 
            else 
                skinOps.GetNumberBones currentSkinMod
                
            for num = 1 to numSkinBone do 
            (
                pb3.value = 25 + (70.0 * num / numSkinBone) as integer
                local boneName = ""
                try
                (
                    boneName = if useHighVersion then
                        skinOps.GetBoneName currentSkinMod num 1 node:currentObj
                    else
                        skinOps.GetBoneName currentSkinMod num 1
                )
                catch
                (
                    boneName = "Bone_" + num as string
                )
                
                if useHighVersion then
                (
                    skinOps.SelectBone currentSkinMod num node:currentObj
                    skinOps.selectVerticesByBone currentSkinMod node:currentObj
                    local allSkinVerts = skinOps.GetSelectedVertices currentSkinMod node:currentObj
                )
                else
                (
                    skinOps.SelectBone currentSkinMod num
                    skinOps.selectVerticesByBone currentSkinMod
                    local allSkinVerts = fn_quickGetSelectedVerts currentSkinMod
                    subobjectLevel = 0
                )
                
                local errorAry = #()
                if allSkinVerts.count > 0 then 
                (
                    local allStableSets = #()
                    local remainingVerts = allSkinVerts as bitArray
                    local allSkinVertsBits = allSkinVerts as bitArray
                    
                    while remainingVerts.count > 0 do 
                    (
                        local seedArray = remainingVerts as array
                        if seedArray.count == 0 then exit
                        local seedVert = seedArray[1]
                        local region = #{seedVert}
                        local toExpand = #{seedVert}
                        local safeCounter = 0
                        local maxIterations = 100000
                        
                        while toExpand.count > 0 do
                        (
                            safeCounter += 1
                            if safeCounter > maxIterations then
                            (
                                fn_addLog ("警告: 骨骼【" + boneName + "】区域扩展超时") level:#warning
                                exit
                            )
                            
                            local newVerts = #{}
                            local expandArray = toExpand as array
                            
                            for v in expandArray do
                            (
                                if v > 0 and v <= vertexRingCache.count then
                                (
                                    local neighborsArray = vertexRingCache[v]
                                    if neighborsArray != undefined then
                                    (
                                        local neighborsBits = neighborsArray as bitArray
                                        local validNeighbors = neighborsBits * allSkinVertsBits - region
                                        newVerts += validNeighbors
                                    )
                                )
                            )
                            region += newVerts
                            toExpand = newVerts
                        )
                        local regionArray = region as array
                        if regionArray.count > 0 then
                            append allStableSets regionArray
                        remainingVerts -= region
                    )
                    
                    -- 检查是否有飞点（多个独立区域）
                    if allStableSets.count > 1 then 
                    (
                        if not useHighVersion then subobjectLevel = 1
                        
                        for regionVerts in allStableSets do 
                        (
                            if regionVerts.count > 0 then
                            (
                                local regionBits = regionVerts as BitArray
                                if useHighVersion then
                                (
                                    skinOps.SelectVertices currentSkinMod regionBits node:currentObj
                                    local shrunkVerts = skinUtils.ShrinkSelection currentObj
                                    shrunkVerts = skinOps.GetSelectedVertices currentSkinMod node:currentObj
                                )
                                else
                                (
                                    skinOps.SelectVertices currentSkinMod regionBits
                                    local shrunkVerts = skinUtils.ShrinkSelection currentObj
                                    shrunkVerts = fn_quickGetSelectedVerts currentSkinMod
                                )
                                
                                if shrunkVerts.count == 0 then 
                                (
                                    append errorAry regionVerts
                                )
                            )
                        )
                        if not useHighVersion then subobjectLevel = 0
                    )
                )
                
                if errorAry.count > 0 then 
                (
                    local boneItem = lst_problems.Items.Add ("【" + boneName + "】")
                    append vertexDataMap #(boneName, num, undefined)
                    for regionIndex = 1 to errorAry.count do 
                    (
                        local regionVerts = errorAry[regionIndex]
                        local item = lst_problems.Items.Add ("        区域 " + regionIndex as string + ": " + regionVerts.count as string + " 个问题顶点")
                        append vertexDataMap #(boneName, num, regionVerts)
                    )
                    lst_problems.EnsureVisible (lst_problems.Items.Count - 1)
                    fn_addLog (boneName + " 发现 " + errorAry.count as string + " 个问题区域") level:#warning
                )
            )
            
            pb3.value = 95
            delete snapshotMesh
            pb3.value = 100
            
            local endTime = timestamp()
            local elapsed = (endTime - startTime) / 1000.0
            local elapsedStr = formattedPrint elapsed format:".2f"
            fn_addLog ("处理了 " + numVerts as string + " 个线...")
            fn_addLog ("处理了 " + numFaces as string + " 个面...")
            fn_addLog ("骨骼数量: " + numSkinBone as string) 
            
            if vertexDataMap.count > 0 then 
            (
                fn_addLog ("检查完成,发现问题 (用时: " + elapsedStr + " 秒)") level:#success
                pb3.color = red 
            ) 
            else 
            (
                local item = lst_problems.Items.Add "✓ 没有发现问题"
                item.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 144 238 144
                fn_addLog ("检查完成,没有发现问题 (用时: " + elapsedStr + " 秒)") level:#success
                pb3.color = green 
            )
        )
        catch 
        (
            local errMsg = "检查出错: " + (getCurrentException()) 
            fn_addLog errMsg level:#error
            pb3.value = 0
            pb3.color = red
        )
    )

-- fn_orderCheck useHighVersion:true   -- 使用高版本模式
-- fn_orderCheck useHighVersion:false  -- 使用低版本模式
fn fn_orderCheck2 useHighVersion:true = 
(
     try 
     (
         if selection.count == 0 then 
         (
             fn_addLog "错误: 未选择对象" level:#error
             return()
         )
         fn_clearIni()
        
         local startTime = timestamp()
         try 
         (
             if selection[1].modifiers[#Skin] != undefined then
             (
                 if useHighVersion then
                     skinOps.closeWeightTool selection[1].modifiers[#Skin] node:selection[1]
                 else
                     skinOps.closeWeightTool selection[1].modifiers[#Skin]
             )
         )
         catch()
        
         currentObj = selection[1]
         edt_selection.Text = currentObj.name
         windows.processPostedMessages()
         fn_addLog ("使用精确检查") level:#success
         fn_addLog ("开始检查对象: " + currentObj.name) level:#success
        
         markedVertices = #()
         roundInfoList = #()
         completeRedraw()
         pb3.value = 0
         pb3.color = yellow
        
         -- 低版本需要设置选择模式
         if not useHighVersion then
             select currentObj
         else
             max create mode
        
         currentSkinMod = undefined
         for m in currentObj.modifiers do 
         (
             if classOf m == Skin then 
             (
                 currentSkinMod = m
                 exit
             )
         )
         if currentSkinMod == undefined then 
         (
             fn_addLog "错误: 对象没有Skin修改器" level:#error
             return()
         )
        
         pb3.value = 0
         fn_addLog "创建网格快照..." level:#success
         local snapshotMesh = snapshotasmesh currentObj
         pb3.value = 5
         windows.processPostedMessages()
        
         local numVerts = meshop.getNumVerts snapshotMesh
         local numFaces = meshop.getNumFaces snapshotMesh
         local vertexRingBitArrays = #()
         for i = 1 to numVerts do 
             vertexRingBitArrays[i] = #{}
        
         for f = 1 to numFaces do
         (
             if mod f 500 == 0 then 
             (
                 pb3.value = 5 + (20.0 * f / numFaces) as integer
                 windows.processPostedMessages()
             )
            
             local face = meshop.getFace snapshotMesh f
             local v1 = face.x as integer
             local v2 = face.y as integer
             local v3 = face.z as integer
            
             vertexRingBitArrays[v1][v2] = true
             vertexRingBitArrays[v1][v3] = true
             vertexRingBitArrays[v2][v1] = true
             vertexRingBitArrays[v2][v3] = true
             vertexRingBitArrays[v3][v1] = true
             vertexRingBitArrays[v3][v2] = true
         )
        
         pb3.value = 25
         windows.processPostedMessages()
        
         local vertexRingCache = #()
         for v = 1 to numVerts do
         (
             vertexRingCache[v] = vertexRingBitArrays[v] as array
             append vertexRingCache[v] v
         )
         vertexRingBitArrays = undefined
        
         fn_addLog "预处理完成，开始检查骨骼..." level:#success
         problemBones = #()
         lst_problems.Items.Clear()
         vertexDataMap = #()
        
         -- 低版本需要设置修改面板
         if not useHighVersion then
         (
             max modify mode
             modPanel.setCurrentObject currentSkinMod
             subobjectLevel = 1
         )
        
         local numSkinBone = if useHighVersion then 
             skinOps.GetNumberBones currentSkinMod node:currentObj 
         else 
             skinOps.GetNumberBones currentSkinMod
            
         for num = 1 to numSkinBone do 
         (
             pb3.value = 25 + (70.0 * num / numSkinBone) as integer
             local boneName = ""
             try
             (
                 boneName = if useHighVersion then
                     skinOps.GetBoneName currentSkinMod num 1 node:currentObj
                 else
                     skinOps.GetBoneName currentSkinMod num 1
             )
             catch
             (
                 boneName = "Bone_" + num as string
             )
            
             if useHighVersion then
             (
                 skinOps.SelectBone currentSkinMod num node:currentObj
                 skinOps.selectVerticesByBone currentSkinMod node:currentObj
                 local allSkinVerts = skinOps.GetSelectedVertices currentSkinMod node:currentObj
             )
             else
             (
                 skinOps.SelectBone currentSkinMod num
                 skinOps.selectVerticesByBone currentSkinMod
                 local allSkinVerts = fn_quickGetSelectedVerts currentSkinMod
                 subobjectLevel = 0
             )
            
             local errorAry = #()
             if allSkinVerts.count > 0 then 
             (
                 local allStableSets = #()
                 local remainingVerts = allSkinVerts as bitArray
                 local allSkinVertsBits = allSkinVerts as bitArray
                
                 while remainingVerts.count > 0 do 
                 (
                     local seedArray = remainingVerts as array
                     if seedArray.count == 0 then exit
                     local seedVert = seedArray[1]
                     local region = #{seedVert}
                     local toExpand = #{seedVert}
                     local safeCounter = 0
                     local maxIterations = 100000
                    
                     while toExpand.count > 0 do
                     (
                         safeCounter += 1
                         if safeCounter > maxIterations then
                         (
                             fn_addLog ("警告: 骨骼【" + boneName + "】区域扩展超时") level:#warning
                             exit
                         )
                        
                         local newVerts = #{}
                         local expandArray = toExpand as array
                        
                         for v in expandArray do
                         (
                             if v > 0 and v <= vertexRingCache.count then
                             (
                                 local neighborsArray = vertexRingCache[v]
                                 if neighborsArray != undefined then
                                 (
                                     local neighborsBits = neighborsArray as bitArray
                                     local validNeighbors = neighborsBits * allSkinVertsBits - region
                                     newVerts += validNeighbors
                                 )
                             )
                         )
                         region += newVerts
                         toExpand = newVerts
                     )
                     local regionArray = region as array
                     if regionArray.count > 0 then
                         append allStableSets regionArray
                     remainingVerts -= region
                 )
                
                 -- 检查是否有多个区域
                 if allStableSets.count > 1 then 
                 (
                     -- 找到顶点数最多的区域作为主区域
                     local maxCount = 0
                     local mainRegionIndex = 1
                     for i = 1 to allStableSets.count do
                     (
                         if allStableSets[i].count > maxCount then
                         (
                             maxCount = allStableSets[i].count
                             mainRegionIndex = i
                         )
                     )
                    
                     fn_addLog ("骨骼【" + boneName + "】主区域: " + maxCount as string + " 个顶点") level:#info
                    
                     -- 将除主区域外的所有区域标记为问题区域
                     if not useHighVersion then subobjectLevel = 1
                    
                     for i = 1 to allStableSets.count do
                     (
                         -- 跳过主区域
                         if i != mainRegionIndex then
                         (
                             local regionVerts = allStableSets[i]
                             if regionVerts.count > 0 then
                             (
                                 append errorAry regionVerts
                             )
                         )
                     )
                    
                     if not useHighVersion then subobjectLevel = 0
                 )
             )
            
             if errorAry.count > 0 then 
             (
                 local boneItem = lst_problems.Items.Add ("【" + boneName + "】")
                 append vertexDataMap #(boneName, num, undefined)
                 for regionIndex = 1 to errorAry.count do 
                 (
                     local regionVerts = errorAry[regionIndex]
                     local item = lst_problems.Items.Add ("        区域 " + regionIndex as string + ": " + regionVerts.count as string + " 个问题顶点")
                     append vertexDataMap #(boneName, num, regionVerts)
                 )
                 lst_problems.EnsureVisible (lst_problems.Items.Count - 1)
                 fn_addLog (boneName + " 发现 " + errorAry.count as string + " 个问题区域") level:#warning
             )
         )
        
         pb3.value = 95
         delete snapshotMesh
         pb3.value = 100
        
         local endTime = timestamp()
         local elapsed = (endTime - startTime) / 1000.0
         local elapsedStr = formattedPrint elapsed format:".2f"
         fn_addLog ("处理了 " + numVerts as string + " 个线...")
         fn_addLog ("处理了 " + numFaces as string + " 个面...")
         fn_addLog ("骨骼数量: " + numSkinBone as string) 
        
         if vertexDataMap.count > 0 then 
         (
             fn_addLog ("检查完成,发现问题 (用时: " + elapsedStr + " 秒)") level:#success
             pb3.color = red 
         ) 
         else 
         (
             local item = lst_problems.Items.Add "✓ 没有发现问题"
             item.ForeColor = (dotNetClass "System.Drawing.Color").FromArgb 144 238 144
             fn_addLog ("检查完成,没有发现问题 (用时: " + elapsedStr + " 秒)") level:#success
             pb3.color = green 
         )
     )
     catch 
     (
         local errMsg = "检查出错: " + (getCurrentException()) 
         fn_addLog errMsg level:#error
         pb3.value = 0
         pb3.color = red
     )
)

    on btn_check pressed do
    (
       if fn_getMaxVersion() >= 2020 then --20版本为分界用不同的Skinops处理.主要因为低版本很多Api缺失
       (
            fn_orderCheck useHighVersion:true
       )
       else
       (
           fn_orderCheck useHighVersion:false
       )
    )
    on btn_check rightclick do
    (
       if fn_getMaxVersion() >= 2020 then --20版本为分界用不同的Skinops处理.主要因为低版本很多Api缺失
       (
            fn_orderCheck2 useHighVersion:true
       )
       else
       (
           fn_orderCheck2 useHighVersion:false
       )
    )
    on btn_clear pressed do
    (
        fn_clearIni()
    )
)
createDialog SkinIslandChecker backgroundColor:(color 68 68 68) fgcolor:[100,200,100] style:#(#style_titlebar, #style_border, #style_sysmenu, #style_minimizebox)