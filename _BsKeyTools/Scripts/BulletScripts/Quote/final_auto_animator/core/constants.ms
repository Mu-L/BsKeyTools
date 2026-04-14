-- ============================================================================
-- Auto Animation Tool - Constants Module
-- ============================================================================
-- This module defines all global constants used throughout the auto animation system.
-- These constants replace magic numbers to improve code readability and maintainability.
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Mathematical Constants

-- TWO_PI: Full sine wave cycle (2 * PI = 6.28319)
-- Used in sine wave expression calculations for frequency conversion
global AA_TWO_PI = 6.28319

-- MAGIC_CONST: Bezier tangent calculation constant (0.25 * (1.0 - 0.25) = 0.1875)
-- Used in bezier curve tangent calculations for smooth interpolation
global AA_MAGIC_CONST = 0.1875

-- # endregion

-- # region Time and Frequency Constants

-- TIME_SCALE: Frame to frequency conversion factor (114.592)
-- This constant converts frame-based loop values to frequency values
-- Formula: frequency = TWO_PI / (loop / TIME_SCALE)
global AA_TIME_SCALE = 114.592

-- CURVE_TIME_OFFSET: Timeline offset for curve evaluation (-100000.0)
-- This large negative offset ensures curve evaluation doesn't conflict with actual timeline
-- Used when sampling bezier curves for amplitude modulation
global AA_CURVE_TIME_OFFSET = -100000.0

-- # endregion

-- # region Layer Names

-- Layer names for organizing autoAnim objects
global AA_LAYER_ROOT = "autoAnim"
global AA_LAYER_CONTROLLERS = "autoAnim_Controllers"
global AA_LAYER_CURVES = "autoAnim_WeightCurves"
global AA_LAYER_HELPERS = "autoAnim_Helpers"

-- # endregion

-- # region Grid Layout Settings

-- X offset for stacking X/Y/Z grids horizontally within same group
-- Should be >= grid width (100) plus some padding
global AA_GRID_STACK_OFFSET = 110.0

-- Grid spacing between different bone chain groups
-- Should accommodate 3 panels (X/Y/Z) per group: 3 * AA_GRID_STACK_OFFSET + padding
global AA_GRID_SPACING = 350.0

-- Maximum columns before wrapping to next row
global AA_GRID_COLUMNS = 3

-- Starting position for the first grid
global AA_GRID_START_POS = [0.0, 0.0, 0.0]

-- # endregion

-- # region Layer Management Functions

-- Get or create the root autoAnim layer
-- Returns the layer object
fn AA_GetOrCreateRootLayer = (
    local layerObj = layerManager.getLayerFromName AA_LAYER_ROOT
    if layerObj == undefined do (
        layerObj = layerManager.newLayerFromName AA_LAYER_ROOT
    )
    return layerObj
)

-- Get or create a child layer under autoAnim root
-- Returns the layer object
fn AA_GetOrCreateChildLayer layerName = (
    -- Ensure root layer exists first
    local rootLayer = AA_GetOrCreateRootLayer()

    local layerObj = layerManager.getLayerFromName layerName
    if layerObj == undefined do (
        layerObj = layerManager.newLayerFromName layerName
    )
    -- Set parent to root layer
    layerObj.setParent rootLayer
    return layerObj
)

-- Add node to the Controllers layer (child of autoAnim)
fn AA_AddToControllersLayer nodeObj = (
    local layerObj = AA_GetOrCreateChildLayer AA_LAYER_CONTROLLERS
    layerObj.addnode nodeObj
)

-- Add node to the Weight Curves layer (child of autoAnim)
fn AA_AddToCurvesLayer nodeObj = (
    local layerObj = AA_GetOrCreateChildLayer AA_LAYER_CURVES
    layerObj.addnode nodeObj
)

-- Add node to the Helpers layer (child of autoAnim)
fn AA_AddToHelpersLayer nodeObj = (
    local layerObj = AA_GetOrCreateChildLayer AA_LAYER_HELPERS
    layerObj.addnode nodeObj
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Auto Animation Tool - Constants Module\n"
format "Version: 3.1.0\n"
format "========================================\n"
format "Loaded constants:\n"
format "  AA_TWO_PI = %\n" AA_TWO_PI
format "  AA_MAGIC_CONST = %\n" AA_MAGIC_CONST
format "  AA_TIME_SCALE = %\n" AA_TIME_SCALE
format "  AA_CURVE_TIME_OFFSET = %\n" AA_CURVE_TIME_OFFSET
format "Layer names:\n"
format "  AA_LAYER_CONTROLLERS = %\n" AA_LAYER_CONTROLLERS
format "  AA_LAYER_CURVES = %\n" AA_LAYER_CURVES
format "  AA_LAYER_HELPERS = %\n" AA_LAYER_HELPERS
format "Grid layout:\n"
format "  AA_GRID_SPACING = %\n" AA_GRID_SPACING
format "  AA_GRID_COLUMNS = %\n" AA_GRID_COLUMNS
format "  AA_GRID_STACK_OFFSET = %\n" AA_GRID_STACK_OFFSET
format "========================================\n"

-- # endregion

