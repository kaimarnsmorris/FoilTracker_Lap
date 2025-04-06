// ManeuverDetector.mc - Detects tacks and gybes
using Toybox.Time;
using Toybox.System;

class ManeuverDetector {
    // Constants
    private const MAN_ANGLE_TIME_MEASURE = 15;   // Time period to measure course (seconds) - increased from 10
    private const MAN_ANGLE_TIME_IGNORE = 15;     // Time to ignore before/after maneuver (seconds) - increased from 4
    
    // Properties
    private var mParent;                  // Reference to WindTracker parent
    private var mTackCount;               // Number of tacks
    private var mGybeCount;               // Number of gybes
    private var mLastTackAngle;           // Most recent tack angle
    private var mLastGybeAngle;           // Most recent gybe angle
    private var mLastTackHeadings;        // Recent tack headings [previous, current]
    private var mLastGybeHeadings;        // Recent gybe headings [previous, current]
    private var mManeuverHistory;         // Array to store maneuver history
    private var mManeuverStats;           // Statistics on maneuvers
    private var mManeuverTimestamp;       // Timestamp of last maneuver detection
    private var mPendingManeuver;         // Information about pending maneuver

    // Member variables for display and lap-specific counters
    private var mDisplayTackCount;        // Count of tacks for display (including unreliable ones)
    private var mDisplayGybeCount;        // Count of gybes for display (including unreliable ones)
    private var mLapDisplayTackCounts;    // Dictionary to store lap-specific tack counts, keyed by lap number
    private var mLapDisplayGybeCounts;    // Dictionary to store lap-specific gybe counts, keyed by lap number
    
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }
    
    // Update the reset function to initialize the counters and lap-specific dictionaries
    function reset() {
        resetManeuverCounts();
        
        // Initialize maneuver history and stats
        mManeuverHistory = new [mParent.MAX_MANEUVERS];
        
        mManeuverStats = {
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "maxTackAngle" => 0,
            "maxGybeAngle" => 0
        };
        
        mManeuverTimestamp = 0;
        mPendingManeuver = null;
        
        // Reset display counters
        mDisplayTackCount = 0;
        mDisplayGybeCount = 0;
        
        // Initialize lap-specific counter dictionaries
        mLapDisplayTackCounts = {};
        mLapDisplayGybeCounts = {};
        
        // Set initial lap counters for lap 1
        mLapDisplayTackCounts[1] = 0;
        mLapDisplayGybeCounts[1] = 0;
        
        log("ManeuverDetector reset");
    }
    
    // Update resetManeuverCounts to reset display counters too
    function resetManeuverCounts() {
        mTackCount = 0;
        mGybeCount = 0;
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        mLastTackHeadings = [0, 0];
        mLastGybeHeadings = [0, 0];
        
        // Reset display counters
        mDisplayTackCount = 0;
        mDisplayGybeCount = 0;
        
        // Initialize lap-specific counter dictionaries
        mLapDisplayTackCounts = {};
        mLapDisplayGybeCounts = {};
        
        // Set initial lap counters for lap 1
        mLapDisplayTackCounts[1] = 0;
        mLapDisplayGybeCounts[1] = 0;
        
        log("ManeuverDetector counters reset");
    }
    
    // Complete replacement for detectManeuver method in ManeuverDetector.mc
    function detectManeuver(heading, speed, currentTime, isStbdTack, isUpwind, windAngleLessCOG) {
        // Use a lower speed threshold for maneuver detection
        var speedThreshold = 2.0;
        
        // Try to get from settings if available
        try {
            var app = Application.getApp();
            var modelData = null;
            
            // Use the app's modelData getter if available
            if (app has :getModelData) {
                modelData = app.getModelData();
            }
            
            if (modelData != null && modelData.hasKey("settings")) {
                var settings = modelData["settings"];
                if (settings != null && settings.hasKey("foilingThreshold")) {
                    speedThreshold = settings["foilingThreshold"];
                }
            }
        } catch (e) {
            log("Error getting speed threshold: " + e.getErrorMessage());
        }
        
        // Only detect maneuvers above speed threshold
        if (speed < speedThreshold) {
            return false;
        }
        
        var maneuverDetected = false;
        var isTack = false;  // Boolean flag for tack vs gybe
        var oldTack = isStbdTack;
        
        // Get the previous wind angle for comparison
        var lastWindAngleLessCOG = mParent.getAngleCalculator().getLastWindAngleLessCOG();
        
        // Check for tack/gybe based on tack and wind angle thresholds
        if (isStbdTack) {
            // Currently on starboard tack
            if (windAngleLessCOG < -mParent.MANEUVER_THRESHOLD) {
                // Tack to port
                mParent.getAngleCalculator().setStarboardTack(false);
                maneuverDetected = true;
                isTack = true;
                log("Tack changed from Starboard to Port (WindAngle: " + windAngleLessCOG + ")");
            } 
            else if (windAngleLessCOG < (-180 + mParent.MANEUVER_THRESHOLD) && !isUpwind) {
                // Gybe to port
                mParent.getAngleCalculator().setStarboardTack(false);
                maneuverDetected = true;
                isTack = false;
                log("Gybe detected from Starboard to Port (WindAngle: " + windAngleLessCOG + ")");
            }
        } else {
            // Currently on port tack
            if (windAngleLessCOG > mParent.MANEUVER_THRESHOLD) {
                // Tack to starboard
                mParent.getAngleCalculator().setStarboardTack(true);
                maneuverDetected = true;
                isTack = true;
                log("Tack changed from Port to Starboard (WindAngle: " + windAngleLessCOG + ")");
            } 
            else if (windAngleLessCOG > (180 - mParent.MANEUVER_THRESHOLD) && !isUpwind) {
                // Gybe to starboard
                mParent.getAngleCalculator().setStarboardTack(true);
                maneuverDetected = true;
                isTack = false;
                log("Gybe detected from Port to Starboard (WindAngle: " + windAngleLessCOG + ")");
            }
        }
        
        // If maneuver detected, start processing
        if (maneuverDetected) {
            // Determine maneuver type based on previous wind angle
            var lastUpwind = (lastWindAngleLessCOG > -90 && lastWindAngleLessCOG < 90);
            
            // Better classification based on point of sail
            isTack = lastUpwind;  // If upwind, it's a tack; if downwind, it's a gybe
            
            // Increment global display counter
            if (isTack) {
                mDisplayTackCount++;
            } else {
                mDisplayGybeCount++;
            }
            
            // Get the current lap number from the LapTracker
            var lapTracker = mParent.getLapTracker();
            var currentLap = 1; // Default to lap 1
            
            if (lapTracker != null) {
                currentLap = lapTracker.getCurrentLap();
                if (currentLap <= 0) {
                    currentLap = 1; // Ensure valid lap number
                }
            }
            
            // Ensure this lap has entries in our dictionaries
            if (!mLapDisplayTackCounts.hasKey(currentLap)) {
                mLapDisplayTackCounts[currentLap] = 0;
            }
            if (!mLapDisplayGybeCounts.hasKey(currentLap)) {
                mLapDisplayGybeCounts[currentLap] = 0;
            }
            
            // Increment the lap-specific counter
            if (isTack) {
                mLapDisplayTackCounts[currentLap]++;
                
                // Output debug with lap-specific and total counters
                log("Display tack counter incremented to " + mDisplayTackCount + 
                    " (lap " + currentLap + ": " + mLapDisplayTackCounts[currentLap] + ")");
                
                // Update the lap tracker using the lap-specific counters
                if (lapTracker != null) {
                    // Use the correct lap-specific counter for this lap
                    lapTracker.updateManeuverCounts(
                        currentLap, 
                        mLapDisplayTackCounts[currentLap],  // Lap-specific tack count
                        mDisplayTackCount,                  // Total tack count
                        mLapDisplayGybeCounts[currentLap],  // Lap-specific gybe count
                        mDisplayGybeCount                   // Total gybe count
                    );
                }
            } else {
                mLapDisplayGybeCounts[currentLap]++;
                
                // Output debug with lap-specific and total counters
                log("Display gybe counter incremented to " + mDisplayGybeCount + 
                    " (lap " + currentLap + ": " + mLapDisplayGybeCounts[currentLap] + ")");
                
                // Update the lap tracker using the lap-specific counters
                if (lapTracker != null) {
                    // Use the correct lap-specific counter for this lap
                    lapTracker.updateManeuverCounts(
                        currentLap, 
                        mLapDisplayTackCounts[currentLap],  // Lap-specific tack count
                        mDisplayTackCount,                  // Total tack count
                        mLapDisplayGybeCounts[currentLap],  // Lap-specific gybe count
                        mDisplayGybeCount                   // Total gybe count
                    );
                }
            }
            
            log("Maneuver classified as " + (isTack ? "Tack" : "Gybe") + 
                " (was " + (lastUpwind ? "upwind" : "downwind") + 
                ", angle: " + lastWindAngleLessCOG + ")");
            
            // Create pending maneuver record
            mPendingManeuver = {
                "isTack" => isTack,
                "timestamp" => currentTime,
                "lastWindAngle" => lastWindAngleLessCOG,
                "currentWindAngle" => windAngleLessCOG,
                "oldTack" => oldTack,
                "newTack" => !oldTack,
                "lapNumber" => currentLap  // Include lap number in pending maneuver
            };
            
            // Store maneuver timestamp
            mManeuverTimestamp = currentTime;
            
            log("Maneuver detected! Type: " + (isTack ? "Tack" : "Gybe") + 
                ", Timestamp: " + currentTime + ", Lap: " + currentLap);
            
            return true;
        }
        
        return false;
    }
    
    // Check if a maneuver's headings are reliable
    function isReliableManeuver(beforeHeadingData, afterHeadingData) {
        // Extract the headings from the raw data
        var beforeHeadings = beforeHeadingData["headings"];
        var afterHeadings = afterHeadingData["headings"];
        
        // Calculate the max variation in each set
        var beforeVariation = calculateMaxVariation(beforeHeadings);
        var afterVariation = calculateMaxVariation(afterHeadings);
        
        // Define max acceptable variation (e.g., 25 degrees)
        var MAX_ACCEPTABLE_VARIATION = 30.0;
        
        // Log the variations for debugging
        log("Heading variations - before: " + beforeVariation.format("%.1f") + 
            "°, after: " + afterVariation.format("%.1f") + "°");
        
        // Return true if both variations are acceptable
        return (beforeVariation <= MAX_ACCEPTABLE_VARIATION && 
                afterVariation <= MAX_ACCEPTABLE_VARIATION);
    }

    // Helper function to calculate maximum variation in a set of headings
    function calculateMaxVariation(headings) {
        if (headings == null || headings.size() < 2) {
            return 0.0;
        }
        
        var minHeading = 360.0;
        var maxHeading = 0.0;
        
        // Find min and max headings
        for (var i = 0; i < headings.size(); i++) {
            var heading = headings[i];
            if (heading < minHeading) {
                minHeading = heading;
            }
            if (heading > maxHeading) {
                maxHeading = heading;
            }
        }
        
        // Return the range
        return mParent.getAngleCalculator().angleAbsDifference(minHeading, maxHeading);
    }

    // Determine if the heading is in "reaching" mode based on wind angle
    function isReaching(heading, windDirection) {
        // Calculate wind angle
        var windAngle = mParent.getAngleCalculator().angleAbsDifference(heading, windDirection);
        
        // Upwind: 0-70 degrees, Downwind: 110-180 degrees, Reaching: 70-110 degrees
        return (windAngle > 70 && windAngle < 110);
    }

  
    // Fixed recordUnreliableManeuver function in ManeuverDetector.mc
    function recordUnreliableManeuver(isTack, lapNumber) {
        // Extra safety check for lapNumber
        if (lapNumber == null || !(lapNumber instanceof Number) || lapNumber <= 0) {
            System.println("WARNING: Invalid lap number for unreliable maneuver, using lap 1");
            lapNumber = 1; // Default to lap 1
        }
        
        // Create a special maneuver record for unreliable maneuvers
        var maneuver = {
            "isTack" => isTack,
            "heading" => 0,
            "angle" => 0,
            "time" => Time.now().value(),
            "timestamp" => System.getTimer(),
            "lapNumber" => lapNumber,
            "isReliable" => false  // Mark as unreliable
        };
        
        // Do NOT increment reliable counters here
        // We only want to count reliable maneuvers for angle calculations
        
        // First, check if lapTracker exists before trying to use it
        if (mParent == null) {
            System.println("Error: mParent is null in recordUnreliableManeuver");
            return false;
        }
        
        var lapTracker = mParent.getLapTracker();
        if (lapTracker == null) {
            System.println("Error: LapTracker is null in recordUnreliableManeuver");
            return false;
        }
        
        // Record this unreliable maneuver in lap-specific tracking
        var success = lapTracker.recordManeuverInLap(maneuver);
        
        log("Unreliable " + (isTack ? "tack" : "gybe") + " recorded - no angle, lap=" + lapNumber + 
            (success ? " (success)" : " (failed)"));
        return success;
    }

    // Fixed checkPendingManeuvers function with additional safety checks
    function checkPendingManeuvers(currentTime) {
        // If no pending maneuver, return
        if (mPendingManeuver == null || mManeuverTimestamp == 0) {
            return;
        }
        
        // Calculate time since maneuver
        var timeSinceManeuver = currentTime - mManeuverTimestamp;
        
        // Wait until we have enough data after the maneuver
        if (timeSinceManeuver < (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000) {
            return;
        }
        
        try {
            // We have enough data, calculate maneuver angle
            calculateManeuverAngle(mPendingManeuver);
        } catch (e) {
            // Log any errors that occur during calculation
            log("Error in checkPendingManeuvers: " + e.getErrorMessage());
        }
        
        // Clear pending maneuver
        mPendingManeuver = null;
    }

    // Fixed calculateManeuverAngle function with better angle calculation
    function calculateManeuverAngle(pendingManeuver) {
        // Safety check for null
        if (pendingManeuver == null) {
            log("Error: pendingManeuver is null in calculateManeuverAngle");
            return;
        }
        
        // Get required values with safety checks
        var maneuverTimestamp = 0;
        var isTack = true;
        var lapNumber = 1;
        
        if (pendingManeuver.hasKey("timestamp") && pendingManeuver["timestamp"] != null) {
            maneuverTimestamp = pendingManeuver["timestamp"];
        }
        
        if (pendingManeuver.hasKey("isTack")) {
            isTack = pendingManeuver["isTack"];
        }
        
        if (pendingManeuver.hasKey("lapNumber") && pendingManeuver["lapNumber"] != null && 
            pendingManeuver["lapNumber"] instanceof Number) {
            lapNumber = pendingManeuver["lapNumber"];
        }
        
        log("Calculating " + (isTack ? "tack" : "gybe") + " angle at timestamp " + 
            (maneuverTimestamp/1000) + "s for lap " + lapNumber);
        
        // Calculate time periods for measurement
        var beforeStart = maneuverTimestamp - (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        var beforeEnd = maneuverTimestamp - MAN_ANGLE_TIME_IGNORE * 1000;
        
        // Use same ignore period after the maneuver
        var afterStart = maneuverTimestamp + MAN_ANGLE_TIME_IGNORE * 1000;
        var afterEnd = maneuverTimestamp + (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        
        log("Time windows: before [" + (beforeStart/1000) + "-" + (beforeEnd/1000) + 
            "], ignore [" + (beforeEnd/1000) + "-" + (afterStart/1000) + 
            "], after [" + (afterStart/1000) + "-" + (afterEnd/1000) + "]");
        
        try {
            // Calculate headings before and after maneuver using weighted average
            var beforeHeadingData = mParent.getAngleCalculator().calculateWeightedAverageHeading(beforeStart, beforeEnd, true);
            var afterHeadingData = mParent.getAngleCalculator().calculateWeightedAverageHeading(afterStart, afterEnd, false);
            
            // If we don't have enough data, record as unreliable maneuver
            if (beforeHeadingData == null || afterHeadingData == null) {
                log("Cannot calculate " + (isTack ? "tack" : "gybe") + 
                    " angle - insufficient heading history data");
                    
                // Record an unreliable maneuver with no angle
                recordUnreliableManeuver(isTack, lapNumber);
                return;
            }
            
            // Extract the averages
            var beforeHeading = beforeHeadingData["average"];
            var afterHeading = afterHeadingData["average"];
            
            // Check if the maneuver is reliable based on heading variations
            var isReliable = isReliableManeuver(beforeHeadingData, afterHeadingData);
            if (!isReliable) {
                log("Rejecting unreliable " + (isTack ? "tack" : "gybe") + 
                    " - excessive heading variation");
                    
                // Record an unreliable maneuver with no angle
                recordUnreliableManeuver(isTack, lapNumber);
                return;
            }
            
            // Calculate the maneuver angle (ensure we're getting absolute difference)
            var maneuverAngle = mParent.getAngleCalculator().angleAbsDifference(beforeHeading, afterHeading);
            
            // Log the calculation details for debugging
            log("Calculated " + (isTack ? "tack" : "gybe") + " angle: " + maneuverAngle + 
                "° (from " + beforeHeading + "° to " + afterHeading + "°)");
            
            // Update the last angle based on maneuver type
            if (isTack) {
                mLastTackAngle = maneuverAngle;
                mLastTackHeadings = [beforeHeading, afterHeading];
                mTackCount++;
            } else {
                mLastGybeAngle = maneuverAngle;
                mLastGybeHeadings = [beforeHeading, afterHeading];
                mGybeCount++;
            }
            
            // Record the maneuver in history with the angle
            recordManeuver(isTack, beforeHeading, maneuverAngle, lapNumber);
            
            log("Successfully recorded " + (isTack ? "tack" : "gybe") + 
                " with angle " + maneuverAngle + "°");
            
        } catch (e) {
            // Log any errors
            log("Error in calculateManeuverAngle: " + e.getErrorMessage());
            
            // Record as unreliable due to error
            recordUnreliableManeuver(isTack, lapNumber);
        }
    }

    // Add this method to reset lap-specific counters for a new lap
    function resetLapCounters() {
        var lapTracker = mParent.getLapTracker();
        var newLapNumber = 1;
        
        if (lapTracker != null) {
            newLapNumber = lapTracker.getCurrentLap();
            if (newLapNumber <= 0) {
                newLapNumber = 1;
            }
        }
        
        // Ensure entry exists for this lap
        if (!mLapDisplayTackCounts.hasKey(newLapNumber)) {
            mLapDisplayTackCounts[newLapNumber] = 0;
        }
        if (!mLapDisplayGybeCounts.hasKey(newLapNumber)) {
            mLapDisplayGybeCounts[newLapNumber] = 0;
        }
        
        // Reset counts for this lap to zero
        mLapDisplayTackCounts[newLapNumber] = 0;
        mLapDisplayGybeCounts[newLapNumber] = 0;
        
        // Update the lap tracker with the reset counters
        if (lapTracker != null) {
            lapTracker.updateManeuverCounts(
                newLapNumber,
                mLapDisplayTackCounts[newLapNumber],  // Reset to 0
                mDisplayTackCount,                    // Keep total
                mLapDisplayGybeCounts[newLapNumber],  // Reset to 0
                mDisplayGybeCount                     // Keep total
            );
        }
        
        log("Reset lap-specific counters for lap " + newLapNumber + 
            ". Totals remain: Tacks=" + mDisplayTackCount + 
            ", Gybes=" + mDisplayGybeCount);
    }
    
    function recordManeuver(isTack, heading, angle, lapNumber) {
        // Create maneuver record
        var maneuver = {
            "isTack" => isTack,
            "heading" => heading,
            "angle" => angle,
            "time" => Time.now().value(),
            "timestamp" => System.getTimer(),
            "lapNumber" => lapNumber,
            "isReliable" => true
        };
        
        // Calculate index in history array
        var index = isTack ? (mTackCount - 1) : (mGybeCount - 1);
        
        // Store in history if index is valid
        if (index >= 0 && index < mParent.MAX_MANEUVERS) {
            mManeuverHistory[index] = maneuver;
            
            // Add to lap-specific maneuvers if lap tracking is active
            mParent.getLapTracker().recordManeuverInLap(maneuver);
            
            // Update statistics
            updateManeuverStats();
            
            // Update current lap with the new maneuver angles
            if (mParent != null && mParent.getLapTracker() != null) {
                // Update lap stats with the latest angles
                mParent.getLapTracker().updateManeuverAngles(
                    lapNumber,  // Use passed lap number
                    mManeuverStats["avgTackAngle"],
                    mManeuverStats["avgGybeAngle"],
                    mManeuverStats["maxTackAngle"],
                    mManeuverStats["maxGybeAngle"]
                );
            }
            
            log("Recorded " + (isTack ? "tack" : "gybe") + " with angle " + 
                angle.format("%.1f") + "° in history at index " + index);
            
            return true;
        }
        
        log("Failed to record maneuver in history - invalid index: " + index);
        return false;
    }
    
    // Update maneuver statistics
    function updateManeuverStats() {
        var tackCount = 0;
        var gybeCount = 0;
        var tackSum = 0;
        var gybeSum = 0;
        var maxTack = 0;
        var maxGybe = 0;
        
        // Loop through history and calculate stats
        for (var i = 0; i < mParent.MAX_MANEUVERS; i++) {
            if (mManeuverHistory[i] != null) {
                var maneuver = mManeuverHistory[i];
                
                if (maneuver["isTack"]) {
                    tackCount++;
                    tackSum += maneuver["angle"];
                    if (maneuver["angle"] > maxTack) {
                        maxTack = maneuver["angle"];
                    }
                } else {
                    gybeCount++;
                    gybeSum += maneuver["angle"];
                    if (maneuver["angle"] > maxGybe) {
                        maxGybe = maneuver["angle"];
                    }
                }
            }
        }
        
        // Calculate averages
        var avgTack = (tackCount > 0) ? tackSum / tackCount : 0;
        var avgGybe = (gybeCount > 0) ? gybeSum / gybeCount : 0;
        
        // Update stats
        mManeuverStats = {
            "avgTackAngle" => avgTack,
            "avgGybeAngle" => avgGybe,
            "maxTackAngle" => maxTack,
            "maxGybeAngle" => maxGybe
        };
    }
    
    // Get recommended wind direction based on maneuvers
    function getRecommendedWindDirection() {
        var shouldUpdate = false;
        var newWindDirection = mParent.getWindDirection();
        
        // Check if we have two consecutive tacks
        if (mTackCount >= 2) {
            var heading1 = mLastTackHeadings[0];
            var heading2 = mLastTackHeadings[1];
            
            if (heading1 != 0 && heading2 != 0) {
                // Calculate bisector angle between tack headings
                var bisector = mParent.getAngleCalculator().calculateBisectorAngle(heading1, heading2);
                newWindDirection = bisector;
                
                log("Auto wind calculation from tacks:");
                log("- Heading 1: " + heading1 + "°");
                log("- Heading 2: " + heading2 + "°");
                log("- Calculated bisector: " + bisector + "°");
                
                // Check if significantly different (> 120°)
                var windDiff = mParent.getAngleCalculator().angleAbsDifference(newWindDirection, mParent.getWindDirection());
                if (windDiff > 120) {
                    // Adjust by 180° to get correct orientation
                    newWindDirection = mParent.getAngleCalculator().normalizeAngle(newWindDirection + 180);
                    log("- Wind direction adjusted by 180° due to large difference");
                }
                
                shouldUpdate = true;
            }
        }
        // Or check if we have two consecutive gybes
        else if (mGybeCount >= 2) {
            var heading1 = mLastGybeHeadings[0];
            var heading2 = mLastGybeHeadings[1];
            
            if (heading1 != 0 && heading2 != 0) {
                // Calculate bisector, then add 180° for downwind
                var bisector = mParent.getAngleCalculator().calculateBisectorAngle(heading1, heading2);
                newWindDirection = mParent.getAngleCalculator().normalizeAngle(bisector + 180);
                
                log("Auto wind calculation from gybes:");
                log("- Heading 1: " + heading1 + "°");
                log("- Heading 2: " + heading2 + "°");
                log("- Calculated bisector: " + bisector + "°");
                log("- Wind direction (bisector + 180°): " + newWindDirection + "°");
                
                // Check if significantly different (> 120°)
                var windDiff = mParent.getAngleCalculator().angleAbsDifference(newWindDirection, mParent.getWindDirection());
                if (windDiff > 120) {
                    // Adjust by 180° to get correct orientation
                    newWindDirection = mParent.getAngleCalculator().normalizeAngle(newWindDirection + 180);
                    log("- Wind direction adjusted by 180° due to large difference");
                }
                
                shouldUpdate = true;
            }
        }
        
        return {
            "updateNeeded" => shouldUpdate,
            "direction" => newWindDirection
        };
    }
    
    // Accessors
    function getTackCount() {
        return mTackCount;
    }
    
    function getGybeCount() {
        return mGybeCount;
    }
    
    function getLastTackAngle() {
        return mLastTackAngle;
    }
    
    function getLastGybeAngle() {
        return mLastGybeAngle;
    }
    
    function getManeuverStats() {
        return mManeuverStats;
    }
    
    // Update the getData method to include display counters and lap-specific counters
    function getData() {
        var lapTracker = mParent.getLapTracker();
        var currentLap = 1;
        
        if (lapTracker != null) {
            currentLap = lapTracker.getCurrentLap();
            if (currentLap <= 0) {
                currentLap = 1;
            }
        }
        
        // Ensure entries exist for the current lap
        if (!mLapDisplayTackCounts.hasKey(currentLap)) {
            mLapDisplayTackCounts[currentLap] = 0;
        }
        if (!mLapDisplayGybeCounts.hasKey(currentLap)) {
            mLapDisplayGybeCounts[currentLap] = 0;
        }
        
        return {
            "tackCount" => mTackCount,
            "gybeCount" => mGybeCount,
            "displayTackCount" => mDisplayTackCount,        // Display counter for all tacks
            "displayGybeCount" => mDisplayGybeCount,        // Display counter for all gybes
            "lapDisplayTackCount" => mLapDisplayTackCounts[currentLap],  // Lap-specific display tack count
            "lapDisplayGybeCount" => mLapDisplayGybeCounts[currentLap],  // Lap-specific display gybe count
            "lastTackAngle" => mLastTackAngle,
            "lastGybeAngle" => mLastGybeAngle,
            "maneuverStats" => mManeuverStats,
            "maneuverHistory" => mManeuverHistory
        };
    }
}