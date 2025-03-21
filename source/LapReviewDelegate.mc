using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;

// Input handler class for lap review screen
class LapReviewDelegate extends WatchUi.BehaviorDelegate {
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
    
    // Handle select button press - Just unpause and return to main view
    function onSelect() {
        if (mModel != null) {
            // Unpause the session
            var data = mModel.getData();
            if (data != null) {
                data["sessionPaused"] = false;
                
                // Update pause state in model
                mModel.setPauseState(false);
            }
            
            System.println("Unpausing from LapReviewDelegate");
            
            // Return to main view
            var mainView = new FoilTrackerView(mModel);
            var mainDelegate = new FoilTrackerDelegate(mainView, mModel, mApp.getWindTracker());
            WatchUi.switchToView(mainView, mainDelegate, WatchUi.SLIDE_IMMEDIATE);
        }
        
        return true;
    }
    
    // Handle back button press - Return to pause confirmation screen
    function onBack() {
        // Pop back to the confirmation view
        WatchUi.popView(WatchUi.SLIDE_UP);
        return true;
    }
    
    // Handle down button press - Show earlier lap (older)
    function onNextPage() {
        // Navigate to earlier lap (down button)
        if (mView != null && mView has :nextLap) {
            mView.nextLap();
        }
        return true;
    }
    
    // Handle up button press - Show later lap (newer)
    function onPreviousPage() {
        // Navigate to later lap (up button)
        if (mView != null && mView has :previousLap) {
            mView.previousLap();
        }
        return true;
    }
}