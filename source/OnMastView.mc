// OnMastView.mc - Display with PNG digit images for VMG and wind angle
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
    
    // Feedback flags and timers
    private var mShowLapFeedback;
    private var mLapFeedbackTimer;
    private var mShowWindResetFeedback;
    private var mWindResetFeedbackTimer;
    
    // Bitmap resources for VMG (white)
    private var mDigit0Bitmap;
    private var mDigit1Bitmap;
    private var mDigit2Bitmap;
    private var mDigit3Bitmap;
    private var mDigit4Bitmap;
    private var mDigit5Bitmap;
    private var mDigit6Bitmap;
    private var mDigit7Bitmap;
    private var mDigit8Bitmap;
    private var mDigit9Bitmap;
    private var mBlankBitmap;
    private var mDecimalWhite;
    
    // Bitmap resources for Wind Angle (green - starboard tack)
    private var mDigit0SmallGreen;
    private var mDigit1SmallGreen;
    private var mDigit2SmallGreen;
    private var mDigit3SmallGreen;
    private var mDigit4SmallGreen;
    private var mDigit5SmallGreen;
    private var mDigit6SmallGreen;
    private var mDigit7SmallGreen;
    private var mDigit8SmallGreen;
    private var mDigit9SmallGreen;
    private var mBlankSmall;
    private var mDegreeSymbolGreen;
    
    // Bitmap resources for Wind Angle (red - port tack)
    private var mDigit0SmallRed;
    private var mDigit1SmallRed;
    private var mDigit2SmallRed;
    private var mDigit3SmallRed;
    private var mDigit4SmallRed;
    private var mDigit5SmallRed;
    private var mDigit6SmallRed;
    private var mDigit7SmallRed;
    private var mDigit8SmallRed;
    private var mDigit9SmallRed;
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
        
        // Initialize feedback flags
        mShowLapFeedback = false;
        mLapFeedbackTimer = 0;
        mShowWindResetFeedback = false;
        mWindResetFeedbackTimer = 0;
        
        // Load bitmap resources for VMG
        mDigit0Bitmap = WatchUi.loadResource(Rez.Drawables.Digit0);
        mDigit1Bitmap = WatchUi.loadResource(Rez.Drawables.Digit1);
        mDigit2Bitmap = WatchUi.loadResource(Rez.Drawables.Digit2);
        mDigit3Bitmap = WatchUi.loadResource(Rez.Drawables.Digit3);
        mDigit4Bitmap = WatchUi.loadResource(Rez.Drawables.Digit4);
        mDigit5Bitmap = WatchUi.loadResource(Rez.Drawables.Digit5);
        mDigit6Bitmap = WatchUi.loadResource(Rez.Drawables.Digit6);
        mDigit7Bitmap = WatchUi.loadResource(Rez.Drawables.Digit7);
        mDigit8Bitmap = WatchUi.loadResource(Rez.Drawables.Digit8);
        mDigit9Bitmap = WatchUi.loadResource(Rez.Drawables.Digit9);
        mBlankBitmap = WatchUi.loadResource(Rez.Drawables.blank);
        mDecimalWhite = WatchUi.loadResource(Rez.Drawables.decimalWhite);
        
        // Load bitmap resources for Wind Angle (Green - Starboard)
        mDigit0SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit0SmallGreen);
        mDigit1SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit1SmallGreen);
        mDigit2SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit2SmallGreen);
        mDigit3SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit3SmallGreen);
        mDigit4SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit4SmallGreen);
        mDigit5SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit5SmallGreen);
        mDigit6SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit6SmallGreen);
        mDigit7SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit7SmallGreen);
        mDigit8SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit8SmallGreen);
        mDigit9SmallGreen = WatchUi.loadResource(Rez.Drawables.Digit9SmallGreen);
        mBlankSmall = WatchUi.loadResource(Rez.Drawables.blankSmall);
        mDegreeSymbolGreen = WatchUi.loadResource(Rez.Drawables.degreeSymbolGreen);
        
        // Load bitmap resources for Wind Angle (Red - Port)
        mDigit0SmallRed = WatchUi.loadResource(Rez.Drawables.Digit0SmallRed);
        mDigit1SmallRed = WatchUi.loadResource(Rez.Drawables.Digit1SmallRed);
        mDigit2SmallRed = WatchUi.loadResource(Rez.Drawables.Digit2SmallRed);
        mDigit3SmallRed = WatchUi.loadResource(Rez.Drawables.Digit3SmallRed);
        mDigit4SmallRed = WatchUi.loadResource(Rez.Drawables.Digit4SmallRed);
        mDigit5SmallRed = WatchUi.loadResource(Rez.Drawables.Digit5SmallRed);
        mDigit6SmallRed = WatchUi.loadResource(Rez.Drawables.Digit6SmallRed);
        mDigit7SmallRed = WatchUi.loadResource(Rez.Drawables.Digit7SmallRed);
        mDigit8SmallRed = WatchUi.loadResource(Rez.Drawables.Digit8SmallRed);
        mDigit9SmallRed = WatchUi.loadResource(Rez.Drawables.Digit9SmallRed);
        mDegreeSymbolRed = WatchUi.loadResource(Rez.Drawables.degreeSymbolRed);
        
        // Get initial values from wind tracker
        updateFromWindTracker();
    }
    
    // Display lap feedback for a short time
    function showLapFeedback() {
        mShowLapFeedback = true;
        mLapFeedbackTimer = System.getTimer();
        WatchUi.requestUpdate();
    }
    
    // Display wind reset feedback for a short time
    function showWindResetFeedback() {
        mShowWindResetFeedback = true;
        mWindResetFeedbackTimer = System.getTimer();
        WatchUi.requestUpdate();
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
        
        // Check feedback timers
        var currentTime = System.getTimer();
        
        // Check if lap feedback should be turned off (after 2 seconds)
        if (mShowLapFeedback && currentTime - mLapFeedbackTimer > 2000) {
            mShowLapFeedback = false;
            WatchUi.requestUpdate();
        }
        
        // Check if wind reset feedback should be turned off (after 2 seconds)
        if (mShowWindResetFeedback && currentTime - mWindResetFeedbackTimer > 2000) {
            mShowWindResetFeedback = false;
            WatchUi.requestUpdate();
        }
        
        return true;
    }
    
    // Helper function to get the appropriate VMG digit bitmap
    function getVmgDigitBitmap(digit) {
        // Handle null input
        if (digit == null) {
            return mBlankBitmap;
        }
        
        // Ensure digit is an integer
        var digitInt = 0;
        if (digit instanceof Float) {
            digitInt = digit.toNumber();
        } else {
            digitInt = digit;
        }
        
        switch(digitInt) {
            case 0: return mDigit0Bitmap;
            case 1: return mDigit1Bitmap;
            case 2: return mDigit2Bitmap;
            case 3: return mDigit3Bitmap;
            case 4: return mDigit4Bitmap;
            case 5: return mDigit5Bitmap;
            case 6: return mDigit6Bitmap;
            case 7: return mDigit7Bitmap;
            case 8: return mDigit8Bitmap;
            case 9: return mDigit9Bitmap;
            default: return mBlankBitmap;
        }
    }
    
    // Helper function to get the appropriate Wind Angle digit bitmap (green or red based on tack)
    function getAngleDigitBitmap(digit, isStarboard) {
        // Handle null input
        if (digit == null) {
            return mBlankSmall;
        }
        
        // Ensure digit is an integer
        var digitInt = 0;
        if (digit instanceof Float) {
            digitInt = digit.toNumber();
        } else {
            digitInt = digit;
        }
        
        if (isStarboard) {
            // Starboard tack - green
            switch(digitInt) {
                case 0: return mDigit0SmallGreen;
                case 1: return mDigit1SmallGreen;
                case 2: return mDigit2SmallGreen;
                case 3: return mDigit3SmallGreen;
                case 4: return mDigit4SmallGreen;
                case 5: return mDigit5SmallGreen;
                case 6: return mDigit6SmallGreen;
                case 7: return mDigit7SmallGreen;
                case 8: return mDigit8SmallGreen;
                case 9: return mDigit9SmallGreen;
                default: return mBlankSmall;
            }
        } else {
            // Port tack - red
            switch(digitInt) {
                case 0: return mDigit0SmallRed;
                case 1: return mDigit1SmallRed;
                case 2: return mDigit2SmallRed;
                case 3: return mDigit3SmallRed;
                case 4: return mDigit4SmallRed;
                case 5: return mDigit5SmallRed;
                case 6: return mDigit6SmallRed;
                case 7: return mDigit7SmallRed;
                case 8: return mDigit8SmallRed;
                case 9: return mDigit9SmallRed;
                default: return mBlankSmall;
            }
        }
    }
    
    // Draw view
    function onUpdate(dc) {
        // Always update from wind tracker
        updateFromWindTracker();
        
        // Get absolute wind angle value
        var absWindAngle = 0;
        if (mWindAngle instanceof Float) {
            absWindAngle = (mWindAngle < 0) ? (-mWindAngle).toNumber() : mWindAngle.toNumber();
        } else {
            absWindAngle = (mWindAngle < 0) ? -mWindAngle : mWindAngle;
        }
        
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        
        // Format VMG to string with one decimal place
        var vmgStr = mVmg.format("%.1f");
        
        // Format wind angle to string (no decimal)
        var angleStr = absWindAngle.toString();
        
        // Get VMG digit image heights
        var vmgDigitHeight = 0;
        if (mDigit0Bitmap != null) {
            vmgDigitHeight = mDigit0Bitmap.getHeight();
        }
        
        // Get Wind Angle digit image heights
        var angleDigitHeight = 0;
        if (mDigit0SmallGreen != null) {
            angleDigitHeight = mDigit0SmallGreen.getHeight();
        }
        
        // Fixed VMG position coordinates as in your original sample
        var vmgStartX = width/2 - 45;
        var vmgY = height/2 - 120;
        
        // Fixed Wind Angle position coordinates
        var angleStartX = width/2 - 120;
        var angleY = height/2 - 80;
        
        // For VMG: Extract the digits directly and handle each position separately
        var vmgInt = 0;
        var vmgDecimal = 0;
        
        // Parse the VMG string to extract the integer and decimal parts
        var decimalPos = vmgStr.find(".");
        if (decimalPos != null && decimalPos != -1) {
            try {
                vmgInt = vmgStr.substring(0, decimalPos).toNumber();
            } catch (e) {
                vmgInt = 0;
            }
            
            if (decimalPos < vmgStr.length() - 1) {
                try {
                    vmgDecimal = vmgStr.substring(decimalPos + 1, decimalPos + 2).toNumber();
                } catch (e) {
                    vmgDecimal = 0;
                }
            }
        } else {
            try {
                vmgInt = vmgStr.toNumber();
            } catch (e) {
                vmgInt = 0;
            }
        }
        
        // Handle VMG display based on whether it's one or two digits
        var digit1 = null;
        var digit2 = null;
        
        if (vmgInt >= 10) {
            // Two-digit number: split into individual digits
            digit1 = (vmgInt / 10).toNumber();
            digit2 = (vmgInt % 10).toNumber();
        } else {
            // Single-digit number: use blank for first position, number for second
            digit1 = null;
            digit2 = vmgInt;
        }
        
        // Draw VMG digits as in your original positioning
        // First digit
        var firstDigitBitmap = getVmgDigitBitmap(digit1);
        if (firstDigitBitmap != null) {
            dc.drawBitmap(vmgStartX, vmgY, firstDigitBitmap);
        }
        
        // Second digit
        var secondDigitBitmap = getVmgDigitBitmap(digit2);
        if (secondDigitBitmap != null) {
            dc.drawBitmap(vmgStartX, vmgY + vmgDigitHeight, secondDigitBitmap);
        }
        
        // Decimal point
        if (mDecimalWhite != null) {
            dc.drawBitmap(vmgStartX, vmgY + vmgDigitHeight * 1.5 + 4 , mDecimalWhite);
        }
        
        // Decimal digit
        var decimalDigitBitmap = getVmgDigitBitmap(vmgDecimal);
        if (decimalDigitBitmap != null) {
            dc.drawBitmap(vmgStartX, vmgY + vmgDigitHeight * 2 + 9, decimalDigitBitmap);
        }
        
        // Handle Wind Angle display (1-3 digits)
        var angleDigit1 = null;
        var angleDigit2 = null;
        var angleDigit3 = null;
        
        // Ensure we have an integer value
        var absAngleInt = absWindAngle.toNumber();
        
        if (absAngleInt >= 100) {
            // Three-digit angle (100-359)
            angleDigit1 = (absAngleInt / 100).toNumber();
            angleDigit2 = ((absAngleInt % 100) / 10).toNumber();
            angleDigit3 = (absAngleInt % 10).toNumber();
        } else if (absAngleInt >= 10) {
            // Two-digit angle (10-99)
            angleDigit1 = null;
            angleDigit2 = (absAngleInt / 10).toNumber();
            angleDigit3 = (absAngleInt % 10).toNumber();
        } else {
            // Single-digit angle (0-9)
            angleDigit1 = null;
            angleDigit2 = null;
            angleDigit3 = absAngleInt;
        }
        
        // Draw Wind Angle digits
        // First digit
        var firstAngleDigitBitmap = getAngleDigitBitmap(angleDigit1, mIsStbdTack);
        if (firstAngleDigitBitmap != null) {
            dc.drawBitmap(angleStartX, angleY, firstAngleDigitBitmap);
        }
        
        // Second digit
        var secondAngleDigitBitmap = getAngleDigitBitmap(angleDigit2, mIsStbdTack);
        if (secondAngleDigitBitmap != null) {
            dc.drawBitmap(angleStartX, angleY + angleDigitHeight, secondAngleDigitBitmap);
        }
        
        // Third digit
        var thirdAngleDigitBitmap = getAngleDigitBitmap(angleDigit3, mIsStbdTack);
        if (thirdAngleDigitBitmap != null) {
            dc.drawBitmap(angleStartX, angleY + 2 * angleDigitHeight, thirdAngleDigitBitmap);
        }
        
        // Degree symbol
        var degreeSymbol = mIsStbdTack ? mDegreeSymbolGreen : mDegreeSymbolRed;
        if (degreeSymbol != null) {
            dc.drawBitmap(angleStartX, angleY + 2.5 * angleDigitHeight, degreeSymbol);
        }
        
        // Draw lap feedback if active
        if (mShowLapFeedback) {
            // Draw LAP MARKER notice at the top of the screen
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            dc.fillRectangle(0, 0, width, 25);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, 2, Graphics.FONT_SMALL, "LAP MARKED", Graphics.TEXT_JUSTIFY_CENTER);
        }
        
        // Draw wind reset feedback if active
        if (mShowWindResetFeedback) {
            // Draw "WIND RESET" in gray at the top of the screen (where VMG debug text normally goes)
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width/2, 20, Graphics.FONT_SMALL, "WIND RESET", Graphics.TEXT_JUSTIFY_CENTER);
        }
        else {
            // Display regular debug info when no feedback is showing
            // dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            // dc.drawText(width/2, 20, Graphics.FONT_SMALL, "VMG: " + vmgStr, Graphics.TEXT_JUSTIFY_CENTER);
            // dc.drawText(width/2, height - 20, Graphics.FONT_SMALL, "Angle: " + angleStr + "° (" + (mIsStbdTack ? "Starboard" : "Port") + ")", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}