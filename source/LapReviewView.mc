using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Application;

// View class for displaying lap review data
class LapReviewView extends WatchUi.View {
    // Layout constants for FR 255 dimensions
    private const MARGIN_SIDE = 10;             // Side margin
    
    // Key vertical positioning
    private const HEAD_DIST_FROM_TOP = 1;       // Lap title position from top
    private const HORZ_LINE_DIST_FROM_TOP = 31; // Horizontal line distance from top
    private const SECTION1_DIST_FROM_TOP = 30;  // Main stats section start from top
    private const SECTION2_DIST_FROM_TOP = 125; // Upwind/Downwind section start from top
    private const TIMESTAMP_DIST_FROM_BOTTOM = 20; // Timestamps distance from bottom
    
    // Horizontal positioning
    private const SECTION1_DIST_FROM_MIDDLE = 20;    // Distance from middle for main stats
    private const SECTION2_DIST_FROM_EDGE_LEFT = 5;  // Left column indent from edge
    private const SECTION2_DIST_FROM_EDGE_RIGHT = 5; // Right column indent from edge
    
    // Spacing values
    private const LINE_SPACING = 21;            // Vertical spacing between lines
    private const SECTION_SPACING = 15;         // Spacing between major sections
    private const LABEL_WIDTH = 60;             // Width for labels
    
    // Member variables
    private var mModel;
    private var mWindTracker;
    private var mCurrentLapIndex;
    private var mTotalLaps;
    private var mLapData;
    
    // Constructor
    function initialize(model, windTracker) {
        View.initialize();
        mModel = model;
        mWindTracker = windTracker;
        mCurrentLapIndex = 0;
        mTotalLaps = 0;
        mLapData = {};
        
        // Load lap data
        loadLapData();
    }
    
    // ---- DEBUG FUNCTION ----
    // This function prints the contents of a dictionary to help debug data format issues
    function debugDictionary(dict, label) {
        if (dict == null) {
            System.println(label + ": NULL dictionary");
            return;
        }
        
        System.println(label + " - Keys available:");
        var keys = dict.keys();
        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i];
            var valueType = "unknown";
            var valueStr = "?";
            
            try {
                var value = dict[key];
                if (value instanceof String) {
                    valueType = "String";
                    valueStr = value;
                } else if (value instanceof Float) {
                    valueType = "Float";
                    valueStr = value.format("%.2f");
                } else if (value instanceof Number) {
                    valueType = "Number";
                    valueStr = value.toString();
                } else if (value instanceof Boolean) {
                    valueType = "Boolean";
                    valueStr = value.toString();
                } else if (value instanceof Dictionary) {
                    valueType = "Dictionary";
                    valueStr = "Dict with " + value.keys().size() + " keys";
                } else if (value instanceof Array) {
                    valueType = "Array";
                    valueStr = "Array with " + value.size() + " items";
                } else if (value == null) {
                    valueType = "null";
                    valueStr = "null";
                } else {
                    valueType = "Object";
                    valueStr = "Object";
                }
                
                System.println("  - " + key + " (" + valueType + "): " + valueStr);
            } catch (e) {
                System.println("  - " + key + ": ERROR accessing value - " + e.getErrorMessage());
            }
        }
    }
    
    // Complete replacement for loadLapData method in source/LapReviewView.mc
    function loadLapData() {
        System.println("LapReviewView.loadLapData() - Starting");
        
        if (mWindTracker == null) {
            System.println("ERROR: mWindTracker is null");
            return;
        }
        
        var lapTracker = mWindTracker.getLapTracker();
        if (lapTracker == null) {
            System.println("ERROR: lapTracker is null");
            return;
        }
        
        try {
            // Get current lap number
            var currentLap = lapTracker.getCurrentLap();
            
            // Consider the session start as the first lap
            // This ensures we always have at least one lap to display
            mTotalLaps = (currentLap > 0) ? currentLap : 1;
            
            System.println("Total laps detected: " + mTotalLaps);
            
            // Get data for each lap
            for (var i = 1; i <= mTotalLaps; i++) {
                System.println("Processing lap " + i + "...");
                
                // Try to get lap stats for this lap
                var lapStats = lapTracker.getLapStats(i);
                
                if (lapStats != null) {
                    // Debug the contents of lapStats for the current lap
                    debugDictionary(lapStats, "Lap " + i + " data from getLapStats");
                    
                    // Store the stats
                    mLapData[i] = lapStats;
                } else if (i == 1) {
                    // Create default data for first lap if not available
                    System.println("Creating default data for first lap");
                    mLapData[i] = createDefaultLapData();
                    
                    // Try to enhance with real data from other components
                    var defaultData = mLapData[i];
                    
                    // Add wind tracker data if available
                    if (mWindTracker != null) {
                        var windData = mWindTracker.getWindData();
                        if (windData != null) {
                            if (windData.hasKey("currentVMG")) {
                                defaultData["lapVMG"] = windData["currentVMG"];
                            }
                            if (windData.hasKey("windDirection")) {
                                defaultData["windDirection"] = windData["windDirection"];
                            }
                        }
                    }
                    
                    // Add model data if available 
                    var app = Application.getApp();
                    var modelData = null;
                    
                    // Use the app's modelData getter if available
                    if (app has :getModelData) {
                        modelData = app.getModelData();
                    }
                    
                    if (modelData != null) {
                        if (modelData.hasKey("maxSpeed")) {
                            defaultData["maxSpeed"] = modelData["maxSpeed"];
                        }
                        if (modelData.hasKey("max3sSpeed")) {
                            defaultData["max3sSpeed"] = modelData["max3sSpeed"];
                        }
                        if (modelData.hasKey("percentOnFoil")) {
                            defaultData["pctOnFoil"] = modelData["percentOnFoil"];
                        }
                    }
                    
                    // Add maneuver detector data if available
                    if (mWindTracker.getManeuverDetector() != null) {
                        var maneuverData = mWindTracker.getManeuverDetector().getData();
                        if (maneuverData != null) {
                            defaultData["tackCount"] = maneuverData["lapDisplayTackCount"];
                            defaultData["displayTackCount"] = maneuverData["displayTackCount"];
                            defaultData["gybeCount"] = maneuverData["lapDisplayGybeCount"];
                            defaultData["displayGybeCount"] = maneuverData["displayGybeCount"];
                        }
                    }
                }
            }
            
            // Start with most recent lap
            mCurrentLapIndex = mTotalLaps;
            System.println("Lap data loaded. Starting at lap " + mCurrentLapIndex);
        } catch (e) {
            System.println("ERROR in loadLapData: " + e.getErrorMessage());
        }
    }
    
    // Create default lap data for first lap
    function createDefaultLapData() {
        // Create a basic stats object with zeros
        return {
            "maxSpeed" => 0.0,
            "max3sSpeed" => 0.0,
            "avgSpeed" => 0.0,
            "pctOnFoil" => 0,
            "tackCount" => 0,
            "gybeCount" => 0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "vmgUp" => 0.0,
            "vmgDown" => 0.0,
            "startTime" => System.getTimer()
        };
    }
    
    // Move to previous lap (newer lap in time)
    function previousLap() {
        if (mCurrentLapIndex < mTotalLaps) {
            mCurrentLapIndex++;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
    
    // Move to next lap (older lap in time)
    function nextLap() {
        if (mCurrentLapIndex > 1) {
            mCurrentLapIndex--;
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
    
    // Get current lap index
    function getCurrentLapIndex() {
        return mCurrentLapIndex;
    }
    
    // Format time string from seconds
    function formatTimeString(seconds) {
        var mins = (seconds / 60).toNumber();
        var secs = (seconds % 60).toNumber();
        return mins.format("%d") + ":" + secs.format("%02d");
    }
    
    // Format time from system timer value
    function formatTimeFromSystem(timerValue) {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var minute = clockTime.min;
        return hour.format("%02d") + ":" + minute.format("%02d");
    }
    
    // Format time from milliseconds value
    function formatTimeFromMilliseconds(milliseconds) {
        // If milliseconds is very small, it might be in seconds already
        if (milliseconds < 1000 && milliseconds > 0) {
            milliseconds *= 1000;
        }
        
        try {
            // Convert milliseconds to clock time - simplified for demo
            var totalSeconds = milliseconds / 1000;
            var minutes = (totalSeconds / 60).toNumber() % 60;
            var hours = (totalSeconds / 3600).toNumber() % 24;
            
            // For demo purposes, create a simulated timestamp
            return hours.format("%02d") + ":" + minutes.format("%02d");
        } catch (e) {
            System.println("Error formatting time: " + e.getErrorMessage());
            return "--:--"; // Return placeholder on error
        }
    }
    
    // Convert m/s to knots
    function metersPerSecondToKnots(mps) {
        return mps * 1.943844;
    }
    
    // Update the view
    function onUpdate(dc) {
        // Clear the screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Get screen dimensions
        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width/2;
        
        // Check if we have data
        if (mTotalLaps == 0 || mCurrentLapIndex <= 0 || mCurrentLapIndex > mTotalLaps) {
            // No lap data available
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height/2, Graphics.FONT_TINY, "No Lap Data", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        
        // Get current lap data
        var lapData = mLapData[mCurrentLapIndex];
        if (lapData == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(centerX, height/2, Graphics.FONT_TINY, "No Data for Lap " + mCurrentLapIndex, Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        
        // Debug the contents of the current lap data
        debugDictionary(lapData, "Current lap data for display");
        System.println("Displaying data for lap: " + mCurrentLapIndex + " of " + mTotalLaps);
        
        // ---- DRAW LAP TITLE ----
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, HEAD_DIST_FROM_TOP, Graphics.FONT_TINY, "Lap " + mCurrentLapIndex, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw horizontal divider below title
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(MARGIN_SIDE, HORZ_LINE_DIST_FROM_TOP, width - MARGIN_SIDE, HORZ_LINE_DIST_FROM_TOP);
        
        // ----- DRAW MAIN STATS SECTION -----
        var yPos = SECTION1_DIST_FROM_TOP; // Start position for stats
        
        // Left and right column positions for text alignment
        var leftTextPos = centerX - SECTION1_DIST_FROM_MIDDLE + 30;
        var rightTextPos = centerX + SECTION1_DIST_FROM_MIDDLE + 50;
        
        // Max Speed
        var maxSpeed = 0.0;
        if (lapData.hasKey("maxSpeed")) {
            maxSpeed = lapData["maxSpeed"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftTextPos, yPos, Graphics.FONT_TINY, "Max:", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(rightTextPos, yPos, Graphics.FONT_TINY, maxSpeed.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // Max 3s Speed
        yPos += LINE_SPACING;
        var max3sSpeed = 0.0;
        if (lapData.hasKey("max3sSpeed")) {
            max3sSpeed = lapData["max3sSpeed"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftTextPos, yPos, Graphics.FONT_TINY, "Max 3s:", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(rightTextPos, yPos, Graphics.FONT_TINY, max3sSpeed.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // Average Speed
        yPos += LINE_SPACING;
        var avgSpeed = 0.0;
        if (lapData.hasKey("avgSpeed")) {
            avgSpeed = lapData["avgSpeed"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftTextPos, yPos, Graphics.FONT_TINY, "Ave:", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(rightTextPos, yPos, Graphics.FONT_TINY, avgSpeed.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // Percentage on Foil
        yPos += LINE_SPACING;
        var pctOnFoil = 0;
        if (lapData.hasKey("pctOnFoil")) {
            pctOnFoil = lapData["pctOnFoil"].toNumber();
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftTextPos, yPos, Graphics.FONT_TINY, "Pct Foil:", Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(rightTextPos, yPos, Graphics.FONT_TINY, pctOnFoil + "%", Graphics.TEXT_JUSTIFY_RIGHT);
        
        // ----- DRAW UPWIND/DOWNWIND HEADERS -----
        yPos = SECTION2_DIST_FROM_TOP;
        
        // Draw upwind/downwind headers closer to the middle
        var upwindX = centerX - 55; // Closer to middle
        var downwindX = centerX + 55; // Closer to middle
        
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(upwindX, yPos, Graphics.FONT_TINY, "Upwind", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(downwindX, yPos, Graphics.FONT_TINY, "Downwind", Graphics.TEXT_JUSTIFY_CENTER);
        
        // ----- DRAW TACK/GYBE STATS -----
        yPos += LINE_SPACING + 10;
        
        var bottomSectionLineSpacing = LINE_SPACING * 2/3;

        // Calculate positions to avoid text overlap and bring closer to middle
        var leftColValue = upwindX + 43;     // Aligned with upwind header
        var rightColValue = downwindX + 43;  // Aligned with downwind header
        var leftColLabel = upwindX - 30;     // Left of upwind header
        var rightColLabel = downwindX - 30;  // Left of downwind header
        
        // Tacks
        var tackCount = 0;
        if (lapData.hasKey("tackCount")) {
            tackCount = lapData["tackCount"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColLabel, yPos, Graphics.FONT_XTINY, "Tacks:", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(leftColValue, yPos, Graphics.FONT_XTINY, tackCount.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // Gybes
        var gybeCount = 0;
        if (lapData.hasKey("gybeCount")) {
            gybeCount = lapData["gybeCount"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightColLabel, yPos, Graphics.FONT_XTINY, "Gybes:", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rightColValue, yPos, Graphics.FONT_XTINY, gybeCount.toString(), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // Average angles
        yPos += LINE_SPACING;
        
        // Average tack angle
        var avgTackAngle = 0;
        if (lapData.hasKey("avgTackAngle")) {
            avgTackAngle = lapData["avgTackAngle"].toNumber();
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColLabel, yPos, Graphics.FONT_XTINY, "Av agl:", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(leftColValue, yPos, Graphics.FONT_XTINY, avgTackAngle + "°", Graphics.TEXT_JUSTIFY_RIGHT);
        
        // Average gybe angle
        var avgGybeAngle = 0;
        if (lapData.hasKey("avgGybeAngle")) {
            avgGybeAngle = lapData["avgGybeAngle"].toNumber();
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightColLabel, yPos, Graphics.FONT_XTINY, "Av agl:", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rightColValue, yPos, Graphics.FONT_XTINY, avgGybeAngle + "°", Graphics.TEXT_JUSTIFY_RIGHT);
        
        // VMG values
        yPos += LINE_SPACING;
        
        // VMG Upwind
        var vmgUp = 0.0;
        if (lapData.hasKey("avgVMGUp")) {
            vmgUp = lapData["avgVMGUp"];
        } else if (lapData.hasKey("vmgUp")) {
            vmgUp = lapData["vmgUp"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(leftColLabel, yPos, Graphics.FONT_XTINY, "VMG:", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(leftColValue, yPos, Graphics.FONT_XTINY, vmgUp.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // VMG Downwind
        var vmgDown = 0.0;
        if (lapData.hasKey("avgVMGDown")) {
            vmgDown = lapData["avgVMGDown"];
        } else if (lapData.hasKey("vmgDown")) {
            vmgDown = lapData["vmgDown"];
        }
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(rightColLabel, yPos, Graphics.FONT_XTINY, "VMG:", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(rightColValue, yPos, Graphics.FONT_XTINY, vmgDown.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT);
        
        // ----- DRAW START/STOP TIMES AT BOTTOM -----
        // Bottom position for timestamps, stacked vertically
        yPos = height - TIMESTAMP_DIST_FROM_BOTTOM;
        
        // Get lap time data
        var startTime = "00:00";
        var stopTime = "--:--";
        
        // Get start time from startTime field if available
        if (lapData.hasKey("startTime")) {
            var timestamp = lapData["startTime"];
            startTime = formatTimeFromMilliseconds(timestamp);
        }
        
        // Get stop time from next lap's start time (if not the current lap)
        if (mCurrentLapIndex < mTotalLaps && mLapData.hasKey(mCurrentLapIndex + 1)) {
            var nextLapData = mLapData[mCurrentLapIndex + 1];
            if (nextLapData != null && nextLapData.hasKey("startTime")) {
                var timestamp = nextLapData["startTime"];
                stopTime = formatTimeFromMilliseconds(timestamp);
            }
        }
        
        // Draw start time
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, yPos - LINE_SPACING, Graphics.FONT_XTINY, "Start: " + startTime, Graphics.TEXT_JUSTIFY_CENTER);
        
        // Draw stop time
        dc.drawText(centerX, yPos, Graphics.FONT_XTINY, "Stop: " + stopTime, Graphics.TEXT_JUSTIFY_CENTER);
    }
}