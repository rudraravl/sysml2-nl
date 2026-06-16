package RoboticSystemUsingMobileRobot {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length :> ISQ::length;
    attribute def Mass :> ISQ::mass;
    attribute def Time :> ISQ::time;
    attribute def Speed :> ISQ::speed;
    attribute def Acceleration :> ISQ::acceleration;
    attribute def Angle :> ISQ::planeAngle;
    attribute def AngularSpeed :> ISQ::angularVelocity;
    attribute def ElectricVoltage :> ISQ::electricPotential;
    attribute def ElectricCurrent :> ISQ::electricCurrent;
    attribute def ElectricCharge :> ISQ::electricCharge;
    attribute def Energy :> ISQ::energy;
    attribute def Power :> ISQ::power;
    attribute def Frequency :> ISQ::frequency;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Percentage :> ScalarValues::Real;

    item def Payload {
        attribute payloadId : String;
        attribute mass : Mass;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
        attribute fragile : Boolean;
    }

    item def Pose2D {
        attribute x : Length;
        attribute y : Length;
        attribute heading : Angle;
    }

    item def VelocityCommand {
        attribute linearVelocity : Speed;
        attribute angularVelocity : AngularSpeed;
        attribute commandTimeout : Time;
    }

    item def WheelOdometry {
        attribute poseEstimate : Pose2D;
        attribute linearSpeed : Speed;
        attribute angularSpeed : AngularSpeed;
        attribute timestamp : Time;
    }

    item def LidarScan {
        attribute minimumRange : Length;
        attribute maximumRange : Length;
        attribute angularResolution : Angle;
        attribute sampleCount : Integer;
        attribute scanRate : Frequency;
    }

    item def CameraFrame {
        attribute frameId : String;
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : Frequency;
        attribute timestamp : Time;
    }

    item def ImuSample {
        attribute yawRate : AngularSpeed;
        attribute longitudinalAcceleration : Acceleration;
        attribute lateralAcceleration : Acceleration;
        attribute timestamp : Time;
    }

    item def MapUpdate {
        attribute mapId : String;
        attribute revision : Integer;
        attribute cellResolution : Length;
        attribute validUntil : Time;
    }

    item def RoutePlan {
        attribute routeId : String;
        attribute waypointCount : Integer;
        attribute plannedDistance : Length;
        attribute expectedTravelTime : Time;
        attribute maxAllowedSpeed : Speed;
    }

    item def ObstacleReport {
        attribute obstacleId : String;
        attribute position : Pose2D;
        attribute radius : Length;
        attribute confidence : Percentage;
    }

    item def MissionOrder {
        attribute missionId : String;
        attribute pickupStationId : String;
        attribute deliveryStationId : String;
        attribute requestedStartTime : Time;
        attribute latestDeliveryTime : Time;
        item assignedPayload : Payload;
    }

    item def MissionStatus {
        attribute missionId : String;
        attribute state : String;
        attribute currentPose : Pose2D;
        attribute batteryStateOfCharge : Percentage;
        attribute remainingDistance : Length;
        attribute faultActive : Boolean;
    }

    item def MissionReport {
        attribute missionId : String;
        attribute completed : Boolean;
        attribute totalDistance : Length;
        attribute totalDuration : Time;
        attribute finalBatteryStateOfCharge : Percentage;
        attribute faultSummary : String;
    }

    item def RobotCommand {
        attribute commandId : String;
        attribute commandKind : String;
        attribute issuedAt : Time;
    }

    item def SafetyCommand {
        attribute stopRequested : Boolean;
        attribute resetRequested : Boolean;
        attribute speedLimit : Speed;
    }

    item def BatteryStatus {
        attribute stateOfCharge : Percentage;
        attribute packVoltage : ElectricVoltage;
        attribute packCurrent : ElectricCurrent;
        attribute remainingEnergy : Energy;
        attribute temperature : Temperature;
        attribute healthy : Boolean;
    }

    item def DcPower {
        attribute voltage : ElectricVoltage;
        attribute current : ElectricCurrent;
        attribute availablePower : Power;
    }

    item def ChargeRequest {
        attribute requestedVoltage : ElectricVoltage;
        attribute requestedCurrent : ElectricCurrent;
        attribute requestedEnergy : Energy;
    }

    item def NetworkPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payloadLength : Integer;
        attribute encrypted : Boolean;
    }

    port def MissionControlPort {
        in item missionOrder : MissionOrder;
        in item command : RobotCommand;
        out item status : MissionStatus;
        out item report : MissionReport;
    }

    port def WirelessNetworkPort {
        in item inboundPacket : NetworkPacket;
        out item outboundPacket : NetworkPacket;
    }

    port def DriveCommandPort {
        in item velocityCommand : VelocityCommand;
        in item safetyCommand : SafetyCommand;
        out item odometry : WheelOdometry;
    }

    port def SensorOutputPort {
        out item lidarScan : LidarScan;
        out item cameraFrame : CameraFrame;
        out item imuSample : ImuSample;
        out item obstacleReport : ObstacleReport;
    }

    port def LocalizationPort {
        in item odometry : WheelOdometry;
        in item lidarScan : LidarScan;
        in item imuSample : ImuSample;
        in item mapUpdate : MapUpdate;
        out item pose : Pose2D;
    }

    port def PlanningPort {
        in item missionOrder : MissionOrder;
        in item currentPose : Pose2D;
        in item mapUpdate : MapUpdate;
        in item obstacleReport : ObstacleReport;
        out item routePlan : RoutePlan;
    }

    port def PayloadPort {
        in item payloadToLoad : Payload;
        out item payloadDelivered : Payload;
        out item payloadOnboard : Payload;
    }

    port def DcPowerSourcePort {
        out item suppliedPower : DcPower;
        in item chargeRequest : ChargeRequest;
    }

    port def DcPowerLoadPort {
        in item receivedPower : DcPower;
        out item powerDemand : ChargeRequest;
    }

    port def BatteryStatusPort {
        out item batteryStatus : BatteryStatus;
    }

    port def DockingPort {
        in item chargePower : DcPower;
        out item chargeRequest : ChargeRequest;
    }

    interface def MissionNetworkInterface {
        end controller : WirelessNetworkPort;
        end robot : WirelessNetworkPort;
        flow controller.outboundPacket to robot.inboundPacket;
        flow robot.outboundPacket to controller.inboundPacket;
    }

    interface def DockChargingInterface {
        end dock : DcPowerSourcePort;
        end robot : DockingPort;
        flow dock.suppliedPower to robot.chargePower;
        flow robot.chargeRequest to dock.chargeRequest;
    }

    interface def InternalDcPowerInterface {
        end source : DcPowerSourcePort;
        end load : DcPowerLoadPort;
        flow source.suppliedPower to load.receivedPower;
        flow load.powerDemand to source.chargeRequest;
    }

    action def ValidateMission {
        in item mission : MissionOrder;
        out attribute missionAccepted : Boolean;
    }

    action def LocalizeRobot {
        in item odometry : WheelOdometry;
        in item scan : LidarScan;
        in item imu : ImuSample;
        out item pose : Pose2D;
    }

    action def PlanRoute {
        in item mission : MissionOrder;
        in item pose : Pose2D;
        in item map : MapUpdate;
        out item route : RoutePlan;
    }

    action def NavigateRoute {
        in item route : RoutePlan;
        in item pose : Pose2D;
        out item velocity : VelocityCommand;
        out attribute arrived : Boolean;
    }

    action def LoadPayload {
        in item payload : Payload;
        out item onboardPayload : Payload;
        out attribute secured : Boolean;
    }

    action def UnloadPayload {
        in item onboardPayload : Payload;
        out item deliveredPayload : Payload;
        out attribute released : Boolean;
    }

    action def DockAndRecharge {
        in item batteryStatus : BatteryStatus;
        out item chargeRequest : ChargeRequest;
        out attribute chargedForNextMission : Boolean;
    }

    action def ExecuteAutonomousMaterialTransport {
        in item mission : MissionOrder;
        out item report : MissionReport;

        action validate : ValidateMission {
            in item mission = mission;
        }

        action localizeAtStart : LocalizeRobot;

        action planToPickup : PlanRoute {
            in item mission = mission;
        }

        action navigateToPickup : NavigateRoute;

        action load : LoadPayload {
            in item payload = mission.assignedPayload;
        }

        action planToDelivery : PlanRoute {
            in item mission = mission;
        }

        action navigateToDelivery : NavigateRoute;

        action unload : UnloadPayload;

        action returnToDock : NavigateRoute;

        action recharge : DockAndRecharge;

        succession first validate then localizeAtStart;
        succession first localizeAtStart then planToPickup;
        succession first planToPickup then navigateToPickup;
        succession first navigateToPickup then load;
        succession first load then planToDelivery;
        succession first planToDelivery then navigateToDelivery;
        succession first navigateToDelivery then unload;
        succession first unload then returnToDock;
        succession first returnToDock then recharge;
    }

    state def MobileRobotOperatingStates {
        state poweredOff;
        state booting;
        state idle;
        state validatingMission;
        state planningRoute;
        state navigatingToPickup;
        state loadingPayload;
        state navigatingToDelivery;
        state unloadingPayload;
        state returningToDock;
        state charging;
        state missionComplete;
        state faulted;
        state emergencyStopped;

        transition initialToOff first start then poweredOff;
        transition powerOn first poweredOff then booting;
        transition bootComplete first booting then idle;
        transition missionReceived first idle then validatingMission;
        transition missionAccepted first validatingMission then planningRoute;
        transition routeReadyToPickup first planningRoute then navigatingToPickup;
        transition arrivedAtPickup first navigatingToPickup then loadingPayload;
        transition payloadSecured first loadingPayload then navigatingToDelivery;
        transition arrivedAtDelivery first navigatingToDelivery then unloadingPayload;
        transition payloadReleased first unloadingPayload then returningToDock;
        transition dockReached first returningToDock then charging;
        transition chargeComplete first charging then missionComplete;
        transition resetAfterComplete first missionComplete then idle;
        transition faultDetectedFromIdle first idle then faulted;
        transition faultDetectedFromNavigation first navigatingToPickup then faulted;
        transition faultDetectedFromDelivery first navigatingToDelivery then faulted;
        transition faultCleared first faulted then idle;
        transition emergencyStopFromAny first idle then emergencyStopped;
        transition emergencyStopDuringMission first navigatingToDelivery then emergencyStopped;
        transition emergencyReset first emergencyStopped then idle;
    }

    part def OperatorConsole {
        attribute displayRefreshRate : Frequency = 30 [Hz];
        attribute authenticatedOperators : Integer = 3;

        port missionControl : MissionControlPort;
        port network : WirelessNetworkPort;
    }

    part def FleetNetwork {
        attribute nominalBandwidthMbps : Real = 100.0;
        attribute maximumLatency : Time = 0.050 [s];
        attribute encryptionEnabled : Boolean = true;

        port consoleSide : WirelessNetworkPort;
        port robotSide : WirelessNetworkPort;
    }

    part def ChargingDock {
        attribute dockId : String = "DOCK-A";
        attribute outputVoltage : ElectricVoltage = 48 [V];
        attribute maximumChargeCurrent : ElectricCurrent = 25 [A];
        attribute maximumChargePower : Power = 1200 [W];

        port chargerOutput : DcPowerSourcePort;
    }

    part def Workstation {
        attribute stationId : String;
        attribute dockingTolerance : Length = 0.05 [m];
        attribute loadHeight : Length = 0.80 [m];

        port payloadInterface : PayloadPort;
    }

    part def BatteryPack {
        attribute nominalVoltage : ElectricVoltage = 48 [V];
        attribute capacity : ElectricCharge = 40 [A h];
        attribute storedEnergy : Energy = 1920 [W h];
        attribute mass : Mass = 14 [kg];
        attribute minimumAllowedSoc : Percentage = 15.0;
        attribute maximumAllowedTemperature : Temperature = 323.15 [K];

        port powerOut : DcPowerSourcePort;
        port statusOut : BatteryStatusPort;
        port chargeIn : DockingPort;
    }

    part def BatteryManagementSystem {
        attribute balancingEnabled : Boolean = true;
        attribute statusUpdateRate : Frequency = 10 [Hz];

        port batteryStatusIn : BatteryStatusPort;
        port managedPowerOut : DcPowerSourcePort;
        port chargerIn : DockingPort;
    }

    part def PowerDistributionUnit {
        attribute regulatedBusVoltage : ElectricVoltage = 24 [V];
        attribute peakOutputPower : Power = 1800 [W];

        port busInput : DcPowerLoadPort;
        port computePower : DcPowerSourcePort;
        port drivePower : DcPowerSourcePort;
        port sensorPower : DcPowerSourcePort;
        port payloadPower : DcPowerSourcePort;
    }

    part def RobotPowerSystem {
        attribute usableEnergy : Energy = 1600 [W h];
        attribute reserveEnergy : Energy = 250 [W h];

        part battery : BatteryPack;
        part bms : BatteryManagementSystem;
        part distribution : PowerDistributionUnit;

        port externalCharge : DockingPort;
        port computeBus : DcPowerSourcePort;
        port driveBus : DcPowerSourcePort;
        port sensorBus : DcPowerSourcePort;
        port payloadBus : DcPowerSourcePort;
        port status : BatteryStatusPort;

        connect battery.powerOut to bms.managedPowerOut;
        connect bms.managedPowerOut to distribution.busInput;
        connect externalCharge to battery.chargeIn;
        connect distribution.computePower to computeBus;
        connect distribution.drivePower to driveBus;
        connect distribution.sensorPower to sensorBus;
        connect distribution.payloadPower to payloadBus;
        connect battery.statusOut to status;
    }

    part def DifferentialDriveBase {
        attribute wheelRadius : Length = 0.15 [m];
        attribute wheelBase : Length = 0.58 [m];
        attribute maximumLinearSpeed : Speed = 1.5 [m/s];
        attribute maximumAngularSpeed : AngularSpeed = 2.0 [rad/s];
        attribute maximumSlope : Angle = 0.1745 [rad];
        attribute odometryRate : Frequency = 50 [Hz];

        port command : DriveCommandPort;
        port power : DcPowerLoadPort;
    }

    part def PerceptionSubsystem {
        attribute lidarRange : Length = 20 [m];
        attribute lidarRate : Frequency = 15 [Hz];
        attribute cameraRate : Frequency = 30 [Hz];
        attribute obstacleDetectionRange : Length = 6 [m];

        port sensorOutput : SensorOutputPort;
        port power : DcPowerLoadPort;
    }

    part def LocalizationSubsystem {
        attribute poseUpdateRate : Frequency = 50 [Hz];
        attribute maximumPositionError : Length = 0.05 [m];
        attribute maximumHeadingError : Angle = 0.035 [rad];

        port localizationInput : LocalizationPort;
        port power : DcPowerLoadPort;
    }

    part def NavigationSubsystem {
        attribute replanningRate : Frequency = 5 [Hz];
        attribute nominalCruiseSpeed : Speed = 1.0 [m/s];
        attribute safeObstacleClearance : Length = 0.40 [m];

        port planner : PlanningPort;
        port driveCommand : DriveCommandPort;
        port power : DcPowerLoadPort;
    }

    part def PayloadHandler {
        attribute maximumPayloadMass : Mass = 12 [kg];
        attribute payloadBayLength : Length = 0.60 [m];
        attribute payloadBayWidth : Length = 0.45 [m];
        attribute payloadBayHeight : Length = 0.35 [m];
        attribute latchCycleTime : Time = 3 [s];

        port payloadPort : PayloadPort;
        port power : DcPowerLoadPort;
    }

    part def SafetyController {
        attribute safetyScanRadius : Length = 1.0 [m];
        attribute emergencyStopLatency : Time = 0.100 [s];
        attribute reducedSpeedLimit : Speed = 0.30 [m/s];

        port sensorInput : SensorOutputPort;
        port driveSafety : DriveCommandPort;
        port power : DcPowerLoadPort;
    }

    part def AutonomyComputer {
        attribute processorCores : Integer = 8;
        attribute memoryCapacityGb : Real = 32.0;
        attribute controlLoopRate : Frequency = 50 [Hz];
        attribute maximumPlanningTime : Time = 1.0 [s];

        port missionPort : MissionControlPort;
        port localization : LocalizationPort;
        port planning : PlanningPort;
        port driveCommand : DriveCommandPort;
        port payloadControl : PayloadPort;
        port power : DcPowerLoadPort;

        perform action materialTransport : ExecuteAutonomousMaterialTransport;
    }

    part def WirelessAdapter {
        attribute radioFrequency : Frequency = 5.2 [GHz];
        attribute nominalRange : Length = 80 [m];

        port externalNetwork : WirelessNetworkPort;
        port robotNetwork : MissionControlPort;
        port power : DcPowerLoadPort;
    }

    part def MobileRobot {
        attribute robotId : String = "MR-01";
        attribute massWithoutPayload : Mass = 68 [kg];
        attribute maximumPayloadMass : Mass = 12 [kg];
        attribute maximumMissionDistance : Length = 2500 [m];
        attribute maximumSpeed : Speed = 1.5 [m/s];
        attribute minimumOperationalSoc : Percentage = 20.0;
        attribute localizationAccuracy : Length = 0.05 [m];

        port externalMissionControl : MissionControlPort;
        port externalNetwork : WirelessNetworkPort;
        port docking : DockingPort;
        port payloadExchange : PayloadPort;

        part powerSystem : RobotPowerSystem;
        part driveBase : DifferentialDriveBase;
        part perception : PerceptionSubsystem;
        part localization : LocalizationSubsystem;
        part navigation : NavigationSubsystem;
        part payloadHandler : PayloadHandler;
        part safetyController : SafetyController;
        part autonomyComputer : AutonomyComputer;
        part wirelessAdapter : WirelessAdapter;

        exhibit state operatingMode : MobileRobotOperatingStates;
        perform action primaryTask : ExecuteAutonomousMaterialTransport;

        connect externalNetwork to wirelessAdapter.externalNetwork;
        connect externalMissionControl to autonomyComputer.missionPort;
        connect wirelessAdapter.robotNetwork to autonomyComputer.missionPort;

        connect docking to powerSystem.externalCharge;
        connect powerSystem.computeBus to autonomyComputer.power;
        connect powerSystem.computeBus to wirelessAdapter.power;
        connect powerSystem.driveBus to driveBase.power;
        connect powerSystem.sensorBus to perception.power;
        connect powerSystem.computeBus to localization.power;
        connect powerSystem.computeBus to navigation.power;
        connect powerSystem.payloadBus to payloadHandler.power;
        connect powerSystem.computeBus to safetyController.power;

        connect perception.sensorOutput to localization.localizationInput;
        connect perception.sensorOutput to safetyController.sensorInput;
        connect driveBase.command to localization.localizationInput;
        connect localization.localizationInput to autonomyComputer.localization;
        connect autonomyComputer.planning to navigation.planner;
        connect navigation.driveCommand to driveBase.command;
        connect safetyController.driveSafety to driveBase.command;
        connect autonomyComputer.driveCommand to driveBase.command;

        connect autonomyComputer.payloadControl to payloadHandler.payloadPort;
        connect payloadExchange to payloadHandler.payloadPort;
    }

    part def RoboticMaterialTransportSystem {
        attribute systemId : String = "RMTS-01";
        attribute operationalAreaLength : Length = 60 [m];
        attribute operationalAreaWidth : Length = 35 [m];
        attribute nominalMissionThroughputPerHour : Real = 18.0;
        attribute allowableNetworkLatency : Time = 0.100 [s];

        part mobileRobot : MobileRobot;
        part operatorConsole : OperatorConsole;
        part fleetNetwork : FleetNetwork;
        part chargingDock : ChargingDock;
        part pickupStation : Workstation {
            attribute stationId = "PICKUP-01";
        }
        part deliveryStation : Workstation {
            attribute stationId = "DELIVERY-01";
        }

        connect operatorConsole.network to fleetNetwork.consoleSide;
        connect fleetNetwork.robotSide to mobileRobot.externalNetwork;
        connect operatorConsole.missionControl to mobileRobot.externalMissionControl;
        connect chargingDock.chargerOutput to mobileRobot.docking;
        connect pickupStation.payloadInterface to mobileRobot.payloadExchange;
        connect deliveryStation.payloadInterface to mobileRobot.payloadExchange;
    }

    constraint def PayloadMassWithinCapacity {
        in payloadMass : Mass;
        in robotCapacity : Mass;
        payloadMass <= robotCapacity;
    }

    constraint def SpeedWithinSafeLimit {
        in commandedSpeed : Speed;
        in maximumSpeed : Speed;
        commandedSpeed <= maximumSpeed;
    }

    constraint def SufficientBatteryReserve {
        in expectedMissionEnergy : Energy;
        in availableEnergy : Energy;
        in reserveEnergy : Energy;
        expectedMissionEnergy + reserveEnergy <= availableEnergy;
    }

    requirement def PrimaryTaskUsingMobileRobotRequirement {
        subject system : RoboticMaterialTransportSystem;
        text = "The robotic system shall perform its primary autonomous material transport task using a MobileRobot part as the mission executing element.";
        require constraint {
            system.mobileRobot.maximumPayloadMass >= 8 [kg]
        }
        require constraint {
            system.mobileRobot.maximumMissionDistance >= 1000 [m]
        }
    }

    requirement def AutonomousNavigationRequirement {
        subject robot : MobileRobot;
        text = "The MobileRobot shall localize, plan, and navigate between pickup and delivery stations without continuous manual driving.";
        require constraint {
            robot.localizationAccuracy <= 0.10 [m]
        }
        require constraint {
            robot.maximumSpeed >= 1.0 [m/s]
        }
    }

    requirement def PayloadHandlingRequirement {
        subject robot : MobileRobot;
        text = "The MobileRobot shall load, secure, transport, and unload the assigned payload within its rated payload capacity.";
        require constraint {
            robot.maximumPayloadMass >= 10 [kg]
        }
    }

    requirement def SafeOperationRequirement {
        subject robot : MobileRobot;
        text = "The MobileRobot shall detect obstacles, enforce speed limits, and enter an emergency stopped state when a stop command or unsafe condition is detected.";
        require constraint {
            robot.safetyController.emergencyStopLatency <= 0.150 [s]
        }
        require constraint {
            robot.safetyController.safetyScanRadius >= 0.75 [m]
        }
    }

    requirement def EnergyAutonomyRequirement {
        subject robot : MobileRobot;
        text = "The MobileRobot shall complete a nominal transport mission and return to the charging dock while maintaining battery reserve.";
        require constraint {
            robot.powerSystem.usableEnergy >= 1200 [W h]
        }
        require constraint {
            robot.minimumOperationalSoc >= 15.0
        }
    }

    part roboticSystem : RoboticMaterialTransportSystem;

    requirement primaryTaskRequirement : PrimaryTaskUsingMobileRobotRequirement {
        subject system = roboticSystem;
    }

    requirement autonomousNavigationRequirement : AutonomousNavigationRequirement {
        subject robot = roboticSystem.mobileRobot;
    }

    requirement payloadHandlingRequirement : PayloadHandlingRequirement {
        subject robot = roboticSystem.mobileRobot;
    }

    requirement safeOperationRequirement : SafeOperationRequirement {
        subject robot = roboticSystem.mobileRobot;
    }

    requirement energyAutonomyRequirement : EnergyAutonomyRequirement {
        subject robot = roboticSystem.mobileRobot;
    }

    satisfy primaryTaskRequirement by roboticSystem.mobileRobot;
    satisfy autonomousNavigationRequirement by roboticSystem.mobileRobot.autonomyComputer;
    satisfy autonomousNavigationRequirement by roboticSystem.mobileRobot.localization;
    satisfy autonomousNavigationRequirement by roboticSystem.mobileRobot.navigation;
    satisfy payloadHandlingRequirement by roboticSystem.mobileRobot.payloadHandler;
    satisfy safeOperationRequirement by roboticSystem.mobileRobot.safetyController;
    satisfy safeOperationRequirement by roboticSystem.mobileRobot.perception;
    satisfy energyAutonomyRequirement by roboticSystem.mobileRobot.powerSystem;
    satisfy energyAutonomyRequirement by roboticSystem.chargingDock;
}
