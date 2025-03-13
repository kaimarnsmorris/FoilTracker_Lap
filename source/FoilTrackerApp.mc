// Optimized FoilTrackerApp.mc

using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Position;
using Toybox.Timer;
using Toybox.FitContributor;
using Toybox.Time;

// Main Application class with significant optimizations
class FoilTrackerApp extends Application.AppBase {
    // Core properties - better grouped for clarity
    private var mModel;
    private var mSession;
    private var mTimer;
    private var mWindTracker;
    
    // FIT Field collections - grouped by type
    private var mSessionFields; // Dictionary to hold session fields
    private var mLapFields;     // Dictionary to hold lap fields

    // Constructor with initialization
    function initialize() {
        AppBase.initialize();
        
        // Initialize the model first
        mModel = new FoilTrackerModel();       
        
        // Initialize core objects
        mSession = null;
        mTimer = null;
        mWindTracker = new WindTracker();
        
        // Initialize field collections
        mSessionFields = {};
        mLapFields = {};
    }

    // App startup
    function onStart(state) {
        System.println("App starting");
        
        // Enable position tracking
        enablePositionTracking();
        
        // Start the update timer
        startSimpleTimer();
        System.println("Timer started");
    }
    
    // Separate position tracking setup for clarity
    function enablePositionTracking() {
        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPositionCallback));
            System.println("Position tracking enabled");
        } catch (e) {
            System.println("Error enabling position tracking: " + e.getErrorMessage());
        }
    }

    // Position callback with correct type signature
    function onPositionCallback(posInfo as Position.Info) as Void {
        // Only process if we have valid location info
        if (posInfo == null) { return; }
        
        // Get model data once
        var modelData = mModel != null ? mModel.getData() : null;
        var isActive = modelData != null && 
                      modelData["isRecording"] && 
                      !(modelData.hasKey("sessionPaused") && modelData["sessionPaused"]);
        
        // Process wind tracker data
        if (mWindTracker != null) {
            mWindTracker.processPositionData(posInfo);
            updateTotalCounts();
        }
        
        // Process location data when active
        if (isActive && mModel != null) {
            mModel.processLocationData(posInfo);
        }
        
        // Request UI update
        WatchUi.requestUpdate();
    }

    // Accessor for model data
    function getModelData() {
        return mModel != null ? mModel.getData() : null;
    }

    // Start activity session
    function startActivitySession() {
        try {
            // Get session name with wind info
            var sessionName = getSessionName();
            
            // Create and start the recording session
            mSession = createRecordingSession(sessionName);
            if (mSession == null) { return; }
            
            // Create custom fields
            createFitContributorFields(sessionName);
            
            // Start recording
            mSession.start();
            System.println("Activity recording started as: " + sessionName);
            
            // Initialize wind direction
            initializeWindDirection();
            
        } catch (e) {
            System.println("Error with activity recording: " + e.getErrorMessage());
        }
    }
    
    // Helper to get session name
    function getSessionName() {
        var sessionName = "Windfoil";
        var modelData = mModel != null ? mModel.getData() : null;
        
        if (modelData != null && modelData.hasKey("windStrength")) {
            sessionName = "Windfoil " + modelData["windStrength"];
        }
        
        return sessionName;
    }
    
    // Helper to create recording session
    function createRecordingSession(sessionName) {
        var sessionOptions = {
            :name => sessionName,
            :sport => Activity.SPORT_GENERIC,
            :subSport => Activity.SUB_SPORT_GENERIC
        };
        
        try {
            return ActivityRecording.createSession(sessionOptions);
        } catch (e) {
            System.println("Error creating session: " + e.getErrorMessage());
            return null;
        }
    }
    
    // Helper to initialize wind direction
    function initializeWindDirection() {
        var modelData = mModel != null ? mModel.getData() : null;
        
        if (modelData != null && modelData.hasKey("initialWindAngle")) {
            var windAngle = modelData["initialWindAngle"];
            System.println("Setting initial wind angle: " + windAngle);
            
            // Set in tracker
            if (mWindTracker != null) {
                mWindTracker.setInitialWindDirection(windAngle);
            }
            
            // Update field
            if (mSessionFields.hasKey("windDirection")) {
                mSessionFields["windDirection"].setData(windAngle);
            }
        }
    }

    // Create FIT contributor fields efficiently
    function createFitContributorFields(sessionName) {
        if (mSession == null) {
            System.println("Session is null, can't create FitContributor fields");
            return;
        }
        
        System.println("Creating FIT fields");
        
        // Create session fields
        createSessionFields(sessionName);
        
        // Create lap fields
        createLapFields();
    }
    
    // Helper to create session fields
    function createSessionFields(sessionName) {
        try {
            // Wind strength field
            var windStrength = parseWindStrengthValue(sessionName);
            var windStrengthField = createField("windLow", 1, FitContributor.DATA_TYPE_UINT8, 
                                               { :mesgType => FitContributor.MESG_TYPE_SESSION });
            
            if (windStrengthField != null) {
                windStrengthField.setData(windStrength);
                mSessionFields["windStrength"] = windStrengthField;
            }
            
            // Wind direction field
            var modelData = mModel != null ? mModel.getData() : null;
            if (modelData != null && modelData.hasKey("initialWindAngle")) {
                var windAngle = convertToInteger(modelData["initialWindAngle"]);
                
                var windDirField = createField("windDir", 2, FitContributor.DATA_TYPE_UINT16,
                                             { :mesgType => FitContributor.MESG_TYPE_SESSION });
                
                if (windDirField != null) {
                    windDirField.setData(windAngle);
                    mSessionFields["windDirection"] = windDirField;
                }
            }
        } catch (e) {
            System.println("Error creating session fields: " + e.getErrorMessage());
        }
    }
    
    // Helper to parse wind strength
    function parseWindStrengthValue(sessionName) {
        var windValue = 7; // Default
        
        if (sessionName != null) {
            if (sessionName.find("7-10") >= 0) { windValue = 7; }
            else if (sessionName.find("10-13") >= 0) { windValue = 10; }
            else if (sessionName.find("13-16") >= 0) { windValue = 13; }
            else if (sessionName.find("16-19") >= 0) { windValue = 16; }
            else if (sessionName.find("19-22") >= 0) { windValue = 19; }
            else if (sessionName.find("22-25") >= 0) { windValue = 22; }
            else if (sessionName.find("25+") >= 0) { windValue = 25; }
        }
        
        return windValue;
    }
    
    // Helper to convert to integer
    function convertToInteger(value) {
        if (value instanceof Float) {
            return value.toNumber();
        }
        return value;
    }

    // Create lap fields efficiently
    function createLapFields() {
        if (mLapFields.size() > 0) {
            // Fields already exist
            return;
        }
        
        try {
            // 1. Percent on Foil - Field ID 100
            var pctOnFoilField = createField(
                "pctOnFoil",
                100,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (pctOnFoilField != null) {
                mLapFields["pctOnFoil"] = pctOnFoilField;
            }
            
            // 2. VMG Upwind - Field ID 101
            var vmgUpField = createField(
                "vmgUp",
                101,
                FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (vmgUpField != null) {
                mLapFields["vmgUp"] = vmgUpField;
            }
            
            // 3. VMG Downwind - Field ID 102
            var vmgDownField = createField(
                "vmgDown",
                102,
                FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (vmgDownField != null) {
                mLapFields["vmgDown"] = vmgDownField;
            }
            
            // 4. Tack Seconds - Field ID 103
            var tackSecField = createField(
                "tackSec",
                103,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (tackSecField != null) {
                mLapFields["tackSec"] = tackSecField;
            }
            
            // 5. Tack Meters - Field ID 104
            var tackMtrField = createField(
                "tackMtr",
                104,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (tackMtrField != null) {
                mLapFields["tackMtr"] = tackMtrField;
            }
            
            // 6. Avg Tack Angle - Field ID 105
            var tackAngField = createField(
                "tackAng",
                105,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (tackAngField != null) {
                mLapFields["tackAng"] = tackAngField;
            }
            
            // 7. Wind Direction - Field ID 106
            var windDirField = createField(
                "windDir",
                106,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (windDirField != null) {
                mLapFields["windDir"] = windDirField;
            }
            
            // 8. Wind Strength - Field ID 107
            var windStrField = createField(
                "windStr",
                107,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (windStrField != null) {
                mLapFields["windStr"] = windStrField;
            }
            
            // 9. Avg Gybe Angle - Field ID 108
            var gybeAngField = createField(
                "gybeAng",
                108,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (gybeAngField != null) {
                mLapFields["gybeAng"] = gybeAngField;
            }
            
            // 10. Tack Count - Field ID 109
            var tackCountField = createField(
                "tackCount",
                109,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (tackCountField != null) {
                mLapFields["tackCount"] = tackCountField;
            }
            
            // 11. Gybe Count - Field ID 110
            var gybeCountField = createField(
                "gybeCount",
                110,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (gybeCountField != null) {
                mLapFields["gybeCount"] = gybeCountField;
            }
            
            // 12. Percent Upwind - Field ID 111
            var pctUpwindField = createField(
                "pctUpwind",
                111,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (pctUpwindField != null) {
                mLapFields["pctUpwind"] = pctUpwindField;
            }
            
            // 13. Percent Downwind - Field ID 112
            var pctDownwindField = createField(
                "pctDownwind",
                112,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (pctDownwindField != null) {
                mLapFields["pctDownwind"] = pctDownwindField;
            }
            
            // 14. Average Wind Angle - Field ID 113
            var avgWindAngField = createField(
                "avgWindAng",
                113,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP }
            );
            if (avgWindAngField != null) {
                mLapFields["avgWindAng"] = avgWindAngField;
            }
            
        } catch (e) {
            System.println("Error creating lap fields: " + e.getErrorMessage());
        }
    }
    
    // Helper to create a single field
    function createField(name, id, type, options) {
        try {
            return mSession.createField(name, id, type, options);
        } catch (e) {
            System.println("Error creating field " + id + ": " + e.getErrorMessage());
            return null;
        }
    }

    // Get data for lap markers with robust error handling
    function getLapData() {
        try {
            System.println("Generating lap data");
            
            // Create a data structure for lap fields with default values
            var lapData = {
                "vmgUp" => 0.0,
                "vmgDown" => 0.0,
                "tackSec" => 0.0,
                "tackMtr" => 0.0,
                "avgTackAngle" => 0,
                "avgGybeAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0,
                "windDirection" => 0,
                "windStrength" => 0,
                "pctUpwind" => 0,
                "pctDownwind" => 0,
                "avgWindAngle" => 0,
                "tackCount" => 0,
                "gybeCount" => 0
            };
            
            // Get data from WindTracker 
            var windData = mWindTracker != null ? mWindTracker.getWindData() : null;
            System.println("- Acquired wind data: " + (windData != null && windData.hasKey("valid")));
            
            // Get lap-specific data if available
            var lapSpecificData = null;
            if (mWindTracker != null) {
                lapSpecificData = mWindTracker.getLapData();
                System.println("- Acquired lap-specific data: " + (lapSpecificData != null));
            }
            
            // Use lap-specific data if available, otherwise fall back to general data
            if (lapSpecificData != null) {
                // VMG data
                if (lapSpecificData.hasKey("vmgUp")) { 
                    lapData["vmgUp"] = lapSpecificData["vmgUp"]; 
                }
                if (lapSpecificData.hasKey("vmgDown")) { 
                    lapData["vmgDown"] = lapSpecificData["vmgDown"]; 
                }
                
                // Tack data
                if (lapSpecificData.hasKey("tackSec")) { 
                    lapData["tackSec"] = lapSpecificData["tackSec"]; 
                }
                if (lapSpecificData.hasKey("tackMtr")) { 
                    lapData["tackMtr"] = lapSpecificData["tackMtr"]; 
                }
                
                // Angle data
                if (lapSpecificData.hasKey("avgTackAngle")) { 
                    lapData["avgTackAngle"] = Math.round(lapSpecificData["avgTackAngle"]).toNumber(); 
                }
                if (lapSpecificData.hasKey("avgGybeAngle")) { 
                    lapData["avgGybeAngle"] = Math.round(lapSpecificData["avgGybeAngle"]).toNumber(); 
                }
                
                // Performance metrics
                if (lapSpecificData.hasKey("lapVMG")) { 
                    lapData["lapVMG"] = lapSpecificData["lapVMG"]; 
                }
                if (lapSpecificData.hasKey("pctOnFoil")) { 
                    lapData["pctOnFoil"] = Math.round(lapSpecificData["pctOnFoil"]).toNumber(); 
                }
                
                // Wind data
                if (lapSpecificData.hasKey("windDirection")) { 
                    lapData["windDirection"] = Math.round(lapSpecificData["windDirection"]).toNumber(); 
                }
                
                // Maneuver counts
                if (lapSpecificData.hasKey("tackCount")) { 
                    lapData["tackCount"] = lapSpecificData["tackCount"]; 
                }
                if (lapSpecificData.hasKey("gybeCount")) { 
                    lapData["gybeCount"] = lapSpecificData["gybeCount"]; 
                }
                
                // Point of sail percentages
                if (lapSpecificData.hasKey("pctUpwind")) { 
                    lapData["pctUpwind"] = Math.round(lapSpecificData["pctUpwind"]).toNumber(); 
                }
                if (lapSpecificData.hasKey("pctDownwind")) { 
                    lapData["pctDownwind"] = Math.round(lapSpecificData["pctDownwind"]).toNumber(); 
                }
                if (lapSpecificData.hasKey("avgWindAngle")) { 
                    lapData["avgWindAngle"] = Math.round(lapSpecificData["avgWindAngle"]).toNumber(); 
                }
            }
            
            // Calculate wind strength as index*3 + 7 (lower wind limit)
            var windStrength = 0;
            try {
                var modelData = mModel != null ? mModel.getData() : null;
                if (modelData != null && modelData.hasKey("windStrengthIndex")) {
                    var windIndex = modelData["windStrengthIndex"];
                    // Convert index to actual wind strength in knots
                    windStrength = windIndex * 3 + 7;
                    System.println("- Wind strength calculated from index " + windIndex + " = " + windStrength + " knots");
                }
            } catch (e) {
                System.println("Error getting wind strength: " + e.getErrorMessage());
            }
            
            // Apply the calculated wind strength
            lapData["windStrength"] = windStrength;
            
            // Apply fallbacks for any missing values
            if (lapData["vmgUp"] == 0.0 && lapData["vmgDown"] == 0.0 && windData != null) {
                if (windData.hasKey("currentVMG") && windData.hasKey("currentPointOfSail")) {
                    var vmg = windData["currentVMG"];
                    var isUpwind = (windData["currentPointOfSail"] == "Upwind");
                    
                    if (isUpwind) {
                        lapData["vmgUp"] = vmg;
                    } else {
                        lapData["vmgDown"] = vmg;
                    }
                }
            }
            
            // Percent on foil fallback
            if (lapData["pctOnFoil"] == 0.0) {
                var modelData = mModel != null ? mModel.getData() : null;
                if (modelData != null && modelData.hasKey("percentOnFoil")) {
                    lapData["pctOnFoil"] = Math.round(modelData["percentOnFoil"]).toNumber();
                }
            }
            
            // Wind direction fallback
            if (lapData["windDirection"] == 0 && windData != null && windData.hasKey("windDirection")) {
                lapData["windDirection"] = windData["windDirection"];
            }
            
            // Validate and normalize
            lapData = validateLapData(lapData);
            
            return lapData;
        } catch (e) {
            System.println("CRITICAL ERROR in getLapData: " + e.getErrorMessage());
            
            // Return minimal valid data structure as emergency fallback
            return {
                "vmgUp" => 0.0,
                "vmgDown" => 0.0,
                "tackSec" => 0.0,
                "tackMtr" => 0.0,
                "avgTackAngle" => 0,
                "avgGybeAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0,
                "windDirection" => 0,
                "windStrength" => 0,
                "pctUpwind" => 0,
                "pctDownwind" => 0,
                "avgWindAngle" => 0,
                "tackCount" => 0,
                "gybeCount" => 0
            };
        }
    }

    // Helper to validate lap data
    function validateLapData(lapData) {
        // Apply range limits
        lapData["vmgUp"] = limitRange(lapData["vmgUp"], 0.0, 99.9);
        lapData["vmgDown"] = limitRange(lapData["vmgDown"], 0.0, 99.9);
        lapData["tackSec"] = limitRange(lapData["tackSec"], 0.0, 9999.9);
        lapData["tackMtr"] = limitRange(lapData["tackMtr"], 0.0, 9999.9);
        lapData["avgTackAngle"] = limitRange(lapData["avgTackAngle"], 0, 180);
        lapData["avgGybeAngle"] = limitRange(lapData["avgGybeAngle"], 0, 180);
        lapData["pctOnFoil"] = limitRange(lapData["pctOnFoil"], 0, 100);
        lapData["pctUpwind"] = limitRange(lapData["pctUpwind"], 0, 100);
        lapData["pctDownwind"] = limitRange(lapData["pctDownwind"], 0, 100);
        
        // Normalize angles
        if (lapData["windDirection"] >= 360) {
            lapData["windDirection"] = lapData["windDirection"] % 360;
        }
        
        // Round values for consistency
        lapData["vmgUp"] = Math.round(lapData["vmgUp"] * 10) / 10.0;
        lapData["vmgDown"] = Math.round(lapData["vmgDown"] * 10) / 10.0;
        lapData["tackSec"] = Math.round(lapData["tackSec"] * 10) / 10.0;
        lapData["tackMtr"] = Math.round(lapData["tackMtr"] * 10) / 10.0;
        lapData["lapVMG"] = Math.round(lapData["lapVMG"] * 10) / 10.0;
        
        return lapData;
    }
  
    // Helper to create default lap data
    function createDefaultLapData() {
        return {
            "vmgUp" => 0.0,
            "vmgDown" => 0.0,
            "tackSec" => 0.0,
            "tackMtr" => 0.0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "lapVMG" => 0.0,
            "pctOnFoil" => 0.0,
            "windDirection" => 0,
            "windStrength" => 0,
            "pctUpwind" => 0,
            "pctDownwind" => 0,
            "avgWindAngle" => 0,
            "tackCount" => 0,
            "gybeCount" => 0
        };
    }
    
    // Helper to update from lap-specific data
    function updateFromLapSpecificData(lapData, lapSpecificData) {
        // VMG data
        if (lapSpecificData.hasKey("vmgUp")) { 
            lapData["vmgUp"] = lapSpecificData["vmgUp"]; 
        }
        if (lapSpecificData.hasKey("vmgDown")) { 
            lapData["vmgDown"] = lapSpecificData["vmgDown"]; 
        }
        
        // Tack data
        if (lapSpecificData.hasKey("tackSec")) { 
            lapData["tackSec"] = lapSpecificData["tackSec"]; 
        }
        if (lapSpecificData.hasKey("tackMtr")) { 
            lapData["tackMtr"] = lapSpecificData["tackMtr"]; 
        }
        
        // Angle data
        if (lapSpecificData.hasKey("avgTackAngle")) { 
            lapData["avgTackAngle"] = Math.round(lapSpecificData["avgTackAngle"]).toNumber(); 
        }
        if (lapSpecificData.hasKey("avgGybeAngle")) { 
            lapData["avgGybeAngle"] = Math.round(lapSpecificData["avgGybeAngle"]).toNumber(); 
        }
        
        // Performance metrics
        if (lapSpecificData.hasKey("lapVMG")) { 
            lapData["lapVMG"] = lapSpecificData["lapVMG"]; 
        }
        if (lapSpecificData.hasKey("pctOnFoil")) { 
            lapData["pctOnFoil"] = Math.round(lapSpecificData["pctOnFoil"]).toNumber(); 
        }
        
        // Wind data
        if (lapSpecificData.hasKey("windDirection")) { 
            lapData["windDirection"] = Math.round(lapSpecificData["windDirection"]).toNumber(); 
        }
        if (lapSpecificData.hasKey("windStrength")) { 
            lapData["windStrength"] = lapSpecificData["windStrength"]; 
        }
        
        // Maneuver counts
        if (lapSpecificData.hasKey("tackCount")) { 
            lapData["tackCount"] = lapSpecificData["tackCount"]; 
        }
        if (lapSpecificData.hasKey("gybeCount")) { 
            lapData["gybeCount"] = lapSpecificData["gybeCount"]; 
        }
        
        // Point of sail percentages
        if (lapSpecificData.hasKey("pctUpwind")) { 
            lapData["pctUpwind"] = Math.round(lapSpecificData["pctUpwind"]).toNumber(); 
        }
        if (lapSpecificData.hasKey("pctDownwind")) { 
            lapData["pctDownwind"] = Math.round(lapSpecificData["pctDownwind"]).toNumber(); 
        }
        if (lapSpecificData.hasKey("avgWindAngle")) { 
            lapData["avgWindAngle"] = Math.round(lapSpecificData["avgWindAngle"]).toNumber(); 
        }
    }
    
    // Helper to check if fallbacks are needed
    function needsFallbackData(lapData) {
        return lapData["vmgUp"] == 0.0 && lapData["vmgDown"] == 0.0 ||
               lapData["pctOnFoil"] == 0.0 ||
               lapData["windDirection"] == 0;
    }
    
    // Helper to apply fallback data
    function applyFallbackData(lapData, windData) {
        // VMG fallbacks
        if (lapData["vmgUp"] == 0.0 && lapData["vmgDown"] == 0.0 && windData != null) {
            if (windData.hasKey("currentVMG") && windData.hasKey("currentPointOfSail")) {
                var vmg = windData["currentVMG"];
                var isUpwind = (windData["currentPointOfSail"] == "Upwind");
                
                if (isUpwind) {
                    lapData["vmgUp"] = vmg;
                } else {
                    lapData["vmgDown"] = vmg;
                }
            }
        }
        
        // Percent on foil fallback
        if (lapData["pctOnFoil"] == 0.0) {
            var modelData = mModel != null ? mModel.getData() : null;
            if (modelData != null && modelData.hasKey("percentOnFoil")) {
                lapData["pctOnFoil"] = Math.round(modelData["percentOnFoil"]).toNumber();
            }
        }
        
        // Wind direction fallback
        if (lapData["windDirection"] == 0 && windData != null && windData.hasKey("windDirection")) {
            lapData["windDirection"] = windData["windDirection"];
        }
        
        // Wind strength fallback
        if (lapData["windStrength"] == 0 && mModel != null) {
            var modelData = mModel.getData();
            if (modelData != null && modelData.hasKey("windStrengthIndex")) {
                lapData["windStrength"] = modelData["windStrengthIndex"];
            }
        }
    }
    
    
    // Helper to limit numeric range
    function limitRange(value, min, max) {
        if (value < min) { 
            return min; 
        }
        if (value > max) { 
            return max; 
        }
        return value;
    }

    // Timer callback with error handling
    function onTimerTick() {
        try {
            processData();
        } catch (e) {
            System.println("Error in timer processing: " + e.getErrorMessage());
        }
    }

    // Process data efficiently
    function processData() {
        var modelData = mModel != null ? mModel.getData() : null;
        if (modelData == null) { return; }
        
        var isActive = modelData["isRecording"] && 
                     !(modelData.hasKey("sessionPaused") && modelData["sessionPaused"]);
        
        if (isActive) {
            // Get field values all at once
            var lapFieldValues = getLapFieldValues();
            
            // Update all field values efficiently
            updateLapFields(lapFieldValues);
            
            // Update model data
            mModel.updateData();
        } else if (modelData.hasKey("sessionPaused") && modelData["sessionPaused"]) {
            // Just update time when paused
            mModel.updateTimeDisplay();
        }
        
        // Request UI update
        WatchUi.requestUpdate();
    }
    
    // Get all lap field values efficiently
    function getLapFieldValues() {
        var values = {
            "pctOnFoil" => 0,
            "vmgUp" => 0.0,
            "vmgDown" => 0.0,
            "tackSec" => 0.0,
            "tackMtr" => 0.0,
            "avgTackAngle" => 0,
            "avgGybeAngle" => 0,
            "windDirection" => 0,
            "windStrength" => 0,
            "tackCount" => 0,
            "gybeCount" => 0,
            "pctUpwind" => 0,
            "pctDownwind" => 0,
            "avgWindAngle" => 0
        };
        
        // Get model data
        var modelData = mModel != null ? mModel.getData() : null;
        if (modelData != null) {
            if (modelData.hasKey("percentOnFoil")) {
                values["pctOnFoil"] = modelData["percentOnFoil"].toNumber();
            }
            
            if (modelData.hasKey("windStrengthIndex")) {
                values["windStrength"] = modelData["windStrengthIndex"];
            }
        }
        
        // Get wind tracker data
        if (mWindTracker != null) {
            var windData = mWindTracker.getWindData();
            if (windData != null && windData.hasKey("valid") && windData["valid"]) {
                updateValuesFromWindData(values, windData);
            }
            
            // Get lap specific data
            var lapData = mWindTracker.getLapData();
            if (lapData != null) {
                updateValuesFromLapData(values, lapData);
            }
        }
        
        return values;
    }
    
    // Helper to update values from wind data
    function updateValuesFromWindData(values, windData) {
        // Wind Direction
        if (windData.hasKey("windDirection")) {
            values["windDirection"] = windData["windDirection"];
        }
        
        // VMG data
        if (windData.hasKey("currentVMG")) {
            var currentVMG = windData["currentVMG"];
            var isUpwind = (windData.hasKey("currentPointOfSail") && 
                         windData["currentPointOfSail"] == "Upwind");
                         
            if (isUpwind) {
                values["vmgUp"] = currentVMG;
            } else {
                values["vmgDown"] = currentVMG;
            }
        }
        
        // Tack angle
        if (windData.hasKey("lastTackAngle")) {
            values["avgTackAngle"] = windData["lastTackAngle"].toNumber();
        }
        
        // Gybe angle
        if (windData.hasKey("lastGybeAngle")) {
            values["avgGybeAngle"] = windData["lastGybeAngle"].toNumber();
        }
        
        // Tack count
        if (windData.hasKey("tackCount")) {
            values["tackCount"] = windData["tackCount"];
        }
        
        // Gybe count
        if (windData.hasKey("gybeCount")) {
            values["gybeCount"] = windData["gybeCount"];
        }
    }
    
    // Helper to update values from lap data
    function updateValuesFromLapData(values, lapData) {
        // Use the individual field updates directly from the data
        if (lapData.hasKey("tackSec")) { values["tackSec"] = lapData["tackSec"]; }
        if (lapData.hasKey("tackMtr")) { values["tackMtr"] = lapData["tackMtr"]; }
        if (lapData.hasKey("avgTackAngle")) { values["avgTackAngle"] = lapData["avgTackAngle"]; }
        if (lapData.hasKey("avgGybeAngle")) { values["avgGybeAngle"] = lapData["avgGybeAngle"]; }
        if (lapData.hasKey("vmgUp")) { values["vmgUp"] = lapData["vmgUp"]; }
        if (lapData.hasKey("vmgDown")) { values["vmgDown"] = lapData["vmgDown"]; }
        if (lapData.hasKey("windDirection")) { values["windDirection"] = lapData["windDirection"]; }
        if (lapData.hasKey("tackCount")) { values["tackCount"] = lapData["tackCount"]; }
        if (lapData.hasKey("gybeCount")) { values["gybeCount"] = lapData["gybeCount"]; }
        if (lapData.hasKey("pctUpwind")) { values["pctUpwind"] = lapData["pctUpwind"]; }
        if (lapData.hasKey("pctDownwind")) { values["pctDownwind"] = lapData["pctDownwind"]; }
        if (lapData.hasKey("avgWindAngle")) { values["avgWindAngle"] = lapData["avgWindAngle"]; }
    }

    // Update lap fields efficiently
    function updateLapFields(values) {
        if (mSession == null || !mSession.isRecording()) { return; }
        
        try {
            // Update each field using the values dictionary
            var keys = mLapFields.keys();
            for (var i = 0; i < keys.size(); i++) {
                var fieldName = keys[i];
                var field = mLapFields[fieldName];
                if (field != null && values.hasKey(fieldName)) {
                    field.setData(values[fieldName]);
                }
            }
        } catch (e) {
            System.println("Error updating lap fields: " + e.getErrorMessage());
        }
    }

    // Add lap marker efficiently
    function addLapMarker() {
        if (mSession == null || !mSession.isRecording()) {
            System.println("Cannot add lap marker - session not recording");
            return;
        }
        
        try {
            System.println("Adding lap marker");
            
            // Get lap data
            var lapData = getLapData();
            
            // Update field values from lap data
            updateLapFieldsFromLapData(lapData);
            
            // Add the lap marker
            mSession.addLap();
            
            // Notify the wind tracker
            if (mWindTracker != null) {
                mWindTracker.onLapMarked(null);
            }
            
            System.println("Lap marker added");
        } catch (e) {
            System.println("ERROR in addLapMarker: " + e.getErrorMessage());
        }
    }
    
    // Helper to update lap fields from lap data
    function updateLapFieldsFromLapData(lapData) {
        try {
            // Map lap data to field names
            var fieldMap = {
                "pctOnFoil" => "pctOnFoil",
                "vmgUp" => "vmgUp",
                "vmgDown" => "vmgDown",
                "tackSec" => "tackSec",
                "tackMtr" => "tackMtr",
                "avgTackAngle" => "tackAng",
                "avgGybeAngle" => "gybeAng",
                "windDirection" => "windDir",
                "windStrength" => "windStr",
                "tackCount" => "tackCount",
                "gybeCount" => "gybeCount",
                "pctUpwind" => "pctUpwind",
                "pctDownwind" => "pctDownwind",
                "avgWindAngle" => "avgWindAng"
            };
            
            // Update each field manually instead of using foreach
            var dataKeys = fieldMap.keys();
            for (var i = 0; i < dataKeys.size(); i++) {
                var dataKey = dataKeys[i];
                var fieldName = fieldMap[dataKey];
                
                if (lapData.hasKey(dataKey) && mLapFields.hasKey(fieldName)) {
                    var value = lapData[dataKey];
                    mLapFields[fieldName].setData(value);
                }
            }
        } catch (e) {
            System.println("Error updating fields from lap data: " + e.getErrorMessage());
        }
    }
    
    // Create and start a simple timer without custom callback class
    function startSimpleTimer() {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
        }
        
        // Use a properly typed callback
        mTimer.start(method(:onTimerCallback), 1000, true);
    }

    // Timer callback with correct signature
    function onTimerCallback() as Void {
        try {
            processData();
        } catch (e) {
            System.println("Error in timer processing: " + e.getErrorMessage());
        }
    }
    
    // Update total counts efficiently
    function updateTotalCounts() {
        var modelData = mModel != null ? mModel.getData() : null;
        var windData = mWindTracker != null ? mWindTracker.getWindData() : null;
        
        // Skip if no valid data
        if (modelData == null || windData == null || 
            !windData.hasKey("valid") || !windData["valid"]) {
            return;
        }
        
        // Update tack count
        updateManeuverCount(modelData, windData, "tackCount", "lastTackCount", "totalTackCount");
        
        // Update gybe count
        updateManeuverCount(modelData, windData, "gybeCount", "lastGybeCount", "totalGybeCount");
    }
    
    // Helper to update maneuver counts
    function updateManeuverCount(modelData, windData, countKey, lastCountKey, totalCountKey) {
        if (!windData.hasKey(countKey) || windData[countKey] <= 0) {
            return;
        }
        
        var currentCount = windData[countKey];
        var totalCount = modelData.hasKey(totalCountKey) ? modelData[totalCountKey] : 0;
        
        // Check if count changed
        if (!modelData.hasKey(lastCountKey) || modelData[lastCountKey] != currentCount) {
            var diff = 0;
            
            if (modelData.hasKey(lastCountKey)) {
                diff = currentCount - modelData[lastCountKey];
                if (diff < 0) {
                    diff = currentCount; // Reset happened
                }
            } else {
                diff = currentCount;
            }
            
            // Update total
            totalCount += diff;
            modelData[totalCountKey] = totalCount;
            
            // Store current count
            modelData[lastCountKey] = currentCount;
        }
    }
    
    // Get initial view
    function getInitialView() {
        // Initialize model if needed
        if (mModel == null) {
            mModel = new FoilTrackerModel();
        }
        
        // Create wind strength picker view
        var windView = new WindStrengthPickerView(mModel);
        var windDelegate = new StartupWindStrengthDelegate(mModel, self);
        windDelegate.setPickerView(windView);
        
        return [windView, windDelegate];
    }
    
    // App stopping - save data
    function onStop(state) {
        System.println("App stopping");
        
        try {
            // Save emergency timestamp
            Application.Storage.setValue("appStopTime", Time.now().value());
            
            // Save activity data
            if (mModel != null) {
                var saveResult = mModel.saveActivityData();
                if (!saveResult) {
                    // Backup save if main save failed
                    saveEmergencyBackup();
                }
            }
        } catch (e) {
            System.println("Error in onStop: " + e.getErrorMessage());
            
            // Try emergency backup
            saveEmergencyBackup();
        }
    }

        // Get the wind tracker instance - add this to FoilTrackerApp.mc
    function getWindTracker() {
        return mWindTracker;
}

    // Emergency backup function
    function saveEmergencyBackup() {
        try {
            var finalBackup = {
                "date" => Time.now().value(),
                "onStopEmergency" => true
            };
            Application.Storage.setValue("onStop_emergency", finalBackup);
            System.println("Emergency save succeeded");
        } catch (e) {
            System.println("All save attempts failed");
        }
    }
}