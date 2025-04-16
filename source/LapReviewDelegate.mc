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
            
            // Update activity tracker with new view
            if (mApp has :getActivityTracker && mApp.getActivityTracker() != null) {
                mApp.getActivityTracker().setCurrentView(mainView);
            }
            
            WatchUi.switchToView(mainView, mainDelegate, WatchUi.SLIDE_IMMEDIATE);
        }
        
        return true;
    }
    
    // Replace the onBack method in LapReviewDelegate
    function onBack() {
        // Instead of popping the view, which may be causing the strange intermediate screen,
        // switch directly back to the main FoilTracker view
        var app = Application.getApp();
        
        try {
            // Create the main view
            var mainView = new FoilTrackerView(mModel);
            var mainDelegate = new FoilTrackerDelegate(mainView, mModel, app.getWindTracker());
            
            // Update activity tracker with new view
            if (app has :getActivityTracker && app.getActivityTracker() != null) {
                app.getActivityTracker().setCurrentView(mainView);
            }
            
            // Switch to the main view
            WatchUi.switchToView(mainView, mainDelegate, WatchUi.SLIDE_IMMEDIATE);
        } catch (e) {
            System.println("Error in LapReviewDelegate.onBack: " + e.getErrorMessage());
            
            // Fallback to normal pop if the switch fails
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        
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