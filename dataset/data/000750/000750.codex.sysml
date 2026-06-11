package ROTIGS_System_Model {
    import ScalarValues::*;

    value def Volt {
        attribute symbol : String = "V";
    }

    value def Ampere {
        attribute symbol : String = "A";
    }

    value def Watt {
        attribute symbol : String = "W";
    }

    value def Meter {
        attribute symbol : String = "m";
    }

    value def MeterPerSecond {
        attribute symbol : String = "m/s";
    }

    value def Degree {
        attribute symbol : String = "deg";
    }

    value def Percent {
        attribute symbol : String = "%";
    }

    value def Second {
        attribute symbol : String = "s";
    }

    value def Celsius {
        attribute symbol : String = "degC";
    }

    value def NewtonMeter {
        attribute symbol : String = "N*m";
    }

    attribute def Voltage {
        :>> unit = Volt;
        :>> quantityKind = "electric potential";
    }

    attribute def Current {
        :>> unit = Ampere;
        :>> quantityKind = "electric current";
    }

    attribute def Power {
        :>> unit = Watt;
        :>> quantityKind = "power";
    }

    attribute def Distance {
        :>> unit = Meter;
        :>> quantityKind = "length";
    }

    attribute def Speed {
        :>> unit = MeterPerSecond;
        :>> quantityKind = "speed";
    }

    attribute def Angle {
        :>> unit = Degree;
        :>> quantityKind = "plane angle";
    }

    attribute def Ratio {
        :>> unit = Percent;
        :>> quantityKind = "dimensionless ratio";
    }

    attribute def Duration {
        :>> unit = Second;
        :>> quantityKind = "time";
    }

    attribute def Temperature {
        :>> unit = Celsius;
        :>> quantityKind = "temperature";
    }

    attribute def Torque {
        :>> unit = NewtonMeter;
        :>> quantityKind = "torque";
    }

    enum def MissionMode {
        enum idle;
        enum teleoperated;
        enum autonomousSurvey;
        enum targetInspection;
        enum returnToBase;
        enum emergencyStop;
    }

    enum def LinkState {
        enum disconnected;
        enum degraded;
        enum nominal;
        enum encrypted;
    }

    enum def HealthState {
        enum nominal;
        enum warning;
        enum fault;
        enum critical;
    }

    enum def TerrainClass {
        enum paved;
        enum gravel;
        enum soil;
        enum sand;
        enum rubble;
        enum indoor;
    }

    item def MissionCommand {
        attribute requestedMode : MissionMode;
        attribute targetLatitude : Real;
        attribute targetLongitude : Real;
        attribute inspectionRadius : Distance;
        attribute maximumSpeed : Speed;
        attribute operatorAuthorized : Boolean;
    }

    item def NavigationEstimate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute heading : Angle;
        attribute positionUncertainty : Distance;
        attribute speed : Speed;
        attribute terrain : TerrainClass;
    }

    item def VideoFrame {
        attribute frameRate : Real;
        attribute horizontalFieldOfView : Angle;
        attribute verticalFieldOfView : Angle;
        attribute latency : Duration;
        attribute encrypted : Boolean;
    }

    item def SensorReport {
        attribute rangeToObject : Distance;
        attribute bearingToObject : Angle;
        attribute confidence : Ratio;
        attribute thermalContrast : Temperature;
        attribute obstacleDetected : Boolean;
    }

    item def HealthReport {
        attribute batteryStateOfCharge : Ratio;
        attribute tractionHealth : HealthState;
        attribute computeHealth : HealthState;
        attribute sensorHealth : HealthState;
        attribute communicationHealth : HealthState;
        attribute internalTemperature : Temperature;
    }

    item def ElectricalEnergyFlow {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def DriveCommand {
        attribute leftTrackTorque : Torque;
        attribute rightTrackTorque : Torque;
        attribute commandedSpeed : Speed;
        attribute commandedTurnRate : Angle;
    }

    item def StopCommand {
        attribute immediate : Boolean;
        attribute reason : String;
    }

    port def CommandPort {
        in item command : MissionCommand;
        in item stop : StopCommand;
    }

    port def TelemetryPort {
        out item navigation : NavigationEstimate;
        out item health : HealthReport;
        out item sensorReport : SensorReport;
        out item video : VideoFrame;
    }

    port def PowerPort {
        in item electricalInput : ElectricalEnergyFlow;
        out item electricalStatus : ElectricalEnergyFlow;
    }

    port def DriveControlPort {
        in item driveCommand : DriveCommand;
        out item odometry : NavigationEstimate;
    }

    port def SensorDataPort {
        out item navigationEstimate : NavigationEstimate;
        out item sensorReport : SensorReport;
        out item videoFrame : VideoFrame;
    }

    port def InternalHealthPort {
        out item healthReport : HealthReport;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 48;
        attribute maximumCurrent : Current = 120;
        attribute peakPower : Power = 5760;
        attribute usableEnergyPercent : Ratio = 92;
        attribute stateOfCharge : Ratio;
        attribute minimumOperationalCharge : Ratio = 15;
        port powerOut : PowerPort;
        port healthOut : InternalHealthPort;
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : Voltage = 48;
        attribute regulatedBusVoltage : Voltage = 24;
        attribute maximumContinuousPower : Power = 3000;
        port batteryInput : PowerPort;
        port computePower : PowerPort;
        port sensorPower : PowerPort;
        port drivePower : PowerPort;
        port healthOut : InternalHealthPort;
    }

    part def TrackedMobilityBase {
        attribute maximumSpeed : Speed = 2.5;
        attribute minimumTurningRadius : Distance = 0.0;
        attribute obstacleClimbHeight : Distance = 0.30;
        attribute slopeCapability : Angle = 35;
        attribute leftTrackTorqueLimit : Torque = 180;
        attribute rightTrackTorqueLimit : Torque = 180;
        port driveControl : DriveControlPort;
        port powerIn : PowerPort;
        port healthOut : InternalHealthPort;
    }

    part def SensorMast {
        attribute mastHeight : Distance = 1.2;
        attribute panRange : Angle = 360;
        attribute tiltRange : Angle = 120;
        attribute lidarRange : Distance = 80;
        attribute thermalDetectionRange : Distance = 60;
        port sensorData : SensorDataPort;
        port powerIn : PowerPort;
        port healthOut : InternalHealthPort;
    }

    part def EdgeComputeModule {
        attribute processorUtilization : Ratio;
        attribute nominalPowerDraw : Power = 85;
        attribute maximumOperatingTemperature : Temperature = 75;
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        port sensorIn : SensorDataPort;
        port driveOut : DriveControlPort;
        port powerIn : PowerPort;
        port healthOut : InternalHealthPort;
    }

    part def SecureRadioModule {
        attribute maximumLineOfSightRange : Distance = 2000;
        attribute nominalDataRateMbps : Real = 25;
        attribute commandLatency : Duration = 0.20;
        attribute linkState : LinkState;
        port operatorCommand : CommandPort;
        port operatorTelemetry : TelemetryPort;
        port computeCommand : CommandPort;
        port computeTelemetry : TelemetryPort;
        port powerIn : PowerPort;
        port healthOut : InternalHealthPort;
    }

    part def OperatorControlUnit {
        attribute displayRefreshRateHz : Real = 60;
        attribute operatorPresent : Boolean;
        attribute authenticated : Boolean;
        port missionCommandOut : CommandPort;
        port telemetryIn : TelemetryPort;
    }

    part def ROTIGS {
        attribute name : String = "Remote Operated Tactical Inspection Ground System";
        attribute primaryFunction : String = "Provide remotely supervised ground mobility, sensing, inspection, and telemetry for hazardous or inaccessible areas while keeping the operator at a safe standoff distance.";
        attribute nominalMissionDuration : Duration = 7200;
        attribute maximumOperatingRange : Distance = 2000;
        attribute commandedMode : MissionMode = MissionMode::idle;
        attribute overallHealth : HealthState = HealthState::nominal;

        port externalCommand : CommandPort;
        port externalTelemetry : TelemetryPort;

        part operatorStation : OperatorControlUnit;
        part battery : BatteryPack;
        part powerDistribution : PowerDistributionUnit;
        part mobilityBase : TrackedMobilityBase;
        part sensorMast : SensorMast;
        part computeModule : EdgeComputeModule;
        part radioModule : SecureRadioModule;

        connect operatorStation.missionCommandOut to radioModule.operatorCommand;
        connect radioModule.computeCommand to computeModule.commandIn;
        connect computeModule.telemetryOut to radioModule.computeTelemetry;
        connect radioModule.operatorTelemetry to operatorStation.telemetryIn;

        connect externalCommand to radioModule.operatorCommand;
        connect radioModule.operatorTelemetry to externalTelemetry;

        connect battery.powerOut to powerDistribution.batteryInput;
        connect powerDistribution.computePower to computeModule.powerIn;
        connect powerDistribution.sensorPower to sensorMast.powerIn;
        connect powerDistribution.drivePower to mobilityBase.powerIn;
        connect computeModule.sensorIn to sensorMast.sensorData;
        connect computeModule.driveOut to mobilityBase.driveControl;
    }

    action def AcceptMissionCommand {
        in item command : MissionCommand;
        out item accepted : Boolean;
        out item selectedMode : MissionMode;

        action validateAuthorization;
        action validateTarget;
        action selectMode;

        first start;
        then validateAuthorization;
        then validateTarget;
        then selectMode;
        then done;
    }

    action def GenerateNavigationPlan {
        in item currentPose : NavigationEstimate;
        in item command : MissionCommand;
        out item plannedSpeed : Speed;
        out item plannedHeading : Angle;
        out item safeToProceed : Boolean;

        action evaluateTerrain;
        action detectObstacles;
        action computeSafeHeading;
        action limitSpeed;

        first start;
        then evaluateTerrain;
        then detectObstacles;
        then computeSafeHeading;
        then limitSpeed;
        then done;
    }

    action def InspectTargetArea {
        in item command : MissionCommand;
        in item navigation : NavigationEstimate;
        out item report : SensorReport;
        out item video : VideoFrame;

        action positionMast;
        action scanVisibleBand;
        action scanThermalBand;
        action classifyFindings;
        action transmitEvidence;

        first start;
        then positionMast;
        then scanVisibleBand;
        then scanThermalBand;
        then classifyFindings;
        then transmitEvidence;
        then done;
    }

    action def ExecuteEmergencyStop {
        in item stop : StopCommand;
        out item driveCommand : DriveCommand;
        out item stopped : Boolean;

        action cutTractionCommand;
        action holdBrake;
        action broadcastStopState;

        first start;
        then cutTractionCommand;
        then holdBrake;
        then broadcastStopState;
        then done;
    }

    state def ROTIGSOperationalStateMachine {
        entry action initializeSystem;

        state PoweredOff;
        state Initializing;
        state Ready;
        state Teleoperated;
        state AutonomousSurvey;
        state TargetInspection;
        state ReturnToBase;
        state FaultManagement;
        state EmergencyStopped;
        state Shutdown;

        transition first PoweredOff;
        transition powerApplied from PoweredOff to Initializing;
        transition initializationComplete from Initializing to Ready;
        transition teleoperationRequested from Ready to Teleoperated;
        transition surveyRequested from Ready to AutonomousSurvey;
        transition inspectionRequested from Ready to TargetInspection;
        transition returnRequested from Teleoperated to ReturnToBase;
        transition returnRequestedFromSurvey from AutonomousSurvey to ReturnToBase;
        transition returnRequestedFromInspection from TargetInspection to ReturnToBase;
        transition missionComplete from ReturnToBase to Ready;
        transition faultDetectedFromReady from Ready to FaultManagement;
        transition faultDetectedFromTeleop from Teleoperated to FaultManagement;
        transition faultDetectedFromSurvey from AutonomousSurvey to FaultManagement;
        transition faultDetectedFromInspection from TargetInspection to FaultManagement;
        transition stopRequestedFromAny from Ready to EmergencyStopped;
        transition resetAfterStop from EmergencyStopped to Ready;
        transition unrecoverableFault from FaultManagement to Shutdown;
        transition operatorShutdown from Ready to Shutdown;
    }

    requirement def PrimaryFunctionRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.primaryFunction == "Provide remotely supervised ground mobility, sensing, inspection, and telemetry for hazardous or inaccessible areas while keeping the operator at a safe standoff distance."
        }
    }

    requirement def StandoffOperationRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.maximumOperatingRange >= 1000
        }
    }

    requirement def MissionDurationRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.nominalMissionDuration >= 3600
        }
    }

    requirement def LowBatteryReturnRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.battery.minimumOperationalCharge >= 10
        }
    }

    requirement def MobilityRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.mobilityBase.maximumSpeed >= 1.5 and
            rotigs.mobilityBase.obstacleClimbHeight >= 0.20 and
            rotigs.mobilityBase.slopeCapability >= 25
        }
    }

    requirement def SensorCoverageRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.sensorMast.lidarRange >= 50 and
            rotigs.sensorMast.panRange >= 360 and
            rotigs.sensorMast.thermalDetectionRange >= 40
        }
    }

    requirement def SecureLinkRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.radioModule.commandLatency <= 0.50 and
            rotigs.radioModule.maximumLineOfSightRange >= 1000
        }
    }

    requirement def EmergencyStopRequirement {
        subject rotigs : ROTIGS;
        require constraint {
            rotigs.commandedMode != MissionMode::emergencyStop or
            rotigs.overallHealth != HealthState::critical
        }
    }

    part rotigsSystem : ROTIGS;

    satisfy PrimaryFunctionRequirement by rotigsSystem;
    satisfy StandoffOperationRequirement by rotigsSystem;
    satisfy MissionDurationRequirement by rotigsSystem;
    satisfy LowBatteryReturnRequirement by rotigsSystem;
    satisfy MobilityRequirement by rotigsSystem;
    satisfy SensorCoverageRequirement by rotigsSystem;
    satisfy SecureLinkRequirement by rotigsSystem;
    satisfy EmergencyStopRequirement by rotigsSystem;
}