package DustbotSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass {
        :> ISQ::mass;
        unit = "kg";
    }

    attribute def Length {
        :> ISQ::length;
        unit = "m";
    }

    attribute def Speed {
        :> ISQ::speed;
        unit = "m/s";
    }

    attribute def TimeDuration {
        :> ISQ::duration;
        unit = "s";
    }

    attribute def ElectricCharge {
        unit = "Ah";
    }

    attribute def ElectricPotential {
        unit = "V";
    }

    attribute def EnergyCapacity {
        unit = "Wh";
    }

    attribute def DataRate {
        unit = "Mb/s";
    }

    attribute def Volume {
        unit = "L";
    }

    attribute def Percentage {
        unit = "%";
    }

    item def WasteItem {
        attribute mass : Mass;
        attribute category : WasteCategory;
        attribute contaminationRisk : Percentage;
    }

    enum def WasteCategory {
        enum mixedMunicipal;
        enum recyclable;
        enum organic;
        enum hazardousCandidate;
        enum unknown;
    }

    item def MissionRequest {
        attribute pickupLocationLatitude : Real;
        attribute pickupLocationLongitude : Real;
        attribute requestedWasteCategory : WasteCategory;
        attribute requestedCollectionWindow : TimeDuration;
    }

    item def MissionStatus {
        attribute currentMode : DustbotMode;
        attribute batteryStateOfCharge : Percentage;
        attribute wasteBinFillLevel : Percentage;
        attribute estimatedTimeToArrival : TimeDuration;
    }

    enum def DustbotMode {
        enum idle;
        enum planning;
        enum navigating;
        enum collectingWaste;
        enum returningToDock;
        enum charging;
        enum faultSafe;
    }

    item def NavigationCommand {
        attribute targetLatitude : Real;
        attribute targetLongitude : Real;
        attribute maximumSpeed : Speed;
    }

    item def DriveCommand {
        attribute leftWheelSpeed : Speed;
        attribute rightWheelSpeed : Speed;
    }

    item def SensorFrame {
        attribute obstacleDistance : Length;
        attribute localizationConfidence : Percentage;
        attribute airQualityIndex : Real;
        attribute binFillLevel : Percentage;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotential;
        attribute current : Real;
    }

    port def MissionServicePort {
        in missionRequest : MissionRequest;
        out missionStatus : MissionStatus;
    }

    port def NavigationPort {
        in navigationCommand : NavigationCommand;
        out sensorFrame : SensorFrame;
    }

    port def DriveControlPort {
        in driveCommand : DriveCommand;
    }

    port def WasteTransferPort {
        in collectedWaste : WasteItem;
        out binStatus : MissionStatus;
    }

    port def PowerPort {
        inout power : ElectricalPower;
    }

    part def Dustbot {
        doc /* Primary function: autonomously travel to citizen-requested pickup locations, collect small urban waste loads, monitor waste and environmental status, and return to a service dock for charging and unloading. */

        attribute nominalMass : Mass = 95;
        attribute maximumSpeed : Speed = 1.2;
        attribute operationalRange : Length = 6000;
        attribute payloadCapacity : Mass = 20;
        attribute binCapacity : Volume = 80;

        port service : MissionServicePort;
        port chargeInterface : PowerPort;

        part missionComputer : MissionComputer;
        part navigationSystem : NavigationSystem;
        part mobilityBase : MobilityBase;
        part wasteCollectionSystem : WasteCollectionSystem;
        part powerSystem : PowerSystem;
        part safetySystem : SafetySystem;
        part communicationsSystem : CommunicationsSystem;
        part dockingInterface : DockingInterface;

        connect service to communicationsSystem.cloudService;
        connect communicationsSystem.missionData to missionComputer.service;
        connect missionComputer.navigation to navigationSystem.command;
        connect navigationSystem.driveOutput to mobilityBase.driveInput;
        connect navigationSystem.sensing to safetySystem.environmentInput;
        connect safetySystem.safeDriveOutput to mobilityBase.driveInput;
        connect wasteCollectionSystem.binTelemetry to missionComputer.wasteTelemetry;
        connect powerSystem.powerDistribution to missionComputer.powerInput;
        connect powerSystem.powerDistribution to navigationSystem.powerInput;
        connect powerSystem.powerDistribution to mobilityBase.powerInput;
        connect powerSystem.powerDistribution to wasteCollectionSystem.powerInput;
        connect chargeInterface to dockingInterface.externalPower;
        connect dockingInterface.internalPower to powerSystem.chargeInput;

        perform behavior dustbotMissionBehavior;
    }

    part def MissionComputer {
        attribute processorHealth : Percentage;
        attribute activeMissionId : String;
        port service : MissionServicePort;
        port navigation : NavigationPort;
        port wasteTelemetry : WasteTransferPort;
        port powerInput : PowerPort;
    }

    part def NavigationSystem {
        attribute localizationAccuracy : Length = 0.25;
        attribute mapUpdateRate : DataRate = 5;
        port command : NavigationPort;
        port sensing : NavigationPort;
        port driveOutput : DriveControlPort;
        port powerInput : PowerPort;

        part lidar : ObstacleSensor;
        part cameraArray : VisionSensor;
        part gnssReceiver : LocalizationSensor;
        part routePlanner : RoutePlanner;
    }

    part def MobilityBase {
        attribute wheelDiameter : Length = 0.32;
        attribute trackWidth : Length = 0.62;
        attribute maximumClimbGrade : Percentage = 12;
        port driveInput : DriveControlPort;
        port powerInput : PowerPort;

        part leftWheelMotor : DriveMotor;
        part rightWheelMotor : DriveMotor;
        part suspension : Suspension;
    }

    part def WasteCollectionSystem {
        attribute binCapacity : Volume = 80;
        attribute compactionRatio : Real = 2.5;
        attribute fillLevel : Percentage;
        port intake : WasteTransferPort;
        port binTelemetry : WasteTransferPort;
        port powerInput : PowerPort;

        part manipulatorArm : ManipulatorArm;
        part intakeHopper : IntakeHopper;
        part compactor : WasteCompactor;
        part sealedBin : WasteBin;
    }

    part def PowerSystem {
        attribute batteryCapacity : EnergyCapacity = 2400;
        attribute nominalVoltage : ElectricPotential = 48;
        attribute stateOfCharge : Percentage;
        port powerDistribution : PowerPort;
        port chargeInput : PowerPort;

        part batteryPack : BatteryPack;
        part powerController : PowerController;
    }

    part def SafetySystem {
        attribute emergencyStopLatency : TimeDuration = 0.1;
        attribute minimumObstacleClearance : Length = 0.5;
        port environmentInput : NavigationPort;
        port safeDriveOutput : DriveControlPort;

        part emergencyStopController : EmergencyStopController;
        part collisionAvoidanceController : CollisionAvoidanceController;
    }

    part def CommunicationsSystem {
        attribute uplinkRate : DataRate = 10;
        attribute downlinkRate : DataRate = 10;
        port cloudService : MissionServicePort;
        port missionData : MissionServicePort;

        part cellularModem : WirelessModem;
        part localOperatorPanel : OperatorPanel;
    }

    part def DockingInterface {
        attribute dockingAlignmentTolerance : Length = 0.05;
        port externalPower : PowerPort;
        port internalPower : PowerPort;
    }

    part def ObstacleSensor {
        attribute range : Length = 20;
        attribute scanRate : Real = 15;
    }

    part def VisionSensor {
        attribute horizontalFieldOfView : Real = 120;
        attribute frameRate : Real = 30;
    }

    part def LocalizationSensor {
        attribute positionAccuracy : Length = 0.5;
    }

    part def RoutePlanner {
        attribute replanningPeriod : TimeDuration = 1;
    }

    part def DriveMotor {
        attribute ratedPower : Real = 600;
        attribute ratedVoltage : ElectricPotential = 48;
    }

    part def Suspension {
        attribute groundClearance : Length = 0.12;
    }

    part def ManipulatorArm {
        attribute reach : Length = 0.8;
        attribute liftCapacity : Mass = 8;
    }

    part def IntakeHopper {
        attribute openingWidth : Length = 0.45;
        attribute openingHeight : Length = 0.35;
    }

    part def WasteCompactor {
        attribute compactionForce : Real = 1500;
    }

    part def WasteBin {
        attribute usableVolume : Volume = 80;
        attribute maximumWasteMass : Mass = 20;
    }

    part def BatteryPack {
        attribute capacity : EnergyCapacity = 2400;
        attribute charge : ElectricCharge = 50;
    }

    part def PowerController {
        attribute conversionEfficiency : Percentage = 92;
    }

    part def EmergencyStopController;
    part def CollisionAvoidanceController;
    part def WirelessModem;
    part def OperatorPanel;

    action def PlanMission {
        in request : MissionRequest;
        out command : NavigationCommand;
    }

    action def NavigateToPickup {
        in command : NavigationCommand;
        out status : MissionStatus;
    }

    action def CollectWaste {
        in waste : WasteItem;
        out fillStatus : MissionStatus;
    }

    action def ReturnToDock {
        in currentStatus : MissionStatus;
        out dockedStatus : MissionStatus;
    }

    action def RechargeBattery {
        inout power : ElectricalPower;
        out chargedStatus : MissionStatus;
    }

    state def DustbotMissionStateMachine {
        entry action initializeDustbot;

        state Idle;
        state Planning;
        state NavigatingToPickup;
        state CollectingWaste;
        state ReturningToDock;
        state Charging;
        state FaultSafe;

        transition first Idle;

        transition Idle_to_Planning
            first Idle
            then Planning
            accept MissionRequest;

        transition Planning_to_Navigating
            first Planning
            then NavigatingToPickup
            do PlanMission;

        transition Navigating_to_Collecting
            first NavigatingToPickup
            then CollectingWaste
            if arrivedAtPickup;

        transition Collecting_to_Returning
            first CollectingWaste
            then ReturningToDock
            if wasteSecured or binFillLevelHigh;

        transition Navigating_to_Returning
            first NavigatingToPickup
            then ReturningToDock
            if batteryLow;

        transition Returning_to_Charging
            first ReturningToDock
            then Charging
            if docked;

        transition Charging_to_Idle
            first Charging
            then Idle
            if batteryCharged and binEmptied;

        transition Any_to_FaultSafe
            first Idle
            then FaultSafe
            if criticalFault;

        transition FaultSafe_to_Idle
            first FaultSafe
            then Idle
            if operatorReset;
    }

    behavior dustbotMissionBehavior {
        perform PlanMission;
        perform NavigateToPickup;
        perform CollectWaste;
        perform ReturnToDock;
        perform RechargeBattery;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Dustbot shall autonomously collect requested urban waste loads from specified pickup locations and return status to municipal waste services. */
        attribute requiredPickupCompletionTime : TimeDuration = 900;
        attribute requiredMissionStatusUpdatePeriod : TimeDuration = 5;
    }

    requirement def NavigationSafetyRequirement {
        doc /* The Dustbot shall maintain obstacle clearance while navigating shared pedestrian environments. */
        attribute minimumClearance : Length = 0.5;
        attribute maximumOperatingSpeed : Speed = 1.2;
    }

    requirement def WasteCapacityRequirement {
        doc /* The Dustbot shall store and compact collected waste without exceeding payload or bin capacity limits. */
        attribute minimumBinVolume : Volume = 80;
        attribute maximumPayloadMass : Mass = 20;
    }

    requirement def EnergyRequirement {
        doc /* The Dustbot shall complete a typical collection mission and retain reserve battery energy for return to dock. */
        attribute minimumOperationalRange : Length = 6000;
        attribute reserveBatteryStateOfCharge : Percentage = 20;
    }

    requirement def CommunicationRequirement {
        doc /* The Dustbot shall exchange mission requests and status with the remote service platform during operation. */
        attribute minimumUplinkRate : DataRate = 1;
        attribute maximumStatusLatency : TimeDuration = 5;
    }

    satisfy PrimaryFunctionRequirement by Dustbot;
    satisfy NavigationSafetyRequirement by SafetySystem;
    satisfy WasteCapacityRequirement by WasteCollectionSystem;
    satisfy EnergyRequirement by PowerSystem;
    satisfy CommunicationRequirement by CommunicationsSystem;
}