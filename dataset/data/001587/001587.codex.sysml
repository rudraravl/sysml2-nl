package StarshipAutonomousDeliverySystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def CurrencyUSD : Real {
        unit = "USD";
    }

    attribute def Latitude : Real {
        unit = "deg";
    }

    attribute def Longitude : Real {
        unit = "deg";
    }

    attribute def Speed : Real {
        unit = "m/s";
    }

    attribute def Distance : Real {
        unit = "m";
    }

    attribute def MassKg : Real {
        unit = "kg";
    }

    attribute def EnergyWh : Real {
        unit = "W*h";
    }

    attribute def PowerW : Real {
        unit = "W";
    }

    attribute def TemperatureC : Real {
        unit = "degC";
    }

    attribute def TimeS : Real {
        unit = "s";
    }

    item def DeliveryOrder {
        attribute orderId : String;
        attribute pickupLatitude : Latitude;
        attribute pickupLongitude : Longitude;
        attribute dropoffLatitude : Latitude;
        attribute dropoffLongitude : Longitude;
        attribute recipientId : String;
        attribute cargoMass : MassKg;
        attribute paidAmount : CurrencyUSD;
        attribute requestedDeliveryWindow : TimeS;
    }

    item def CargoPackage {
        attribute packageId : String;
        attribute mass : MassKg;
        attribute volumeLiters : Real;
        attribute temperatureSensitive : Boolean;
        attribute sealed : Boolean;
    }

    item def RoutePlan {
        attribute routeId : String;
        attribute totalDistance : Distance;
        attribute estimatedDuration : TimeS;
        attribute maximumPlannedSpeed : Speed;
        attribute includesRoadCrossing : Boolean;
    }

    item def RobotPose {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute headingDeg : Real;
        attribute speed : Speed;
        attribute positionUncertainty : Distance;
    }

    item def ObstacleReport {
        attribute obstacleId : String;
        attribute range : Distance;
        attribute bearingDeg : Real;
        attribute relativeSpeed : Speed;
        attribute classification : String;
        attribute collisionRisk : Percent;
    }

    item def CustomerAccessToken {
        attribute tokenId : String;
        attribute recipientId : String;
        attribute validForOrderId : String;
        attribute expiration : TimeS;
    }

    item def TelemetryPacket {
        attribute robotId : String;
        attribute pose : RobotPose;
        attribute batteryStateOfCharge : Percent;
        attribute cargoBayLocked : Boolean;
        attribute activeOrderId : String;
        attribute faultCode : String;
    }

    item def UnlockCommand {
        attribute orderId : String;
        attribute token : CustomerAccessToken;
    }

    port def OrderServicePort {
        in item order : DeliveryOrder;
        out item status : TelemetryPacket;
    }

    port def CargoTransferPort {
        in item package : CargoPackage;
        out item packageReleased : CargoPackage;
    }

    port def NavigationDataPort {
        out item pose : RobotPose;
        out item obstacle : ObstacleReport;
        in item route : RoutePlan;
    }

    port def RemoteOpsPort {
        out item telemetry : TelemetryPacket;
        in item operatorRoute : RoutePlan;
        in item emergencyStop : Boolean;
    }

    port def CustomerAccessPort {
        in item unlock : UnlockCommand;
        out item packageReleased : CargoPackage;
    }

    port def ElectricalPowerPort {
        out attribute suppliedPower : PowerW;
        in attribute demandedPower : PowerW;
    }

    port def DriveCommandPort {
        in attribute targetSpeed : Speed;
        in attribute steeringAngleDeg : Real;
        out attribute measuredSpeed : Speed;
    }

    part def StarshipDeliveryRobot {
        attribute robotId : String;
        attribute curbWeight : MassKg = 25.0;
        attribute maximumCargoMass : MassKg = 10.0;
        attribute maximumSpeed : Speed = 1.8;
        attribute operationalRange : Distance = 6400.0;
        attribute minimumSafeBatterySoc : Percent = 15.0;
        attribute nominalBatteryEnergy : EnergyWh = 500.0;

        port orderPort : OrderServicePort;
        port loadingPort : CargoTransferPort;
        port customerPort : CustomerAccessPort;
        port remoteOpsPort : RemoteOpsPort;

        part chassis : Chassis;
        part cargoBay : SecureCargoBay;
        part perception : PerceptionSuite;
        part localization : LocalizationSubsystem;
        part navigation : AutonomousNavigationController;
        part drive : SixWheelDrive;
        part battery : BatterySystem;
        part communication : CommunicationSubsystem;
        part safety : SafetySupervisor;
        part userInterface : RecipientInterface;

        bind battery.powerOut = drive.powerIn;
        bind battery.powerOut = perception.powerIn;
        bind battery.powerOut = communication.powerIn;
        bind battery.powerOut = cargoBay.powerIn;

        connect orderPort.order to navigation.orderInput;
        connect loadingPort.package to cargoBay.loadInput;
        connect cargoBay.releaseOutput to customerPort.packageReleased;
        connect perception.navigationData to navigation.navigationData;
        connect localization.poseOutput to navigation.poseInput;
        connect navigation.driveCommand to drive.commandInput;
        connect navigation.routeStatus to communication.telemetryInput;
        connect safety.remoteOps to remoteOpsPort;
        connect communication.telemetryOutput to remoteOpsPort.telemetry;
        connect remoteOpsPort.operatorRoute to navigation.remoteRouteInput;
        connect remoteOpsPort.emergencyStop to safety.emergencyStopInput;
        connect customerPort.unlock to userInterface.unlockInput;
        connect userInterface.validUnlock to cargoBay.unlockInput;

        perform action acceptAndDeliverOrder;
        exhibit state robotOperationalStates;
    }

    part def Chassis {
        attribute ingressProtectionRating : String = "IP54";
        attribute wheelCount : Integer = 6;
        attribute maximumStaticLoad : MassKg = 40.0;
    }

    part def SecureCargoBay {
        attribute internalVolumeLiters : Real = 40.0;
        attribute maximumPayloadMass : MassKg = 10.0;
        attribute lockEngaged : Boolean = true;
        attribute cargoPresent : Boolean = false;
        attribute cargoTemperature : TemperatureC;

        port loadInput : CargoTransferPort;
        port releaseOutput : CargoTransferPort;
        port unlockInput {
            in attribute authorized : Boolean;
        }
        port powerIn : ElectricalPowerPort;

        action loadCargo {
            in item package : CargoPackage;
            first start;
            then verifyMass;
            then closeLid;
            then engageLock;
            then loaded;

            action verifyMass {
                assert constraint { package.mass <= maximumPayloadMass; }
            }

            action closeLid;
            action engageLock {
                lockEngaged = true;
                cargoPresent = true;
            }
        }

        action releaseCargo {
            in attribute authorized : Boolean;
            first verifyAuthorization;
            then disengageLock;
            then releasePackage;
            then empty;

            action verifyAuthorization {
                assert constraint { authorized == true; }
            }

            action disengageLock {
                lockEngaged = false;
            }

            action releasePackage {
                cargoPresent = false;
            }
        }
    }

    part def PerceptionSuite {
        attribute cameraCount : Integer = 10;
        attribute ultrasonicSensorCount : Integer = 12;
        attribute detectionRange : Distance = 20.0;
        attribute minimumObstacleClearance : Distance = 0.25;

        port powerIn : ElectricalPowerPort;
        port navigationData : NavigationDataPort;

        part cameras : CameraArray;
        part ultrasonicRing : UltrasonicRing;
        part obstacleClassifier : ObstacleClassifier;

        connect cameras.imageFeatures to obstacleClassifier.cameraFeatures;
        connect ultrasonicRing.rangeReadings to obstacleClassifier.rangeFeatures;
        connect obstacleClassifier.obstacleOutput to navigationData.obstacle;
    }

    part def CameraArray {
        attribute horizontalCoverageDeg : Real = 360.0;
        attribute frameRateHz : Real = 30.0;

        port imageFeatures {
            out attribute featureConfidence : Percent;
        }
    }

    part def UltrasonicRing {
        attribute minimumRange : Distance = 0.05;
        attribute maximumRange : Distance = 5.0;

        port rangeReadings {
            out attribute nearestRange : Distance;
        }
    }

    part def ObstacleClassifier {
        port cameraFeatures {
            in attribute featureConfidence : Percent;
        }

        port rangeFeatures {
            in attribute nearestRange : Distance;
        }

        port obstacleOutput {
            out item obstacle : ObstacleReport;
        }
    }

    part def LocalizationSubsystem {
        attribute nominalPositionAccuracy : Distance = 0.20;
        attribute gnssAvailable : Boolean;
        attribute mapMatched : Boolean;

        port poseOutput {
            out item pose : RobotPose;
        }

        part gnssReceiver : GNSSReceiver;
        part inertialUnit : InertialMeasurementUnit;
        part wheelOdometry : WheelOdometry;
        part mapMatcher : SidewalkMapMatcher;

        connect gnssReceiver.gnssPose to mapMatcher.gnssInput;
        connect inertialUnit.motionDelta to mapMatcher.imuInput;
        connect wheelOdometry.odometryDelta to mapMatcher.odometryInput;
        connect mapMatcher.poseEstimate to poseOutput.pose;
    }

    part def GNSSReceiver {
        attribute updateRateHz : Real = 5.0;
        port gnssPose {
            out item pose : RobotPose;
        }
    }

    part def InertialMeasurementUnit {
        attribute updateRateHz : Real = 100.0;
        port motionDelta {
            out attribute yawRateDegPerS : Real;
            out attribute accelerationMps2 : Real;
        }
    }

    part def WheelOdometry {
        attribute tickResolution : Integer = 2048;
        port odometryDelta {
            out attribute distanceDelta : Distance;
            out attribute headingDeltaDeg : Real;
        }
    }

    part def SidewalkMapMatcher {
        port gnssInput {
            in item pose : RobotPose;
        }

        port imuInput {
            in attribute yawRateDegPerS : Real;
            in attribute accelerationMps2 : Real;
        }

        port odometryInput {
            in attribute distanceDelta : Distance;
            in attribute headingDeltaDeg : Real;
        }

        port poseEstimate {
            out item pose : RobotPose;
        }
    }

    part def AutonomousNavigationController {
        attribute activeRoute : RoutePlan;
        attribute commandedSpeed : Speed;
        attribute destinationReached : Boolean = false;
        attribute safeToProceed : Boolean = true;

        port orderInput {
            in item order : DeliveryOrder;
        }

        port poseInput {
            in item pose : RobotPose;
        }

        port navigationData : NavigationDataPort;

        port remoteRouteInput {
            in item route : RoutePlan;
        }

        port driveCommand : DriveCommandPort;

        port routeStatus {
            out item telemetry : TelemetryPacket;
        }

        action planSidewalkRoute {
            in item order : DeliveryOrder;
            out item route : RoutePlan;
        }

        action followRoute {
            in item route : RoutePlan;
            in item pose : RobotPose;
            out attribute targetSpeed : Speed;
            out attribute steeringAngleDeg : Real;
        }

        action yieldToPedestrian {
            in item obstacle : ObstacleReport;
            out attribute targetSpeed : Speed;
        }

        action crossStreetWhenClear {
            in item pose : RobotPose;
            in item obstacle : ObstacleReport;
            out attribute targetSpeed : Speed;
        }

        exhibit state navigationStates;
    }

    part def SixWheelDrive {
        attribute wheelCount : Integer = 6;
        attribute peakDrivePower : PowerW = 250.0;
        attribute maximumClimbGradePercent : Percent = 15.0;
        attribute measuredSpeed : Speed;

        port powerIn : ElectricalPowerPort;
        port commandInput : DriveCommandPort;

        part leftMotors : WheelMotorSet;
        part rightMotors : WheelMotorSet;

        connect commandInput.targetSpeed to leftMotors.targetSpeed;
        connect commandInput.targetSpeed to rightMotors.targetSpeed;
    }

    part def WheelMotorSet {
        attribute motorCount : Integer = 3;
        attribute continuousPower : PowerW = 90.0;

        port targetSpeed {
            in attribute speed : Speed;
        }
    }

    part def BatterySystem {
        attribute stateOfCharge : Percent = 100.0;
        attribute energyCapacity : EnergyWh = 500.0;
        attribute maximumContinuousPower : PowerW = 400.0;
        attribute lowBatteryThreshold : Percent = 20.0;

        port powerOut : ElectricalPowerPort;
        port chargePort {
            in attribute chargePower : PowerW;
            out attribute stateOfCharge : Percent;
        }

        action supplyPower {
            in attribute demandedPower : PowerW;
            out attribute suppliedPower : PowerW;
            assert constraint { demandedPower <= maximumContinuousPower; }
        }

        action recharge {
            in attribute chargePower : PowerW;
            assert constraint { chargePower <= 250.0 [W]; }
        }
    }

    part def CommunicationSubsystem {
        attribute cellularConnected : Boolean;
        attribute wifiConnected : Boolean;
        attribute encryptedSessionActive : Boolean;

        port telemetryInput {
            in item telemetry : TelemetryPacket;
        }

        port telemetryOutput {
            out item telemetry : TelemetryPacket;
        }

        port orderService : OrderServicePort;

        action publishTelemetry {
            in item telemetry : TelemetryPacket;
            out item transmittedTelemetry : TelemetryPacket;
        }

        action receiveOrder {
            out item order : DeliveryOrder;
        }
    }

    part def SafetySupervisor {
        attribute emergencyStopActive : Boolean = false;
        attribute minimumPedestrianClearance : Distance = 0.50;
        attribute maximumFaultResponseTime : TimeS = 0.25;

        port remoteOps : RemoteOpsPort;
        port emergencyStopInput {
            in attribute stopRequested : Boolean;
        }

        action evaluateHazards {
            in item obstacle : ObstacleReport;
            in item pose : RobotPose;
            out attribute safeToProceed : Boolean;
        }

        action executeSafeStop {
            out attribute targetSpeed : Speed = 0.0;
        }
    }

    part def RecipientInterface {
        attribute displayEnabled : Boolean = true;
        attribute audioPromptEnabled : Boolean = true;

        port unlockInput {
            in item unlock : UnlockCommand;
        }

        port validUnlock {
            out attribute authorized : Boolean;
        }

        action authenticateRecipient {
            in item unlock : UnlockCommand;
            out attribute authorized : Boolean;
            assert constraint { unlock.token.validForOrderId == unlock.orderId; }
        }
    }

    action def AcceptAndDeliverOrder {
        in item order : DeliveryOrder;
        out item deliveredPackage : CargoPackage;

        first receiveOrder;
        then loadAtMerchant;
        then calculateRoute;
        then navigateToCustomer;
        then authenticateCustomer;
        then unlockCargoBay;
        then completeDelivery;

        action receiveOrder {
            in item order : DeliveryOrder;
        }

        action loadAtMerchant {
            in item package : CargoPackage;
            assert constraint { package.mass <= 10.0 [kg]; }
        }

        action calculateRoute {
            in item order : DeliveryOrder;
            out item route : RoutePlan;
        }

        action navigateToCustomer {
            in item route : RoutePlan;
            assert constraint { route.maximumPlannedSpeed <= 1.8 [m/s]; }
        }

        action authenticateCustomer {
            in item token : CustomerAccessToken;
            out attribute authorized : Boolean;
        }

        action unlockCargoBay {
            in attribute authorized : Boolean;
            assert constraint { authorized == true; }
        }

        action completeDelivery {
            out item deliveredPackage : CargoPackage;
        }
    }

    state def RobotOperationalStates {
        entry action initializeSystems;

        state Idle;
        state Assigned;
        state Loading;
        state RoutePlanning;
        state EnRouteToCustomer;
        state WaitingAtCrossing;
        state YieldingToPedestrian;
        state Arrived;
        state AwaitingRecipientAuthentication;
        state CargoUnlocked;
        state DeliveryComplete;
        state ReturningToBase;
        state Charging;
        state FaultSafeStopped;

        transition first Idle;
        transition Idle_to_Assigned
            first Idle
            accept DeliveryOrder
            then Assigned;

        transition Assigned_to_Loading
            first Assigned
            then Loading;

        transition Loading_to_RoutePlanning
            first Loading
            if cargoBay.cargoPresent == true
            then RoutePlanning;

        transition RoutePlanning_to_EnRoute
            first RoutePlanning
            if navigation.activeRoute.totalDistance > 0.0 [m]
            then EnRouteToCustomer;

        transition EnRoute_to_Yielding
            first EnRouteToCustomer
            if navigation.safeToProceed == false
            then YieldingToPedestrian;

        transition Yielding_to_EnRoute
            first YieldingToPedestrian
            if navigation.safeToProceed == true
            then EnRouteToCustomer;

        transition EnRoute_to_Crossing
            first EnRouteToCustomer
            if navigation.activeRoute.includesRoadCrossing == true
            then WaitingAtCrossing;

        transition Crossing_to_EnRoute
            first WaitingAtCrossing
            if navigation.safeToProceed == true
            then EnRouteToCustomer;

        transition EnRoute_to_Arrived
            first EnRouteToCustomer
            if navigation.destinationReached == true
            then Arrived;

        transition Arrived_to_Auth
            first Arrived
            then AwaitingRecipientAuthentication;

        transition Auth_to_Unlocked
            first AwaitingRecipientAuthentication
            if cargoBay.lockEngaged == false
            then CargoUnlocked;

        transition Unlocked_to_Complete
            first CargoUnlocked
            if cargoBay.cargoPresent == false
            then DeliveryComplete;

        transition Complete_to_Return
            first DeliveryComplete
            then ReturningToBase;

        transition Return_to_Charging
            first ReturningToBase
            if battery.stateOfCharge < battery.lowBatteryThreshold
            then Charging;

        transition Charging_to_Idle
            first Charging
            if battery.stateOfCharge >= 95.0 [%]
            then Idle;

        transition Any_to_Fault
            first Idle, Assigned, Loading, RoutePlanning, EnRouteToCustomer, WaitingAtCrossing, YieldingToPedestrian, Arrived, AwaitingRecipientAuthentication, CargoUnlocked, ReturningToBase
            if safety.emergencyStopActive == true
            then FaultSafeStopped;
    }

    state def NavigationStates {
        state NoRoute;
        state RouteAvailable;
        state TrackingPath;
        state AvoidingObstacle;
        state StoppedForHazard;
        state DestinationReached;

        transition first NoRoute;

        transition NoRoute_to_RouteAvailable
            first NoRoute
            if activeRoute.totalDistance > 0.0 [m]
            then RouteAvailable;

        transition RouteAvailable_to_Tracking
            first RouteAvailable
            then TrackingPath;

        transition Tracking_to_Avoiding
            first TrackingPath
            if safeToProceed == false
            then AvoidingObstacle;

        transition Avoiding_to_Tracking
            first AvoidingObstacle
            if safeToProceed == true
            then TrackingPath;

        transition Tracking_to_Stopped
            first TrackingPath
            if commandedSpeed == 0.0 [m/s] and safeToProceed == false
            then StoppedForHazard;

        transition Stopped_to_Tracking
            first StoppedForHazard
            if safeToProceed == true
            then TrackingPath;

        transition Tracking_to_DestinationReached
            first TrackingPath
            if destinationReached == true
            then DestinationReached;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The system shall autonomously transport a customer order from a merchant pickup location to a recipient dropoff location using a compact sidewalk delivery robot, while protecting cargo, avoiding pedestrians and obstacles, communicating telemetry, and enabling secure recipient pickup. */

        subject robot : StarshipDeliveryRobot;

        require constraint {
            robot.maximumCargoMass >= 10.0 [kg] and
            robot.maximumSpeed <= 1.8 [m/s] and
            robot.operationalRange >= 6000.0 [m]
        }
    }

    requirement def SecureCargoRequirement {
        subject bay : SecureCargoBay;

        require constraint {
            bay.lockEngaged == true implies bay.cargoPresent == true or bay.cargoPresent == false
        }
    }

    requirement def PedestrianSafetyRequirement {
        subject supervisor : SafetySupervisor;

        require constraint {
            supervisor.minimumPedestrianClearance >= 0.50 [m] and
            supervisor.maximumFaultResponseTime <= 0.25 [s]
        }
    }

    requirement def BatteryRangeRequirement {
        subject battery : BatterySystem;

        require constraint {
            battery.energyCapacity >= 500.0 [W*h] and
            battery.lowBatteryThreshold >= 15.0 [%]
        }
    }

    requirement def RecipientAuthenticationRequirement {
        subject interface : RecipientInterface;

        require constraint {
            interface.displayEnabled == true
        }
    }

    requirement def TelemetryRequirement {
        subject communication : CommunicationSubsystem;

        require constraint {
            communication.encryptedSessionActive == true
        }
    }

    part starshipBasedDeliverySystem : StarshipDeliveryRobot {
        attribute robotId = "SBR-001";

        satisfy PrimaryFunctionRequirement by starshipBasedDeliverySystem;
        satisfy SecureCargoRequirement by cargoBay;
        satisfy PedestrianSafetyRequirement by safety;
        satisfy BatteryRangeRequirement by battery;
        satisfy RecipientAuthenticationRequirement by userInterface;
        satisfy TelemetryRequirement by communication;
    }
}