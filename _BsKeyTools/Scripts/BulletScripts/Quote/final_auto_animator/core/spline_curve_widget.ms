-- ============================================================================
-- Auto Animation Tool - Spline Curve Widget Module
-- ============================================================================
-- This module handles creation and management of Spline-based weight curves.
-- The Spline curve allows animated weight control that changes over time.
--
-- Spline Structure:
--   - X axis: Bone position in chain (0-100)
--   - Y axis: Weight multiplier (0-100)
--   - Z axis: Ignored (soft constraint)
--
-- Features:
--   - Create weight curve Spline with reference plane
--   - Support vertex editing (add/delete/move)
--   - Support modifiers (FFD, Noise, etc.)
--   - Optional follow mode for bone chain
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Global Variables

-- Counter for unique naming
global AA_WeightCurveCounter = 0

-- Forward declarations for global functions
global AA_CreateWeightCurveSpline
global AA_CreateReferencePlane
global AA_GridConfig
global AA_CreateGridLines
global AA_CreateXAxis
global AA_CreateYAxis
global AA_CreateOriginMarker
global AA_CreateBoundary
global AA_CreateCoordinateLabels
global AA_CreateSnapPoints
global AA_GetOrCreateLayer
global AA_MoveToLayer
global AA_FreezeHierarchy

-- Grid layout and grouping functions
global AA_FindExistingGrids
global AA_FindExistingGridGroups
global AA_CheckGridCollision
global AA_CalculateNextGridPosition
global AA_SetGridOrientation
global AA_CreateGridGroup
global AA_StackGridInGroup

-- # endregion

-- # region Grid Configuration

struct AA_GridConfig (
    -- Grid settings
    minX = 0.0,
    maxX = 100.0,
    minY = 0.0,
    maxY = 100.0,

    -- Grid density
    majorStep = 20.0,      -- Major grid lines every 20 units
    minorStep = 10.0,      -- Minor grid lines every 10 units

    -- Colors
    majorGridColor = color 100 100 100,   -- Darker gray for major lines
    minorGridColor = color 60 60 60,      -- Lighter gray for minor lines
    xAxisColor = color 255 50 50,         -- Red X-axis
    yAxisColor = color 50 255 50,         -- Green Y-axis
    labelColor = color 180 180 180,       -- Light gray for labels
    originColor = color 255 255 50,       -- Yellow origin marker
    snapPointColor = color 128 128 128,   -- Gray for snap points

    -- Z offsets to avoid overlap
    gridZ = -0.1,
    axisZ = 0.0,
    labelZ = 0.1,
    snapPointZ = 0.0,

    -- Label settings
    labelSize = 4.0,
    labelOffset = 6.0,    -- Distance from axis

    -- Snap point settings
    snapPointSize = 1.5,  -- Size of snap point helpers

    -- Display options
    showMinorGrid = true,
    showLabels = true,
    showOriginMarker = true,
    showBoundary = true,
    showSnapPoints = true,  -- Show points at grid intersections for snapping

    -- Layer settings
    layerName = "autoAnim_Helpers",
    freezeReferences = true   -- Freeze reference objects to prevent selection
)

-- # endregion

-- # region Spline Creation

-- Create a weight curve Spline
-- Creates a SplineShape with default range [0,0] to [100,100]
--
-- Parameters:
--   startX: Start X coordinate (default: 0)
--   startY: Start Y coordinate (default: 0)
--   endX: End X coordinate (default: 100)
--   endY: End Y coordinate (default: 100)
--   pos: Position in world space (default: [0,0,0])
--
-- Returns:
--   The created SplineShape object
--
fn AA_CreateWeightCurveSpline startX:0.0 startY:0.0 endX:100.0 endY:100.0 pos:[0,0,0] = (

    -- Increment counter for unique naming
    AA_WeightCurveCounter += 1
    local curveName = "AA_WeightCurve_" + (formattedPrint AA_WeightCurveCounter format:"03d")

    -- Create SplineShape
    local splineObj = SplineShape name:curveName pos:pos

    -- Calculate middle point
    local midX = (startX + endX) / 2.0
    local midY = (startY + endY) / 2.0

    -- Add first spline with three knots (start, middle, end)
    -- Create as straight line - all knots use #bezier type for collinear handles
    addNewSpline splineObj
    addKnot splineObj 1 #smooth #curve [startX, startY, 0]
    addKnot splineObj 1 #smooth #curve [midX, midY, 0]
    addKnot splineObj 1 #smooth #curve [endX, endY, 0]
    updateShape splineObj

    -- Convert all knots to #bezier type for collinear handles
    setKnotType splineObj 1 1 #bezier
    setKnotType splineObj 1 2 #bezier
    setKnotType splineObj 1 3 #bezier
    updateShape splineObj

    -- Calculate direction vector from start to end
    local dirX = endX - startX
    local dirY = endY - startY
    local totalLen = sqrt(dirX * dirX + dirY * dirY)

    -- Normalize direction
    if totalLen > 0 then (
        dirX = dirX / totalLen
        dirY = dirY / totalLen
    )

    -- Handle length (1/6 of total distance for smooth straight line)
    local handleLen = totalLen / 6.0

    -- Start point: handles along the line direction
    -- InVec points backward (opposite direction), OutVec points forward (toward end)
    setInVec splineObj 1 1 [startX - dirX * handleLen, startY - dirY * handleLen, 0]
    setOutVec splineObj 1 1 [startX + dirX * handleLen, startY + dirY * handleLen, 0]

    -- Middle point: handles along the line direction
    -- InVec points toward start, OutVec points toward end
    setInVec splineObj 1 2 [midX - dirX * handleLen, midY - dirY * handleLen, 0]
    setOutVec splineObj 1 2 [midX + dirX * handleLen, midY + dirY * handleLen, 0]

    -- End point: handles along the line direction
    -- InVec points backward (toward start), OutVec points forward (opposite direction)
    setInVec splineObj 1 3 [endX - dirX * handleLen, endY - dirY * handleLen, 0]
    setOutVec splineObj 1 3 [endX + dirX * handleLen, endY + dirY * handleLen, 0]

    updateShape splineObj

    -- Keep pivot at default (0,0,0) - do not modify

    -- Set display properties
    splineObj.wireColor = color 255 128 0  -- Orange color for visibility
    splineObj.renderable = false
    splineObj.displayRenderMesh = false

    return splineObj
)

-- # endregion

-- # region Grid Line Creation

-- Create spline-based grid lines (transparent, never blocks other objects)
fn AA_CreateGridLines config baseName:"AA_RefGrid" = (
    local gridObj = SplineShape name:(baseName + "_Lines") pos:[0,0,0]

    local splineIdx = 0

    -- Create vertical lines (along Y direction)
    for x = config.minX to config.maxX by config.minorStep do (
        local isMajor = (mod (x - config.minX) config.majorStep) == 0
        if config.showMinorGrid or isMajor then (
            addNewSpline gridObj
            splineIdx += 1
            addKnot gridObj splineIdx #corner #line [x, config.minY, config.gridZ]
            addKnot gridObj splineIdx #corner #line [x, config.maxY, config.gridZ]
        )
    )

    -- Create horizontal lines (along X direction)
    for y = config.minY to config.maxY by config.minorStep do (
        local isMajor = (mod (y - config.minY) config.majorStep) == 0
        if config.showMinorGrid or isMajor then (
            addNewSpline gridObj
            splineIdx += 1
            addKnot gridObj splineIdx #corner #line [config.minX, y, config.gridZ]
            addKnot gridObj splineIdx #corner #line [config.maxX, y, config.gridZ]
        )
    )

    updateShape gridObj
    gridObj.wireColor = config.majorGridColor
    gridObj.renderable = false

    return gridObj
)

-- Create colored X-axis
fn AA_CreateXAxis config baseName:"AA_RefGrid" = (
    local xAxisObj = SplineShape name:(baseName + "_XAxis") pos:[0,0,0]
    addNewSpline xAxisObj
    addKnot xAxisObj 1 #corner #line [config.minX, 0, config.axisZ]
    addKnot xAxisObj 1 #corner #line [config.maxX, 0, config.axisZ]
    updateShape xAxisObj
    xAxisObj.wireColor = config.xAxisColor
    xAxisObj.renderable = false
    return xAxisObj
)

-- Create colored Y-axis
fn AA_CreateYAxis config baseName:"AA_RefGrid" = (
    local yAxisObj = SplineShape name:(baseName + "_YAxis") pos:[0,0,0]
    addNewSpline yAxisObj
    addKnot yAxisObj 1 #corner #line [0, config.minY, config.axisZ]
    addKnot yAxisObj 1 #corner #line [0, config.maxY, config.axisZ]
    updateShape yAxisObj
    yAxisObj.wireColor = config.yAxisColor
    yAxisObj.renderable = false
    return yAxisObj
)

-- Create origin marker (small cross at 0,0)
fn AA_CreateOriginMarker config baseName:"AA_RefGrid" = (
    local markerSize = config.majorStep / 4.0
    local markerObj = SplineShape name:(baseName + "_Origin") pos:[0,0,0]

    -- Horizontal line of cross
    addNewSpline markerObj
    addKnot markerObj 1 #corner #line [-markerSize, 0, config.axisZ + 0.01]
    addKnot markerObj 1 #corner #line [markerSize, 0, config.axisZ + 0.01]

    -- Vertical line of cross
    addNewSpline markerObj
    addKnot markerObj 2 #corner #line [0, -markerSize, config.axisZ + 0.01]
    addKnot markerObj 2 #corner #line [0, markerSize, config.axisZ + 0.01]

    updateShape markerObj
    markerObj.wireColor = config.originColor
    markerObj.renderable = false
    return markerObj
)

-- Create boundary box
fn AA_CreateBoundary config baseName:"AA_RefGrid" = (
    local boundObj = SplineShape name:(baseName + "_Boundary") pos:[0,0,0]
    addNewSpline boundObj
    addKnot boundObj 1 #corner #line [config.minX, config.minY, config.gridZ]
    addKnot boundObj 1 #corner #line [config.maxX, config.minY, config.gridZ]
    addKnot boundObj 1 #corner #line [config.maxX, config.maxY, config.gridZ]
    addKnot boundObj 1 #corner #line [config.minX, config.maxY, config.gridZ]
    close boundObj 1

    updateShape boundObj
    boundObj.wireColor = color 150 150 150
    boundObj.renderable = false
    return boundObj
)

-- # endregion

-- # region Coordinate Labels Creation

-- Create Text labels for coordinates
fn AA_CreateCoordinateLabels config baseName:"AA_RefGrid" = (
    local labelGroup = Dummy name:(baseName + "_Labels") boxSize:[1,1,1]
    labelGroup.pos = [0,0,0]

    -- X-axis labels (below the axis)
    for x = config.minX to config.maxX by config.majorStep do (
        local labelText = (x as integer) as string
        local txt = Text text:labelText size:config.labelSize \
            pos:[x, -config.labelOffset, config.labelZ] \
            wireColor:config.labelColor
        txt.renderable = false
        txt.parent = labelGroup
    )

    -- Y-axis labels (left of the axis)
    for y = config.minY to config.maxY by config.majorStep do (
        -- Skip 0 to avoid overlap with X-axis label
        if y > 0 then (
            local labelText = (y as integer) as string
            local txt = Text text:labelText size:config.labelSize \
                pos:[-config.labelOffset, y, config.labelZ] \
                wireColor:config.labelColor
            txt.renderable = false
            txt.parent = labelGroup
        )
    )

    return labelGroup
)

-- # endregion

-- # region Snap Points Creation

-- Create Point helpers at grid intersections for snapping
fn AA_CreateSnapPoints config baseName:"AA_RefGrid" = (
    local snapGroup = Dummy name:(baseName + "_SnapPoints") boxSize:[1,1,1]
    snapGroup.pos = [0,0,0]

    -- Create points at all grid intersections (using minorStep)
    for x = config.minX to config.maxX by config.minorStep do (
        for y = config.minY to config.maxY by config.minorStep do (
            local pt = Point name:"AA_SnapPt" size:config.snapPointSize \
                pos:[x, y, config.snapPointZ] \
                wireColor:config.snapPointColor \
                centermarker:true cross:false axisTripod:false box:false
            pt.renderable = false
            pt.parent = snapGroup
        )
    )

    return snapGroup
)

-- # endregion

-- # region Layer Management

-- Get or create a layer by name
fn AA_GetOrCreateLayer layerName = (
    local layer = LayerManager.getLayerFromName layerName
    if layer == undefined then (
        layer = LayerManager.newLayerFromName layerName
    )
    return layer
)

-- Move object and all its children to a layer
fn AA_MoveToLayer obj layer = (
    layer.addNode obj
    for child in obj.children do (
        AA_MoveToLayer child layer
    )
)

-- Freeze object and all its children (except specified exclusions)
fn AA_FreezeHierarchy obj excludeNames:#() = (
    local shouldFreeze = true
    for exName in excludeNames do (
        if matchPattern obj.name pattern:exName do shouldFreeze = false
    )
    if shouldFreeze do (
        obj.isFrozen = true
        if isProperty obj #showFrozenInGray do obj.showFrozenInGray = false
    )
    for child in obj.children do (
        AA_FreezeHierarchy child excludeNames:excludeNames
    )
)

-- # endregion

-- # region Reference Plane Creation

-- Create the complete reference plane V2 with all components
-- Uses Spline-based grid lines (transparent) instead of Plane geometry
--
-- Parameters:
--   splineObj: The Spline weight curve to attach to
--   config: AA_GridConfig struct (optional, uses defaults if not provided)
--
-- Returns:
--   Dummy object that is the parent of all grid components
--
fn AA_CreateReferencePlane splineObj config:undefined = (

    -- Use default config if not provided
    if config == undefined do config = AA_GridConfig()

    -- Create base name from spline name
    local baseName = (substituteString splineObj.name "WeightCurve" "RefGrid")

    -- Create parent Point helper for all grid components (easier to select than Dummy)
    local gridParent = Point name:baseName size:15 centermarker:true cross:true axisTripod:true box:true
    gridParent.pos = [0,0,0]
    gridParent.wirecolor = color 255 200 0  -- Golden yellow for visibility
    gridParent.renderable = false

    -- Create grid lines
    local gridLines = AA_CreateGridLines config baseName:baseName
    gridLines.parent = gridParent

    -- Create colored axes
    local xAxis = AA_CreateXAxis config baseName:baseName
    xAxis.parent = gridParent

    local yAxis = AA_CreateYAxis config baseName:baseName
    yAxis.parent = gridParent

    -- Create origin marker (if enabled)
    if config.showOriginMarker then (
        local origin = AA_CreateOriginMarker config baseName:baseName
        origin.parent = gridParent
    )

    -- Create boundary (if enabled)
    if config.showBoundary then (
        local boundary = AA_CreateBoundary config baseName:baseName
        boundary.parent = gridParent
    )

    -- Create coordinate labels (if enabled)
    if config.showLabels then (
        local labels = AA_CreateCoordinateLabels config baseName:baseName
        labels.parent = gridParent
    )

    -- Create snap points at grid intersections (if enabled)
    if config.showSnapPoints then (
        local snapPoints = AA_CreateSnapPoints config baseName:baseName
        snapPoints.parent = gridParent
    )

    -- Attach spline curve to grid
    splineObj.parent = gridParent

    -- Move all objects to the specified layer
    local helperLayer = AA_GetOrCreateLayer config.layerName
    AA_MoveToLayer gridParent helperLayer

    -- Freeze reference objects (exclude the weight curve spline and gridParent)
    if config.freezeReferences then (
        -- Freeze all children except the weight curve
        for child in gridParent.children do (
            if child != splineObj then (
                AA_FreezeHierarchy child excludeNames:#()
            )
        )
        -- DO NOT freeze gridParent - keep it selectable for moving the whole grid
    )

    return gridParent
)

-- # endregion

-- # region Grid Layout and Grouping

-- Find all existing reference grid parent dummies in scene
-- Returns: Array of grid parent Dummy nodes (AA_RefGrid_*)
fn AA_FindExistingGrids = (
    local grids = #()
    for obj in objects do (
        if matchPattern obj.name pattern:"AA_RefGrid_*" do (
            -- Only collect parent helpers, not child objects (Point or Dummy for backward compatibility)
            if classof obj == Dummy or classof obj == Point do (
                append grids obj
            )
        )
    )
    return grids
)

-- Find all existing grid group containers in scene
-- Returns: Array of grid group Dummy nodes (*_GridGroup)
fn AA_FindExistingGridGroups = (
    local groups = #()
    for obj in objects do (
        if matchPattern obj.name pattern:"*_GridGroup" do (
            if classof obj == Dummy do (
                append groups obj
            )
        )
    )
    return groups
)

-- Check if a candidate position collides with any existing grid or grid group
-- Uses distance-based collision detection
--
-- Parameters:
--   pos: Candidate position [x, y, z]
--   existingObjects: Array of existing grid/group objects to check against
--   threshold: Minimum distance to consider as collision (default: 96.0 = 80% of 120 spacing)
--
-- Returns:
--   true if collision detected, false otherwise
fn AA_CheckGridCollision pos existingObjects threshold:96.0 = (
    for obj in existingObjects do (
        local dist = length (obj.pos - pos)
        if dist < threshold do return true
    )
    return false
)

-- Calculate next available grid position with collision avoidance
-- Handles user-moved grids by checking actual positions instead of just counting
--
-- Parameters:
--   spacing: Distance between grids (default: AA_GRID_SPACING)
--   columns: Max columns before row wrap (default: AA_GRID_COLUMNS)
--
-- Returns:
--   Point3 position for new grid that doesn't collide with existing ones
fn AA_CalculateNextGridPosition spacing:AA_GRID_SPACING columns:AA_GRID_COLUMNS = (
    -- Get all existing grid groups (primary collision targets)
    local existingGroups = AA_FindExistingGridGroups()
    local threshold = spacing * 0.8  -- 80% of spacing as collision threshold

    -- Try grid positions until finding one without collision
    for attempts = 0 to 99 do (
        local row = attempts / columns
        local col = mod attempts columns

        -- Calculate candidate position (MaxScript requires single line Point3)
        local posX = AA_GRID_START_POS.x + (col * spacing)
        local posY = AA_GRID_START_POS.y - (row * spacing)
        local posZ = AA_GRID_START_POS.z
        local candidatePos = [posX, posY, posZ]

        -- Check collision with existing grid groups
        if not (AA_CheckGridCollision candidatePos existingGroups threshold:threshold) do (
            return candidatePos
        )
    )

    -- Fallback: offset from last grid group
    if existingGroups.count > 0 then (
        return existingGroups[existingGroups.count].pos + [spacing, 0, 0]
    ) else (
        return AA_GRID_START_POS
    )
)

-- Set the orientation of a grid or grid group
-- This allows grids to be rotated (e.g., standing up vertically)
-- Note: Animation driving is NOT affected because sampling uses local coordinates
--
-- Parameters:
--   gridObj: The grid parent dummy or grid group to rotate
--   orientation: #horizontal (default), #vertical_xz (face Y), #vertical_yz (face X)
--
-- Returns:
--   true if successful
fn AA_SetGridOrientation gridObj orientation:#horizontal = (
    if gridObj == undefined do return false
    if not isValidNode gridObj do return false

    case orientation of (
        #horizontal: (
            -- Flat on XY plane (default)
            gridObj.rotation = (quat 0 0 0 1)
        )
        #vertical_xz: (
            -- Standing up, facing Y axis (rotate 90 degrees around X)
            gridObj.rotation = (quat 0.7071068 0 0 0.7071068)
        )
        #vertical_yz: (
            -- Standing up, facing X axis (rotate 90 degrees around Y)
            gridObj.rotation = (quat 0 0.7071068 0 0.7071068)
        )
        default: (
            -- Unknown orientation, keep current
            return false
        )
    )

    return true
)

-- Create a group container for a bone chain's grids
-- All X/Y/Z grids for the same bone chain will be children of this group
--
-- Parameters:
--   prefix: Bone chain prefix name (used in naming)
--   basePos: Base position for this group (optional, auto-calculated if undefined)
--
-- Returns:
--   Dummy object as group container
fn AA_CreateGridGroup prefix basePos:undefined = (
    local groupName = prefix + "_GridGroup"

    -- Calculate position if not provided
    if basePos == undefined do (
        basePos = AA_CalculateNextGridPosition()
    )

    -- Delete if exists (recreate with new position)
    local existing = getNodeByName groupName
    if existing != undefined do delete existing

    -- Create group container dummy (no rotation, just a container)
    -- Each child grid will be rotated individually in AA_StackGridInGroup
    local groupDummy = Dummy name:groupName pos:basePos boxSize:[1,1,1]
    groupDummy.renderable = false

    -- Create a dedicated sub-layer for this bone chain's grids
    -- Layer hierarchy: autoAnim_WeightCurves > {prefix}_GridGroup
    local curvesLayer = AA_GetOrCreateChildLayer AA_LAYER_CURVES
    local groupLayerName = groupName
    local groupLayer = layerManager.getLayerFromName groupLayerName
    if groupLayer == undefined do (
        groupLayer = layerManager.newLayerFromName groupLayerName
    )
    -- Set parent using setParent (not addChildLayer which doesn't exist)
    groupLayer.setParent curvesLayer

    -- Add group dummy to its dedicated layer
    groupLayer.addnode groupDummy

    return groupDummy
)

-- Stack a grid within its parent group
-- X/Y/Z grids are stacked with X-offset (horizontal direction) to avoid overlap
-- Each grid is rotated to vertical orientation (standing up, facing front view)
-- This makes X/Y/Z grids visible side-by-side horizontally in front view
--
-- Parameters:
--   gridParent: The reference grid dummy to position
--   groupContainer: The parent group dummy
--   axisIndex: (deprecated) Now ignored, position is based on existing children count
--   stackOffset: X offset between stacked grids (default: AA_GRID_STACK_OFFSET)
fn AA_StackGridInGroup gridParent groupContainer axisIndex stackOffset:AA_GRID_STACK_OFFSET = (
    if gridParent == undefined do return false
    if groupContainer == undefined do return false

    -- Count existing children to determine position (before parenting)
    local existingCount = groupContainer.children.count

    -- First rotate the grid to vertical orientation BEFORE parenting
    -- This ensures the grid stands up facing the front view
    AA_SetGridOrientation gridParent orientation:#vertical_xz

    -- Parent to group
    gridParent.parent = groupContainer

    -- Stack position in parent space: offset in X direction based on existing children count
    -- First grid at 0, second at stackOffset, third at stackOffset*2, etc.
    in coordsys parent gridParent.pos = [existingCount * stackOffset, 0, 0]

    -- Move grid and all its children to the same layer as the group container
    local groupLayerName = groupContainer.name
    local groupLayer = layerManager.getLayerFromName groupLayerName
    if groupLayer != undefined do (
        groupLayer.addnode gridParent
        -- Also add all children (spline curve, grid lines, etc.)
        for child in gridParent.children do (
            groupLayer.addnode child
        )
    )

    return true
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Spline Curve Widget Module Loaded\n"
format "========================================\n"

-- # endregion

