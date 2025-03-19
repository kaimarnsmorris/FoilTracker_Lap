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
    
    // More efficient lap marking
    function onLapMarked(position) {
        var prevLapNum = mCurrentLapNumber;
        mCurrentLapNumber++;
        var lapNum = mCurrentLapNumber;
        var currentTime = System.getTimer();
        var systemTime = Time.now().value();
        
        System.println("DEBUG-LAP: Marking lap " + lapNum + ", previous lap " + prevLapNum);
        System.println("DEBUG-LAP: Current time (ms): " + currentTime + ", System time: " + systemTime);
        
        if (prevLapNum > 0 && mLapPositionData.hasKey(prevLapNum)) {
            var prevLapStart = mLapPositionData[prevLapNum]["startTime"];
            var lapDuration = currentTime - prevLapStart;
            System.println("DEBUG-LAP: Previous lap start time: " + prevLapStart + ", duration: " + lapDuration + "ms");
        } else {
            System.println("DEBUG-LAP: First lap or no previous lap data");
        }
        
        // Initialize position data
        mLapPositionData[lapNum] = {
            "startPosition" => position,
            "startTime" => currentTime,
            "distance" => 0.0
        };
        
        System.println("DEBUG-LAP: New lap " + lapNum + " start time: " + currentTime);
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
    
    // Update getLapData to better handle type errors
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
    
    // Create default lap data with proper types
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
            "gybeCount" => 0
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
    
    function getLapStats(lapNumber) {
        if (lapNumber > 0 && mLapStats.hasKey(lapNumber)) {
            return mLapStats[lapNumber];
        }
        return null;
    }
}