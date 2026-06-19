package ThymioBasedAutonomousExplorer {
    private import ScalarValues::*;

    attribute def Voltage_V :> Real;
    attribute def Current_A :> Real;
    attribute def Power_W :> Real;
    attribute def Energy_Wh :> Real;
    attribute def Distance_m :> Real;
    attribute def Speed_mps :> Real;
    attribute def AngularSpeed_radps :> Real;
    attribute def Angle_rad :> Real;
    attribute def Time_s :> Real;
    attribute def Frequency_Hz :> Real;
    attribute def Illuminance_lux :> Real;
    attribute def Count :> Integer;

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute availablePower : Power_W;
    }

    item def MotorCommand {
        attribute leftWheelAngularSpeed : AngularSpeed_radps;
        attribute rightWheelAngularSpeed : AngularSpeed_radps;
        attribute commandAge : Time_s;
    }

    item def WheelMotion {
        attribute angularSpeed : AngularSpeed_radps;
        attribute wheelRadius : Distance_m;
        attribute linearSpeed : Speed_mps;
    }

    item def ProximityReport {
        attribute frontLeftRange : Distance_m;
        attribute frontCenterLeftRange : Distance_m;
        attribute frontCenterRange : Distance_m;
        attribute frontCenterRightRange : Distance_m;
        attribute frontRightRange : Distance_m;
        attribute rearLeftRange : Distance_m;
        attribute rearRightRange : Distance_m;
        attribute closestObstacleRange : Distance_m;
    }

    item def GroundReport {
        attribute leftReflectance : Illuminance_lux;
        attribute rightReflectance : Illuminance_lux;
        attribute leftEdgeDetected : Boolean;
        attribute rightEdgeDetected : Boolean;
    }

    item def UserCommand {
        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
        attribute explorationModeRequested : Boolean;
        attribute followModeRequested : Boolean;
    }

    item def StatusIndication {
        attribute ready : Boolean;
        attribute navigating : Boolean;
        attribute avoidingObstacle : Boolean;
        attribute fault : Boolean;
        attribute batteryLow : Boolean;
    }

    item def AudioTone {
        attribute frequency : Frequency_Hz;
        attribute duration : Time_s;
    }

    item def ExplorationMission {
        attribute requestedDuration : Time_s;
        attribute nominalForwardSpeed : Speed_mps;
        attribute minimumClearance : Distance_m;
        attribute tableEdgeAvoidanceEnabled : Boolean;
    }

    item def MissionReport {
        attribute missionCompleted : Boolean;
        attribute stoppedByUser : Boolean;
        attribute stoppedByLowBattery : Boolean;
        attribute collisionAvoided : Boolean;
        attribute elapsedTime : Time_s;
    }

    port def PowerSourcePort {
        out item power : ElectricalPower;
    }

    port def PowerLoadPort {
        in item power : ElectricalPower;
    }

    port def MotorCommandSourcePort {
        out item command : MotorCommand;
    }

    port def MotorCommandSinkPort {
        in item command : MotorCommand;
    }

    port def WheelMotionSourcePort {
        out item motion : WheelMotion;
    }

    port def WheelMotionSinkPort {
        in item motion : WheelMotion;
    }

    port def ProximitySourcePort {
        out item report : ProximityReport;
    }

    port def ProximitySinkPort {
        in item report : ProximityReport;
    }

    port def GroundSourcePort {
        out item report : GroundReport;
    }

    port def GroundSinkPort {
        in item report : GroundReport;
    }

    port def UserCommandSourcePort {
        out item command : UserCommand;
    }

    port def UserCommandSinkPort {
        in item command : UserCommand;
    }

    port def StatusSourcePort {
        out item indication : StatusIndication;
    }

    port def StatusSinkPort {
        in item indication : StatusIndication;
    }

    port def AudioSourcePort {
        out item tone : AudioTone;
    }

    port def AudioSinkPort {
        in item tone : AudioTone;
    }

    port def MissionInputPort {
        in item mission : ExplorationMission;
    }

    port def MissionReportPort {
        out item report : MissionReport;
    }

    action def SenseEnvironment {
        out item proximity : ProximityReport;
        out item ground : GroundReport;
    }

    action def SelectSafeMotion {
        in item mission : ExplorationMission;
        in item proximity : ProximityReport;
        in item ground : GroundReport;
        out item command : MotorCommand;
    }

    action def DriveDifferentialWheels {
        in item command : MotorCommand;
        out item leftMotion : WheelMotion;
        out item rightMotion : WheelMotion;
    }

    action def AnnounceStatus {
        in item status : StatusIndication;
        out item tone : AudioTone;
    }

    action def AutonomousObstacleAvoidingExploration {
        in item mission : ExplorationMission;
        out item report : MissionReport;

        action sense : SenseEnvironment;
        action selectMotion : SelectSafeMotion;
        action drive : DriveDifferentialWheels;
        action announce : AnnounceStatus;

        flow mission to selectMotion.mission;
        flow sense.proximity to selectMotion.proximity;
        flow sense.ground to selectMotion.ground;
        flow selectMotion.command to drive.command;
    }

    state def ThymioOperatingModes {
        entry; then poweredOff;

        state poweredOff;
        state ready;
        state navigating;
        state avoidingObstacle;
        state tableEdgeRecovery;
        state stopped;
        state fault;

        transition powerOn first poweredOff then ready;
        transition startMission first ready then navigating;
        transition obstacleDetected first navigating then avoidingObstacle;
        transition obstacleCleared first avoidingObstacle then navigating;
        transition edgeDetected first navigating then tableEdgeRecovery;
        transition edgeRecovered first tableEdgeRecovery then navigating;
        transition stopRequestedFromReady first ready then stopped;
        transition stopRequestedFromNavigation first navigating then stopped;
        transition stopRequestedFromAvoidance first avoidingObstacle then stopped;
        transition lowBatteryStop first navigating then stopped;
        transition faultDetectedFromReady first ready then fault;
        transition faultDetectedFromNavigation first navigating then fault;
        transition resetFault first fault then ready;
    }

    part def RechargeableBattery {
        attribute nominalVoltage : Voltage_V = 3.7;
        attribute capacity : Energy_Wh = 5.2;
        attribute maximumContinuousCurrent : Current_A = 1.5;
        attribute lowBatteryVoltage : Voltage_V = 3.4;

        port powerOut : PowerSourcePort;
    }

    part def Microcontroller {
        attribute controlLoopPeriod : Time_s = 0.02;
        attribute processorClock : Frequency_Hz = 72000000.0;
        attribute obstacleDecisionDistance : Distance_m = 0.12;
        attribute edgeDecisionReflectance : Illuminance_lux = 120.0;

        port powerIn : PowerLoadPort;
        port proximityIn : ProximitySinkPort;
        port groundIn : GroundSinkPort;
        port userCommandIn : UserCommandSinkPort;
        port motorCommandOut : MotorCommandSourcePort;
        port statusOut : StatusSourcePort;
        port audioOut : AudioSourcePort;
    }

    part def ProximitySensorArray {
        attribute frontSensorCount : Count = 5;
        attribute rearSensorCount : Count = 2;
        attribute maximumUsableRange : Distance_m = 0.14;
        attribute minimumReliableRange : Distance_m = 0.01;
        attribute updatePeriod : Time_s = 0.02;

        port powerIn : PowerLoadPort;
        port proximityOut : ProximitySourcePort;
    }

    part def GroundSensorPair {
        attribute sensorCount : Count = 2;
        attribute edgeDetectionLookAhead : Distance_m = 0.025;
        attribute updatePeriod : Time_s = 0.02;

        port powerIn : PowerLoadPort;
        port groundOut : GroundSourcePort;
    }

    part def TopButtonPanel {
        attribute buttonCount : Count = 5;

        port powerIn : PowerLoadPort;
        port userCommandOut : UserCommandSourcePort;
    }

    part def MotorDriver {
        attribute maximumMotorVoltage : Voltage_V = 3.7;
        attribute peakMotorCurrentPerChannel : Current_A = 0.7;

        port powerIn : PowerLoadPort;
        port commandIn : MotorCommandSinkPort;
        port leftMotorPowerOut : PowerSourcePort;
        port rightMotorPowerOut : PowerSourcePort;
    }

    part def DcGearMotor {
        attribute nominalVoltage : Voltage_V = 3.7;
        attribute noLoadAngularSpeed : AngularSpeed_radps = 34.0;
        attribute stallCurrent : Current_A = 0.65;

        port powerIn : PowerLoadPort;
        port shaftMotionOut : WheelMotionSourcePort;
    }

    part def Wheel {
        attribute radius : Distance_m = 0.022;
        attribute treadWidth : Distance_m = 0.010;

        port hubMotionIn : WheelMotionSinkPort;
    }

    part def LedRing {
        attribute ledCount : Count = 8;

        port powerIn : PowerLoadPort;
        port indicationIn : StatusSinkPort;
    }

    part def Speaker {
        attribute minimumFrequency : Frequency_Hz = 100.0;
        attribute maximumFrequency : Frequency_Hz = 8000.0;

        port powerIn : PowerLoadPort;
        port audioIn : AudioSinkPort;
    }

    part def ThymioChassis {
        attribute length : Distance_m = 0.110;
        attribute width : Distance_m = 0.110;
        attribute height : Distance_m = 0.055;
        attribute wheelBase : Distance_m = 0.095;
        attribute massWithBattery : Real = 0.270;
    }

    part def ThymioExplorer {
        doc /* Primary high-level function: a Thymio-based mobile robot shall autonomously explore an indoor tabletop or floor area, sense nearby obstacles and table edges, choose safe differential wheel motion, avoid collisions, and communicate its state using LEDs and sound. */

        attribute primaryFunctionEnabled : Boolean = true;
        attribute requiredObstacleClearance : Distance_m = 0.10;
        attribute minimumControlledClearance : Distance_m = 0.10;
        attribute maximumForwardSpeed : Speed_mps = 0.14;
        attribute nominalExplorationSpeed : Speed_mps = 0.08;
        attribute minimumMissionDuration : Time_s = 60.0;

        port missionIn : MissionInputPort;
        port missionReportOut : MissionReportPort;
        port externalUserCommandIn : UserCommandSinkPort;
        port externalStatusOut : StatusSourcePort;

        part chassis : ThymioChassis;
        part battery : RechargeableBattery;
        part controller : Microcontroller;
        part proximitySensors : ProximitySensorArray;
        part groundSensors : GroundSensorPair;
        part buttons : TopButtonPanel;
        part motorDriver : MotorDriver;
        part leftMotor : DcGearMotor;
        part rightMotor : DcGearMotor;
        part leftWheel : Wheel;
        part rightWheel : Wheel;
        part leds : LedRing;
        part speaker : Speaker;

        perform action primaryFunction : AutonomousObstacleAvoidingExploration;
        exhibit state operatingModes : ThymioOperatingModes;

        connection batteryToController connect battery.powerOut to controller.powerIn;
        connection batteryToProximitySensors connect battery.powerOut to proximitySensors.powerIn;
        connection batteryToGroundSensors connect battery.powerOut to groundSensors.powerIn;
        connection batteryToButtons connect battery.powerOut to buttons.powerIn;
        connection batteryToMotorDriver connect battery.powerOut to motorDriver.powerIn;
        connection batteryToLeds connect battery.powerOut to leds.powerIn;
        connection batteryToSpeaker connect battery.powerOut to speaker.powerIn;

        connection proximityDataToController connect proximitySensors.proximityOut to controller.proximityIn;
        connection groundDataToController connect groundSensors.groundOut to controller.groundIn;
        connection buttonCommandsToController connect buttons.userCommandOut to controller.userCommandIn;
        connection controllerCommandsToDriver connect controller.motorCommandOut to motorDriver.commandIn;

        connection leftDriverPowerToMotor connect motorDriver.leftMotorPowerOut to leftMotor.powerIn;
        connection rightDriverPowerToMotor connect motorDriver.rightMotorPowerOut to rightMotor.powerIn;
        connection leftMotorToWheel connect leftMotor.shaftMotionOut to leftWheel.hubMotionIn;
        connection rightMotorToWheel connect rightMotor.shaftMotionOut to rightWheel.hubMotionIn;

        connection controllerStatusToLeds connect controller.statusOut to leds.indicationIn;
        connection controllerAudioToSpeaker connect controller.audioOut to speaker.audioIn;

        connection externalUserToController connect externalUserCommandIn to controller.userCommandIn;
        connection controllerStatusToExternal connect controller.statusOut to externalStatusOut;
    }

    requirement def PrimaryFunctionRequirement {
        subject robot : ThymioExplorer;
        doc /* The system shall provide high-level autonomous exploration based on the Thymio robot platform by combining proximity sensing, ground sensing, differential drive motion, and user-visible feedback. */
        require constraint { robot.primaryFunctionEnabled == true }
    }

    requirement def ObstacleAvoidanceRequirement {
        subject robot : ThymioExplorer;
        doc /* During autonomous exploration the robot shall keep at least the required clearance from detected obstacles whenever the obstacle is within the reliable proximity sensing range. */
        require constraint { robot.minimumControlledClearance >= robot.requiredObstacleClearance }
    }

    requirement def SpeedLimitRequirement {
        subject robot : ThymioExplorer;
        doc /* The exploration speed shall remain within a safe high-level limit appropriate for a small Thymio differential-drive robot. */
        require constraint { robot.nominalExplorationSpeed <= robot.maximumForwardSpeed }
    }

    requirement def MissionDurationRequirement {
        subject robot : ThymioExplorer;
        doc /* The robot shall support a nontrivial autonomous mission duration for demonstration of its primary exploration and avoidance function. */
        require constraint { robot.minimumMissionDuration >= 60.0 }
    }

    part thymioBasedSystem : ThymioExplorer;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject robot = thymioBasedSystem;
    }

    requirement obstacleAvoidanceRequirement : ObstacleAvoidanceRequirement {
        subject robot = thymioBasedSystem;
    }

    requirement speedLimitRequirement : SpeedLimitRequirement {
        subject robot = thymioBasedSystem;
    }

    requirement missionDurationRequirement : MissionDurationRequirement {
        subject robot = thymioBasedSystem;
    }

    satisfy primaryFunctionRequirement by thymioBasedSystem;
    satisfy obstacleAvoidanceRequirement by thymioBasedSystem;
    satisfy speedLimitRequirement by thymioBasedSystem;
    satisfy missionDurationRequirement by thymioBasedSystem;
}
