// ActivityStateTracker.mc - Handles automatic lap markers based on activity state
using Toybox.System;
using Toybox.Time;
using Toybox.Application;

class ActivityStateTracker {
    // Constants
    private const INACTIVITY_WAIT_TIME = 10;          // Seconds to wait before marking inactive lap
    private const INACTIVITY_SPEED_THRESHOLD = 2;   // Speed threshold in knots for inactivity
    
    // Properties
    private var mApp;                       // Reference to parent app
    private var mModel;                     // Reference to model
    private var mIsActive;                  // Current activity state
    private var mLastActivityTime;          // Time of last active state
    private var mLastInactivityTime;        // Time of last inactive state
    private var mLastLapForInactivity;      // Whether last lap was for inactivity
    private var mInactivityDetected;        // Whether inactivity is currently detected
    private var mActivityDetected;          // Whether activity is currently detected
    private var mInactivityTimeoutStarted;  // Whether inactivity timeout has started
    private var mInactivityTimeoutStart;    // When inactivity timeout started
    private var mCurrentView;  // Current view reference


    // Constructor
    function initialize(app, model) {
        mApp = app;
        mModel = model;
        mIsActive = false;
        mLastActivityTime = 0;
        mLastInactivityTime = 0;
        mLastLapForInactivity = false;
        mInactivityDetected = false;
        mActivityDetected = false;
        mInactivityTimeoutStarted = false;
        mInactivityTimeoutStart = 0;
        mCurrentView = null;
        
        System.println("ActivityStateTracker initialized");
    }
    
    // Add method to set current view
    function setCurrentView(view) {
        mCurrentView = view;
    }
    
    function processSpeed(speed) {
        // Get foiling threshold from model settings
        var foilingThreshold = 7.0; // Default fallback
        var settings = null;
        
        if (mModel != null) {
            // Get model data
            var data = mModel.getData();
            if (data != null && data.hasKey("settings")) {
                settings = data["settings"];
                if (settings != null && settings.hasKey("foilingThreshold")) {
                    foilingThreshold = settings["foilingThreshold"];
                }
            }
        }
        
        // Check if recording and not paused
        var isSessionActive = isSessionRecording();
        if (!isSessionActive) {
            // Reset state when session isn't active
            resetState();
            return;
        }
        
        // Get current system time
        var currentTime = System.getTimer();
        
        // NEW: Initialize state if both flags are false and speed is high
        if (!mActivityDetected && !mInactivityDetected) {
            if (speed >= foilingThreshold) {
                // If we start with high speed, initialize to active state directly
                mActivityDetected = true;
                System.println("ActivityTracker: Initialized to active state - speed: " + speed.format("%.1f") + " kt");
            } else if (speed < INACTIVITY_SPEED_THRESHOLD) {
                // If we start with low speed, initialize to inactive state directly
                mInactivityDetected = true;
                System.println("ActivityTracker: Initialized to inactive state - speed: " + speed.format("%.1f") + " kt");
            }
            // For intermediate speeds, wait for a clear signal in either direction
        }
        
        // Occasional debug logging
        if (currentTime % 30000 < 100) { // Every ~30 seconds
            System.println("ActivityTracker: speed=" + speed.format("%.1f") + 
                        " inactiveState=" + mInactivityDetected + 
                        " activeState=" + mActivityDetected + 
                        " timeout=" + mInactivityTimeoutStarted);
        }
        
        // PART 1: Handle transitions to inactive state
        if (speed < INACTIVITY_SPEED_THRESHOLD) {
            // We're below inactivity threshold (slow or stopped)
            
            // Start inactivity timeout if not already started and we're currently in active state
            if (!mInactivityTimeoutStarted && mActivityDetected) {
                mInactivityTimeoutStarted = true;
                mInactivityTimeoutStart = currentTime;
                System.println("Inactivity timeout started - speed: " + speed.format("%.1f") + " kt");
            }
            
            // Check for inactivity timeout completion
            if (mInactivityTimeoutStarted) {
                var timeInactive = (currentTime - mInactivityTimeoutStart) / 1000; // Convert to seconds
                
                if (timeInactive >= INACTIVITY_WAIT_TIME) {
                    // Only mark inactivity if we're currently in active state
                    if (mActivityDetected && !mInactivityDetected) {
                        System.println("Inactivity detected after " + timeInactive.format("%.1f") + " seconds");
                        
                        // Update state flags BEFORE adding lap marker
                        mActivityDetected = false;
                        mInactivityDetected = true;
                        
                        // Add a lap marker for inactivity
                        System.println("Adding lap marker for INACTIVITY");
                        addLapMarker("inactivity");
                    }
                    
                    // Reset timeout flag
                    mInactivityTimeoutStarted = false;
                }
            }
        }
        // PART 2: Handle transitions to active state
        else if (speed >= foilingThreshold) {
            // We're above foiling threshold (definitely active)
            
            // Cancel any ongoing inactivity timeout
            if (mInactivityTimeoutStarted) {
                mInactivityTimeoutStarted = false;
                System.println("Inactivity timeout cancelled - speed: " + speed.format("%.1f") + " kt");
            }
            
            // Detect transition from inactive to active state
            if (mInactivityDetected && !mActivityDetected) {
                System.println("Activity detected - speed: " + speed.format("%.1f") + " kt (threshold: " + 
                            foilingThreshold.format("%.1f") + " kt)");
                
                // Update state flags BEFORE adding lap marker
                mActivityDetected = true;
                mInactivityDetected = false;
                
                // Add a lap marker for activity resumption
                System.println("Adding lap marker for ACTIVITY RESUMED");
                addLapMarker("activity");
            }
        }
        // For intermediate speeds (between inactive and foiling thresholds)
        else {
            // Cancel inactivity timeout if started (we're moving, just not fast enough for foiling)
            if (mInactivityTimeoutStarted) {
                mInactivityTimeoutStarted = false;
                System.println("Inactivity timeout cancelled (intermediate speed): " + speed.format("%.1f") + " kt");
            }
            
            // No state changes or lap markers for intermediate speeds
        }
    }
    
    // Handle creation of lap markers based on activity state changes
    function handleLapMarkers() {
        // Skip if session isn't recording
        if (!isSessionRecording()) {
            return;
        }
        
        // Add lap for inactivity
        if (mInactivityDetected) {
            if (!mLastLapForInactivity) {
                System.println("Adding lap marker for INACTIVITY");
                addLapMarker("inactivity");
                mLastLapForInactivity = true;
            }
            mInactivityDetected = false;
        }
        
        // Add lap for activity resuming
        if (mActivityDetected) {
            if (mLastLapForInactivity) {
                System.println("Adding lap marker for ACTIVITY RESUMED");
                addLapMarker("activity");
                mLastLapForInactivity = false;
            }
            mActivityDetected = false;
        }
    }
    
    function addLapMarker(reason) {
        if (mApp != null) {
            // Note: We no longer store lap auto type in model data
            
            // Call app's lap marker function
            mApp.addLapMarker();
            
            // Show visual feedback if view is available
            if (mCurrentView != null && mCurrentView has :showLapFeedback) {
                mCurrentView.showLapFeedback();
                System.println("Showing lap feedback in current view");
            } else {
                System.println("No view available for lap feedback or view doesn't support feedback");
            }
            
            System.println("Lap marker added for " + reason);
        }
    }
    
    // Check if session is recording and not paused
    function isSessionRecording() {
        if (mModel == null) {
            return false;
        }
        
        var data = mModel.getData();
        if (data == null) {
            return false;
        }
        
        var isRecording = data.hasKey("isRecording") && data["isRecording"];
        var isPaused = data.hasKey("sessionPaused") && data["sessionPaused"];
        
        return isRecording && !isPaused;
    }
    
    // Reset the activity state tracker
    function resetState() {
        mIsActive = false;
        mLastActivityTime = 0;
        mLastInactivityTime = 0;
        mLastLapForInactivity = false;
        mInactivityDetected = false;
        mActivityDetected = false;
        mInactivityTimeoutStarted = false;
        mInactivityTimeoutStart = 0;
    }
}