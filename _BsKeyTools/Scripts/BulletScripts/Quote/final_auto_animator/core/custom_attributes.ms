-- ============================================================================
-- Auto Animation Tool - Custom Attributes Module
-- ============================================================================
-- This module contains the Custom Attributes definition for the auto animation system.
-- This includes all UI elements, parameters, and event handlers.
--
-- Custom Attributes Structure:
--   - boneSineAniUsePos: Main parameters and UI
--
-- Note: The original "Float Controller" dotnet PictureBox curve UI has been removed.
-- Weight curves now use Spline objects exclusively.
--
-- Version: 3.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

boneSineAniUsePos = attributes boneSineAniUsePos
attribid:#(0x764520ba, 0x2bbba0c9)
version:1
(
	-- # region Parameters
	parameters boneSineAniUsePos rollout: boneSineAniUsePos
	(
		range type:#float UI:range defult:0
		loop type:#float UI:loop defult:0

		speedV type:#float UI:speedV defult:12.0
		offsetV type:#float UI:offsetV defult:4.0
		rangeAdd type:#float UI:rangeAdd defult:3

		frameFix type:#float UI:frameFix defult:0.0

		setsInfo type:#string default:""
		boneInfo type:#string default:""

		-- Record bone chain length (count)
		boneCount type:#integer defult:1
		-- Record bone chain length ratio
		bonelongPercent type:#string default:""

		-- Spline weight curve parameters
		-- Reference to the Spline weight curve object
		splineCurveNode type:#node
		-- Weight curve mode: 2 = Spline Curve (default, UI Curve mode removed)
		weightCurveMode type:#integer default:2

		-- Twist control parameters
		-- twistMode: 0=None, 1=FirstLast (spinner driven), 2=Individual (manual euler)
		twistMode type:#integer default:1
		twistStart type:#float UI:twistStart default:0.0
		twistEnd type:#float UI:twistEnd default:0.0
	)
	-- # endregion

	-- # region On Create
	on create do
	(
		isLeaf = true
	)
	-- # endregion

	-- # region Main Rollout
	Rollout boneSineAniUsePos "自己动"		
	(
		group "摆动"
		(
			spinner speedV "速度Z:" width:150 Height:16 Align:#Center Offset:[0,0] Type:#float Range:[-1000,1000,12.0] enabled:false
			
			button setLoopbt  "按时间轴循环:"  width:100 Height:20 Align:#Center Offset:[0,0] 
			spinner loop "循环:" width:150 Height:16 Align:#Center Offset:[0,0] Type:#float Range:[-10000,10000,0] scale:1 

			spinner range "幅度:" width:150 Height:16 Align:#Center Offset:[0,0] Type:#float Range:[-1000,1000,15.0]
			spinner offsetV "滞后:" width:150 Height:16 Align:#Center Offset:[0,0] Type:#float Range:[-10000,10000,4.0]
			spinner rangeAdd "增益:" width:150 Height:16 Align:#Center Offset:[0,0] Type:#float Range:[-1000,1000,3.0]		
			spinner frameFix "帧位:" width:150 Height:16 Align:#Center Offset:[0,0] Type:#float Range:[-1000,1000,0]
		)
 
		group "权重曲线"
		(
			label lblSplineCurve "Spline曲线:" across:2
			button btnSelectSpline "选择" width:60 tooltip:"在场景中选择关联的Spline曲线"
		)

		-- Twist control spinners (only visible when twistMode == 1, FirstLast mode)
		-- Using label + spinners for visibility control (group cannot be hidden)
		group "twist控制"
		(
			spinner twistStart "起始:" width:150 height:16 type:#float range:[-36000,36000,0] Align:#Center Offset:[0,0]
			spinner twistEnd "结束:" width:150 height:16 type:#float range:[-36000,36000,0] Align:#Center Offset:[0,0]
		)
		
		group "塌陷"
		(
			radioButtons rdoRangeType "" labels:#("Time Line","Range") default:1 columns:2
			label lbStart "Start :"　across:2 enabled:false
			spinner spnStart "" align:#left width:60 range:[-9999,9999,0] type:#integer enabled:false
			label lbEnd "End :"　across:2 enabled:false
			spinner spnEnd "" align:#left width:60 range:[-9999,9999,0] type:#integer enabled:false
		)
		
		button resetToV  "默认" tooltip: "左键恢复预设，右键对帧位" across:2
		button collapseToOri "塌陷↑" tooltip: "恢复成原始骨骼,选择需要塌陷的骨骼链" across:2
		button resetToOpen  "开(?′ヮ′)?" tooltip: "打开表达式动画" across:2
		button resetToZero  "?(ˊ?ˋ*)?关" tooltip: "关闭表达式动画" across:2

		
		label aboutsplide	"~~~~~~~~~~~~~~"
		label aboutYun "written  by：东见云"
		
		on setLoopbt pressed do
		(
			animationRange.end.frame - animationRange.start.frame
			loop.value = animationRange.end.frame - animationRange.start.frame
		)

		-- Select the associated Spline curve in scene
		on btnSelectSpline pressed do
		(
			if splineCurveNode != undefined and isValidNode splineCurveNode do (
				select splineCurveNode
			)
		)


		-- On rollout open
		on boneSineAniUsePos open do
		(
			--if animButtonState == true then (max tool animmode; set animate off)

			speedV.value = (AA_TWO_PI / (loop.value / AA_TIME_SCALE))
			if startTime == undefined then (
				global startTime
			)
			startTime = (animationRange.start as string) as integer
			if endTime == undefined then (
				global endTime
			)
			endTime = (animationRange.end as string) as integer

			spnStart.value = startTime
			spnEnd.value = endTime

			-- Show/hide twist controls based on twistMode
			-- Only show when twistMode == 1 (FirstLast mode)
			-- Note: group cannot be hidden, only hide spinners inside
			local showTwist = (twistMode == 1)
			twistStart.visible = showTwist
			twistEnd.visible = showTwist

			if boneSineTimeRangeType != undefined then
			(
				rdoRangeType.state = boneSineTimeRangeType
				case boneSineTimeRangeType of (
					1:(
						lbStart.enabled = false
						lbEnd.enabled = false
						spnStart.enabled = false
						spnEnd.enabled = false
					)
					2:(
						lbStart.enabled = true
						lbEnd.enabled = true
						spnStart.enabled = true
						spnEnd.enabled = true
					)
				)
			)
		)

		-- Speed change syncs with period
		on loop changed val do (
			speedV.value = (AA_TWO_PI / (val / AA_TIME_SCALE))
		)

		-- Collapse range toggle
		on rdoRangeType changed val do (
			case val of (
				1:(
					lbStart.enabled = false
					lbEnd.enabled = false
					spnStart.enabled = false
					spnEnd.enabled = false
				)
				2:(
					lbStart.enabled = true
					lbEnd.enabled = true
					spnStart.enabled = true
					spnEnd.enabled = true
				)
			)
			if boneSineTimeRangeType == undefined then (
				global boneSineTimeRangeType
			)
			boneSineTimeRangeType = val
		)

		-- Timeline control
		on spnStart changed val do (
			if spnEnd.value < val then (
				spnEnd.value = val
			)
			if startTime == undefined then (
				global startTime
			)
			startTime = val
		)

		on spnEnd changed val do (
			if spnStart.value > val then (
				spnStart.value = val
			)
			if endTime == undefined then (
				global endTime
			)
			endTime = val
		)
		-- # endregion

		-- # region Collapse Handler
		on collapseToOri pressed do
		(
			undo on
			(
				tStart = (animationRange.start as string) as integer
				if rdoRangeType.state == 2 then
				(tStart = spnStart.value)

				tEnd = (animationRange.end as string) as integer
				if rdoRangeType.state == 2 then
				(tEnd = spnEnd.value)

				tNow = (currentTime as string) as integer
				TimeLength = (tEnd - tStart) + 1
				frames = #()
				for i = tStart to tEnd do append frames i
				boneN = execute($.modifiers[1].boneInfo)
				sel = #()
				for i in boneN do (append sel (getnodebyname i))

				if sel.count < 1 then (messageBox "骨骼重命名就会看到我喔~~~") else (
					TM_record = #()
					-- Record transform matrices
					for frame in frames do
					(
						at time frame
						(
							TM_buffer = #()
							for obj in sel do (append TM_buffer obj.transform)
							append TM_record TM_buffer
						)
					)
					-- Restore controllers
					for i in sel do (
						i.pos.controller = Position_XYZ()
						i.rotation.controller = Euler_XYZ()
					)
					-- Restore animation
					animate on
					(
						for f = 1 to frames.count do
						(
							at time (frames[f] as time)
							(
								for i = 1 to sel.count do (sel[i].transform = TM_record[f][i])
							)
						)
						print "KKKK"
					)
				)
				try (delete $) catch(print "未选择控制")
			)
		)
		-- # endregion

		-- # region Animation Toggle Handlers
		-- Close animation
		on resetToZero pressed do (
			with animate off (
				if speedV.value != 0 then
				(
					buffer = #()
					append buffer $.modifiers[1].speedV
					$.modifiers[1].setsInfo = buffer as string
					$.modifiers[1].speedV = 0
					redrawViews()
					print "表达式动画已关闭"
				)

				$.modifiers[1].loop = AA_TIME_SCALE * (AA_TWO_PI / $.modifiers[1].speedV)
			)
		)

		-- Open animation
		on resetToOpen pressed do (
			with animate off (
				try (
					bufferGet = execute($.modifiers[1].setsInfo)
					$.modifiers[1].speedV = bufferGet[1]

					$.modifiers[1].loop = AA_TIME_SCALE * (AA_TWO_PI / $.modifiers[1].speedV)

					print "表达式动画已打开"
					redrawViews()
				) catch()
			)
		)

		-- Preset
		on resetToV pressed do (
			with animate off (
				redrawViews()
				print "表达式动画已打开"
			)
		)

		-- Frame position
		on resetToV rightclick do (
			frameFix.value = (animationRange.start.frame as integer)
		)
		-- # endregion
	)
	-- # endregion
)

