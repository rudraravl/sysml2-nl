package AutonomousMilitaryRobot {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value type Distance :> Real { unit 'm'; }
    value type Speed :> Real { unit 'm/s'; }
    value type Mass :> Real { unit 'kg'; }
    value type Power :> Real {> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type DataRate :> Real { unit 'bit/s'; }
    value type Temperature :> Real { unit 'K'; }
    value type Angle :> Real { unit 'rad'; }
    value type AmmunitionCount :> Integer;
    value type ConfidenceLevel :> Real { min 0.0; max 1.0; }
    value type GPSAccuracy :> Real { unit 'm'; }
    value type EncryptionStrength :> Integer;
    
    // ===== Enumerations =====
    
    enum ThreatType { personnel, lightVehicle, armoredVehicle, unknown }
    enum MissionPhase { idle, navigating, scanning, engaging, transmitting, returning, standby }
    enum WeaponStatus { safe, armed, firing, jammed, empty }
    enum TerrainType { flat, rough, urban, forest, desert, mud, waterCrossing }
    enum CommLinkState { disconnected, connecting, connected, authenticated, transmitting }
    enum NavigationMode { manual, autonomous, waypointFollow, returnToBase, holdPosition }
    enum SensorMode { standby, activeScan, targetTrack, classificationMode }
    enum EngagementDecision { holdFire, trackOnly, engage, disengage, requestAuthorization }
    
    // ===== Item Definitions =====
    
    item def SensorData {
        attribute timestamp : Time;
        attribute sensorId : String;
        attribute rangeReading : Distance;
        attribute bearing : Angle;
        attribute confidence : ConfidenceLevel;
    }
    
    item def OpticalImageData :> SensorData {
        attribute resolution : Integer;
        attribute frameRate : Frequency;
        attribute imagePayload : String;
    }
    
    item def ThermalImageData :> SensorData {
        attribute temperatureReading : Temperature;
        attribute heatSignatureStrength : Real;
        attribute imagePayload : String;
    }
    
    item def RadarData :> SensorData {
        attribute dopplerShift : Frequency;
        attribute targetVelocity : Speed;
        attribute rangeResolution : Distance;
    }
    
    item def ThreatReport {
        attribute threatId : String;
        attribute threatType : ThreatType;
        attribute location_lat : Real;
        attribute location_lon : Real;
        attribute distance : Distance;
        attribute bearing : Angle;
        attribute confidence : ConfidenceLevel;
        attribute detectedAt : Time;
    }
    
    item def MissionOrder {
        attribute missionId : String;
        attribute waypoints : OrderedSet[+] of Waypoint;
        attribute rulesOfEngagement : String;
        attribute priority : Integer;
        attribute issuedAt : Time;
    }
    
    item def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Distance;
        attribute arrivalRadius : Distance;
        attribute sequence : Integer;
    }
    
    item def TelemetryPacket {
        attribute robotId : String;
        attribute currentLat : Real;
        attribute currentLon : Real;
        attribute batteryLevel : Percent;
        attribute currentSpeed : Speed;
        attribute heading : Angle;
        attribute missionPhase : MissionPhase;
        attribute timestamp : Time;
    }
    
    item def CommandPacket {
        attribute commandId : String;
        attribute commandType : String;
        attribute parameters : String;
        attribute authorizationCode : String;
        attribute timestamp : Time;
    }
    
    item def EngagementReport {
        attribute threatId : String;
        attribute roundsFired : Integer;
        attribute engagementDuration : Time;
        attribute outcome : String;
        attribute timestamp : Time;
    }
    
    item def BatteryStatus {
        attribute stateOfCharge : Percent;
        attribute voltage : Voltage;
        attribute currentDraw : Current;
        attribute temperature : Temperature;
        attribute estimatedRemaining : Time;
    }
    
    item def NavigationFix {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Distance;
        attribute accuracy : GPSAccuracy;
        attribute heading : Angle;
        attribute groundSpeed : Speed;
        attribute timestamp : Time;
        attribute satellitesUsed : Integer;
    }
    
    item def WeaponCommand {
        attribute commandType : String;
        attribute targetBearing : Angle;
        attribute targetElevation : Angle;
        attribute burstCount : Integer;
        attribute authorizationCode : String;
    }
    
    item def DriveCommand {
        attribute linearVelocity : Speed;
        attribute angularVelocity : Real;
        attribute brakeApplied : Boolean;
    }
    
    // ===== Port Definitions =====
    
    port def SensorDataPort {
        out sensorData : SensorData;
    }
    
    port def OpticalDataPort {
        out opticalData : OpticalImageData;
    }
    
    port def ThermalDataPort {
        out thermalData : ThermalImageData;
    }
    
    port def RadarDataPort {
        out radarData : RadarData;
    }
    
    port def ThreatReportPort {
        out threatReport : ThreatReport;
    }
    
    port def MissionOrderPort {
        in missionOrder : MissionOrder;
    }
    
    port def TelemetryPort {
        out telemetry : TelemetryPacket;
    }
    
    port def CommandPort {
        in command : CommandPacket;
    }
    
    port def NavigationFixPort {
        out navFix : NavigationFix;
    }
    
    port def DriveCommandPort {
        out driveCmd : DriveCommand;
    }
    
    port def WeaponCommandPort {
        out weaponCmd : WeaponCommand;
    }
    
    port def EngagementReportPort {
        out engagementReport : EngagementReport;
    }
    
    port def BatteryStatusPort {
        out batteryStatus : BatteryStatus;
    }
    
    port def PowerOutputPort {
        out power : Power;
    }
    
    port def PowerInputPort {
        in power : Power;
    }
    
    // ===== Part Definitions: Subsystems =====
    
    part def BatterySystem {
        attribute capacity : Power = 5000 [W];
        attribute maxVoltage : Voltage = 48 [V];
        attribute maxCurrent : Current = 120 [A];
        attribute currentCharge : Percent = 100.0;
        
        port powerOutput : PowerOutputPort;
        port batteryStatusOut : BatteryStatusPort;
        
        action def discharge :> Action {
            in load : Power;
            out status : BatteryStatus;
        }
        
        action def monitorCharge :> Action {
            out status : BatteryStatus;
        }
        
        execute monitorCharge;
    }
    
    part def MobilityPlatform {
        attribute maxSpeed : Speed = 8.0 [m/s];
        attribute mass : Mass = 350 [kg];
        attribute groundClearance : Distance = 0.35 [m];
        attribute wheelCount : Integer = 6;
        attribute currentTerrain : TerrainType;
        
        port driveCommandIn : DriveCommandPort;
        port powerInput : PowerInputPort;
        
        action def traverse :> Action {
            in command : DriveCommand;
            in terrain : TerrainType;
            out actualSpeed : Speed;
            out actualHeading : Angle;
        }
        
        action def adaptTerrain :> Action {
            in terrain : TerrainType;
            out adjustedSpeed : Speed;
        }
        
        execute traverse;
    }
    
    part def OpticalCamera {
        attribute resolution : Integer = 3840;
        attribute frameRate : Frequency = 60 [Hz];
        attribute fieldOfView : Angle = 1.047 [rad];
        attribute detectionRange : Distance = 2000 [m];
        attribute mode : SensorMode = SensorMode::standby;
        
        port opticalDataOut : OpticalDataPort;
        port powerInput : PowerInputPort;
        
        action def captureImage :> Action {
            out data : OpticalImageData;
        }
        
        execute captureImage;
    }
    
    part def ThermalSensor {
        attribute resolution : Integer = 640;
        attribute frameRate : Frequency = 30 [Hz];
        attribute fieldOfView : Angle = 0.873 [rad];
        attribute detectionRange : Distance = 1500 [m];
        attribute temperatureSensitivity : Temperature = 0.05 [K];
        attribute mode : SensorMode = SensorMode::standby;
        
        port thermalDataOut : ThermalDataPort;
        port powerInput : PowerInputPort;
        
        action def captureThermal :> Action {
            out data : ThermalImageData;
        }
        
        execute captureThermal;
    }
    
    part def RadarSystem {
        attribute frequency : Frequency = 77000000000 [Hz];
        attribute maxRange : Distance = 5000 [m];
        attribute rangeResolution : Distance = 0.5 [m];
        attribute fieldOfView : Angle = 3.141 [rad];
        attribute mode : SensorMode = SensorMode::standby;
        
        port radarDataOut : RadarDataPort;
        port powerInput : PowerInputPort;
        
        action def scanArea :> Action {
            out data : RadarData;
        }
        
        action def trackTarget :> Action {
            in bearing : Angle;
            out data : RadarData;
        }
        
        execute scanArea;
    }
    
    part def WeaponSystem {
        attribute maxAmmunition : AmmunitionCount = 1000;
        attribute remainingAmmunition : AmmunitionCount = 1000;
        attribute rateOfFire : Frequency = 10 [Hz];
        attribute maxEffectiveRange : Distance = 800 [m];
        attribute status : WeaponStatus = WeaponStatus::safe;
        
        port weaponCommandIn : WeaponCommandPort;
        port engagementReportOut : EngagementReportPort;
        port powerInput : PowerInputPort;
        
        action def arm :> Action {
            out weaponStatus : WeaponStatus;
        }
        
        action def fire :> Action {
            in burstCount : Integer;
            out roundsFired : Integer;
            out report : EngagementReport;
        }
        
        action def reload :> Action {
            out newCount : AmmunitionCount;
        }
        
        action def clearJam :> Action {
            out weaponStatus : WeaponStatus;
        }
        
        state def WeaponStateMachine {
            entry; then Safe;
            
            state Safe {
                entry; then done;
            }
            
            transition from Safe to Armed
                when weaponCommandIn.weaponCmd.commandType == "arm"
                if weaponCommandIn.weaponCmd.authorizationCode != "";
            
            state Armed {
                entry; then done;
            }
            
            transition from Armed to Firing
                when weaponCommandIn.weaponCmd.commandType == "fire"
                if remainingAmmunition > 0;
            
            state Firing {
                entry; then done;
            }
            
            transition from Firing to Armed
                when weaponCommandIn.weaponCmd.commandType == "ceasefire";
            
            transition from Armed to Safe
                when weaponCommandIn.weaponCmd.commandType == "safe";
            
            transition from Firing to Jammed
                if status == WeaponStatus::jammed;
            
            state Jammed {
                entry; then done;
            }
            
            transition from Jammed to Safe
                when weaponCommandIn.weaponCmd.commandType == "clearjam";
            
            transition from Armed to Empty
                if remainingAmmunition == 0;
            
            state Empty {
                entry; then done;
            }
        }
        
        exhibit WeaponStateMachine;
    }
    
    part def CommunicationSystem {
        attribute maxRange : Distance = 30000 [m];
        attribute dataRate : DataRate = 2000000 [bit/s];
        attribute encryptionStrength : EncryptionStrength = 256;
        attribute frequencyBand : Frequency = 2400000000 [Hz];
        attribute linkState : CommLinkState = CommLinkState::disconnected;
        
        port telemetryOut : TelemetryPort;
        port commandIn : CommandPort;
        port powerInput : PowerInputPort;
        
        action def establishLink :> Action {
            out state : CommLinkState;
        }
        
        action def encryptData :> Action {
            in data : TelemetryPacket;
            out encrypted : String;
        }
        
        action def decryptCommand :> Action {
            in encrypted : String;
            out command : CommandPacket;
        }
        
        action def transmitTelemetry :> Action {
            in telemetry : TelemetryPacket;
        }
        
        action def receiveCommand :> Action {
            out command : CommandPacket;
        }
        
        state def CommLinkStateMachine {
            entry; then Disconnected;
            
            state Disconnected {
                entry; then done;
            }
            
            transition from Disconnected to Connecting
                when true;
            
            state Connecting {
                entry; then done;
            }
            
            transition from Connecting to Connected
                when true;
            
            state Connected {
                entry; then done;
            }
            
            transition from Connected to Authenticated
                when true;
            
            state Authenticated {
                entry; then done;
            }
            
            transition from Authenticated to Transmitting
                when true;
            
            state Transmitting {
                entry; then done;
            }
            
            transition from Transmitting to Authenticated
                when true;
            
            transition from Authenticated to Disconnected
                when false;
        }
        
        exhibit CommLinkStateMachine;
    }
    
    part def NavigationSystem {
        attribute gpsAccuracy : GPSAccuracy = 0.5 [m];
        attribute imuUpdateRate : Frequency = 200 [Hz];
        attribute waypointTolerance : Distance = 2.0 [m];
        attribute navigationMode : NavigationMode = NavigationMode::holdPosition;
        
        port navFixOut : NavigationFixPort;
        port powerInput : PowerInputPort;
        
        action def computePosition :> Action {
            out fix : NavigationFix;
        }
        
        action def planPath :> Action {
            in destination : Waypoint;
            in currentFix : NavigationFix;
            out driveCmd : DriveCommand;
        }
        
        action def followWaypoints :> Action {
            in waypoints : OrderedSet[+] of Waypoint;
            in currentFix : NavigationFix;
            out driveCmd : DriveCommand;
        }
        
        action def returnToBase :> Action {
            in baseLocation : Waypoint;
            in currentFix : NavigationFix;
            out driveCmd : DriveCommand;
        }
        
        execute computePosition;
    }
    
    part def MissionController {
        attribute robotId : String = "AMGR-001";
        attribute currentPhase : MissionPhase = MissionPhase::idle;
        attribute rulesOfEngagement : String;
        attribute currentMission : MissionOrder;
        attribute threatDatabase : OrderedSet[+] of ThreatReport;
        attribute engagementDecision : EngagementDecision = EngagementDecision::holdFire;
        attribute targetClassificationThreshold : ConfidenceLevel = 0.85;
        
        port opticalDataIn : OpticalDataPort;
        port thermalDataIn : ThermalDataPort;
        port radarDataIn : RadarDataPort;
        port navFixIn : NavigationFixPort;
        port driveCommandOut : DriveCommandPort;
        port weaponCommandOut : WeaponCommandPort;
        port telemetryOut : TelemetryPort;
        port missionOrderIn : MissionOrderPort;
        port engagementReportIn : EngagementReportPort;
        port batteryStatusIn : BatteryStatusPort;
        
        action def fuseSensorData :> Action {
            in optical : OpticalImageData;
            in thermal : ThermalImageData;
            in radar : RadarData;
            out threat : ThreatReport;
        }
        
        action def classifyThreat :> Action {
            in fusedData : SensorData;
            out threatType : ThreatType;
            out confidence : ConfidenceLevel;
        }
        
        action def evaluateEngagement :> Action {
            in threat : ThreatReport;
            out decision : EngagementDecision;
        }
        
        action def generateDriveCommand :> Action {
            in navFix : NavigationFix;
            in targetWaypoint : Waypoint;
            out driveCmd : DriveCommand;
        }
        
        action def generateWeaponCommand :> Action {
            in threat : ThreatReport;
            out weaponCmd : WeaponCommand;
        }
        
        action def compileTelemetry :> Action {
            in navFix : NavigationFix;
            in batteryStatus : BatteryStatus;
            out telemetry : TelemetryPacket;
        }
        
        action def processCommand :> Action {
            in command : CommandPacket;
            out updatedMission : MissionOrder;
        }
        
        state def MissionStateMachine {
            entry; then Idle;
            
            state Idle {
                entry; then done;
            }
            
            transition from Idle to Navigating
                when missionOrderIn.missionOrder != null;
            
            state Navigating {
                entry; then done;
            }
            
            transition from Navigating to Scanning
                when navFixIn.navFix.accuracy <= 2.0 [m];
            
            state Scanning {
                entry; then done;
            }
            
            transition from Scanning to Engaging
                when threatDatabase.size > 0
                if engagementDecision == EngagementDecision::engage;
            
            transition from Scanning to Transmitting
                when threatDatabase.size > 0
                if engagementDecision == EngagementDecision::trackOnly;
            
            state Engaging {
                entry; then done;
            }
            
            transition from Engaging to Transmitting
                when engagementReportIn.engagementReport != null;
            
            state Transmitting {
                entry; then done;
            }
            
            transition from Transmitting to Navigating
                when telemetryOut.telemetry != null
                if currentPhase != MissionPhase::returning;
            
            transition from Transmitting to Returning
                when telemetryOut.telemetry != null
                if currentPhase == MissionPhase::returning;
            
            state Returning {
                entry; then done;
            }
            
            transition from Returning to Idle
                when navFixIn.navFix.accuracy <= 2.0 [m];
            
            transition from Navigating to Returning
                when batteryStatusIn.batteryStatus.stateOfCharge < 20.0;
            
            transition from Scanning to Returning
                when batteryStatusIn.batteryStatus.stateOfCharge < 20.0;
        }
        
        exhibit MissionStateMachine;
        
        execute fuseSensorData;
        execute classifyThreat;
        execute evaluateEngagement;
        execute generateDriveCommand;
        execute generateWeaponCommand;
        execute compileTelemetry;
    }
    
    // ===== Top-Level System =====
    
    part def AutonomousGroundRobot {
        attribute systemName : String = "Reconnaissance Combat Robot RCV-7";
        attribute systemMass : Mass = 450 [kg];
        attribute operationalRange : Distance = 50000 [m];
        attribute endurance : Time = 43200 [s];
        
        part battery : BatterySystem;
        part mobility : MobilityPlatform;
        part opticalCamera : OpticalCamera;
        part thermalSensor : ThermalSensor;
        part radar : RadarSystem;
        part weapon : WeaponSystem;
        part comm : CommunicationSystem;
        part navigation : NavigationSystem;
        part controller : MissionController;
        
        // Power distribution connections
        connection battery.powerOutput to mobility.powerInput;
        connection battery.powerOutput to opticalCamera.powerInput;
        connection battery.powerOutput to thermalSensor.powerInput;
        connection battery.powerOutput to radar.powerInput;
        connection battery.powerOutput to weapon.powerInput;
        connection battery.powerOutput to comm.powerInput;
        connection battery.powerOutput to navigation.powerInput;
        connection battery.powerOutput to controller.batteryStatusIn;
        
        // Sensor data connections to controller
        connection opticalCamera.opticalDataOut to controller.opticalDataIn;
        connection thermalSensor.thermalDataOut to controller.thermalDataIn;
        connection radar.radarDataOut to controller.radarDataIn;
        
        // Navigation connections
        connection navigation.navFixOut to controller.navFixIn;
        connection controller.driveCommandOut to mobility.driveCommandIn;
        
        // Weapon connections
        connection controller.weaponCommandOut to weapon.weaponCommandIn;
        connection weapon.engagementReportOut to controller.engagementReportIn;
        
        // Communication connections
        connection controller.telemetryOut to comm.telemetryOut;
        connection comm.commandIn to controller.missionOrderIn;
        
        // Battery status to controller
        connection battery.batteryStatusOut to controller.batteryStatusIn;
    }
    
    // ===== Requirements =====
    
    requirement def ReconnaissanceRequirement {
        doc /* The robot shall detect and classify threats at extended ranges using a multi-sensor suite. */
        attribute detectionRange : Distance = 2000 [m];
        attribute classificationAccuracy : ConfidenceLevel = 0.85;
        subject robot : AutonomousGroundRobot;
        
        require robot.opticalCamera.detectionRange >= detectionRange;
        require robot.thermalSensor.detectionRange >= 1500 [m];
        require robot.radar.maxRange >= 5000 [m];
    }
    
    requirement def CombatEngagementRequirement {
        doc /* The robot shall engage identified threats using its integrated weapon system per rules of engagement. */
        attribute maxAmmunition : AmmunitionCount = 1000;
        attribute rateOfFire : Frequency = 10 [Hz];
        attribute maxEffectiveRange : Distance = 800 [m];
        subject robot : AutonomousGroundRobot;
        
        require robot.weapon.maxAmmunition >= maxAmmunition;
        require robot.weapon.rateOfFire >= rateOfFire;
        require robot.weapon.maxEffectiveRange >= maxEffectiveRange;
    }
    
    requirement def CommunicationRequirement {
        doc /* The robot shall maintain secure, long-range communication with the command center. */
        attribute commRange : Distance = 30000 [m];
        attribute encryptionLevel : EncryptionStrength = 256;
        attribute dataRate : DataRate = 2000000 [bit/s];
        subject robot : AutonomousGroundRobot;
        
        require robot.comm.maxRange >= commRange;
        require robot.comm.encryptionStrength >= encryptionLevel;
        require robot.comm.dataRate >= dataRate;
    }
    
    requirement def NavigationRequirement {
        doc /* The robot shall autonomously navigate to designated coordinates with high accuracy. */
        attribute gpsAccuracy : GPSAccuracy = 0.5 [m];
        attribute waypointTolerance : Distance = 2.0 [m];
        subject robot : AutonomousGroundRobot;
        
        require robot.navigation.gpsAccuracy <= gpsAccuracy;
        require robot.navigation.waypointTolerance <= waypointTolerance;
    }
    
    requirement def EnduranceRequirement {
        doc /* The robot shall operate for extended periods without recharging. */
        attribute minEndurance : Time = 43200 [s];
        attribute batteryCapacity : Power = 5000 [W];
        subject robot : AutonomousGroundRobot;
        
        require robot.endurance >= minEndurance;
        require robot.battery.capacity >= batteryCapacity;
    }
    
    requirement def MobilityRequirement {
        doc /* The robot shall traverse all-terrain environments on a robust mobility platform. */
        attribute maxSpeed : Speed = 8.0 [m/s];
        attribute groundClearance : Distance = 0.35 [m];
        subject robot : AutonomousGroundRobot;
        
        require robot.mobility.maxSpeed >= maxSpeed;
        require robot.mobility.groundClearance >= groundClearance;
    }
    
    requirement def MissionControlRequirement {
        doc /* The onboard mission controller shall direct the robot through all operational states. */
        subject robot : AutonomousGroundRobot;
        
        require robot.controller.currentPhase == MissionPhase::idle
            or robot.controller.currentPhase == MissionPhase::navigating
            or robot.controller.currentPhase == MissionPhase::scanning
            or robot.controller.currentPhase == MissionPhase::engaging
            or robot.controller.currentPhase == MissionPhase::transmitting
            or robot.controller.currentPhase == MissionPhase::returning;
    }
    
    requirement def SystemRequirements {
        doc /* Top-level requirements for the autonomous military ground robot. */
        subject robot : AutonomousGroundRobot;
        
        satisfy ReconnaissanceRequirement;
        satisfy CombatEngagementRequirement;
        satisfy CommunicationRequirement;
        satisfy NavigationRequirement;
        satisfy EnduranceRequirement;
        satisfy MobilityRequirement;
        satisfy MissionControlRequirement;
    }
    
    part robot : AutonomousGroundRobot {
        satisfy SystemRequirements;
    }
}
