using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;

// VMGDelegate class to handle button presses on VMG view
class VMGDelegate extends WatchUi.BehaviorDelegate {
    private var mView;
    private var mModel;
    private var mApp;
    private var mWindTracker;
    
    // Constructor
    function initialize(view, model, app) {
        BehaviorDelegate.initialize();
        mView = view;
        mModel = model;
        mApp = app;
        mWindTracker = app.getWindTracker();
    }
    
    // Handle menu button press
    function onMenu() {
        // Show the menu when the menu button is pressed
        WatchUi.pushView(new FoilTrackerMenuView(), new FoilTrackerMenuDelegate(mModel), WatchUi.SLIDE_UP);
        return true;
    }
    
    function onSelect() {
        var data = mModel.getData();
        
        // Check if the activity is recording and not paused
        var isActive = false;
        if (data != null && data.hasKey("isRecording") && data["isRecording"]) {
            if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                isActive = true;
            }
        }
        
        if (isActive) {
            System.println("SELECT BUTTON PRESSED - ADDING LAP FROM VMG VIEW");
            
            try {
                // Add a lap marker with no arguments
                if (mApp != null) {
                    mApp.addLapMarker();
                    System.println("App.addLapMarker() called successfully");
                } else {
                    System.println("Error: mApp is null");
                }
                
                // Show lap feedback in the view if available
                if (mView != null && mView has :showLapFeedback) {
                    mView.showLapFeedback();
                    System.println("View feedback shown");
                }
            } catch (e) {
                System.println("ERROR in VMGDelegate.onSelect: " + e.getErrorMessage());
            }
        } else {
            System.println("Cannot add lap marker - not recording or paused");
        }
        
        return true;
    }
    
    // Complete replacement for VMGDelegate's onBack method
    function onBack() {
        if (mWindTracker != null) {
            if (mWindTracker.isWindDirectionLocked()) {
                // If already locked, unlock AND reset to manual direction
                mWindTracker.unlockWindDirection();
                mWindTracker.resetToManualDirection();
                System.println("Wind direction unlocked and reset to manual input");
            } else {
                // Toggle wind direction lock
                mWindTracker.lockWindDirection();
                System.println("Wind direction locked at: " + mWindTracker.getWindDirection());
            }
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
        return true;
    }

    // Complete replacement for VMGDelegate's onNextPage method to navigate to OnMast view
    function onNextPage() {
        // Switch to OnMast view when down button is pressed
        var view = new OnMastView(mModel, mWindTracker);
        var delegate = new OnMastDelegate(view, mModel, mApp);
        
        // Update activity tracker with new view
        if (mApp has :getActivityTracker && mApp.getActivityTracker() != null) {
            mApp.getActivityTracker().setCurrentView(view);
        }
        
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_DOWN);
        return true;
    }
    
    // Handle previous page button (up) - Go back to main view
    function onPreviousPage() {
        // Switch back to the main FoilTrackerView
        var view = new FoilTrackerView(mModel);
        var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
        
        // Update activity tracker with new view
        if (mApp has :getActivityTracker && mApp.getActivityTracker() != null) {
            mApp.getActivityTracker().setCurrentView(view);
        }
        
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_UP);
        return true;
    }

    
    // Handle key events (for compatibility with devices that use onKey)
    function onKey(keyEvent) {
        // Let parent class handle other keys
        return BehaviorDelegate.onKey(keyEvent);
    }
    
    // Override the onShow handler to ensure view is updated when shown
    function onShow() {
        // Force an update when view is shown
        System.println("VMGDelegate.onShow() - Forcing UI update");
        WatchUi.requestUpdate();
        return true;
    }
}