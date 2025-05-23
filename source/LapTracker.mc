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

    private var mLapSpeedData = {}; // Add this property to the class


    
    // Fixed initialization for LapTracker
    function initialize(parent) {
        mParent = parent;
        reset();
    }

    // Improved reset function with proper initialization of all data structures
    function reset() {
        mCurrentLapNumber = 0;
        mLastLapStartTime = System.getTimer();
        
        // Use fewer containers with more structured data - initialize all properly
        mLapManeuvers = {};
        mLapStats = {};
        mLapPositionData = {}; // Contains positions, timestamps, distances
        mLapPointsData = {};   // Contains all point counting data
        mLapDirectionData = {}; // Contains all direction/angle data
        mLapSpeedData = {};    // Contains speed tracking data
        
        // Initialize first lap data structures (lap 1)
        // This is crucial to prevent null references when first data arrives
        mLapManeuvers[1] = {
            "tacks" => [],
            "gybes" => []
        };
        
        mLapStats[1] = {
            "tackCount" => 0,
            "gybeCount" => 0,
            "displayTackCount" => 0,
            "displayGybeCount" => 0,
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
        
        mLapPositionData[1] = {
            "startPosition" => null,
            "startTime" => System.getTimer(),
            "distance" => 0.0
        };
        
        mLapPointsData[1] = {
            "totalPoints" => 0,
            "foilingPoints" => 0,
            "upwindPoints" => 0,
            "downwindPoints" => 0,
            "reachingPoints" => 0,
            "vmgUpPoints" => 0,
            "vmgDownPoints" => 0
        };
        
        mLapDirectionData[1] = {
            "windAngleSum" => 0,
            "windDirectionSum" => 0,
            "windDirectionPoints" => 0
        };
        
        // Initialize speed tracking for lap 1
        initSpeedTracking(1);
        
        log("LapTracker reset - using optimized containers");
    }

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
            System.println("Updated maneuver counts for lap " + lapNumber + 
                        ": tackCount=" + tackCount + 
                        ", displayTackCount=" + displayTackCount + 
                        ", gybeCount=" + gybeCount + 
                        ", displayGybeCount=" + displayGybeCount);
            return true;
        } catch (e) {
            System.println("Error updating maneuver counts: " + e.getErrorMessage());
            return false;
        }
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


    // Modified function to store actual clock time
    function onLapMarked(position) {
        var prevLapNum = mCurrentLapNumber;
        mCurrentLapNumber++;
        var lapNum = mCurrentLapNumber;
        
        // Get current system time and clock time
        var currentTime = System.getTimer();
        var clockTime = System.getClockTime();
        
        // Store both system time and clock time
        mLapPositionData[lapNum] = {
            "startPosition" => position,
            "startTime" => currentTime,
            "clockTimeHour" => clockTime.hour,
            "clockTimeMin" => clockTime.min,
            "clockTimeSec" => clockTime.sec,
            "distance" => 0.0
        };
        
        System.println("Marking lap " + lapNum + " at clock time: " + 
                    clockTime.hour + ":" + clockTime.min + ":" + clockTime.sec);
                    
    // IMPORTANT: Also store clock time in lap stats directly
        if (!mLapStats.hasKey(lapNum)) {
            mLapStats[lapNum] = {};
        }
        mLapStats[lapNum]["clockTimeHour"] = clockTime.hour;
        mLapStats[lapNum]["clockTimeMin"] = clockTime.min;
        mLapStats[lapNum]["clockTimeSec"] = clockTime.sec;
        
        System.println("Stored clock time in lap stats for lap " + lapNum + ": " + 
                    clockTime.hour + ":" + clockTime.min);
                
        // Initialize points data, direction data, and stats with default values
        mLapPointsData[lapNum] = {
            "totalPoints" => 0,
            "foilingPoints" => 0,
            // [other point data...]
        };
        
        mLapDirectionData[lapNum] = {
            "windAngleSum" => 0,
            "windDirectionSum" => 0,
            "windDirectionPoints" => 0
        };
        
        // Initialize stats with default values - IMPORTANT ADDITION: display counters
        mLapStats[lapNum] = {
            "tackCount" => 0,
            "gybeCount" => 0,
            "displayTackCount" => 0,  // Added display counter storage
            "displayGybeCount" => 0,  // Added display counter storage
            // [other stats...]
        };
        
        initSpeedTracking(lapNum);

        // [Copy speed data code...]
        
        // Initialize maneuvers
        mLapManeuvers[lapNum] = {
            "tacks" => [],
            "gybes" => []
        };
        
        // Notify the ManeuverDetector to reset lap counters - CRITICAL FIX
        if (mParent != null && mParent.getManeuverDetector() != null) {
            mParent.getManeuverDetector().resetLapCounters();
        }
        
        log("New lap marked: " + lapNum);
        return lapNum;
    }
    
    function processData(info, speed, isUpwind, currentTime) {
        if (mCurrentLapNumber <= 0) { return; }
        
        var lapNum = mCurrentLapNumber;
        
        // Ensure all data containers exist for the current lap
        ensureLapDataContainers(lapNum);
        
        // Get local references to data containers
        var pointsData = mLapPointsData[lapNum]; 
        var directionData = mLapDirectionData[lapNum]; 
        var stats = mLapStats[lapNum]; 
        
        // Critical safety check: make sure all containers exist and are initialized
        if (pointsData == null || directionData == null || stats == null) {
            System.println("Warning: Data containers are null in processData for lap " + lapNum);
            return; // Exit early since we can't safely proceed
        }
        
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
        // Initialize if null or not a number
        if (pointsData["totalPoints"] == null || !(pointsData["totalPoints"] instanceof Number)) {
            pointsData["totalPoints"] = 0;
        }
        
        // Safe increment
        pointsData["totalPoints"] += 1;
        
        // Foiling check
        var isOnFoil = (speed >= foilingThreshold);
        
        // Initialize foiling points if needed
        if (pointsData["foilingPoints"] == null || !(pointsData["foilingPoints"] instanceof Number)) {
            pointsData["foilingPoints"] = 0;
        }
        
        // Update foiling points if on foil
        if (isOnFoil) {
            pointsData["foilingPoints"] += 1;
        }
        
        // Get absolute wind angle once
        var windAngleLessCOG = (mParent != null && mParent.getAngleCalculator() != null) 
            ? mParent.getAngleCalculator().getWindAngleLessCOG() : 0;
        var absWindAngle = (windAngleLessCOG < 0) ? -windAngleLessCOG : windAngleLessCOG;
        
        // Create or update windAngleTotal field (CRITICAL FIX)
        if (!pointsData.hasKey("windAngleTotal")) {
            pointsData["windAngleTotal"] = 0.0;
        }
        
        // Accumulate wind angle
        pointsData["windAngleTotal"] += absWindAngle;
        
        // Log for debugging
        if (pointsData["totalPoints"] % 10 == 0) {  // Log every 10th point to avoid excessive logs
            System.println("Wind Angle Tracking - Current: " + absWindAngle + 
                        ", Total: " + pointsData["windAngleTotal"] + 
                        ", Points: " + pointsData["totalPoints"]);
        }
        
        // Update wind direction tracking
        var windDirection = (mParent != null) ? mParent.getWindDirection() : 0;
        
        // Initialize direction tracking if needed
        if (directionData["windDirectionSum"] == null || !(directionData["windDirectionSum"] instanceof Number)) {
            directionData["windDirectionSum"] = 0;
        }
        if (directionData["windDirectionPoints"] == null || !(directionData["windDirectionPoints"] instanceof Number)) {
            directionData["windDirectionPoints"] = 0;
        }
        
        // Update wind direction stats
        directionData["windDirectionSum"] += windDirection;
        directionData["windDirectionPoints"] += 1;
        
        // Initialize point of sail counters if needed
        if (pointsData["upwindPoints"] == null || !(pointsData["upwindPoints"] instanceof Number)) {
            pointsData["upwindPoints"] = 0;
        }
        if (pointsData["downwindPoints"] == null || !(pointsData["downwindPoints"] instanceof Number)) {
            pointsData["downwindPoints"] = 0;
        }
        if (pointsData["reachingPoints"] == null || !(pointsData["reachingPoints"] instanceof Number)) {
            pointsData["reachingPoints"] = 0;
        }
        
        // Update point of sail counters
        if (absWindAngle <= UPWIND_THRESHOLD) {
            pointsData["upwindPoints"] += 1;
        } else if (absWindAngle >= DOWNWIND_THRESHOLD) {
            pointsData["downwindPoints"] += 1;
        } else {
            pointsData["reachingPoints"] += 1;
        }
        
        // Update VMG
        updateVMG(info, speed, isUpwind, lapNum);
        
        // Calculate and update percentages and averages if we have data
        if (pointsData["totalPoints"] > 0) {
            // Calculate percentage on foil
            stats["pctOnFoil"] = (pointsData["foilingPoints"] * 100.0) / pointsData["totalPoints"];
            
            // Calculate point of sail percentages
            stats["pctUpwind"] = (pointsData["upwindPoints"] * 100.0) / pointsData["totalPoints"];
            stats["pctDownwind"] = (pointsData["downwindPoints"] * 100.0) / pointsData["totalPoints"];
            
            // Calculate wind angle average - CRITICAL FIX
            stats["avgWindAngle"] = Math.round(pointsData["windAngleTotal"] / pointsData["totalPoints"]).toNumber();
            
            // Log these calculations once in a while
            if (pointsData["totalPoints"] % 20 == 0) {  // Every 20th point
                System.println("Updated lap stats for lap " + lapNum + ":");
                System.println("  pctOnFoil: " + stats["pctOnFoil"].format("%.1f") + "%");
                System.println("  pctUpwind: " + stats["pctUpwind"].format("%.1f") + "%");
                System.println("  pctDownwind: " + stats["pctDownwind"].format("%.1f") + "%");
                System.println("  avgWindAngle: " + stats["avgWindAngle"] + "°");
            }
        }
    }
    
    // Fixed updateVMG function to handle null values safely
    function updateVMG(info, speed, isUpwind, lapNum) {
        if (!mLapStats.hasKey(lapNum) || !mLapPointsData.hasKey(lapNum)) {
            return;
        }
        
        // Get all needed data up front with null checks
        var absWindAngle = (mParent != null && mParent.getAngleCalculator() != null) 
            ? mParent.getAngleCalculator().getAbsWindAngle() : 0;
        
        var stats = mLapStats[lapNum];
        var pointsData = mLapPointsData[lapNum];
        
        // Initialize necessary stats properties if null
        if (stats["vmgUpTotal"] == null || !(stats["vmgUpTotal"] instanceof Number || stats["vmgUpTotal"] instanceof Float)) {
            stats["vmgUpTotal"] = 0.0;
        }
        if (stats["vmgDownTotal"] == null || !(stats["vmgDownTotal"] instanceof Number || stats["vmgDownTotal"] instanceof Float)) {
            stats["vmgDownTotal"] = 0.0;
        }
        
        // Initialize point counters if null
        if (pointsData["vmgUpPoints"] == null || !(pointsData["vmgUpPoints"] instanceof Number)) {
            pointsData["vmgUpPoints"] = 0;
        }
        if (pointsData["vmgDownPoints"] == null || !(pointsData["vmgDownPoints"] instanceof Number)) {
            pointsData["vmgDownPoints"] = 0;
        }
        
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
        
        // Update position data if needed - with extra safety checks
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

    function getLapData() {
        var lapNum = mCurrentLapNumber;
        
        // Return default data if no laps yet
        if (lapNum <= 0) {
            return createDefaultLapData();
        }
        
        // Create a safe return object with defaults
        var lapData = createDefaultLapData();
        
        try {
            // CRITICAL FIX: Calculate wind angle average directly from raw data first
            if (mLapPointsData.hasKey(lapNum)) {
                var pointsData = mLapPointsData[lapNum];
                if (pointsData != null && pointsData.hasKey("windAngleTotal") && 
                    pointsData.hasKey("totalPoints") && pointsData["totalPoints"] > 0) {
                    
                    // Calculate directly from the raw data
                    var avgWindAngle = Math.round(pointsData["windAngleTotal"] / pointsData["totalPoints"]).toNumber();
                    
                    // Store it in both the return data and in the stats
                    lapData["avgWindAngle"] = avgWindAngle;
                    
                    // Also update it in the stats for future reference
                    if (mLapStats.hasKey(lapNum)) {
                        mLapStats[lapNum]["avgWindAngle"] = avgWindAngle;
                    }
                    
                    System.println("DIRECT CALCULATION: Wind Angle Average = " + avgWindAngle + 
                                " (from " + pointsData["windAngleTotal"] + " / " + pointsData["totalPoints"] + ")");
                }
            }
            
            // Safely get all needed data sources with null checks
            if (mLapStats.hasKey(lapNum)) {
                var stats = mLapStats[lapNum];
                if (stats != null) {
                    // Copy basic data
                    if (stats.hasKey("lapVMG")) { lapData["lapVMG"] = stats["lapVMG"]; }
                    if (stats.hasKey("pctOnFoil")) { lapData["pctOnFoil"] = stats["pctOnFoil"]; }
                    if (stats.hasKey("tackCount")) { lapData["tackCount"] = stats["tackCount"]; }
                    if (stats.hasKey("gybeCount")) { lapData["gybeCount"] = stats["gybeCount"]; }
                    if (stats.hasKey("avgTackAngle")) { lapData["avgTackAngle"] = stats["avgTackAngle"]; }
                    if (stats.hasKey("avgGybeAngle")) { lapData["avgGybeAngle"] = stats["avgGybeAngle"]; }

                    // VMG data
                    if (stats.hasKey("avgVMGUp")) { lapData["vmgUp"] = stats["avgVMGUp"]; }
                    else if (stats.hasKey("vmgUp")) { lapData["vmgUp"] = stats["vmgUp"]; }
                    
                    if (stats.hasKey("avgVMGDown")) { lapData["vmgDown"] = stats["avgVMGDown"]; }
                    else if (stats.hasKey("vmgDown")) { lapData["vmgDown"] = stats["vmgDown"]; }
                    
                    // Speed data
                    if (stats.hasKey("maxSpeed")) { lapData["maxSpeed"] = stats["maxSpeed"]; }
                    if (stats.hasKey("max3sSpeed")) { lapData["max3sSpeed"] = stats["max3sSpeed"]; }
                    if (stats.hasKey("avgSpeed")) { lapData["avgSpeed"] = stats["avgSpeed"]; }
                }
            }
            
            // Get position data for time and distance
            if (mLapPositionData.hasKey(lapNum)) {
                var posData = mLapPositionData[lapNum];
                if (posData != null) {
                    if (posData.hasKey("startTime")) { lapData["startTime"] = posData["startTime"]; }
                    if (posData.hasKey("distance")) { lapData["tackMtr"] = posData["distance"]; }
                }
            }

            // Get point of sail percentages from points data
            if (mLapPointsData.hasKey(lapNum)) {
                var pointsData = mLapPointsData[lapNum];
                if (pointsData != null && pointsData.hasKey("totalPoints") && pointsData["totalPoints"] > 0) {
                    // Calculate percentage upwind
                    if (pointsData.hasKey("upwindPoints")) {
                        lapData["pctUpwind"] = Math.round((pointsData["upwindPoints"] * 100.0) / pointsData["totalPoints"]).toNumber();
                    }
                    
                    // Calculate percentage downwind
                    if (pointsData.hasKey("downwindPoints")) {
                        lapData["pctDownwind"] = Math.round((pointsData["downwindPoints"] * 100.0) / pointsData["totalPoints"]).toNumber();
                    }
                }
            }

            // Get wind direction from parent
            if (mParent != null) {
                lapData["windDirection"] = mParent.getWindDirection();
            }
            
            // Get wind strength from model
            lapData["windStrength"] = getWindStrength();
            
            // Log the key data for debugging
            System.println("FINAL LAP DATA for lap " + lapNum + ": pctUpwind=" + lapData["pctUpwind"] + 
                        ", pctDownwind=" + lapData["pctDownwind"] + 
                        ", avgWindAngle=" + lapData["avgWindAngle"]);
        } catch (e) {
            System.println("Error in getLapData: " + e.getErrorMessage());
            // Return default data when we hit an error
            return createDefaultLapData();
        }
        
        // Round all values once before returning
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
    
    // Safer calculation helpers for point of sail percentages
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
        
        // If sum is 0, just return 0
        if (sum == 0) {
            return 0;
        }
        
        // Use same calculation as in the processData method
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

    function ensureLapDataContainers(lapNum) {
        // Initialize points data if not exists
        if (!mLapPointsData.hasKey(lapNum)) {
            mLapPointsData[lapNum] = {
                "totalPoints" => 0,
                "foilingPoints" => 0,
                "upwindPoints" => 0,
                "downwindPoints" => 0,
                "reachingPoints" => 0,
                "vmgUpPoints" => 0,
                "vmgDownPoints" => 0,
                "windAngleTotal" => 0.0  // Added this field
            };
        }
        
        // Initialize direction data if not exists
        if (!mLapDirectionData.hasKey(lapNum)) {
            mLapDirectionData[lapNum] = {
                "windAngleSum" => 0,
                "windDirectionSum" => 0,
                "windDirectionPoints" => 0
            };
        }
        
        // Initialize stats if not exists
        if (!mLapStats.hasKey(lapNum)) {
            mLapStats[lapNum] = {
                "tackCount" => 0,
                "gybeCount" => 0,
                "displayTackCount" => 0,
                "displayGybeCount" => 0,
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
                "pctUpwind" => 0,
                "pctDownwind" => 0,
                "avgWindAngle" => 0
            };
        }
        
        // Initialize speed tracking if not exists
        if (!mLapSpeedData.hasKey(lapNum)) {
            mLapSpeedData[lapNum] = {
                "speedSum" => 0.0,
                "speedPoints" => 0,
                "maxSpeed" => 0.0,
                "max3sSpeed" => 0.0
            };
        }
        
        // Initialize maneuvers if not exists
        if (!mLapManeuvers.hasKey(lapNum)) {
            mLapManeuvers[lapNum] = {
                "tacks" => [],
                "gybes" => []
            };
        }
    }

    // Fixed recordManeuverInLap function to handle null/invalid values
    function recordManeuverInLap(maneuver) {
        // Safety check - make sure maneuver is valid
        if (maneuver == null) {
            System.println("Error: Tried to record null maneuver");
            return false;
        }
        
        // Get the lap number and ensure it's valid
        var lapNumber = 1; // Default to lap 1 if not specified
        if (maneuver.hasKey("lapNumber") && maneuver["lapNumber"] != null && maneuver["lapNumber"] instanceof Number) {
            lapNumber = maneuver["lapNumber"];
        }
        
        // Make sure we have a lap maneuvers entry for this lap
        if (!mLapManeuvers.hasKey(lapNumber) || mLapManeuvers[lapNumber] == null) {
            // Initialize the lap maneuvers for this lap
            mLapManeuvers[lapNumber] = {
                "tacks" => [],
                "gybes" => []
            };
            System.println("Initialized maneuvers collection for lap " + lapNumber);
        }
        
        // Get the maneuver type
        var isTack = true; // Default to tack if not specified
        if (maneuver.hasKey("isTack")) {
            isTack = maneuver["isTack"];
        }
        
        // Check for isReliable flag - default to true if not specified
        var isReliable = true;
        if (maneuver.hasKey("isReliable")) {
            isReliable = maneuver["isReliable"];
        }
        
        // Add to the appropriate collection based on type
        var collection = isTack ? "tacks" : "gybes";
        
        // Safety check for collection
        if (!mLapManeuvers[lapNumber].hasKey(collection)) {
            mLapManeuvers[lapNumber][collection] = [];
        }
        
        try {
            // Add the maneuver to the collection
            mLapManeuvers[lapNumber][collection].add(maneuver);
            
            // Update any stats based on this maneuver
            if (isReliable) {
                // Get angle if available
                var angle = 0;
                if (maneuver.hasKey("angle") && maneuver["angle"] != null) {
                    angle = maneuver["angle"];
                }
                
                // Update stats if this lap exists in mLapStats
                if (mLapStats.hasKey(lapNumber)) {
                    if (isTack) {
                        // Update tack angle stats
                        if (mLapStats[lapNumber].hasKey("avgTackAngle")) {
                            mLapStats[lapNumber]["avgTackAngle"] = angle;
                        }
                        if (mLapStats[lapNumber].hasKey("maxTackAngle") && 
                            angle > mLapStats[lapNumber]["maxTackAngle"]) {
                            mLapStats[lapNumber]["maxTackAngle"] = angle;
                        }
                    } else {
                        // Update gybe angle stats
                        if (mLapStats[lapNumber].hasKey("avgGybeAngle")) {
                            mLapStats[lapNumber]["avgGybeAngle"] = angle;
                        }
                        if (mLapStats[lapNumber].hasKey("maxGybeAngle") && 
                            angle > mLapStats[lapNumber]["maxGybeAngle"]) {
                            mLapStats[lapNumber]["maxGybeAngle"] = angle;
                        }
                    }
                }
            }
            
            // Log success
            System.println("Recorded " + (isReliable ? "reliable" : "unreliable") + 
                        " " + (isTack ? "tack" : "gybe") + " in lap " + lapNumber);
            return true;
        } catch (e) {
            // Log the error for debugging
            System.println("Error recording maneuver in lap: " + e.getErrorMessage());
            return false;
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


    // Updated getLapStats method to ensure it uses tracked point of sail data
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
        
        // Calculate and add point of sail percentages if not already set
        if (mLapPointsData.hasKey(lapNumber)) {
            var pointsData = mLapPointsData[lapNumber];
            
            // Only calculate if not already set or if set to 0
            if (!stats.hasKey("pctUpwind") || stats["pctUpwind"] == 0) {
                stats["pctUpwind"] = calculatePctUpwind(pointsData);
            }
            
            if (!stats.hasKey("pctDownwind") || stats["pctDownwind"] == 0) {
                stats["pctDownwind"] = calculatePctDownwind(pointsData);
            }
        }
        
        // Calculate and add average wind angle if not already set
        if (mLapDirectionData.hasKey(lapNumber) && mLapPointsData.hasKey(lapNumber)) {
            var dirData = mLapDirectionData[lapNumber];
            var pointsData = mLapPointsData[lapNumber];
            
            if (!stats.hasKey("avgWindAngle") || stats["avgWindAngle"] == 0) {
                stats["avgWindAngle"] = calculateAvgWindAngle(dirData, pointsData);
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
        
        // Log the point of sail percentages
        System.println("  - pctUpwind: " + stats["pctUpwind"]);
        System.println("  - pctDownwind: " + stats["pctDownwind"]);
        System.println("  - avgWindAngle: " + stats["avgWindAngle"]);
        
        return stats;
    }
}