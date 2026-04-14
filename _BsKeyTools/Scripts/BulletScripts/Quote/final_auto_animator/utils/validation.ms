-- ============================================================================
-- Auto Animation Tool - Validation Module
-- ============================================================================
-- This module provides parameter validation functions to ensure data integrity
-- and provide meaningful error messages to users.
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Bone Chain Validation

-- Validate bone chain selection
-- Checks if the selected bones form a valid chain for auto animation
--
-- Parameters:
--   bones: Array of bone objects to validate
--
-- Returns:
--   true if valid, false otherwise (displays error message)
--
fn AA_ValidateBoneChain bones = (
    -- Check if bones array exists and has elements
    if bones == undefined or bones.count == 0 then (
        messageBox "错误：请选择至少一个骨骼" title:"自己动 - 验证错误"
        return false
    )
    
    -- Check if at least 2 bones for meaningful animation
    -- (removed warning popup - allow single bone silently)
    -- if bones.count < 2 then (
    --     messageBox "警告：建议选择至少2个骨骼以获得更好的动画效果" title:"自己动 - 警告"
    -- )
    
    -- Validate each bone is actually a bone or helper object
    for bone in bones do (
        if bone == undefined then (
            messageBox "错误：选择中包含无效对象" title:"自己动 - 验证错误"
            return false
        )
    )
    
    return true
)

-- # endregion

-- # region Parameter Validation

-- Validate numeric parameter range
-- Checks if a parameter value is within acceptable range
--
-- Parameters:
--   paramName: Name of the parameter (for error message)
--   value: Value to validate
--   minVal: Minimum acceptable value
--   maxVal: Maximum acceptable value
--
-- Returns:
--   true if valid, false otherwise (displays error message)
--
fn AA_ValidateParameter paramName value minVal maxVal = (
    if value < minVal or value > maxVal then (
        errorMsg = paramName + " 必须在 " + (minVal as string) + " 到 " + (maxVal as string) + " 之间\n"
        errorMsg += "当前值: " + (value as string)
        messageBox errorMsg title:"自己动 - 参数错误"
        return false
    )
    return true
)

-- Validate loop parameter (must be positive)
-- Loop value represents animation cycle length in frames
--
-- Parameters:
--   loopValue: Loop value to validate
--
-- Returns:
--   true if valid, false otherwise
--
fn AA_ValidateLoop loopValue = (
    if loopValue <= 0 then (
        messageBox "循环周期必须大于0帧" title:"自己动 - 参数错误"
        return false
    )
    
    if loopValue > 10000 then (
        messageBox "警告：循环周期过大 (>10000帧)，可能导致性能问题" title:"自己动 - 警告"
        -- Allow but warn
    )
    
    return true
)

-- Validate range parameter (amplitude)
-- Range value represents animation amplitude
--
-- Parameters:
--   rangeValue: Range value to validate
--
-- Returns:
--   true if valid, false otherwise
--
fn AA_ValidateRange rangeValue = (
    if rangeValue < 0 then (
        messageBox "振幅范围不能为负数" title:"自己动 - 参数错误"
        return false
    )
    
    if rangeValue > 1000 then (
        messageBox "警告：振幅范围过大 (>1000)，可能导致不自然的动画" title:"自己动 - 警告"
        -- Allow but warn
    )
    
    return true
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Validation Module Loaded\n"
format "========================================\n"

-- # endregion

