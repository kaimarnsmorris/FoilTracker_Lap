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
    
    // Handle select button press - Records lap (same as in main view)
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
            System.println("SELECT BUTTON PRESSED - ADDING LAP FROM VMG VIEW");
            
            // Add a lap marker with all custom fields
            mApp.addLapMarker();
            
            // Show lap feedback in the view if available
            if (mView has :showLapFeedback) {
                mView.showLapFeedback();
            }
            
            System.println("Lap marker added from VMG view");
        } else {
            System.println("Cannot add lap marker - not recording or paused");
        }
        
        return true;
    }
    
    // Handle back button press - Lock/unlock wind direction
    function onBack() {
        if (mWindTracker != null) {
            // Toggle wind direction lock
            if (mWindTracker.isWindDirectionLocked()) {
                mWindTracker.unlockWindDirection();
                System.println("Wind direction unlocked");
            } else {
                mWindTracker.lockWindDirection();
                System.println("Wind direction locked at: " + mWindTracker.getWindDirection());
            }
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
        return true;
    }
    
    // Handle previous page button (up) - Go back to main view
    function onPreviousPage() {
        // Switch back to the main FoilTrackerView
        var view = new FoilTrackerView(mModel);
        var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
        WatchUi.switchToView(view, delegate, WatchUi.SLIDE_UP);
        return true;
    }
    
    // Handle next page button (down) - Reset wind direction to initial user input
    function onNextPage() {
        if (mWindTracker != null) {
            // Reset the wind tracker to use the initial user input and unlock
            mWindTracker.unlockWindDirection();
            mWindTracker.resetToManualDirection();
            
            // Log the reset action
            System.println("Wind direction reset to manual input");
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
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