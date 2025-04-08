// VMGCalculator.mc - Handles VMG calculations with improved vibration alerts
using Toybox.Math;
using Toybox.System;
using Toybox.Attention;
using Toybox.Application;

class VMGCalculator {
    // Constants
    private const VMG_SMOOTHING_FACTOR = 0.1;  // Smoothing factor for VMG
    private const VMG_POINTS_SIZE = 3;         // Track last 3 VMG values for averaging
    
    // Vibration constants
    private const VMG_VIBRATION_THRESHOLD = 13.0;    // Default threshold if no target set
    private const VIBRATION_COOLDOWN = 3000;         // 3 second cooldown between vibrations (in ms)
    
    // Properties
    private var mParent;              // Reference to WindTracker parent
    private var mCurrentVMG;          // Current velocity made good (knots)
    private var mSessionMaxVMGUp;     // Track max VMG upwind for the session
    private var mSessionMaxVMGDown;   // Track max VMG downwind for the session
    private var mVMGPoints;           // Array to store recent VMG points
    private var mVMGPointIndex;       // Current index in VMG points array
    
    // New vibration tracking properties
    private var mLastVMGAlertTime;    // Time of last VMG above target alert
    private var mLastMaxVMGAlertTime; // Time of last max VMG alert
    private var mTargetUpwindVMG;     // Target upwind VMG from settings
    
    // Initialize
    function initialize(parent) {
        mParent = parent;
        reset();
    }

    // Reset with full initialization of tracking properties
    function reset() {
        mCurrentVMG = 0.0;
        mSessionMaxVMGUp = 0.0;
        mSessionMaxVMGDown = 0.0;
        
        // Initialize VMG points array for 3-point averaging
        mVMGPoints = new [VMG_POINTS_SIZE];
        for (var i = 0; i < VMG_POINTS_SIZE; i++) {
            mVMGPoints[i] = 0.0;
        }
        mVMGPointIndex = 0;
        
        // Initialize vibration tracking
        mLastVMGAlertTime = 0;
        mLastMaxVMGAlertTime = 0;
        mTargetUpwindVMG = getTargetUpwindVMG();
        
        log("VMGCalculator reset");
    }
    
    // Get target upwind VMG from model settings
    function getTargetUpwindVMG() {
        var defaultTarget = 7.0; // Default value
        
        try {
            // Get the app instance
            var app = Application.getApp();
            if (app == null) {
                return defaultTarget;
            }
            
            // Get model data using the accessor method
            var data = null;
            if (app has :getModelData) {
                data = app.getModelData();
            }
            
            // If we successfully got data, extract the target setting
            if (data != null && data.hasKey("targetSettings")) {
                var targetSettings = data["targetSettings"];
                if (targetSettings != null && targetSettings.hasKey("targetUpwindVMG")) {
                    return targetSettings["targetUpwindVMG"];
                }
            }
            
            // If all else fails, check Application.Storage
            var storage = Application.Storage;
            if (storage != null) {
                var storedSettings = storage.getValue("targetSettings");
                if (storedSettings != null && storedSettings.hasKey("targetUpwindVMG")) {
                    return storedSettings["targetUpwindVMG"];
                }
            }
            
            return defaultTarget;
        } catch (e) {
            System.println("Error getting target VMG: " + e.getErrorMessage());
            return defaultTarget;
        }
    }
    
    // Calculate VMG with smoothing and alert triggering
    function calculateVMG(heading, speed, isUpwind, windAngleLessCOG) {
        if (speed <= 0) {
            mCurrentVMG = 0.0;
            return 0.0;
        }
        
        // Get absolute wind angle for VMG calculation
        var absWindAngle = (windAngleLessCOG < 0) ? -windAngleLessCOG : windAngleLessCOG;
        
        // Calculate raw VMG
        var windAngleRad;
        var rawVMG;
        
        if (isUpwind) {
            // Upwind calculation
            windAngleRad = Math.toRadians(absWindAngle);
            rawVMG = speed * Math.cos(windAngleRad);
        } else {
            // Downwind calculation
            windAngleRad = Math.toRadians(180 - absWindAngle);
            rawVMG = speed * Math.cos(windAngleRad);
        }
        
        // Ensure VMG is positive (speed TO wind or AWAY from wind)
        if (rawVMG < 0) {
            rawVMG = -rawVMG;
        }
        
        // Apply smoothing using EMA
        if (mCurrentVMG > 0) {
            mCurrentVMG = (mCurrentVMG * (1.0 - VMG_SMOOTHING_FACTOR)) + (rawVMG * VMG_SMOOTHING_FACTOR);
        } else {
            mCurrentVMG = rawVMG;
        }
        
        // Store in points array for 3-point averaging
        mVMGPoints[mVMGPointIndex] = mCurrentVMG;
        mVMGPointIndex = (mVMGPointIndex + 1) % VMG_POINTS_SIZE;
        
        // Calculate 3-point average VMG
        var vmgSum = 0.0;
        var vmgCount = 0;
        for (var i = 0; i < VMG_POINTS_SIZE; i++) {
            if (mVMGPoints[i] > 0.0) {
                vmgSum += mVMGPoints[i];
                vmgCount++;
            }
        }
        
        var avg3pVMG = (vmgCount > 0) ? vmgSum / vmgCount : 0.0;
        
        // Check if we need to update target VMG from settings
        var currentTime = System.getTimer();
        if (currentTime % 5000 < 100) { // Check every ~5 seconds
            mTargetUpwindVMG = getTargetUpwindVMG();
        }
        
        // Check for alerts - but only if we have 3 points and are actively sailing
        if (vmgCount >= 3 && speed > 3.0) {
            // Get current time for alert timing
            
            if (isUpwind) {
                // UPWIND VMG Alerts - New implementation
                
                // Check for new max upwind VMG
                var isNewMax = false;
                if (avg3pVMG > mSessionMaxVMGUp) {
                    mSessionMaxVMGUp = avg3pVMG;
                    isNewMax = true;
                    
                    // Log the new max
                    System.println("New max VMG upwind: " + mSessionMaxVMGUp.format("%.1f") + " kt");
                    
                    // Trigger max alert if not too soon after last alert
                    if (currentTime - mLastMaxVMGAlertTime > VIBRATION_COOLDOWN) {
                        triggerMaxVMGAlert();
                        mLastMaxVMGAlertTime = currentTime;
                    }
                }
                
                // Check if above target for regular alert - only do this if not already triggering a max alert
                if (!isNewMax && avg3pVMG >= mTargetUpwindVMG) {
                    // Only vibrate if above threshold and not too soon after last alert
                    if (currentTime - mLastVMGAlertTime > VIBRATION_COOLDOWN) {
                        triggerVMGAlert();
                        mLastVMGAlertTime = currentTime;
                    }
                }
            } else {
                // DOWNWIND VMG Tracking - Just track the max without alerts
                if (avg3pVMG > mSessionMaxVMGDown) {
                    mSessionMaxVMGDown = avg3pVMG;
                    System.println("New max VMG downwind: " + mSessionMaxVMGDown.format("%.1f") + " kt");
                }
            }
        }
        
        // Debugging output (reduced frequency to avoid log spam)
        if (currentTime % 5000 < 100) {
            log("VMG Calculation - Wind: " + mParent.getWindDirection() + 
                "°, COG: " + heading + 
                "°, WindAngle: " + windAngleLessCOG + 
                "°, VMG: " + mCurrentVMG.format("%.2f") + " kt" +
                ", 3p VMG: " + avg3pVMG.format("%.2f") + " kt");
        }
                
        return mCurrentVMG;
    }
    
    // Trigger VMG alert - long vibration for above target
    function triggerVMGAlert() {
        var app = Application.getApp();
        if (app has :vibratePattern) {
            // One long vibration
            app.vibratePattern(4); // Using pattern ID 4 for VMG alert
            System.println("VMG ALERT - Above target: " + mCurrentVMG.format("%.1f") + " > " + mTargetUpwindVMG + " kt");
        }
    }
    
    // Trigger Max VMG alert - double long vibration for new max
    function triggerMaxVMGAlert() {
        var app = Application.getApp();
        if (app has :vibratePattern) {
            // Two long vibrations
            app.vibratePattern(5); // Using pattern ID 5 for max VMG alert
            System.println("MAX VMG ALERT - New max upwind: " + mSessionMaxVMGUp.format("%.1f") + " kt");
        }
    }

    // Accessor methods
    function getCurrentVMG() {
        return mCurrentVMG;
    }

    function getData() {
        // Calculate 3-point average VMG
        var vmgSum = 0.0;
        var vmgCount = 0;
        for (var i = 0; i < VMG_POINTS_SIZE; i++) {
            if (mVMGPoints[i] > 0.0) {
                vmgSum += mVMGPoints[i];
                vmgCount++;
            }
        }
        
        var avg3pVMG = (vmgCount > 0) ? vmgSum / vmgCount : 0.0;
        
        return {
            "currentVMG" => mCurrentVMG,
            "avg3pVMG" => avg3pVMG,
            "maxVMGUp" => mSessionMaxVMGUp,
            "maxVMGDown" => mSessionMaxVMGDown,
            "pointCount" => vmgCount,
            "targetUpwindVMG" => mTargetUpwindVMG
        };
    }
}