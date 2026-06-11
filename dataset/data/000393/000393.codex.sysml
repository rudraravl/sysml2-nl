package RoboticDeliverySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def Distance :> Real {
        unit = "m";
    }

    value def Speed :> Real {
        unit = "m/s";
    }

    value def Mass :> Real {
        unit = "kg";
    }

    value def Energy :> Real {
        unit = "Wh";
    }

    value def Power :> Real {
        unit = "W";
    }

    value def TimeDuration :> Real {
        unit = "s";
    }

    value def Temperature :> Real {
        unit = "degC";
    }

    value def Percentage :> Real {
        unit = "%";
    }

    value def CurrencyAmount :> Real {
        unit = "USD";
    }

    enum def RobotMode {
        enum idle;
        enum loading;
        enum navigating;
        enum delivering;
        enum returning;
        enum charging;
        enum faulted;
    }

    enum def PackageCondition {
        enum accepted;
        enum secured;
        enum inTransit;
        enum delivered;
        enum rejected;
    }

    enum def NavigationStatus {
        enum routePlanned;
        enum obstacleDetected;
        enum replanning;
        enum arrived;
        enum lostLocalization;
    }

    item def DeliveryOrder {
        attribute orderId : String;
        attribute destinationAddress : String;
        attribute customerName : String;
        attribute promisedDeliveryTime : TimeDuration;
        attribute deliveryFee : CurrencyAmount;
    }

    item def DeliveryPackage {
        attribute packageId : String;
        attribute mass : Mass;
        attribute width : Distance;
        attribute height : Distance;
        attribute depth : Distance;
        attribute condition : PackageCondition;
        attribute requiresTemperatureControl : Boolean;
    }

    item def RoutePlan {
        attribute routeId : String;
        attribute totalDistance : Distance;
        attribute estimatedTravelTime : TimeDuration;
        attribute maximumAllowedSpeed : Speed;
    }

    item def BatteryEnergy {
        attribute remainingEnergy : Energy;
        attribute stateOfCharge : Percentage;
    }

    item def MotionCommand {
        attribute targetLinearSpeed : Speed;
        attribute targetAngularSpeed : Real;
        attribute emergencyStop : Boolean;
    }

    item def LocalizationEstimate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute heading : Real;
        attribute confidence : Percentage;
    }

    item def ObstacleReport {
        attribute obstacleDistance : Distance;
        attribute obstacleBearing : Real;
        attribute collisionRisk : Percentage;
    }

    item def DeliveryConfirmation {
        attribute orderId : String;
        attribute delivered : Boolean;
        attribute recipientVerified : Boolean;
        attribute timestamp : TimeDuration;
    }

    port def OrderPort {
        in item order : DeliveryOrder;
        out item confirmation : DeliveryConfirmation;
    }

    port def PackagePort {
        in item packageIn : DeliveryPackage;
        out item packageOut : DeliveryPackage;
    }

    port def RoutePort {
        out item route : RoutePlan;
        in item localization : LocalizationEstimate;
        in item obstacle : ObstacleReport;
    }

    port def MotionPort {
        in item command : MotionCommand;
    }

    port def BatteryPort {
        out item battery : BatteryEnergy;
        in item powerDemand : Power;
    }

    port def ChargePort {
        in item chargingPower : Power;
        out item batteryState : BatteryEnergy;
    }

    port def TelemetryPort {
        out attribute mode : RobotMode;
        out item localization : LocalizationEstimate;
        out item battery : BatteryEnergy;
    }

    part def DeliveryRobot {
        attribute mode : RobotMode;
        attribute maximumPayloadMass : Mass = 15.0;
        attribute maximumSpeed : Speed = 2.0;
        attribute nominalRange : Distance = 12000.0;
        attribute curbClimbHeight : Distance = 0.08;
        attribute safeStoppingDistance : Distance = 1.2;

        port orderPort : OrderPort;
        port packagePort : PackagePort;
        port chargePort : ChargePort;
        port telemetryPort : TelemetryPort;

        part chassis : Chassis;
        part driveSystem : DifferentialDriveSystem;
        part batterySystem : BatterySystem;
        part navigationSystem : NavigationSystem;
        part perceptionSystem : PerceptionSystem;
        part cargoBay : CargoBay;
        part deliveryInterface : DeliveryInterface;
        part safetyController : SafetyController;
        part computeModule : ComputeModule;

        connect batterySystem.powerOut to driveSystem.powerIn;
        connect batterySystem.powerOut to computeModule.powerIn;
        connect batterySystem.powerOut to cargoBay.powerIn;
        connect perceptionSystem.obstacleOut to navigationSystem.obstacleIn;
        connect navigationSystem.motionCommandOut to safetyController.motionCommandIn;
        connect safetyController.safeMotionCommandOut to driveSystem.motionCommandIn;
        connect navigationSystem.localizationOut to telemetryPort.localization;
        connect batterySystem.batteryOut to telemetryPort.battery;
        connect cargoBay.packagePort to packagePort;
        connect deliveryInterface.orderPort to orderPort;
    }

    part def Chassis {
        attribute mass : Mass = 38.0;
        attribute length : Distance = 0.95;
        attribute width : Distance = 0.62;
        attribute height : Distance = 1.10;
        attribute ingressProtectionRating : String = "IP54";
    }

    part def DifferentialDriveSystem {
        attribute wheelRadius : Distance = 0.13;
        attribute trackWidth : Distance = 0.50;
        attribute maximumContinuousPower : Power = 850.0;

        port powerIn : BatteryPort;
        port motionCommandIn : MotionPort;

        part leftMotor : DriveMotor;
        part rightMotor : DriveMotor;
        part leftWheel : Wheel;
        part rightWheel : Wheel;

        connect leftMotor.shaft to leftWheel.hub;
        connect rightMotor.shaft to rightWheel.hub;
    }

    part def DriveMotor {
        attribute ratedPower : Power = 425.0;
        attribute peakPower : Power = 900.0;
        port shaft : MechanicalRotaryPort;
    }

    part def Wheel {
        attribute diameter : Distance = 0.26;
        attribute tirePressure : Real = 240.0;
        port hub : MechanicalRotaryPort;
    }

    port def MechanicalRotaryPort {
        in attribute torque : Real;
        in attribute angularVelocity : Real;
    }

    part def BatterySystem {
        attribute capacity : Energy = 1800.0;
        attribute minimumDispatchCharge : Percentage = 70.0;
        attribute reserveCharge : Percentage = 15.0;
        attribute maximumDischargePower : Power = 1600.0;
        attribute currentStateOfCharge : Percentage;

        port powerOut : BatteryPort;
        port chargePort : ChargePort;
        port batteryOut : BatteryPort;
    }

    part def ComputeModule {
        attribute processorTemperature : Temperature;
        attribute nominalPower : Power = 85.0;
        port powerIn : BatteryPort;
    }

    part def NavigationSystem {
        attribute localizationConfidence : Percentage;
        attribute plannedRouteDistance : Distance;

        port obstacleIn : RoutePort;
        port localizationOut : RoutePort;
        port motionCommandOut : MotionPort;

        part routePlanner : RoutePlanner;
        part localizationUnit : LocalizationUnit;
        part pathFollower : PathFollower;

        connect routePlanner.routeOut to pathFollower.routeIn;
        connect localizationUnit.localizationOut to pathFollower.localizationIn;
    }

    part def RoutePlanner {
        attribute replanningLimit : Integer = 5;
        port routeOut : RoutePort;
    }

    part def LocalizationUnit {
        attribute gpsAccuracy : Distance = 1.5;
        attribute odometryDriftPerMeter : Real = 0.01;
        port localizationOut : RoutePort;
    }

    part def PathFollower {
        attribute trackingTolerance : Distance = 0.25;
        port routeIn : RoutePort;
        port localizationIn : RoutePort;
        port commandOut : MotionPort;
    }

    part def PerceptionSystem {
        attribute forwardDetectionRange : Distance = 18.0;
        attribute sideDetectionRange : Distance = 6.0;

        port obstacleOut : RoutePort;

        part lidar : LidarSensor;
        part cameraArray : CameraArray;
        part ultrasonicRing : UltrasonicRing;
    }

    part def LidarSensor {
        attribute range : Distance = 30.0;
        attribute horizontalFieldOfView : Real = 270.0;
    }

    part def CameraArray {
        attribute cameraCount : Integer = 4;
        attribute frameRate : Real = 30.0;
    }

    part def UltrasonicRing {
        attribute sensorCount : Integer = 12;
        attribute minimumRange : Distance = 0.05;
        attribute maximumRange : Distance = 4.0;
    }

    part def CargoBay {
        attribute usableVolume : Real = 0.12;
        attribute payloadMassLimit : Mass = 15.0;
        attribute internalTemperature : Temperature;
        attribute locked : Boolean;

        port packagePort : PackagePort;
        port powerIn : BatteryPort;

        part lock : CargoLock;
        part scale : PayloadScale;
        part temperatureController : TemperatureController;
    }

    part def CargoLock {
        attribute locked : Boolean;
        attribute tamperDetected : Boolean;
    }

    part def PayloadScale {
        attribute measuredMass : Mass;
        attribute accuracy : Mass = 0.05;
    }

    part def TemperatureController {
        attribute setpoint : Temperature = 8.0;
        attribute tolerance : Temperature = 2.0;
        attribute maximumPower : Power = 120.0;
    }

    part def DeliveryInterface {
        attribute screenBrightness : Percentage = 80.0;
        attribute authenticationTimeout : TimeDuration = 60.0;

        port orderPort : OrderPort;

        part display : TouchDisplay;
        part scanner : CodeScanner;
        part speaker : Speaker;
    }

    part def TouchDisplay {
        attribute diagonalSize : Distance = 0.18;
    }

    part def CodeScanner {
        attribute scanDistance : Distance = 0.45;
    }

    part def Speaker {
        attribute soundPressureLevel : Real = 72.0;
    }

    part def SafetyController {
        attribute emergencyStopActive : Boolean;
        attribute minimumHumanClearance : Distance = 1.0;

        port motionCommandIn : MotionPort;
        port safeMotionCommandOut : MotionPort;
    }

    part def ChargingDock {
        attribute maximumChargingPower : Power = 650.0;
        attribute dockingTolerance : Distance = 0.04;

        port chargePort : ChargePort;
    }

    part def FleetOperationsCenter {
        attribute activeRobotCount : Integer;
        attribute dispatchQueueLength : Integer;

        port orderDispatchPort : OrderPort;
        port telemetryIn : TelemetryPort;
    }

    part def DeliveryEnvironment {
        attribute operatingAreaRadius : Distance = 5000.0;
        attribute maximumAllowedGrade : Real = 8.0;
        attribute minimumOperatingTemperature : Temperature = -10.0;
        attribute maximumOperatingTemperature : Temperature = 40.0;

        part sidewalkNetwork : SidewalkNetwork;
        part crosswalkNetwork : CrosswalkNetwork;
        part customerDropoffZone : DropoffZone;
    }

    part def SidewalkNetwork {
        attribute totalLength : Distance = 24000.0;
        attribute minimumWidth : Distance = 1.5;
    }

    part def CrosswalkNetwork {
        attribute crossingCount : Integer = 42;
        attribute averageCrossingDistance : Distance = 14.0;
    }

    part def DropoffZone {
        attribute accessRadius : Distance = 2.0;
        attribute requiresRecipientAuthentication : Boolean = true;
    }

    part def RoboticDeliveryMission {
        part robot : DeliveryRobot;
        part dock : ChargingDock;
        part operationsCenter : FleetOperationsCenter;
        part environment : DeliveryEnvironment;

        connect operationsCenter.orderDispatchPort to robot.orderPort;
        connect robot.telemetryPort to operationsCenter.telemetryIn;
        connect dock.chargePort to robot.chargePort;
    }

    action def AcceptDeliveryOrder {
        in item order : DeliveryOrder;
        in item package : DeliveryPackage;
        out attribute accepted : Boolean;

        first start;
        then validatePayload;
        then validateDestination;
        then validateBatteryReserve;
        then decision;

        action validatePayload;
        action validateDestination;
        action validateBatteryReserve;
        action decision;
    }

    action def PlanDeliveryRoute {
        in item order : DeliveryOrder;
        in item localization : LocalizationEstimate;
        out item route : RoutePlan;

        first receiveDestination;
        then computeCandidateRoutes;
        then evaluateEnergyCost;
        then selectSafestRoute;
        then publishRoute;

        action receiveDestination;
        action computeCandidateRoutes;
        action evaluateEnergyCost;
        action selectSafestRoute;
        action publishRoute;
    }

    action def NavigateToDestination {
        in item route : RoutePlan;
        in item localization : LocalizationEstimate;
        in item obstacle : ObstacleReport;
        out item command : MotionCommand;
        out attribute status : NavigationStatus;

        first followRoute;
        then monitorObstacle;
        then decideAvoidance;

        action followRoute;
        action monitorObstacle;
        action decideAvoidance;

        if obstacle.collisionRisk > 50.0 then avoidObstacle;
        else continueRoute;

        action avoidObstacle;
        action continueRoute;
    }

    action def PerformDelivery {
        in item order : DeliveryOrder;
        in item package : DeliveryPackage;
        out item confirmation : DeliveryConfirmation;

        first arriveAtDropoff;
        then authenticateRecipient;
        then unlockCargoBay;
        then releasePackage;
        then lockCargoBay;
        then recordConfirmation;

        action arriveAtDropoff;
        action authenticateRecipient;
        action unlockCargoBay;
        action releasePackage;
        action lockCargoBay;
        action recordConfirmation;
    }

    action def ReturnToDock {
        in item localization : LocalizationEstimate;
        out item route : RoutePlan;

        first identifyNearestDock;
        then planReturnRoute;
        then navigateToDock;
        then performDocking;

        action identifyNearestDock;
        action planReturnRoute;
        action navigateToDock;
        action performDocking;
    }

    action def ChargeBattery {
        in item battery : BatteryEnergy;
        in attribute chargingPower : Power;
        out item chargedBattery : BatteryEnergy;

        first docked;
        then enableCharging;
        then monitorStateOfCharge;
        then stopAtTargetCharge;

        action docked;
        action enableCharging;
        action monitorStateOfCharge;
        action stopAtTargetCharge;
    }

    state def DeliveryRobotStateMachine {
        entry action initializeRobot;

        state Off;
        state Idle;
        state Loading;
        state RoutePlanning;
        state Navigating;
        state ObstacleAvoidance;
        state Arrived;
        state RecipientAuthentication;
        state PackageRelease;
        state ReturningToDock;
        state Charging;
        state Fault;

        transition first Off then Idle
            effect initializeRobot;

        transition Idle then Loading
            accept orderReceived
            guard batteryStateOfCharge >= 70.0;

        transition Loading then RoutePlanning
            accept packageSecured
            guard payloadMass <= 15.0;

        transition RoutePlanning then Navigating
            accept routeAvailable;

        transition Navigating then ObstacleAvoidance
            accept obstacleDetected
            guard collisionRisk >= 35.0;

        transition ObstacleAvoidance then Navigating
            accept obstacleCleared;

        transition Navigating then Arrived
            accept destinationReached;

        transition Arrived then RecipientAuthentication
            accept customerPresent;

        transition RecipientAuthentication then PackageRelease
            accept recipientVerified;

        transition PackageRelease then ReturningToDock
            accept deliveryConfirmed;

        transition ReturningToDock then Charging
            accept docked;

        transition Charging then Idle
            accept chargeComplete
            guard batteryStateOfCharge >= 90.0;

        transition Idle then Charging
            accept lowBattery
            guard batteryStateOfCharge < 30.0;

        transition Navigating then ReturningToDock
            accept lowBattery
            guard batteryStateOfCharge < 20.0;

        transition Loading then Fault
            accept payloadRejected;

        transition Navigating then Fault
            accept localizationLost
            guard localizationConfidence < 40.0;

        transition Fault then Idle
            accept operatorReset;

        action initializeRobot;
    }

    requirement def PrimaryDeliveryCapability {
        subject robot : DeliveryRobot;

        require constraint {
            robot.maximumPayloadMass >= 10.0
        }

        require constraint {
            robot.maximumSpeed <= 2.5
        }

        require constraint {
            robot.nominalRange >= 8000.0
        }
    }

    requirement def SafeNavigationRequirement {
        subject robot : DeliveryRobot;

        require constraint {
            robot.safeStoppingDistance <= 1.5
        }

        require constraint {
            robot.perceptionSystem.forwardDetectionRange >= 15.0
        }

        require constraint {
            robot.safetyController.minimumHumanClearance >= 1.0
        }
    }

    requirement def CargoSecurityRequirement {
        subject bay : CargoBay;

        require constraint {
            bay.payloadMassLimit >= 10.0
        }

        require constraint {
            bay.locked == true
        }
    }

    requirement def BatteryDispatchRequirement {
        subject battery : BatterySystem;

        require constraint {
            battery.minimumDispatchCharge >= 70.0
        }

        require constraint {
            battery.reserveCharge >= 15.0
        }

        require constraint {
            battery.capacity >= 1500.0
        }
    }

    requirement def DeliveryConfirmationRequirement {
        subject interface : DeliveryInterface;

        require constraint {
            interface.authenticationTimeout <= 90.0
        }
    }

    requirement def OperatingEnvironmentRequirement {
        subject environment : DeliveryEnvironment;

        require constraint {
            environment.maximumAllowedGrade <= 10.0
        }

        require constraint {
            environment.minimumOperatingTemperature <= -5.0
        }

        require constraint {
            environment.maximumOperatingTemperature >= 35.0
        }
    }

    satisfy PrimaryDeliveryCapability by DeliveryRobot;
    satisfy SafeNavigationRequirement by DeliveryRobot;
    satisfy CargoSecurityRequirement by CargoBay;
    satisfy BatteryDispatchRequirement by BatterySystem;
    satisfy DeliveryConfirmationRequirement by DeliveryInterface;
    satisfy OperatingEnvironmentRequirement by DeliveryEnvironment;

}