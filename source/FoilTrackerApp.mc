using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Position;
using Toybox.Timer;
using Toybox.Lang;
using Toybox.FitContributor;
using Toybox.Time;

// Main Application class

class FoilTrackerApp extends Application.AppBase {
    private var mLapTackCountField = null;
    private var mLapGybeCountField = null;

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
    
    private var mLapPctOnFoilField;
    private var mLapVMGUpField;
    private var mLapVMGDownField;
    private var mLapTackSecField;
    private var mLapTackMtrField;
    private var mLapAvgTackAngleField;
    private var mLapWindDirectionField;
    private var mLapWindStrengthField;
    private var mLapAvgGybeAngleField;

    // Update FoilTrackerModel.mc initialize method
    // In FoilTrackerApp initialize method
    function initialize() {
        AppBase.initialize();
        
        // Initialize the model first
        mModel = new FoilTrackerModel();
        
        // Then access data through the model
        var data = mModel.getData(); // Correct way to access the data
        
        // Rest of your initialization
        mSession = null;
        mPositionEnabled = false;
        mTimer = null;
        mTimerRunning = false;
        mWindTracker = new WindTracker();
        
        // Initialize field objects
        mWorkoutNameField = null;
        mWindStrengthField = null;
        mWindDirectionField = null;
        mLapPctOnFoilField = null;
        mLapVMGUpField = null;
        mLapVMGDownField = null;
        mLapTackSecField = null;
        mLapTackMtrField = null;
        mLapAvgTackAngleField = null;
        mLapWindDirectionField = null; 
        mLapWindStrengthField = null;
        mLapAvgGybeAngleField = null;
        mLapTackCountField = null;
        mLapGybeCountField = null;
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
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPositionCallback));
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
    // Update this method in FoilTrackerApp.mc
    function onPositionCallback(posInfo as Position.Info) as Void {
        // Only process if we have valid location info
        if (posInfo != null) {
            // Pass position data to wind tracker
            if (mWindTracker != null) {
                mWindTracker.processPositionData(posInfo);
                
                // Update total counts
                updateTotalCounts();
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

    // Add this accessor method to FoilTrackerApp
    function getModelData() {
        if (mModel != null) {
            return mModel.getData();
        }
        return null;
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

    // Create FitContributor fields for the session - simplified for compatibility
    // Modified to use proper lap field creation syntax and add tack/gybe counts
    // Create FitContributor fields for the session
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
                
                // 2. VMG Upwind - Field ID 101 - Changed to FLOAT
                mLapVMGUpField = mSession.createField(
                    "vmgUp",
                    101,
                    FitContributor.DATA_TYPE_FLOAT,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "kts"
                    }
                );
                
                if (mLapVMGUpField != null) {
                    System.println("✓ Created lap field: vmgUp (ID: 101)");
                }
                
                // 3. VMG Downwind - Field ID 102 - Changed to FLOAT
                mLapVMGDownField = mSession.createField(
                    "vmgDown",
                    102,
                    FitContributor.DATA_TYPE_FLOAT,
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
                
                // 7. Wind Direction - Field ID 106
                mLapWindDirectionField = mSession.createField(
                    "windDir",
                    106,
                    FitContributor.DATA_TYPE_UINT16,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "deg"
                    }
                );
                
                if (mLapWindDirectionField != null) {
                    System.println("✓ Created lap field: windDir (ID: 106)");
                }
                
                // 8. Wind Strength - Field ID 107
                mLapWindStrengthField = mSession.createField(
                    "windStr",
                    107,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "kts"
                    }
                );
                
                if (mLapWindStrengthField != null) {
                    System.println("✓ Created lap field: windStr (ID: 107)");
                }
                
                // 9. Avg Gybe Angle - Field ID 108
                mLapAvgGybeAngleField = mSession.createField(
                    "gybeAng",
                    108,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "deg"
                    }
                );
                
                if (mLapAvgGybeAngleField != null) {
                    System.println("✓ Created lap field: gybeAng (ID: 108)");
                }
                
                // 10. Tack Count - Field ID 109
                mLapTackCountField = mSession.createField(
                    "tackCount",
                    109,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "count"
                    }
                );
                
                if (mLapTackCountField != null) {
                    System.println("✓ Created lap field: tackCount (ID: 109)");
                }
                
                // 11. Gybe Count - Field ID 110
                mLapGybeCountField = mSession.createField(
                    "gybeCount",
                    110,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "count"
                    }
                );
                
                if (mLapGybeCountField != null) {
                    System.println("✓ Created lap field: gybeCount (ID: 110)");
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
                "avgGybeAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0,
                "windDirection" => 0,
                "windStrength" => 0
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
                    
                    // VMG Upwind - use as float
                    if (lapSpecificData.hasKey("vmgUp")) {
                        var vmgUp = lapSpecificData["vmgUp"];
                        // Ensure it's a number and not null
                        if (vmgUp != null) {
                            lapData["vmgUp"] = vmgUp;
                            System.println("- Using lap VMG Up: " + vmgUp);
                        }
                    }
                    
                    // VMG Downwind - use as float
                    if (lapSpecificData.hasKey("vmgDown")) {
                        var vmgDown = lapSpecificData["vmgDown"];
                        // Ensure it's a number and not null
                        if (vmgDown != null) {
                            lapData["vmgDown"] = vmgDown;
                            System.println("- Using lap VMG Down: " + vmgDown);
                        }
                    }
                    
                    // Tack Seconds - handle as float
                    if (lapSpecificData.hasKey("tackSec")) {
                        var tackSec = lapSpecificData["tackSec"];
                        // Ensure it's a number and not null
                        if (tackSec != null) {
                            lapData["tackSec"] = tackSec;
                            System.println("- Using lap Tack Seconds: " + tackSec);
                        }
                    }
                    
                    // Tack Meters - handle as float
                    if (lapSpecificData.hasKey("tackMtr")) {
                        var tackMtr = lapSpecificData["tackMtr"];
                        // Ensure it's a number and not null
                        if (tackMtr != null) {
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
                    
                    // Average Gybe Angle - integer
                    if (lapSpecificData.hasKey("avgGybeAngle")) {
                        var avgGybeAngle = lapSpecificData["avgGybeAngle"];
                        // Ensure it's a number and not null
                        if (avgGybeAngle != null) {
                            // Round to whole number
                            avgGybeAngle = Math.round(avgGybeAngle).toNumber();
                            lapData["avgGybeAngle"] = avgGybeAngle;
                            System.println("- Using lap Avg Gybe Angle: " + avgGybeAngle);
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
                    
                    // Wind Direction
                    if (lapSpecificData.hasKey("windDirection")) {
                        var windDirection = lapSpecificData["windDirection"];
                        // Ensure it's a number and not null
                        if (windDirection != null) {
                            // Round to whole number
                            windDirection = Math.round(windDirection).toNumber();
                            lapData["windDirection"] = windDirection;
                            System.println("- Using lap wind direction: " + windDirection);
                        }
                    }
                    
                    // Wind Strength
                    if (lapSpecificData.hasKey("windStrength")) {
                        var windStrength = lapSpecificData["windStrength"];
                        // Ensure it's a number and not null
                        if (windStrength != null) {
                            lapData["windStrength"] = windStrength;
                            System.println("- Using lap wind strength: " + windStrength);
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
    // VMG fallbacks based on current point of sail
                if (lapData["vmgUp"] == 0.0 && lapData["vmgDown"] == 0.0 && windData != null) {
                    if (windData.hasKey("currentVMG") && windData.hasKey("currentPointOfSail")) {
                        var vmg = windData["currentVMG"];
                        var isUpwind = (windData["currentPointOfSail"] == "Upwind");
                        
                        if (isUpwind) {
                            lapData["vmgUp"] = vmg;
                            System.println("- Fallback VMG Up: " + lapData["vmgUp"]);
                        } else {
                            lapData["vmgDown"] = vmg;
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
                
                // Gybe angle fallback from overall stats
                if (lapData["avgGybeAngle"] == 0 && windData != null && windData.hasKey("maneuverStats")) {
                    var stats = windData["maneuverStats"];
                    if (stats != null && stats.hasKey("avgGybeAngle")) {
                        var angle = stats["avgGybeAngle"];
                        if (angle != null) {
                            angle = Math.round(angle).toNumber();
                            lapData["avgGybeAngle"] = angle;
                            System.println("- Fallback Avg Gybe Angle: " + angle);
                        }
                    }
                }
                
                // Wind direction fallback
                if (lapData["windDirection"] == 0 && windData != null && windData.hasKey("windDirection")) {
                    var windDirection = windData["windDirection"];
                    lapData["windDirection"] = windDirection;
                    System.println("- Fallback wind direction: " + windDirection);
                }
                
                // Wind strength fallback
                if (lapData["windStrength"] == 0 && mModel != null) {
                    var data = mModel.getData();
                    if (data.hasKey("windStrengthIndex")) {
                        var windStrength = data["windStrengthIndex"];
                        lapData["windStrength"] = windStrength;
                        System.println("- Fallback wind strength: " + windStrength);
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
                if (lapData["avgGybeAngle"] > 180) { lapData["avgGybeAngle"] = 180; }
                if (lapData["pctOnFoil"] > 100) { lapData["pctOnFoil"] = 100; }
                if (lapData["windDirection"] > 359) { lapData["windDirection"] = lapData["windDirection"] % 360; }
                
                // Ensure all values are non-negative
                if (lapData["vmgUp"] < 0) { lapData["vmgUp"] = 0; }
                if (lapData["vmgDown"] < 0) { lapData["vmgDown"] = 0; }
                if (lapData["tackSec"] < 0) { lapData["tackSec"] = 0; }
                if (lapData["tackMtr"] < 0) { lapData["tackMtr"] = 0; }
                if (lapData["avgTackAngle"] < 0) { lapData["avgTackAngle"] = 0; }
                if (lapData["avgGybeAngle"] < 0) { lapData["avgGybeAngle"] = 0; }
                if (lapData["pctOnFoil"] < 0) { lapData["pctOnFoil"] = 0; }
                if (lapData["windStrength"] < 0) { lapData["windStrength"] = 0; }
                
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
            System.println("- Avg Gybe Angle: " + lapData["avgGybeAngle"]);
            System.println("- % On Foil: " + lapData["pctOnFoil"]);
            System.println("- Lap VMG: " + lapData["lapVMG"]);
            System.println("- Wind Direction: " + lapData["windDirection"]);
            System.println("- Wind Strength: " + lapData["windStrength"]);
            
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
                "avgGybeAngle" => 0,
                "lapVMG" => 0.0,
                "pctOnFoil" => 0.0,
                "windDirection" => 0,
                "windStrength" => 0
            };
        }
    }
    // In FoilTrackerApp.mc - onTimerLap implementation
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
    // Helper method to update lap fields
    // Helper method to update lap fields
    // Complete updateLapFields method
    function updateLapFields(pctOnFoil, vmgUp, vmgDown, tackSec, tackMtr, tackAng, gybeAng, avgWindDir, windStr, tackCount, gybeCount) {
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
                
                if (mLapAvgGybeAngleField != null) {
                    mLapAvgGybeAngleField.setData(gybeAng);
                }
                
                if (mLapWindDirectionField != null) {
                    mLapWindDirectionField.setData(avgWindDir);
                }
                
                if (mLapWindStrengthField != null) {
                    mLapWindStrengthField.setData(windStr);
                }
                
                if (mLapTackCountField != null) {
                    mLapTackCountField.setData(tackCount);
                }
                
                if (mLapGybeCountField != null) {
                    mLapGybeCountField.setData(gybeCount);
                }
                
                // No need to call addLap() here - this just keeps the field values up to date
                // The system will grab these values when a lap is actually triggered
            } catch (e) {
                System.println("Error updating lap fields: " + e.getErrorMessage());
            }
        }
    }

    // Method to add a lap marker
    // Method to add a lap marker
    function addLapMarker() {
        if (mSession != null && mSession.isRecording()) {
            try {
                System.println("=== VERIFYING FIELD OBJECTS BEFORE LAP MARKER ===");
                
                // Create fields if they don't exist
                createLapFields();
                
                // Get lap data from wind tracker
                var lapData = mWindTracker.getLapData();
                if (lapData == null) {
                    System.println("WARNING: No lap data available - using default values");
                    lapData = {
                        "pctOnFoil" => 0,
                        "vmgUp" => 0.0,
                        "vmgDown" => 0.0,
                        "tackSec" => 0.0,
                        "tackMtr" => 0.0,
                        "avgTackAngle" => 0,
                        "avgGybeAngle" => 0,
                        "windDirection" => mWindTracker.getWindDirection(),
                        "windStrength" => 0,
                        "tackCount" => 0,
                        "gybeCount" => 0
                    };
                    
                    if (mModel != null && mModel.getData().hasKey("windStrengthIndex")) {
                        lapData["windStrength"] = mModel.getData()["windStrengthIndex"];
                    }
                }
                
                System.println("=== SETTING FIELD VALUES ===");
                
                // Set field values
                try {
                    // Set Percent on Foil value
                    if (mLapPctOnFoilField != null) {
                        var pctOnFoil = Math.round(lapData["pctOnFoil"]).toNumber();
                        System.println("Setting field 100 (pct on foil) = " + pctOnFoil);
                        var result = mLapPctOnFoilField.setData(pctOnFoil);
                        System.println("Result of setting field 100: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 100: " + e.getErrorMessage());
                }
                
                // Add these try/catch blocks to your addLapMarker method
                try {
                    if (mLapTackCountField != null) {
                        var tackCount = 0;
                        if (lapData.hasKey("tackCount")) {
                            tackCount = lapData["tackCount"];
                        }
                        System.println("Setting field 109 (tack count) = " + tackCount);
                        var result = mLapTackCountField.setData(tackCount);
                        System.println("Result of setting field 109: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 109: " + e.getErrorMessage());
                }

                try {
                    if (mLapGybeCountField != null) {
                        var gybeCount = 0;
                        if (lapData.hasKey("gybeCount")) {
                            gybeCount = lapData["gybeCount"];
                        }
                        System.println("Setting field 110 (gybe count) = " + gybeCount);
                        var result = mLapGybeCountField.setData(gybeCount);
                        System.println("Result of setting field 110: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 110: " + e.getErrorMessage());
                }

                // Set VMG Up value
                try {
                    if (mLapVMGUpField != null) {
                        var vmgUp = lapData["vmgUp"];
                        System.println("Setting field 101 (vmg up) = " + vmgUp);
                        var result = mLapVMGUpField.setData(vmgUp);
                        System.println("Result of setting field 101: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 101: " + e.getErrorMessage());
                }
                
                // Set VMG Down value
                try {
                    if (mLapVMGDownField != null) {
                        var vmgDown = lapData["vmgDown"];
                        System.println("Setting field 102 (vmg down) = " + vmgDown);
                        var result = mLapVMGDownField.setData(vmgDown);
                        System.println("Result of setting field 102: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 102: " + e.getErrorMessage());
                }
                
                // Set Tack Seconds value
                try {
                    if (mLapTackSecField != null) {
                        var tackSec = Math.round(lapData["tackSec"]).toNumber();
                        System.println("Setting field 103 (tack sec) = " + tackSec);
                        var result = mLapTackSecField.setData(tackSec);
                        System.println("Result of setting field 103: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 103: " + e.getErrorMessage());
                }
                
                // Set Tack Meters value
                try {
                    if (mLapTackMtrField != null) {
                        var tackMtr = Math.round(lapData["tackMtr"]).toNumber();
                        System.println("Setting field 104 (tack mtr) = " + tackMtr);
                        var result = mLapTackMtrField.setData(tackMtr);
                        System.println("Result of setting field 104: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 104: " + e.getErrorMessage());
                }
                
                // Set Average Tack Angle value
                try {
                    if (mLapAvgTackAngleField != null) {
                        var tackAngle = Math.round(lapData["avgTackAngle"]).toNumber();
                        System.println("Setting field 105 (tack angle) = " + tackAngle);
                        var result = mLapAvgTackAngleField.setData(tackAngle);
                        System.println("Result of setting field 105: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 105: " + e.getErrorMessage());
                }
                
                // Set Wind Direction value
                try {
                    if (mLapWindDirectionField != null) {
                        var windDirection = Math.round(lapData["windDirection"]).toNumber();
                        System.println("Setting field 106 (wind dir) = " + windDirection);
                        var result = mLapWindDirectionField.setData(windDirection);
                        System.println("Result of setting field 106: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 106: " + e.getErrorMessage());
                }
                
                // Set Wind Strength value
                try {
                    if (mLapWindStrengthField != null) {
                        var windStrength = lapData["windStrength"];
                        System.println("Setting field 107 (wind str) = " + windStrength);
                        var result = mLapWindStrengthField.setData(windStrength);
                        System.println("Result of setting field 107: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 107: " + e.getErrorMessage());
                }
                
                // Set Average Gybe Angle value
                try {
                    if (mLapAvgGybeAngleField != null) {
                        var gybeAngle = Math.round(lapData["avgGybeAngle"]).toNumber();
                        System.println("Setting field 108 (gybe angle) = " + gybeAngle);
                        var result = mLapAvgGybeAngleField.setData(gybeAngle);
                        System.println("Result of setting field 108: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 108: " + e.getErrorMessage());
                }
                
                // Set Tack Count value
                try {
                    if (mLapTackCountField != null) {
                        var tackCount = 0;
                        if (lapData.hasKey("tackCount")) {
                            tackCount = lapData["tackCount"];
                        }
                        System.println("Setting field 109 (tack count) = " + tackCount);
                        var result = mLapTackCountField.setData(tackCount);
                        System.println("Result of setting field 109: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 109: " + e.getErrorMessage());
                }
                
                // Set Gybe Count value
                try {
                    if (mLapGybeCountField != null) {
                        var gybeCount = 0;
                        if (lapData.hasKey("gybeCount")) {
                            gybeCount = lapData["gybeCount"];
                        }
                        System.println("Setting field 110 (gybe count) = " + gybeCount);
                        var result = mLapGybeCountField.setData(gybeCount);
                        System.println("Result of setting field 110: " + result);
                    }
                } catch (e) {
                    System.println("ERROR setting field 110: " + e.getErrorMessage());
                }
                
                // Add a lap marker
                System.println("=== ADDING LAP MARKER ===");
                mSession.addLap();
                
                // Notify the WindTracker
                if (mWindTracker != null) {
                    mWindTracker.onLapMarked(null);
                }
                
                System.println("Lap marker added");
                
            } catch (e) {
                System.println("ERROR in addLapMarker: " + e.getErrorMessage());
            }
        } else {
            System.println("Cannot add lap marker - session not recording");
        }
    }

    // Helper function to ensure lap fields exist
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
                
                // 2. VMG Upwind - Field ID 101 - Changed to FLOAT
                mLapVMGUpField = mSession.createField(
                    "vmgUp",
                    101,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 101: vmgUp");
                
                // 3. VMG Downwind - Field ID 102 - Changed to FLOAT
                mLapVMGDownField = mSession.createField(
                    "vmgDown",
                    102,
                    FitContributor.DATA_TYPE_FLOAT,
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
                
                // 7. Wind Direction - Field ID 106
                mLapWindDirectionField = mSession.createField(
                    "windDir",
                    106,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 106: windDir");
                
                // 8. Wind Strength - Field ID 107
                mLapWindStrengthField = mSession.createField(
                    "windStr",
                    107,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 107: windStr");
                
                // 9. Avg Gybe Angle - Field ID 108
                mLapAvgGybeAngleField = mSession.createField(
                    "gybeAng",
                    108,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 108: gybeAng");

                // 10. Tack Count - Field ID 109
                mLapTackCountField = mSession.createField(
                    "tackCount",
                    109,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 109: tackCount");

                // 11. Gybe Count - Field ID 110
                mLapGybeCountField = mSession.createField(
                    "gybeCount",
                    110,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 110: gybeCount");

                // Add these field creations to createLapFields method
                // 10. Tack Count - Field ID 109
                mLapTackCountField = mSession.createField(
                    "tackCount",
                    109,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 109: tackCount");

                // 11. Gybe Count - Field ID 110
                mLapGybeCountField = mSession.createField(
                    "gybeCount",
                    110,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                System.println("Created field 110: gybeCount");
                
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
                // Get current values for lap fields
                var pctOnFoil = 0;
                var vmgUp = 0.0;
                var vmgDown = 0.0;
                var tackSec = 0.0;
                var tackMtr = 0.0;
                var tackAng = 0;
                var gybeAng = 0;
                var avgWindDir = 0;
                var windStr = 0;
                var tackCount = 0;
                var gybeCount = 0;
                
                // Get data from model
                if (data.hasKey("percentOnFoil")) {
                    pctOnFoil = data["percentOnFoil"].toNumber();
                }
                
                // Get wind strength from model
                if (data.hasKey("windStrengthIndex")) {
                    windStr = data["windStrengthIndex"];
                }
                
                // Get data from WindTracker for other fields
                if (mWindTracker != null) {
                    var windData = mWindTracker.getWindData();
                    if (windData != null && windData.hasKey("valid") && windData["valid"]) {
                        // Wind Direction
                        if (windData.hasKey("windDirection")) {
                            avgWindDir = windData["windDirection"];
                        }
                        
                        // VMG data - use float values directly
                        if (windData.hasKey("currentVMG")) {
                            // Based on point of sail, update vmgUp or vmgDown
                            var currentVMG = windData["currentVMG"];
                            var isUpwind = (windData.hasKey("currentPointOfSail") && 
                                        windData["currentPointOfSail"] == "Upwind");
                                        
                            if (isUpwind) {
                                vmgUp = currentVMG;  // Use directly as float
                            } else {
                                vmgDown = currentVMG;  // Use directly as float
                            }
                        }
                        
                        // Tack angle
                        if (windData.hasKey("lastTackAngle")) {
                            tackAng = windData["lastTackAngle"].toNumber();
                        }
                        
                        // Gybe angle
                        if (windData.hasKey("lastGybeAngle")) {
                            gybeAng = windData["lastGybeAngle"].toNumber();
                        }
                        
                        // Tack count
                        if (windData.hasKey("tackCount")) {
                            tackCount = windData["tackCount"];
                        }
                        
                        // Gybe count
                        if (windData.hasKey("gybeCount")) {
                            gybeCount = windData["gybeCount"];
                        }
                    }
                    
                    // Get lap specific data
                    var lapData = mWindTracker.getLapData();
                    if (lapData != null) {
                        if (lapData.hasKey("tackSec")) {
                            tackSec = lapData["tackSec"];
                        }
                        if (lapData.hasKey("tackMtr")) {
                            tackMtr = lapData["tackMtr"];
                        }
                        // Use lap-specific tack and gybe angles if available
                        if (lapData.hasKey("avgTackAngle")) {
                            tackAng = lapData["avgTackAngle"];
                        }
                        if (lapData.hasKey("avgGybeAngle")) {
                            gybeAng = lapData["avgGybeAngle"];
                        }
                        // Use lap-specific VMG values if available
                        if (lapData.hasKey("vmgUp")) {
                            vmgUp = lapData["vmgUp"];
                        }
                        if (lapData.hasKey("vmgDown")) {
                            vmgDown = lapData["vmgDown"];
                        }
                        // Use lap-specific wind direction if available
                        if (lapData.hasKey("windDirection")) {
                            avgWindDir = lapData["windDirection"];
                        }
                        // Use lap-specific tack and gybe counts if available
                        if (lapData.hasKey("tackCount")) {
                            tackCount = lapData["tackCount"];
                        }
                        if (lapData.hasKey("gybeCount")) {
                            gybeCount = lapData["gybeCount"];
                        }
                    }
                }
                
                // Now continuously update the lap fields with current values
                System.println("Updating lap fields with current values");
                updateLapFields(pctOnFoil, vmgUp, vmgDown, tackSec, tackMtr, tackAng, gybeAng, avgWindDir, windStr, tackCount, gybeCount);
                
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
    
    // Add this method to FoilTrackerApp.mc
    function updateTotalCounts() {
        if (mModel != null && mWindTracker != null) {
            var data = mModel.getData();
            var windData = mWindTracker.getWindData();
            
            if (windData != null && windData.hasKey("valid") && windData["valid"]) {
                // Calculate total tack count
                var totalTackCount = 0;
                if (data.hasKey("totalTackCount")) {
                    totalTackCount = data["totalTackCount"];
                }
                
                // If current tack count is greater than what we've stored
                if (windData.hasKey("tackCount") && windData["tackCount"] > 0) {
                    var currentTackCount = windData["tackCount"];
                    if (!data.hasKey("lastTackCount") || data["lastTackCount"] != currentTackCount) {
                        // Tack count has changed
                        var diff = 0;
                        if (data.hasKey("lastTackCount")) {
                            diff = currentTackCount - data["lastTackCount"];
                            if (diff < 0) {
                                // A reset happened, just add the current count
                                diff = currentTackCount;
                            }
                        } else {
                            diff = currentTackCount;
                        }
                        
                        // Update total
                        totalTackCount += diff;
                        data["totalTackCount"] = totalTackCount;
                        
                        // Store current count for next comparison
                        data["lastTackCount"] = currentTackCount;
                    }
                }
                
                // Calculate total gybe count - similar logic
                var totalGybeCount = 0;
                if (data.hasKey("totalGybeCount")) {
                    totalGybeCount = data["totalGybeCount"];
                }
                
                if (windData.hasKey("gybeCount") && windData["gybeCount"] > 0) {
                    var currentGybeCount = windData["gybeCount"];
                    if (!data.hasKey("lastGybeCount") || data["lastGybeCount"] != currentGybeCount) {
                        // Gybe count has changed
                        var diff = 0;
                        if (data.hasKey("lastGybeCount")) {
                            diff = currentGybeCount - data["lastGybeCount"];
                            if (diff < 0) {
                                // A reset happened, just add the current count
                                diff = currentGybeCount;
                            }
                        } else {
                            diff = currentGybeCount;
                        }
                        
                        // Update total
                        totalGybeCount += diff;
                        data["totalGybeCount"] = totalGybeCount;
                        
                        // Store current count for next comparison
                        data["lastGybeCount"] = currentGybeCount;
                    }
                }
            }
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