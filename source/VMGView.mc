using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Math;

// VMG View class for wind angle and VMG calculations
class VMGView extends WatchUi.View {
    private var mModel;
    private var mWindTracker;
    private var mWindDirection;
    private var mVmg;
    private var mIsUpwind;
    private var mCurrentTack;
    private var mLastTackAngle;
    private var mLastGybeAngle;
    private var mTackCount;
    private var mGybeCount;
    private var mWindMode;
    private var mLastRefreshTime;
    private var mForcedUpdate;
    private var mWindAngle;
    private var mDataChanged;
    private var mTackDisplayText;
    private var mTackColorId;
    private var mShowLapFeedback;
    private var mLapFeedbackTimer;
    
    // Constructor
    function initialize(model, windTracker) {
        View.initialize();
        mModel = model;
        mWindTracker = windTracker;
        
        // Initialize with default values
        mWindDirection = 0;
        mVmg = 0.0;
        mIsUpwind = true;
        mCurrentTack = "Unknown";
        mLastTackAngle = 0;
        mLastGybeAngle = 0;
        mTackCount = 0;
        mGybeCount = 0;
        mWindMode = "Manual";
        mLastRefreshTime = 0;
        mForcedUpdate = true;
        mWindAngle = 0;
        mDataChanged = false;
        mTackDisplayText = "Stb";
        mTackColorId = 1; // 1 = green, 2 = red
        mShowLapFeedback = false;
        mLapFeedbackTimer = 0;
        
        // Get initial values from wind tracker
        updateFromWindTracker();
    }
    
    // Force a refresh of the view
    function forceRefresh() {
        mForcedUpdate = true;
        WatchUi.requestUpdate();
    }
    
    // Display lap feedback for a short time
    function showLapFeedback() {
        mShowLapFeedback = true;
        mLapFeedbackTimer = System.getTimer();
        WatchUi.requestUpdate();
    }
    
    // Update data from wind tracker
    function updateFromWindTracker() {
        var windData = mWindTracker.getWindData();
        mDataChanged = false;
        
        if (windData != null && windData.hasKey("valid") && windData["valid"]) {
            // Check wind direction
            if (windData.hasKey("windDirection") && mWindDirection != windData["windDirection"]) { 
                mWindDirection = windData["windDirection"];
                mDataChanged = true;
            }
            
            // Check VMG
            if (windData.hasKey("currentVMG") && mVmg != windData["currentVMG"]) { 
                mVmg = windData["currentVMG"]; 
                mDataChanged = true;
            }
            
            // Check point of sail
            if (windData.hasKey("currentPointOfSail")) {
                var newUpwind = (windData["currentPointOfSail"] == "Upwind");
                
                if (mIsUpwind != newUpwind) {
                    mIsUpwind = newUpwind;
                    mDataChanged = true;
                }
            }
            
            // Check current tack
            if (windData.hasKey("currentTack")) {
                var newTack = windData["currentTack"];
                if (mCurrentTack != newTack) {
                    mCurrentTack = newTack;
                    mDataChanged = true;
                    WatchUi.requestUpdate();
                }
            }
            
            // Check wind angle
            if (windData.hasKey("windAngleLessCOG")) {
                var newAngle = windData["windAngleLessCOG"];
                if (newAngle != mWindAngle) {
                    mWindAngle = newAngle;
                    mDataChanged = true;
                }
            }
            
            // Check tack angle
            if (windData.hasKey("lastTackAngle") && mLastTackAngle != windData["lastTackAngle"]) { 
                mLastTackAngle = windData["lastTackAngle"]; 
                mDataChanged = true;
            }
            
            // Check gybe angle
            if (windData.hasKey("lastGybeAngle") && mLastGybeAngle != windData["lastGybeAngle"]) { 
                mLastGybeAngle = windData["lastGybeAngle"]; 
                mDataChanged = true;
            }
            
            // Check tack count
            if (windData.hasKey("tackCount") && mTackCount != windData["tackCount"]) { 
                mTackCount = windData["tackCount"]; 
                mDataChanged = true;
            }
            
            // Check gybe count
            if (windData.hasKey("gybeCount") && mGybeCount != windData["gybeCount"]) { 
                mGybeCount = windData["gybeCount"]; 
                mDataChanged = true;
            }
            
            // Check tack display text
            if (windData.hasKey("tackDisplayText")) {
                mTackDisplayText = windData["tackDisplayText"];
            }
            
            // Check tack color ID
            if (windData.hasKey("tackColorId")) {
                mTackColorId = windData["tackColorId"];
            }
            
            // Check wind mode
            var newMode = "Manual";
            if (windData.hasKey("windDirectionLocked") && windData["windDirectionLocked"]) {
                newMode = "Locked";
            } else if (windData.hasKey("autoWindDetection") && windData["autoWindDetection"]) {
                newMode = "Auto";
            }
            
            if (mWindMode != newMode) {
                mWindMode = newMode;
                mDataChanged = true;
            }
            
            // Store the refresh time to monitor updates
            mLastRefreshTime = System.getTimer();
            
            // If data changed, explicitly request a UI update
            if (mDataChanged) {
                WatchUi.requestUpdate();
            }
        }
        
        // Check if lap feedback should be turned off
        if (mShowLapFeedback) {
            var currentTime = System.getTimer();
            if (currentTime - mLapFeedbackTimer > 2000) { // 2 seconds feedback
                mShowLapFeedback = false;
                WatchUi.requestUpdate();
            }
        }
        
        return mDataChanged;
    }
    
    // On layout
    function onLayout(dc) {
        // Nothing special needed
    }
    
    // Add this helper method outside of onUpdate
    function formatManeuverCount(lapCount, totalCount) {
        return lapCount + "/" + totalCount;
    }

    // Complete replacement for onUpdate method
    function onUpdate(dc) {
        // Always update from wind tracker
        updateFromWindTracker();
        
        // Get absolute wind angle value
        var absWindAngle = (mWindAngle < 0) ? -mWindAngle : mWindAngle;
        
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Display VMG value in larger white font
        var vmgStr = mVmg.format("%.1f");
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        // Use a larger font for VMG
        dc.drawText(width/2, 10, Graphics.FONT_NUMBER_THAI_HOT, vmgStr, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Set color based on tack color ID from model
        var textColor = (mTackColorId == 1) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        
        // Draw tack indicator text to the left of the wind angle with correct color
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(90, 105, Graphics.FONT_SMALL, mTackDisplayText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(130, 90, Graphics.FONT_NUMBER_MEDIUM, absWindAngle.format("%d") + "°", Graphics.TEXT_JUSTIFY_LEFT);
        
        // Statistics section - Tacks/Gybes
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        
        // Get both total and lap-specific counts from wind data
        var totalTackCount = 0;
        var totalGybeCount = 0;
        var lapTackCount = 0;
        var lapGybeCount = 0;
        
        var windData = null;
        if (mWindTracker != null) {
            windData = mWindTracker.getWindData();
        }
        
        if (windData != null && windData.hasKey("valid") && windData["valid"]) {
            // Get total display counts
            if (windData.hasKey("displayTackCount")) {
                totalTackCount = windData["displayTackCount"];
            }
            if (windData.hasKey("displayGybeCount")) {
                totalGybeCount = windData["displayGybeCount"];
            }
            
            // Get lap-specific display counts
            if (windData.hasKey("lapDisplayTackCount")) {
                lapTackCount = windData["lapDisplayTackCount"];
            }
            if (windData.hasKey("lapDisplayGybeCount")) {
                lapGybeCount = windData["lapDisplayGybeCount"];
            }
        }
        
        // Tacks section - Always show lap/total format
        var tackText = "Tacks: " + formatManeuverCount(lapTackCount, totalTackCount);
        dc.drawText(5, 140, Graphics.FONT_TINY, tackText, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Last tack angle directly underneath
        var lastTackText = "Last: ";
        if (mLastTackAngle > 0) {
            lastTackText += mLastTackAngle.format("%d") + "°";
        } else {
            lastTackText += "--";
        }
        dc.drawText(25, 160, Graphics.FONT_TINY, lastTackText, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Gybes section - Always show lap/total format
        var gybeText = "Gybes: " + formatManeuverCount(lapGybeCount, totalGybeCount);
        dc.drawText(130, 140, Graphics.FONT_TINY, gybeText, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Last gybe angle directly underneath
        var lastGybeText = "Last: ";
        if (mLastGybeAngle > 0) {
            lastGybeText += mLastGybeAngle.format("%d") + "°";
        } else {
            lastGybeText += "--";
        }
        dc.drawText(140, 160, Graphics.FONT_TINY, lastGybeText, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Draw wind direction and mode at bottom
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height - 40, Graphics.FONT_TINY, "Wind: " + mWindDirection.format("%d") + "°", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, height - 60, Graphics.FONT_TINY, mWindMode + " wind mode", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw lap feedback if active
        if (mShowLapFeedback) {
            // Draw LAP MARKER notice at the top of the screen
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            dc.fillRectangle(0, 0, width, 25);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, 2, Graphics.FONT_SMALL, "LAP MARKED", Graphics.TEXT_JUSTIFY_CENTER);
        }
       

    }
}