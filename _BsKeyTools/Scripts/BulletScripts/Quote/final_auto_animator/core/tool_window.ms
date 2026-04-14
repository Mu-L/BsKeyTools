-- ============================================================================
-- Auto Animation Tool - Tool Window Module
-- ============================================================================
-- This module contains the main tool window (yun_autoAnim_tool rollout).
-- 
-- IMPORTANT: UI MUST NOT BE MODIFIED!
-- This file should contain the EXACT original code from:
--   ref_code/自己动封装开始_v2.ms lines 1308-1630
--
-- MANUAL COPY REQUIRED:
-- 1. Open ref_code/自己动封装开始_v2.ms in a text editor with GBK encoding
-- 2. Copy lines 1308-1630 (the entire yun_autoAnim_tool section)
-- 3. Paste below this comment block, replacing the placeholder
--
-- Version: 2.0.0
-- ============================================================================

-- # region Tool Window Code (copied from original lines 1308-1630)

Global yun_autoAnim_tool 		--界面
Global iniPosTest_yun_autoAnim    --位置
if iniPosTest_yun_autoAnim==undefined then (iniPosTest_yun_autoAnim = [200,200])
Global switchAnimButtonMouState_yun_autoAnim = false  ---鼠标状态
Global posAnimButtonMouMove_yun_autoAnim     = [0,0]   ---事变移动

ctrl_masterGrp =#()   --控制器储存
selectExpressionBones = undefined --骨骼储存
waveLoc = #()   --中间物储存
try(destroyDialog yun_autoAnim_tool)catch()
rollout yun_autoAnim_tool "" width:218 height:43
(
		button ctrlZ "退货" pos:[175,3] width:38 height:35 tooltip:"恢复所有"
		-----一键
		button btn_Sets1 "^O^" pos:[2,3] width:35 height:35   tooltip:"左键解君愁，右键赐惊喜"
		checkbox axisSet_X "X"  pos:[55,15] width:40 height:15 checked:false tooltip:"x"
		checkbox axisSet_Y "Y"  pos:[95,15] width:30 height:15 checked:true tooltip:"y"
		checkbox axisSet_Z "Z"  pos:[135,15] width:30 height:15 checked:false tooltip:"z"

		-- Twist control UI (placed below X/Y/Z checkboxes)
		
		checkbox chkEnableTwist "启用Twist" pos:[10,45] width:70 height:18 checked:true tooltip:"启用骨骼链Twist/Roll控制"
		radioButtons rdoTwistMode "" labels:#("首尾      ", "单独   ") pos:[90,47] columns:2 default:1 visible:true
		label split1 "︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵"  pos:[5,68] width:218 height:10
		------详细设置
		button btn_Sets2 "^O^" pos:[2,80] width:35 height:35   tooltip:"左键解君愁，右键赐惊喜"
		label lab_2 "前缀：" pos:[55,91] width:35 height:50
		editText prefixTx  text:"" pos:[85,83] width:130 height:30   labelOnTop: false bold:true --readOnly:false
		button creatCrl "1>加控制器" pos:[2,120] width:70 height:35   tooltip:""
		button creathierarchy "2>加中间层" pos:[75,120] width:70 height:35   tooltip:""
		button creathExp "2>加表达式" pos:[146,120] width:70 height:35   tooltip:""
		label split2 "︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵︵"  pos:[5,155] width:218 height:10
		label occuqied_temp "—————暂时什么都没有了（*゜ー゜*）"  pos:[5,175] width:218 height:35
	-- Twist checkbox changed event: show/hide radioButtons
	on chkEnableTwist changed state do (
		rdoTwistMode.visible = state
	)

	
		
		--恢复所有
		on ctrlZ pressed do (
			format "\n========== 恢复所有 按钮被点击 ==========\n"
			max create mode

			format "[DEBUG] selectExpressionBones: %\n" selectExpressionBones
			format "[DEBUG] selection.count: %\n" selection.count

			if selectExpressionBones == undefined or selectExpressionBones.count == 0 or not isValidNode(selectExpressionBones[1]) then (
				format "[DEBUG] 需要从选择获取骨骼\n"
				if selection.count > 0 then (
					selectExpressionBones = selection as array
					format "[DEBUG] 从选择获取骨骼: %\n" selectExpressionBones
				) else (
					messageBox "请先选择需要恢复的骨骼链"
					return undefined
				)
			)

			undo on (
				-- Get selected bone names for matching
				-- Strip "_Anim" suffix if present to match original bone names
				local selectedBoneNames = for bone in selectExpressionBones collect (
					local bName = bone.name
					if matchPattern bName pattern:"*_Anim" then (
						-- Remove "_Anim" suffix (5 characters)
						substring bName 1 (bName.count - 5)
					) else (
						bName
					)
				)
				format "[DEBUG] Selected bone names (stripped): %\n" selectedBoneNames

				-- Step 0: Find ALL controllers that match the selected bone chain
				local matchedControllers = #()  -- Array of: #(controller, caInst, spline)
				local controllerCount = 0

				-- Search for controllers with Custom Attributes (boneSineAniUsePos)
				for obj in objects do (
					if obj.modifiers.count > 0 do (
						for i = 1 to obj.modifiers.count do (
							if classof obj.modifiers[i] == EmptyModifier do (
								local attrMod = obj.modifiers[i]
								local custAttrDefs = custAttributes.getDefs attrMod

								if custAttrDefs != undefined and custAttrDefs.count > 0 do (
									for caDef in custAttrDefs do (
										if caDef.name == #boneSineAniUsePos do (
											controllerCount += 1
											local caInst = custAttributes.get attrMod caDef

											if caInst != undefined and (hasProperty caInst #boneInfo) do (
												local storedBoneInfoRaw = caInst.boneInfo
												local displayLen = if storedBoneInfoRaw.count > 100 then 100 else storedBoneInfoRaw.count
												format "[DEBUG] Controller '%' boneInfo (raw, first 100 chars): %\n" obj.name (substring storedBoneInfoRaw 1 displayLen)

												-- boneInfo is stored as a string, need to parse it
												if storedBoneInfoRaw != undefined and storedBoneInfoRaw != "" do (
													-- Check if string is truncated (contains "...")
													local isTruncated = (findString storedBoneInfoRaw "...") != undefined
													local storedBoneInfo = undefined

													if isTruncated then (
														format "[DEBUG] WARNING: boneInfo is truncated, using fallback parsing\n"
														-- Fallback: extract bone names manually
														storedBoneInfo = #()
														local tempStr = storedBoneInfoRaw
														local startPos = 1
														while true do (
															local quoteStart = findString (substring tempStr startPos -1) "\""
															if quoteStart == undefined do exit
															quoteStart = startPos + quoteStart - 1
															local quoteEnd = findString (substring tempStr (quoteStart + 1) -1) "\""
															if quoteEnd == undefined do exit
															quoteEnd = quoteStart + quoteEnd
															local boneName = substring tempStr (quoteStart + 1) (quoteEnd - quoteStart - 1)
															append storedBoneInfo boneName
															startPos = quoteEnd + 1
														)
														format "[DEBUG] Parsed % bone names from truncated string\n" storedBoneInfo.count
													) else (
														-- Normal parsing with execute
														storedBoneInfo = execute storedBoneInfoRaw
													)

													if classof storedBoneInfo == Array and storedBoneInfo.count > 0 do (
														local isMatch = false
														for selName in selectedBoneNames do (
															for storedName in storedBoneInfo do (
																if selName == storedName do (
																	isMatch = true
																	exit
																)
															)
															if isMatch do exit
														)
														if isMatch do (
															-- Get associated spline
															local splineNode = undefined
															if hasProperty caInst #splineCurveNode do (
																splineNode = caInst.splineCurveNode
															)
															-- Store matched controller info
															append matchedControllers #(obj, caInst, splineNode)
															format "[DEBUG] Matched controller: % (spline: %)\n" obj.name (if splineNode != undefined then splineNode.name else "none")
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)

				format "[DEBUG] Total controllers in scene: %, Matched: %\n" controllerCount matchedControllers.count

				if matchedControllers.count == 0 do (
					messageBox "未找到该骨骼链对应的控制器"
					return undefined
				)

				-- Step 1: Zero out ALL matched controllers to restore bones to bind pose
				for ctrlData in matchedControllers do (
					local caInst = ctrlData[2]
					if caInst != undefined do (
						caInst.range = 0
						caInst.rangeAdd = 0
						caInst.offsetV = 0
						format "[DEBUG] Controller '%' parameters zeroed\n" ctrlData[1].name
					)
				)

				-- Force viewport update to apply zero values
				sliderTime = currentTime
				redrawViews()

				-- Step 2: Restore bone controllers and transforms
				for bone in selectExpressionBones do (
					if isValidNode bone do (
						local tm = bone.transform
						bone.rotation.controller = Euler_XYZ()
						bone.pos.controller = Position_XYZ()
						bone.transform = tm
					)
				)

				-- Step 3: Delete the associated splines and their parent (reference grids) for ALL controllers
				for ctrlData in matchedControllers do (
					local matchedSpline = ctrlData[3]
					if matchedSpline != undefined and isValidNode matchedSpline do (
						local refGrid = matchedSpline.parent
						if refGrid != undefined and isValidNode refGrid do (
							format "[DEBUG] Deleting refGrid and all children: %\n" refGrid.name
							-- Collect all children using iterative approach (BFS)
							local allChildren = #()
							local queue = #(refGrid)
							while queue.count > 0 do (
								local current = queue[1]
								deleteItem queue 1
								for child in current.children do (
									append allChildren child
									append queue child
								)
							)
							format "[DEBUG] Found % children to delete\n" allChildren.count
							-- Delete children first (in reverse order to handle hierarchy)
							for i = allChildren.count to 1 by -1 do (
								if isValidNode allChildren[i] do delete allChildren[i]
							)
							-- Then delete the parent
							if isValidNode refGrid do delete refGrid
						)
					)
				)

				-- Step 4: Delete ALL controller objects (the SplineShape with boneSineAniUsePos)
				for ctrlData in matchedControllers do (
					local ctrl = ctrlData[1]
					if isValidNode ctrl do (
						format "[DEBUG] Deleting controller: %\n" ctrl.name
						delete ctrl
					)
				)

				-- Step 5: Delete helper objects (_Anim_Master, _Anim_Wave) associated with this bone chain
				-- Get the original bone names (without _Anim suffix)
				-- IMPORTANT: Clear Wave rotation controllers BEFORE deleting Masters to avoid script errors
				local helperObjectsToDelete = #()
				local waveObjectsToDelete = #()
				local masterObjectsToDelete = #()
				for boneName in selectedBoneNames do (
					-- Find *_Anim_Master and *_Anim_Wave objects
					local masterName = boneName + "_Anim_Master"
					local waveName = boneName + "_Anim_Wave"
					local masterObj = getNodeByName masterName
					local waveObj = getNodeByName waveName
					if waveObj != undefined do append waveObjectsToDelete waveObj
					if masterObj != undefined do append masterObjectsToDelete masterObj
				)

				-- Clear Wave rotation controllers to prevent script errors when Masters are deleted
				for obj in waveObjectsToDelete do (
					if isValidNode obj do (
						format "[DEBUG] Clearing rotation controller for: %\n" obj.name
						obj.rotation.controller = Euler_XYZ()
					)
				)

				-- Delete Wave objects first
				for obj in waveObjectsToDelete do (
					if isValidNode obj do (
						format "[DEBUG] Deleting helper: %\n" obj.name
						delete obj
					)
				)

				-- Then delete Master objects
				for obj in masterObjectsToDelete do (
					if isValidNode obj do (
						format "[DEBUG] Deleting helper: %\n" obj.name
						delete obj
					)
				)

				-- Step 6: Delete copied bones (_Anim bones)
				local animBonesToDelete = #()
				for boneName in selectedBoneNames do (
					local animBoneName = boneName + "_Anim"
					local animBone = getNodeByName animBoneName
					if animBone != undefined do append animBonesToDelete animBone
				)

				-- Delete from last to first to handle hierarchy
				for i = animBonesToDelete.count to 1 by -1 do (
					local bone = animBonesToDelete[i]
					if isValidNode bone do (
						format "[DEBUG] Deleting anim bone: %\n" bone.name
						delete bone
					)
				)

				-- Clear stored references for this bone chain
				selectExpressionBones = undefined
				waveLoc = #()

				format "[INFO] Bone chain restored. Controller and helper objects cleaned.\n"
			)
		)
		
		---一键执行
		on btn_Sets1 pressed do
		(
			yun_autoAnim_tool.creatCrl.pressed()
			if selection.count>0 then	(	
				yun_autoAnim_tool.creathierarchy.pressed()
				redrawViews()
				yun_autoAnim_tool.creathExp.pressed()
			)
		)
		--1>加控制器
		on creatCrl pressed do (
			ctrl_masterGrp =#()   --控制器储存
			selectExpressionBones = undefined --骨骼储存
			waveLoc = #()   --中间物储存
			if selection.count>0 then	(
				animate off (
					---获取选择
					selectExpressionBones  = sortArrayByHeirarchy (selection as array)
					----根据骨骼大小调整控制器大小
					r = 1/5
					p = [0,0,0]
					if selectExpressionBones.count > 0 and classof(selectExpressionBones[1])==BoneGeometry then
					(r = selectExpressionBones[1].length;p = selectExpressionBones[1].transform.pos)

					-- 前缀设定
					prefix = "antoAnim"
					if yun_autoAnim_tool.prefixTx.text=="" then (prefix = selectExpressionBones[1].name) else (prefix = yun_autoAnim_tool.prefixTx.text)

					-- Create grid group container for this bone chain's coordinate systems
					-- All X/Y/Z grids will be stacked vertically within this group
					local gridGroup = AA_CreateGridGroup prefix

					-- Get twist mode from UI for controller creation
					local twistModeForCtrl = 0  -- Default: no twist
					if yun_autoAnim_tool.chkEnableTwist.checked do (
						twistModeForCtrl = yun_autoAnim_tool.rdoTwistMode.state  -- 1=FirstLast, 2=Individual
					)

					-- Track if twist has been assigned to a controller (only first one gets twist)
					local twistAssigned = false

					--检查重复
					--ctrlCheck = getnodebyname (prefix+"EXP")
					--if (ctrlCheck!=undefined) then
					--(messageBox "已经存在同名控制，请删除或改前缀")
					--else (
						--开始创建 (Priority: Y > X > Z for twist assignment)
						if   yun_autoAnim_tool.axisSet_Y.checked then(
							local thisTwistMode = if twistAssigned then 0 else twistModeForCtrl
							CC =  creatAutoAnimMainCtrl (prefix + "_Y") selectExpressionBones  r [p.x,p.y,(p.z+2*r)] gridGroup:gridGroup axisIndex:2 twistMode:thisTwistMode
							append ctrl_masterGrp CC
							ctrl_masterGrp[2] = CC
							CC.modifiers[#Attribute_Holder].boneSineAniUsePos.frameFix = 80
							if twistModeForCtrl != 0 do twistAssigned = true
						)
						if   yun_autoAnim_tool.axisSet_X.checked then(
							local thisTwistMode = if twistAssigned then 0 else twistModeForCtrl
							CC =  creatAutoAnimMainCtrl (prefix + "_X") selectExpressionBones  r [p.x,p.y,(p.z+3*r)] gridGroup:gridGroup axisIndex:1 twistMode:thisTwistMode
							append ctrl_masterGrp CC
							ctrl_masterGrp[1] = CC
							CC.modifiers[#Attribute_Holder].boneSineAniUsePos.frameFix = 40
							if twistModeForCtrl != 0 do twistAssigned = true
						)
						if   yun_autoAnim_tool.axisSet_Z.checked then(
							local thisTwistMode = if twistAssigned then 0 else twistModeForCtrl
							CC =  creatAutoAnimMainCtrl (prefix + "_Z") selectExpressionBones  r [p.x,p.y,(p.z+1*r)] gridGroup:gridGroup axisIndex:3 twistMode:thisTwistMode
							append ctrl_masterGrp CC
							ctrl_masterGrp[3] = CC
							if twistModeForCtrl != 0 do twistAssigned = true
						)
					--)
				)
				select selectExpressionBones
			)else (	messageBox "未选物体";)

			-- Controllers already added to layer in creatAutoAnimMainCtrl function



		)
		--2>加中间层
		on creathierarchy pressed do (
			max create mode
			undo on(
			sel = selection as array
			animBones = #()
			-- Get or create Helpers layer for hierarchy objects (child of autoAnim)
			local helpersLayer = AA_GetOrCreateChildLayer AA_LAYER_HELPERS

			maxOps.cloneNodes sel cloneType:#copy newNodes:&animBones
			for i in animBones do (helpersLayer.addnode i )  --加到层里
			for i=1 to animBones.count do (
				animBones[i].name = sel[i].name+"_Anim"
				animBones[i].wirecolor = yellow  -- Set _Anim bones to yellow for visibility
			)
			waveLoc = #()
			masterLoc = #()  -- Collect masters for quaternion aim constraints
			for i in animBones do
			(
				animate off
				(
					nameLoc = (i.name+"_Master")
					nameWave = (i.name+"_Wave")

					yunDummyCheckCreate nameLoc
					yunDummyCheckCreate nameWave

					waveObj = getNodeByName nameWave
					append waveLoc waveObj
					masterObj = getNodeByName nameLoc
					append masterLoc masterObj  -- Collect master for quaternion aim
					waveObj.parent =  masterObj

					helpersLayer.addnode waveObj   --加到层里
					helpersLayer.addnode masterObj   --加到层里

					masterObj.transform = i.transform
					--层级link给复制的骨骼
					masterObj.Transform.controller = Link_Constraint ()
					masterObj.transform.controller.AddTarget i ((sliderTime as string) as integer)
					masterObj.isHidden = true  -- Hide Master, keep Wave visible

					in coordsys parent waveObj.rotation = (quat 0 0 0 0)
					in coordsys parent waveObj.pos = [0,0,0]
					waveObj.axistripod = on
					waveObj.cross = off
				)
			)
		
			--删除原先骨骼动画
			select sel
			macros.run "Animation Tools" "DeleteSelectedAnimation"
			for i in sel do (  --		i =sel[1]
				PP = getNodeByName (i.name+"_Anim"+"_Wave")
				--print PP
				if PP!=undefined then(	
					--蒙皮骨骼link给loc
					i.Transform.controller =  prs ()
					yunPosconstraint  i PP
					yunRotconstraint  i PP
				)
			)
			)
			
			
			if ::SHLWAPI == undefined do SHLWAPI = getSHLWAPI()
			-- Sort both arrays in same order (wave and master must match)
			try (qsort waveLoc SHLWAPI.StrCmpLogicalW )catch()
			try (qsort masterLoc SHLWAPI.StrCmpLogicalW )catch()
			ReverseListFN waveLoc
			ReverseListFN masterLoc

			-- Apply quaternion aim constraints (replaces LookAt_Constraint to avoid gimbal lock)
			-- rootParent: first _Anim bone as rotation inheritance root
			local rootParent = animBones[1]
			if rootParent == undefined do rootParent = waveLoc[1].parent  -- fallback

			-- Get twist mode from UI
			local twistModeVal = 0  -- Default: no twist
			if yun_autoAnim_tool.chkEnableTwist.checked do (
				twistModeVal = yun_autoAnim_tool.rdoTwistMode.state  -- 1=FirstLast, 2=Individual
			)

			-- Get mainCtrl and bonelongPercent for FirstLast twist mode
			local mainCtrlForTwist = undefined
			local percentArray = #()
			if twistModeVal == 1 and ctrl_masterGrp.count > 0 do (
				-- Use first available controller (Y axis preferred)
				if ctrl_masterGrp[2] != undefined then (
					mainCtrlForTwist = ctrl_masterGrp[2]
				) else if ctrl_masterGrp[1] != undefined then (
					mainCtrlForTwist = ctrl_masterGrp[1]
				) else if ctrl_masterGrp[3] != undefined then (
					mainCtrlForTwist = ctrl_masterGrp[3]
				)
				-- Parse bonelongPercent from controller
				if mainCtrlForTwist != undefined do (
					local pctStr = mainCtrlForTwist.modifiers[1].boneSineAniUsePos.bonelongPercent
					if pctStr != "" do percentArray = execute pctStr
				)
			)

			AA_ApplyQuaternionAimConstraints waveLoc masterLoc rootParent twistMode:twistModeVal mainCtrl:mainCtrlForTwist bonelongPercent:percentArray
		)
		
		--3>加表达式
		on creathExp pressed do (
			-->加脚本自己动
			ReverseListFN waveLoc	
			max create mode	
			if   yun_autoAnim_tool.axisSet_X.checked then(
				percentValue = execute(ctrl_masterGrp[1].modifiers[1].boneSineAniUsePos.bonelongPercent)	
				mackExpAnim 1 ctrl_masterGrp[1] waveLoc	 percentValue			
			)
			if   yun_autoAnim_tool.axisSet_Y.checked then(
				percentValue = execute(ctrl_masterGrp[2].modifiers[1].boneSineAniUsePos.bonelongPercent)	
				mackExpAnim 2 ctrl_masterGrp[2] waveLoc percentValue
			)
			if   yun_autoAnim_tool.axisSet_Z.checked then(
				percentValue = execute(ctrl_masterGrp[3].modifiers[1].boneSineAniUsePos.bonelongPercent)	
				mackExpAnim 3 ctrl_masterGrp[3] waveLoc percentValue
			)			
		)
	
		
	
			
		---展开1
		on btn_Sets1 rightclick do (
			if yun_autoAnim_tool.height==43 then (yun_autoAnim_tool.height=160;btn_Sets2.text =  "⊙▽⊙") else (yun_autoAnim_tool.height=43;btn_Sets2.text =  "^O^")
		)
		---展开3
		on btn_Sets2 rightclick do (
			if yun_autoAnim_tool.height==160 then (yun_autoAnim_tool.height=210;btn_Sets2.text =  "⊙▽⊙") else (yun_autoAnim_tool.height = 160;btn_Sets2.text =  "^O^")
		)
	
	
		-- 窗口移动功能
		on yun_autoAnim_tool mousemove pos do UI_make.MoveWindow yun_autoAnim_tool
		on yun_autoAnim_tool lbuttondown pos do UI_make.IsReadyToMove yun_autoAnim_tool pos
		on yun_autoAnim_tool lbuttonup pos do UI_make.LetGoTheWindow()	
	
--关闭时记录位置
	on yun_autoAnim_tool close do -- 关闭记忆浮动窗口位置
	(
        iniPosTest_yun_autoAnim   = (GetDialogPos yun_autoAnim_tool)
	)
---中间按下关闭窗口
	on yun_autoAnim_tool mbuttondown pos do 
	(
		try (destroydialog yun_autoAnim_tool) catch ()
	)
-- 左键鼠标位置
	on yun_autoAnim_tool lbuttondown posMou do
	(
		posAnimButtonMouMove_yun_autoAnim = posMou
		switchAnimButtonMouState_yun_autoAnim = on
	)
---左键弹起
	on yun_autoAnim_tool lbuttonup posMou do
	(
		switchAnimButtonMouState_yun_autoAnim = off
	)
	
--移动鼠标则移动窗口
	on yun_autoAnim_tool mouseMove pos do
	(
		if switchAnimButtonMouState_yun_autoAnim == on then
		(
			SetDialogPos yun_autoAnim_tool (mouse.screenpos - posAnimButtonMouMove_yun_autoAnim)			
		)
	)
)

Createdialog yun_autoAnim_tool  pos:iniPosTest_yun_autoAnim style:#() 
