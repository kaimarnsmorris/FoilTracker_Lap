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
    
    // Handle select button press - Toggle recording (pausing)
    function onSelect() {
        var data = mModel.getData();
        
        // Toggle recording state
        data["isRecording"] = !data["isRecording"];
        
        // Toggle pause/resume state
        var isPaused = !data["isRecording"];
        
        // Call the model's setPauseState function to properly handle pause timing
        mModel.setPauseState(isPaused);
        
        // Request UI update to show pause state
        WatchUi.requestUpdate();
        
        return true;
    }
    
    // Handle back button press - Now used to end session (not pause)
    function onBack() {
        var data = mModel.getData();
        
        // Safer check for recording or paused state
        var isActive = false;
        
        // Check if isRecording exists and is true
        if (data.hasKey("isRecording") && data["isRecording"]) {
            isActive = true;
        }
        
        // Check if sessionPaused exists and is true
        if (data.hasKey("sessionPaused") && data["sessionPaused"]) {
            isActive = true;
        }
        
        // If recording or paused, confirm end session
        if (isActive) {
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
    
    // In FoilTrackerDelegate.mc
    // Make sure you have this specific method name for light button handling
    function onKey(keyEvent) {
        // Check if the key is the LIGHT button
        if (keyEvent.getKey() == WatchUi.KEY_LIGHT || keyEvent.getKey() == WatchUi.KEY_ENTER) {
            System.println("LIGHT button detected!");
            
            var app = Application.getApp();
            
            // Check if the activity is recording
            var data = mModel.getData();
            var isActive = false;
            
            // Only add lap when activity is recording and not paused
            if (data.hasKey("isRecording") && data["isRecording"]) {
                if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                    isActive = true;
                }
            }
            
            if (isActive) {
                System.println("LIGHT BUTTON PRESSED - ADDING LAP");
                
                // Add a lap marker with all custom fields
                app.addLapMarker();
                
                // Show lap feedback in the view if available
                if (mView has :showLapFeedback) {
                    mView.showLapFeedback();
                }
                
                System.println("Lap marker added from Main view");
                return true;
            } else {
                System.println("Cannot add lap marker - not recording or paused");
            }
        }
        
        // Let parent class handle other keys
        return BehaviorDelegate.onKey(keyEvent);
    }

    // NEW FUNCTION: Handle light button press - Add lap marker with custom fields
    // In FoilTrackerDelegate.mc - modify the onLight function
    function onLight() {
        var app = Application.getApp();
        
        // Check if the activity is recording
        var data = mModel.getData();
        var isActive = false;
        
        // Only add lap when activity is recording and not paused
        if (data.hasKey("isRecording") && data["isRecording"]) {
            if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                isActive = true;
            }
        }
        
        if (isActive) {
            System.println("LIGHT BUTTON PRESSED - ADDING LAP");
            
            // Add a lap marker with all custom fields
            app.addLapMarker();
            
            // Show lap feedback in the view if that method exists
            if (mView has :showLapFeedback) {
                mView.showLapFeedback();
            }
            
            System.println("Lap marker added from Main view");
        } else {
            System.println("Cannot add lap marker - not recording or paused");
        }
        
        return true;
    }
    
    // Handle light button press - Add lap marker
    // function onLight() {
    //     var app = Application.getApp();
        
    //     // Check if the activity is recording
    //     var data = mModel.getData();
    //     var isActive = false;
        
    //     // Only add lap when activity is recording and not paused
    //     if (data.hasKey("isRecording") && data["isRecording"]) {
    //         if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
    //             isActive = true;
    //         }
    //     }
        
    //     if (isActive) {
    //         System.println("LIGHT BUTTON PRESSED - ADDING LAP");
            
    //         // Add a lap marker
    //         app.addLapMarker();
            
    //         // Show lap feedback in the view if that method exists
    //         if (mView has :showLapFeedback) {
    //             mView.showLapFeedback();
    //         }
            
    //         System.println("Lap marker added from Main view");
    //     } else {
    //         System.println("Cannot add lap marker - not recording or paused");
    //     }
        
    //     return true;
    // }
    
    // Handle light button long press - Add lap marker with custom fields
    // function onLongLight() {
    //     var app = Application.getApp();
        
    //     // Check if the activity is recording
    //     var data = mModel.getData();
    //     var isActive = false;
        
    //     // Only add lap when activity is recording and not paused
    //     if (data.hasKey("isRecording") && data["isRecording"]) {
    //         if (!(data.hasKey("sessionPaused") && data["sessionPaused"])) {
    //             isActive = true;
    //         }
    //     }
        
    //     if (isActive) {
    //         System.println("LONG LIGHT BUTTON PRESSED - ADDING LAP");
            
    //         // Add a lap marker with all custom fields
    //         app.addLapMarker();
            
    //         // Show lap feedback in the view if that method exists
    //         if (mView has :showLapFeedback) {
    //             mView.showLapFeedback();
    //         }
            
    //         System.println("Lap marker
}