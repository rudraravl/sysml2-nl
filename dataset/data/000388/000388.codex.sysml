package AgriculturalRoboticSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent :> Real {
        range : ScalarValues::Real[0..100];
        unit = "%";
    }

    attribute def DegreeCelsius :> Real {
        unit = "degC";
    }

    attribute def Millimeter :> Real {
        unit = "mm";
    }

    attribute def Meter :> Real {
        unit = "m";
    }

    attribute def MeterPerSecond :> Real {
        unit = "m/s";
    }

    attribute def Kilogram :> Real {
        unit = "kg";
    }

    attribute def KilogramPerHour :> Real {
        unit = "kg/h";
    }

    attribute def Liter :> Real {
        unit = "L";
    }

    attribute def LiterPerMinute :> Real {
        unit = "L/min";
    }

    attribute def WattHour :> Real {
        unit = "Wh";
    }

    attribute def Volt :> Real {
        unit = "V";
    }

    attribute def Ampere :> Real {
        unit = "A";
    }

    attribute def NewtonMeter :> Real {
        unit = "N*m";
    }

    attribute def Hectare :> Real {
        unit = "ha";
    }

    attribute def HectarePerHour :> Real {
        unit = "ha/h";
    }

    attribute def LatitudeDegrees :> Real {
        unit = "deg";
        range : ScalarValues::Real[-90..90];
    }

    attribute def LongitudeDegrees :> Real {
        unit = "deg";
        range : ScalarValues::Real[-180..180];
    }

    enum def CropHealthKind {
        enum nominal;
        enum stressed;
        enum diseased;
        enum weed;
        enum unknown;
    }

    enum def RobotModeKind {
        enum off;
        enum standby;
        enum localManual;
        enum autonomousSurvey;
        enum autonomousTreatment;
        enum returnToBase;
        enum charging;
        enum fault;
        enum emergencyStop;
    }

    enum def TreatmentKind {
        enum none;
        enum mechanicalWeeding;
        enum spotSpray;
        enum nutrientDose;
    }

    item def GNSSFix {
        attribute latitude : LatitudeDegrees;
        attribute longitude : LongitudeDegrees;
        attribute altitude : Meter;
        attribute horizontalAccuracy : Meter;
        attribute fixValid : Boolean;
        attribute timestamp : Real;
    }

    item def FieldMap {
        attribute fieldArea : Hectare;
        attribute rowSpacing : Meter;
        attribute rowLength : Meter;
        attribute boundaryVertexCount : Integer;
        attribute restrictedZoneCount : Integer;
    }

    item def CropObservation {
        attribute position : GNSSFix;
        attribute cropHealth : CropHealthKind;
        attribute canopyHeight : Millimeter;
        attribute weedProbability : Percent;
        attribute soilMoisture : Percent;
        attribute imageConfidence : Percent;
        attribute timestamp : Real;
    }

    item def TreatmentCommand {
        attribute treatment : TreatmentKind;
        attribute targetPosition : GNSSFix;
        attribute doseVolume : Liter;
        attribute toolDepth : Millimeter;
        attribute maxVehicleSpeed : MeterPerSecond;
    }

    item def TelemetryPacket {
        attribute mode : RobotModeKind;
        attribute position : GNSSFix;
        attribute batteryStateOfCharge : Percent;
        attribute tankLevel : Percent;
        attribute vehicleSpeed : MeterPerSecond;
        attribute activeFaultCount : Integer;
        attribute emergencyStopActive : Boolean;
    }

    item def MissionPlan {
        attribute plannedArea : Hectare;
        attribute targetCoverage : Percent;
        attribute nominalRowSpeed : MeterPerSecond;
        attribute treatmentEnabled : Boolean;
        attribute maximumAllowedDose : Liter;
    }

    item def PowerFlow {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute availableEnergy : WattHour;
    }

    item def MotionCommand {
        attribute leftWheelTorque : NewtonMeter;
        attribute rightWheelTorque : NewtonMeter;
        attribute commandedSpeed : MeterPerSecond;
        attribute commandedCurvature : Real;
    }

    item def LiquidFlow {
        attribute flowRate : LiterPerMinute;
        attribute pressure : Real;
        attribute volumeRemaining : Liter;
    }

    port def DataInPort {
        in item data;
    }

    port def DataOutPort {
        out item data;
    }

    port def PowerInPort {
        in item power : PowerFlow;
    }

    port def PowerOutPort {
        out item power : PowerFlow;
    }

    port def MotionCommandOutPort {
        out item command : MotionCommand;
    }

    port def MotionCommandInPort {
        in item command : MotionCommand;
    }

    port def TreatmentCommandOutPort {
        out item command : TreatmentCommand;
    }

    port def TreatmentCommandInPort {
        in item command : TreatmentCommand;
    }

    port def LiquidOutPort {
        out item liquid : LiquidFlow;
    }

    port def LiquidInPort {
        in item liquid : LiquidFlow;
    }

    port def TelemetryOutPort {
        out item telemetry : TelemetryPacket;
    }

    port def TelemetryInPort {
        in item telemetry : TelemetryPacket;
    }

    port def MissionInPort {
        in item mission : MissionPlan;
    }

    part def AgriculturalRobot {
        attribute mass : Kilogram;
        attribute width : Meter;
        attribute length : Meter;
        attribute groundClearance : Meter;
        attribute maximumSpeed : MeterPerSecond;
        attribute operatingTemperatureMin : DegreeCelsius;
        attribute operatingTemperatureMax : DegreeCelsius;
        attribute currentMode : RobotModeKind;
        attribute coveredArea : Hectare;
        attribute missionCoverage : Percent;

        port missionPort : MissionInPort;
        port telemetryPort : TelemetryOutPort;

        part chassis : Chassis;
        part powerSystem : PowerSystem;
        part mobilitySystem : DifferentialDriveMobility;
        part perceptionSystem : CropPerceptionSystem;
        part navigationSystem : RowNavigationSystem;
        part taskSystem : AgriculturalTaskSystem;
        part safetySystem : SafetySystem;
        part communicationSystem : FarmCommunicationSystem;

        connect powerSystem.loadPowerPort to mobilitySystem.powerPort;
        connect powerSystem.loadPowerPort to perceptionSystem.powerPort;
        connect powerSystem.loadPowerPort to navigationSystem.powerPort;
        connect powerSystem.loadPowerPort to taskSystem.powerPort;
        connect powerSystem.loadPowerPort to communicationSystem.powerPort;
        connect powerSystem.loadPowerPort to safetySystem.powerPort;

        connect perceptionSystem.observationPort to navigationSystem.observationPort;
        connect perceptionSystem.observationPort to taskSystem.observationPort;
        connect navigationSystem.motionCommandPort to mobilitySystem.motionCommandPort;
        connect taskSystem.treatmentCommandPort to taskSystem.implement.commandPort;
        connect taskSystem.liquidSupplyPort to taskSystem.implement.liquidPort;
        connect safetySystem.safeMotionCommandPort to mobilitySystem.motionCommandPort;
        connect communicationSystem.missionOutputPort to missionPort;
        connect communicationSystem.telemetryInputPort to telemetryPort;
        connect navigationSystem.positionPort to communicationSystem.positionInputPort;
        connect powerSystem.telemetryPort to communicationSystem.powerTelemetryInputPort;
        connect taskSystem.telemetryPort to communicationSystem.taskTelemetryInputPort;

        perform behavior robotOperationalBehavior;
    }

    part def Chassis {
        attribute frameMaterialDensity : Kilogram;
        attribute payloadCapacity : Kilogram;
        attribute ingressProtectionRating : Integer;
        attribute rowCropCompatibleWidth : Meter;
    }

    part def PowerSystem {
        attribute batteryCapacity : WattHour;
        attribute nominalVoltage : Volt;
        attribute maximumDischargeCurrent : Ampere;
        attribute stateOfCharge : Percent;
        attribute minimumReserveStateOfCharge : Percent;

        port chargePowerPort : PowerInPort;
        port loadPowerPort : PowerOutPort;
        port telemetryPort : DataOutPort;

        part batteryPack : BatteryPack;
        part batteryManagementSystem : BatteryManagementSystem;
        part dcBus : DCBus;

        connect batteryPack.powerPort to batteryManagementSystem.batteryPort;
        connect batteryManagementSystem.busPort to dcBus.inputPort;
        connect dcBus.outputPort to loadPowerPort;
    }

    part def BatteryPack {
        attribute capacity : WattHour = 9600;
        attribute nominalVoltage : Volt = 48;
        attribute maximumCurrent : Ampere = 220;
        attribute stateOfCharge : Percent;

        port powerPort : PowerOutPort;
    }

    part def BatteryManagementSystem {
        attribute cellTemperature : DegreeCelsius;
        attribute packVoltage : Volt;
        attribute packCurrent : Ampere;
        attribute isolationFaultDetected : Boolean;

        port batteryPort : PowerInPort;
        port busPort : PowerOutPort;
    }

    part def DCBus {
        attribute busVoltage : Volt = 48;
        attribute availableCurrent : Ampere;

        port inputPort : PowerInPort;
        port outputPort : PowerOutPort;
    }

    part def DifferentialDriveMobility {
        attribute trackWidth : Meter = 1.2;
        attribute wheelRadius : Meter = 0.32;
        attribute maximumClimbSlope : Percent = 18;
        attribute odometrySpeed : MeterPerSecond;

        port powerPort : PowerInPort;
        port motionCommandPort : MotionCommandInPort;

        part leftMotor : WheelMotor;
        part rightMotor : WheelMotor;
        part leftWheel : TractionWheel;
        part rightWheel : TractionWheel;
        part suspension : PassiveSuspension;

        connect leftMotor.mechanicalPort to leftWheel.hubPort;
        connect rightMotor.mechanicalPort to rightWheel.hubPort;
    }

    part def WheelMotor {
        attribute ratedTorque : NewtonMeter = 85;
        attribute peakTorque : NewtonMeter = 160;
        attribute efficiency : Percent = 91;

        port electricalPort : PowerInPort;
        port mechanicalPort : DataOutPort;
    }

    part def TractionWheel {
        attribute diameter : Meter = 0.64;
        attribute treadDepth : Millimeter = 28;
        attribute soilCompactionLimit : Real;
        port hubPort : DataInPort;
    }

    part def PassiveSuspension {
        attribute travel : Millimeter = 140;
        attribute dampingCoefficient : Real;
    }

    part def CropPerceptionSystem {
        attribute detectionLatency : Real;
        attribute cropClassificationAccuracy : Percent;
        attribute weedDetectionAccuracy : Percent;

        port powerPort : PowerInPort;
        port observationPort : DataOutPort;

        part stereoCamera : StereoCamera;
        part multispectralCamera : MultispectralCamera;
        part soilProbe : SoilMoistureProbe;
        part perceptionComputer : EdgeAIComputer;

        connect stereoCamera.imagePort to perceptionComputer.cameraInputPort;
        connect multispectralCamera.spectralPort to perceptionComputer.spectralInputPort;
        connect soilProbe.measurementPort to perceptionComputer.soilInputPort;
        connect perceptionComputer.observationOutputPort to observationPort;
    }

    part def StereoCamera {
        attribute baseline : Millimeter = 120;
        attribute frameRate : Real = 30;
        attribute horizontalFieldOfView : Real = 90;
        port imagePort : DataOutPort;
    }

    part def MultispectralCamera {
        attribute bandCount : Integer = 5;
        attribute groundSampleDistance : Millimeter = 8;
        port spectralPort : DataOutPort;
    }

    part def SoilMoistureProbe {
        attribute insertionDepth : Millimeter = 80;
        attribute measurementAccuracy : Percent = 3;
        port measurementPort : DataOutPort;
    }

    part def EdgeAIComputer {
        attribute inferenceRate : Real = 12;
        attribute processorPower : Real = 45;

        port cameraInputPort : DataInPort;
        port spectralInputPort : DataInPort;
        port soilInputPort : DataInPort;
        port observationOutputPort : DataOutPort;
    }

    part def RowNavigationSystem {
        attribute lateralRowError : Meter;
        attribute headingError : Real;
        attribute pathTrackingUpdateRate : Real = 20;

        port powerPort : PowerInPort;
        port observationPort : DataInPort;
        port positionPort : DataOutPort;
        port motionCommandPort : MotionCommandOutPort;

        part gnssReceiver : RTKGNSSReceiver;
        part imu : InertialMeasurementUnit;
        part rowTracker : CropRowTracker;
        part pathPlanner : CoveragePathPlanner;
        part motionController : MotionController;

        connect gnssReceiver.fixPort to pathPlanner.positionInputPort;
        connect imu.motionPort to motionController.imuInputPort;
        connect rowTracker.rowEstimatePort to motionController.rowInputPort;
        connect pathPlanner.pathPort to motionController.pathInputPort;
        connect motionController.commandPort to motionCommandPort;
        connect gnssReceiver.fixPort to positionPort;
    }

    part def RTKGNSSReceiver {
        attribute updateRate : Real = 10;
        attribute horizontalAccuracy : Meter = 0.025;
        port fixPort : DataOutPort;
    }

    part def InertialMeasurementUnit {
        attribute gyroBiasStability : Real;
        attribute accelerationRange : Real;
        port motionPort : DataOutPort;
    }

    part def CropRowTracker {
        attribute maximumRowCurvature : Real;
        attribute rowEstimateConfidence : Percent;
        port imageFeatureInputPort : DataInPort;
        port rowEstimatePort : DataOutPort;
    }

    part def CoveragePathPlanner {
        attribute plannedCoverage : Percent;
        attribute turnRadius : Meter = 1.8;
        attribute headlandWidth : Meter = 3.0;

        port missionInputPort : MissionInPort;
        port positionInputPort : DataInPort;
        port pathPort : DataOutPort;
    }

    part def MotionController {
        attribute maximumLateralError : Meter = 0.08;
        attribute nominalSpeed : MeterPerSecond = 0.9;

        port imuInputPort : DataInPort;
        port rowInputPort : DataInPort;
        port pathInputPort : DataInPort;
        port commandPort : MotionCommandOutPort;
    }

    part def AgriculturalTaskSystem {
        attribute primaryTask : String = "autonomous crop-row inspection and precision weed treatment";
        attribute inspectedArea : Hectare;
        attribute treatedWeedCount : Integer;
        attribute averageDosePerTarget : Liter;

        port powerPort : PowerInPort;
        port observationPort : DataInPort;
        port treatmentCommandPort : TreatmentCommandOutPort;
        port liquidSupplyPort : LiquidOutPort;
        port telemetryPort : DataOutPort;

        part decisionManager : CropCareDecisionManager;
        part implement : PrecisionWeedingImplement;
        part chemicalTank : TreatmentTank;
        part pump : MeteringPump;

        connect observationPort to decisionManager.observationInputPort;
        connect decisionManager.commandOutputPort to treatmentCommandPort;
        connect chemicalTank.liquidOutputPort to pump.liquidInputPort;
        connect pump.liquidOutputPort to liquidSupplyPort;
    }

    part def CropCareDecisionManager {
        attribute weedTreatmentThreshold : Percent = 72;
        attribute cropStressAlertThreshold : Percent = 65;
        attribute minimumPlantSpacing : Millimeter = 120;

        port observationInputPort : DataInPort;
        port commandOutputPort : TreatmentCommandOutPort;

        perform behavior decideTreatment;
    }

    part def PrecisionWeedingImplement {
        attribute toolWidth : Meter = 0.45;
        attribute nozzleCount : Integer = 4;
        attribute mechanicalBladeDepth : Millimeter;
        attribute placementAccuracy : Millimeter = 25;

        port commandPort : TreatmentCommandInPort;
        port liquidPort : LiquidInPort;

        part sprayer : SpotSprayer;
        part mechanicalHoe : MechanicalHoe;
    }

    part def SpotSprayer {
        attribute minimumDose : Liter = 0.005;
        attribute maximumDose : Liter = 0.030;
        attribute sprayConeAngle : Real = 25;
        port liquidPort : LiquidInPort;
        port commandPort : TreatmentCommandInPort;
    }

    part def MechanicalHoe {
        attribute bladeWidth : Millimeter = 80;
        attribute maximumDepth : Millimeter = 45;
        attribute actuationTime : Real = 0.18;
        port commandPort : TreatmentCommandInPort;
    }

    part def TreatmentTank {
        attribute capacity : Liter = 40;
        attribute currentLevel : Percent;
        attribute fluidTemperature : DegreeCelsius;
        port liquidOutputPort : LiquidOutPort;
    }

    part def MeteringPump {
        attribute maximumFlowRate : LiterPerMinute = 2.5;
        attribute meteringAccuracy : Percent = 4;
        port liquidInputPort : LiquidInPort;
        port liquidOutputPort : LiquidOutPort;
    }

    part def SafetySystem {
        attribute obstacleDetectionRange : Meter = 8;
        attribute emergencyStopActive : Boolean;
        attribute protectiveStopDistance : Meter = 0.5;

        port powerPort : PowerInPort;
        port safeMotionCommandPort : MotionCommandOutPort;

        part lidar : SafetyLidar;
        part bumper : ContactBumper;
        part emergencyStopButton : EmergencyStopButton;
        part safetyController : SafetyController;

        connect lidar.obstaclePort to safetyController.obstacleInputPort;
        connect bumper.contactPort to safetyController.contactInputPort;
        connect emergencyStopButton.stopPort to safetyController.estopInputPort;
        connect safetyController.motionLimitPort to safeMotionCommandPort;
    }

    part def SafetyLidar {
        attribute range : Meter = 8;
        attribute scanRate : Real = 15;
        attribute minimumDetectableObjectHeight : Millimeter = 120;
        port obstaclePort : DataOutPort;
    }

    part def ContactBumper {
        attribute activationForce : Real = 45;
        port contactPort : DataOutPort;
    }

    part def EmergencyStopButton {
        attribute latched : Boolean;
        port stopPort : DataOutPort;
    }

    part def SafetyController {
        attribute safetyIntegrityLevel : Integer = 2;
        attribute stopCommandLatency : Real = 0.08;
        port obstacleInputPort : DataInPort;
        port contactInputPort : DataInPort;
        port estopInputPort : DataInPort;
        port motionLimitPort : MotionCommandOutPort;
    }

    part def FarmCommunicationSystem {
        attribute wirelessRange : Meter = 1000;
        attribute telemetryRate : Real = 1;
        attribute commandLatency : Real;

        port powerPort : PowerInPort;
        port telemetryInputPort : TelemetryInPort;
        port positionInputPort : DataInPort;
        port powerTelemetryInputPort : DataInPort;
        port taskTelemetryInputPort : DataInPort;
        port missionOutputPort : MissionInPort;

        part radioModem : FarmRadioModem;
        part operatorConsoleLink : OperatorConsoleLink;

        connect radioModem.dataPort to operatorConsoleLink.radioPort;
    }

    part def FarmRadioModem {
        attribute frequency : Real = 915;
        attribute transmitPower : Real = 1;
        attribute packetLossRate : Percent;
        port dataPort : DataOutPort;
    }

    part def OperatorConsoleLink {
        attribute authenticated : Boolean;
        attribute encryptionEnabled : Boolean;
        port radioPort : DataInPort;
    }

    action def ExecuteMission {
        in item mission : MissionPlan;
        out item telemetry : TelemetryPacket;

        first start;
        then validateMission;
        then localizeRobot;
        then followCropRows;
        then inspectCrops;
        then decideAndApplyTreatment;
        then updateCoverage;
        then evaluateCompletion;
        if done then returnToBase;
        else followCropRows;
        then reportMissionSummary;
    }

    action def DecideTreatment {
        in item observation : CropObservation;
        out item command : TreatmentCommand;

        first classifyObservation;
        then compareWeedProbability;
        if weedDetected then selectTreatmentMode;
        else suppressTreatment;
        then computeDoseOrToolDepth;
        then issueTreatmentCommand;
    }

    action def PerformEmergencyStop {
        in item telemetry : TelemetryPacket;
        out item command : MotionCommand;

        first detectUnsafeCondition;
        then commandZeroTorque;
        then latchEmergencyStop;
        then notifyOperator;
    }

    state def AgriculturalRobotOperationalStateMachine {
        entry action initializeDiagnostics;

        state off;
        state standby;
        state localManual;
        state autonomousSurvey;
        state autonomousTreatment;
        state returnToBase;
        state charging;
        state fault;
        state emergencyStop;

        transition initial then off;
        transition off_to_standby
            first off
            accept powerOn
            then standby;

        transition standby_to_survey
            first standby
            accept missionLoaded
            if batteryOk and fieldMapValid
            then autonomousSurvey;

        transition survey_to_treatment
            first autonomousSurvey
            accept targetDetected
            if treatmentEnabled
            then autonomousTreatment;

        transition treatment_to_survey
            first autonomousTreatment
            accept targetTreated
            then autonomousSurvey;

        transition survey_to_return
            first autonomousSurvey
            accept missionCoverageReached
            then returnToBase;

        transition treatment_to_return
            first autonomousTreatment
            accept lowBatteryOrLowTank
            then returnToBase;

        transition return_to_charging
            first returnToBase
            accept dockedAtBase
            then charging;

        transition charging_to_standby
            first charging
            accept chargeComplete
            then standby;

        transition any_to_emergencyStop
            first off, standby, localManual, autonomousSurvey, autonomousTreatment, returnToBase, charging, fault
            accept emergencyStopPressed
            then emergencyStop;

        transition any_to_fault
            first standby, localManual, autonomousSurvey, autonomousTreatment, returnToBase, charging
            accept criticalFaultDetected
            then fault;

        transition fault_to_standby
            first fault
            accept faultCleared
            if diagnosticsPassed
            then standby;

        transition emergencyStop_to_standby
            first emergencyStop
            accept emergencyStopReset
            if safeToResume
            then standby;
    }

    behavior robotOperationalBehavior : AgriculturalRobotOperationalStateMachine;

    behavior decideTreatment : DecideTreatment;

    requirement def PrimaryTaskRequirement {
        subject robot : AgriculturalRobot;
        require constraint {
            robot.taskSystem.primaryTask == "autonomous crop-row inspection and precision weed treatment"
        }
    }

    requirement def FieldCoverageRequirement {
        subject robot : AgriculturalRobot;
        attribute requiredCoverage : Percent = 95;
        require constraint {
            robot.missionCoverage >= requiredCoverage
        }
    }

    requirement def RowTrackingRequirement {
        subject navigation : RowNavigationSystem;
        attribute maximumAllowedError : Meter = 0.10;
        require constraint {
            navigation.lateralRowError <= maximumAllowedError
        }
    }

    requirement def WeedTreatmentAccuracyRequirement {
        subject implement : PrecisionWeedingImplement;
        attribute maximumPlacementError : Millimeter = 30;
        require constraint {
            implement.placementAccuracy <= maximumPlacementError
        }
    }

    requirement def BatteryReserveRequirement {
        subject power : PowerSystem;
        attribute reserve : Percent = 15;
        require constraint {
            power.stateOfCharge >= reserve
        }
    }

    requirement def SafetyStopRequirement {
        subject safety : SafetySystem;
        attribute maximumStopLatency : Real = 0.10;
        require constraint {
            safety.safetyController.stopCommandLatency <= maximumStopLatency
        }
    }

    requirement def OperatingEnvironmentRequirement {
        subject robot : AgriculturalRobot;
        attribute minimumTemperature : DegreeCelsius = -5;
        attribute maximumTemperature : DegreeCelsius = 45;
        require constraint {
            robot.operatingTemperatureMin <= minimumTemperature and
            robot.operatingTemperatureMax >= maximumTemperature
        }
    }

    requirement def SoilProtectionRequirement {
        subject mobility : DifferentialDriveMobility;
        attribute maximumSpeedInCropRow : MeterPerSecond = 1.2;
        require constraint {
            mobility.odometrySpeed <= maximumSpeedInCropRow
        }
    }

    requirement def TelemetryRequirement {
        subject comms : FarmCommunicationSystem;
        attribute minimumTelemetryRate : Real = 1;
        require constraint {
            comms.telemetryRate >= minimumTelemetryRate and
            comms.operatorConsoleLink.authenticated == true and
            comms.operatorConsoleLink.encryptionEnabled == true
        }
    }

    part agriculturalRobotSystem : AgriculturalRobot {
        attribute mass = 420;
        attribute width = 1.35;
        attribute length = 2.1;
        attribute groundClearance = 0.42;
        attribute maximumSpeed = 1.5;
        attribute operatingTemperatureMin = -10;
        attribute operatingTemperatureMax = 50;
        attribute currentMode = RobotModeKind::standby;
        attribute coveredArea = 0;
        attribute missionCoverage = 0;

        part powerSystem {
            attribute batteryCapacity = 9600;
            attribute nominalVoltage = 48;
            attribute maximumDischargeCurrent = 220;
            attribute stateOfCharge = 100;
            attribute minimumReserveStateOfCharge = 15;
        }

        part mobilitySystem {
            attribute odometrySpeed = 0;
        }

        part perceptionSystem {
            attribute cropClassificationAccuracy = 92;
            attribute weedDetectionAccuracy = 89;
            attribute detectionLatency = 0.18;
        }

        part navigationSystem {
            attribute lateralRowError = 0.04;
            attribute headingError = 0.02;
        }

        part taskSystem {
            attribute inspectedArea = 0;
            attribute treatedWeedCount = 0;
            attribute averageDosePerTarget = 0.012;
        }

        part safetySystem {
            attribute emergencyStopActive = false;
        }

        part communicationSystem {
            attribute commandLatency = 0.25;
        }
    }

}