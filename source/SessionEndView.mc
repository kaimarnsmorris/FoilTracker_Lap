using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

// Session end view for saving or discarding activity
class SessionEndView extends WatchUi.ConfirmationDelegate {
    private var mModel;
    private var mApp;
    
    function initialize(model, app) {
        ConfirmationDelegate.initialize();
        mModel = model;
        mApp = app;
    }
    
    function onResponse(response) {
        if (response == WatchUi.CONFIRM_YES) {
            // Save activity
            System.println("Saving activity");
            
            // Save data in the model
            if (mModel != null) {
                mModel.saveActivityData();
            }
            
            // Save the activity recording session
            if (mApp != null && mApp has :mSession && mApp.mSession != null && mApp.mSession.isRecording()) {
                try {
                    mApp.mSession.stop();
                    mApp.mSession.save();
                    System.println("Activity recording saved");
                } catch (e) {
                    System.println("Error saving activity: " + e.getErrorMessage());
                }
            }
        } else {
            // Discard activity
            System.println("Discarding activity");
            
            // Mark as discarded in the model so auto-save doesn't run
            if (mModel != null) {
                var data = mModel.getData();
                data["sessionComplete"] = true;
                data["sessionDiscarded"] = true;
                System.println("Session marked as discarded in model");
            }
            
            // Discard the activity recording session
            if (mApp != null && mApp has :mSession && mApp.mSession != null && mApp.mSession.isRecording()) {
                try {
                    mApp.mSession.stop();
                    mApp.mSession.discard();
                    System.println("Activity recording discarded");
                } catch (e) {
                    System.println("Error discarding activity: " + e.getErrorMessage());
                }
            }
        }
        
        // Exit the app
        System.exit();
        return true;
    }
}