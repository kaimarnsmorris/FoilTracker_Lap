using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

// Confirmation dialog for exiting while recording
class ConfirmationView extends WatchUi.View {
    private var mPrompt;
    
    function initialize(prompt) {
        View.initialize();
        mPrompt = prompt;
    }
    
    function onLayout(dc) {
        // Layout resources
    }
    
    function onUpdate(dc) {
            // Clear the screen
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            
            // Get screen dimensions
            var width = dc.getWidth();
            var height = dc.getHeight();
            
            // Draw PAUSED text at the top
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, height/2 - 60, Graphics.FONT_SMALL, "PAUSED", Graphics.TEXT_JUSTIFY_CENTER);
            
            // Draw confirmation text
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, height/2 - 30, Graphics.FONT_MEDIUM, mPrompt, Graphics.TEXT_JUSTIFY_CENTER);
            
            // Button instructions
            dc.drawText(width/2, height/2 + 10, Graphics.FONT_SMALL, "Press SELECT to return", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width/2, height/2 + 30, Graphics.FONT_SMALL, "Press BACK to end", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width/2, height/2 + 50, Graphics.FONT_SMALL, "Press DOWN for laps", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

// Confirmation delegate - MODIFIED for new button flow
class ConfirmationDelegate extends WatchUi.BehaviorDelegate {
    private var mModel;
    private var mApp;
    
    function initialize(model) {
        BehaviorDelegate.initialize();
        mModel = model;
        mApp = Application.getApp();
    }
    
    // CHANGED: Select now returns to recording (unpauses)
    function onSelect() {
        // Resume recording
        if (mModel != null) {
            var data = mModel.getData();
            data["sessionPaused"] = false;
            
            // Update pause state in model
            mModel.setPauseState(false);
            
            // Pop view to return to main screen
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        
        return true;
    }
    
    // CHANGED: Back now ends the activity
    function onBack() {
        // End recording immediately
        if (mModel != null) {
            var data = mModel.getData();
            data["isRecording"] = false;
            data["sessionPaused"] = false;
            data["sessionComplete"] = false; // Will be set to true when saved
        }
        
        // Show our custom save dialog
        var saveView = new SaveDialogView(mModel);
        var saveDelegate = new SaveDialogDelegate(mModel, mApp);
        
        // Push the view
        WatchUi.pushView(saveView, saveDelegate, WatchUi.SLIDE_LEFT);
        
        return true;
    }

    // NEW: Down button now shows lap review
    function onNextPage() {
        // Switch to Lap Review screen
        if (mApp != null) {
            var windTracker = mApp.getWindTracker();
            
            if (windTracker != null) {
                // Create lap review view and delegate
                var lapReviewView = new LapReviewView(mModel, windTracker);
                var lapReviewDelegate = new LapReviewDelegate(lapReviewView, mModel, mApp);
                
                // Switch to lap review view
                WatchUi.switchToView(lapReviewView, lapReviewDelegate, WatchUi.SLIDE_DOWN);
            }
        }
        
        return true;
    }
}