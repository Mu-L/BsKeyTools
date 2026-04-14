-- ============================================================================
-- Auto Animation Tool - Naming Utilities Module
-- ============================================================================
-- This module provides utility functions for naming and bone chain calculations.
-- These functions are used throughout the system for consistent naming and
-- bone percentage calculations.
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Bone Chain Calculations

-- Calculate bone chain length percentages
-- This function calculates the cumulative distance percentage for each bone in a chain
-- Used for phase offset calculations in sine wave expressions
--
-- Parameters:
--   boneChain: Array of bone objects in hierarchical order
--
-- Returns:
--   Array of float values representing cumulative distance percentage (0.0 to 1.0)
--   First bone is always 0.0, last bone is always 1.0
--
-- Example:
--   bones = #($Bone01, $Bone02, $Bone03)
--   percentages = AA_CalculateBonePercent bones
--   -- Returns something like: #(0.0, 0.35, 1.0)
--
fn AA_CalculateBonePercent boneChain = (
    -- Record distances between bones
    distanceRec = #()
    disAll = 0
    append distanceRec 0
    
    -- Calculate cumulative distances
    for i = 1 to boneChain.count-1 do (
        dis = length(boneChain[i+1].transform.pos - boneChain[i].transform.pos)
        disAll += dis
        append distanceRec disAll
    )
    
    -- Convert to percentages (0.0 to 1.0)
    longthPer = #()
    -- Avoid divide by zero when bones are at same position or only one bone
    if disAll == 0 then disAll = 1.0
    for i = 1 to boneChain.count do (
        append longthPer (distanceRec[i] / disAll)
    )
    
    return longthPer
)

-- Get total bone chain length
-- Calculates the total distance from first bone to last bone
--
-- Parameters:
--   boneChain: Array of bone objects
--
-- Returns:
--   Float value representing total chain length in scene units
--
fn AA_GetBoneChainLength boneChain = (
    if boneChain == undefined or boneChain.count < 2 then (
        return 0.0
    )
    
    totalLength = 0.0
    for i = 1 to boneChain.count-1 do (
        dis = length(boneChain[i+1].transform.pos - boneChain[i].transform.pos)
        totalLength += dis
    )
    
    return totalLength
)

-- # endregion

-- # region Naming Utilities

-- Generate unique name with suffix
-- Creates a unique object name by appending a suffix and number if needed
--
-- Parameters:
--   baseName: Base name for the object (e.g., "Wave")
--   suffix: Suffix to append (e.g., "_Locator")
--
-- Returns:
--   String with unique name (e.g., "Wave_Locator01" if "Wave_Locator" exists)
--
fn AA_GenerateUniqueName baseName suffix = (
    proposedName = baseName + suffix
    
    -- Check if name already exists
    if (getnodebyname proposedName) == undefined then (
        return proposedName
    )
    
    -- Find unique number suffix
    counter = 1
    while counter < 1000 do (
        numberedName = proposedName + (formattedprint counter format:"02d")
        if (getnodebyname numberedName) == undefined then (
            return numberedName
        )
        counter += 1
    )
    
    -- Fallback: use timestamp
    return proposedName + (timestamp() as string)
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Naming Utilities Module Loaded\n"
format "========================================\n"

-- # endregion

