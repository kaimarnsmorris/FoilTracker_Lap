// OnMastView.mc - Test implementation with PNG images and conditional display
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Application;

class OnMastView extends WatchUi.View {
    private var mModel;
    private var mWindTracker;
    private var mVmg;
    private var mWindAngle;
    private var mIsStbdTack;
    
    // Bitmap resources
    private var mDigit1Bitmap;
    private var mDigit9Bitmap;

    private var mDigit9BitmapSmallRed;
    private var mDigit9BitmapSmallGreen;

    private var mDecimalWhite;
    private var mDegreeSymbolGreen;
    private var mDegreeSymbolRed;



    // Constructor
    function initialize(model, windTracker) {
        View.initialize();
        mModel = model;
        mWindTracker = windTracker;
        
        // Initialize with default values
        mVmg = 0.0;
        mWindAngle = 0;
        mIsStbdTack = true;
        
        // Load bitmap resources
        mDigit1Bitmap = WatchUi.loadResource(Rez.Drawables.Digit1);
        mDigit9Bitmap = WatchUi.loadResource(Rez.Drawables.Digit9);
        
        mDigit9BitmapSmallGreen = WatchUi.loadResource(Rez.Drawables.Digit1SmallGreen);
        mDigit9BitmapSmallRed = WatchUi.loadResource(Rez.Drawables.Digit9SmallRed);

        mDegreeSymbolRed = WatchUi.loadResource(Rez.Drawables.DegreeSymbolRed);
        mDegreeSymbolGreen = WatchUi.loadResource(Rez.Drawables.DegreeSymbolGreen);
        mDecimalWhite = WatchUi.loadResource(Rez.Drawables.DecimalWhite);




        // Get initial values from wind tracker
        updateFromWindTracker();
    }
    
    // Update data from wind tracker
    function updateFromWindTracker() {
        var windData = mWindTracker.getWindData();
        
        if (windData != null && windData.hasKey("valid") && windData["valid"]) {
            // Get VMG
            if (windData.hasKey("currentVMG")) { 
                mVmg = windData["currentVMG"]; 
            }
            
            // Get wind angle
            if (windData.hasKey("windAngleLessCOG")) {
                mWindAngle = windData["windAngleLessCOG"];
            }
            
            // Determine tack (starboard or port)
            if (windData.hasKey("tackColorId")) {
                mIsStbdTack = (windData["tackColorId"] == 1);
            }
        }
        
        return true;
    }
    
    // Draw view
    function onUpdate(dc) {
        // Always update from wind tracker
        updateFromWindTracker();
        
        // Get absolute wind angle value
        var absWindAngle = (mWindAngle < 0) ? -mWindAngle : mWindAngle;
        
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Determine which digit to show based on VMG decimal
        var vmgStr = mVmg.format("%.1f");
        var vmgDecimal = 0;
        
        // Parse the decimal part from the string
        var decimalPos = vmgStr.find(".");
        if (decimalPos != null && decimalPos != -1 && decimalPos < vmgStr.length() - 1) {
            // Extract the first decimal digit
            vmgDecimal = vmgStr.substring(decimalPos + 1, decimalPos + 2).toNumber();
        }
        
        // Log the value we're using to determine the display
        System.println("VMG: " + vmgStr + ", Decimal: " + vmgDecimal + ", IsOdd: " + (vmgDecimal % 2 == 1));
        
        // Choose bitmap based on whether decimal is odd or even
        var digitBitmap = (vmgDecimal % 2 == 1) ? mDigit1Bitmap : mDigit9Bitmap;
        var digitBitmapSmall = (vmgDecimal % 2 == 1) ? mDigit9BitmapSmallGreen : mDigit9BitmapSmallRed;
        
        // Draw the selected digit in the center
        if (digitBitmap != null) {
            var bmpWidth = digitBitmap.getWidth();
            var bmpHeight = digitBitmap.getHeight();

            var smallBmpWidth = digitBitmapSmall.getWidth();
            var smallBmpHeight = digitBitmapSmall.getHeight();

            dc.drawBitmap(width/2 -45, height/2 - 120 , digitBitmap);
            dc.drawBitmap(width/2 -45, height/2 - 120 + bmpHeight, digitBitmap);
            dc.drawBitmap(width/2 -45, height/2 - 110 + 1.5 * bmpHeight, mDecimalWhite);
            dc.drawBitmap(width/2 -45, height/2 - 105 + 2 * bmpHeight, digitBitmap);
            
            dc.drawBitmap(width/2 -120, height/2 - 80 , digitBitmapSmall);
            dc.drawBitmap(width/2 -120, height/2 - 80 + smallBmpHeight, digitBitmapSmall);
            dc.drawBitmap(width/2 -120, height/2 - 80 + 2.5 * smallBmpHeight, mDegreeSymbolGreen);           
            dc.drawBitmap(width/2 -120, height/2 - 80 + 2 * smallBmpHeight, digitBitmapSmall);
            

            // Draw which digit is showing and why
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            if (vmgDecimal % 2 == 1) {
                dc.drawText(width/2, height - 40, Graphics.FONT_SMALL, "Showing 1 (odd decimal)", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(width/2, height - 40, Graphics.FONT_SMALL, "Showing 9 (even decimal)", Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            // Fallback if bitmap failed to load
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, height/2, Graphics.FONT_MEDIUM, "Image failed to load", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        // Display debug info at the top
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, 20, Graphics.FONT_SMALL, "VMG: " + vmgStr, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width/2, 45, Graphics.FONT_SMALL, "Change VMG to test", Graphics.TEXT_JUSTIFY_CENTER);
    }
}