// WindTrackerBase.mc - Core functionality for WindTracker
using Toybox.System;
using Toybox.Lang;
using Toybox.Time;

// Debug mode flag
const DEBUG_MODE = true;  // Set to false for production builds

// Helper function for debug logging
function log(message) {
    if (DEBUG_MODE) {
        System.println(message);
    }
}

// Core WindTracker class
class WindTracker {
    // Constants (shared across component classes)
    const HEADING_BUFFER_SIZE = 10;         // Size of heading buffer
    const MANEUVER_THRESHOLD = 10;          // Threshold angle for maneuvers
    const MAX_MANEUVERS = 100;              // Maximum number of maneuvers to track
    
    // Core properties
    private var mWindDirection;             // Current wind direction (degrees)
    private var mInitialWindDirection;      // User-specified initial wind direction
    private var mAutoWindDetection;         // Whether auto wind direction is active
    private var mWindDirectionLocked;       // Whether wind direction is locked
    private var mLastSignificantHeading;    // Last significant heading
    private var mLastLogTime = 0;           // Time of last debug log
    
    // Components
    private var mAngleCalculator;           // Angle calculation component
    private var mManeuverDetector;          // Maneuver detection component
    private var mLapTracker;                // Lap tracking component 
    private var mVMGCalculator;             // VMG calculation component

    // Add to existing member variables in the WindTracker class
    private var mManualResetTime;          // Timestamp when manual wind reset was performed
    private var mWaitingForNewManeuvers;   // Flag to indicate we're waiting for new maneuvers after reset
    
    // Constructor - Initialize the WindTracker
    function initialize() {
        resetData();
        
        // Initialize components
        mAngleCalculator = new WindAngleCalculator(self);
        mManeuverDetector = new ManeuverDetector(self);
        mLapTracker = new LapTracker(self);
        mVMGCalculator = new VMGCalculator(self);
        
        log("WindTracker initialized with all components");
    }
    
    // Reset all data to initial state
    function resetData() {
        mWindDirection = 0;
        mInitialWindDirection = 0;
        mAutoWindDetection = false;
        mWindDirectionLocked = false;
        mLastSignificantHeading = 0;
        mLastLogTime = 0;
        mManualResetTime = 0;
        mWaitingForNewManeuvers = false;
        
        // Reset components if they exist
        if (mAngleCalculator != null) { mAngleCalculator.reset(); }
        if (mManeuverDetector != null) { mManeuverDetector.reset(); }
        if (mLapTracker != null) { mLapTracker.reset(); }
        if (mVMGCalculator != null) { mVMGCalculator.reset(); }
        
        log("WindTracker data reset");
    }
    
    // Set initial wind direction from user input
    function setInitialWindDirection(angle) {
        mInitialWindDirection = angle;
        mWindDirection = angle;
        mAutoWindDetection = false;
        mLastSignificantHeading = 0;
        
        // Reset maneuver tracking
        if (mManeuverDetector != null) {
            mManeuverDetector.resetManeuverCounts();
        }
        
        log("Initial wind direction set to: " + angle);
    }
    
    // Complete replacement for resetToManualDirection in WindTracker.mc
    function resetToManualDirection() {
        mWindDirection = mInitialWindDirection;
        mAutoWindDetection = false;
        mWindDirectionLocked = false;
        
        // Set timestamp of manual reset
        mManualResetTime = System.getTimer();
        
        // We're now waiting for new maneuvers
        mWaitingForNewManeuvers = true;
        
        // Reset counters used for auto detection
        if (mManeuverDetector != null) {
            // Reset counters used for auto detection, but preserve displayed counters
            mManeuverDetector.resetAutoDetectionCounters();
        }
        
        log("Reset to manual wind direction: " + mInitialWindDirection + 
            " (waiting for new maneuvers for auto detection)");
    }
    
    // Lock/unlock wind direction
    function lockWindDirection() {
        mWindDirectionLocked = true;
        log("Wind direction locked at: " + mWindDirection);
    }
    
    function unlockWindDirection() {
        mWindDirectionLocked = false;
        log("Wind direction unlocked");
    }
    
    // Main processing function for position data - with improved logging
    function processPositionData(info) {
        // Ensure we have valid data
        if (info == null || !(info has :heading) || !(info has :speed) || 
            info.heading == null || info.speed == null) {
            return;
        }
        
        // Extract heading and speed from position info
        var heading = info.heading.toFloat();
        var speed = info.speed * 1.943844; // Convert m/s to knots
        
        // Convert heading from radians to degrees if needed
        if (heading < 2 * Math.PI) {
            heading = Math.toDegrees(heading);
        }
        
        // Store recent headings for debugging - log every 5 seconds
        var currentTime = System.getTimer();
        if (currentTime - mLastLogTime > 5000) {
            log("Raw heading: " + heading.format("%.1f") + "°, speed: " + speed.format("%.1f") + " kt");
            mLastLogTime = currentTime;
        }
        
        // Process with angle calculator
        heading = mAngleCalculator.processHeading(heading, currentTime);
        
        // Get current tack and point of sail state
        var isStbdTack = mAngleCalculator.isStarboardTack();
        var isUpwind = mAngleCalculator.isUpwind();
        var windAngleLessCOG = mAngleCalculator.getWindAngleLessCOG();
        
        // Check for maneuvers if we have previous data
        if (mAngleCalculator.hasPreviousData()) {
            // Detect maneuvers
            mManeuverDetector.detectManeuver(heading, speed, currentTime, 
                isStbdTack, isUpwind, windAngleLessCOG);
            
            // Check pending maneuvers
            mManeuverDetector.checkPendingManeuvers(currentTime);
        }
        
        // Calculate VMG
        mVMGCalculator.calculateVMG(heading, speed, isUpwind, windAngleLessCOG);
        
        // Update lap statistics
        mLapTracker.processData(info, speed, isUpwind, currentTime);
        
        // Update auto wind direction (uses results from maneuver detection)
        updateAutoWindDirection();
        
        // Update last significant heading
        if (mLastSignificantHeading == 0) {
            mLastSignificantHeading = heading;
        }
    }

    // Accessor for waiting flag
    function isWaitingForNewManeuvers() {
        return mWaitingForNewManeuvers;
    }

    // Clear waiting flag
    function clearWaitingForNewManeuvers() {
        mWaitingForNewManeuvers = false;
    }

    // Update wind direction automatically based on tack/gybe patterns
    function updateAutoWindDirection() {
        // Skip if wind direction is locked
        if (mWindDirectionLocked) {
            return;
        }
        
        // Skip auto detection for a period after manual reset (30 seconds)
        var currentTime = System.getTimer();
        if (currentTime - mManualResetTime < 30000) {
            return;
        }
        
        // Skip if we're waiting for new maneuvers after a reset
        if (mWaitingForNewManeuvers) {
            return;
        }
        
        // Ask maneuver detector for new wind direction recommendation
        var windDirectionInfo = mManeuverDetector.getRecommendedWindDirection();
        
        // Update if we have valid new direction
        if (windDirectionInfo != null && windDirectionInfo.hasKey("updateNeeded") && 
            windDirectionInfo["updateNeeded"]) {
            
            mWindDirection = windDirectionInfo["direction"];
            mAutoWindDetection = true;
            log("Auto wind direction updated to: " + mWindDirection);
            
            // Recalculate wind angles with new direction
            mAngleCalculator.recalculateWithNewWindDirection(mWindDirection);
        }
    }
    
    function onLapMarked(position) {
        // Tell the LapTracker about the lap
        var lapResult = mLapTracker.onLapMarked(position);
        
        // Reset lap-specific maneuver counters, but keep total counters
        if (mManeuverDetector != null) {
            mManeuverDetector.resetLapCounters();
        }
        
        log("Lap marked in WindTracker - lap number: " + lapResult);
        
        return lapResult;
    }
    
    // In the getWindData function, add display counters
    function getWindData() {
        // Get data from components
        var angleData = mAngleCalculator.getData();
        var maneuverData = mManeuverDetector.getData();
        var vmgData = mVMGCalculator.getData();
        
        // Create consolidated wind data
        var windData = {
            // Core properties
            "windDirection" => mWindDirection,
            "initialWindDirection" => mInitialWindDirection,
            "autoWindDetection" => mAutoWindDetection,
            "windDirectionLocked" => mWindDirectionLocked,
            
            // Flag to indicate valid data
            "valid" => true
        };
        
        // Add data from components
        try {
            // Add angle calculator data
            if (angleData != null) {
                windData.put("windAngleLessCOG", angleData["windAngleLessCOG"]);
                windData.put("currentTack", angleData["currentTack"]);
                windData.put("currentPointOfSail", angleData["currentPointOfSail"]);
                windData.put("tackDisplayText", angleData["tackDisplayText"]);
                windData.put("tackColorId", angleData["tackColorId"]);
            }
            
            // Add maneuver detector data
            if (maneuverData != null) {
                windData.put("tackCount", maneuverData["tackCount"]);
                windData.put("gybeCount", maneuverData["gybeCount"]);
                windData.put("displayTackCount", maneuverData["displayTackCount"]);
                windData.put("displayGybeCount", maneuverData["displayGybeCount"]);
                windData.put("lapDisplayTackCount", maneuverData["lapDisplayTackCount"]);
                windData.put("lapDisplayGybeCount", maneuverData["lapDisplayGybeCount"]);
                windData.put("lastTackAngle", maneuverData["lastTackAngle"]);
                windData.put("lastGybeAngle", maneuverData["lastGybeAngle"]);
                windData.put("maneuverStats", maneuverData["maneuverStats"]);
            }
            
            // Add VMG calculator data
            if (vmgData != null) {
                windData.put("currentVMG", vmgData["currentVMG"]);
            }
        } catch (ex) {
            log("Error in getWindData: " + ex.getErrorMessage());
        }
        
        return windData;
    }
    
    // Get lap-specific data for lap markers
    function getLapData() {
        return mLapTracker.getLapData();
    }
    
    // Accessor methods for components to access WindTracker properties
    function getWindDirection() {
        return mWindDirection;
    }
    
    function getInitialWindDirection() {
        return mInitialWindDirection;
    }
    
    function isAutoWindDetection() {
        return mAutoWindDetection;
    }
    
    function isWindDirectionLocked() {
        return mWindDirectionLocked;
    }
    
    function getLastSignificantHeading() {
        return mLastSignificantHeading;
    }
    
    // Accessor methods for components to access other components
    function getAngleCalculator() {
        return mAngleCalculator;
    }
    
    function getManeuverDetector() {
        return mManeuverDetector;
    }
    
    function getLapTracker() {
        return mLapTracker;
    }
    
    function getVMGCalculator() {
        return mVMGCalculator;
    }
    
    // Setter methods for properties
    function setWindDirectionValue(value) {
        mWindDirection = value;
    }
    
    function setInitialWindDirectionValue(value) {
        mInitialWindDirection = value;
    }
    
    function setAutoWindDetection(value) {
        mAutoWindDetection = value;
    }
    
    function setWindDirectionLocked(value) {
        mWindDirectionLocked = value;
    }
    
    function setLastSignificantHeading(value) {
        mLastSignificantHeading = value;
    }

}