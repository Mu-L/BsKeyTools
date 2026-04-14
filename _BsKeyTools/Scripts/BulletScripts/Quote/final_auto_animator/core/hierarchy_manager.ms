-- ============================================================================
-- Auto Animation Tool - Hierarchy Manager Module
-- ============================================================================
-- This module manages the 4-layer hierarchy system for auto animation.
--
-- 4-Layer Hierarchy Structure:
--   Original Bone ← Wave Locator ← Master Locator ← Copy Bone
--
-- Layer Explanation:
--   1. Copy Bone (_Anim): Duplicate of original bone, receives final animation
--   2. Master Locator (_Master): Links to Copy Bone, provides stable reference
--   3. Wave Locator (_Wave): Child of Master, receives sine wave expression
--   4. Original Bone: Constrained to Wave Locator for final animation
--
-- IMPORTANT: This algorithm is COMPLETELY PRESERVED from the original script.
-- Only comments and organization have been improved.
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Helper Object Creation

-- Create or recreate a dummy/point helper object
-- If object with same name exists, it will be deleted and recreated
--
-- Parameters:
--   objName: Name for the helper object
--
-- Returns:
--   The created point helper object
--
fn AA_CreateDummyHelper objName = (
    -- Check if object already exists and delete it
    existingObj = getNodeByName objName
    if existingObj != undefined then (
        delete existingObj
    )
    
    -- Create new point helper
    dummyObj = point pos:[0,0,0] isSelected:off
    dummyObj.name = objName
    dummyObj.cameross = on
    dummyObj.axistripod = off
    
    return dummyObj
)

-- # endregion

-- # region Constraint Functions

-- Apply position constraint from objA to objB
-- Uses Position_Constraint with relative mode
--
-- Parameters:
--   objA: Object to be constrained
--   objB: Target object
--
fn AA_ApplyPositionConstraint objA objB = (
    objA.pos.controller = Position_XYZ()
    objA.pos.controller = position_list()
    posPP = Position_Constraint()
    objA.pos.controller.Available.controller = posPP
    posPP.appendTarget objB 100
    posPP.relative = true
    objA.pos.controller.Available.controller = Position_XYZ()
    objA.pos.controller.setActive 3
)

-- Apply rotation constraint from objA to objB
-- Uses Orientation_Constraint with relative mode
--
-- Parameters:
--   objA: Object to be constrained
--   objB: Target object
--
fn AA_ApplyRotationConstraint objA objB = (
    objA.rotation.controller = Euler_XYZ()
    objA.rotation.controller = rotation_list()
    rotPP = Orientation_Constraint()
    objA.rotation.controller.Available.controller = rotPP
    rotPP.appendTarget objB 100
    rotPP.relative = true
    objA.rotation.controller.Available.controller = Local_Euler_XYZ()
    objA.rotation.controller.setActive 3
)

-- # endregion

-- # region 4-Layer Hierarchy Creation

-- Create Wave Locator for a bone
-- Wave Locator is the layer that receives sine wave expressions
--
-- Parameters:
--   copyBone: The copied bone (_Anim)
--   layerObj: Layer to add objects to
--
-- Returns:
--   The created Wave Locator object
--
fn AA_CreateWaveLocator copyBone layerObj = (
    nameWave = copyBone.name + "_Wave"
    
    -- Create Wave Locator helper
    AA_CreateDummyHelper nameWave
    waveObj = getNodeByName nameWave
    
    -- Reset transform in parent space
    in coordsys parent waveObj.rotation = (quat 0 0 0 0)
    in coordsys parent waveObj.pos = [0,0,0]
    waveObj.axistripod = on
    waveObj.cross = off
    
    -- Add to layer
    if layerObj != undefined then (
        layerObj.addnode waveObj
    )
    
    return waveObj
)

-- Create Master Locator for a bone
-- Master Locator links to the Copy Bone and parents the Wave Locator
--
-- Parameters:
--   copyBone: The copied bone (_Anim)
--   layerObj: Layer to add objects to
--
-- Returns:
--   The created Master Locator object
--
fn AA_CreateMasterLocator copyBone layerObj = (
    nameMaster = copyBone.name + "_Master"

    -- Create Master Locator helper
    AA_CreateDummyHelper nameMaster
    masterObj = getNodeByName nameMaster

    -- Match transform to copy bone
    masterObj.transform = copyBone.transform

    -- Link to copy bone using Link_Constraint
    masterObj.Transform.controller = Link_Constraint()
    masterObj.transform.controller.AddTarget copyBone ((sliderTime as string) as integer)

    -- Add to layer
    if layerObj != undefined then (
        layerObj.addnode masterObj
    )

    -- Hide Master Locator (Wave remains visible for user interaction)
    masterObj.isHidden = true

    return masterObj
)

-- Create complete 4-layer hierarchy for a single bone
-- This is the main function that creates all layers and sets up constraints
--
-- Parameters:
--   originalBone: The original bone to animate
--   copyBone: The copied bone (_Anim)
--   layerObj: Layer to add objects to (optional)
--
-- Returns:
--   Array: #(masterLocator, waveLocator)
--
fn AA_Create4LayerHierarchy originalBone copyBone layerObj = (

    animate off (
        -- Create Master Locator (Layer 2)
        masterObj = AA_CreateMasterLocator copyBone layerObj

        -- Create Wave Locator (Layer 3)
        waveObj = AA_CreateWaveLocator copyBone layerObj

        -- Parent Wave to Master
        waveObj.parent = masterObj

        -- Constrain original bone to Wave Locator (Layer 4 → Layer 3)
        -- This is where the final animation is applied
        originalBone.Transform.controller = prs()
        AA_ApplyPositionConstraint originalBone waveObj
        AA_ApplyRotationConstraint originalBone waveObj
    )

    return #(masterObj, waveObj)
)

-- [DEPRECATED] Apply LookAt constraints to wave locators
-- NOTE: This function is kept for backward compatibility but replaced by AA_ApplyQuaternionAimConstraints
-- LookAt_Constraint causes gimbal lock flipping when _Anim bones are rotated
--
-- Parameters:
--   waveLocators: Array of wave locator objects (sorted)
--   targetAxis: LookAt target axis (default 0)
--   targetAxisFlip: Whether to flip target axis (default false)
--
fn AA_ApplyLookAtConstraints waveLocators targetAxis:0 targetAxisFlip:false = (

    for s = 1 to waveLocators.count do (
        if s > 1 do (
            local t_b = waveLocators[s]

            -- Setup rotation controller
            t_b.rotation.controller = Euler_XYZ()
            t_b.rotation.controller = rotation_list()
            t_b.rotation.controller.Available.controller = LookAt_Constraint()

            lst = t_b.rotation.controller
            lst.SetActive 2

            -- Get previous locator as target
            try (
                lookat_target = waveLocators[(s - 1)]
            ) catch ()

            if lookat_target != undefined do (
                lst.LookAt_Constraint.controller.appendtarget lookat_target 50
                lst.LookAt_Constraint.controller.lookat_vector_length = 0
                lst.LookAt_Constraint.controller.upnode_world = true
                lst.LookAt_Constraint.controller.target_axis = targetAxis
                lst.LookAt_Constraint.controller.target_axisFlip = targetAxisFlip
            )
        )
    )
)

-- # endregion

-- # region Quaternion Aim Constraints

-- Initialize position_list controller for a Wave locator
-- This must be called BEFORE applying quaternion aim constraints
-- to ensure the position controller can receive wave expressions later
--
-- IMPORTANT: This must match the structure expected by mackExpAnim in tool_functions.ms
-- Structure: position_list with [1]=base Position_XYZ, [2]=available slot for expressions
--
-- Parameters:
--   waveObj: Wave locator object
--
fn AA_InitWavePositionController waveObj = (
    if classof(waveObj.pos.controller) != position_list then (
        -- Store current local position
        local localPos = in coordsys parent waveObj.pos

        -- Setup position_list structure (matching tool_functions.ms mackExpAnim expectations)
        waveObj.pos.controller = Position_XYZ()
        waveObj.pos.controller = position_list()

        -- First slot [1]: base position
        waveObj.pos.controller[1].controller = Position_XYZ()

        -- Second slot [2]: available for expressions (added via .Available.controller)
        local posPP = Position_XYZ()
        waveObj.pos.controller.Available.controller = posPP

        -- Restore local position in first slot
        in coordsys parent waveObj.pos = localPos
    )
)

-- Apply Quaternion-based aim constraints to wave locators
-- This replaces LookAt_Constraint to avoid gimbal lock flipping
--
-- Uses rotation_script with quaternion calculation:
-- - Wave[n] looks at Wave[n+1] (forward direction)
-- - Position calculated from Master (fixed) + Wave local offset (independent of rotation)
-- - This avoids circular dependency errors
--
-- Parameters:
--   waveLocators: Array of wave locator objects (sorted from root to tip)
--   masterLocators: Array of master locator objects (same order as waveLocators)
--   rootParent: Reference node for rotation inheritance (usually first _Anim or world)
--   twistMode: Twist control mode (0=None, 1=FirstLast, 2=Individual). Default 1.
--   mainCtrl: Main controller object with twist parameters (required for FirstLast mode)
--   bonelongPercent: Array of bone length percentages for twist distribution
--
fn AA_ApplyQuaternionAimConstraints waveLocators masterLocators rootParent twistMode:1 mainCtrl:undefined bonelongPercent:#() = (

    -- Validate input arrays
    if waveLocators.count != masterLocators.count do (
        format "ERROR: waveLocators and masterLocators must have same length\n"
        return false
    )

    if waveLocators.count < 2 do (
        format "WARNING: Need at least 2 waves for aim constraints\n"
        return true
    )

    -- Initialize position_list for all waves BEFORE applying rotation scripts
    -- This ensures pos.controller is ready for dynamic wave expressions
    for i = 1 to waveLocators.count do (
        AA_InitWavePositionController waveLocators[i]
    )

    -- Build quaternion script expression string
    -- CRITICAL: Must reference Wave position controllers to respond to wave expressions
    -- Wave expressions are added AFTER quaternion constraints, so we need dynamic updates
    --
    -- IMPORTANT: Use axis-angle quaternion method (from ChainsTools.ms)
    -- Calculate in parent LOCAL space to avoid Z-axis flipping issues
    -- Reference vector is [1,0,0] (X-axis) because bone chains grow along X-axis
    local scriptString = \
        "-- Get Wave world positions (Master world pos + Wave local offset)\n" + \
        "posThis = thisMaster.transform.pos + (thisLocalPos.value * thisMaster.transform.rotation)\n" + \
        "posTarget = targetMaster.transform.pos + (targetLocalPos.value * targetMaster.transform.rotation)\n" + \
        "-- Convert to parent local space\n" + \
        "posThisLocal = posThis * inverse thisMaster.transform\n" + \
        "posTargetLocal = posTarget * inverse thisMaster.transform\n" + \
        "-- Calculate aim vector in LOCAL space\n" + \
        "vector = normalize (posTargetLocal - posThisLocal)\n" + \
        "-- Axis-angle quaternion (reference X-axis [1,0,0] for stability)\n" + \
        "axis = normalize (cross vector [1,0,0])\n" + \
        "angle = acos vector.x\n" + \
        "-- Return local rotation (Wave is child of thisMaster)\n" + \
        "(quat angle axis)"

    -- Apply rotation_script to each wave (except first one, which is at the end of array)
    -- NOTE: waveLocators array is in REVERSE order (tip to root)
    -- So waveLocators[1] is the last bone, waveLocators[count] is the first bone
    -- Each wave should look at the PREVIOUS wave in the array (which is the NEXT bone in the chain)
    for i = 2 to waveLocators.count do (
        local thisWave = waveLocators[i]
        local prevWave = waveLocators[i - 1]  -- Previous in array = next in chain
        local thisMaster = masterLocators[i]
        local prevMaster = masterLocators[i - 1]

        -- Create rotation_script controller for quaternion aim
        local quatCtrl = rotation_script()

        -- Add references:
        -- addNode: for Master objects (world position via .transform.pos)
        -- addObject: for Wave position_list (local offset via .value, updates with wave expressions)
        quatCtrl.addNode "thisMaster" thisMaster
        quatCtrl.addNode "targetMaster" prevMaster
        quatCtrl.addObject "thisLocalPos" thisWave.pos.controller
        quatCtrl.addObject "targetLocalPos" prevWave.pos.controller
        quatCtrl.script = scriptString

        -- Apply rotation structure based on twistMode
        if twistMode == 0 then (
            -- No twist: direct rotation_script
            thisWave.rotation.controller = quatCtrl
        ) else (
            -- Twist enabled: use rotation_list
            -- [1] = quaternion aim, [2] = twist layer
            thisWave.rotation.controller = rotation_list()
            thisWave.rotation.controller[1].controller = quatCtrl

            if twistMode == 1 then (
                -- FirstLast mode: euler_xyz with X driven by float_script
                local twistEuler = euler_xyz()
                thisWave.rotation.controller.Available.controller = twistEuler

                -- Create float_script to drive X rotation based on bonelongPercent
                local twistScript = float_script()
                twistEuler.x_rotation.controller = twistScript

                -- Get bone percentage for this wave (arrays are reversed, need to map correctly)
                -- i goes from 2 to count, map to bonelongPercent index
                -- bonelongPercent is in normal order [0, ..., 1.0]
                -- waveLocators[count] = first bone (index 1 in bonelongPercent)
                -- waveLocators[1] = last bone (index count in bonelongPercent)
                local boneIdx = waveLocators.count - i + 1
                local bonePct = 0.0
                if bonelongPercent.count >= boneIdx and boneIdx > 0 do (
                    bonePct = bonelongPercent[boneIdx]
                )

                -- Add references to main controller's twist parameters
                if mainCtrl != undefined and mainCtrl.modifiers.count > 0 do (
                    twistScript.addTarget "twistStart" mainCtrl.modifiers[1].boneSineAniUsePos[#twistStart]
                    twistScript.addTarget "twistEnd" mainCtrl.modifiers[1].boneSineAniUsePos[#twistEnd]
                )
                twistScript.addConstant "bonePct" bonePct

                -- Twist distribution formula: twistStart + (twistEnd - twistStart) * bonePct
                -- Convert degrees to radians
                twistScript.script = "degtorad (twistStart + (twistEnd - twistStart) * bonePct)"
            ) else if twistMode == 2 then (
                -- Individual mode: euler_xyz for manual adjustment
                local twistEuler = euler_xyz()
                thisWave.rotation.controller.Available.controller = twistEuler
                -- Set Euler XYZ as active so user can directly rotate
                thisWave.rotation.controller.setActive 2
            )
        )
    )

    return true
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Hierarchy Manager Module Loaded\n"
format "========================================\n"

-- # endregion

