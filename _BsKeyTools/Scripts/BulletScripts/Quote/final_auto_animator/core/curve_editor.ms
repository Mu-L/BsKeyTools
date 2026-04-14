-- ============================================================================
-- Auto Animation Tool - Curve Editor Module
-- ============================================================================
-- This module handles bezier curve editing for amplitude modulation.
-- The curve is sampled at each bone's position to determine amplitude variation.
--
-- Curve Structure:
--   - X axis: Bone position in chain (0-100)
--   - Y axis: Amplitude multiplier (0-100)
--   - Stored as bezier_float controller on Curve object
--
-- IMPORTANT: This module contains the curve editing logic from the original script.
-- The UI components remain in core/custom_attributes.ms
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Curve Initialization

-- Initialize default bezier curve
-- Creates a curve with 2 points: (0,0) and (100,100)
--
-- Parameters:
--   curveController: The bezier_float controller to initialize
--
fn AA_InitializeDefaultCurve curveController = (
    
    -- Delete existing keys
    deleteKeys curveController #allKeys
    
    -- Add first key at time offset
    addNewKey curveController AA_CURVE_TIME_OFFSET
    KA = getKey curveController 1
    KA.value = 0.0
    KA.inTangentType = #smooth
    KA.inTangentLength = 0.25
    KA.inTangent = AA_MAGIC_CONST
    KA.outTangentType = #smooth
    KA.outTangentLength = 0.25
    KA.outTangent = AA_MAGIC_CONST
    
    -- Add second key
    addNewKey curveController (AA_CURVE_TIME_OFFSET + 100)
    KB = getKey curveController 2
    KB.value = 100.0
    KB.inTangentType = #smooth
    KB.inTangentLength = 0.25
    KB.inTangent = -AA_MAGIC_CONST
    KB.outTangentType = #smooth
    KB.outTangentLength = 0.25
    KB.outTangent = AA_MAGIC_CONST
)

-- # endregion

-- # region Curve Sampling

-- Sample curve value at specific bone percentage
-- Used in expression to get amplitude modulation
--
-- Parameters:
--   curveController: The bezier_float controller
--   bonePercent: Bone position in chain (0.0 to 1.0)
--
-- Returns:
--   Float value from curve (typically 0-100)
--
fn AA_SampleCurveAtPercent curveController bonePercent = (
    -- Convert bone percent (0-1) to curve time (0-100)
    curveTime = bonePercent * 100.0
    
    -- Sample at offset time
    sampleTime = AA_CURVE_TIME_OFFSET + curveTime
    
    -- Get value from controller
    curveValue = at time sampleTime curveController.value
    
    return curveValue
)

-- # endregion

-- # region Curve Manipulation

-- Update bezier curve key
-- Modifies a key's position and tangents
--
-- Parameters:
--   curveController: The bezier_float controller
--   keyIndex: Index of key to update (1-based)
--   xPos: X position (0-100)
--   yPos: Y position (0-100)
--   inTangent: Optional in tangent value
--   outTangent: Optional out tangent value
--
fn AA_UpdateCurveKey curveController keyIndex xPos yPos inTangent:undefined outTangent:undefined = (
    
    if keyIndex < 1 or keyIndex > curveController.keys.count then (
        return false
    )
    
    key = getKey curveController keyIndex
    
    -- Update key time (X position)
    key.time = AA_CURVE_TIME_OFFSET + xPos
    
    -- Update key value (Y position)
    key.value = yPos
    
    -- Update tangents if provided
    if inTangent != undefined then (
        key.inTangent = inTangent
    )
    
    if outTangent != undefined then (
        key.outTangent = outTangent
    )
    
    return true
)

-- Add new key to curve
-- Inserts a new key at specified position
--
-- Parameters:
--   curveController: The bezier_float controller
--   xPos: X position (0-100)
--   yPos: Y position (0-100)
--
-- Returns:
--   Index of newly created key
--
fn AA_AddCurveKey curveController xPos yPos = (
    
    timeValue = AA_CURVE_TIME_OFFSET + xPos
    
    addNewKey curveController timeValue
    
    -- Find the newly added key
    for i = 1 to curveController.keys.count do (
        key = getKey curveController i
        if key.time == timeValue then (
            key.value = yPos
            key.inTangentType = #smooth
            key.outTangentType = #smooth
            return i
        )
    )
    
    return 0
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Curve Editor Module Loaded\n"
format "========================================\n"

-- # endregion

