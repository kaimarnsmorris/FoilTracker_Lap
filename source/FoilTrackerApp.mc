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
    
    // For FoilTrackerApp class
    // Standard fields
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


    // New fields
    private var mLapPctUpwindField;
    private var mLapPctDownwindField;
    private var mLapAvgWindAngleField;
    private var mLapAvgSpeedField;
    private var mLapMaxSpeedField;

    // In FoilTrackerApp.mc
    // Update initialize method to remove avgSpeed and maxSpeed fields
    function initialize() {
        AppBase.initialize();
        
        // Initialize the model first
        mModel = new FoilTrackerModel();       
        
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
        
        // New field initializations
        mLapPctUpwindField = null;
        mLapPctDownwindField = null;
        mLapAvgWindAngleField = null;
        
        // CHANGE 1: Remove these field initializations
        // mLapAvgSpeedField = null;
        // mLapMaxSpeedField = null;
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

    // In FoilTrackerApp.mc
    // Update createFitContributorFields with simplified wind logic and reduced logging
    function createFitContributorFields(sessionName, windStrength) {
        try {
            // Check if the session is valid
            if (mSession == null) {
                return;
            }
            
            // --- SESSION FIELDS ---
            
            // SIMPLIFIED: Create windStrength field with lower limit value based on index
            mWindStrengthField = mSession.createField(
                "windLow",
                1,
                FitContributor.DATA_TYPE_UINT8, 
                { :mesgType => FitContributor.MESG_TYPE_SESSION }
            );
            
            if (mWindStrengthField != null) {
                var windValue = 7; // Default value
                
                // Get the index directly from the model
                var data = mModel.getData();
                if (data != null && data.hasKey("windStrengthIndex")) {
                    var windIndex = data["windStrengthIndex"];
                    windValue = 7 + (windIndex * 3);
                }
                
                mWindStrengthField.setData(windValue);
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
                }
            }
            
            // --- LAP FIELDS ---
            
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
                
                // 12. Percent Upwind - Field ID 111
                mLapPctUpwindField = mSession.createField(
                    "pctUpwind",
                    111,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "%"
                    }
                );
                
                // 13. Percent Downwind - Field ID 112
                mLapPctDownwindField = mSession.createField(
                    "pctDownwind",
                    112,
                    FitContributor.DATA_TYPE_UINT8,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "%"
                    }
                );
                
                // 14. Average Wind Angle - Field ID 113
                mLapAvgWindAngleField = mSession.createField(
                    "avgWindAng",
                    113,
                    FitContributor.DATA_TYPE_UINT16,
                    { 
                        :mesgType => FitContributor.MESG_TYPE_LAP,
                        :units => "deg"
                    }
                );
            }
        } catch (e) {
            // Silent error handling
        }
    }

    // In FoilTrackerApp.mc
    // Update getLapData to remove avgSpeed and maxSpeed fields and use lower wind limits
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
                "windStrength" => 0,
                "pctUpwind" => 0,
                "pctDownwind" => 0,
                "avgWindAngle" => 0
                // CHANGE 1: Removed avgSpeed and maxSpeed fields
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
                    
                    // Wind Strength - use the lower limit of the range
                    if (lapSpecificData.hasKey("windStrength")) {
                        var windStrength = lapSpecificData["windStrength"];
                        // Ensure it's a number and not null
                        if (windStrength != null) {
                            lapData["windStrength"] = windStrength;
                            System.println("- Using lap wind strength: " + windStrength);
                        }
                    }
                    
                    // Point of Sail percentages
                    if (lapSpecificData.hasKey("pctUpwind")) {
                        var pctUpwind = lapSpecificData["pctUpwind"];
                        if (pctUpwind != null) {
                            lapData["pctUpwind"] = pctUpwind;
                            System.println("- Using lap % Upwind: " + pctUpwind);
                        }
                    }
                    
                    if (lapSpecificData.hasKey("pctDownwind")) {
                        var pctDownwind = lapSpecificData["pctDownwind"];
                        if (pctDownwind != null) {
                            lapData["pctDownwind"] = pctDownwind;
                            System.println("- Using lap % Downwind: " + pctDownwind);
                        }
                    }
                    
                    // Average Wind Angle
                    if (lapSpecificData.hasKey("avgWindAngle")) {
                        var avgWindAngle = lapSpecificData["avgWindAngle"];
                        if (avgWindAngle != null) {
                            lapData["avgWindAngle"] = avgWindAngle;
                            System.println("- Using lap Avg Wind Angle: " + avgWindAngle);
                        }
                    }
                    
                    // CHANGE 1: Removed avgSpeed and maxSpeed fields
                    
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
                
                // CHANGE 3: Wind strength fallback - use the lower limit of wind range
                if (lapData["windStrength"] == 0) {
                    var data = mModel.getData();
                    if (data != null) {
                        if (data.hasKey("windStrength")) {
                            var windStrengthStr = data["windStrength"];
                            
                            // Extract the lower limit of the range
                            if (windStrengthStr != null && windStrengthStr instanceof String) {
                                // Parse the string to get the lower limit of the range
                                var dashIndex = windStrengthStr.find("-");
                                var plusIndex = windStrengthStr.find("+");
                                
                                if (dashIndex >= 0) {
                                    // Format like "7-10 knots" or "10-13 knots"
                                    var lowerLimitStr = windStrengthStr.substring(0, dashIndex);
                                    lapData["windStrength"] = lowerLimitStr.toNumber();
                                    System.println("- Extracted lower wind limit from range: " + lapData["windStrength"]);
                                } else if (plusIndex >= 0) {
                                    // Format like "25+ knots"
                                    var limitStr = windStrengthStr.substring(0, plusIndex);
                                    lapData["windStrength"] = limitStr.toNumber();
                                    System.println("- Extracted wind limit from plus format: " + lapData["windStrength"]);
                                }
                            } else if (data.hasKey("windStrengthIndex")) {
                                // Fallback to index-based calculation
                                var windIndex = data["windStrengthIndex"];
                                
                                // Convert index to lower limit of range (7, 10, 13, 16, 19, 22, 25)
                                lapData["windStrength"] = 7 + (windIndex * 3);
                                System.println("- Calculated wind strength from index: " + lapData["windStrength"]);
                            }
                        } else if (data.hasKey("windStrengthIndex")) {
                            // Fallback to index-based calculation
                            var windIndex = data["windStrengthIndex"];
                            
                            // Convert index to lower limit of range (7, 10, 13, 16, 19, 22, 25)
                            lapData["windStrength"] = 7 + (windIndex * 3);
                            System.println("- Calculated wind strength from index: " + lapData["windStrength"]);
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
                
                // Point of sail percentages
                if (lapData["pctUpwind"] > 100) { lapData["pctUpwind"] = 100; }
                if (lapData["pctDownwind"] > 100) { lapData["pctDownwind"] = 100; }
                if (lapData["pctUpwind"] < 0) { lapData["pctUpwind"] = 0; }
                if (lapData["pctDownwind"] < 0) { lapData["pctDownwind"] = 0; }
                
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
            System.println("- % Upwind: " + lapData["pctUpwind"]);
            System.println("- % Downwind: " + lapData["pctDownwind"]);
            System.println("- Avg Wind Angle: " + lapData["avgWindAngle"]);
            
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
                "windStrength" => 0,
                "pctUpwind" => 0,
                "pctDownwind" => 0,
                "avgWindAngle" => 0
                // CHANGE 1: Removed avgSpeed and maxSpeed fields
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

    // In FoilTrackerApp.mc
    // Update updateLapFields to remove avgSpeed and maxSpeed
    function updateLapFields(pctOnFoil, vmgUp, vmgDown, tackSec, tackMtr, tackAng, gybeAng, avgWindDir, windStr, tackCount, gybeCount, 
                            pctUpwind, pctDownwind, avgWindAngle) {
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
                
                // New fields
                if (mLapPctUpwindField != null) {
                    mLapPctUpwindField.setData(pctUpwind);
                }
                
                if (mLapPctDownwindField != null) {
                    mLapPctDownwindField.setData(pctDownwind);
                }
                
                if (mLapAvgWindAngleField != null) {
                    mLapAvgWindAngleField.setData(avgWindAngle);
                }
                
                // CHANGE 1: Removed avgSpeed and maxSpeed fields
                
                // No need to call addLap() here - this just keeps the field values up to date
                // The system will grab these values when a lap is actually triggered
            } catch (e) {
                System.println("Error updating lap fields: " + e.getErrorMessage());
            }
        }
    }

    // In FoilTrackerApp.mc
    // Update addLapMarker with reduced logging and simplified wind logic
    function addLapMarker() {
        if (mSession != null && mSession.isRecording()) {
            try {
                // Create fields if they don't exist
                createLapFields();
                
                // Get lap data from wind tracker
                var lapData = mWindTracker.getLapData();
                if (lapData == null) {
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
                        "gybeCount" => 0,
                        "pctUpwind" => 0,
                        "pctDownwind" => 0,
                        "avgWindAngle" => 0
                    };
                    
                    // SIMPLIFIED: Wind strength from index
                    if (mModel != null && mModel.getData().hasKey("windStrengthIndex")) {
                        var windIndex = mModel.getData()["windStrengthIndex"];
                        lapData["windStrength"] = 7 + (windIndex * 3);
                    }
                }
                
                // Set field values with minimal logging
                try {
                    // Set Percent on Foil value
                    if (mLapPctOnFoilField != null) {
                        var pctOnFoil = Math.round(lapData["pctOnFoil"]).toNumber();
                        mLapPctOnFoilField.setData(pctOnFoil);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set VMG Up value
                try {
                    if (mLapVMGUpField != null) {
                        var vmgUp = lapData["vmgUp"];
                        mLapVMGUpField.setData(vmgUp);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set VMG Down value
                try {
                    if (mLapVMGDownField != null) {
                        var vmgDown = lapData["vmgDown"];
                        mLapVMGDownField.setData(vmgDown);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Tack Seconds value
                try {
                    if (mLapTackSecField != null) {
                        var tackSec = Math.round(lapData["tackSec"]).toNumber();
                        mLapTackSecField.setData(tackSec);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Tack Meters value
                try {
                    if (mLapTackMtrField != null) {
                        var tackMtr = Math.round(lapData["tackMtr"]).toNumber();
                        mLapTackMtrField.setData(tackMtr);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Average Tack Angle value
                try {
                    if (mLapAvgTackAngleField != null) {
                        var tackAngle = Math.round(lapData["avgTackAngle"]).toNumber();
                        mLapAvgTackAngleField.setData(tackAngle);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Wind Direction value
                try {
                    if (mLapWindDirectionField != null) {
                        var windDirection = Math.round(lapData["windDirection"]).toNumber();
                        mLapWindDirectionField.setData(windDirection);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Wind Strength value
                try {
                    if (mLapWindStrengthField != null) {
                        var windStrength = lapData["windStrength"];
                        mLapWindStrengthField.setData(windStrength);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Average Gybe Angle value
                try {
                    if (mLapAvgGybeAngleField != null) {
                        var gybeAngle = Math.round(lapData["avgGybeAngle"]).toNumber();
                        mLapAvgGybeAngleField.setData(gybeAngle);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Tack Count value
                try {
                    if (mLapTackCountField != null) {
                        var tackCount = 0;
                        if (lapData.hasKey("tackCount")) {
                            tackCount = lapData["tackCount"];
                        }
                        mLapTackCountField.setData(tackCount);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Gybe Count value
                try {
                    if (mLapGybeCountField != null) {
                        var gybeCount = 0;
                        if (lapData.hasKey("gybeCount")) {
                            gybeCount = lapData["gybeCount"];
                        }
                        mLapGybeCountField.setData(gybeCount);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Percent Upwind value
                try {
                    if (mLapPctUpwindField != null) {
                        var pctUpwind = 0;
                        if (lapData.hasKey("pctUpwind")) {
                            pctUpwind = lapData["pctUpwind"];
                        }
                        mLapPctUpwindField.setData(pctUpwind);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Percent Downwind value
                try {
                    if (mLapPctDownwindField != null) {
                        var pctDownwind = 0;
                        if (lapData.hasKey("pctDownwind")) {
                            pctDownwind = lapData["pctDownwind"];
                        }
                        mLapPctDownwindField.setData(pctDownwind);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Set Average Wind Angle value
                try {
                    if (mLapAvgWindAngleField != null) {
                        var avgWindAngle = 0;
                        if (lapData.hasKey("avgWindAngle")) {
                            avgWindAngle = lapData["avgWindAngle"];
                        }
                        mLapAvgWindAngleField.setData(avgWindAngle);
                    }
                } catch (e) {
                    // Silent error handling
                }
                
                // Add a lap marker
                mSession.addLap();
                
                // Notify the WindTracker
                if (mWindTracker != null) {
                    mWindTracker.onLapMarked(null);
                }
                
            } catch (e) {
                // Silent error handling
            }
        }
    }

    // In FoilTrackerApp.mc
    // Update createLapFields with reduced logging
    function createLapFields() {
        // Only create fields if they don't already exist
        if (mLapPctOnFoilField == null) {
            try {
                // 1. Percent on Foil - Field ID 100
                mLapPctOnFoilField = mSession.createField(
                    "pctOnFoil",
                    100,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 2. VMG Upwind - Field ID 101 - Changed to FLOAT
                mLapVMGUpField = mSession.createField(
                    "vmgUp",
                    101,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 3. VMG Downwind - Field ID 102 - Changed to FLOAT
                mLapVMGDownField = mSession.createField(
                    "vmgDown",
                    102,
                    FitContributor.DATA_TYPE_FLOAT,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 4. Tack Seconds - Field ID 103
                mLapTackSecField = mSession.createField(
                    "tackSec",
                    103,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 5. Tack Meters - Field ID 104
                mLapTackMtrField = mSession.createField(
                    "tackMtr",
                    104,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 6. Avg Tack Angle - Field ID 105
                mLapAvgTackAngleField = mSession.createField(
                    "tackAng",
                    105,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 7. Wind Direction - Field ID 106
                mLapWindDirectionField = mSession.createField(
                    "windDir",
                    106,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 8. Wind Strength - Field ID 107
                mLapWindStrengthField = mSession.createField(
                    "windStr",
                    107,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 9. Avg Gybe Angle - Field ID 108
                mLapAvgGybeAngleField = mSession.createField(
                    "gybeAng",
                    108,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );

                // 10. Tack Count - Field ID 109
                mLapTackCountField = mSession.createField(
                    "tackCount",
                    109,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );

                // 11. Gybe Count - Field ID 110
                mLapGybeCountField = mSession.createField(
                    "gybeCount",
                    110,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 12. Percent Upwind - Field ID 111
                mLapPctUpwindField = mSession.createField(
                    "pctUpwind",
                    111,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 13. Percent Downwind - Field ID 112
                mLapPctDownwindField = mSession.createField(
                    "pctDownwind",
                    112,
                    FitContributor.DATA_TYPE_UINT8,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // 14. Average Wind Angle - Field ID 113
                mLapAvgWindAngleField = mSession.createField(
                    "avgWindAng",
                    113,
                    FitContributor.DATA_TYPE_UINT16,
                    { :mesgType => FitContributor.MESG_TYPE_LAP }
                );
                
                // CHANGE 1: Remove avgSpeed and maxSpeed fields (ID 114 and 115)
                
            } catch (e) {
                // Silent error handling
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

    // In FoilTrackerApp.mc
    // Update processData with simplified wind logic and reduced logging
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
                
                // New metrics
                var pctUpwind = 0;
                var pctDownwind = 0;
                var avgWindAngle = 0;
                
                // Get data from model
                if (data.hasKey("percentOnFoil")) {
                    pctOnFoil = data["percentOnFoil"].toNumber();
                }
                
                // SIMPLIFIED: Wind strength from index
                if (data.hasKey("windStrengthIndex")) {
                    var windIndex = data["windStrengthIndex"];
                    windStr = 7 + (windIndex * 3);
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
                        
                        // Get new metrics
                        if (lapData.hasKey("pctUpwind")) {
                            pctUpwind = lapData["pctUpwind"];
                        }
                        if (lapData.hasKey("pctDownwind")) {
                            pctDownwind = lapData["pctDownwind"];
                        }
                        if (lapData.hasKey("avgWindAngle")) {
                            avgWindAngle = lapData["avgWindAngle"];
                        }
                    }
                }
                
                // Update the lap fields with current values
                updateLapFields(pctOnFoil, vmgUp, vmgDown, tackSec, tackMtr, tackAng, gybeAng, avgWindDir, windStr, 
                            tackCount, gybeCount, pctUpwind, pctDownwind, avgWindAngle);
                
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