using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Position;
using Toybox.Timer;
using Toybox.Lang;
using Toybox.FitContributor;

// Main Application class
class FoilTrackerApp extends Application.AppBase {
    // Initialize class variables
    private var mView;
    private var mModel;
    private var mSession;
    private var mPositionEnabled;
    private var mTimer;
    private var mTimerRunning;
    private var mWindTracker;  // Wind tracker
    
    // FitContributor fields for Session
    private var mWorkoutNameField;
    private var mWindStrengthField;
    private var mWindDirectionField;
    
    // FitContributor fields for Lap
    private var mLapPctOnFoilField;
    private var mLapVMGUpField;
    private var mLapVMGDownField;
    private var mLapTackSecField;
    private var mLapTackMtrField;
    private var mLapWindDirectionField;
    private var mLapWindStrengthField;
    private var mLapAvgTackAngleField;

    // Initialize the application
    function initialize() {
        AppBase.initialize();
        mModel = null;
        mSession = null;
        mPositionEnabled = false;
        mTimer = null;
        mTimerRunning = false;
        mWindTracker = new WindTracker();  // Initialize wind tracker
        
        // Initialize FitContributor fields
        mWorkoutNameField = null;
        mWindStrengthField = null;
        mWindDirectionField = null;
        
        // Initialize Lap fields
        mLapPctOnFoilField = null;
        mLapVMGUpField = null;
        mLapVMGDownField = null;
        mLapTackSecField = null;
        mLapTackMtrField = null;
        mLapWindDirectionField = null;
        mLapWindStrengthField = null;
        mLapAvgTackAngleField = null;
    }

    // onStart() is called when the application is starting
    function onStart(state) {
        System.println("App starting");
        // Initialize the app model if not already done
        if (mModel == null) {
            mModel = new FoilTrackerModel();
        }
        System.println("Model initialized");
        
        // Enable position tracking
        try {
            // Define a callback that matches the expected signature
            mPositionEnabled = true;
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, new Method(self, :onPositionCallback));
            System.println("Position tracking enabled");
        } catch (e) {
            mPositionEnabled = false;
            System.println("Error enabling position tracking: " + e.getErrorMessage());
        }
        
        // Note: We'll start the activity session after wind strength is selected
        // in the StartupWindStrengthDelegate's onSelect method
        
        // Start the update timer
        startSimpleTimer();
        System.println("Timer started");
    }
    
    // Position callback with correct type signature
    function onPositionCallback(posInfo as Position.Info) as Void {
        // Only process if we have valid location info
        if (posInfo != null) {
            // Pass position data to wind tracker
            if (mWindTracker != null) {
                mWindTracker.processPositionData(posInfo);
            }
            
            // Process location data in model
            if (mModel != null) {
                var data = mModel.getData();
                if (data["isRecording"] && !(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                    mModel.processLocationData(posInfo);
                }
            }
            
            // Request UI update to reflect changes
            WatchUi.requestUpdate();
        }
    }
    
    // Modified function to start activity recording session with wind strength in name
    function startActivitySession() {
        try {
            // Get wind strength if available
            var sessionName = "Windfoil";
            var windStrength = null;
            if (mModel != null && mModel.getData().hasKey("windStrength")) {
                windStrength = mModel.getData()["windStrength"];
                sessionName = "Windfoil " + windStrength; // Add wind strength to name
                System.println("Creating session with name: " + sessionName);
            }
            
            // Create activity recording session
            var sessionOptions = {
                :name => sessionName,
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC
            };
            
            // Create session with the name including wind strength
            mSession = ActivityRecording.createSession(sessionOptions);
            
            // Create custom FitContributor fields for important metadata
            createFitContributorFields(sessionName, windStrength);
            
            // Start the session
            mSession.start();
            System.println("Activity recording started as: " + sessionName);
            
            // Set initial wind direction if available
            if (mModel != null && mModel.getData().hasKey("initialWindAngle")) {
                var windAngle = mModel.getData()["initialWindAngle"];
                System.println("Setting initial wind angle: " + windAngle);
                
                // Initialize the WindTracker with the manual direction
                if (mWindTracker != null) {
                    mWindTracker.setInitialWindDirection(windAngle);
                    System.println("WindTracker initialized with direction: " + windAngle);
                    
                    // Update the FitContributor field with wind direction
                    if (mWindDirectionField != null) {
                        mWindDirectionField.setData(windAngle);
                    }
                }
            }
        } catch (e) {
            System.println("Error with activity recording: " + e.getErrorMessage());
        }
    }
    
    // Create FitContributor fields for the session - now includes LAP field types
    // Create FitContributor fields for the session - simplified for compatibility
    // Modified to use proper lap field creation syntax
    function createFitContributorFields(sessionName, windStrength) {
        try {
            // Check if the session is valid
            if (mSession == null) {
                System.println("Session is null, can't create FitContributor fields");
                return;
            }
            
            System.println("=== CREATING FIT FIELDS ===");
            
            // --- SESSION FIELDS ---
            
            // Create windStrength field
            mWindStrengthField = mSession.createField(
                "windLow",
                1,
                FitContributor.DATA_TYPE_UINT8, 
                { :mesgType => FitContributor.MESG_TYPE_SESSION }
            );
            
            if (mWindStrengthField != null) {
                var windValue = 7;
                if (windStrength != null) {
                    if (windStrength.find("7-10") >= 0) { windValue = 7; }
                    else if (windStrength.find("10-13") >= 0) { windValue = 10; }
                    else if (windStrength.find("13-16") >= 0) { windValue = 13; }
                    else if (windStrength.find("16-19") >= 0) { windValue = 16; }
                    else if (windStrength.find("19-22") >= 0) { windValue = 19; }
                    else if (windStrength.find("22-25") >= 0) { windValue = 22; }
                    else if (windStrength.find("25+") >= 0) { windValue = 25; }
                }
                mWindStrengthField.setData(windValue);
                System.println("Created session field: windLow = " + windValue);
            }
            
            // Create wind direction field if we have the data
            if (mModel != null && mModel.getData().hasKey("initialWindAngle")) {
                var windAngle = mModel.getData()["initialWindAngle"];
                if (windAngle instanceof Float) {
                    windAngle = windAngle.toNumber();
                }
                
                mWindDirectionField = mSession.createField(
                    "windDir",             
                    2,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_SESSION }
                );
                
                if (mWindDirectionField != null) {
                    mWindDirectionField.setData(windAngle);
                    System.println("Created session field: windDir = " + windAngle);
                }
            }
            
            // --- LAP FIELDS ---
            System.println("Creating LAP fields...");
            
            // 1. Percent on Foil - Field ID 100
            mLapPctOnFoilField = mSession.createField(
                "pctOnFoil",
                100,
                FitContributor.DATA_TYPE_UINT8,
                { 
                    :mesgType => FitContributor.MESG_TYPE_LAP,
                    :units => "%"
                }
            );
            
            if (mLapPctOnFoilField != null) {
                System.println("✓ Created lap field: pctOnFoil (ID: 100)");
                
                // 2. VMG Upwind - Field ID 101
                mLapVMGUpField = mSession.createField(
                    "vmgUp",
                    101,
                    FitContributor.DATA_TYPE_UINT16,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "kts"
                    }
                );
                
                if (mLapVMGUpField != null) {
                    System.println("✓ Created lap field: vmgUp (ID: 101)");
                }
                
                // 3. VMG Downwind - Field ID 102
                mLapVMGDownField = mSession.createField(
                    "vmgDown",
                    102,
                    FitContributor.DATA_TYPE_UINT16,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "kts"
                    }
                );
                
                if (mLapVMGDownField != null) {
                    System.println("✓ Created lap field: vmgDown (ID: 102)");
                }
                
                // 4. Tack Seconds - Field ID 103
                mLapTackSecField = mSession.createField(
                    "tackSec",
                    103,
                    FitContributor.DATA_TYPE_UINT16,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "s"
                    }
                );
                
                if (mLapTackSecField != null) {
                    System.println("✓ Created lap field: tackSec (ID: 103)");
                }
                
                // 5. Tack Meters - Field ID 104
                mLapTackMtrField = mSession.createField(
                    "tackMtr",
                    104,
                    FitContributor.DATA_TYPE_UINT16,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "m"
                    }
                );
                
                if (mLapTackMtrField != null) {
                    System.println("✓ Created lap field: tackMtr (ID: 104)");
                }
                
                // 6. Avg Tack Angle - Field ID 105
                mLapAvgTackAngleField = mSession.createField(
                    "tackAng",
                    105,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "deg"
                    }
                );
                
                if (mLapAvgTackAngleField != null) {
                    System.println("✓ Created lap field: tackAng (ID: 105)");
                }
            } else {
                System.println("✗ Failed to create pctOnFoil field - subsequent fields not created");
            }
            
            System.println("Field creation complete");
            
        } catch (e) {
            System.println("ERROR in createFitContributorFields: " + e.getErrorMessage());
        }
    }
    
    // Get data for lap markers with robust error handling
    function getLapData() {
        try {
            System.println("==== GENERATING LAP DATA ====");
            
            // Create a data structure for lap fields with default values
            var lapData = {
                "vmgUp" => 0.0,
                "vmgDown" => 0.0,
                "tackSec" => 0.0,
                "tackMtr" => 0.0,
                "avgTackAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0
            };
            
            // Get data from WindTracker 
            var windData = mWindTracker.getWindData();
            System.println("- Acquired wind data: " + (windData != null && windData.hasKey("valid")));
            
            // Get lap-specific data if available
            var lapSpecificData = null;
            if (mWindTracker != null) {
                lapSpecificData = mWindTracker.getLapData();
                System.println("- Acquired lap-specific data: " + (lapSpecificData != null));
            }
            
            // Use lap-specific data if available, otherwise fall back to general data
            if (lapSpecificData != null) {
                try {
                    // Copy each field with validation and convert to appropriate format
                    
                    // VMG Upwind - handle scaled value (×10 for 1 decimal place)
                    if (lapSpecificData.hasKey("vmgUp")) {
                        var vmgUp = lapSpecificData["vmgUp"];
                        // Ensure it's a number and not null
                        if (vmgUp != null) {
                            // Round to 1 decimal place
                            vmgUp = Math.round(vmgUp * 10) / 10.0;
                            lapData["vmgUp"] = vmgUp;
                            System.println("- Using lap VMG Up: " + vmgUp);
                        }
                    }
                    
                    // VMG Downwind - handle scaled value (×10 for 1 decimal place)
                    if (lapSpecificData.hasKey("vmgDown")) {
                        var vmgDown = lapSpecificData["vmgDown"];
                        // Ensure it's a number and not null
                        if (vmgDown != null) {
                            // Round to 1 decimal place
                            vmgDown = Math.round(vmgDown * 10) / 10.0;
                            lapData["vmgDown"] = vmgDown;
                            System.println("- Using lap VMG Down: " + vmgDown);
                        }
                    }
                    
                    // Tack Seconds - handle scaled value (×10 for 1 decimal place)
                    if (lapSpecificData.hasKey("tackSec")) {
                        var tackSec = lapSpecificData["tackSec"];
                        // Ensure it's a number and not null
                        if (tackSec != null) {
                            // Round to 1 decimal place
                            tackSec = Math.round(tackSec * 10) / 10.0;
                            lapData["tackSec"] = tackSec;
                            System.println("- Using lap Tack Seconds: " + tackSec);
                        }
                    }
                    
                    // Tack Meters - handle scaled value (×10 for 1 decimal place)
                    if (lapSpecificData.hasKey("tackMtr")) {
                        var tackMtr = lapSpecificData["tackMtr"];
                        // Ensure it's a number and not null
                        if (tackMtr != null) {
                            // Round to 1 decimal place 
                            tackMtr = Math.round(tackMtr * 10) / 10.0;
                            lapData["tackMtr"] = tackMtr;
                            System.println("- Using lap Tack Meters: " + tackMtr);
                        }
                    }
                    
                    // Average Tack Angle - integer
                    if (lapSpecificData.hasKey("avgTackAngle")) {
                        var avgTackAngle = lapSpecificData["avgTackAngle"];
                        // Ensure it's a number and not null
                        if (avgTackAngle != null) {
                            // Round to whole number
                            avgTackAngle = Math.round(avgTackAngle).toNumber();
                            lapData["avgTackAngle"] = avgTackAngle;
                            System.println("- Using lap Avg Tack Angle: " + avgTackAngle);
                        }
                    }
                    
                    // Lap VMG - general VMG metric
                    if (lapSpecificData.hasKey("lapVMG")) {
                        var lapVMG = lapSpecificData["lapVMG"];
                        // Ensure it's a number and not null
                        if (lapVMG != null) {
                            // Round to 1 decimal place
                            lapVMG = Math.round(lapVMG * 10) / 10.0;
                            lapData["lapVMG"] = lapVMG;
                            System.println("- Using lap VMG: " + lapVMG);
                        }
                    }
                    
                    // Percent On Foil - integer
                    if (lapSpecificData.hasKey("pctOnFoil")) {
                        var pctOnFoil = lapSpecificData["pctOnFoil"];
                        // Ensure it's a number and not null
                        if (pctOnFoil != null) {
                            // Round to whole number
                            pctOnFoil = Math.round(pctOnFoil).toNumber();
                            lapData["pctOnFoil"] = pctOnFoil;
                            System.println("- Using lap % On Foil: " + pctOnFoil);
                        }
                    }
                } catch (e) {
                    System.println("✗ Error processing lap-specific data: " + e.getErrorMessage());
                    
                    // Continue with fallbacks in case of error
                }
            }
            
            // Fallback for any missing values - use model data or current VMG
            try {
                // VMG fallbacks based on current point of sail
                if (lapData["vmgUp"] == 0.0 && lapData["vmgDown"] == 0.0 && windData != null) {
                    if (windData.hasKey("currentVMG") && windData.hasKey("currentPointOfSail")) {
                        var vmg = windData["currentVMG"];
                        var isUpwind = (windData["currentPointOfSail"] == "Upwind");
                        
                        if (isUpwind) {
                            lapData["vmgUp"] = Math.round(vmg * 10) / 10.0;
                            System.println("- Fallback VMG Up: " + lapData["vmgUp"]);
                        } else {
                            lapData["vmgDown"] = Math.round(vmg * 10) / 10.0;
                            System.println("- Fallback VMG Down: " + lapData["vmgDown"]);
                        }
                    }
                }
                
                // Percent on foil fallback from model
                if (lapData["pctOnFoil"] == 0.0) {
                    var data = mModel.getData();
                    if (data.hasKey("percentOnFoil")) {
                        var pctOnFoil = data["percentOnFoil"];
                        // Round to whole number
                        pctOnFoil = Math.round(pctOnFoil).toNumber();
                        lapData["pctOnFoil"] = pctOnFoil;
                        System.println("- Fallback % On Foil: " + pctOnFoil);
                    }
                }
                
                // Tack angle fallback from overall stats
                if (lapData["avgTackAngle"] == 0 && windData != null && windData.hasKey("maneuverStats")) {
                    var stats = windData["maneuverStats"];
                    if (stats != null && stats.hasKey("avgTackAngle")) {
                        var angle = stats["avgTackAngle"];
                        if (angle != null) {
                            angle = Math.round(angle).toNumber();
                            lapData["avgTackAngle"] = angle;
                            System.println("- Fallback Avg Tack Angle: " + angle);
                        }
                    }
                }
            } catch (e) {
                System.println("✗ Error in fallback processing: " + e.getErrorMessage());
            }
            
            // Make sure all values are valid numbers before returning
            try {
                // Limit max values to reasonable ranges
                if (lapData["vmgUp"] > 99.9) { lapData["vmgUp"] = 99.9; }
                if (lapData["vmgDown"] > 99.9) { lapData["vmgDown"] = 99.9; }
                if (lapData["tackSec"] > 9999.9) { lapData["tackSec"] = 9999.9; }
                if (lapData["tackMtr"] > 9999.9) { lapData["tackMtr"] = 9999.9; }
                if (lapData["avgTackAngle"] > 180) { lapData["avgTackAngle"] = 180; }
                if (lapData["pctOnFoil"] > 100) { lapData["pctOnFoil"] = 100; }
                
                // Ensure all values are non-negative
                if (lapData["vmgUp"] < 0) { lapData["vmgUp"] = 0; }
                if (lapData["vmgDown"] < 0) { lapData["vmgDown"] = 0; }
                if (lapData["tackSec"] < 0) { lapData["tackSec"] = 0; }
                if (lapData["tackMtr"] < 0) { lapData["tackMtr"] = 0; }
                if (lapData["avgTackAngle"] < 0) { lapData["avgTackAngle"] = 0; }
                if (lapData["pctOnFoil"] < 0) { lapData["pctOnFoil"] = 0; }
                
                System.println("Validated all values in lap data");
            } catch (e) {
                System.println("✗ Error validating lap data: " + e.getErrorMessage());
            }
            
            // Log final values
            System.println("Final lap data:");
            System.println("- VMG Up: " + lapData["vmgUp"]);
            System.println("- VMG Down: " + lapData["vmgDown"]);
            System.println("- Tack Seconds: " + lapData["tackSec"]);
            System.println("- Tack Meters: " + lapData["tackMtr"]);
            System.println("- Avg Tack Angle: " + lapData["avgTackAngle"]);
            System.println("- % On Foil: " + lapData["pctOnFoil"]);
            System.println("- Lap VMG: " + lapData["lapVMG"]);
            
            return lapData;
        } catch (e) {
            System.println("✗ CRITICAL ERROR in getLapData: " + e.getErrorMessage());
            
            // Return minimal valid data structure as emergency fallback
            return {
                "vmgUp" => 0.0,
                "vmgDown" => 0.0,
                "tackSec" => 0.0,
                "tackMtr" => 0.0,
                "avgTackAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0
            };
        }
    }
    
    // In FoilTrackerApp.mc - add onTimerLap implementation
    function onTimerLap() {
        System.println("onTimerLap called - lap has already been recorded");
        
        // Reset any lap-specific counters here
        // But don't try to set field values as it's too late for the lap that just ended
        
        // We can notify the WindTracker that a lap has occurred
        if (mWindTracker != null) {
            mWindTracker.onLapMarked(null);
        }
    }

    // Add new helper method to update lap fields
    function updateLapFields(pctOnFoil, vmgUp, vmgDown, tackSec, tackMtr, tackAng) {
        if (mSession != null && mSession.isRecording()) {
            try {
                // Set each field value if the field exists
                if (mLapPctOnFoilField != null) {
                    mLapPctOnFoilField.setData(pctOnFoil);
                }
                
                if (mLapVMGUpField != null) {
                    mLapVMGUpField.setData(vmgUp);
                }
                
                if (mLapVMGDownField != null) {
                    mLapVMGDownField.setData(vmgDown);
                }
                
                if (mLapTackSecField != null) {
                    mLapTackSecField.setData(tackSec);
                }
                
                if (mLapTackMtrField != null) {
                    mLapTackMtrField.setData(tackMtr);
                }
                
                if (mLapAvgTackAngleField != null) {
                    mLapAvgTackAngleField.setData(tackAng);
                }
                
                // No need to call addLap() here - this just keeps the field values up to date
                // The system will grab these values when a lap is actually triggered
            } catch (e) {
                System.println("Error updating lap fields: " + e.getErrorMessage());
            }
        }
    }

    // In FoilTrackerApp.mc
    function addLapMarker() {
        if (mSession != null && mSession.isRecording()) {
            try {
                System.println("=== VERIFYING FIELD OBJECTS BEFORE LAP MARKER ===");
                // Verify that field objects exist
                if (mLapPctOnFoilField == null) {
                    System.println("ERROR: mLapPctOnFoilField is null - recreating it");
                    mLapPctOnFoilField = mSession.createField(
                        "pctOnFoil", 
                        100, 
                        FitContributor.DATA_TYPE_UINT8, 
                        { :mesgType => FitContributor.MESG_TYPE_LAP }
                    );
                } else {
                    System.println("mLapPctOnFoilField exists");
                }
                
                // Do similar checks for other field objects
                
                // Create a FIT Lap directly
                System.println("=== SETTING FIELD VALUES ===");
                // Set field values explicitly - use try/catch for each
                try {
                    // Set Percent on Foil value (Field 100)
                    System.println("Setting field 100 (pct on foil) = 75");
                    var result = mLapPctOnFoilField.setData(75);
                    System.println("Result of setting field 100: " + result);
                } catch (e) {
                    System.println("ERROR setting field 100: " + e.getErrorMessage());
                }
                
                // Set VMG Up value (Field 101)
                try {
                    if (mLapVMGUpField != null) {
                        System.println("Setting field 101 (vmg up) = 65");
                        var result = mLapVMGUpField.setData(65);
                        System.println("Result of setting field 101: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 101: " + e.getErrorMessage());
                }
                
                // Set VMG Down value (Field 102)
                try {
                    if (mLapVMGDownField != null) {
                        System.println("Setting field 102 (vmg down) = 82");
                        var result = mLapVMGDownField.setData(82);
                        System.println("Result of setting field 102: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 102: " + e.getErrorMessage());
                }
                
                // Continue with other fields...
                
                // Add a small delay to ensure field values are processed
                System.println("=== ADDING LAP MARKER ===");
                mSession.addLap();
                System.println("Lap marker added");
                
            } catch (e) {
                System.println("ERROR in addLapMarker: " + e.getErrorMessage());
            }
        } else {
            System.println("Cannot add lap marker - session not recording");
        }
    }

    // Helper function to ensure lap fields exist
    function createLapFields() {
        // Only create fields if they don't already exist
        if (mLapPctOnFoilField == null) {
            System.println("Creating lap fields...");
            
            try {
                // 1. Percent on Foil - Field ID 100
                mLapPctOnFoilField = mSession.createField(
                    "pctOnFoil",
                    100,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 100: pctOnFoil");
                
                // 2. VMG Upwind - Field ID 101
                mLapVMGUpField = mSession.createField(
                    "vmgUp",
                    101,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 101: vmgUp");
                
                // 3. VMG Downwind - Field ID 102
                mLapVMGDownField = mSession.createField(
                    "vmgDown",
                    102,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 102: vmgDown");
                
                // 4. Tack Seconds - Field ID 103
                mLapTackSecField = mSession.createField(
                    "tackSec",
                    103,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 103: tackSec");
                
                // 5. Tack Meters - Field ID 104
                mLapTackMtrField = mSession.createField(
                    "tackMtr",
                    104,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 104: tackMtr");
                
                // 6. Avg Tack Angle - Field ID 105
                mLapAvgTackAngleField = mSession.createField(
                    "tackAng",
                    105,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 105: tackAng");
                
            } catch (e) {
                System.println("Error creating lap fields: " + e.getErrorMessage());
            }
        }
    }
    
    // Basic function to record wind data in the activity
    function updateSessionWithWindData(windStrength) {
        if (mSession != null && mSession.isRecording()) {
            try {
                // Store wind data in model for saving in app storage
                if (mModel != null) {
                    mModel.getData()["windStrength"] = windStrength;
                    System.println("Wind strength stored in model: " + windStrength);
                }
                
                // Update FitContributor field if available
                if (mWindStrengthField != null) {
                    mWindStrengthField.setData(windStrength);
                    System.println("Updated wind strength field: " + windStrength);
                }
                
                // Add a lap marker to indicate where wind strength was recorded
                // This is the most basic API call that should work on all devices
                mSession.addLap();
                System.println("Added lap marker for wind strength: " + windStrength);
                
            } catch (e) {
                System.println("Error adding wind data: " + e.getErrorMessage());
            }
        }
    }
    
    // Get the wind tracker instance
    function getWindTracker() {
        return mWindTracker;
    }
    
    // Create and start a simple timer without custom callback class
    function startSimpleTimer() {
        if (mTimer == null) {
            mTimer = new Timer.Timer();
        }
        
        // Use a simple direct callback instead of a custom class
        mTimer.start(method(:onTimerTick), 1000, true);
        mTimerRunning = true;
        System.println("Simple timer running");
    }
    
    // Direct timer callback function - safe implementation
    function onTimerTick() {
        try {
            processData();
        } catch (e) {
            System.println("Error in timer processing: " + e.getErrorMessage());
        }
    }
    
    function processData() {
        if (mModel != null) {
            var data = mModel.getData();
            
            // Only process data if recording and not paused
            if (data["isRecording"] && !(data.hasKey("sessionPaused") && data["sessionPaused"])) {
                // Process model data...
                
                // Get current values for lap fields
                var pctOnFoil = 0;
                var vmgUp = 0;
                var vmgDown = 0;
                var tackSec = 0;
                var tackMtr = 0;
                var tackAng = 0;
                
                // Get data from model
                if (data.hasKey("percentOnFoil")) {
                    pctOnFoil = data["percentOnFoil"].toNumber();
                }
                
                // Get data from WindTracker for other fields
                if (mWindTracker != null) {
                    var windData = mWindTracker.getWindData();
                    if (windData != null && windData.hasKey("valid") && windData["valid"]) {
                        // VMG data
                        if (windData.hasKey("currentVMG")) {
                            // Based on point of sail, update vmgUp or vmgDown
                            var currentVMG = windData["currentVMG"];
                            var isUpwind = (windData.hasKey("currentPointOfSail") && 
                                        windData["currentPointOfSail"] == "Upwind");
                                        
                            if (isUpwind) {
                                vmgUp = (currentVMG * 10).toNumber(); // Scale by 10 for one decimal place
                            } else {
                                vmgDown = (currentVMG * 10).toNumber(); // Scale by 10 for one decimal place
                            }
                        }
                        
                        // Tack angle
                        if (windData.hasKey("lastTackAngle")) {
                            tackAng = windData["lastTackAngle"].toNumber();
                        }
                        
                        // Get other data if available
                        // ...
                    }
                    
                    // Get lap specific data
                    var lapData = mWindTracker.getLapData();
                    if (lapData != null) {
                        if (lapData.hasKey("tackSec")) {
                            tackSec = (lapData["tackSec"] * 10).toNumber(); // Scale by 10
                        }
                        if (lapData.hasKey("tackMtr")) {
                            tackMtr = (lapData["tackMtr"] * 10).toNumber(); // Scale by 10
                        }
                    }
                }
                
                // Now continuously update the lap fields with current values
                System.println("Updating lap fields with current values");
                updateLapFields(pctOnFoil, vmgUp, vmgDown, tackSec, tackMtr, tackAng);
                
                // Rest of method remains the same...
                mModel.updateData();
            } else {
                // Still update time display when paused
                if (data.hasKey("sessionPaused") && data["sessionPaused"]) {
                    mModel.updateTimeDisplay();
                }
            }
            
            // Request UI update regardless of state
            WatchUi.requestUpdate();
        }
    }

    // onStop() is called when the application is exiting
    function onStop(state) {
        System.println("App stopping - saving activity data");
        
        // Emergency timestamp save first (always works)
        try {
            var storage = Application.Storage;
            storage.setValue("appStopTime", Time.now().value());
            System.println("Emergency timestamp saved");
        } 
        catch (e) {
            System.println("Even timestamp save failed");
        }
        
        // Attempt full data save if model is available
        if (mModel != null) {
            try {
                var saveResult = mModel.saveActivityData();
                if (saveResult) {
                    System.println("Activity data saved successfully");
                } else {
                    System.println("Activity save reported failure");
                }
            } 
            catch (e) {
                System.println("Error in onStop when saving: " + e.getErrorMessage());
                
                // Try one more emergency direct save
                try {
                    var storage = Application.Storage;
                    var finalBackup = {
                        "date" => Time.now().value(),
                        "onStopEmergency" => true
                    };
                    storage.setValue("onStop_emergency", finalBackup);
                    System.println("OnStop emergency save succeeded");
                } catch (e2) {
                    System.println("All save attempts failed");
                }
            }
        } 
        else {
            System.println("Model not available in onStop");
        }
    }

    // Function to get initial view - modified to start with wind picker
    function getInitialView() {
        // Initialize the model if not already initialized
        if (mModel == null) {
            mModel = new FoilTrackerModel();
        }
        
        // Create a wind strength picker view as the initial view
        var windView = new WindStrengthPickerView(mModel);
        var windDelegate = new StartupWindStrengthDelegate(mModel, self);
        windDelegate.setPickerView(windView);
        
        // Return the wind picker as initial view
        return [windView, windDelegate];
    }
}