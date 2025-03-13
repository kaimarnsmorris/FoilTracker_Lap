// LapTracker.mc - Tracks lap-specific data
using Toybox.System;
using Toybox.Math;

class LapTracker {
    // Constants
    private const UPWIND_THRESHOLD = 70;     // Angle threshold for upwind (0-70 degrees)
    private const DOWNWIND_THRESHOLD = 110;  // Angle threshold for downwind (110-180 degrees)

    // In LapTracker.mc
    // Add these new variables to the existing private variables declaration
    private var mParent;                  // Reference to WindTracker parent
    private var mCurrentLapNumber;        // Current lap number
    private var mLapManeuvers;            // Dictionary of maneuvers by lap
    private var mLapStats;                // Dictionary of stats by lap
    private var mLastLapStartTime;        // Timestamp of lap start
    private var mLapStartPositions;       // Start positions by lap
    private var mLapStartTimestamps;      // Start times by lap
    private var mLapDistances;            // Distances by lap

    // Foiling statistics
    private var mLapFoilingPoints;        // Points spent foiling by lap
    private var mLapTotalPoints;          // Total points by lap

    // VMG statistics
    private var mLapVMGUpTotal;           // Total upwind VMG by lap
    private var mLapVMGDownTotal;         // Total downwind VMG by lap
    private var mLapUpwindPoints;         // Upwind data points by lap
    private var mLapDownwindPoints;       // Downwind data points by lap

    // Wind direction tracking
    private var mLapWindDirectionSum;     // Sum of wind directions in lap
    private var mLapWindDirectionPoints;  // Number of wind direction points in lap

    // New point of sail tracking
    private var mLapPOSUpwindPoints;      // Points spent upwind by lap (for point of sail tracking)
    private var mLapPOSDownwindPoints;    // Points spent downwind by lap (for point of sail tracking)
    private var mLapPOSReachingPoints;    // Points spent reaching by lap (for point of sail tracking)
    private var mLapWindAngleSum;         // Sum of wind angles in lap (for average)
    private var mLapSpeedSum;             // Sum of speeds in lap (for average)
    
    // Initialize
    // In LapTracker.mc
    // Update initialize method
    function initialize(parent) {
        mParent = parent;
        reset();
    }

    // Update reset method to add separate POS (Point of Sail) counters
    function reset() {
        mCurrentLapNumber = 0;
        mLapManeuvers = {};
        mLapStats = {};
        mLastLapStartTime = System.getTimer();
        mLapStartPositions = {};
        mLapStartTimestamps = {};
        mLapDistances = {};
        
        // Reset foiling statistics
        mLapFoilingPoints = {};
        mLapTotalPoints = {};
        
        // Reset VMG statistics
        mLapVMGUpTotal = {};
        mLapVMGDownTotal = {};
        mLapUpwindPoints = {};
        mLapDownwindPoints = {};
        
        // Reset wind direction tracking
        mLapWindDirectionSum = {};
        mLapWindDirectionPoints = {};
        
        // NEW: Separate POS (Point of Sail) counters 
        mLapPOSUpwindPoints = {};
        mLapPOSDownwindPoints = {};
        mLapPOSReachingPoints = {};
        mLapWindAngleSum = {};
        mLapSpeedSum = {};
        
        log("LapTracker reset");
    }
    
    // Mark the start of a new lap
    // In LapTracker.mc
    // Update onLapMarked method to initialize new POS counters
    function onLapMarked(position) {
        // Increment lap counter
        mCurrentLapNumber++;
        
        // Store lap start position
        if (position != null) {
            mLapStartPositions[mCurrentLapNumber] = position;
            log("Stored start position for lap " + mCurrentLapNumber);
        }
        
        // Set timestamp for the new lap
        var currentTime = System.getTimer();
        mLastLapStartTime = currentTime;
        mLapStartTimestamps[mCurrentLapNumber] = currentTime;
        
        // Initialize lap distance
        mLapDistances[mCurrentLapNumber] = 0.0;
        
        // Initialize foiling counters for this specific lap
        mLapFoilingPoints[mCurrentLapNumber] = 0;
        mLapTotalPoints[mCurrentLapNumber] = 0;
        
        // Initialize VMG averages
        mLapVMGUpTotal[mCurrentLapNumber] = 0.0;
        mLapVMGDownTotal[mCurrentLapNumber] = 0.0;
        mLapUpwindPoints[mCurrentLapNumber] = 0;
        mLapDownwindPoints[mCurrentLapNumber] = 0;
        
        // Initialize wind direction tracking
        mLapWindDirectionSum[mCurrentLapNumber] = 0.0;
        mLapWindDirectionPoints[mCurrentLapNumber] = 0;
        
        // Initialize NEW separate POS counters
        mLapPOSUpwindPoints[mCurrentLapNumber] = 0;
        mLapPOSDownwindPoints[mCurrentLapNumber] = 0;
        mLapPOSReachingPoints[mCurrentLapNumber] = 0;
        mLapWindAngleSum[mCurrentLapNumber] = 0;
        mLapSpeedSum[mCurrentLapNumber] = 0.0;
        
        // Initialize maneuver tracking for this lap
        mLapManeuvers[mCurrentLapNumber] = {
            "tacks" => [],
            "gybes" => []
        };
        
        // Initialize statistics for this lap
        mLapStats[mCurrentLapNumber] = {
            "tackCount" => 0,
            "gybeCount" => 0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "maxTackAngle" => 0,
            "maxGybeAngle" => 0,
            "lapVMG" => 0.0,
            "pctOnFoil" => 0.0,
            "avgVMGUp" => 0.0,
            "avgVMGDown" => 0.0
        };
        
        log("New lap marked: " + mCurrentLapNumber + " - initialized all counters");
        
        return mCurrentLapNumber;
    }
    
    // In LapTracker.mc
    // Update processData with reduced logging
    function processData(info, speed, isUpwind, currentTime) {
        // Skip if not tracking a lap yet
        if (mCurrentLapNumber <= 0) {
            return;
        }
        
        // Track foiling status
        var foilingThreshold = 7.0; // Default threshold in knots
        var isActive = true; // Assume active unless determined otherwise
        
        // Try to get from settings
        try {
            var app = Application.getApp();
            if (app != null && app has :mModel && app.mModel != null) {
                var data = app.mModel.getData();
                if (data != null && data.hasKey("settings")) {
                    var settings = data["settings"];
                    if (settings != null && settings.hasKey("foilingThreshold")) {
                        foilingThreshold = settings["foilingThreshold"];
                    }
                }
                
                // Check if app is paused
                if (data != null && data.hasKey("sessionPaused") && data["sessionPaused"]) {
                    isActive = false;
                }
            }
        } catch (e) {
            // Silent error handling
        }
        
        // Check if currently foiling
        var isOnFoil = (speed >= foilingThreshold);
        
        // Skip further processing if not active
        if (!isActive) {
            return;
        }
        
        // Increment total points counter once per data point
        if (!mLapTotalPoints.hasKey(mCurrentLapNumber)) {
            mLapTotalPoints[mCurrentLapNumber] = 0;
        }
        mLapTotalPoints[mCurrentLapNumber]++;
        
        // Update foiling status (only increment foiling counter if on foil)
        if (isOnFoil) {
            if (!mLapFoilingPoints.hasKey(mCurrentLapNumber)) {
                mLapFoilingPoints[mCurrentLapNumber] = 0;
            }
            mLapFoilingPoints[mCurrentLapNumber]++;
        }
        
        // Update lap VMG averages - these still use isUpwind for categorization
        updateLapVMGAverages(speed, isUpwind);
        
        // Update lap VMG calculation
        updateLapVMG(info);
        
        // Track average wind direction for this lap
        var windDirection = mParent.getWindDirection();
        if (!mLapWindDirectionSum.hasKey(mCurrentLapNumber)) {
            mLapWindDirectionSum[mCurrentLapNumber] = 0.0;
            mLapWindDirectionPoints[mCurrentLapNumber] = 0;
        }
        mLapWindDirectionSum[mCurrentLapNumber] += windDirection;
        mLapWindDirectionPoints[mCurrentLapNumber]++;
        
        // Get absolute wind angle
        var windAngleLessCOG = mParent.getAngleCalculator().getWindAngleLessCOG();
        var absWindAngle = (windAngleLessCOG < 0) ? -windAngleLessCOG : windAngleLessCOG;
        
        // Update wind angle sum for averaging
        if (!mLapWindAngleSum.hasKey(mCurrentLapNumber)) {
            mLapWindAngleSum[mCurrentLapNumber] = 0;
        }
        mLapWindAngleSum[mCurrentLapNumber] += absWindAngle;
        
        // Update speed data
        if (!mLapSpeedSum.hasKey(mCurrentLapNumber)) {
            mLapSpeedSum[mCurrentLapNumber] = 0.0;
        }
        mLapSpeedSum[mCurrentLapNumber] += speed;
        
        // Ensure the NEW point of sail counters exist
        if (!mLapPOSUpwindPoints.hasKey(mCurrentLapNumber)) {
            mLapPOSUpwindPoints[mCurrentLapNumber] = 0;
        }
        if (!mLapPOSDownwindPoints.hasKey(mCurrentLapNumber)) {
            mLapPOSDownwindPoints[mCurrentLapNumber] = 0;
        }
        if (!mLapPOSReachingPoints.hasKey(mCurrentLapNumber)) {
            mLapPOSReachingPoints[mCurrentLapNumber] = 0;
        }
        
        // Classify by point of sail using class constants - each point gets counted in EXACTLY ONE category
        if (absWindAngle <= UPWIND_THRESHOLD) {
            // Upwind
            mLapPOSUpwindPoints[mCurrentLapNumber]++;
        } else if (absWindAngle >= DOWNWIND_THRESHOLD) {
            // Downwind
            mLapPOSDownwindPoints[mCurrentLapNumber]++;
        } else {
            // Reaching
            mLapPOSReachingPoints[mCurrentLapNumber]++;
        }
        
        // Calculate percentage on foil for this lap
        if (mLapTotalPoints[mCurrentLapNumber] > 0) {
            var pctOnFoil = (mLapFoilingPoints[mCurrentLapNumber] * 100.0) / 
                        mLapTotalPoints[mCurrentLapNumber];
                        
            // Update lap stats
            if (mLapStats.hasKey(mCurrentLapNumber)) {
                mLapStats[mCurrentLapNumber]["pctOnFoil"] = pctOnFoil;
            }
        }
    }
    
    // Update lap VMG calculations
    // Update lap VMG calculations
    function updateLapVMG(info) {
        if (mCurrentLapNumber <= 0 || info == null) {
            return;
        }
        
        // Store position as start if none exists
        if (!mLapStartPositions.hasKey(mCurrentLapNumber)) {
            mLapStartPositions[mCurrentLapNumber] = info;
            return;
        }
        
        // Get lap start position
        var startPos = mLapStartPositions[mCurrentLapNumber];
        
        // Calculate distance and bearing
        var distance = 0.0;
        var bearing = 0.0;
        
        // Use a more compatible approach for distance calculation between positions
        if (info has :position && startPos has :position) {
            try {
                // Basic distance calculation
                var lat1 = startPos.position[0];
                var lon1 = startPos.position[1];
                var lat2 = info.position[0];
                var lon2 = info.position[1];
                
                // Approximate distance using Pythagorean theorem
                var latDiff = lat2 - lat1;
                var lonDiff = lon2 - lon1;
                
                // Converting to approximate meters
                var latMeters = latDiff * 111320; // 1 degree lat is ~111.32 km
                var lonMeters = lonDiff * 111320 * Math.cos(Math.toRadians((lat1 + lat2) / 2));
                
                distance = Math.sqrt(latMeters * latMeters + lonMeters * lonMeters);
                
                // Calculate bearing
                bearing = Math.toDegrees(Math.atan2(lonDiff, latDiff));
                if (bearing < 0) {
                    bearing += 360;
                }
            } catch (e) {
                log("Error calculating position: " + e.getErrorMessage());
                distance = 0.0;
                bearing = 0.0;
            }
        }
        
        // Store distance for other calculations
        if (distance > 0) {
            mLapDistances[mCurrentLapNumber] = distance;
        }
        
        // Get current timestamp
        var currentTime = System.getTimer();
        
        // Calculate time elapsed since lap start (in hours)
        var lapStartTime = mLapStartTimestamps[mCurrentLapNumber];
        var elapsedTimeHours = (currentTime - lapStartTime) / (1000.0 * 60.0 * 60.0);
        
        // Skip VMG calculation if elapsed time is too small
        if (elapsedTimeHours < 0.001) {
            return;
        }
        
        // Calculate projection onto wind direction
        var windDirRadians = Math.toRadians(mParent.getWindDirection());
        var bearingRadians = Math.toRadians(bearing);
        
        // Component of travel in direction of wind
        var distanceToWind = distance * Math.cos(bearingRadians - windDirRadians);
        
        // If going upwind, we want to go against the wind, so negate
        if (mParent.getAngleCalculator().isUpwind()) {
            distanceToWind = -distanceToWind;
        }
        
        // Convert from meters to nautical miles (1 nm = 1852 meters)
        var distanceNM = distanceToWind / 1852.0;
        
        // Calculate VMG in knots (nautical miles per hour)
        var lapVMG = distanceNM / elapsedTimeHours;
        
        // Update lap stats with this VMG
        if (mLapStats.hasKey(mCurrentLapNumber)) {
            mLapStats[mCurrentLapNumber]["lapVMG"] = lapVMG;
        }
    }
    
    // Update foiling percentage for current lap
    // Update foiling percentage for current lap
    function updateLapFoilingPercentage(isOnFoil) {
        if (mCurrentLapNumber <= 0) {
            return;
        }
        
        // Ensure counters exist for this lap
        if (!mLapTotalPoints.hasKey(mCurrentLapNumber)) {
            mLapTotalPoints[mCurrentLapNumber] = 0;
            mLapFoilingPoints[mCurrentLapNumber] = 0;
            log("Created new foiling counters for lap " + mCurrentLapNumber);
        }
        
        // Increment total points for this lap
        mLapTotalPoints[mCurrentLapNumber]++;
        
        // Increment foiling points if on foil
        if (isOnFoil) {
            mLapFoilingPoints[mCurrentLapNumber]++;
        }
        
        // Calculate percentage for this lap only
        if (mLapTotalPoints[mCurrentLapNumber] > 0) {
            var pctOnFoil = (mLapFoilingPoints[mCurrentLapNumber] * 100.0) / 
                            mLapTotalPoints[mCurrentLapNumber];
            
            // Update lap stats
            if (mLapStats.hasKey(mCurrentLapNumber)) {
                mLapStats[mCurrentLapNumber]["pctOnFoil"] = pctOnFoil;
            }
            
            if (mLapTotalPoints[mCurrentLapNumber] % 20 == 0) {
                log("Lap " + mCurrentLapNumber + " Foiling: " + 
                    mLapFoilingPoints[mCurrentLapNumber] + "/" + 
                    mLapTotalPoints[mCurrentLapNumber] + " = " + 
                    pctOnFoil.format("%.1f") + "%");
            }
        }
    }
    
    // Update lap VMG averages
    function updateLapVMGAverages(speed, isUpwind) {
        if (mCurrentLapNumber <= 0) {
            return;
        }
        
        // Calculate VMG for current speed and wind angle
        var absWindAngle = mParent.getAngleCalculator().getAbsWindAngle();
        var windAngleRad;
        var lapVMG;
        
        if (isUpwind) {
            // Upwind calculation
            windAngleRad = Math.toRadians(absWindAngle);
            lapVMG = speed * Math.cos(windAngleRad);
            
            // Ensure positive (moving toward wind)
            if (lapVMG < 0) {
                lapVMG = -lapVMG;
            }
            
            // Add to upwind totals
            if (!mLapVMGUpTotal.hasKey(mCurrentLapNumber)) {
                mLapVMGUpTotal[mCurrentLapNumber] = 0.0;
                mLapUpwindPoints[mCurrentLapNumber] = 0;
            }
            
            mLapVMGUpTotal[mCurrentLapNumber] += lapVMG;
            mLapUpwindPoints[mCurrentLapNumber]++;
            
            // Calculate average upwind VMG
            if (mLapUpwindPoints[mCurrentLapNumber] > 0) {
                var avgVMGUp = mLapVMGUpTotal[mCurrentLapNumber] / 
                            mLapUpwindPoints[mCurrentLapNumber];
                
                // Update lap stats - store as floating point
                if (mLapStats.hasKey(mCurrentLapNumber)) {
                    mLapStats[mCurrentLapNumber]["avgVMGUp"] = avgVMGUp;
                }
            }
        } else {
            // Downwind calculation
            windAngleRad = Math.toRadians(180 - absWindAngle);
            lapVMG = speed * Math.cos(windAngleRad);
            
            // Ensure positive (moving away from wind)
            if (lapVMG < 0) {
                lapVMG = -lapVMG;
            }
            
            // Add to downwind totals
            if (!mLapVMGDownTotal.hasKey(mCurrentLapNumber)) {
                mLapVMGDownTotal[mCurrentLapNumber] = 0.0;
                mLapDownwindPoints[mCurrentLapNumber] = 0;
            }
            
            mLapVMGDownTotal[mCurrentLapNumber] += lapVMG;
            mLapDownwindPoints[mCurrentLapNumber]++;
            
            // Calculate average downwind VMG
        if (mLapDownwindPoints[mCurrentLapNumber] > 0) {
            var avgVMGDown = mLapVMGDownTotal[mCurrentLapNumber] / 
                            mLapDownwindPoints[mCurrentLapNumber];
            
            // Update lap stats - store as floating point
            if (mLapStats.hasKey(mCurrentLapNumber)) {
                mLapStats[mCurrentLapNumber]["avgVMGDown"] = avgVMGDown;
            }
        }
    }
}
    
    // Record a maneuver in the current lap
    function recordManeuverInLap(maneuver) {
        // Extract lap number from the maneuver
        var lapNumber = maneuver["lapNumber"];
        if (lapNumber <= 0 || !mLapManeuvers.hasKey(lapNumber)) {
            return;
        }
        
        var isTack = maneuver["isTack"];
        
        // Add to lap-specific collections
        if (isTack) {
            mLapManeuvers[lapNumber]["tacks"].add(maneuver);
            log("Added tack to lap " + lapNumber + " with angle " + maneuver["angle"]);
        } else {
            mLapManeuvers[lapNumber]["gybes"].add(maneuver);
            log("Added gybe to lap " + lapNumber + " with angle " + maneuver["angle"]);
        }
        
        // Update lap-specific statistics immediately
        updateLapManeuverStats(lapNumber);
    }
    
    // Update lap-specific maneuver statistics
    function updateLapManeuverStats(lapNumber) {
        if (!mLapManeuvers.hasKey(lapNumber) || !mLapStats.hasKey(lapNumber)) {
            return;
        }
        
        var lapTacks = mLapManeuvers[lapNumber]["tacks"];
        var lapGybes = mLapManeuvers[lapNumber]["gybes"];
        
        var tackCount = lapTacks.size();
        var gybeCount = lapGybes.size();
        var tackSum = 0;
        var gybeSum = 0;
        var maxTack = 0;
        var maxGybe = 0;
        
        // Calculate tack statistics for this specific lap
        for (var i = 0; i < tackCount; i++) {
            var angle = lapTacks[i]["angle"];
            tackSum += angle;
            if (angle > maxTack) {
                maxTack = angle;
            }
        }
        
        // Calculate gybe statistics for this specific lap
        for (var i = 0; i < gybeCount; i++) {
            var angle = lapGybes[i]["angle"];
            gybeSum += angle;
            if (angle > maxGybe) {
                maxGybe = angle;
            }
        }
        
        // Calculate averages for this specific lap
        var avgTack = (tackCount > 0) ? tackSum / tackCount : 0;
        var avgGybe = (gybeCount > 0) ? gybeSum / gybeCount : 0;
        
        log("Lap " + lapNumber + " Tack Stats: " + tackCount + " tacks, avg angle " + avgTack);
        log("Lap " + lapNumber + " Gybe Stats: " + gybeCount + " gybes, avg angle " + avgGybe);
        
        // Update lap stats with existing fields preserved
        var existingStats = mLapStats[lapNumber];
        var updatedStats = {
            "tackCount" => tackCount,
            "gybeCount" => gybeCount,
            "avgTackAngle" => avgTack,
            "avgGybeAngle" => avgGybe,
            "maxTackAngle" => maxTack,
            "maxGybeAngle" => maxGybe,
            "lapVMG" => existingStats.hasKey("lapVMG") ? existingStats["lapVMG"] : 0.0,
            "pctOnFoil" => existingStats.hasKey("pctOnFoil") ? existingStats["pctOnFoil"] : 0.0,
            "avgVMGUp" => existingStats.hasKey("avgVMGUp") ? existingStats["avgVMGUp"] : 0.0,
            "avgVMGDown" => existingStats.hasKey("avgVMGDown") ? existingStats["avgVMGDown"] : 0.0
        };
        
        // Completely replace the stats object to ensure all fields are updated
        mLapStats[lapNumber] = updatedStats;
    }
    
    // Get time since last tack in current lap
    function getTimeSinceLastTack() {
        if (mCurrentLapNumber <= 0 || !mLapManeuvers.hasKey(mCurrentLapNumber)) {
            return 0.0;
        }
        
        var tackArray = mLapManeuvers[mCurrentLapNumber]["tacks"];
        if (tackArray == null || tackArray.size() == 0) {
            // If no tacks in lap, return time since lap start
            var currentTime = System.getTimer();
            return (currentTime - mLastLapStartTime) / 1000.0;
        }
        
        // Get timestamp of last tack
        var lastTackTimestamp = tackArray[tackArray.size() - 1]["timestamp"];
        var currentTime = System.getTimer();
        
        // Return seconds since last tack
        return (currentTime - lastTackTimestamp) / 1000.0;
    }
    
    // In LapTracker.mc
    // Update getLapData with simplified wind logic and reduced logging
    function getLapData() {
        // Create a data structure for lap fields with default values
        var lapData = {
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
        
        // Use lap-specific values if available
        if (mCurrentLapNumber > 0 && mLapStats.hasKey(mCurrentLapNumber)) {
            var lapStats = mLapStats[mCurrentLapNumber];
            
            // Get lap-specific VMG values
            if (lapStats.hasKey("avgVMGUp")) {
                lapData["vmgUp"] = lapStats["avgVMGUp"];
            }
            
            if (lapStats.hasKey("avgVMGDown")) {
                lapData["vmgDown"] = lapStats["avgVMGDown"];
            }
            
            // Get lap-specific percent on foil
            if (lapStats.hasKey("pctOnFoil")) {
                lapData["pctOnFoil"] = lapStats["pctOnFoil"];
            } else if (mLapFoilingPoints.hasKey(mCurrentLapNumber) && 
                    mLapTotalPoints.hasKey(mCurrentLapNumber) && 
                    mLapTotalPoints[mCurrentLapNumber] > 0) {
                        
                // Calculate directly if not in stats
                lapData["pctOnFoil"] = (mLapFoilingPoints[mCurrentLapNumber] * 100.0) / 
                                    mLapTotalPoints[mCurrentLapNumber];
            }
            
            // Get lap-specific tack angle
            if (lapStats.hasKey("avgTackAngle")) {
                lapData["avgTackAngle"] = lapStats["avgTackAngle"];
            }
            
            // Get lap-specific gybe angle
            if (lapStats.hasKey("avgGybeAngle")) {
                lapData["avgGybeAngle"] = lapStats["avgGybeAngle"];
            }
            
            // Get lap-specific VMG
            if (lapStats.hasKey("lapVMG")) {
                lapData["lapVMG"] = lapStats["lapVMG"];
            }
            
            // Get lap-specific tack/gybe counts
            if (lapStats.hasKey("tackCount")) {
                lapData["tackCount"] = lapStats["tackCount"];
            }
            
            if (lapStats.hasKey("gybeCount")) {
                lapData["gybeCount"] = lapStats["gybeCount"];
            }
            
            // Calculate time since last tack
            lapData["tackSec"] = getTimeSinceLastTack();
        }
        
        // Calculate average wind direction for this lap
        var avgWindDirection = 0;
        if (mCurrentLapNumber > 0 && 
            mLapWindDirectionPoints.hasKey(mCurrentLapNumber) && 
            mLapWindDirectionPoints[mCurrentLapNumber] > 0) {
            
            avgWindDirection = mLapWindDirectionSum[mCurrentLapNumber] / 
                            mLapWindDirectionPoints[mCurrentLapNumber];
            
            // Round to nearest degree
            avgWindDirection = Math.round(avgWindDirection).toNumber();
        } else {
            // Fallback to current wind direction
            avgWindDirection = mParent.getWindDirection();
        }
        
        // Include average wind direction in lap data
        lapData["windDirection"] = avgWindDirection;
        
        // SIMPLIFIED: Use index-based wind strength calculation
        var windStrength = 0;
        try {
            var app = Application.getApp();
            if (app != null && app has :mModel && app.mModel != null) {
                var data = app.mModel.getData();
                if (data != null && data.hasKey("windStrengthIndex")) {
                    var windIndex = data["windStrengthIndex"];
                    // Convert index to lower limit of range (7, 10, 13, 16, 19, 22, 25)
                    windStrength = 7 + (windIndex * 3);
                }
            }
        } catch (e) {
            // Silent error handling
        }
        
        lapData["windStrength"] = windStrength;
        
        // Include the distance traveled in this lap if available
        if (mCurrentLapNumber > 0 && mLapDistances.hasKey(mCurrentLapNumber)) {
            lapData["tackMtr"] = mLapDistances[mCurrentLapNumber];
        }
        
        // Calculate percentages and averages using NEW POS counters
        if (mCurrentLapNumber > 0 && mLapTotalPoints.hasKey(mCurrentLapNumber) && mLapTotalPoints[mCurrentLapNumber] > 0) {
            var totalPoints = mLapTotalPoints[mCurrentLapNumber];
            
            // Use the NEW POS counters for percentage calculations
            if (mLapPOSUpwindPoints.hasKey(mCurrentLapNumber)) {
                lapData["pctUpwind"] = Math.round((mLapPOSUpwindPoints[mCurrentLapNumber] * 100.0) / totalPoints);
            }
            
            if (mLapPOSDownwindPoints.hasKey(mCurrentLapNumber)) {
                lapData["pctDownwind"] = Math.round((mLapPOSDownwindPoints[mCurrentLapNumber] * 100.0) / totalPoints);
            }
            
            // Calculate average wind angle
            if (mLapWindAngleSum.hasKey(mCurrentLapNumber)) {
                lapData["avgWindAngle"] = Math.round(mLapWindAngleSum[mCurrentLapNumber] / totalPoints);
            }
        }
        
        // Round all values for consistency
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
    
    function getLapManeuvers(lapNumber) {
        if (lapNumber > 0 && mLapManeuvers.hasKey(lapNumber)) {
            return mLapManeuvers[lapNumber];
        }
        return null;
    }
}

