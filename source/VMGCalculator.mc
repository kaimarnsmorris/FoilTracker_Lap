// VMGCalculator.mc - Handles VMG calculations
using Toybox.Math;
using Toybox.System;

class VMGCalculator {
    // Constants
    private const VMG_SMOOTHING_FACTOR = 0.1;  // Smoothing factor for VMG

    // Properties
    private var mParent;              // Reference to WindTracker parent
    private var mCurrentVMG;          // Current velocity made good (knots)
 
    // Add these constants and member variables to the VMGCalculator class
    private const VMG_POINTS_SIZE = 3;     // Track last 3 VMG values for averaging
    private var mSessionMaxVMGUp;          // Track max VMG upwind for the session
    private var mSessionMaxVMGDown;        // Track max VMG downwind for the session
    private var mVMGPoints;                // Array to store recent VMG points
    private var mVMGPointIndex;            // Current index in VMG points array   

    function initialize(parent) {
        mParent = parent;
        reset();
    }

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
        
        log("VMGCalculator reset");
    }
    
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
        
        // Check for new max VMG values and vibrate if needed
        // Only consider it valid if we have 3 points
        if (vmgCount >= 3) {
            if (isUpwind) {
                if (avg3pVMG > mSessionMaxVMGUp) {
                    mSessionMaxVMGUp = avg3pVMG;
                    
                    // Vibrate twice for new max VMG upwind
                    var app = Application.getApp();
                    if (app has :vibratePattern) {
                        app.vibratePattern(2);
                        System.println("New max VMG upwind: " + mSessionMaxVMGUp.format("%.1f") + " kt - vibrating twice");
                    }
                }
            } else {
                if (avg3pVMG > mSessionMaxVMGDown) {
                    mSessionMaxVMGDown = avg3pVMG;
                    
                    // Vibrate three times for new max VMG downwind
                    var app = Application.getApp();
                    if (app has :vibratePattern) {
                        app.vibratePattern(3);
                        System.println("New max VMG downwind: " + mSessionMaxVMGDown.format("%.1f") + " kt - vibrating three times");
                    }
                }
            }
        }
        
        log("VMG Calculation - Wind: " + mParent.getWindDirection() + 
            "°, COG: " + heading + 
            "°, WindAngle: " + windAngleLessCOG + 
            "°, VMG: " + mCurrentVMG.format("%.2f") + " kt" +
            ", 3p VMG: " + avg3pVMG.format("%.2f") + " kt");
                
        return mCurrentVMG;
    }

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
            "pointCount" => vmgCount
        };
    }

}