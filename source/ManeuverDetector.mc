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

    // Add these member variables to ManeuverDetector class
    private var mDisplayTackCount;       // Count of tacks for display (including unreliable ones)
    private var mDisplayGybeCount;       // Count of gybes for display (including unreliable ones)
    private var mCurrentLapDisplayTackCount;  // Lap-specific display tack count
    private var mCurrentLapDisplayGybeCount;  // Lap-specific display gybe count   
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }
    
    // Update the reset function to initialize the new counters
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
        mCurrentLapDisplayTackCount = 0;
        mCurrentLapDisplayGybeCount = 0;
        
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
        mCurrentLapDisplayTackCount = 0;
        mCurrentLapDisplayGybeCount = 0;
        
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
            
            // Increment display counter immediately
            if (isTack) {
                mDisplayTackCount++;
                mCurrentLapDisplayTackCount++;
                
                // Update the lap tracker using the public method instead of accessing mLapStats directly
                var lapTracker = mParent.getLapTracker();
                if (lapTracker != null) {
                    var currentLap = lapTracker.getCurrentLap();
                    if (currentLap > 0) {
                        // Use the public method to update counters
                        lapTracker.updateManeuverCounts(
                            currentLap, 
                            mCurrentLapDisplayTackCount, 
                            mDisplayTackCount,
                            mCurrentLapDisplayGybeCount,
                            mDisplayGybeCount
                        );
                    }
                }
                
                log("Display tack counter incremented to " + mDisplayTackCount + 
                    " (lap: " + mCurrentLapDisplayTackCount + ")");
            } else {
                mDisplayGybeCount++;
                mCurrentLapDisplayGybeCount++;
                
                // Update the lap tracker using the public method instead of accessing mLapStats directly
                var lapTracker = mParent.getLapTracker();
                if (lapTracker != null) {
                    var currentLap = lapTracker.getCurrentLap();
                    if (currentLap > 0) {
                        // Use the public method to update counters
                        lapTracker.updateManeuverCounts(
                            currentLap, 
                            mCurrentLapDisplayTackCount, 
                            mDisplayTackCount,
                            mCurrentLapDisplayGybeCount,
                            mDisplayGybeCount
                        );
                    }
                }
                
                log("Display gybe counter incremented to " + mDisplayGybeCount + 
                    " (lap: " + mCurrentLapDisplayGybeCount + ")");
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
                "newTack" => !oldTack
            };
            
            // Store maneuver timestamp
            mManeuverTimestamp = currentTime;
            
            log("Maneuver detected! Type: " + (isTack ? "Tack" : "Gybe") + 
                ", Timestamp: " + currentTime);
            
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
        var MAX_ACCEPTABLE_VARIATION = 25.0;
        
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

    // Check for pending maneuvers that need angle calculation
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
        
        // We have enough data, calculate maneuver angle
        calculateManeuverAngle(mPendingManeuver);
        
        // Clear pending maneuver
        mPendingManeuver = null;
    }
    
    // New function to record unreliable maneuvers
    function recordUnreliableManeuver(isTack, lapNumber) {
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
        
        // Record this unreliable maneuver in lap-specific tracking
        mParent.getLapTracker().recordManeuverInLap(maneuver);
        
        log("Unreliable " + (isTack ? "tack" : "gybe") + " recorded - no angle, lap=" + lapNumber);
    }

    // Modified calculateManeuverAngle function to handle unreliable maneuvers
    function calculateManeuverAngle(pendingManeuver) {
        var maneuverTimestamp = pendingManeuver["timestamp"];
        var isTack = pendingManeuver["isTack"];
        
        log("Calculating " + (isTack ? "tack" : "gybe") + " angle at timestamp " + (maneuverTimestamp/1000) + "s");
        
        // Calculate time periods for measurement
        var beforeStart = maneuverTimestamp - (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        var beforeEnd = maneuverTimestamp - MAN_ANGLE_TIME_IGNORE * 1000;
        
        // Use same ignore period after the maneuver
        var afterStart = maneuverTimestamp + MAN_ANGLE_TIME_IGNORE * 1000;
        var afterEnd = maneuverTimestamp + (MAN_ANGLE_TIME_MEASURE + MAN_ANGLE_TIME_IGNORE) * 1000;
        
        log("Time windows: before [" + (beforeStart/1000) + "-" + (beforeEnd/1000) + 
            "], ignore [" + (beforeEnd/1000) + "-" + (afterStart/1000) + 
            "], after [" + (afterStart/1000) + "-" + (afterEnd/1000) + "]");
        
        // Calculate headings before and after maneuver using weighted average
        var beforeHeadingData = mParent.getAngleCalculator().calculateWeightedAverageHeading(beforeStart, beforeEnd, true);
        var afterHeadingData = mParent.getAngleCalculator().calculateWeightedAverageHeading(afterStart, afterEnd, false);
        
        // Get current lap before processing the maneuver
        var currentLap = mParent.getLapTracker().getCurrentLap();
        
        // If we don't have enough data, record as unreliable maneuver
        if (beforeHeadingData == null || afterHeadingData == null) {
            log("Cannot calculate " + (isTack ? "tack" : "gybe") + 
                " angle - insufficient heading history data");
                
            // Record an unreliable maneuver with no angle
            recordUnreliableManeuver(isTack, currentLap);
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
            recordUnreliableManeuver(isTack, currentLap);
            return;
        }
        
        // Get current wind direction
        var windDirection = mParent.getWindDirection();
        
        // Check if both before and after headings are in "reaching" mode
        var beforeReaching = isReaching(beforeHeading, windDirection);
        var afterReaching = isReaching(afterHeading, windDirection);
        
        // Calculate maneuver angle - simple COG-based approach for both tacks and gybes
        var maneuverAngle = mParent.getAngleCalculator().angleAbsDifference(beforeHeading, afterHeading);
        
        log("Maneuver Angle: before=" + beforeHeading + "°, after=" + afterHeading + 
            "°, diff=" + maneuverAngle + "°, type=" + (isTack ? "Tack" : "Gybe") +
            ", reaching=" + (beforeReaching && afterReaching));
        
        // After calculating maneuverAngle, find the section for isTack and !isTack:

        if (isTack) {
            // Increment tack counter
            mTackCount += 1;
            
            // Update last tack angle
            mLastTackAngle = maneuverAngle;
            
            // Only update wind direction if not in reaching mode on both sides
            if (!(beforeReaching && afterReaching)) {
                // Record tack headings for auto wind calculation
                mLastTackHeadings[0] = mLastTackHeadings[1];
                mLastTackHeadings[1] = afterHeading;
                log("Updated tack headings for wind calculation");
            } else {
                log("Both headings in reaching mode - not updating wind direction");
            }
            
            // Record maneuver in history
            recordManeuver(true, afterHeading, maneuverAngle);
            
            // Directly notify lap tracker of this tack with proper angle and current lap
            currentLap = mParent.getLapTracker().getCurrentLap();
            mParent.getLapTracker().recordManeuverInLap({
                "isTack" => true,
                "heading" => afterHeading,
                "angle" => maneuverAngle,
                "time" => Time.now().value(),
                "timestamp" => System.getTimer(),
                "lapNumber" => currentLap,
                "isReliable" => true
            });
            
            // Update maneuver angles in lap stats
            if (mParent != null && mParent.getLapTracker() != null) {
                // Get maneuver stats to update lap data
                var avgTackAngle = mManeuverStats["avgTackAngle"];
                var avgGybeAngle = mManeuverStats["avgGybeAngle"];
                var maxTackAngle = mManeuverStats["maxTackAngle"];
                var maxGybeAngle = mManeuverStats["maxGybeAngle"];
                
                // Update lap stats with angles
                mParent.getLapTracker().updateManeuverAngles(
                    currentLap,
                    avgTackAngle,
                    avgGybeAngle,
                    maxTackAngle,
                    maxGybeAngle
                );
            }
            
            log("Tack #" + mTackCount + " recorded: angle=" + maneuverAngle + "°, lap=" + currentLap);
        } else {
            // Increment gybe counter
            mGybeCount += 1;
            
            // Update last gybe angle
            mLastGybeAngle = maneuverAngle;
            
            // Only update wind direction if not in reaching mode on both sides
            if (!(beforeReaching && afterReaching)) {
                // Record gybe headings for auto wind calculation
                mLastGybeHeadings[0] = mLastGybeHeadings[1];
                mLastGybeHeadings[1] = afterHeading;
                log("Updated gybe headings for wind calculation");
            } else {
                log("Both headings in reaching mode - not updating wind direction");
            }
            
            // Record maneuver in history
            recordManeuver(false, afterHeading, maneuverAngle);
            
            // Directly notify lap tracker of this gybe with proper angle and current lap
            currentLap = mParent.getLapTracker().getCurrentLap();
            mParent.getLapTracker().recordManeuverInLap({
                "isTack" => false,
                "heading" => afterHeading,
                "angle" => maneuverAngle,
                "time" => Time.now().value(),
                "timestamp" => System.getTimer(),
                "lapNumber" => currentLap,
                "isReliable" => true
            });
            
            // Update maneuver angles in lap stats
            if (mParent != null && mParent.getLapTracker() != null) {
                // Get maneuver stats to update lap data
                var avgTackAngle = mManeuverStats["avgTackAngle"];
                var avgGybeAngle = mManeuverStats["avgGybeAngle"];
                var maxTackAngle = mManeuverStats["maxTackAngle"];
                var maxGybeAngle = mManeuverStats["maxGybeAngle"];
                
                // Update lap stats with angles
                mParent.getLapTracker().updateManeuverAngles(
                    currentLap,
                    avgTackAngle,
                    avgGybeAngle,
                    maxTackAngle,
                    maxGybeAngle
                );
            }
            
            log("Gybe #" + mGybeCount + " recorded: angle=" + maneuverAngle + "°, lap=" + currentLap);
        }
    }

    // Add this method to ManeuverDetector.mc
    function resetLapCounters() {
        // Reset lap-specific counters only
        mCurrentLapDisplayTackCount = 0;
        mCurrentLapDisplayGybeCount = 0;
        
        // Update the current lap's stats with the reset counters
        if (mParent != null && mParent.getLapTracker() != null) {
            var lapTracker = mParent.getLapTracker();
            var currentLap = lapTracker.getCurrentLap();
            
            if (currentLap > 0) {
                // Update the lap statistics with zeros for the lap counters
                // but preserve the display counters that show total
                lapTracker.updateManeuverCounts(
                    currentLap,
                    0,  // Reset lap tack count
                    mDisplayTackCount,  // Keep total tack count
                    0,  // Reset lap gybe count
                    mDisplayGybeCount   // Keep total gybe count
                );
            }
        }
        
        log("Reset lap-specific tack/gybe counters. Totals remain: Tacks=" + 
            mDisplayTackCount + ", Gybes=" + mDisplayGybeCount);
    }

    // Add reset method for lap-specific display counters
    function resetLapDisplayCounters() {
        mCurrentLapDisplayTackCount = 0;
        mCurrentLapDisplayGybeCount = 0;
        log("Lap-specific display counters reset");
    }

    function resetTackGybeCountsForLap() {
        log("Resetting tack/gybe counts for new lap");
        
        // We don't reset mTackCount and mGybeCount because they're used 
        // for wind direction calculation and overall session statistics
        
        // Instead, we rely on lap-specific tracking in LapTracker
        // which initializes new counts for each lap in its onLapMarked method
    }
    
    // Complete replacement for recordManeuver method in ManeuverDetector.mc
    function recordManeuver(isTack, heading, angle) {
        // Create maneuver record
        var maneuver = {
            "isTack" => isTack,
            "heading" => heading,
            "angle" => angle,
            "time" => Time.now().value(),
            "timestamp" => System.getTimer(),
            "lapNumber" => mParent.getLapTracker().getCurrentLap()
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
                var currentLap = mParent.getLapTracker().getCurrentLap();
                
                // Update lap stats with the latest angles
                mParent.getLapTracker().updateManeuverAngles(
                    currentLap,
                    mManeuverStats["avgTackAngle"],
                    mManeuverStats["avgGybeAngle"],
                    mManeuverStats["maxTackAngle"],
                    mManeuverStats["maxGybeAngle"]
                );
            }
        }
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
    
    // Update the getData method to include display counters
    function getData() {
        return {
            "tackCount" => mTackCount,
            "gybeCount" => mGybeCount,
            "displayTackCount" => mDisplayTackCount,        // Display counter for all tacks
            "displayGybeCount" => mDisplayGybeCount,        // Display counter for all gybes
            "lapDisplayTackCount" => mCurrentLapDisplayTackCount,  // Lap-specific display tack count
            "lapDisplayGybeCount" => mCurrentLapDisplayGybeCount,  // Lap-specific display gybe count
            "lastTackAngle" => mLastTackAngle,
            "lastGybeAngle" => mLastGybeAngle,
            "maneuverStats" => mManeuverStats,
            "maneuverHistory" => mManeuverHistory
        };
    }
}