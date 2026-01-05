package WorkplaceRoboticsSafety {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    doc /* 
     * This model describes a workplace robotics safety system designed to protect
     * human workers in collaborative industrial environments. The system's primary
     * function is to continuously monitor the workspace around industrial robots,
     * detect human presence and proximity, assess collision risks in real-time,
     * and automatically control robot behavior to prevent accidents. It employs
     * multiple sensor types for redundant detection, processes safety-critical
     * data through a certified controller, and enforces graduated responses
     * ranging from speed reduction to emergency stops based on proximity zones.
     */
    
    attribute def DistanceValue :> LengthValue;
    attribute def VelocityValue :> SpeedValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def ReactionTimeValue :> TimeValue;
    
    enum def SafetyZone {
        collaborative;
        warning;
        restricted;
        prohibited;
    }
    
    enum def OperationalMode {
        fullSpeed;
        reducedSpeed;
        handGuiding;
        safeguardedStop;
        emergencyStop;
    }
    
    enum def HazardSeverity {
        none;
        minimal;
        moderate;
        severe;
        critical;
    }
    
    item def Worker {
        attribute position : DistanceValue[3];
        attribute velocity : VelocityValue;
        attribute isDetected : Boolean;
    }
    
    item def SafetyEvent {
        attribute timestamp : TimeValue;
        attribute severity : HazardSeverity;
        attribute zone : SafetyZone;
    }
    
    attribute def SafetyParameters {
        attribute collaborativeZoneRadius : DistanceValue = 3.5 [m];
        attribute warningZoneRadius : DistanceValue = 2.0 [m];
        attribute restrictedZoneRadius : DistanceValue = 1.0 [m];
        attribute prohibitedZoneRadius : DistanceValue = 0.5 [m];
        attribute maxCollaborativeSpeed : VelocityValue = 0.25 [m/s];
        attribute maxWarningSpeed : VelocityValue = 0.5 [m/s];
        attribute maxContactForce : ForceValue = 150.0 [N];
        attribute systemReactionTime : ReactionTimeValue = 0.08 [s];
    }
    
    port def SensorDataPort {
        out detectionData : Real[*];
        out confidence : Real;
    }
    
    port def ControlCommandPort {
        in mode : OperationalMode;
        in velocityLimit : VelocityValue;
    }
    
    port def StatusPort {
        out currentMode : OperationalMode;
        out currentVelocity : VelocityValue;
        out currentForce : ForceValue;
    }
    
    port def EmergencyPort {
        in stopSignal : Boolean;
        out stopAcknowledge : Boolean;
    }
    
    part def LaserScanner {
        attribute scanRange : DistanceValue = 10.0 [m];
        attribute scanFrequency : Real = 40.0;
        attribute angularResolution : Real = 0.25;
        port scanOutput : SensorDataPort;
    }
    
    part def VisionCamera {
        attribute fieldOfView : Real = 110.0;
        attribute frameRate : Real = 60.0;
        attribute resolution : Integer[2] = (1920, 1080);
        port visionOutput : SensorDataPort;
    }
    
    part def ProximitySensor {
        attribute detectionRange : DistanceValue = 5.0 [m];
        attribute responseTime : ReactionTimeValue = 0.02 [s];
        port proximityOutput : SensorDataPort;
    }
    
    part def ForceTorqueSensor {
        attribute forceRange : ForceValue = 500.0 [N];
        attribute torqueRange : Real = 100.0;
        attribute sensitivity : Real = 0.1;
        port forceOutput : SensorDataPort;
    }
    
    part def SafetyPLC {
        attribute safetyIntegrityLevel : Integer = 3;
        attribute cycleTime : ReactionTimeValue = 0.01 [s];
        attribute redundantChannels : Integer = 2;
        port sensorInputs : SensorDataPort[*];
        port robotControl : ControlCommandPort;
        port emergencyControl : EmergencyPort;
        port systemStatus : StatusPort;
    }
    
    part def CollaborativeRobot {
        attribute maxReach : DistanceValue = 1.3 [m];
        attribute payload : Real = 10.0;
        attribute jointCount : Integer = 6;
        attribute nominalSpeed : VelocityValue = 1.0 [m/s];
        attribute currentSpeed : VelocityValue = 0.0 [m/s];
        attribute currentForce : ForceValue = 0.0 [N];
        attribute operatingMode : OperationalMode = OperationalMode::safeguardedStop;
        
        port controlInput : ControlCommandPort;
        port statusOutput : StatusPort;
        port emergencyInput : EmergencyPort;
        
        part manipulator {
            attribute linkLengths : DistanceValue[6];
            attribute jointLimits : Real[6];
        }
        
        part endEffector {
            attribute graspForce : ForceValue = 80.0 [N];
            attribute toolWeight : Real = 1.5;
        }
    }
    
    action def ScanEnvironment {
        in scanData : Real[*];
        in visionData : Real[*];
        in proximityData : Real[*];
        out detectedWorkers : Integer;
        out minimumDistance : DistanceValue;
        out workerPositions : DistanceValue[*];
    }
    
    action def ClassifyZone {
        in distance : DistanceValue;
        in safetyParams : SafetyParameters;
        out zone : SafetyZone;
    }
    
    action def AssessRisk {
        in zone : SafetyZone;
        in robotVelocity : VelocityValue;
        in robotForce : ForceValue;
        in workerVelocity : VelocityValue;
        out severity : HazardSeverity;
    }
    
    action def DetermineMode {
        in severity : HazardSeverity;
        in zone : SafetyZone;
        out mode : OperationalMode;
        out velocityLimit : VelocityValue;
    }
    
    action def ExecuteStop {
        in stopType : OperationalMode;
        out brakingTime : ReactionTimeValue;
        out stopComplete : Boolean;
    }
    
    action def LogEvent {
        in event : SafetyEvent;
        out logged : Boolean;
    }
    
    state def RobotSafetyBehavior {
        entry; then normalOperation;
        
        state normalOperation {
            entry assign operatingMode = OperationalMode::fullSpeed;
        }
        
        state collaborativeMode {
            entry assign operatingMode = OperationalMode::reducedSpeed;
        }
        
        state warningMode {
            entry assign operatingMode = OperationalMode::reducedSpeed;
        }
        
        state protectiveStop {
            entry assign operatingMode = OperationalMode::safeguardedStop;
        }
        
        state emergencyMode {
            entry assign operatingMode = OperationalMode::emergencyStop;
        }
        
        transition normal_to_collaborative
            first normalOperation
            accept zoneChange : SafetyZone
            if zoneChange == SafetyZone::collaborative
            then collaborativeMode;
        
        transition collaborative_to_warning
            first collaborativeMode
            accept zoneChange : SafetyZone
            if zoneChange == SafetyZone::warning
            then warningMode;
        
        transition warning_to_protective
            first warningMode
            accept zoneChange : SafetyZone
            if zoneChange == SafetyZone::restricted
            then protectiveStop;
        
        transition any_to_emergency
            first normalOperation
            accept zoneChange : SafetyZone
            if zoneChange == SafetyZone::prohibited
            then emergencyMode;
        
        transition protective_to_warning
            first protectiveStop
            accept zoneCleared : SafetyZone
            if zoneCleared == SafetyZone::warning
            then warningMode;
        
        transition warning_to_collaborative
            first warningMode
            accept zoneCleared : SafetyZone
            if zoneCleared == SafetyZone::collaborative
            then collaborativeMode;
        
        transition collaborative_to_normal
            first collaborativeMode
            accept zoneCleared : SafetyZone
            if zoneCleared == SafetyZone::collaborative
            then normalOperation;
        
        transition emergency_to_protective
            first emergencyMode
            accept systemReset : Boolean
            if systemReset == true
            then protectiveStop;
    }
    
    action def SafetyControlCycle {
        first start;
        then merge continuousLoop;
        
        then action scan : ScanEnvironment {
            out detectedWorkers : Integer;
            out minimumDistance : DistanceValue;
        }
        
        then action classify : ClassifyZone {
            in distance = scan.minimumDistance;
            out zone : SafetyZone;
        }
        
        then action assess : AssessRisk {
            in zone = classify.zone;
            out severity : HazardSeverity;
        }
        
        then decide;
            if assess.severity == HazardSeverity::critical then emergencyAction;
            if assess.severity == HazardSeverity::severe then stopAction;
            if assess.severity == HazardSeverity::moderate then slowAction;
            if assess.severity == HazardSeverity::minimal then collaborativeAction;
            if assess.severity == HazardSeverity::none then normalAction;
        
        action emergencyAction : ExecuteStop {
            in stopType = OperationalMode::emergencyStop;
        }
        then action logEmergency : LogEvent;
        then continuousLoop;
        
        action stopAction : ExecuteStop {
            in stopType = OperationalMode::safeguardedStop;
        }
        then action logStop : LogEvent;
        then continuousLoop;
        
        action slowAction : DetermineMode {
            in severity = assess.severity;
            in zone = classify.zone;
        }
        then action logSlow : LogEvent;
        then continuousLoop;
        
        action collaborativeAction : DetermineMode {
            in severity = assess.severity;
            in zone = classify.zone;
        }
        then continuousLoop;
        
        action normalAction : DetermineMode {
            in severity = assess.severity;
            in zone = classify.zone;
        }
        then continuousLoop;
    }
    
    part workplaceSafetySystem {
        doc /* 
         * Integrated workplace robotics safety system providing comprehensive
         * protection for human workers through multi-sensor monitoring, real-time
         * risk assessment, and automated robot control with graduated safety responses.
         */
        
        attribute safetyParams : SafetyParameters;
        attribute totalSystemReactionTime : ReactionTimeValue = 0.15 [s];
        attribute minimumSafeSeparation : DistanceValue = 0.5 [m];
        
        part robot : CollaborativeRobot {
            attribute :>> maxReach = 1.3 [m];
            attribute :>> nominalSpeed = 1.0 [m/s];
            
            part :>> manipulator {
                attribute :>> linkLengths = (0.2, 0.3, 0.25, 0.2, 0.15, 0.1) [m];
            }
            
            part :>> endEffector {
                attribute :>> graspForce = 80.0 [N];
            }
        }
        
        part safetyController : SafetyPLC {
            attribute :>> safetyIntegrityLevel = 3;
            attribute :>> cycleTime = 0.01 [s];
            
            perform action safetyControl : SafetyControlCycle;
            exhibit state robotBehavior : RobotSafetyBehavior;
        }
        
        part laserScanners : LaserScanner[4] {
            attribute :>> scanRange = 10.0 [m];
            attribute :>> scanFrequency = 40.0;
        }
        
        part visionSystem : VisionCamera[2] {
            attribute :>> fieldOfView = 110.0;
            attribute :>> frameRate = 60.0;
        }
        
        part proximitySensors : ProximitySensor[8] {
            attribute :>> detectionRange = 5.0 [m];
        }
        
        part forceSensor : ForceTorqueSensor {
            attribute :>> forceRange = 500.0 [N];
        }
        
        connection laserToController1 connect 
            laserScanners[1].scanOutput to safetyController.sensorInputs[1];
        
        connection laserToController2 connect 
            laserScanners[2].scanOutput to safetyController.sensorInputs[2];
        
        connection laserToController3 connect 
            laserScanners[3].scanOutput to safetyController.sensorInputs[3];
        
        connection laserToController4 connect 
            laserScanners[4].scanOutput to safetyController.sensorInputs[4];
        
        connection visionToController1 connect 
            visionSystem[1].visionOutput to safetyController.sensorInputs[5];
        
        connection visionToController2 connect 
            visionSystem[2].visionOutput to safetyController.sensorInputs[6];
        
        connection proximityToController1 connect 
            proximitySensors[1].proximityOutput to safetyController.sensorInputs[7];
        
        connection forceToController connect 
            forceSensor.forceOutput to safetyController.sensorInputs[8];
        
        connection controlToRobot connect 
            safetyController.robotControl to robot.controlInput;
        
        connection robotStatus connect 
            robot.statusOutput to safetyController.systemStatus;
        
        connection emergencyLink connect 
            safetyController.emergencyControl to robot.emergencyInput;
        
        assert constraint reactionTimeLimit {
            totalSystemReactionTime <= 0.2 [s]
        }
        
        assert constraint separationDistance {
            minimumSafeSeparation >= 0.5 [m]
        }
    }
    
    requirement <'REQ-WRS-100'> primarySafetyMission {
        doc /* 
         * The workplace robotics safety system shall protect human workers by
         * continuously monitoring the collaborative workspace, detecting human
         * presence, assessing collision risks, and automatically controlling
         * robot operation to prevent accidents and injuries.
         */
        subject system :> workplaceSafetySystem;
    }
    
    requirement <'REQ-WRS-101'> multiSensorDetection {
        doc /* 
         * The system shall employ redundant sensing technologies including
         * laser scanners, vision cameras, and proximity sensors to ensure
         * reliable human detection with minimum 10 meter range.
         */
        subject system :> workplaceSafetySystem;
        require constraint {
            system.laserScanners.scanRange >= 10.0 [m] and
            system.proximitySensors.detectionRange >= 5.0 [m]
        }
    }
    
    requirement <'REQ-WRS-102'> zonedSafetyResponse {
        doc /* 
         * The system shall implement graduated safety zones with appropriate
         * responses: collaborative (3.5m), warning (2.0m), restricted (1.0m),
         * and prohibited (0.5m) zones.
         */
        subject params :> workplaceSafetySystem.safetyParams;
        require constraint {
            params.collaborativeZoneRadius >= 3.5 [m] and
            params.warningZoneRadius >= 2.0 [m] and
            params.restrictedZoneRadius >= 1.0 [m] and
            params.prohibitedZoneRadius >= 0.5 [m]
        }
    }
    
    requirement <'REQ-WRS-103'> systemReactionTime {
        doc /* 
         * The total system reaction time from detection to robot response
         * shall not exceed 200 milliseconds.
         */
        subject system :> workplaceSafetySystem;
        require constraint {
            system.totalSystemReactionTime <= 0.2 [s]
        }
    }
    
    requirement <'REQ-WRS-104'> velocityLimitation {
        doc /* 
         * Robot velocity shall be limited based on proximity: 0.25 m/s in
         * collaborative zone, 0.5 m/s in warning zone, stopped in restricted zone.
         */
        subject params :> workplaceSafetySystem.safetyParams;
        require constraint {
            params.maxCollaborativeSpeed <= 0.25 [m/s] and
            params.maxWarningSpeed <= 0.5 [m/s]
        }
    }
    
    requirement <'REQ-WRS-105'> forceControl {
        doc /* 
         * Maximum contact force between robot and human shall not exceed
         * 150 Newtons to prevent injury.
         */
        subject params :> workplaceSafetySystem.safetyParams;
        require constraint {
            params.maxContactForce <= 150.0 [N]
        }
    }
    
    requirement <'REQ-WRS-106'> emergencyStopCapability {
        doc /* 
         * The system shall execute emergency stop within prohibited zone
         * detection with immediate halt of all robot motion.
         */
        subject controller :> workplaceSafetySystem.safetyController;
    }
    
    requirement <'REQ-WRS-107'> safetyIntegrity {
        doc /* 
         * Safety controller shall meet SIL 3 (Safety Integrity Level 3)
         * certification with redundant processing channels.
         */
        subject controller :> workplaceSafetySystem.safetyController;
        require constraint {
            controller.safetyIntegrityLevel >= 3 and
            controller.redundantChannels >= 2
        }
    }
    
    satisfy primarySafetyMission by workplaceSafetySystem;
    satisfy multiSensorDetection by workplaceSafetySystem.laserScanners;
    satisfy multiSensorDetection by workplaceSafetySystem.visionSystem;
    satisfy multiSensorDetection by workplaceSafetySystem.proximitySensors;
    satisfy zonedSafetyResponse by workplaceSafetySystem.safetyController;
    satisfy systemReactionTime by workplaceSafetySystem.safetyController;
    satisfy velocityLimitation by workplaceSafetySystem.safetyController;
    satisfy forceControl by workplaceSafetySystem.forceSensor;
    satisfy emergencyStopCapability by workplaceSafetySystem.safetyController;
    satisfy safetyIntegrity by workplaceSafetySystem.safetyController;
}
