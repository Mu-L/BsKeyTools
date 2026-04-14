-- ============================================================================
-- Auto Animation Tool 2.0 - Main Entry Point
-- ============================================================================
-- This is the main entry point for the Auto Animation Tool.
-- It loads all required modules in the correct order and initializes the system.
--
-- Usage:
--   fileIn "D:/UGit/allTogether/aa_self_free/final_auto_animator/autoAnim_main.ms"
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Version Info

global AA_VERSION = "2.0.0"
global AA_BUILD_DATE = "2026-02-13"

format "\n"
format "========================================\n"
format "  Auto Animation Tool v%\n" AA_VERSION
format "  Build Date: %\n" AA_BUILD_DATE
format "========================================\n"
format "\n"

-- # endregion

-- # region Get Script Directory

-- Get the directory where this script is located
-- This allows us to load modules using relative paths
scriptPath = getSourceFileName()
scriptDir = getFilenamePath scriptPath

format "[INFO] Script directory: %\n" scriptDir

-- # endregion

-- # region Load Modules

format "[INFO] Loading modules...\n"

-- Load constants first (no dependencies)
fileIn (scriptDir + "core\\constants.ms")

-- Load utility modules (depend on constants)
fileIn (scriptDir + "utils\\naming.ms")
fileIn (scriptDir + "utils\\validation.ms")
fileIn (scriptDir + "utils\\startup_installer.ms")  -- Startup script auto-installer

-- Load core modules (depend on constants and utils)
fileIn (scriptDir + "core\\spline_curve_widget.ms")   -- Spline weight curve creation
fileIn (scriptDir + "core\\spline_curve_sampler.ms")  -- Spline X-coordinate sampling
fileIn (scriptDir + "core\\expression_builder.ms")
fileIn (scriptDir + "core\\hierarchy_manager.ms")
fileIn (scriptDir + "core\\curve_editor.ms")
fileIn (scriptDir + "core\\custom_attributes.ms")
fileIn (scriptDir + "core\\tool_functions.ms")
fileIn (scriptDir + "core\\tool_window.ms")  -- Tool window UI (original code preserved)

format "[INFO] All modules loaded successfully!\n"
format "\n"

-- # endregion

-- # region Module Status

format "========================================\n"
format "Module Status:\n"
format "========================================\n"
format "  [OK] core/constants.ms\n"
format "  [OK] utils/naming.ms\n"
format "  [OK] utils/validation.ms\n"
format "  [OK] utils/startup_installer.ms\n"
format "  [OK] core/spline_curve_widget.ms\n"
format "  [OK] core/spline_curve_sampler.ms\n"
format "  [OK] core/expression_builder.ms\n"
format "  [OK] core/hierarchy_manager.ms\n"
format "  [OK] core/curve_editor.ms\n"
format "  [OK] core/custom_attributes.ms\n"
format "  [OK] core/tool_functions.ms\n"
format "  [OK] core/tool_window.ms\n"
format "========================================\n"
format "\n"

-- # endregion

-- # region Quick Test

format "[INFO] Running quick module test...\n"
format "\n"

-- Test constants
format "[TEST] Constants:\n"
format "  AA_TWO_PI = %\n" AA_TWO_PI
format "  AA_TIME_SCALE = %\n" AA_TIME_SCALE
format "\n"

-- Test naming utilities
format "[TEST] Naming utilities:\n"
testName = AA_GenerateUniqueName "TestObject" "_Locator"
format "  Generated name: %\n" testName
format "\n"

-- Test validation
format "[TEST] Validation:\n"
testBones = selection as array
if testBones.count > 0 then (
    isValid = AA_ValidateBoneChain testBones
    format "  Bone chain valid: %\n" isValid
    
    if isValid then (
        percentages = AA_CalculateBonePercent testBones
        format "  Bone percentages: %\n" percentages
    )
) else (
    format "  No bones selected for testing\n"
)
format "\n"

format "========================================\n"
format "Auto Animation Tool v% Ready!\n" AA_VERSION
format "========================================\n"
format "\n"

-- # endregion

-- # region Startup Script Installation

-- Ensure startup script is installed for scene reload support
AA_EnsureStartupInstalled scriptDir

-- # endregion

