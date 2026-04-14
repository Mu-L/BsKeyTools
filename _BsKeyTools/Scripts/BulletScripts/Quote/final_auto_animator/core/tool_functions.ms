-- ============================================================================
-- Auto Animation Tool - Tool Functions Module
-- ============================================================================
-- This module contains the external functions used by the tool window.
-- These functions handle hierarchy creation, expression application, etc.
--
-- Version: 2.0.0
-- ============================================================================

-- # region Hierarchy Sorting

-- Sort objects by hierarchy (parents first, then children)
fn sortArrayByHeirarchy objectArray = ( 
	sortedArray = #()
	childArray = #()
	-- first find roots and put them at left
	for obj in objectArray do (
		if (finditem objectArray obj.parent) == 0 
			then append sortedArray obj
			else append childArray obj  
	)
	-- now insert children on immediate right of their parents
	-- repeat scan until child array is empty
	while childArray.count > 0 do (
		i = 1
		while i <= childArray.count do (
			parentIdx = finditem sortedArray childArray[i].parent
			if parentIdx != 0 then (
				insertItem childArray[i] sortedArray (parentIdx+1) 
				deleteItem childArray i
			) else (
				i += 1  
			)
		)
	)
	sortedArray
)

-- # endregion

-- # region Controller Creation

-- Create main animation controller with Custom Attributes
-- Parameters:
--   prefix: Name prefix for the controller
--   boneChain: Array of bones in the chain
--   r: Controller size
--   p: Controller position
--   gridGroup: Optional grid group container (if provided, grid will be stacked in group)
--   axisIndex: Axis index for stacking (1=X, 2=Y, 3=Z)
--   twistMode: Twist control mode (0=None, 1=FirstLast, 2=Individual)
fn creatAutoAnimMainCtrl prefix boneChain r p gridGroup:undefined axisIndex:1 twistMode:1 = (
	-- r = controller size, p = controller position
	local existing = getnodebyname prefix
	if existing != undefined do delete existing
	ctrl_master = undefined
	ctrl_master = text size:r kerning:0 leading:0 pos:p isSelected:off
	ctrl_master.text = prefix
	ctrl_master.name = prefix

	-- Position adjustment
	ctrl_master.rotation = (quat 0.707107 0 0 0.707107)
	ctrl_master.pos = p

	-- Add Custom Attributes
	addmodifier ctrl_master (EmptyModifier())
	add_attribute = custattributes.add ctrl_master.modifiers[1] boneSineAniUsePos

	-- Initialize default values
	ctrl_master.modifiers[1].range = 0
	ctrl_master.modifiers[1].loop = 160
	ctrl_master.modifiers[1].speedV = 8.8
	ctrl_master.modifiers[1].offsetV = 100
	ctrl_master.modifiers[1].rangeAdd = 20
	ctrl_master.modifiers[1].frameFix = 0.0
	ctrl_master.modifiers[1].twistMode = twistMode

	-- Store bone names (use custom format to avoid truncation)
	boneInfoName = #()
	for i in boneChain do (append boneInfoName i.name)
	-- Build string manually to avoid "..." truncation in large arrays
	local boneInfoStr = "#("
	for i = 1 to boneInfoName.count do (
		boneInfoStr += "\"" + boneInfoName[i] + "\""
		if i < boneInfoName.count then boneInfoStr += ", "
	)
	boneInfoStr += ")"
	ctrl_master.modifiers[1].boneInfo = boneInfoStr

	-- Calculate bone percentages
	distanceRec = #()
	disAll = 0
	append distanceRec 0

	for i = 1 to boneChain.count-1 do (
		dis = length(boneChain[i+1].transform.pos - boneChain[i].transform.pos)
		disAll += dis
		append distanceRec disAll
	)
	-- Avoid divide by zero
	if disAll == 0 then disAll = 1.0
	longthPer = #()
	perDD = 0
	for i = 1 to boneChain.count do (append longthPer (distanceRec[i]/disAll))

	strfix = "#("
	for i = 1 to longthPer.count do (
		strfix += (longthPer[i] as string)
		if i < longthPer.count then (strfix += ", ")
	)
	strfix += ")"

	ctrl_master.modifiers[1].boneCount = longthPer.count
	ctrl_master.modifiers[1].bonelongPercent = strfix

	-- Create Spline weight curve at [0,0,0]
	-- No position offset - Spline stays at origin with pivot at [0,0,0]
	local splineCurve = AA_CreateWeightCurveSpline pos:[0, 0, 0]

	-- Create reference plane - this sets splineCurve.parent = refPlane
	-- Plane at [0,0,0] with pivot at [0,0,0], no parent
	-- Spline becomes child of Plane, also at [0,0,0]
	local refPlane = AA_CreateReferencePlane splineCurve

	-- Add controller to Controllers layer
	AA_AddToControllersLayer ctrl_master
	-- Add Spline and reference plane to Weight Curves layer
	AA_AddToCurvesLayer splineCurve
	AA_AddToCurvesLayer refPlane

	-- Position the reference plane based on gridGroup or calculate new position
	if gridGroup != undefined then (
		-- Stack grid within the group
		AA_StackGridInGroup refPlane gridGroup axisIndex
	) else (
		-- Calculate new position using collision detection
		local newPos = AA_CalculateNextGridPosition()
		refPlane.pos = newPos
	)

	-- Associate Spline with controller's Custom Attributes
	ctrl_master.modifiers[1].boneSineAniUsePos.splineCurveNode = splineCurve
	ctrl_master.modifiers[1].boneSineAniUsePos.weightCurveMode = 2  -- Use Spline mode by default

	return ctrl_master
)

-- # endregion

-- # region Expression Animation

-- Add expression animation to objects
-- axisSet: 1=X, 2=Y, 3=Z position
fn mackExpAnim axisSet ctrl_master objs percentValue = (
	-- Get Spline weight curve from attributes
	local splineNode = undefined
	local attrHolder = ctrl_master.modifiers[#Attribute_Holder]
	if attrHolder != undefined do (
		if hasProperty attrHolder.boneSineAniUsePos #splineCurveNode do (
			splineNode = attrHolder.boneSineAniUsePos.splineCurveNode
		)
	)

	for i = 1 to objs.count do (
		boneTar = objs[i]
		if classof(boneTar.pos.controller) != position_list then (
			boneTar.pos.controller = Position_XYZ ()
			boneTar.pos.controller = position_list ()
			posPP = Position_XYZ ()
			boneTar.pos.controller[1][axisSet].value = 0
			boneTar.pos.controller.Available.controller = posPP
		)

		posPPScript = float_script()
		boneTar.pos.controller[2][axisSet].controller = posPPScript

		posPPScript.AddNode "this" ctrl_master
		posPPScript.AddTarget "range" ctrl_master.modifiers[1].boneSineAniUsePos[#range]
		posPPScript.AddTarget "loop" ctrl_master.modifiers[1].boneSineAniUsePos[#loop]
		posPPScript.AddTarget "offsetV" ctrl_master.modifiers[1].boneSineAniUsePos[#offsetV]
		posPPScript.AddTarget "rangeAdd" ctrl_master.modifiers[1].boneSineAniUsePos[#rangeAdd]
		posPPScript.AddTarget "frameFix" ctrl_master.modifiers[1].boneSineAniUsePos[#frameFix]
		posPPScript.AddConstant "boneper" percentValue[i]

		-- Build expression using Spline weight curve or fallback to constant
		if splineNode != undefined and isValidNode splineNode then (
			-- Spline mode: use AA_SampleSplineAtX for weight lookup
			posPPScript.AddNode "splineCurve" splineNode
			posPPScript.script =
				"curveVV = AA_SampleSplineAtX splineCurve (boneper * 100)" + "\n" +
				"sin( (" + (AA_TWO_PI as string) + " / (loop / " + (AA_TIME_SCALE as string) + ")) * ((F) + frameFix + (offsetV*1 * boneper * -1))) * ( curveVV*rangeAdd*0.01 + range)"
		) else (
			-- Fallback: no Spline available, use constant weight = 100
			posPPScript.script =
				"curveVV = 100" + "\n" +
				"sin( (" + (AA_TWO_PI as string) + " / (loop / " + (AA_TIME_SCALE as string) + ")) * ((F) + frameFix + (offsetV*1 * boneper * -1))) * ( curveVV*rangeAdd*0.01 + range)"
		)
	)
)

-- # endregion

-- # region Utility Functions

-- Format number to 3 digits with leading zeros
fn formatNumberToThreeDigits num = (
	numStr = num as string 
	while (numStr.count < 3) do (numStr = "0" + numStr)
	return numStr
)

-- Reverse array in place
fn ReverseListFN arr = (
	if arr == undefined do return undefined
	if (mod arr.count 2) == 0 then (
		for i = 1 to (arr.count / 2) do (
			local atemp = arr[i]
			index = arr.count - (i - 1)
			arr[i] = arr[index]
			arr[index] = atemp
		)
	) else (
		endindex = (arr.count - 1) * 0.5
		for i = 1 to endindex do (
			local atemp = arr[i]
			index = arr.count - (i - 1)
			arr[i] = arr[index]
			arr[index] = atemp
		)
	)
)

-- # endregion

-- # region Natural Sort Helper

-- Get SHLWAPI for natural sorting
fn getSHLWAPI = (
	source = "using System;\n"
	source += "using System.Runtime.InteropServices;\n"
	source += "class SHLWAPI\n"
	source += "{\n"
	source += "	[DllImport(\"shlwapi.dll\", CharSet = CharSet.Auto)]\n"
	source += "	public static extern int StrCmpLogicalW(string lpszStr, string lpszComp);\n"
	source += "}\n"

	csharpProvider = dotnetobject "Microsoft.CSharp.CSharpCodeProvider"
	compilerParams = dotnetobject "System.CodeDom.Compiler.CompilerParameters"

	compilerParams.GenerateInMemory = on
	compilerResults = csharpProvider.CompileAssemblyFromSource compilerParams #(source)
	compilerResults.CompiledAssembly.CreateInstance "SHLWAPI"
)

-- # endregion

-- # region Locator and Constraint Functions

-- Create or replace a point helper (locator)
-- Uses visible Point helper with centermarker and axisTripod for easy selection
fn yunDummyCheckCreate obj = (
	yunSel = getNodeByName obj
	-- Delete if exists
	if yunSel != undefined then (delete yunSel)
	Dummy_Anim = point pos:[0,0,0] isSelected:off size:13 centermarker:true cross:true axisTripod:true box:false
	Dummy_Anim.name = obj
	Dummy_Anim.wirecolor = color 0 200 255  -- Cyan for visibility
)

-- Apply position constraint from objA to objB
fn yunPosconstraint objA objB = (
	objA.pos.controller = Position_XYZ ()
	objA.pos.controller = position_list ()
	posPP = Position_Constraint()
	objA.pos.controller.Available.controller = posPP
	posPP.appendTarget objB 100
	posPP.relative = true
	objA.pos.controller.Available.controller = Position_XYZ ()
	objA.pos.controller.setActive 3
)

-- Apply rotation constraint from objA to objB
fn yunRotconstraint objA objB = (
	objA.rotation.controller = Euler_XYZ ()
	objA.rotation.controller = rotation_list ()
	rotPP = Orientation_Constraint()
	objA.rotation.controller.Available.controller = rotPP
	rotPP.appendTarget objB 100
	rotPP.relative = true
	objA.rotation.controller.Available.controller = Local_Euler_XYZ ()
	objA.rotation.controller.setActive 3
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Tool Functions Module Loaded\n"
format "  - sortArrayByHeirarchy\n"
format "  - creatAutoAnimMainCtrl\n"
format "  - mackExpAnim\n"
format "  - yunDummyCheckCreate\n"
format "  - yunPosconstraint\n"
format "  - yunRotconstraint\n"
format "========================================\n"

-- # endregion

