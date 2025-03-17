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
        
        log("LapTracker reset - using optimized containers");
    }
    
    // More efficient lap marking
    function onLapMarked(position) {
        mCurrentLapNumber++;
        var lapNum = mCurrentLapNumber; // Local variable for better performance
        var currentTime = System.getTimer();
        
        // Initialize position data
        mLapPositionData[lapNum] = {
            "startPosition" => position,
            "startTime" => currentTime,
            "distance" => 0.0
        };
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
        
        // Initialize VMG data directly in stats
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
        var windAngleLessCOG = mParent.getAngleCalculator().getWindAngleLessCOG();
        var absWindAngle = (windAngleLessCOG < 0) ? -windAngleLessCOG : windAngleLessCOG;
        
        // Update wind direction tracking
        var windDirection = mParent.getWindDirection();
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
        stats["pctOnFoil"] = (pointsData["foilingPoints"] * 100.0) / pointsData["totalPoints"];
    }
    
    // Simplified VMG handling
    function updateVMG(info, speed, isUpwind, lapNum) {
        // Get all needed data up front
        var absWindAngle = mParent.getAngleCalculator().getAbsWindAngle();
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
    
    // In LapTracker.mc
 // In LapTracker.mc
    // Updated updatePositionData method with proper error handling for Garmin devices
    function updatePositionData(info) {
        var lat1 = null;
        var lon1 = null;
        var lat2 = null;
        var lon2 = null;
        var lapNum = mCurrentLapNumber;
        if (lapNum <= 0 || info == null) { return; }
        
        // Safety check - make sure we have the lapNum key in the dictionary
        if (!mLapPositionData.hasKey(lapNum)) {
            mLapPositionData[lapNum] = {
                "startPosition" => null,
                "startTime" => System.getTimer(),
                "distance" => 0.0
            };
        }
        
        var posData = mLapPositionData[lapNum];
        
        // Skip if no start position and store current position as start
        if (posData["startPosition"] == null) {
            posData["startPosition"] = info;
            return;
        }
        
        // Make sure both positions have the required data before calculating
        var startPos = posData["startPosition"];
        
        // Safety check before position calculations - with safe property access
        try {
            // Check if position property exists and is not null
            if (info has :position && startPos has :position && 
                info.position != null && startPos.position != null) {
                
                // Extract latitude and longitude directly from the position objects
                // According to Garmin docs, position is accessed with individual lat/lon properties               
                // Try direct array access first (some devices provide position as array)
                try {
                    if (startPos.position[0] != null && startPos.position[1] != null &&
                        info.position[0] != null && info.position[1] != null) {
                        lat1 = startPos.position[0];
                        lon1 = startPos.position[1];
                        lat2 = info.position[0];
                        lon2 = info.position[1];
                    }
                } catch (e) {
                    // If array access fails, try accessing as lat/lon properties
                    if (startPos.position has :latitude && startPos.position has :longitude &&
                        info.position has :latitude && info.position has :longitude) {
                        lat1 = startPos.position.latitude;
                        lon1 = startPos.position.longitude;
                        lat2 = info.position.latitude;
                        lon2 = info.position.longitude;
                    }
                }
                
                // Calculate distance only if we have valid coordinates
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
            }
        } catch (e) {
            log("Error calculating position: " + e.getErrorMessage());
        }
    }

    // Updated calculateLapVMG method with improved safety checks
    function calculateLapVMG(info) {
        var lat1 = null;
        var lon1 = null;
        var lat2 = null;
        var lon2 = null;
        var lapNum = mCurrentLapNumber;
        if (lapNum <= 0 || info == null || !mLapPositionData.hasKey(lapNum)) {
            return;
        }
        
        var posData = mLapPositionData[lapNum];
        if (!mLapStats.hasKey(lapNum)) {
            return;
        }
        
        var stats = mLapStats[lapNum];
        
        // Skip if no valid distance
        if (!posData.hasKey("distance") || posData["distance"] <= 0) {
            return;
        }
        
        // Calculate time elapsed
        var startTime = posData.hasKey("startTime") ? posData["startTime"] : mLastLapStartTime;
        var elapsedTimeHours = (System.getTimer() - startTime) / (1000.0 * 60.0 * 60.0);
        
        // Skip VMG calculation if elapsed time is too small
        if (elapsedTimeHours < 0.001) {
            return;
        }
        
        // Try to get bearing
        var bearing = 0.0;
        
        // Calculate bearing safely with comprehensive validation
        try {
            var startPos = posData["startPosition"];
            
            // Check if position exists and has required data
            if (info has :position && startPos has :position && 
                info.position != null && startPos.position != null) {

                
                // Try direct array access first
                try {
                    if (startPos.position[0] != null && startPos.position[1] != null &&
                        info.position[0] != null && info.position[1] != null) {
                        lat1 = startPos.position[0];
                        lon1 = startPos.position[1];
                        lat2 = info.position[0];
                        lon2 = info.position[1];
                    }
                } catch (e) {
                    // If array access fails, try accessing as lat/lon properties
                    if (startPos.position has :latitude && startPos.position has :longitude &&
                        info.position has :latitude && info.position has :longitude) {
                        lat1 = startPos.position.latitude;
                        lon1 = startPos.position.longitude;
                        lat2 = info.position.latitude;
                        lon2 = info.position.longitude;
                    }
                }
                
                // Calculate bearing only if coordinates are valid
                if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
                    // Calculate bearing
                    var lonDiff = lon2 - lon1;
                    bearing = Math.toDegrees(Math.atan2(lonDiff, lat2 - lat1));
                    if (bearing < 0) {
                        bearing += 360;
                    }
                }
            }
        } catch (e) {
            log("Error calculating bearing: " + e.getErrorMessage());
            bearing = 0.0;
        }
        
        // Calculate projection onto wind direction
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
    
    // Efficiently get lap data
    function getLapData() {
        var lapNum = mCurrentLapNumber;
        if (lapNum <= 0) {
            return createDefaultLapData();
        }
        
        // Get all needed data sources
        var stats = mLapStats[lapNum];
        var pointsData = mLapPointsData[lapNum];
        var dirData = mLapDirectionData[lapNum];
        var posData = mLapPositionData[lapNum];
        
        // Create return object all at once
        var lapData = {
            "vmgUp" => stats.hasKey("avgVMGUp") ? stats["avgVMGUp"] : 0.0,
            "vmgDown" => stats.hasKey("avgVMGDown") ? stats["avgVMGDown"] : 0.0,
            "tackSec" => getTimeSinceLastTack(),
            "tackMtr" => posData.hasKey("distance") ? posData["distance"] : 0.0,
            "avgTackAngle" => stats.hasKey("avgTackAngle") ? stats["avgTackAngle"] : 0,
            "avgGybeAngle" => stats.hasKey("avgGybeAngle") ? stats["avgGybeAngle"] : 0,
            "lapVMG" => stats.hasKey("lapVMG") ? stats["lapVMG"] : 0.0,
            "pctOnFoil" => stats.hasKey("pctOnFoil") ? stats["pctOnFoil"] : 0.0,
            "tackCount" => stats.hasKey("tackCount") ? stats["tackCount"] : 0,
            "gybeCount" => stats.hasKey("gybeCount") ? stats["gybeCount"] : 0,
            "windDirection" => calculateAvgWindDirection(dirData),
            "windStrength" => getWindStrength(),
            "pctUpwind" => calculatePctUpwind(pointsData),
            "pctDownwind" => calculatePctDownwind(pointsData),
            "avgWindAngle" => calculateAvgWindAngle(dirData, pointsData)
        };
        
        // Round all values once
        return roundLapData(lapData);
    }
    
    // Helper functions for lap data - split for better maintainability
    function createDefaultLapData() {
        return {
            "vmgUp" => 0.0, "vmgDown" => 0.0, "tackSec" => 0.0, "tackMtr" => 0.0,
            "avgTackAngle" => 0, "avgGybeAngle" => 0, "lapVMG" => 0.0, "pctOnFoil" => 0.0,
            "windDirection" => 0, "windStrength" => 0, "pctUpwind" => 0, "pctDownwind" => 0,
            "avgWindAngle" => 0, "tackCount" => 0, "gybeCount" => 0
        };
    }
    
    function calculateAvgWindDirection(dirData) {
        if (dirData != null && dirData.hasKey("windDirectionPoints") && dirData["windDirectionPoints"] > 0) {
            return Math.round(dirData["windDirectionSum"] / dirData["windDirectionPoints"]).toNumber();
        }
        return mParent.getWindDirection();
    }
    
    function calculatePctUpwind(pointsData) {
        if (pointsData == null || pointsData["totalPoints"] == 0) { return 0; }
        return Math.round((pointsData["upwindPoints"] * 100.0) / pointsData["totalPoints"]).toNumber();
    }
    
    function calculatePctDownwind(pointsData) {
        if (pointsData == null || pointsData["totalPoints"] == 0) { return 0; }
        return Math.round((pointsData["downwindPoints"] * 100.0) / pointsData["totalPoints"]).toNumber();
    }
    
    function calculateAvgWindAngle(dirData, pointsData) {
        if (dirData == null || pointsData == null || pointsData["totalPoints"] == 0) { return 0; }
        return Math.round(dirData["windAngleSum"] / pointsData["totalPoints"]).toNumber();
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
    
    // Efficiently round all values in one function
    function roundLapData(lapData) {
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
        
        return lapData;
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
    
    // Accessors
    function getCurrentLap() {
        return mCurrentLapNumber;
    }
    
    function getLapStats(lapNumber) {
        if (lapNumber > 0 && mLapStats.hasKey(lapNumber)) {
            return mLapStats[lapNumber];
        }
        return null;
    }
    
    // Record maneuvers efficiently
    function recordManeuverInLap(maneuver) {
        var lapNumber = maneuver["lapNumber"];
        if (lapNumber <= 0 || !mLapManeuvers.hasKey(lapNumber)) {
            return;
        }
        
        var isTack = maneuver["isTack"];
        var collection = isTack ? "tacks" : "gybes";
        
        // Add to collection
        mLapManeuvers[lapNumber][collection].add(maneuver);
        
        // Update stats immediately
        updateLapManeuverStats(lapNumber);
    }
    
    // Update maneuver stats more efficiently
    function updateLapManeuverStats(lapNumber) {
        if (!mLapManeuvers.hasKey(lapNumber) || !mLapStats.hasKey(lapNumber)) {
            return;
        }
        
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
    }
}