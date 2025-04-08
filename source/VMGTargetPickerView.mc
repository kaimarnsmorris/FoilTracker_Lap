// VMGTargetPickerView.mc - For selecting target upwind VMG

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Attention;

// VMG Target Picker View
class VMGTargetPickerView extends WatchUi.View {
    private var mModel;
    public var mSelectedIndex;
    public var mVMGOptions;  // Changed to public for delegate access
    
    function initialize(model) {
        View.initialize();
        mModel = model;
        mSelectedIndex = 0; // Default to 10.0 kt upwind VMG (first option)
        
        // Create VMG options from 10.0 to 16.0 knots (in 1.0 knot increments)
        mVMGOptions = [];
        for (var i = 10; i <= 16; i++) {
            var vmg = i.toString() + ".0 kt";
            mVMGOptions.add(vmg);
        }
    }
    
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Draw title - MOVED DOWN 20px from original position
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 30, Graphics.FONT_SMALL, "Target Upwind VMG", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider - ALSO MOVED DOWN
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(10, 55, width-10, 55);
        
        // Draw the selected option with highlight color
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/2, Graphics.FONT_LARGE, mVMGOptions[mSelectedIndex], Graphics.TEXT_JUSTIFY_CENTER);
        
        // Get font height to better position arrows
        var mediumFontHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var arrowOffset = mediumFontHeight / 2;
        
        // Draw prev/next indicators
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        
        // Draw up arrow for previous option
        if (mSelectedIndex > 0) {
            dc.drawLine(width/2, height/2 - 40, width/2 - 10, height/2 - 30);
            dc.drawLine(width/2, height/2 - 40, width/2 + 10, height/2 - 30);
            dc.drawLine(width/2 - 10, height/2 - 30, width/2 + 10, height/2 - 30);
        }
        
        // Draw down arrow for next option - MOVED DOWN 40px
        if (mSelectedIndex < mVMGOptions.size() - 1) {
            dc.drawLine(width/2, height/2 + 80, width/2 - 10, height/2 + 70);
            dc.drawLine(width/2, height/2 + 80, width/2 + 10, height/2 + 70);
            dc.drawLine(width/2 - 10, height/2 + 70, width/2 + 10, height/2 + 70);
        }
        
        // Draw instruction at bottom - MOVED UP 20px from original position
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height - 50, Graphics.FONT_TINY, "SELECT to confirm", Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    // Get the selected VMG value (numeric)
    function getSelectedVMG() {
        return 10.0 + mSelectedIndex;
    }
}

// VMG Target Picker Delegate
class VMGTargetPickerDelegate extends WatchUi.BehaviorDelegate {
    private var mModel;
    private var mPickerView;
    private var mApp;
    
    function initialize(model, app) {
        BehaviorDelegate.initialize();
        mModel = model;
        mApp = app;
        mPickerView = null;
    }
    
    function setPickerView(view) {
        mPickerView = view;
    }
    
    function onNextPage() {
        if (mPickerView != null) {
            // Access the size through the view's property
            var optionsSize = mPickerView.mVMGOptions.size();
            if (mPickerView.mSelectedIndex < optionsSize - 1) {
                mPickerView.mSelectedIndex++;
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
    
    function onPreviousPage() {
        if (mPickerView != null) {
            if (mPickerView.mSelectedIndex > 0) {
                mPickerView.mSelectedIndex--;
                WatchUi.requestUpdate();
            }
        }
        return true;
    }
    
    function onSelect() {
        try {
            // Get selected VMG
            var targetVMG = mPickerView.getSelectedVMG();
            
            // Store in model
            if (mModel != null) {
                var data = mModel.getData();
                if (!data.hasKey("targetSettings")) {
                    data["targetSettings"] = {};
                }
                data["targetSettings"]["targetUpwindVMG"] = targetVMG;
                System.println("Target upwind VMG set to: " + targetVMG + " kt");
                
                // Vibrate twice as a sample - longer vibration
                if (Attention has :vibrate) {
                    var pattern = [new Attention.VibeProfile(100, 600)];
                    Attention.vibrate(pattern);
                }
            }
            
            // Now start the activity session with the wind and target data
            if (mApp != null) {
                // Start the activity recording session
                mApp.startActivitySession();
                
                // Switch to the main app view
                var view = new FoilTrackerView(mModel);
                var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
                WatchUi.switchToView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
            }
        } catch (e) {
            System.println("Error in VMGTargetPickerDelegate: " + e.getErrorMessage());
            
            // Fall back to starting the session
            if (mApp != null) {
                mApp.startActivitySession();
                var view = new FoilTrackerView(mModel);
                var delegate = new FoilTrackerDelegate(view, mModel, mApp.getWindTracker());
                WatchUi.switchToView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
            }
        }
        
        return true;
    }
    
    function onBack() {
        // Go back to speed target picker
        var speedView = new SpeedTargetPickerView(mModel);
        var speedDelegate = new SpeedTargetPickerDelegate(mModel, mApp);
        speedDelegate.setPickerView(speedView);
        
        WatchUi.switchToView(speedView, speedDelegate, WatchUi.SLIDE_DOWN);
        return true;
    }
}
