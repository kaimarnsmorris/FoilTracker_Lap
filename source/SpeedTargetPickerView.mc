// SpeedTargetPickerView.mc - For selecting target max speed

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Attention;

// Speed Target Picker View
class SpeedTargetPickerView extends WatchUi.View {
    private var mModel;
    public var mSelectedIndex;
    public var mSpeedOptions;  // Public so delegate can access it
    
    function initialize(model) {
        View.initialize();
        mModel = model;
        mSelectedIndex = 0; // Default to 18 knots (first option)
        
        // Create speed options from 18 to 28 knots
        mSpeedOptions = [];
        for (var i = 18; i <= 28; i++) {
            mSpeedOptions.add(i.toString() + " kt");
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
        dc.drawText(width/2, 30, Graphics.FONT_SMALL, "Target Max Speed", Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider - ALSO MOVED DOWN
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(10, 55, width-10, 55);
        
        // Draw the selected option with highlight color
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height/2, Graphics.FONT_LARGE, mSpeedOptions[mSelectedIndex], Graphics.TEXT_JUSTIFY_CENTER);
        
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
        if (mSelectedIndex < mSpeedOptions.size() - 1) {
            dc.drawLine(width/2, height/2 + 80, width/2 - 10, height/2 + 70);
            dc.drawLine(width/2, height/2 + 80, width/2 + 10, height/2 + 70);
            dc.drawLine(width/2 - 10, height/2 + 70, width/2 + 10, height/2 + 70);
        }
        
        // Draw instruction at bottom - MOVED UP 20px from original position
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height - 50, Graphics.FONT_TINY, "SELECT to confirm", Graphics.TEXT_JUSTIFY_CENTER);
    }
    
    // Get the selected speed value (numeric)
    function getSelectedSpeed() {
        return 18 + mSelectedIndex;
    }
}

// Speed Target Picker Delegate
class SpeedTargetPickerDelegate extends WatchUi.BehaviorDelegate {
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
            var optionsSize = mPickerView.mSpeedOptions.size();
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
            // Get selected speed
            var targetSpeed = mPickerView.getSelectedSpeed();
            
            // Store in model
            if (mModel != null) {
                var data = mModel.getData();
                if (!data.hasKey("targetSettings")) {
                    data["targetSettings"] = {};
                }
                data["targetSettings"]["targetMaxSpeed"] = targetSpeed;
                System.println("Target max speed set to: " + targetSpeed + " kt");
                
                // Vibrate once as a sample - short vibration
                if (Attention has :vibrate) {
                    var pattern = [new Attention.VibeProfile(100, 300)];
                    Attention.vibrate(pattern);
                }
            }
            
            // Switch to VMG target picker
            var vmgView = new VMGTargetPickerView(mModel);
            var vmgDelegate = new VMGTargetPickerDelegate(mModel, mApp);
            vmgDelegate.setPickerView(vmgView);
            
            WatchUi.switchToView(vmgView, vmgDelegate, WatchUi.SLIDE_LEFT);
        } catch (e) {
            System.println("Error in SpeedTargetPickerDelegate: " + e.getErrorMessage());
            
            // Fall back to wind angle picker
            var windAngleView = new WindAnglePickerView(mModel);
            var windAngleDelegate = new WindAnglePickerDelegate(mModel, mApp);
            windAngleDelegate.setPickerView(windAngleView);
            
            WatchUi.switchToView(windAngleView, windAngleDelegate, WatchUi.SLIDE_LEFT);
        }
        
        return true;
    }
    
    function onBack() {
        // Go back to wind strength picker
        var windView = new WindStrengthPickerView(mModel);
        var windDelegate = new StartupWindStrengthDelegate(mModel, mApp);
        windDelegate.setPickerView(windView);
        
        WatchUi.switchToView(windView, windDelegate, WatchUi.SLIDE_DOWN);
        return true;
    }
}