package AgriculturalRoboticPrimaryTaskModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value type Meter :> Real {
        doc "Length measured in meters.";
        unit = "m";
    }

    value type SquareMeter :> Real {
        doc "Area measured in square meters.";
        unit = "m^2";
    }

    value type MeterPerSecond :> Real {
        doc "Linear speed measured in meters per second.";
        unit = "m/s";
    }

    value type Degree :> Real {
        doc "Angle measured in degrees.";
        unit = "deg";
    }

    value type Kilogram :> Real {
        doc "Mass measured in kilograms.";
        unit = "kg";
    }

    value type Newton :> Real {
        doc "Force measured in newtons.";
        unit = "N";
    }

    value type Watt :> Real {
        doc "Power measured in watts.";
        unit = "W";
    }

    value type Volt :> Real {
        doc "Electrical potential measured in volts.";
        unit = "V";
    }

    value type AmpereHour :> Real {
        doc "Battery capacity measured in ampere-hours.";
        unit = "A*h";
    }

    value type Percent :> Real {
        doc "Fractional percentage from 0 to 100.";
        unit = "%";
    }

    value type Second :> Real {
        doc "Time measured in seconds.";
        unit = "s";
    }

    value type Liter :> Real {
        doc "Liquid volume measured in liters.";
        unit = "L";
    }

    value type LiterPerMinute :> Real {
        doc "Volumetric flow rate measured in liters per minute.";
        unit = "L/min";
    }

    value type Celsius :> Real {
        doc "Temperature measured in degrees Celsius.";
        unit = "degC";
    }

    value type Count :> Integer {
        doc "Discrete count.";
        unit = "1";
    }

    value type Confidence :> Real {
        doc "Normalized confidence from 0.0 to 1.0.";
        unit = "1";
    }

    enum def CropKind {
        enum soybean;
        enum corn;
        enum lettuce;
        enum wheat;
        enum tomato;
    }

    enum def WeedTreatmentMode {
        enum none;
        enum mechanicalCut;
        enum microSpray;
        enum thermalPulse;
    }

    enum def MissionPhase {
        enum notStarted;
        enum initialized;
        enum localizing;
        enum traversingRow;
        enum scanningCropZone;
        enum treatingWeed;
        enum avoidingObstacle;
        enum returningToDock;
        enum charging;
        enum complete;
        enum safeStopped;
        enum faulted;
    }

    enum def Severity {
        enum advisory;
        enum caution;
        enum warning;
        enum critical;
    }

    item def ElectricalEnergy {
        attribute stateOfCharge : Percent;
        attribute voltage : Volt;
        attribute availablePower : Watt;
    }

    item def TractionPower {
        attribute commandedWheelTorque : Newton;
        attribute commandedSpeed : MeterPerSecond;
    }

    item def RobotCommand {
        attribute missionIdentifier : String;
        attribute startCommand : Boolean;
        attribute pauseCommand : Boolean;
        attribute abortCommand : Boolean;
        attribute requestedMode : WeedTreatmentMode;
        attribute maximumSpeed : MeterPerSecond;
    }

    item def RobotStatus {
        attribute phase : MissionPhase;
        attribute batteryStateOfCharge : Percent;
        attribute traveledDistance : Meter;
        attribute treatedWeedCount : Count;
        attribute cropDamageEstimate : Percent;
        attribute activeFaultCount : Count;
    }

    item def GeoPosition {
        attribute latitude : Degree;
        attribute longitude : Degree;
        attribute altitude : Meter;
        attribute horizontalAccuracy : Meter;
    }

    item def Pose2D {
        attribute x : Meter;
        attribute y : Meter;
        attribute heading : Degree;
        attribute covarianceTrace : Real;
    }

    item def FieldBoundary {
        attribute fieldIdentifier : String;
        attribute area : SquareMeter;
        attribute minimumX : Meter;
        attribute maximumX : Meter;
        attribute minimumY : Meter;
        attribute maximumY : Meter;
    }

    item def CropRow {
        attribute rowIdentifier : String;
        attribute rowStartX : Meter;
        attribute rowStartY : Meter;
        attribute rowEndX : Meter;
        attribute rowEndY : Meter;
        attribute nominalSpacing : Meter;
        attribute cropKind : CropKind;
    }

    item def MissionPlan {
        attribute missionIdentifier : String;
        attribute targetCrop : CropKind;
        attribute targetArea : SquareMeter;
        attribute rowCount : Count;
        attribute treatmentMode : WeedTreatmentMode;
        attribute plannedSpeed : MeterPerSecond;
        attribute maximumAllowedCropDamage : Percent;
        attribute minimumWeedRemovalRate : Percent;
    }

    item def ImageFrame {
        attribute frameIdentifier : String;
        attribute widthPixels : Count;
        attribute heightPixels : Count;
        attribute exposureTime : Second;
        attribute cameraTemperature : Celsius;
    }

    item def LidarScan {
        attribute scanIdentifier : String;
        attribute angularRange : Degree;
        attribute minimumRange : Meter;
        attribute maximumRange : Meter;
        attribute pointCount : Count;
    }

    item def PlantDetection {
        attribute detectionIdentifier : String;
        attribute cropProbability : Confidence;
        attribute weedProbability : Confidence;
        attribute xInRobotFrame : Meter;
        attribute yInRobotFrame : Meter;
        attribute estimatedStemDiameter : Meter;
        attribute cropKind : CropKind;
    }

    item def WeedTarget {
        attribute targetIdentifier : String;
        attribute xInRobotFrame : Meter;
        attribute yInRobotFrame : Meter;
        attribute confidence : Confidence;
        attribute recommendedTreatment : WeedTreatmentMode;
        attribute keepOutRadiusAroundCrop : Meter;
    }

    item def TreatmentCommand {
        attribute targetIdentifier : String;
        attribute mode : WeedTreatmentMode;
        attribute applicatorX : Meter;
        attribute applicatorY : Meter;
        attribute sprayVolume : Liter;
        attribute toolDepth : Meter;
        attribute pulseDuration : Second;
    }

    item def TreatmentResult {
        attribute targetIdentifier : String;
        attribute applied : Boolean;
        attribute mode : WeedTreatmentMode;
        attribute actualSprayVolume : Liter;
        attribute actualToolDepth : Meter;
        attribute estimatedWeedNeutralized : Boolean;
        attribute nearestCropDistance : Meter;
    }

    item def ObstacleReport {
        attribute obstacleIdentifier : String;
        attribute distance : Meter;
        attribute bearing : Degree;
        attribute relativeSpeed : MeterPerSecond;
        attribute severity : Severity;
    }

    item def FaultReport {
        attribute faultIdentifier : String;
        attribute severity : Severity;
        attribute message : String;
        attribute recoverable : Boolean;
    }

    port def ElectricalPowerPort {
        in item suppliedEnergy : ElectricalEnergy;
        out item demandedPower : ElectricalEnergy;
    }

    port def CommandPort {
        in item command : RobotCommand;
    }

    port def StatusPort {
        out item status : RobotStatus;
        out item fault : FaultReport;
    }

    port def MissionPlanPort {
        in item missionPlan : MissionPlan;
        in item fieldBoundary : FieldBoundary;
        in item cropRow : CropRow;
    }

    port def LocalizationPort {
        out item position : GeoPosition;
        out item pose : Pose2D;
    }

    port def SensorImagePort {
        out item image : ImageFrame;
    }

    port def LidarPort {
        out item scan : LidarScan;
        out item obstacle : ObstacleReport;
    }

    port def DetectionPort {
        out item plantDetection : PlantDetection;
        out item weedTarget : WeedTarget;
    }

    port def TreatmentPort {
        in item treatmentCommand : TreatmentCommand;
        out item treatmentResult : TreatmentResult;
    }

    port def MobilityCommandPort {
        in item tractionCommand : TractionPower;
        out item poseFeedback : Pose2D;
    }

    port def TelemetryPort {
        in item statusToDisplay : RobotStatus;
        in item faultToDisplay : FaultReport;
        out item operatorCommand : RobotCommand;
    }

    part def BatteryPack {
        attribute nominalVoltage : Volt = 48.0;
        attribute capacity : AmpereHour = 120.0;
        attribute maximumContinuousPower : Watt = 4200.0;
        attribute minimumOperationalStateOfCharge : Percent = 15.0;
        attribute stateOfCharge : Percent = 100.0;
        port powerOut : ElectricalPowerPort;
    }

    part def SolarAssistPanel {
        attribute peakPower : Watt = 400.0;
        attribute active : Boolean = true;
        port powerOut : ElectricalPowerPort;
    }

    part def ChargingDock {
        attribute dockIdentifier : String = "FieldDock-01";
        attribute chargePower : Watt = 5000.0;
        attribute dockingTolerance : Meter = 0.10;
        port powerOut : ElectricalPowerPort;
        port statusIn : TelemetryPort;
    }

    part def DriveModule {
        attribute trackWidth : Meter = 0.85;
        attribute wheelBase : Meter = 1.15;
        attribute maximumSpeed : MeterPerSecond = 1.8;
        attribute minimumRowFollowingSpeed : MeterPerSecond = 0.15;
        attribute maximumSlope : Degree = 12.0;
        attribute groundClearance : Meter = 0.28;
        port mobilityCommand : MobilityCommandPort;
        port powerIn : ElectricalPowerPort;
    }

    part def SteeringController {
        attribute rowTrackingLateralErrorLimit : Meter = 0.05;
        attribute headingErrorLimit : Degree = 2.0;
        port localizationIn : LocalizationPort;
        port mobilityOut : MobilityCommandPort;
    }

    part def GnssReceiver {
        attribute updateRateHz : Real = 10.0;
        attribute expectedHorizontalAccuracy : Meter = 0.03;
        port localizationOut : LocalizationPort;
        port powerIn : ElectricalPowerPort;
    }

    part def InertialMeasurementUnit {
        attribute gyroBiasStability : Real = 0.5;
        attribute updateRateHz : Real = 100.0;
        port localizationOut : LocalizationPort;
        port powerIn : ElectricalPowerPort;
    }

    part def StereoCropCamera {
        attribute baseline : Meter = 0.12;
        attribute fieldOfView : Degree = 78.0;
        attribute minimumFocusDistance : Meter = 0.20;
        attribute frameRateHz : Real = 30.0;
        port imageOut : SensorImagePort;
        port powerIn : ElectricalPowerPort;
    }

    part def MultispectralCamera {
        attribute spectralBandCount : Count = 5;
        attribute groundSampleDistance : Meter = 0.008;
        attribute frameRateHz : Real = 10.0;
        port imageOut : SensorImagePort;
        port powerIn : ElectricalPowerPort;
    }

    part def SafetyLidar {
        attribute horizontalFieldOfView : Degree = 270.0;
        attribute detectionRange : Meter = 12.0;
        attribute minimumProtectiveStopDistance : Meter = 1.2;
        port lidarOut : LidarPort;
        port powerIn : ElectricalPowerPort;
    }

    part def PerceptionComputer {
        attribute processorPower : Watt = 85.0;
        attribute minimumWeedClassificationConfidence : Confidence = 0.82;
        attribute minimumCropClassificationConfidence : Confidence = 0.88;
        attribute maximumPlantLocalizationError : Meter = 0.02;
        port stereoImageIn : SensorImagePort;
        port multispectralImageIn : SensorImagePort;
        port lidarIn : LidarPort;
        port detectionOut : DetectionPort;
        port powerIn : ElectricalPowerPort;
    }

    part def WeedTreatmentEndEffector {
        attribute toolWorkingWidth : Meter = 0.08;
        attribute mechanicalCutDepth : Meter = 0.025;
        attribute microSprayNozzleFlow : LiterPerMinute = 0.12;
        attribute herbicideTankCapacity : Liter = 18.0;
        attribute remainingFluid : Liter = 18.0;
        attribute cropExclusionRadius : Meter = 0.06;
        attribute treatmentPlacementTolerance : Meter = 0.015;
        port treatmentInOut : TreatmentPort;
        port powerIn : ElectricalPowerPort;
    }

    part def OnboardMissionComputer {
        attribute missionIdentifier : String = "unassigned";
        attribute activePhase : MissionPhase = MissionPhase::notStarted;
        attribute safeStopRequested : Boolean = false;
        attribute weedCount : Count = 0;
        attribute treatedWeedCount : Count = 0;
        attribute estimatedCropDamage : Percent = 0.0;
        port commandIn : CommandPort;
        port planIn : MissionPlanPort;
        port statusOut : StatusPort;
        port localizationIn : LocalizationPort;
        port detectionIn : DetectionPort;
        port lidarIn : LidarPort;
        port mobilityOut : MobilityCommandPort;
        port treatmentOutIn : TreatmentPort;
        port powerIn : ElectricalPowerPort;
    }

    part def FarmManagementStation {
        attribute operatorName : String = "farm-operator";
        attribute missionLibrarySize : Count = 12;
        port telemetry : TelemetryPort;
        port missionPlanOut : MissionPlanPort;
    }

    action def InitializeAgriculturalRobot {
        in item command : RobotCommand;
        in item missionPlan : MissionPlan;
        out item initializedStatus : RobotStatus;

        action validateMission {
            in item missionPlan : MissionPlan;
            out item accepted : Boolean;
        }

        action checkBattery {
            out item sufficientEnergy : Boolean;
        }

        action calibrateSensors {
            out item calibrationComplete : Boolean;
        }

        action armTreatmentSystem {
            out item treatmentReady : Boolean;
        }

        first start;
        then validateMission;
        then checkBattery;
        then calibrateSensors;
        then armTreatmentSystem;
        then done;

        constraint {
            missionPlan.minimumWeedRemovalRate >= 90.0
        }

        constraint {
            missionPlan.maximumAllowedCropDamage <= 2.0
        }
    }

    action def NavigateCropRow {
        in item row : CropRow;
        in item currentPose : Pose2D;
        out item tractionCommand : TractionPower;
        out item rowComplete : Boolean;

        action computeRowCenterline {
            in item row : CropRow;
        }

        action estimateLateralOffset {
            in item currentPose : Pose2D;
            out item lateralError : Meter;
        }

        action commandLowSpeedRowFollowing {
            out item tractionCommand : TractionPower;
        }

        first start;
        then computeRowCenterline;
        then estimateLateralOffset;
        then commandLowSpeedRowFollowing;
        then done;

        constraint {
            tractionCommand.commandedSpeed <= 0.8
        }
    }

    action def DetectAndClassifyPlants {
        in item image : ImageFrame;
        in item scan : LidarScan;
        out item plantDetection : PlantDetection;
        out item weedTarget : WeedTarget;

        action segmentVegetation {
            in item image : ImageFrame;
        }

        action fuseDepthAndSpectralFeatures {
            in item scan : LidarScan;
        }

        action classifyCropOrWeed {
            out item plantDetection : PlantDetection;
        }

        action selectTreatableWeed {
            out item weedTarget : WeedTarget;
        }

        first start;
        then segmentVegetation;
        then fuseDepthAndSpectralFeatures;
        then classifyCropOrWeed;
        then selectTreatableWeed;
        then done;

        constraint {
            weedTarget.confidence >= 0.82
        }
    }

    action def ApplyWeedTreatment {
        in item weedTarget : WeedTarget;
        out item treatmentCommand : TreatmentCommand;
        out item treatmentResult : TreatmentResult;

        action positionApplicator {
            in item weedTarget : WeedTarget;
            out item placementError : Meter;
        }

        action chooseTreatmentMode {
            in item weedTarget : WeedTarget;
            out item treatmentCommand : TreatmentCommand;
        }

        action executeTreatment {
            in item treatmentCommand : TreatmentCommand;
            out item treatmentResult : TreatmentResult;
        }

        action verifyCropClearance {
            in item treatmentResult : TreatmentResult;
            out item cropSafe : Boolean;
        }

        first start;
        then positionApplicator;
        then chooseTreatmentMode;
        then executeTreatment;
        then verifyCropClearance;
        then done;

        constraint {
            treatmentResult.nearestCropDistance >= 0.06
        }
    }

    action def AvoidObstacle {
        in item obstacle : ObstacleReport;
        in item currentPose : Pose2D;
        out item tractionCommand : TractionPower;
        out item avoidanceComplete : Boolean;

        action stopBeforeObstacle {
            in item obstacle : ObstacleReport;
        }

        action computeBypassPath {
            in item currentPose : Pose2D;
        }

        action resumeRowPath {
            out item avoidanceComplete : Boolean;
        }

        first start;
        then stopBeforeObstacle;
        then computeBypassPath;
        then resumeRowPath;
        then done;

        constraint {
            obstacle.distance >= 0.0
        }
    }

    action def ExecutePrecisionWeedingMission {
        in item command : RobotCommand;
        in item missionPlan : MissionPlan;
        in item fieldBoundary : FieldBoundary;
        in item row : CropRow;
        out item status : RobotStatus;

        action initialize : InitializeAgriculturalRobot;
        action navigateRow : NavigateCropRow;
        action detectPlants : DetectAndClassifyPlants;
        action applyTreatment : ApplyWeedTreatment;
        action avoidObstacle : AvoidObstacle;

        first start;
        then initialize;
        then navigateRow;
        then detectPlants;
        then applyTreatment;
        then navigateRow;
        then done;

        constraint {
            status.cropDamageEstimate <= missionPlan.maximumAllowedCropDamage
        }
    }

    state def AgriculturalRobotOperatingStates {
        attribute phase : MissionPhase;

        state idle {
            entry action {
                phase = MissionPhase::notStarted;
            }
        }

        state initialized {
            entry action {
                phase = MissionPhase::initialized;
            }
        }

        state localizing {
            entry action {
                phase = MissionPhase::localizing;
            }
        }

        state traversingRow {
            entry action {
                phase = MissionPhase::traversingRow;
            }
        }

        state scanningCropZone {
            entry action {
                phase = MissionPhase::scanningCropZone;
            }
        }

        state treatingWeed {
            entry action {
                phase = MissionPhase::treatingWeed;
            }
        }

        state avoidingObstacle {
            entry action {
                phase = MissionPhase::avoidingObstacle;
            }
        }

        state returningToDock {
            entry action {
                phase = MissionPhase::returningToDock;
            }
        }

        state charging {
            entry action {
                phase = MissionPhase::charging;
            }
        }

        state complete {
            entry action {
                phase = MissionPhase::complete;
            }
        }

        state safeStopped {
            entry action {
                phase = MissionPhase::safeStopped;
            }
        }

        state faulted {
            entry action {
                phase = MissionPhase::faulted;
            }
        }

        transition startMission
            first idle
            accept RobotCommand
            if startCommand
            then initialized;

        transition localizationReady
            first initialized
            if true
            then localizing;

        transition poseConverged
            first localizing
            if true
            then traversingRow;

        transition cropZoneDetected
            first traversingRow
            if true
            then scanningCropZone;

        transition weedTargetConfirmed
            first scanningCropZone
            if true
            then treatingWeed;

        transition treatmentComplete
            first treatingWeed
            if true
            then traversingRow;

        transition obstacleDetected
            first traversingRow
            accept ObstacleReport
            if severity == Severity::warning or severity == Severity::critical
            then avoidingObstacle;

        transition obstacleCleared
            first avoidingObstacle
            if true
            then traversingRow;

        transition missionAreaComplete
            first traversingRow
            if true
            then returningToDock;

        transition docked
            first returningToDock
            if true
            then charging;

        transition chargeNotRequired
            first returningToDock
            if true
            then complete;

        transition chargeComplete
            first charging
            if true
            then complete;

        transition pauseRequested
            first traversingRow
            accept RobotCommand
            if pauseCommand
            then safeStopped;

        transition abortRequested
            first scanningCropZone
            accept RobotCommand
            if abortCommand
            then safeStopped;

        transition unrecoverableFault
            first treatingWeed
            accept FaultReport
            if not recoverable
            then faulted;
    }

    part def AgriculturalRobot {
        attribute robotIdentifier : String = "AgBot-PrecisionWeeder-01";
        attribute overallLength : Meter = 1.60;
        attribute overallWidth : Meter = 0.92;
        attribute overallHeight : Meter = 1.20;
        attribute mass : Kilogram = 180.0;
        attribute maximumOperationalSpeed : MeterPerSecond = 1.8;
        attribute nominalRowFollowingSpeed : MeterPerSecond = 0.45;
        attribute minimumCropClearance : Meter = 0.06;
        attribute expectedWeedRemovalRate : Percent = 94.0;
        attribute expectedCropDamageRate : Percent = 0.8;
        attribute activeMissionPhase : MissionPhase = MissionPhase::notStarted;

        port commandIn : CommandPort;
        port missionPlanIn : MissionPlanPort;
        port statusOut : StatusPort;
        port chargingPowerIn : ElectricalPowerPort;

        part battery : BatteryPack;
        part solarAssist : SolarAssistPanel;
        part drive : DriveModule;
        part steering : SteeringController;
        part gnss : GnssReceiver;
        part imu : InertialMeasurementUnit;
        part stereoCamera : StereoCropCamera;
        part multispectralCamera : MultispectralCamera;
        part safetyLidar : SafetyLidar;
        part perception : PerceptionComputer;
        part treatmentTool : WeedTreatmentEndEffector;
        part missionComputer : OnboardMissionComputer;

        connect chargingPowerIn to battery.powerOut;
        connect solarAssist.powerOut to battery.powerOut;

        connect battery.powerOut to drive.powerIn;
        connect battery.powerOut to gnss.powerIn;
        connect battery.powerOut to imu.powerIn;
        connect battery.powerOut to stereoCamera.powerIn;
        connect battery.powerOut to multispectralCamera.powerIn;
        connect battery.powerOut to safetyLidar.powerIn;
        connect battery.powerOut to perception.powerIn;
        connect battery.powerOut to treatmentTool.powerIn;
        connect battery.powerOut to missionComputer.powerIn;

        connect commandIn to missionComputer.commandIn;
        connect missionPlanIn to missionComputer.planIn;
        connect missionComputer.statusOut to statusOut;

        connect gnss.localizationOut to missionComputer.localizationIn;
        connect imu.localizationOut to missionComputer.localizationIn;
        connect gnss.localizationOut to steering.localizationIn;
        connect imu.localizationOut to steering.localizationIn;

        connect stereoCamera.imageOut to perception.stereoImageIn;
        connect multispectralCamera.imageOut to perception.multispectralImageIn;
        connect safetyLidar.lidarOut to perception.lidarIn;
        connect safetyLidar.lidarOut to missionComputer.lidarIn;

        connect perception.detectionOut to missionComputer.detectionIn;
        connect missionComputer.mobilityOut to steering.mobilityOut;
        connect steering.mobilityOut to drive.mobilityCommand;
        connect missionComputer.treatmentOutIn to treatmentTool.treatmentInOut;

        perform action primaryTask : ExecutePrecisionWeedingMission;
        exhibit state operatingStates : AgriculturalRobotOperatingStates;

        constraint massLimit {
            mass <= 250.0
        }

        constraint fieldSpeedLimit {
            nominalRowFollowingSpeed <= maximumOperationalSpeed
        }

        constraint cropProtectionGeometry {
            minimumCropClearance >= treatmentTool.cropExclusionRadius
        }

        constraint expectedPerformance {
            expectedWeedRemovalRate >= 90.0 and expectedCropDamageRate <= 2.0
        }
    }

    part def AgriculturalRoboticSystem {
        doc "Robotic system whose primary task is precision crop-row weeding performed by an AgriculturalRobot.";

        attribute systemIdentifier : String = "Agricultural-Robotic-System-Primary-Task-01";
        attribute assignedFieldArea : SquareMeter = 25000.0;
        attribute nominalMissionDuration : Second = 10800.0;
        attribute primaryTaskName : String = "Autonomous precision weed detection and treatment";

        part agriculturalRobot : AgriculturalRobot;
        part managementStation : FarmManagementStation;
        part chargingDock : ChargingDock;

        item field : FieldBoundary {
            attribute fieldIdentifier = "NorthField-A";
            attribute area = 25000.0;
            attribute minimumX = 0.0;
            attribute maximumX = 250.0;
            attribute minimumY = 0.0;
            attribute maximumY = 100.0;
        }

        item row01 : CropRow {
            attribute rowIdentifier = "Row-001";
            attribute rowStartX = 5.0;
            attribute rowStartY = 2.0;
            attribute rowEndX = 5.0;
            attribute rowEndY = 98.0;
            attribute nominalSpacing = 0.75;
            attribute cropKind = CropKind::soybean;
        }

        item baselineMissionPlan : MissionPlan {
            attribute missionIdentifier = "Mission-NorthField-A-Weeding-001";
            attribute targetCrop = CropKind::soybean;
            attribute targetArea = 25000.0;
            attribute rowCount = 132;
            attribute treatmentMode = WeedTreatmentMode::mechanicalCut;
            attribute plannedSpeed = 0.45;
            attribute maximumAllowedCropDamage = 2.0;
            attribute minimumWeedRemovalRate = 90.0;
        }

        connect managementStation.telemetry to agriculturalRobot.commandIn;
        connect managementStation.missionPlanOut to agriculturalRobot.missionPlanIn;
        connect agriculturalRobot.statusOut to managementStation.telemetry;
        connect chargingDock.powerOut to agriculturalRobot.chargingPowerIn;
        connect agriculturalRobot.statusOut to chargingDock.statusIn;

        perform action systemPrimaryTask : ExecutePrecisionWeedingMission;

        constraint assignedAreaConsistency {
            assignedFieldArea == field.area
        }

        constraint missionDurationFeasibility {
            nominalMissionDuration <= 14400.0
        }
    }

    requirement def PrimaryTaskUsesAgriculturalRobotRequirement {
        doc "The robotic system shall perform its primary task using an AgriculturalRobot.";
        subject system : AgriculturalRoboticSystem;

        require constraint {
            system.agriculturalRobot.expectedWeedRemovalRate >= 90.0
        }

        require constraint {
            system.agriculturalRobot.expectedCropDamageRate <= 2.0
        }

        require constraint {
            system.systemPrimaryTask == system.agriculturalRobot.primaryTask
        }
    }

    requirement def AutonomousRowNavigationRequirement {
        doc "The AgriculturalRobot shall autonomously navigate crop rows while maintaining lateral row-following error within 0.05 m during treatment operations.";
        subject robot : AgriculturalRobot;

        require constraint {
            robot.steering.rowTrackingLateralErrorLimit <= 0.05
        }

        require constraint {
            robot.nominalRowFollowingSpeed >= 0.15 and robot.nominalRowFollowingSpeed <= 0.8
        }
    }

    requirement def WeedDetectionRequirement {
        doc "The AgriculturalRobot shall classify weed targets with confidence sufficient for autonomous treatment.";
        subject robot : AgriculturalRobot;

        require constraint {
            robot.perception.minimumWeedClassificationConfidence >= 0.82
        }

        require constraint {
            robot.perception.maximumPlantLocalizationError <= 0.02
        }
    }

    requirement def CropProtectionRequirement {
        doc "The AgriculturalRobot shall avoid damaging crop plants while applying weed treatment.";
        subject robot : AgriculturalRobot;

        require constraint {
            robot.minimumCropClearance >= 0.06
        }

        require constraint {
            robot.treatmentTool.treatmentPlacementTolerance <= 0.015
        }

        require constraint {
            robot.expectedCropDamageRate <= 2.0
        }
    }

    requirement def EnergyRequirement {
        doc "The AgriculturalRobot shall have sufficient onboard energy to complete planned field operations or return safely to the charging dock.";
        subject robot : AgriculturalRobot;

        require constraint {
            robot.battery.capacity >= 100.0
        }

        require constraint {
            robot.battery.minimumOperationalStateOfCharge >= 10.0
        }

        require constraint {
            robot.battery.maximumContinuousPower >= 3500.0
        }
    }

    requirement def SafetyObstacleRequirement {
        doc "The AgriculturalRobot shall detect obstacles and initiate protective stopping or avoidance before violating the minimum protective stop distance.";
        subject robot : AgriculturalRobot;

        require constraint {
            robot.safetyLidar.detectionRange >= 10.0
        }

        require constraint {
            robot.safetyLidar.minimumProtectiveStopDistance >= 1.0
        }

        require constraint {
            robot.maximumOperationalSpeed <= 2.0
        }
    }

    requirement def FieldMissionPlanningRequirement {
        doc "The AgriculturalRoboticSystem shall accept a mission plan containing field boundary, crop row, target crop, treatment mode, and performance limits.";
        subject system : AgriculturalRoboticSystem;

        require constraint {
            system.baselineMissionPlan.targetArea == system.field.area
        }

        require constraint {
            system.baselineMissionPlan.maximumAllowedCropDamage <= 2.0
        }

        require constraint {
            system.baselineMissionPlan.minimumWeedRemovalRate >= 90.0
        }
    }

    satisfy PrimaryTaskUsesAgriculturalRobotRequirement by AgriculturalRoboticSystem::agriculturalRobot;
    satisfy AutonomousRowNavigationRequirement by AgriculturalRobot::steering;
    satisfy WeedDetectionRequirement by AgriculturalRobot::perception;
    satisfy CropProtectionRequirement by AgriculturalRobot::treatmentTool;
    satisfy EnergyRequirement by AgriculturalRobot::battery;
    satisfy SafetyObstacleRequirement by AgriculturalRobot::safetyLidar;
    satisfy FieldMissionPlanningRequirement by AgriculturalRoboticSystem::managementStation;

    part agriculturalRoboticSystem : AgriculturalRoboticSystem;

}
