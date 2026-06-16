package DeliveryRobotSystemModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Mass :> ISQ::mass;
    attribute def Length :> ISQ::length;
    attribute def Area :> ISQ::area;
    attribute def Volume :> ISQ::volume;
    attribute def Time :> ISQ::time;
    attribute def Speed :> ISQ::speed;
    attribute def Acceleration :> ISQ::acceleration;
    attribute def Energy :> ISQ::energy;
    attribute def Power :> ISQ::power;
    attribute def ElectricPotential :> ISQ::electricPotential;
    attribute def ElectricCurrent :> ISQ::electricCurrent;
    attribute def Frequency :> ISQ::frequency;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Angle :> ISQ::planeAngle;
    attribute def Distance :> ISQ::length;
    attribute def Percentage :> Real;
    attribute def CurrencyAmount :> Real;
    attribute def Identifier :> String;
    attribute def Text :> String;

    enum def MissionPriority {
        standard;
        urgent;
        medical;
        returnOnly;
    }

    enum def RobotMode {
        off;
        initializing;
        idle;
        assigned;
        navigatingToPickup;
        loading;
        navigatingToDestination;
        recipientVerification;
        unloading;
        returningToBase;
        charging;
        maintenance;
        fault;
        emergencyStopped;
    }

    enum def ParcelCondition {
        accepted;
        secured;
        damaged;
        delivered;
        returned;
    }

    enum def CommandKind {
        assignMission;
        cancelMission;
        pause;
        resume;
        returnToBase;
        emergencyStop;
        releaseParcel;
        beginCharging;
        runDiagnostics;
    }

    enum def FaultSeverity {
        advisory;
        recoverable;
        degradedOperation;
        critical;
    }

    item def Location {
        attribute latitudeDeg : Real;
        attribute longitudeDeg : Real;
        attribute altitude : Length;
        attribute horizontalUncertainty : Distance;
    }

    item def GeoFence {
        attribute fenceId : Identifier;
        attribute center : Location;
        attribute radius : Distance;
        attribute speedLimit : Speed;
        attribute pedestrianPriority : Boolean;
    }

    item def Parcel {
        attribute parcelId : Identifier;
        attribute recipientId : Identifier;
        attribute destination : Location;
        attribute pickupLocation : Location;
        attribute mass : Mass;
        attribute volume : Volume;
        attribute declaredValue : CurrencyAmount;
        attribute temperatureSensitive : Boolean;
        attribute minimumTemperature : Temperature;
        attribute maximumTemperature : Temperature;
        attribute condition : ParcelCondition;
    }

    item def DeliveryOrder {
        attribute orderId : Identifier;
        attribute priority : MissionPriority;
        attribute requestedPickupTime : Time;
        attribute promisedDeliveryTime : Time;
        attribute pickupLocation : Location;
        attribute deliveryLocation : Location;
        attribute parcelMass : Mass;
        attribute parcelVolume : Volume;
        attribute recipientCredentialHash : Identifier;
    }

    item def DeliveryReceipt {
        attribute orderId : Identifier;
        attribute parcelId : Identifier;
        attribute delivered : Boolean;
        attribute deliveryTime : Time;
        attribute deliveryLocation : Location;
        attribute recipientVerified : Boolean;
        attribute proofImageId : Identifier;
        attribute finalCondition : ParcelCondition;
    }

    item def RobotCommand {
        attribute commandId : Identifier;
        attribute kind : CommandKind;
        attribute targetOrderId : Identifier;
        attribute issuedTime : Time;
        attribute validFor : Time;
    }

    item def RobotStatus {
        attribute robotId : Identifier;
        attribute mode : RobotMode;
        attribute pose : Location;
        attribute speed : Speed;
        attribute batteryStateOfCharge : Percentage;
        attribute cargoOccupied : Boolean;
        attribute activeOrderId : Identifier;
        attribute faultActive : Boolean;
        attribute message : Text;
    }

    item def DiagnosticReport {
        attribute robotId : Identifier;
        attribute generatedTime : Time;
        attribute faultActive : Boolean;
        attribute severity : FaultSeverity;
        attribute subsystemName : Text;
        attribute diagnosticCode : Identifier;
        attribute recommendedAction : Text;
    }

    item def MapData {
        attribute mapId : Identifier;
        attribute revision : Identifier;
        attribute routeLength : Distance;
        attribute maxSlope : Angle;
        attribute includesConstructionHazard : Boolean;
    }

    item def RoutePlan {
        attribute routeId : Identifier;
        attribute start : Location;
        attribute destination : Location;
        attribute plannedDistance : Distance;
        attribute estimatedTravelTime : Time;
        attribute expectedEnergyUse : Energy;
        attribute minimumClearance : Length;
        attribute obeysGeofence : Boolean;
    }

    item def ObstacleTrack {
        attribute trackId : Identifier;
        attribute relativeBearing : Angle;
        attribute range : Distance;
        attribute relativeSpeed : Speed;
        attribute collisionRisk : Percentage;
        attribute pedestrianClassified : Boolean;
    }

    item def PerceptionFrame {
        attribute frameId : Identifier;
        attribute acquisitionTime : Time;
        attribute nearestObstacleDistance : Distance;
        attribute pedestrianDetected : Boolean;
        attribute curbDetected : Boolean;
        attribute localizationConfidence : Percentage;
    }

    item def MotionCommand {
        attribute targetSpeed : Speed;
        attribute targetHeading : Angle;
        attribute maximumAcceleration : Acceleration;
        attribute brakeRequest : Boolean;
    }

    item def DriveTelemetry {
        attribute leftWheelSpeed : Speed;
        attribute rightWheelSpeed : Speed;
        attribute motorTemperature : Temperature;
        attribute tractionLimited : Boolean;
    }

    item def ElectricalPowerFlow {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def ChargingStatus {
        attribute connected : Boolean;
        attribute chargeRate : Power;
        attribute estimatedTimeToFull : Time;
        attribute batteryTemperature : Temperature;
    }

    item def AuthenticationToken {
        attribute recipientId : Identifier;
        attribute orderId : Identifier;
        attribute tokenHash : Identifier;
        attribute validUntil : Time;
    }

    port def DataPort {
        in item incoming : RobotCommand;
        in item incomingOrder : DeliveryOrder;
        in item incomingMap : MapData;
        out item outgoingStatus : RobotStatus;
        out item outgoingReceipt : DeliveryReceipt;
        out item outgoingDiagnostic : DiagnosticReport;
    }

    port def MissionPort {
        in item order : DeliveryOrder;
        in item command : RobotCommand;
        out item status : RobotStatus;
        out item receipt : DeliveryReceipt;
    }

    port def ParcelPort {
        in item receivedParcel : Parcel;
        out item releasedParcel : Parcel;
    }

    port def ChargingPort {
        in item chargingPower : ElectricalPowerFlow;
        out item chargingStatus : ChargingStatus;
    }

    port def PowerPort {
        in item suppliedPower : ElectricalPowerFlow;
        out item consumedPower : ElectricalPowerFlow;
    }

    port def SensorDataPort {
        out item perception : PerceptionFrame;
        out item obstacle : ObstacleTrack;
    }

    port def MotionPort {
        in item motionCommand : MotionCommand;
        out item driveTelemetry : DriveTelemetry;
    }

    port def NavigationPort {
        in item map : MapData;
        in item order : DeliveryOrder;
        out item route : RoutePlan;
        out item motion : MotionCommand;
    }

    port def AuthenticationPort {
        in item token : AuthenticationToken;
        out item receipt : DeliveryReceipt;
    }

    part def DispatchCenter {
        attribute centerId : Identifier;
        attribute operatorAvailable : Boolean;
        attribute maximumAssignedRobots : Integer;
        port networkPort : DataPort;
        perform action issueMission : IssueDeliveryMission;
        perform action monitorFleet : MonitorRobotStatus;
    }

    part def CloudFleetManager {
        attribute activeMissionCount : Integer;
        attribute routeReplanPeriod : Time;
        attribute minimumRobotBatteryForAssignment : Percentage;
        port dispatchPort : DataPort;
        port robotPort : DataPort;
        perform action assignDeliveryRobot : AssignDeliveryRobot;
        perform action updateMaps : UpdateOperationalMap;
    }

    part def LoadingDock {
        attribute dockId : Identifier;
        attribute location : Location;
        attribute loadingHeight : Length;
        attribute maximumParcelMass : Mass;
        port parcelPort : ParcelPort;
        port missionPort : MissionPort;
        perform action stageParcel : StageParcelForRobot;
    }

    part def RecipientDropBox {
        attribute boxId : Identifier;
        attribute location : Location;
        attribute compartmentVolume : Volume;
        attribute locked : Boolean;
        port parcelPort : ParcelPort;
        port authenticationPort : AuthenticationPort;
        perform action acceptDeliveredParcel : AcceptParcel;
    }

    part def ChargingStation {
        attribute stationId : Identifier;
        attribute location : Location;
        attribute maximumChargePower : Power;
        attribute outputVoltage : ElectricPotential;
        attribute available : Boolean;
        port chargingPort : ChargingPort;
        perform action provideCharge : ProvideChargingPower;
    }

    part def BatteryPack {
        attribute capacity : Energy;
        attribute stateOfCharge : Percentage;
        attribute reserveThreshold : Percentage;
        attribute nominalVoltage : ElectricPotential;
        attribute maximumDischargePower : Power;
        attribute maximumChargePower : Power;
        attribute temperature : Temperature;
        port powerPort : PowerPort;
        port chargingPort : ChargingPort;
        perform action supplyElectricalPower : SupplyElectricalPower;
        perform action acceptChargingPower : AcceptChargingPower;
    }

    part def PowerDistributionUnit {
        attribute busVoltage : ElectricPotential;
        attribute peakPowerLimit : Power;
        attribute protectedByFuse : Boolean;
        port batteryPower : PowerPort;
        port drivePower : PowerPort;
        port computePower : PowerPort;
        port manipulatorPower : PowerPort;
        port sensorPower : PowerPort;
    }

    part def DriveTrain {
        attribute maximumSpeed : Speed;
        attribute nominalCruiseSpeed : Speed;
        attribute maximumSlope : Angle;
        attribute wheelDiameter : Length;
        attribute trackWidth : Length;
        attribute brakingDistanceAtCruise : Distance;
        port powerPort : PowerPort;
        port motionPort : MotionPort;
        perform action executeMotionCommand : ExecuteMotionCommand;
        perform action brakeToStop : BrakeToSafeStop;
    }

    part def LidarSensor {
        attribute horizontalFieldOfView : Angle;
        attribute maximumRange : Distance;
        attribute scanFrequency : Frequency;
        attribute rangeAccuracy : Distance;
        port powerPort : PowerPort;
        port sensorPort : SensorDataPort;
        perform action scanEnvironment : ScanEnvironment;
    }

    part def CameraArray {
        attribute cameraCount : Integer;
        attribute horizontalFieldOfView : Angle;
        attribute frameRate : Frequency;
        attribute minimumIllumination : Real;
        port powerPort : PowerPort;
        port sensorPort : SensorDataPort;
        perform action captureImages : CaptureImages;
    }

    part def UltrasonicRing {
        attribute sensorCount : Integer;
        attribute maximumRange : Distance;
        attribute minimumRange : Distance;
        port powerPort : PowerPort;
        port sensorPort : SensorDataPort;
        perform action detectNearObstacles : DetectNearObstacles;
    }

    part def PerceptionSuite {
        part lidar : LidarSensor {
            attribute horizontalFieldOfView = 270 [deg];
            attribute maximumRange = 40 [m];
            attribute scanFrequency = 10 [Hz];
            attribute rangeAccuracy = 0.03 [m];
        }
        part cameras : CameraArray {
            attribute cameraCount = 4;
            attribute horizontalFieldOfView = 360 [deg];
            attribute frameRate = 30 [Hz];
        }
        part ultrasonics : UltrasonicRing {
            attribute sensorCount = 12;
            attribute maximumRange = 3 [m];
            attribute minimumRange = 0.05 [m];
        }
        port powerPort : PowerPort;
        port sensorPort : SensorDataPort;
        perform action fuseSensorData : FusePerceptionData;
        connection lidarPower connect powerPort to lidar.powerPort;
        connection cameraPower connect powerPort to cameras.powerPort;
        connection ultrasonicPower connect powerPort to ultrasonics.powerPort;
        connection lidarData connect lidar.sensorPort to sensorPort;
        connection cameraData connect cameras.sensorPort to sensorPort;
        connection ultrasonicData connect ultrasonics.sensorPort to sensorPort;
    }

    part def LocalizationUnit {
        attribute gnssAccuracy : Distance;
        attribute deadReckoningDriftPerMeter : Percentage;
        attribute poseUpdateRate : Frequency;
        port powerPort : PowerPort;
        port sensorPort : SensorDataPort;
        perform action estimatePose : EstimateRobotPose;
    }

    part def NavigationComputer {
        attribute processorName : Text;
        attribute routeReplanPeriod : Time;
        attribute minimumObstacleClearance : Distance;
        attribute maximumLocalizationUncertainty : Distance;
        port powerPort : PowerPort;
        port navigationPort : NavigationPort;
        port sensorPort : SensorDataPort;
        port motionPort : MotionPort;
        perform action computeRoute : ComputeRoutePlan;
        perform action avoidObstacle : AvoidObstacle;
        perform action generateMotionCommand : GenerateMotionCommand;
    }

    part def CargoBay {
        attribute internalVolume : Volume;
        attribute maximumPayloadMass : Mass;
        attribute doorOpen : Boolean;
        attribute parcelSecured : Boolean;
        attribute temperatureControlled : Boolean;
        attribute currentTemperature : Temperature;
        port parcelPort : ParcelPort;
        port powerPort : PowerPort;
        perform action secureParcel : SecureParcel;
        perform action releaseParcel : ReleaseParcel;
        perform action monitorParcelCondition : MonitorParcelCondition;
    }

    part def Manipulator {
        attribute maximumLiftMass : Mass;
        attribute reach : Length;
        attribute positioningAccuracy : Length;
        attribute gripperOpening : Length;
        port powerPort : PowerPort;
        port parcelPort : ParcelPort;
        perform action loadParcel : LoadParcel;
        perform action unloadParcel : UnloadParcel;
    }

    part def CommunicationsModule {
        attribute cellularAvailable : Boolean;
        attribute wifiAvailable : Boolean;
        attribute updatePeriod : Time;
        attribute maximumLatency : Time;
        port powerPort : PowerPort;
        port externalDataPort : DataPort;
        port internalMissionPort : MissionPort;
        perform action transmitStatus : TransmitStatus;
        perform action receiveCommand : ReceiveCommand;
    }

    part def SafetyController {
        attribute emergencyStopActive : Boolean;
        attribute minimumPedestrianClearance : Distance;
        attribute maximumSafeSpeedNearPedestrian : Speed;
        attribute diagnosticInterval : Time;
        port powerPort : PowerPort;
        port sensorPort : SensorDataPort;
        port motionPort : MotionPort;
        port missionPort : MissionPort;
        perform action evaluateSafety : EvaluateSafety;
        perform action commandEmergencyStop : CommandEmergencyStop;
        perform action runDiagnostics : RunDiagnostics;
    }

    part def DeliveryRobot {
        attribute robotId : Identifier;
        attribute curbMass : Mass;
        attribute maximumPayloadMass : Mass;
        attribute maximumPayloadVolume : Volume;
        attribute maximumSpeed : Speed;
        attribute nominalCruiseSpeed : Speed;
        attribute minimumTurningRadius : Length;
        attribute operatingTemperatureMin : Temperature;
        attribute operatingTemperatureMax : Temperature;
        attribute missionSuccessRate : Percentage;
        attribute availability : Percentage;
        attribute currentMode : RobotMode;
        attribute activeOrderId : Identifier;

        port missionPort : MissionPort;
        port dataPort : DataPort;
        port chargingPort : ChargingPort;
        port pickupParcelPort : ParcelPort;
        port deliveryParcelPort : ParcelPort;

        part battery : BatteryPack {
            attribute capacity = 2.4 [kW*h];
            attribute stateOfCharge = 100.0;
            attribute reserveThreshold = 20.0;
            attribute nominalVoltage = 48 [V];
            attribute maximumDischargePower = 1200 [W];
            attribute maximumChargePower = 800 [W];
        }

        part powerDistribution : PowerDistributionUnit {
            attribute busVoltage = 48 [V];
            attribute peakPowerLimit = 1500 [W];
            attribute protectedByFuse = true;
        }

        part driveTrain : DriveTrain {
            attribute maximumSpeed = 2.0 [m/s];
            attribute nominalCruiseSpeed = 1.2 [m/s];
            attribute maximumSlope = 10 [deg];
            attribute wheelDiameter = 0.25 [m];
            attribute trackWidth = 0.55 [m];
            attribute brakingDistanceAtCruise = 0.75 [m];
        }

        part perception : PerceptionSuite;
        part localization : LocalizationUnit {
            attribute gnssAccuracy = 1.5 [m];
            attribute deadReckoningDriftPerMeter = 0.5;
            attribute poseUpdateRate = 20 [Hz];
        }

        part navigationComputer : NavigationComputer {
            attribute processorName = "ruggedized autonomous navigation computer";
            attribute routeReplanPeriod = 1 [s];
            attribute minimumObstacleClearance = 0.6 [m];
            attribute maximumLocalizationUncertainty = 2.0 [m];
        }

        part cargoBay : CargoBay {
            attribute internalVolume = 0.12 [m^3];
            attribute maximumPayloadMass = 15 [kg];
            attribute doorOpen = false;
            attribute parcelSecured = false;
            attribute temperatureControlled = true;
            attribute currentTemperature = 293.15 [K];
        }

        part manipulator : Manipulator {
            attribute maximumLiftMass = 15 [kg];
            attribute reach = 0.8 [m];
            attribute positioningAccuracy = 0.01 [m];
            attribute gripperOpening = 0.35 [m];
        }

        part communications : CommunicationsModule {
            attribute cellularAvailable = true;
            attribute wifiAvailable = true;
            attribute updatePeriod = 2 [s];
            attribute maximumLatency = 1 [s];
        }

        part safetyController : SafetyController {
            attribute emergencyStopActive = false;
            attribute minimumPedestrianClearance = 1.0 [m];
            attribute maximumSafeSpeedNearPedestrian = 0.5 [m/s];
            attribute diagnosticInterval = 60 [s];
        }

        connection externalMission connect missionPort to communications.internalMissionPort;
        connection externalData connect dataPort to communications.externalDataPort;
        connection chargeInterface connect chargingPort to battery.chargingPort;
        connection batteryToPdu connect battery.powerPort to powerDistribution.batteryPower;
        connection pduToDrive connect powerDistribution.drivePower to driveTrain.powerPort;
        connection pduToCompute connect powerDistribution.computePower to navigationComputer.powerPort;
        connection pduToManipulator connect powerDistribution.manipulatorPower to manipulator.powerPort;
        connection pduToPerception connect powerDistribution.sensorPower to perception.powerPort;
        connection pduToSafety connect powerDistribution.computePower to safetyController.powerPort;
        connection pduToLocalization connect powerDistribution.sensorPower to localization.powerPort;
        connection pduToCommunications connect powerDistribution.computePower to communications.powerPort;

        connection perceptionToNavigation connect perception.sensorPort to navigationComputer.sensorPort;
        connection localizationToNavigation connect localization.sensorPort to navigationComputer.sensorPort;
        connection perceptionToSafety connect perception.sensorPort to safetyController.sensorPort;
        connection navigationToDrive connect navigationComputer.motionPort to driveTrain.motionPort;
        connection safetyToDrive connect safetyController.motionPort to driveTrain.motionPort;
        connection pickupToManipulator connect pickupParcelPort to manipulator.parcelPort;
        connection manipulatorToCargo connect manipulator.parcelPort to cargoBay.parcelPort;
        connection cargoToDelivery connect cargoBay.parcelPort to deliveryParcelPort;
        connection missionToNavigation connect communications.internalMissionPort to navigationComputer.navigationPort;
        connection missionToSafety connect communications.internalMissionPort to safetyController.missionPort;

        perform action primaryTask : PerformAutonomousParcelDelivery;
        exhibit state robotStates : DeliveryRobotOperationalStates;
    }

    part def RoboticDeliverySystem {
        attribute systemId : Identifier;
        attribute serviceAreaRadius : Distance;
        attribute dailyDeliveryTarget : Integer;
        attribute commandedAvailability : Percentage;

        part dispatchCenter : DispatchCenter {
            attribute centerId = "urban-dispatch-01";
            attribute operatorAvailable = true;
            attribute maximumAssignedRobots = 50;
        }

        part fleetManager : CloudFleetManager {
            attribute activeMissionCount = 0;
            attribute routeReplanPeriod = 10 [s];
            attribute minimumRobotBatteryForAssignment = 35.0;
        }

        part loadingDock : LoadingDock {
            attribute dockId = "dock-north";
            attribute loadingHeight = 0.45 [m];
            attribute maximumParcelMass = 15 [kg];
        }

        part deliveryRobot : DeliveryRobot {
            attribute robotId = "delivery-robot-DR-001";
            attribute curbMass = 62 [kg];
            attribute maximumPayloadMass = 15 [kg];
            attribute maximumPayloadVolume = 0.12 [m^3];
            attribute maximumSpeed = 2.0 [m/s];
            attribute nominalCruiseSpeed = 1.2 [m/s];
            attribute minimumTurningRadius = 0.6 [m];
            attribute operatingTemperatureMin = 263.15 [K];
            attribute operatingTemperatureMax = 318.15 [K];
            attribute missionSuccessRate = 0.99;
            attribute availability = 0.97;
            attribute currentMode = RobotMode::idle;
            attribute activeOrderId = "none";
        }

        part customerDropBox : RecipientDropBox {
            attribute boxId = "customer-dropbox-42";
            attribute compartmentVolume = 0.14 [m^3];
            attribute locked = true;
        }

        part chargingStation : ChargingStation {
            attribute stationId = "charger-A1";
            attribute maximumChargePower = 800 [W];
            attribute outputVoltage = 48 [V];
            attribute available = true;
        }

        connection dispatchToFleet connect dispatchCenter.networkPort to fleetManager.dispatchPort;
        connection fleetToRobot connect fleetManager.robotPort to deliveryRobot.dataPort;
        connection dockMissionToRobot connect loadingDock.missionPort to deliveryRobot.missionPort;
        connection dockParcelToRobot connect loadingDock.parcelPort to deliveryRobot.pickupParcelPort;
        connection robotToDropBoxParcel connect deliveryRobot.deliveryParcelPort to customerDropBox.parcelPort;
        connection robotToDropBoxAuth connect deliveryRobot.dataPort to customerDropBox.authenticationPort;
        connection robotToCharger connect deliveryRobot.chargingPort to chargingStation.chargingPort;

        perform action primaryTask : PerformAutonomousParcelDelivery;
    }

    action def IssueDeliveryMission {
        out item order : DeliveryOrder;
        out item command : RobotCommand;
    }

    action def MonitorRobotStatus {
        in item status : RobotStatus;
        in item diagnostic : DiagnosticReport;
    }

    action def AssignDeliveryRobot {
        in item order : DeliveryOrder;
        in item status : RobotStatus;
        out item command : RobotCommand;
    }

    action def UpdateOperationalMap {
        out item map : MapData;
    }

    action def StageParcelForRobot {
        in item order : DeliveryOrder;
        out item parcel : Parcel;
    }

    action def AcceptParcel {
        in item parcel : Parcel;
        in item token : AuthenticationToken;
        out item receipt : DeliveryReceipt;
    }

    action def ProvideChargingPower {
        out item chargingPower : ElectricalPowerFlow;
        in item chargingStatus : ChargingStatus;
    }

    action def SupplyElectricalPower {
        out item power : ElectricalPowerFlow;
    }

    action def AcceptChargingPower {
        in item chargingPower : ElectricalPowerFlow;
        out item status : ChargingStatus;
    }

    action def ExecuteMotionCommand {
        in item motionCommand : MotionCommand;
        out item telemetry : DriveTelemetry;
    }

    action def BrakeToSafeStop {
        out item telemetry : DriveTelemetry;
    }

    action def ScanEnvironment {
        out item perception : PerceptionFrame;
        out item obstacle : ObstacleTrack;
    }

    action def CaptureImages {
        out item perception : PerceptionFrame;
    }

    action def DetectNearObstacles {
        out item obstacle : ObstacleTrack;
    }

    action def FusePerceptionData {
        in item lidarFrame : PerceptionFrame;
        in item cameraFrame : PerceptionFrame;
        in item nearObstacle : ObstacleTrack;
        out item fusedFrame : PerceptionFrame;
    }

    action def EstimateRobotPose {
        in item perception : PerceptionFrame;
        out item pose : Location;
    }

    action def ComputeRoutePlan {
        in item order : DeliveryOrder;
        in item map : MapData;
        out item route : RoutePlan;
    }

    action def AvoidObstacle {
        in item obstacle : ObstacleTrack;
        in item route : RoutePlan;
        out item revisedRoute : RoutePlan;
    }

    action def GenerateMotionCommand {
        in item route : RoutePlan;
        in item perception : PerceptionFrame;
        out item motion : MotionCommand;
    }

    action def SecureParcel {
        in item parcel : Parcel;
        out item securedParcel : Parcel;
    }

    action def ReleaseParcel {
        in item parcel : Parcel;
        out item releasedParcel : Parcel;
    }

    action def MonitorParcelCondition {
        in item parcel : Parcel;
        out item status : RobotStatus;
    }

    action def LoadParcel {
        in item parcel : Parcel;
        out item securedParcel : Parcel;
    }

    action def UnloadParcel {
        in item securedParcel : Parcel;
        out item releasedParcel : Parcel;
    }

    action def TransmitStatus {
        in item status : RobotStatus;
        out item diagnostic : DiagnosticReport;
    }

    action def ReceiveCommand {
        in item command : RobotCommand;
        in item order : DeliveryOrder;
    }

    action def EvaluateSafety {
        in item perception : PerceptionFrame;
        in item obstacle : ObstacleTrack;
        out item motion : MotionCommand;
    }

    action def CommandEmergencyStop {
        out item motion : MotionCommand;
        out item status : RobotStatus;
    }

    action def RunDiagnostics {
        out item report : DiagnosticReport;
    }

    action def ValidateDeliveryOrder {
        in item order : DeliveryOrder;
        out item status : RobotStatus;
    }

    action def NavigateToPickup {
        in item route : RoutePlan;
        out item status : RobotStatus;
    }

    action def NavigateToDestination {
        in item route : RoutePlan;
        out item status : RobotStatus;
    }

    action def VerifyRecipient {
        in item token : AuthenticationToken;
        in item order : DeliveryOrder;
        out item receipt : DeliveryReceipt;
    }

    action def ReturnToChargingStation {
        in item map : MapData;
        out item status : RobotStatus;
    }

    action def PerformAutonomousParcelDelivery {
        in item order : DeliveryOrder;
        in item map : MapData;
        in item pickupParcel : Parcel;
        in item recipientToken : AuthenticationToken;
        out item receipt : DeliveryReceipt;
        out item finalStatus : RobotStatus;

        action validateOrder : ValidateDeliveryOrder;
        action computePickupRoute : ComputeRoutePlan;
        action navigatePickup : NavigateToPickup;
        action load : LoadParcel;
        action secure : SecureParcel;
        action computeDeliveryRoute : ComputeRoutePlan;
        action navigateDestination : NavigateToDestination;
        action verifyRecipient : VerifyRecipient;
        action unload : UnloadParcel;
        action returnHome : ReturnToChargingStation;

        succession validateOrder then computePickupRoute;
        succession computePickupRoute then navigatePickup;
        succession navigatePickup then load;
        succession load then secure;
        succession secure then computeDeliveryRoute;
        succession computeDeliveryRoute then navigateDestination;
        succession navigateDestination then verifyRecipient;
        succession verifyRecipient then unload;
        succession unload then returnHome;
    }

    state def DeliveryRobotOperationalStates {
        state Initializing;
        state Idle;
        state Assigned;
        state NavigatingToPickup;
        state LoadingParcel;
        state NavigatingToDestination;
        state VerifyingRecipient;
        state UnloadingParcel;
        state ReturningToBase;
        state Charging;
        state Maintenance;
        state FaultRecovery;
        state EmergencyStopped;
        state MissionComplete;

        transition initial_to_idle first Initializing then Idle;
        transition assign_mission from Idle to Assigned accept RobotCommand;
        transition begin_pickup_navigation from Assigned to NavigatingToPickup accept DeliveryOrder;
        transition reached_pickup from NavigatingToPickup to LoadingParcel accept RobotStatus;
        transition parcel_secured from LoadingParcel to NavigatingToDestination accept Parcel;
        transition reached_destination from NavigatingToDestination to VerifyingRecipient accept RobotStatus;
        transition recipient_valid from VerifyingRecipient to UnloadingParcel accept AuthenticationToken;
        transition parcel_released from UnloadingParcel to MissionComplete accept DeliveryReceipt;
        transition mission_complete_return from MissionComplete to ReturningToBase accept RobotCommand;
        transition docked_for_charge from ReturningToBase to Charging accept ChargingStatus;
        transition charge_complete from Charging to Idle accept ChargingStatus;
        transition maintenance_requested from Idle to Maintenance accept RobotCommand;
        transition maintenance_complete from Maintenance to Idle accept DiagnosticReport;
        transition recoverable_fault from NavigatingToPickup to FaultRecovery accept DiagnosticReport;
        transition recoverable_fault_delivery from NavigatingToDestination to FaultRecovery accept DiagnosticReport;
        transition fault_recovered from FaultRecovery to Idle accept DiagnosticReport;
        transition emergency_from_idle from Idle to EmergencyStopped accept RobotCommand;
        transition emergency_from_assigned from Assigned to EmergencyStopped accept RobotCommand;
        transition emergency_from_pickup_navigation from NavigatingToPickup to EmergencyStopped accept RobotCommand;
        transition emergency_from_loading from LoadingParcel to EmergencyStopped accept RobotCommand;
        transition emergency_from_delivery_navigation from NavigatingToDestination to EmergencyStopped accept RobotCommand;
        transition emergency_from_unloading from UnloadingParcel to EmergencyStopped accept RobotCommand;
        transition reset_emergency from EmergencyStopped to FaultRecovery accept DiagnosticReport;
    }

    constraint def PayloadMassConstraint {
        in parcelMass : Mass;
        in maximumPayloadMass : Mass;
        constraint payloadWithinLimit { parcelMass <= maximumPayloadMass }
    }

    constraint def PayloadVolumeConstraint {
        in parcelVolume : Volume;
        in maximumPayloadVolume : Volume;
        constraint payloadVolumeWithinLimit { parcelVolume <= maximumPayloadVolume }
    }

    constraint def EnergyReserveConstraint {
        in expectedEnergyUse : Energy;
        in availableEnergy : Energy;
        in reserveEnergy : Energy;
        constraint sufficientEnergy { availableEnergy >= expectedEnergyUse + reserveEnergy }
    }

    constraint def PedestrianSafetyConstraint {
        in nearestPedestrianDistance : Distance;
        in minimumPedestrianClearance : Distance;
        constraint pedestrianClearanceMaintained { nearestPedestrianDistance >= minimumPedestrianClearance }
    }

    constraint def DeliveryTimeConstraint {
        in actualDeliveryTime : Time;
        in promisedDeliveryTime : Time;
        constraint deliveredOnTime { actualDeliveryTime <= promisedDeliveryTime }
    }

    requirement def PrimaryDeliveryTaskRequirement {
        subject system : RoboticDeliverySystem;
        doc /* The robotic system shall perform its primary task by using the DeliveryRobot to autonomously transport a parcel from the loading dock to the recipient drop box and produce a delivery receipt. */
        require constraint {
            system.deliveryRobot.missionSuccessRate >= 0.98
        }
    }

    requirement def DeliveryRobotUsageRequirement {
        subject system : RoboticDeliverySystem;
        doc /* The primary delivery task shall be performed by the part deliveryRobot typed by DeliveryRobot. */
        require constraint {
            system.deliveryRobot.maximumPayloadMass >= 15 [kg]
        }
    }

    requirement def PayloadCapacityRequirement {
        subject robot : DeliveryRobot;
        doc /* The DeliveryRobot shall carry the specified parcel without exceeding cargo bay mass or volume limits. */
        require constraint {
            robot.maximumPayloadMass >= 15 [kg] and robot.maximumPayloadVolume >= 0.12 [m^3]
        }
    }

    requirement def SafeNavigationRequirement {
        subject robot : DeliveryRobot;
        doc /* The DeliveryRobot shall navigate sidewalks and shared spaces while maintaining pedestrian clearance and limiting speed near pedestrians. */
        require constraint {
            robot.safetyController.minimumPedestrianClearance >= 1.0 [m] and
            robot.safetyController.maximumSafeSpeedNearPedestrian <= 0.5 [m/s]
        }
    }

    requirement def AutonomousEnergyRequirement {
        subject robot : DeliveryRobot;
        doc /* The DeliveryRobot shall maintain a reserve battery threshold after completing a delivery mission and returning to the charging station. */
        require constraint {
            robot.battery.reserveThreshold >= 20.0
        }
    }

    requirement def LocalizationRequirement {
        subject robot : DeliveryRobot;
        doc /* The DeliveryRobot shall localize itself sufficiently for autonomous delivery in the service area. */
        require constraint {
            robot.navigationComputer.maximumLocalizationUncertainty <= 2.0 [m]
        }
    }

    requirement def ObstacleDetectionRequirement {
        subject robot : DeliveryRobot;
        doc /* The DeliveryRobot shall detect obstacles within its braking distance at nominal cruise speed. */
        require constraint {
            robot.perception.lidar.maximumRange >= 40 [m] and
            robot.driveTrain.brakingDistanceAtCruise <= 0.75 [m]
        }
    }

    requirement def ChargingCompatibilityRequirement {
        subject system : RoboticDeliverySystem;
        doc /* The DeliveryRobot charging interface shall be compatible with the charging station voltage and power. */
        require constraint {
            system.deliveryRobot.battery.nominalVoltage == system.chargingStation.outputVoltage and
            system.chargingStation.maximumChargePower >= system.deliveryRobot.battery.maximumChargePower
        }
    }

    requirement def ReceiptRequirement {
        subject system : RoboticDeliverySystem;
        doc /* A completed delivery mission shall output a receipt indicating order id, parcel id, delivery time, location, recipient verification, and final parcel condition. */
        require constraint {
            system.deliveryRobot.availability >= 0.95
        }
    }

    requirement def OperatingEnvironmentRequirement {
        subject robot : DeliveryRobot;
        doc /* The DeliveryRobot shall operate over the specified urban outdoor temperature range. */
        require constraint {
            robot.operatingTemperatureMin <= 263.15 [K] and
            robot.operatingTemperatureMax >= 318.15 [K]
        }
    }
}
