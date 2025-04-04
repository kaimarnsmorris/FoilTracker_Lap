// Optimized LapTracker.mc
using Toybox.System;
using Toybox.Math;

class LapTracker {
    // Constants
    private const UPWIND_THRESHOLD = 70;
    private const DOWNWIND_THRESHOLD = 110;

    // Core properties
    private var mParent;
    private var mCurrentLapNumber;
    private var mLastLapStartTime;
    
    // Collection containers - consolidate related data
    private var mLapManeuvers;
    private var mLapStats;
    private var mLapPositionData;
    private var mLapPointsData;  // Combined tracking data to reduce container count
    private var mLapDirectionData; // Combined direction data
    private var mLapDisplayManeuvers;  // Track display-only maneuver counts
    
    // Initialize with minimal setup
    function initialize(parent) {
        mParent = parent;
        reset();
    }

    // Reset with optimized container management
    function reset() {
        mCurrentLapNumber = 0;
        mLastLapStartTime = System.getTimer();
        
        // Use fewer containers with more structured data
        mLapManeuvers = {};
        mLapStats = {};
        mLapPositionData = {}; // Contains positions, timestamps, distances
        mLapPointsData = {};   // Contains all point counting data
        mLapDirectionData = {}; // Contains all direction/angle data
        mLapDisplayManeuvers = {};  // Contains display-only maneuver counts
        
        log("LapTracker reset - using optimized containers");
    }
    
    // Method to update maneuver counts for a specific lap
    function updateManeuverCounts(lapNumber, tackCount, displayTackCount, gybeCount, displayGybeCount) {
        if (lapNumber <= 0 || !mLapStats.hasKey(lapNumber)) {
            System.println("updateManeuverCounts: No lap stats for lap " + lapNumber);
            return false;
        }
        
        try {
            var stats = mLapStats[lapNumber];
            stats["tackCount"] = tackCount;
            stats["displayTackCount"] = displayTackCount;
            stats["gybeCount"] = gybeCount;
            stats["displayGybeCount"] = displayGybeCount;
            System.println("Updated maneuver counts for lap " + lapNumber);
            return true;
        } catch (e) {
            System.println("Error updating maneuver counts: " + e.getErrorMessage());
            return false;
        }
    }

    // Enhanced data tracking - store maxSpeed, max3sSpeed and calculate avgSpeed
    private var mLapSpeedData = {}; // Add this property to the class

    // Method to initialize speed tracking data for a lap
    // This should be called when a lap is created
    function initSpeedTracking(lapNumber) {
        if (lapNumber <= 0) { return; }
        
        mLapSpeedData[lapNumber] = {
            "speedSum" => 0.0,
            "speedPoints" => 0,
            "maxSpeed" => 0.0,
            "max3sSpeed" => 0.0
        };
        
        System.println("Initialized speed tracking for lap " + lapNumber);
    }

    // Method to update speed data for the current lap
    function updateSpeedData(speed, max3sSpeed) {
        var lapNumber = mCurrentLapNumber;
        if (lapNumber <= 0) { return; }
        
        // Ensure speed data container exists for this lap
        if (!mLapSpeedData.hasKey(lapNumber)) {
            initSpeedTracking(lapNumber);
        }
        
        var speedData = mLapSpeedData[lapNumber];
        
        // Update running totals
        speedData["speedSum"] += speed;
        speedData["speedPoints"]++;
        
        // Update max speed
        if (speed > speedData["maxSpeed"]) {
            speedData["maxSpeed"] = speed;
            
            // Also update the lap stats
            if (mLapStats.hasKey(lapNumber)) {
                mLapStats[lapNumber]["maxSpeed"] = speed;
            }
        }
        
        // Update max 3s speed
        if (max3sSpeed > speedData["max3sSpeed"]) {
            speedData["max3sSpeed"] = max3sSpeed;
            
            // Also update the lap stats
            if (mLapStats.hasKey(lapNumber)) {
                mLapStats[lapNumber]["max3sSpeed"] = max3sSpeed;
            }
        }
        
        // Calculate and update average speed
        if (speedData["speedPoints"] > 0) {
            var avgSpeed = speedData["speedSum"] / speedData["speedPoints"];
            
            // Update the lap stats
            if (mLapStats.hasKey(lapNumber)) {
                mLapStats[lapNumber]["avgSpeed"] = avgSpeed;
            }
        }
    }


    // Update for LapTracker.onLapMarked method
    function onLapMarked(position) {
        var prevLapNum = mCurrentLapNumber;
        mCurrentLapNumber++;
        var lapNum = mCurrentLapNumber;
        var currentTime = System.getTimer();
        var systemTime = Time.now().value();
        
        System.println("Marking lap " + lapNum + ", previous lap " + prevLapNum);
        System.println("Current time (ms): " + currentTime + ", System time: " + systemTime);
        
        if (prevLapNum > 0 && mLapPositionData.hasKey(prevLapNum)) {
            var prevLapStart = mLapPositionData[prevLapNum]["startTime"];
            var lapDuration = currentTime - prevLapStart;
            System.println("Previous lap start time: " + prevLapStart + ", duration: " + lapDuration + "ms");
        } else {
            System.println("First lap or no previous lap data");
        }
        
        // Store position data with the lap
        mLapPositionData[lapNum] = {
            "startPosition" => position,
            "startTime" => currentTime,
            "distance" => 0.0
        };
        
        if (position != null && position.position != null) {
            System.println("Lap " + lapNum + " position recorded: " + 
                        position.position[0] + "," + position.position[1]);
        } else {
            System.println("Lap " + lapNum + " has no position data");
        }
        
        System.println("New lap " + lapNum + " start time: " + currentTime);
        mLastLapStartTime = currentTime;
        
        // Initialize points data with a single container
        mLapPointsData[lapNum] = {
            "totalPoints" => 0,
            "foilingPoints" => 0,
            "upwindPoints" => 0,
            "downwindPoints" => 0,
            "reachingPoints" => 0,
            "vmgUpPoints" => 0,
            "vmgDownPoints" => 0
        };
        
        // Initialize direction data
        mLapDirectionData[lapNum] = {
            "windAngleSum" => 0,
            "windDirectionSum" => 0,
            "windDirectionPoints" => 0
        };
        
        // Initialize stats with speed metrics
        mLapStats[lapNum] = {
            "tackCount" => 0,
            "gybeCount" => 0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "maxTackAngle" => 0,
            "maxGybeAngle" => 0,
            "lapVMG" => 0.0,
            "pctOnFoil" => 0.0,
            "avgVMGUp" => 0.0,
            "avgVMGDown" => 0.0,
            "vmgUpTotal" => 0.0,
            "vmgDownTotal" => 0.0,
            "maxSpeed" => 0.0,
            "max3sSpeed" => 0.0,
            "avgSpeed" => 0.0
        };
        
        initSpeedTracking(lapNum);

        // Copy speed data from model if available
        var app = Application.getApp();
        if (app != null && app has :mModel && app.mModel != null) {
            var modelData = app.mModel.getData();
            if (modelData != null) {
                if (modelData.hasKey("maxSpeed")) {
                    mLapStats[lapNum]["maxSpeed"] = modelData["maxSpeed"];
                }
                
                if (modelData.hasKey("max3sSpeed")) {
                    mLapStats[lapNum]["max3sSpeed"] = modelData["max3sSpeed"];
                }
                
                // For average speed, we either use the model's avgSpeed or calculate our own
                if (modelData.hasKey("avgSpeed")) {
                    mLapStats[lapNum]["avgSpeed"] = modelData["avgSpeed"];
                } else if (modelData.hasKey("maxSpeed")) {
                    // Fallback calculation - roughly 70% of max speed
                    mLapStats[lapNum]["avgSpeed"] = modelData["maxSpeed"] * 0.7;
                }
            }
        }
        
        // Initialize maneuvers
        mLapManeuvers[lapNum] = {
            "tacks" => [],
            "gybes" => []
        };
        
        log("New lap marked: " + lapNum);
        return lapNum;
    }
    
    // Process position data with optimized container access
    function processData(info, speed, isUpwind, currentTime) {
        if (mCurrentLapNumber <= 0) { return; }
        
        var lapNum = mCurrentLapNumber;
        
        // Ensure all data containers exist for the current lap
        if (!mLapPointsData.hasKey(lapNum)) {
            mLapPointsData[lapNum] = {
                "totalPoints" => 0,
                "foilingPoints" => 0,
                "upwindPoints" => 0,
                "downwindPoints" => 0,
                "reachingPoints" => 0,
                "vmgUpPoints" => 0,
                "vmgDownPoints" => 0
            };
        }
        
        if (!mLapDirectionData.hasKey(lapNum)) {
            mLapDirectionData[lapNum] = {
                "windAngleSum" => 0,
                "windDirectionSum" => 0,
                "windDirectionPoints" => 0
            };
        }
        
        if (!mLapStats.hasKey(lapNum)) {
            mLapStats[lapNum] = {
                "tackCount" => 0,
                "gybeCount" => 0,
                "avgTackAngle" => 0,
                "avgGybeAngle" => 0,
                "maxTackAngle" => 0,
                "maxGybeAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0,
                "avgVMGUp" => 0.0,
                "avgVMGDown" => 0.0,
                "vmgUpTotal" => 0.0,
                "vmgDownTotal" => 0.0
            };
        }
        
        var pointsData = mLapPointsData[lapNum]; // Local reference
        var directionData = mLapDirectionData[lapNum]; // Local reference
        var stats = mLapStats[lapNum]; // Local reference
        
        // Fewer container/dictionary key lookups by using local references
        var isActive = true;
        var foilingThreshold = 7.0;
        
        // Consolidated settings check
        try {
            var app = Application.getApp();
            if (app != null && app has :mModel) {
                var data = app.mModel != null ? app.mModel.getData() : null;
                if (data != null) {
                    // Check settings and pause state in one consolidated check
                    var settings = data.hasKey("settings") ? data["settings"] : null;
                    foilingThreshold = (settings != null && settings.hasKey("foilingThreshold")) 
                        ? settings["foilingThreshold"] : foilingThreshold;
                    
                    isActive = !(data.hasKey("sessionPaused") && data["sessionPaused"]);
                }
            }
        } catch (e) {
            log("Settings error: " + e.getErrorMessage());
        }
        
        // Skip if not active
        if (!isActive) { return; }
        
        // Update point counters efficiently
        pointsData["totalPoints"]++;
        
        // Foiling check
        var isOnFoil = (speed >= foilingThreshold);
        if (isOnFoil) { pointsData["foilingPoints"]++; }
        
        // Get absolute wind angle once
        var windAngleLessCOG = (mParent != null && mParent.getAngleCalculator() != null) 
            ? mParent.getAngleCalculator().getWindAngleLessCOG() : 0;
        var absWindAngle = (windAngleLessCOG < 0) ? -windAngleLessCOG : windAngleLessCOG;
        
        // Update wind direction tracking
        var windDirection = (mParent != null) ? mParent.getWindDirection() : 0;
        directionData["windDirectionSum"] += windDirection;
        directionData["windDirectionPoints"]++;
        directionData["windAngleSum"] += absWindAngle;
        
        // Classify point of sail with single conditional
        if (absWindAngle <= UPWIND_THRESHOLD) {
            pointsData["upwindPoints"]++;
        } else if (absWindAngle >= DOWNWIND_THRESHOLD) {
            pointsData["downwindPoints"]++;
        } else {
            pointsData["reachingPoints"]++;
        }
        
        // Update VMG
        updateVMG(info, speed, isUpwind, lapNum);
        
        // Calculate percent on foil
        if (pointsData["totalPoints"] > 0) {
            stats["pctOnFoil"] = (pointsData["foilingPoints"] * 100.0) / pointsData["totalPoints"];
        }
    }
    
    // Simplified VMG handling
    function updateVMG(info, speed, isUpwind, lapNum) {
        if (!mLapStats.hasKey(lapNum) || !mLapPointsData.hasKey(lapNum)) {
            return;
        }
        
        // Get all needed data up front
        var absWindAngle = (mParent != null && mParent.getAngleCalculator() != null) 
            ? mParent.getAngleCalculator().getAbsWindAngle() : 0;
        var stats = mLapStats[lapNum];
        var pointsData = mLapPointsData[lapNum];
        
        // Calculate VMG
        var windAngleRad = 0.0;
        var vmg = 0.0;
        
        if (isUpwind) {
            // Upwind calculation
            windAngleRad = Math.toRadians(absWindAngle);
            vmg = speed * Math.cos(windAngleRad);
            vmg = vmg < 0 ? -vmg : vmg; // Ensure positive
            
            stats["vmgUpTotal"] += vmg;
            pointsData["vmgUpPoints"]++;
            
            // Calculate average upwind VMG
            if (pointsData["vmgUpPoints"] > 0) {
                stats["avgVMGUp"] = stats["vmgUpTotal"] / pointsData["vmgUpPoints"];
            }
        } else {
            // Downwind calculation
            windAngleRad = Math.toRadians(180 - absWindAngle);
            vmg = speed * Math.cos(windAngleRad);
            vmg = vmg < 0 ? -vmg : vmg; // Ensure positive
            
            stats["vmgDownTotal"] += vmg;
            pointsData["vmgDownPoints"]++;
            
            // Calculate average downwind VMG
            if (pointsData["vmgDownPoints"] > 0) {
                stats["avgVMGDown"] = stats["vmgDownTotal"] / pointsData["vmgDownPoints"];
            }
        }
        
        // Update position data if needed
        updatePositionData(info);
    }
    
    function updatePositionData(info) {
        var lapNum = mCurrentLapNumber;
        if (lapNum <= 0 || info == null || !mLapPositionData.hasKey(lapNum)) { 
            return; 
        }
        
        var posData = mLapPositionData[lapNum];
        
        // Skip if no start position and store current position as start
        if (posData["startPosition"] == null) {
            posData["startPosition"] = info;
            return;
        }
        
        try {
            // Get the position information
            var startPos = posData["startPosition"];
            var lat1 = null;
            var lon1 = null;
            var lat2 = null;
            var lon2 = null;
            
            // Try to extract latitude and longitude
            if (startPos has :position && info has :position && 
                startPos.position != null && info.position != null) {
                
                // Try different methods to get the position data
                try {
                    // First, try to access position as properties
                    if (startPos.position has :latitude && startPos.position has :longitude &&
                        info.position has :latitude && info.position has :longitude) {
                        lat1 = startPos.position.latitude;
                        lon1 = startPos.position.longitude;
                        lat2 = info.position.latitude;
                        lon2 = info.position.longitude;
                    }
                    // If that fails, try array access - but only if we have an array
                    else if (startPos.position has :size && info.position has :size) {
                        // Only access arrays if they have a size method and sufficient elements
                        if (startPos.position.size() >= 2 && info.position.size() >= 2) {
                            lat1 = startPos.position[0];
                            lon1 = startPos.position[1];
                            lat2 = info.position[0];
                            lon2 = info.position[1];
                        }
                    }
                    // Last resort - try direct array access without checking size
                    else if (startPos.position instanceof Array && info.position instanceof Array) {
                        // Just try direct access and let error handling catch any issues
                        lat1 = startPos.position[0];
                        lon1 = startPos.position[1];
                        lat2 = info.position[0];
                        lon2 = info.position[1];
                    }
                } catch (e) {
                    log("Position data extraction error: " + e.getErrorMessage());
                    // Continue without position data
                }
            }
            
            // If we have valid coordinates, calculate distance
            if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
                // Approximate distance using Pythagorean theorem
                var latDiff = lat2 - lat1;
                var lonDiff = lon2 - lon1;
                
                // Converting to approximate meters
                var latMeters = latDiff * 111320; // 1 degree lat is ~111.32 km
                var lonMeters = lonDiff * 111320 * Math.cos(Math.toRadians((lat1 + lat2) / 2));
                
                posData["distance"] = Math.sqrt(latMeters * latMeters + lonMeters * lonMeters);
                
                // Calculate lap VMG safely
                calculateLapVMG(info);
            }
        } catch (e) {
            log("Error in updatePositionData: " + e.getErrorMessage());
        }
    }

    // Updated calculateLapVMG method with improved safety checks
    function calculateLapVMG(info) {
        var lapNum = mCurrentLapNumber;
        if (lapNum <= 0 || info == null || !mLapPositionData.hasKey(lapNum) || !mLapStats.hasKey(lapNum)) {
            return;
        }
        
        var posData = mLapPositionData[lapNum];
        var stats = mLapStats[lapNum];
        
        // Skip if no valid distance
        if (!posData.hasKey("distance") || posData["distance"] <= 0) {
            return;
        }
        
        try {
            // Calculate time elapsed
            var startTime = posData.hasKey("startTime") ? posData["startTime"] : mLastLapStartTime;
            var elapsedTimeHours = (System.getTimer() - startTime) / (1000.0 * 60.0 * 60.0);
            
            // Skip VMG calculation if elapsed time is too small
            if (elapsedTimeHours < 0.001) {
                return;
            }
            
            // Calculate bearing
            var bearing = 0.0;
            var startPos = posData["startPosition"];
            
            // Try to calculate bearing if we have valid position data
            if (startPos != null && info != null && 
                startPos has :position && info has :position && 
                startPos.position != null && info.position != null) {
                
                var lat1 = null;
                var lon1 = null;
                var lat2 = null;
                var lon2 = null;
                
                // Extract coordinates safely
                try {
                    // Try array access
                    if (startPos.position.size() >= 2 && info.position.size() >= 2) {
                        lat1 = startPos.position[0];
                        lon1 = startPos.position[1];
                        lat2 = info.position[0];
                        lon2 = info.position[1];
                    }
                } catch (e) {
                    // Try property access
                    if (startPos.position has :latitude && startPos.position has :longitude &&
                        info.position has :latitude && info.position has :longitude) {
                        lat1 = startPos.position.latitude;
                        lon1 = startPos.position.longitude;
                        lat2 = info.position.latitude;
                        lon2 = info.position.longitude;
                    }
                }
                
                // Calculate bearing if coordinates are valid
                if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
                    var lonDiff = lon2 - lon1;
                    bearing = Math.toDegrees(Math.atan2(lonDiff, lat2 - lat1));
                    if (bearing < 0) {
                        bearing += 360;
                    }
                }
            }
            
            // Calculate projection onto wind direction
            if (mParent != null) {
                var windDirRadians = Math.toRadians(mParent.getWindDirection());
                var bearingRadians = Math.toRadians(bearing);
                
                // Component of travel in direction of wind
                var distance = posData["distance"];
                var distanceToWind = distance * Math.cos(bearingRadians - windDirRadians);
                
                // If going upwind, we want to go against the wind, so negate
                if (mParent.getAngleCalculator() != null && mParent.getAngleCalculator().isUpwind()) {
                    distanceToWind = -distanceToWind;
                }
                
                // Convert from meters to nautical miles (1 nm = 1852 meters)
                var distanceNM = distanceToWind / 1852.0;
                
                // Calculate VMG in knots (nautical miles per hour)
                var lapVMG = distanceNM / elapsedTimeHours;
                
                // Update lap stats with this VMG
                stats["lapVMG"] = lapVMG;
            }
        } catch (e) {
            log("Error in calculateLapVMG: " + e.getErrorMessage());
        }
    }
    
    function getLapPositionData(lapNumber) {
    if (lapNumber > 0 && mLapPositionData.hasKey(lapNumber)) {
        return mLapPositionData[lapNumber];
    }
    return null;
}

    // Update for LapTracker.getLapData method
    function getLapData() {
        var lapNum = mCurrentLapNumber;
        
        // Return default data if no laps yet
        if (lapNum <= 0) {
            return createDefaultLapData();
        }
        
        // Create a safe return object with defaults
        var lapData = createDefaultLapData();
        
        try {
            // Safely get all needed data sources with null checks
            if (mLapStats.hasKey(lapNum)) {
                var stats = mLapStats[lapNum];
                if (stats != null) {
                    // Safely copy stats values
                    if (stats.hasKey("avgVMGUp")) { lapData["vmgUp"] = stats["avgVMGUp"]; }
                    if (stats.hasKey("avgVMGDown")) { lapData["vmgDown"] = stats["avgVMGDown"]; }
                    if (stats.hasKey("avgTackAngle")) { lapData["avgTackAngle"] = stats["avgTackAngle"]; }
                    if (stats.hasKey("avgGybeAngle")) { lapData["avgGybeAngle"] = stats["avgGybeAngle"]; }
                    if (stats.hasKey("lapVMG")) { lapData["lapVMG"] = stats["lapVMG"]; }
                    if (stats.hasKey("pctOnFoil")) { lapData["pctOnFoil"] = stats["pctOnFoil"]; }
                    
                    // Include speed metrics
                    if (stats.hasKey("maxSpeed")) { lapData["maxSpeed"] = stats["maxSpeed"]; }
                    if (stats.hasKey("max3sSpeed")) { lapData["max3sSpeed"] = stats["max3sSpeed"]; }
                    if (stats.hasKey("avgSpeed")) { lapData["avgSpeed"] = stats["avgSpeed"]; }
                }
            }
            
            // Add time since last tack
            lapData["tackSec"] = getTimeSinceLastTack();
            
            // Get position data safely
            if (mLapPositionData.hasKey(lapNum) && mLapPositionData[lapNum] != null) {
                var posData = mLapPositionData[lapNum];
                if (posData.hasKey("distance")) {
                    lapData["tackMtr"] = posData["distance"];
                }
                if (posData.hasKey("startTime")) {
                    lapData["startTime"] = posData["startTime"];
                }
            }
            
            // Get point data safely
            if (mLapPointsData.hasKey(lapNum) && mLapPointsData[lapNum] != null) {
                var pointsData = mLapPointsData[lapNum];
                lapData["pctUpwind"] = calculatePctUpwind(pointsData);
                lapData["pctDownwind"] = calculatePctDownwind(pointsData);
            }
            
            // Get direction data safely
            if (mLapDirectionData.hasKey(lapNum) && mLapDirectionData[lapNum] != null) {
                var dirData = mLapDirectionData[lapNum];
                lapData["windDirection"] = calculateAvgWindDirection(dirData);
                lapData["avgWindAngle"] = calculateAvgWindAngle(dirData, mLapPointsData[lapNum]);
            }
            
            // Get wind strength safely
            lapData["windStrength"] = getWindStrength();
            
            // Get tack/gybe counts safely
            if (mLapDisplayManeuvers != null && mLapDisplayManeuvers.hasKey(lapNum)) {
                lapData["tackCount"] = mLapDisplayManeuvers[lapNum]["displayTackCount"];
                lapData["gybeCount"] = mLapDisplayManeuvers[lapNum]["displayGybeCount"];
            }
        } catch (e) {
            System.println("Error in getLapData: " + e.getErrorMessage());
            // Return default data when we hit an error
            return createDefaultLapData();
        }
        
        // Round all values once
        return roundLapData(lapData);
    }
    
    // Helper functions for lap data
    
    // Update for LapTracker.createDefaultLapData method
    function createDefaultLapData() {
        return {
            "vmgUp" => 0.0,
            "vmgDown" => 0.0,
            "tackSec" => 0.0,
            "tackMtr" => 0.0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "lapVMG" => 0.0,
            "pctOnFoil" => 0.0,
            "windDirection" => 0,
            "windStrength" => 0,
            "pctUpwind" => 0,
            "pctDownwind" => 0,
            "avgWindAngle" => 0,
            "tackCount" => 0,
            "gybeCount" => 0,
            "maxSpeed" => 0.0,
            "max3sSpeed" => 0.0,
            "avgSpeed" => 0.0,
            "startTime" => System.getTimer()
        };
    }
    
    // Safer calculation helpers
    function calculatePctUpwind(pointsData) {
        if (pointsData == null || !pointsData.hasKey("totalPoints") || pointsData["totalPoints"] == 0) { 
            return 0; 
        }
        
        var upwindPoints = pointsData.hasKey("upwindPoints") ? pointsData["upwindPoints"] : 0;
        var totalPoints = pointsData["totalPoints"];
        
        return Math.round((upwindPoints * 100.0) / totalPoints).toNumber();
    }
    
    function calculatePctDownwind(pointsData) {
        if (pointsData == null || !pointsData.hasKey("totalPoints") || pointsData["totalPoints"] == 0) { 
            return 0; 
        }
        
        var downwindPoints = pointsData.hasKey("downwindPoints") ? pointsData["downwindPoints"] : 0;
        var totalPoints = pointsData["totalPoints"];
        
        return Math.round((downwindPoints * 100.0) / totalPoints).toNumber();
    }
    
    function calculateAvgWindDirection(dirData) {
        if (dirData == null || !dirData.hasKey("windDirectionPoints") || dirData["windDirectionPoints"] <= 0) {
            return mParent != null ? mParent.getWindDirection() : 0;
        }
        
        var sum = dirData.hasKey("windDirectionSum") ? dirData["windDirectionSum"] : 0;
        var count = dirData["windDirectionPoints"];
        
        return Math.round(sum / count).toNumber();
    }
    
    function calculateAvgWindAngle(dirData, pointsData) {
        if (dirData == null || pointsData == null || 
            !pointsData.hasKey("totalPoints") || pointsData["totalPoints"] == 0) { 
            return 0; 
        }
        
        var sum = dirData.hasKey("windAngleSum") ? dirData["windAngleSum"] : 0;
        var count = pointsData["totalPoints"];
        
        return Math.round(sum / count).toNumber();
    }
    
    // Efficiently round all values in one function
    function roundLapData(lapData) {
        try {
            lapData["vmgUp"] = Math.round(lapData["vmgUp"] * 10) / 10.0;
            lapData["vmgDown"] = Math.round(lapData["vmgDown"] * 10) / 10.0;
            lapData["tackSec"] = Math.round(lapData["tackSec"] * 10) / 10.0;
            lapData["tackMtr"] = Math.round(lapData["tackMtr"] * 10) / 10.0;
            lapData["lapVMG"] = Math.round(lapData["lapVMG"] * 10) / 10.0;
            lapData["pctOnFoil"] = Math.round(lapData["pctOnFoil"]);
            lapData["avgWindAngle"] = Math.round(lapData["avgWindAngle"]);
            lapData["windDirection"] = Math.round(lapData["windDirection"]);
            lapData["pctUpwind"] = Math.round(lapData["pctUpwind"]);
            lapData["pctDownwind"] = Math.round(lapData["pctDownwind"]);
        } catch (e) {
            log("Error rounding lap data: " + e.getErrorMessage());
        }
        
        return lapData;
    }
    
    function getWindStrength() {
        var windStrength = 0;
        try {
            var app = Application.getApp();
            if (app != null && app has :mModel && app.mModel != null) {
                var data = app.mModel.getData();
                if (data != null && data.hasKey("windStrengthIndex")) {
                    windStrength = data["windStrengthIndex"];
                }
            }
        } catch (e) {
            log("Error getting wind strength: " + e.getErrorMessage());
        }
        return windStrength;
    }
    
    // Simplified time since last tack calculation
    function getTimeSinceLastTack() {
        var lapNum = mCurrentLapNumber;
        if (lapNum <= 0 || !mLapManeuvers.hasKey(lapNum)) {
            return 0.0;
        }
        
        var tackArray = mLapManeuvers[lapNum]["tacks"];
        if (tackArray == null || tackArray.size() == 0) {
            // If no tacks in lap, return time since lap start
            return (System.getTimer() - mLastLapStartTime) / 1000.0;
        }
        
        // Get timestamp of last tack
        var lastTackTimestamp = tackArray[tackArray.size() - 1]["timestamp"];
        
        // Return seconds since last tack
        return (System.getTimer() - lastTackTimestamp) / 1000.0;
    }
    
    // Record maneuvers in lap
    function recordManeuverInLap(maneuver) {
        var lapNumber = maneuver["lapNumber"];
        if (lapNumber <= 0 || !mLapManeuvers.hasKey(lapNumber)) {
            return;
        }
        
        var isTack = maneuver["isTack"];
        var isReliable = maneuver.hasKey("isReliable") ? maneuver["isReliable"] : true;
        var collection = isTack ? "tacks" : "gybes";
        
        // Only add reliable maneuvers to collection for angle calculations
        if (isReliable) {
            // Add to collection
            mLapManeuvers[lapNumber][collection].add(maneuver);
            
            // Update stats immediately
            updateLapManeuverStats(lapNumber);
        }
        
        // Always update display counts
        if (!mLapDisplayManeuvers.hasKey(lapNumber)) {
            mLapDisplayManeuvers[lapNumber] = {
                "displayTackCount" => 0,
                "displayGybeCount" => 0
            };
        }
        
        // Increment the appropriate display counter
        if (isTack) {
            mLapDisplayManeuvers[lapNumber]["displayTackCount"]++;
        } else {
            mLapDisplayManeuvers[lapNumber]["displayGybeCount"]++;
        }
    }
    
    // Update maneuver stats more efficiently
    function updateLapManeuverStats(lapNumber) {
        if (!mLapManeuvers.hasKey(lapNumber) || !mLapStats.hasKey(lapNumber)) {
            return;
        }
        
        try {
            var stats = mLapStats[lapNumber];
            var maneuvers = mLapManeuvers[lapNumber];
            
            var tackArray = maneuvers["tacks"];
            var gybeArray = maneuvers["gybes"];
            
            // Update tack stats
            var tackCount = tackArray.size();
            var tackSum = 0;
            var maxTack = 0;
            
            for (var i = 0; i < tackCount; i++) {
                var angle = tackArray[i]["angle"];
                tackSum += angle;
                if (angle > maxTack) { maxTack = angle; }
            }
            
            // Update gybe stats
            var gybeCount = gybeArray.size();
            var gybeSum = 0;
            var maxGybe = 0;
            
            for (var i = 0; i < gybeCount; i++) {
                var angle = gybeArray[i]["angle"];
                gybeSum += angle;
                if (angle > maxGybe) { maxGybe = angle; }
            }
            
            // Update all stats at once
            stats["tackCount"] = tackCount;
            stats["gybeCount"] = gybeCount;
            stats["avgTackAngle"] = tackCount > 0 ? tackSum / tackCount : 0;
            stats["avgGybeAngle"] = gybeCount > 0 ? gybeSum / gybeCount : 0;
            stats["maxTackAngle"] = maxTack;
            stats["maxGybeAngle"] = maxGybe;
        } catch (e) {
            log("Error updating lap maneuver stats: " + e.getErrorMessage());
        }
    }
    
    // Accessors
    function getCurrentLap() {
        return mCurrentLapNumber;
    }
    
    // Add this method to LapTracker.mc to update maneuver angles
    function updateManeuverAngles(lapNumber, avgTackAngle, avgGybeAngle, maxTackAngle, maxGybeAngle) {
        if (lapNumber <= 0 || !mLapStats.hasKey(lapNumber)) {
            System.println("updateManeuverAngles: No lap stats for lap " + lapNumber);
            return false;
        }
        
        try {
            var stats = mLapStats[lapNumber];
            stats["avgTackAngle"] = avgTackAngle;
            stats["avgGybeAngle"] = avgGybeAngle;
            stats["maxTackAngle"] = maxTackAngle;
            stats["maxGybeAngle"] = maxGybeAngle;
            System.println("Updated maneuver angles for lap " + lapNumber + 
                        " - avgTack: " + avgTackAngle + 
                        ", avgGybe: " + avgGybeAngle);
            return true;
        } catch (e) {
            System.println("Error updating maneuver angles: " + e.getErrorMessage());
            return false;
        }
    }


    // Update the getLapStats method in LapTracker.mc to ensure it uses our tracked data

    function getLapStats(lapNumber) {
        if (lapNumber <= 0 || !mLapStats.hasKey(lapNumber)) {
            System.println("getLapStats: No data for lap " + lapNumber);
            return null;
        }
        
        System.println("getLapStats: Fetching data for lap " + lapNumber);
        
        // Start with the base stats we already have
        var stats = mLapStats[lapNumber];
        
        // Add speed data from our tracked values
        if (mLapSpeedData.hasKey(lapNumber)) {
            var speedData = mLapSpeedData[lapNumber];
            
            // Ensure max and max3s speeds are included
            if (speedData.hasKey("maxSpeed")) {
                stats["maxSpeed"] = speedData["maxSpeed"];
            }
            
            if (speedData.hasKey("max3sSpeed")) {
                stats["max3sSpeed"] = speedData["max3sSpeed"];
            }
            
            // Calculate and include average speed
            if (speedData.hasKey("speedSum") && speedData.hasKey("speedPoints") && 
                speedData["speedPoints"] > 0) {
                stats["avgSpeed"] = speedData["speedSum"] / speedData["speedPoints"];
            }
        }
        
        // Add tack/gybe counts from ManeuverDetector if needed
        if (mParent != null && mParent.getManeuverDetector() != null) {
            var maneuverData = mParent.getManeuverDetector().getData();
            
            // Only update if not already set
            if (!stats.hasKey("tackCount") || stats["tackCount"] == 0) {
                stats["tackCount"] = maneuverData["lapDisplayTackCount"];
            }
            
            if (!stats.hasKey("displayTackCount") || stats["displayTackCount"] == 0) {
                stats["displayTackCount"] = maneuverData["displayTackCount"];
            }
            
            if (!stats.hasKey("gybeCount") || stats["gybeCount"] == 0) {
                stats["gybeCount"] = maneuverData["lapDisplayGybeCount"];
            }
            
            if (!stats.hasKey("displayGybeCount") || stats["displayGybeCount"] == 0) {
                stats["displayGybeCount"] = maneuverData["displayGybeCount"];
            }
        }
        
        // Add current point of sail information
        if (mParent != null && mParent.getAngleCalculator() != null) {
            stats["isUpwind"] = mParent.getAngleCalculator().isUpwind();
        }
        
        // Add VMG data
        if (mParent != null && mParent.getVMGCalculator() != null) {
            var vmgCalculator = mParent.getVMGCalculator();
            var vmgData = vmgCalculator.getData();
            if (vmgData != null) {
                var currentVMG = vmgData["currentVMG"];
                
                // Assign to correct field based on point of sail
                if (mParent.getAngleCalculator() != null) {
                    var isUpwind = mParent.getAngleCalculator().isUpwind();
                    if (isUpwind) {
                        stats["vmgUp"] = currentVMG;
                    } else {
                        stats["vmgDown"] = currentVMG;
                    }
                }
            }
        }
        
        // Add model data for percentage on foil
        try {
            var app = Application.getApp();
            var modelData = null;
            
            // Use the app's modelData getter if available
            if (app has :getModelData) {
                modelData = app.getModelData();
            }
            
            if (modelData != null && modelData.hasKey("percentOnFoil")) {
                stats["pctOnFoil"] = modelData["percentOnFoil"];
            }
        } catch (e) {
            System.println("Error getting model data: " + e.getErrorMessage());
        }
        
        // Make sure position data is included
        if (mLapPositionData.hasKey(lapNumber)) {
            var posData = mLapPositionData[lapNumber];
            stats["startTime"] = posData["startTime"];
            if (posData.hasKey("distance")) {
                stats["tackMtr"] = posData["distance"];
            }
        }
        
        // Debug output of the enhanced stats
        System.println("Enhanced getLapStats for lap " + lapNumber + ":");
        System.println("  - tackCount: " + stats["tackCount"]);
        System.println("  - gybeCount: " + stats["gybeCount"]);
        if (stats.hasKey("pctOnFoil")) {
            System.println("  - pctOnFoil: " + stats["pctOnFoil"]);
        }
        if (stats.hasKey("maxSpeed")) {
            System.println("  - maxSpeed: " + stats["maxSpeed"]);
        }
        if (stats.hasKey("max3sSpeed")) {
            System.println("  - max3sSpeed: " + stats["max3sSpeed"]);
        }
        if (stats.hasKey("avgSpeed")) {
            System.println("  - avgSpeed: " + stats["avgSpeed"]);
        }
        if (stats.hasKey("vmgUp")) {
            System.println("  - vmgUp: " + stats["vmgUp"]);
        }
        if (stats.hasKey("vmgDown")) {
            System.println("  - vmgDown: " + stats["vmgDown"]);
        }
        
        return stats;
    }
}