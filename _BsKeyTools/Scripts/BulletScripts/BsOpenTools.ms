/*
* @Description: 快速打开max文件，并保存常用目录
* @Author: Bullet.S
* @Date: 2019-11-23 01:41:13
 * @LastEditors: Bullet.S
 * @LastEditTime: 2025-05-11 23:37:12
* @Email: animator.bullet@foxmail.com
*/


try(destroydialog rolBsOpenTools)catch()
try(destroydialog rolAddItem)catch()

struct itemsFolder (name,dir)
Global iniPosOpenTools
Global iniWidthOpenTools = 340
Global iniDesktop        = (itemsFolder name:"Desktop" dir:"")
Global iniSelectedID     = 1
Global iniLikedFolder    = #()
Global iniFilterPrefix   = #()

try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnSaveLoadConfig.ms"))
catch(messagebox "脚本安装可能不完全,建议重新安装...        " beep:false)
try(FileIn ((getDir #scripts) + "\\BulletScripts\\fnGetColorTheme.ms"))
catch(messagebox "脚本安装可能不完全,建议重新安装...        " beep:false)
stLoadConfigAll.fnLoadConfigBsOpenTools ()

struct itemsFolder (name,dir)
global dateTime = (dotNetClass "System.DateTime").Now
global arrDayWeek = #("日", "一", "二", "三", "四", "五", "六")
Global BulletConfig = execute ("@\"" + (getDir #maxData) + "\\BulletConfig.ini\"")  --配置文件路径

-- Global iniRefPicDir			= (itemsFolder name:"RefPicDir" dir:"")
Global posMouMove         = [0,0]
Global switchMouState     = false

Global arrFolders         = #()
Global arrFoldersName     = #()
Global arrFiles           = #()
Global arrFilesName       = #()
Global dirLiked           = ""
Global dirOpened          = ""
Global arrDirItems        = #()
Global arrPreItems        = #()
Global arrRecentFiles     = #()
Global arrRecentFilesName = #()
Global arrFileType        = #(".max",".fbx",".bip",".ms*", ".mzp")
Global rolBsOpenTools
Global fnRefreshList
Global tempLastFolder

rollout rolAddItem "添加常用路径" width:340 height:80
(
	groupbox gbxAddDir "添加常用路径  ---------- Tips：右击框内条目删除 " width:330 height:70 pos:[5,5]
	
	edittext edtAddDir "收藏命名" pos:[10,50] fieldWidth:210 height:20 labelOnTop:false text:""
	button btnOpenDir "选择目录"  pos:[275,25] width:55 height:20 tooltip:"选择添加目录，默认打开当前文件目录"
	edittext edtDirStr "" pos:[5,25] fieldWidth:262 height:20 readOnly:true
	
	-- groupbox gbxAddPre "添加过滤前缀  ---------- Tips：右击框内条目删除 "  width:330 height:70 pos:[5,5]
	-- edittext edtPrefix ""  text:"" fieldWidth:262 height:35 pos:[5,35]

	button btnAddItems "添加" width:55 height:25 pos:[275,45]

	fn fnAddToFavorite =
	(
		if ((edtDirStr.text != "") and (edtAddDir.text != "") and (edtDirStr.visible == true)) then
		(
			local fnExist = 0
			for i = 1 to iniLikedFolder.count do 
			(
				if matchPattern iniLikedFolder[i].dir pattern:edtDirStr.text then 
				(
					fnExist = 1
				)
			)
			if fnExist == 0 then
			(
				append iniLikedFolder (itemsFolder edtAddDir.text edtDirStr.text)
				arrDirItems = #()
				for i = iniLikedFolder.count to 1 by -1 do
				(
					append arrDirItems iniLikedFolder[i].name
				)
				rolBsOpenTools.ltbLikedFolder.items = arrDirItems
				rolBsOpenTools.ltbLikedFolder.selection = 1
				-- fnRefreshList rolBsOpenTools.edtBrowseFolder.text type:arrFileType[rolBsOpenTools.rdoFileType.state]
			)
			else (messagebox "----------------------------------------\r\n可能常用目录中已存在此目录~")
		)
	)

	on btnOpenDir pressed do 
	(
		local dir = getSavePath caption:"请选择目录:" initialDir:(maxFilePath)
		if (dir != undefined) then
		(
			edtDirStr.text = dir
		)
	)

	on edtAddDir changed txt do 
	(
		tempText = substituteString txt "\n" ""
		edtAddDir.text = tempText
		-- print edtAddDir.text
	)

	on edtPrefix changed txt do 
	(
		tempText = substituteString txt "\n" ""
		edtPrefix.text = tempText
		-- print edtPrefix.text
	)

	on btnAddItems pressed do 
	(
		fnAddToFavorite()
		try(destroydialog rolAddItem)catch()
		rolBsOpenTools.fnRefreshList rolBsOpenTools.edtBrowseFolder.text type:arrFileType[rolBsOpenTools.rdoFileType.state]
		iniSelectedID = rolBsOpenTools.ltbLikedFolder.selection
		stSetConfigAll.fnSetConfigBsOpenTools ()
	)
)

rollout rolBsOpenTools "" width:580 height:400
(
	groupbox grpMain "时光机_v1.1" \
	width:570 height:395 pos:[5,0]
	button btnClose "X" pos:[rolBsOpenTools.width - 15,0] height:15 width:15 border:false
	editText edtBrowseFolder "" text:"" labelOnTop:false align:#right \
	height:20 fieldWidth:425 pos:[70,22] readOnly:true 
	button btnOpenAddress "..." align:#right tooltip:"选择打开目录" \
	height:22 width:30 pos:[37,20] border:false
	button btnAddPathToVavorite "✚" align:#left border:false \
	height:22 width:30 pos:[505,20] tooltip:"添加当前路径至常用目录"
	button btnOpenCurrentDir "O" tooltip:"打开当前文件夹" \
	height:22 width:30 pos:[535,20] border:false
	-- button btnRemoveFolder "━" align:#left \
	-- height:20 width:25 pos:[10,20] tooltip:"删除选中的收藏目录"
	-- button btnAddFolder "✚" align:#left border:false \
	-- height:20 width:20 pos:[35,20] tooltip:"新增常用目录"
	button btnRefreshFolder "↻" align:#left border:false \
	height:22 width:25 pos:[10,20] tooltip:"左：刷新当前文件目录\r\n\r\n右：重置场景"
	label lblLikedFolderTitle "常用目录" align:#left \
	height:18 width:60 pos:[15,50]
	button btnAddLikedFolder "＋" border:true \
	height:18 width:18 pos:[75,50] tooltip:"添加常用目录"
	button btnDelLikedFolder "－" border:true \
	height:18 width:18 pos:[95,50] tooltip:"删除选中常用目录"
	listbox ltbLikedFolder "" selection:0 \
	height:22 Width:105 pos:[10,75]
	editText edtInputFilter "" text:"" labelOnTop:false align:#left \
	height:17 fieldWidth:100 pos:[115,75]
	listBox ltbFilesList "" align:#right selection:0 \
	height:22 width:340 pos:[225,75]
	label lblFilterPrefixTitle "过滤词缀" align:#left \
	height:18 width:60 pos:[125,50]
	button btnAddFilterPrefix "＋" border:true \
	height:18 width:18 pos:[180,50] tooltip:"添加过滤词缀"
	button btnDelFilterPrefix "－" border:true \
	height:18 width:18 pos:[200,50] tooltip:"删除选中过滤词缀"
	checkbutton ckbReverse "倒序" pos:[480,50] height:18 width:40 border:true
	button btnPrevFolder "上层" tooltip:"返回上层目录，也可右击面板空白处" \
	height:18 width:40 pos:[525,50] border:true
	listBox ltbFilterPrefix "" align:#left selection:0 \
	height:10 width:100 pos:[120,100]
	radioButtons rdoFileType "" columns:5 \
	pos:[235,50] labels:#(".max",".fbx",".bip",".ms", ".mzp") 

	checkbox ckbSilentOpen "静默打开Max" pos:[125,240] width:90 height:15 checked:true
	button btnRecentFileDir "最近打开" border:true \
	height:25 width:100 pos:[120,260] tooltip:"最近打开文件"
	button btnDesktopDir "桌面自定" border:true \
	height:25 width:100 pos:[120,285] tooltip:"自定文件夹，默认桌面，右键可重设"
	button btnScriptsDir "脚本目录" border:true \
	height:25 width:100 pos:[120,310] tooltip:"脚本文件夹\r\n左：根目录\r\n右：自启目录"
	button btnAutobackDir "自动保存" border:true \
	height:25 width:100 pos:[120,335] tooltip:"自动保存目录"
	-- button btnPreviewDir "<轮回梦境>" border:false \
	-- height:25 width:70 pos:[10,310] tooltip:"左：预览视频默认文件夹\r\n右：快速拍屏渲染预览动画"
	groupBox grpDate "" width:570 height:30 pos:[5,365]
	label lblLikedFolder "" height:15 width:140 pos:[10,375]
	label lblCountTips "" height:15 width:80 pos:[470,375]
	label lblDateTime "" height:15 width:140 pos:[180,375] 
	HyperLink lnkLink "Bullet.S" color:myfgColor hovercolor:myClickColor visitedcolor:myClickColor \
	pos:[330,375] address:"https://space.bilibili.com/2031113"
	-- checkbutton ckbLockWidth "🔒" pos:[86,312] width:20 height:20 border:false \
	-- toolTip:"是否解锁宽度调节\r\n右：重置宽度" checked:false
	-- slider sldSetWidth "" pos:[113,312] range:[340,540,iniWidthOpenTools] ticks:0 \
	-- width:222 type:#integer toolTip:"调节面板宽度,以显示更多字" enabled:false
	-- label labLogo "-------------------------  TECH OTAKUS SAVE THE WORLD -" pos:[12,365]
	------------------------------------------------- ↑ UI -------------------------------------
	
	-- global charClass = dotNetClass "System.Char" --dotnet charclass used for isDigit comparisment
	-- dotNetClass:System.Char

	fn getFilesequenceFile f &base &digits = 
	(
		f = getFilenameFile f
		base = trimRight f "0123456789"
		digits = subString f (base.count + 1) -1
	)

	fn fnPseudoNaturalSort a b =  --文件名排序新方法--https://forums.cgsociety.org/t/sorting-filenames/1219205/4
	(
		a = a as string
		b = b as string
		getFilesequenceFile a &aBase &aDigits
		-- hackhackhack.  This pads a number with zeros to 6 digits without using a loop.
		-- things will fail if there's more digits.. 6 'seems' safe.
		aDigits = subString ((1000000 + (aDigits as integer)) as string) 2 -1
		getFilesequenceFile b &bBase &bDigits
		bDigits = subString ((1000000 + (bDigits as integer)) as string) 2 -1
		a = aBase + aDigits
		b = bBase + bDigits
	
		case of (
		(a == b): 0
		(a < b): -1
		(a > b): 1
		)
	)
-------------------------------------↑ 文件排序方法 --------------------------------------------------
	Fn fnLoadRecentFileList = -------获取最近打开文件列表
	(
		local recentfiles = (getdir #maxData) + "RecentDocuments.xml"
		if doesfileexist recentfiles then
		(
			arrRecentFiles     = #()
			arrRecentFilesName = #()
			xDoc = dotnetobject "system.xml.xmldocument"	
			xDoc.Load recentfiles
			Rootelement = xDoc.documentelement

			arrRecentFiles = for i = 0 to rootelement.childnodes.item[4].childnodes.itemof[0].childnodes.count-1 collect 
			(
				rootelement.childnodes.item[4].childnodes.itemof[0].childnodes.itemof[i].childnodes.itemof[3].innertext	
			)
			Return arrRecentFiles
			LRXML = Undefined
			XDoc = Undefined
			XDoc = nothing	
		)
		if arrRecentFiles[1] != undefined then
		(
			for c in arrRecentFiles do  --获取文件夹名字,后面切换脚本类别和列表会用到
			(
				append arrRecentFilesName ("📄 " + (getFilenameFile (substring c 1 (c.count-1))))
			)
		)
	)

	fn fnGetLastFolder strFolder =
	(
		if ((strFolder != "") and (doesDirectoryExist strFolder)) then
		(
			local arrFilterStr = filterstring strFolder @"\"
			local strLastFolder = ""
			for i = 1 to (arrFilterStr.count - 1) do 
			(
				strLastFolder = strLastFolder  + arrFilterStr[i] + @"\\"
			)
		)
		return strLastFolder
	)
	
	fn fnRefreshList strFilesDir filename:(rolBsOpenTools.ltbFilterPrefix.selected) type:".max" =
	(
		arrFolders = #()
		arrFiles = #()
		arrFoldersName = #()
		arrFilesName = #()
		arrAll = #()
		arrFinal = #()
		if strFilesDir != undefined then 
		(
			if ((strFilesDir != "") and (doesDirectoryExist strFilesDir)) then
			(
				local tempDir = GetDirectories (strFilesDir + "/*")
				for i in tempDir do 
				(
					append arrFolders (substring i 1 (i.count-1))
				)
				qsort arrFolders fnPseudoNaturalSort
				(arrFilesBeforeFilter = getFiles (strFilesDir + "\\*" + type))
				qsort arrFilesBeforeFilter fnPseudoNaturalSort
				if (filename != undefined) then
				(
					for i in arrFilesBeforeFilter do 
					(
						if (matchpattern (getfilenamefile i) \
						pattern:("*" + filename + "*")) then 
						(append arrFiles i)
					)
					rolBsOpenTools.edtInputFilter.text = filename
				)
				else arrFiles = arrFilesBeforeFilter
				
				if arrFolders[1] != undefined then
				(
					for c in arrFolders do  --获取文件夹名字,后面切换脚本类别和列表会用到
					(
						append arrFoldersName ("📂 " + (getFilenameFile c))
					)
				)
				if arrFiles[1] != undefined then
				(
					for c in arrFiles do  --获取文件名字,后面切换脚本类别和列表会用到
					(
						(append arrFilesName ("📄 " + (getFilenameFile c) + type))
					)
				)
				if rolBsOpenTools.ckbReverse.state == true then 
				(
					arrAll = (arrFoldersName + arrFilesName)
					tempArray = for i = arrAll.count to 1 by -1 collect arrAll[i]
					arrFinal = for i in tempArray collect i
					rolBsOpenTools.ltbFilesList.items = arrFinal
				)
				else
				(
					rolBsOpenTools.ltbFilesList.items = arrFoldersName + arrFilesName
				)
				rolBsOpenTools.edtBrowseFolder.text = strFilesDir
				for i = 1 to iniLikedFolder.count do 
				(
					if matchPattern iniLikedFolder[i].dir pattern:strFilesDir then 
					(
						rolBsOpenTools.ltbLikedFolder.selection = iniLikedFolder.count + 1 - i
					)
				)
			)
			else 
			(
				if ((iniSelectedID != 0) and (iniLikedFolder.count > 0)) then
				(
					rolBsOpenTools.ltbLikedFolder.selection = iniSelectedID
					fnRefreshList iniLikedFolder[iniLikedFolder.count + 1 - iniSelectedID].dir
				)
			)
		)
		else messagebox "-------------------------------------\r\n文件夹可能已不存在\r\n请尝试刷新\r\n"
		lblCountTips.text = "文件：" + arrFiles.count as string
		lblLikedFolder.text = if ltbLikedFolder.selected == undefined then "请添加常用目录" else ltbLikedFolder.selected
	)
	
	fn fnRefreshAddress =
	(
		if (maxFilePath != "") then 
		(
			local tempMaxFilePath = (substring maxFilePath 1 (maxFilePath.count-1))
			fnRefreshList tempMaxFilePath type:arrFileType[rdoFileType.state]
		)
		else 
		(
			if rolBsOpenTools.ltbLikedFolder.selection != 0 then 
			(
				local tempSelectionID = rolBsOpenTools.ltbLikedFolder.selection
				edtBrowseFolder.text = iniLikedFolder[iniLikedFolder.count + 1 - tempSelectionID].dir
			)
			else 
			(
				edtBrowseFolder.text = " ( 打开目录 )"
			)
		)
	)

	fn fnRefLikedFolderItems =
	(
		arrDirItems = #()
		if iniLikedFolder.count != 0 then
		(
			for i = iniLikedFolder.count to 1 by -1 do
			(
				if (doesDirectoryExist iniLikedFolder[i].dir) then 
				(
					append arrDirItems iniLikedFolder[i].name
				)
				else 
				(
					messagebox (iniLikedFolder[i].dir + "\r\n文件夹不存在\r\n已从常用路径中删除                                                                          \r\n")
					deleteitem iniLikedFolder i
				)
			)
		)
		else 
		(
			lblLikedFolder.text = "请添加常用目录"
		)
		rolBsOpenTools.ltbLikedFolder.items = arrDirItems
	)

	fn fnRefreshFilterItems =
	(
		local arrPreItems = #()
		for i = iniFilterPrefix.count to 1 by -1 do
		(
			append arrPreItems iniFilterPrefix[i]
		)
		rolBsOpenTools.ltbFilterPrefix.items = arrPreItems
	)

	fn fnLoadBip fBip =
	(
		-- biped.loadBipFile <biped_ctrl> <file_name> \
		-- [#matchFileStruct] [#zeroHgt] [#noRedraw] \
		-- [#loadMaxObjects][#promptForDuplicates] [#retargetHeight] \
		-- [#retargetLimbSizes] [#scaleIKObjectSize] [#loadSubAnimControllers] \
		-- [#loadSelectedMaxObjects nodename_array] \
		-- [#loadSelectedSubAnimControllers bipednodename_array int_array]

		local numSelbiped = #()   -------判断选择了几个biped骨架
		if selection.count != 0 then
		(
			for i in (selection as array) where ((classof i == Biped_Object) and (i.ishidden == false)) do  
			(
				appendIfUnique numSelbiped i.controller.rootNode  --添加到骨架数组
			)
			for b in numSelbiped do 
			(
				biped.loadBipFile b.controller fBip #noRedraw
			)
		)
	)

	fn fnRefreshDate =
	(
		local arrTime = (getLocalTime())
		local dayWeekID = (mod arrTime[3] 7) as integer
		lblDateTime.text = dateTime.Year as string + "/" + dateTime.Month as string + "/" \
		+ dateTime.Day as string + "  星期" + arrDayWeek[dayWeekID + 1] as string
	)

	----------------------------------------------------------------------------------------------------
	
	on rolBsOpenTools open do 
	(
		-- sldSetWidth.value        = iniWidthOpenTools
		-- rolBsOpenTools.width     = iniWidthOpenTools
		btnRefreshFolder.images  = #("UVWUnwrapModes_16i.bmp","UVWUnwrapModes_16i.bmp",28,3,3,3,3,true,false)
		-- ckbLockWidth.images      = #("LockButtonExt_i.bmp","LockButtonExt_i.bmp",2,1,1,2,2,true,false)
		btnAddPathToVavorite.images = #("enss_tools_16i.bmp","enss_tools_16a.bmp",13,5,5,6,6,false,true)
		btnOpenCurrentDir.images = #("bip_general_i.bmp","bip_general_i.bmp",30,5,5,6,6,false,true)
		-- btnPrevFolder.images     = #("MergeAnim_24i.bmp","MergeAnim_24i.bmp",4,1,1,1,1,false,true)
		stLoadConfigAll.fnLoadConfigBsOpenTools ()  ---------------脚本位置等赋值
		stSetConfigAll.fnSetConfigBsOpenTools ()  ----------------保存位置信息到ini文件	
		fnRefLikedFolderItems ()
		fnRefreshAddress ()
		fnRefreshList maxFilePath type: arrFileType[rdoFileType.state]
		lblCountTips.text = "文件：" + arrFiles.count as string
		lblLikedFolder.text = if ltbLikedFolder.selected == undefined then "请添加常用目录" else ltbLikedFolder.selected
		ltbFilterPrefix.selection = 0
		fnRefreshFilterItems ()
		ltbLikedFolder.selection = iniSelectedID
		fnRefreshDate ()
	)

	on rolBsOpenTools close do -- 关闭记忆浮动窗口位置
	(
		iniPosOpenTools   = (GetDialogPos rolBsOpenTools)
		iniSelectedID     = rolBsOpenTools.ltbLikedFolder.selection
		iniWidthOpenTools = rolBsOpenTools.width
		stSetConfigAll.fnSetConfigBsOpenTools ()
	)

	on rolBsOpenTools mbuttondown pos do 
	(
		try (destroydialog rolBsOpenTools) catch ()
		try(destroydialog rolAddItem)catch()
	)

	on rolBsOpenTools lbuttondown posMou do
	(
		posMouMove = posMou
		switchMouState = on
	)

	on rolBsOpenTools lbuttonup posMou do
	(
		switchMouState = off
	)

	on rolBsOpenTools rbuttondown pos do 
	(
		tempLastFolder = fnGetLastFolder edtBrowseFolder.text
		fnRefreshList tempLastFolder type:arrFileType[rdoFileType.state]
		rolBsOpenTools.ltbFilesList.selection = 0
	)

	on rolBsOpenTools mouseMove pos do
	(
		if switchMouState == on then
		(
			SetDialogPos rolBsOpenTools (mouse.screenpos - posMouMove)			
		)
	)

	-- on rolBsOpenTools resized pos do
	-- (
	-- 	grpMain.width          = rolBsOpenTools.width - 10
	-- 	grpDate.width          = rolBsOpenTools.width - 10
	-- 	edtBrowseFolder.width  = rolBsOpenTools.width - 130
	-- 	ltbFilesList.width     = rolBsOpenTools.width - 95
	-- 	btnOpenCurrentDir.pos  = [rolBsOpenTools.width - 35,20]
	-- 	btnPrevFolder.pos      = [rolBsOpenTools.width - 60,20]

	-- )
	------------------------------------------------------------------------------

	-- on ckbLockWidth changed state do 
	-- (
	-- 	if state == on then sldSetWidth.enabled = true 
	-- 	else sldSetWidth.enabled = false
	-- )

	-- on ckbLockWidth rightclick do
	-- (
	-- 	rolBsOpenTools.width = 340
	-- 	sldSetWidth.value    = 340
	-- )

	-- on sldSetWidth changed ticks do
	-- (
	-- 	rolBsOpenTools.width = ticks
	-- )

	on btnRefreshFolder pressed do 
	(
		fnRefreshAddress ()
		fnRefreshList edtBrowseFolder.text type:arrFileType[rdoFileType.state]
	)

	on btnPrevFolder pressed do 
	(
		tempLastFolder = fnGetLastFolder edtBrowseFolder.text
		fnRefreshList tempLastFolder type:arrFileType[rdoFileType.state]
		rolBsOpenTools.ltbFilesList.selection = 0
	)

	on btnRefreshFolder rightclick do 
	(
		if CheckForSave() then 
		(
			resetMaxFile #noPrompt
			max tool maximize
		)
	)

	on btnOpenCurrentDir pressed do 
	(
		if (doesDirectoryExist edtBrowseFolder.text) then
		(
			shellLaunch edtBrowseFolder.text ""
		)
	)

	on edtBrowseFolder changed txt do
	(
		fnRefreshList txt type:arrFileType[rdoFileType.state]
	)

	on rdoFileType changed state do
	(
		fnRefreshList rolBsOpenTools.edtBrowseFolder.text type:arrFileType[state]
	)

	on btnOpenAddress pressed do 
	(
		dirOpened = getSavePath caption:"请选择Max文件路径:" initialDir:(maxFilePath)
		if (dirOpened != undefined) then
		(
			edtBrowseFolder.text = dirOpened
			fnRefreshList dirOpened type:arrFileType[rdoFileType.state]
		)
	)
	
	on btnAddLikedFolder pressed do 
	(
		try(destroydialog rolAddItem)catch()
		createdialog rolAddItem fgcolor:myfgColor pos:mouse.screenpos
	)

	on btnDelLikedFolder pressed do
	(
		if iniLikedFolder.count > 0 and ltbLikedFolder.selection != 0 then
		(
			idDel = iniLikedFolder.count + 1 - ltbLikedFolder.selection
			local delName = iniLikedFolder[idDel].name
			local confirmResult = queryBox ("确定要删除常用目录 \"" + delName + "\" 吗?") title:"删除确认" beep:false
			if confirmResult then
			(
				deleteItem iniLikedFolder idDel
				print idDel
				fnRefLikedFolderItems ()
			)
		)
	)

	on btnAddPathToVavorite pressed do 
	(
		try(destroydialog rolAddItem)catch()
		createdialog rolAddItem fgcolor:myfgColor pos:mouse.screenpos
		
		if (edtBrowseFolder.text != "") then
		(
			rolAddItem.edtDirStr.text = edtBrowseFolder.text
			rolAddItem.fnAddToFavorite()
		)
	)

	on btnAddFilterPrefix pressed do 
	(
		if (edtInputFilter.text != "") then
		(
			if (findItem iniFilterPrefix edtInputFilter.text) != 0 then 
			(
				messagebox "-------------------------------------\r\n可能过滤词缀中已存在~"
			)
			else
			(
				append iniFilterPrefix edtInputFilter.text
				arrPreItems = #()
				for i = iniFilterPrefix.count to 1 by -1 do
				(
					append arrPreItems iniFilterPrefix[i]
				)
				rolBsOpenTools.ltbFilterPrefix.items = arrPreItems
				rolBsOpenTools.ltbFilterPrefix.selection = 1
			)
			rolBsOpenTools.fnRefreshList rolBsOpenTools.edtBrowseFolder.text type:arrFileType[rolBsOpenTools.rdoFileType.state]
		)
		else 
		(
			messagebox "--------------------------------------\r\n请在按钮下方输入过滤词缀~\r\n--------------------------------------"
		)
	)

	on btnDelFilterPrefix pressed do 
	(
		if iniFilterPrefix.count > 0 and ltbFilterPrefix.selection != 0 then
		(
			idDel = iniFilterPrefix.count + 1 - ltbFilterPrefix.selection
			local delPrefix = iniFilterPrefix[idDel]
			local confirmResult = queryBox ("确定要删除过滤词缀 \"" + delPrefix + "\" 吗?") title:"删除确认" beep:false
			if confirmResult then
			(
				deleteItem iniFilterPrefix idDel
				fnRefreshFilterItems ()
				fnRefreshList edtBrowseFolder.text type:arrFileType[rdoFileType.state]
			)
		)
	)

	on ltbLikedFolder selected id do
	(
		if iniLikedFolder[id] != undefined then
		(
			strDir = iniLikedFolder[iniLikedFolder.count + 1 - id].dir
			fnRefreshList strDir type:arrFileType[rdoFileType.state]
		)
		iniSelectedID = id
	)
	
	on ltbLikedFolder rightclick id do
	(
		btnDelLikedFolder.pressed()
	)

	on ltbFilterPrefix selected id do
	(
		fnRefreshList edtBrowseFolder.text type:arrFileType[rdoFileType.state]
	)
	
	on ltbFilterPrefix rightclick id do
	(
		btnDelFilterPrefix.pressed()
	)

	on ltbFilesList rightclick id do
	(
		tempLastFolder = fnGetLastFolder edtBrowseFolder.text
		fnRefreshList tempLastFolder type:arrFileType[rdoFileType.state]
		rolBsOpenTools.ltbFilesList.selection = 0
	)

	on ltbFilesList doubleClicked id do
	(
		if (doesDirectoryExist edtBrowseFolder.text) then
		(
			idNew = id
			if rolBsOpenTools.ckbReverse.state == true then 
			(
				idNew = (arrFiles.count + arrFolders.count) + 1 - id
			)
			-- if edtBrowseFolder.text == (getdir #preview) then ramplayer arrFiles[idNew] ""
			-- else 
			-- (
				case of
				(
					((idNew <= arrFolders.count) and (idNew > 0)):
					(
						edtBrowseFolder.text = arrFolders[idNew]
						fnRefreshList edtBrowseFolder.text type:arrFileType[rdoFileType.state]
						-- fnRefreshList edtBrowseFolder.text type:arrFileType[rdoFileType.state]
					)
					(idNew > arrFolders.count):
					(
						local idFile = idNew - arrFolders.count
						case of 
						(
							(rdoFileType.state == 1):
							(
								if CheckForSave() then 
								(
									loadMaxFile (arrFiles[idFile] as string) useFileUnits:true quiet:ckbSilentOpen.state
								)
							)
							(rdoFileType.state == 2):(importFile arrFiles[idFile] #noPrompt using:FBXIMP)
							(rdoFileType.state == 3):(fnLoadBip arrFiles[idFile])
							(rdoFileType.state == 4):(fileIn arrFiles[idFile])
							(rdoFileType.state == 5):(fileIn arrFiles[idFile])
						)
					)
				)
			-- )
		)
		else 
		(
			if edtBrowseFolder.text == "( 最近打开 Max 文件列表 )" then
			(
				if doesFileExist arrRecentFiles[id] then 
				(
					loadMaxFile (arrRecentFiles[id]) useFileUnits:true quiet:ckbSilentOpen.state
					local tempDir = getfilenamepath arrRecentFiles[id]
					fnRefreshList tempDir type:arrFileType[rdoFileType.state]
				)
			)
		)
	)

	on btnDesktopDir pressed do 
	(
		if iniDesktop.dir == "" then 
		(
			iniDesktop.dir = (@"C:\Users\" + (filterString  (getdir #userscripts) @"\")[3] + @"\Desktop\")
		)
		fnRefreshList iniDesktop.dir type:arrFileType[rdoFileType.state]
	)

	on btnDesktopDir rightclick do 
	(
		dirOpened = getSavePath caption:"请设置桌面路径:" initialDir:(maxFilePath)
		if (dirOpened != undefined) then
		(
			iniDesktop.dir = dirOpened
			fnRefreshList iniDesktop.dir type:arrFileType[rdoFileType.state]
		)
	)

	on btnAutobackDir pressed do 
	(
		rdoFileType.state  = 1
		fnRefreshList (getdir #autoback) type:".max"
	)

	on btnScriptsDir pressed do
	(
		rdoFileType.state  = 4
		fnRefreshList (getdir #scripts) type:".ms*"
	)

	on btnScriptsDir rightclick do
	(
		rdoFileType.state  = 4
		fnRefreshList (getdir #startupScripts) type:".ms*"
	)

	on btnRecentFileDir pressed do 
	(
		fnLoadRecentFileList ()
		for i in arrRecentFiles do 
		(
			if doesFileExist i then
			(
				append arrRecentFilesName ("📄 " + (getFilenameFile i) + ".max")
			)
			else append arrRecentFilesName ("📄 ( X )  " + (getFilenameFile i) + ".max")
		)
		rdoFileType.state  = 1
		ltbFilesList.items = arrRecentFilesName
		edtBrowseFolder.text = "( 最近打开 Max 文件列表 )"
		lblCountTips.text = "文件：" + arrRecentFiles.count as string
		lblLikedFolder.text = if ltbLikedFolder.selected == undefined then "请添加常用目录" else ltbLikedFolder.selected
	)

	on btnClose pressed do 
	(
		try (destroydialog rolBsOpenTools) catch()
	)

	on edtInputFilter entered textFolder do
	(
		fnRefreshList edtBrowseFolder.text filename:textFolder type:arrFileType[rdoFileType.state]
	)

	on ckbReverse changed state do 
	(
		rolBsOpenTools.fnRefreshList edtBrowseFolder.text type:arrFileType[rdoFileType.state]
		arrAll = (arrFoldersName + arrFilesName)
		id = rolBsOpenTools.ltbFilesList.selection
		rolBsOpenTools.ltbFilesList.selection = arrAll.count + 1 - id
	)
)
if (iniPosOpenTools != 0) then (Createdialog rolBsOpenTools fgcolor:myFgColor pos:iniPosOpenTools style:#() lockHeight:true)
else (Createdialog rolBsOpenTools fgcolor:myFgColor style:#() lockHeight:true)
------------------------toolbar----------------------------------------------------
macroScript BsOpenTools
category:"_[BulletTools]"
buttonText:"时光机"
toolTip:"时光机"
-- Icon:#("Systems",2)
(
	on execute do
	(
		fileIn ((getDir #Scripts)+ @"\\BulletScripts\\BsOpenTools.ms")
	)
)
-------------------------------------------------------------------------------------