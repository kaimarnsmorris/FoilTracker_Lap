// OnMastDelegate.mc - Handler for OnMast view
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;

class OnMastDelegate extends WatchUi.BehaviorDelegate {
    private var mView;
    private var mModel;
    private var mApp;
    
    // Constructor
    function initialize(view, model, app) {
        BehaviorDelegate.initialize();
        mView = view;
        mModel = model;
        mApp = app;
    }
    
    // Handle back button - Go to pause screen
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
    
    // Handle up button - Return to VMG view
    function onPreviousPage() {
        // Switch back to VMG view
        var vmgView = new VMGView(mModel, mApp.getWindTracker());
        var vmgDelegate = new VMGDelegate(vmgView, mModel, mApp);
        
        // Update activity tracker with new view
        if (mApp has :getActivityTracker && mApp.getActivityTracker() != null) {
            mApp.getActivityTracker().setCurrentView(vmgView);
        }
        
        WatchUi.switchToView(vmgView, vmgDelegate, WatchUi.SLIDE_UP);
        return true;
    }
    
    // Handle select button - Add lap marker
    function onSelect() {
        var data = mModel.getData();
        
        // Check if the activity is recording and not paused
        var isActive = false;
        if (data != null && data.hasKey("isRecording") && data["isRecording"]) {
            if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                isActive = true;
            }
        }
        
        if (isActive && mApp != null) {
            mApp.addLapMarker();
            System.println("Lap marker added from OnMast view");
            
            // Show lap feedback
            if (mView != null && mView has :showLapFeedback) {
                mView.showLapFeedback();
                System.println("Lap feedback shown in OnMast view");
            }
        }
        
        return true;
    }
    
    // Handle down button - Reset wind to manual
    function onNextPage() {
        if (mApp != null && mApp.getWindTracker() != null) {
            var windTracker = mApp.getWindTracker();
            
            // Unlock and reset to manual direction
            windTracker.unlockWindDirection();
            windTracker.resetToManualDirection();
            
            System.println("Wind direction reset to manual input from OnMast view");
            System.println("Waiting for 2 tacks/gybes to reinitialize wind direction");
            
            // Show feedback for wind reset
            if (mView != null && mView has :showWindResetFeedback) {
                mView.showWindResetFeedback();
                System.println("Wind reset feedback shown in OnMast view");
            }
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
        return true;
    }
}