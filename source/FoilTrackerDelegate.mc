using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.Application;

// Input handler class for UI events
class FoilTrackerDelegate extends WatchUi.BehaviorDelegate {
    private var mView;
    private var mModel;
    private var mWindTracker;
    
    // Constructor with WindTracker parameter
    function initialize(view, model, windTracker) {
        BehaviorDelegate.initialize();
        mView = view;
        mModel = model;
        mWindTracker = windTracker;
    }
    
    // Handle menu button press
    function onMenu() {
        // Show the menu when the menu button is pressed
        WatchUi.pushView(new FoilTrackerMenuView(), new FoilTrackerMenuDelegate(mModel), WatchUi.SLIDE_UP);
        return true;
    }
    
    // Handle select button press - CHANGED: Now used for lap marking instead of pause/resume
    function onSelect() {
        var data = mModel.getData();
        
        // Check if the activity is recording and not paused
        var isActive = false;
        if (data.hasKey("isRecording") && data["isRecording"]) {
            if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                isActive = true;
            }
        }
        
        if (isActive) {
            System.println("SELECT BUTTON PRESSED - ADDING LAP");
            
            // Add a lap marker with all custom fields
            var app = Application.getApp();
            app.addLapMarker();
            
            // Show lap feedback in the view if available
            if (mView has :showLapFeedback) {
                mView.showLapFeedback();
            }
            
            System.println("Lap marker added from Main view");
        } else {
            System.println("Cannot add lap marker - not recording or paused");
        }
        
        return true;
    }
    
    // Handle back button press - CHANGED: Go straight to end session confirmation
    function onBack() {
        var data = mModel.getData();
        
        // If recording, pause and show confirmation directly
        if (data.hasKey("isRecording") && data["isRecording"]) {
            // Pause the session
            data["sessionPaused"] = true;
            
            // Call the model's setPauseState function to properly handle pause timing
            mModel.setPauseState(true);
            
            // Make sure the view and delegate objects are created properly
            try {
                var confirmView = new ConfirmationView("End Session?");
                var confirmDelegate = new ConfirmationDelegate(mModel);
                
                // Push the view with proper parameters
                WatchUi.pushView(confirmView, confirmDelegate, WatchUi.SLIDE_IMMEDIATE);
            } catch(e) {
                System.println("Error pushing confirmation view: " + e.getErrorMessage());
            }
            return true;
        }
        
        return false; // Let the system handle this event (exits app)
    }
    
    // Handle up button - Do nothing
    function onPreviousPage() {
        // Stay on main view, no action needed
        return true;
    }
    
    // Handle down button press - Go to VMG view
    function onNextPage() {
        // Navigate to VMG view
        var app = Application.getApp();
        var vmgView = new VMGView(mModel, app.getWindTracker());
        var vmgDelegate = new VMGDelegate(vmgView, mModel, app);
        
        // Switch to VMG view
        WatchUi.switchToView(vmgView, vmgDelegate, WatchUi.SLIDE_DOWN);
        
        return true;
    }
    
    // Handle key events (for compatibility with devices that use onKey)
    function onKey(keyEvent) {
        // Let parent class handle other keys
        return BehaviorDelegate.onKey(keyEvent);
    }
}