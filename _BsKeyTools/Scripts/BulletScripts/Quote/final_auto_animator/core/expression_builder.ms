-- ============================================================================
-- Auto Animation Tool - Expression Builder Module
-- ============================================================================
-- This module handles the creation of sine wave expressions for procedural animation.
-- It builds MaxScript float_script expressions that drive bone positions.
--
-- Expression Formula:
--   curveVV = AA_SampleSplineAtX splineCurve (boneper * 100)
--   sin(frequency * (F + frameFix + phaseOffset)) * amplitude
--
-- Where:
--   frequency = TWO_PI / (loop / TIME_SCALE)
--   phaseOffset = offsetV * boneper * -1
--   amplitude = curveVV * rangeAdd * 0.01 + range
--
-- Weight Curve:
--   Uses Spline object for weight sampling (replaces old dotnet PictureBox curve)
--   Fallback to curveVV = 100 if no Spline is available
--
-- Version: 3.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Expression Building

-- Build sine wave expression for a single bone
-- Creates a float_script controller with sine wave expression
--
-- Parameters:
--   axisSet: Axis to animate (1=X, 2=Y, 3=Z)
--   ctrl_master: Master control object with Custom Attributes
--   boneTarget: Target bone to apply expression to
--   bonePercent: Bone's position in chain (0.0 to 1.0)
--
-- Returns:
--   The created float_script controller
--
fn AA_BuildSineExpression axisSet ctrl_master boneTarget bonePercent = (

    -- Create position controller if needed
    if classof(boneTarget.pos.controller) != position_list then (
        boneTarget.pos.controller = Position_XYZ()
        boneTarget.pos.controller = position_list()
        posPP = Position_XYZ()
        boneTarget.pos.controller[1][axisSet].value = 0
        boneTarget.pos.controller.Available.controller = posPP
    )

    -- Create float_script controller for expression
    posPPScript = float_script()
    boneTarget.pos.controller[2][axisSet].controller = posPPScript

    -- Add references to master controller parameters
    posPPScript.AddNode "this" ctrl_master
    posPPScript.AddTarget "range" ctrl_master.modifiers[1].boneSineAniUsePos[#range]
    posPPScript.AddTarget "loop" ctrl_master.modifiers[1].boneSineAniUsePos[#loop]
    posPPScript.AddTarget "offsetV" ctrl_master.modifiers[1].boneSineAniUsePos[#offsetV]
    posPPScript.AddTarget "rangeAdd" ctrl_master.modifiers[1].boneSineAniUsePos[#rangeAdd]
    posPPScript.AddTarget "frameFix" ctrl_master.modifiers[1].boneSineAniUsePos[#frameFix]

    -- Add bone-specific constant
    posPPScript.AddConstant "boneper" bonePercent

    -- Get Spline weight curve from attributes
    local splineNode = undefined
    local attrHolder = ctrl_master.modifiers[#Attribute_Holder]
    if attrHolder != undefined do (
        if hasProperty attrHolder.boneSineAniUsePos #splineCurveNode do (
            splineNode = attrHolder.boneSineAniUsePos.splineCurveNode
        )
    )

    -- Build expression using Spline weight curve
    posPPScript.script = "0"

    if splineNode != undefined and isValidNode splineNode then (
        -- Spline mode: use AA_SampleSplineAtX for weight lookup
        posPPScript.AddNode "splineCurve" splineNode
        posPPScript.script =
            "curveVV = AA_SampleSplineAtX splineCurve (boneper * 100)" + "\n" +
            "sin( (" + (AA_TWO_PI as string) + " / (loop / " + (AA_TIME_SCALE as string) + ")) * ((F) + frameFix + (offsetV*1 * boneper * -1))) * " +
            "( curveVV*rangeAdd*0.01 + range)"
    ) else (
        -- Fallback: no Spline available, use constant weight = 100
        posPPScript.script =
            "curveVV = 100" + "\n" +
            "sin( (" + (AA_TWO_PI as string) + " / (loop / " + (AA_TIME_SCALE as string) + ")) * ((F) + frameFix + (offsetV*1 * boneper * -1))) * " +
            "( curveVV*rangeAdd*0.01 + range)"
    )

    return posPPScript
)

-- Apply sine wave expressions to bone chain
-- Applies expressions to all bones in a chain for a specific axis
--
-- Parameters:
--   axisSet: Axis to animate (1=X, 2=Y, 3=Z)
--   ctrl_master: Master control object
--   bones: Array of bone objects
--   percentValues: Array of bone percentages (0.0 to 1.0)
--
fn AA_ApplyExpressionsToChain axisSet ctrl_master bones percentValues = (
    
    if bones.count != percentValues.count then (
        messageBox "Error: Bone count doesn't match percentage count" title:"Expression Builder Error"
        return false
    )
    
    for i = 1 to bones.count do (
        AA_BuildSineExpression axisSet ctrl_master bones[i] percentValues[i]
    )
    
    return true
)

-- # endregion

-- # region Utility Functions

-- Format number to three digits with leading zeros
-- Used for consistent naming of helper objects
--
-- Parameters:
--   num: Number to format
--
-- Returns:
--   String with three digits (e.g., 1 -> "001", 42 -> "042")
--
fn AA_FormatNumberToThreeDigits num = (
    numStr = num as string
    while (numStr.count < 3) do (
        numStr = "0" + numStr
    )
    return numStr
)

-- Calculate frequency from loop value
-- Converts loop (frame count) to frequency for sine wave
--
-- Parameters:
--   loopValue: Loop value in frames
--
-- Returns:
--   Frequency value for sine wave calculation
--
fn AA_CalculateFrequency loopValue = (
    return AA_TWO_PI / (loopValue / AA_TIME_SCALE)
)

-- Calculate phase offset for bone
-- Determines phase offset based on bone position in chain
--
-- Parameters:
--   bonePercent: Bone's position in chain (0.0 to 1.0)
--   offsetValue: Offset multiplier from UI
--
-- Returns:
--   Phase offset value
--
fn AA_CalculatePhaseOffset bonePercent offsetValue = (
    return offsetValue * bonePercent * -1.0
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Expression Builder Module Loaded\n"
format "========================================\n"

-- # endregion

