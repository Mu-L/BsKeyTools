-- ============================================================================
-- Auto Animation Tool - Spline Curve Sampler Module
-- ============================================================================
-- This module handles sampling of Spline-based weight curves.
-- Given an X coordinate, returns the corresponding Y value from the curve.
--
-- Sampling Method:
--   - Uses interpCurve3D to sample points along the curve
--   - Binary search for monotonic curves (X always increasing)
--   - Linear search fallback for non-monotonic curves
--   - Caches results to avoid redundant calculations
--
-- Version: 2.0.0
-- Author: Auto Animation Tool Team
-- ============================================================================

-- # region Global Variables

-- Global cache container
global AA_SplineSampleCache = #()

-- Default number of sample points for curve interpolation
global AA_DEFAULT_SAMPLE_COUNT = 100

-- Forward declarations for global functions
global AA_ComputeKnotHash
global AA_FindCache
global AA_RemoveCache
global AA_BuildSampleCache
global AA_BinarySearchY
global AA_LinearSearchY
global AA_GetCachedSample
global AA_SampleSplineAtX

-- # endregion

-- # region Cache Structure

-- Compute hash from knot positions and tangent vectors for change detection
fn AA_ComputeKnotHash splineObj = (
    if splineObj == undefined do return 0.0
    if not isValidNode splineObj do return 0.0
    if numSplines splineObj < 1 do return 0.0

    local hashVal = 0.0
    local knotCount = numKnots splineObj 1
    for i = 1 to knotCount do (
        local pt = getKnotPoint splineObj 1 i
        local inV = getInVec splineObj 1 i
        local outV = getOutVec splineObj 1 i
        hashVal += pt.x * i + pt.y * (i * 2) + pt.z * (i * 3)
        hashVal += inV.x * (i * 0.1) + inV.y * (i * 0.2)
        hashVal += outV.x * (i * 0.3) + outV.y * (i * 0.4)
    )
    return hashVal
)

-- Cache entry structure for storing sampled curve data
struct AA_CacheEntry (
    splineObj,          -- Reference to the Spline object
    timeStamp,          -- Time when cache was built
    knotCount,          -- Number of knots for modification detection
    knotHash,           -- Hash from knot positions
    samplePoints,       -- Array of [x, y] sample points
    minX,               -- Minimum X value in curve
    maxX,               -- Maximum X value in curve
    isMonotonic,        -- Whether X values are monotonically increasing

    -- Check if cache is still valid
    fn isValid checkTime = (
        if this.splineObj == undefined do return false
        if not isValidNode this.splineObj do return false

        local currentKnotCount = numKnots this.splineObj 1
        local currentHash = AA_ComputeKnotHash this.splineObj
        local hashMatch = this.knotCount == currentKnotCount and this.knotHash == currentHash
        local timeMatch = this.timeStamp == checkTime

        return (hashMatch and timeMatch)
    )
)

-- # endregion

-- # region Cache Management

-- Find cache entry for a Spline object
fn AA_FindCache splineObj = (
    for cache in AA_SplineSampleCache do (
        if cache.splineObj == splineObj do return cache
    )
    return undefined
)

-- Remove cache entry for a Spline object
fn AA_RemoveCache splineObj = (
    local newCache = #()
    for cache in AA_SplineSampleCache do (
        if cache.splineObj != splineObj do append newCache cache
    )
    AA_SplineSampleCache = newCache
)

-- # endregion

-- # region Cache Building

-- Build sample cache for a Spline curve
-- Pre-samples the curve at regular intervals
--
-- Parameters:
--   splineObj: The SplineShape object to sample
--   numSamples: Number of sample points (default: AA_DEFAULT_SAMPLE_COUNT)
--
-- Returns:
--   AA_CacheEntry with sampled data
--
fn AA_BuildSampleCache splineObj numSamples:AA_DEFAULT_SAMPLE_COUNT = (

    local cacheTime = currentTime
    local samplePoints = #()

    -- Get knot info for cache validation
    local knotCount = numKnots splineObj 1
    local knotHash = AA_ComputeKnotHash splineObj

    -- Sample curve directly (fast, no copy needed)
    for i = 0 to numSamples do (
        local t = i as float / numSamples
        local worldPt = interpCurve3D splineObj 1 t
        local localPt = worldPt * (inverse splineObj.transform)
        append samplePoints [localPt.x, localPt.y]
    )

    -- Determine if curve is monotonic (X always increasing)
    local isMonotonic = true
    local prevX = samplePoints[1][1]
    for i = 2 to samplePoints.count do (
        if samplePoints[i][1] <= prevX do (
            isMonotonic = false
            exit
        )
        prevX = samplePoints[i][1]
    )

    -- Find min/max X values
    local minX = samplePoints[1][1]
    local maxX = samplePoints[1][1]
    for pt in samplePoints do (
        if pt[1] < minX do minX = pt[1]
        if pt[1] > maxX do maxX = pt[1]
    )

    -- Create cache entry
    local cacheEntry = AA_CacheEntry \
        splineObj:splineObj \
        timeStamp:cacheTime \
        knotCount:knotCount \
        knotHash:knotHash \
        samplePoints:samplePoints \
        minX:minX \
        maxX:maxX \
        isMonotonic:isMonotonic

    -- Update global cache
    AA_RemoveCache splineObj
    append AA_SplineSampleCache cacheEntry

    return cacheEntry
)

-- # endregion

-- # region Sampling Functions

-- Binary search for Y value at given X (for monotonic curves)
--
-- Parameters:
--   samplePoints: Array of [x, y] points
--   targetX: The X coordinate to find
--
-- Returns:
--   Interpolated Y value
--
fn AA_BinarySearchY samplePoints targetX = (
    local low = 1
    local high = samplePoints.count

    -- Binary search to find bracketing points
    while (high - low) > 1 do (
        local mid = (low + high) / 2
        if samplePoints[mid][1] <= targetX then
            low = mid
        else
            high = mid
    )

    -- Linear interpolation between bracketing points
    local x1 = samplePoints[low][1]
    local y1 = samplePoints[low][2]
    local x2 = samplePoints[high][1]
    local y2 = samplePoints[high][2]

    if (x2 - x1) < 0.0001 do return y1

    local t = (targetX - x1) / (x2 - x1)
    return y1 + t * (y2 - y1)
)

-- Linear search for Y value at given X (for non-monotonic curves)
-- Returns the first intersection found
--
-- Parameters:
--   samplePoints: Array of [x, y] points
--   targetX: The X coordinate to find
--
-- Returns:
--   Y value at closest X match
--
fn AA_LinearSearchY samplePoints targetX = (
    local closestDist = 1e9
    local closestY = 0.0

    for i = 1 to samplePoints.count - 1 do (
        local x1 = samplePoints[i][1]
        local x2 = samplePoints[i+1][1]

        -- Check if targetX is between these two points
        if (targetX >= x1 and targetX <= x2) or (targetX >= x2 and targetX <= x1) do (
            local y1 = samplePoints[i][2]
            local y2 = samplePoints[i+1][2]

            local range = x2 - x1
            if abs(range) < 0.0001 do (
                return y1
            )

            local t = (targetX - x1) / range
            return y1 + t * (y2 - y1)
        )
    )

    -- Fallback: find closest point
    for pt in samplePoints do (
        local dist = abs(pt[1] - targetX)
        if dist < closestDist do (
            closestDist = dist
            closestY = pt[2]
        )
    )

    return closestY
)

-- Get cached sample or rebuild cache if needed
--
-- Parameters:
--   splineObj: The SplineShape object
--
-- Returns:
--   AA_CacheEntry (valid cache)
--
fn AA_GetCachedSample splineObj = (
    local checkTime = currentTime
    local cache = AA_FindCache splineObj

    if cache == undefined or not cache.isValid checkTime do (
        cache = AA_BuildSampleCache splineObj
    )

    return cache
)

-- Sample Spline curve at given X coordinate
-- Main sampling function - returns Y value for given X
--
-- Parameters:
--   splineObj: The SplineShape object to sample
--   xValue: The X coordinate to sample at (typically 0-100)
--
-- Returns:
--   Y value from the curve at the given X position
--
fn AA_SampleSplineAtX splineObj xValue = (

    if splineObj == undefined do return 0.0
    if not isValidNode splineObj do return 0.0

    -- Get or build cache
    local cache = AA_GetCachedSample splineObj

    -- Clamp X to curve range
    local clampedX = xValue
    if clampedX < cache.minX do clampedX = cache.minX
    if clampedX > cache.maxX do clampedX = cache.maxX

    -- Use appropriate search algorithm
    local yValue = 0.0
    if cache.isMonotonic then (
        yValue = AA_BinarySearchY cache.samplePoints clampedX
    ) else (
        yValue = AA_LinearSearchY cache.samplePoints clampedX
    )

    return yValue
)

-- # endregion

-- # region Module Info

format "========================================\n"
format "Spline Curve Sampler Module Loaded\n"
format "========================================\n"

-- # endregion

