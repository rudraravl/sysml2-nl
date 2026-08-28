package StarshipDeliveryRobot {

    private import ScalarValues::*;

    package Units {
        unit m;
        unit 'm/s';
        unit 'm/s^2';
        unit rad;
        unit 'rad/s';
        unit deg;
        unit 'deg/s';
        unit kg;
        unit degC;
        unit percent;
        unit s;
        unit W;
        unit V;
        unit Hz;
        unit Ah;
    }

    package ValueTypes {
        value type Distance :> Real { unit m; }
        value type Speed :> Real { unit 'm/s'; }
        value type Acceleration :> Real { unit 'm/s^2'; }
        value type Angle :> Real { unit rad; }
        value type AngularVelocity :> Real { unit 'rad/s'; }
        value type Heading :> Real { unit deg; }
        value type Mass :> Real { unit kg; }
        value type Temperature :> Real { unit degC; }
        value type BatteryLevel :> Real { unit percent; }
        value type Duration :> Real { unit s; }
        value type Power :> Real { unit W; }
        value type Voltage :> Real { unit V; }
        value type Frequency :> Real { unit Hz; }
        value type Current :> Real { unit Ah; }
    }

    package Items {

        item def DeliveryOrder {
            attribute orderId : String;
            attribute pickupLocation : String;
            attribute dropoffLocation : String;
            attribute packageId : String;
            attribute recipientCode : String;
            attribute priority : Integer default 1;
            attribute requiresTempControl : Boolean default false;
            attribute targetTemperature : Temperature default 4.0;
        }

        item def Package {
            attribute packageId : String;
            attribute mass : Mass;
            attribute requiresTempControl : Boolean;
            attribute targetTemperature : Temperature;
            attribute fragile : Boolean default false;
        }

        item def SecurityCode {
            attribute codeValue : String;
            attribute valid : Boolean;
        }

        item def LidarScan {
            attribute ranges : Distance[0..*];
            attribute minRange : Distance default 0.1;
            attribute maxRange : Distance default 100.0;
            attribute angularResolution : Angle default 0.5;
            attribute timestamp : Duration;
        }

        item def CameraImage {
            attribute imageId : String;
            attribute widthPixels : Integer default 1920;
            attribute heightPixels : Integer default 1080;
            attribute timestamp : Duration;
        }

        item def UltrasonicEcho {
            attribute distance : Distance;
            attribute confidence : Real default 1.0;
            attribute timestamp : Duration;
        }

        item def GPSFix {
            attribute latitude : Real;
            attribute longitude : Real;
            attribute altitude : Distance;
            attribute horizontalAccuracy : Distance;
            attribute timestamp : Duration;
        }

        item def IMUMeasurement {
            attribute linearAccelerationX : Acceleration;
            attribute linearAccelerationY : Acceleration;
            attribute linearAccelerationZ : Acceleration;
            attribute angularVelocityX : AngularVelocity;
            attribute angularVelocityY : AngularVelocity;
            attribute angularVelocityZ : AngularVelocity;
            attribute roll : Angle;
            attribute pitch : Angle;
            attribute yaw : Angle;
            attribute timestamp : Duration;
        }

        item def EnvironmentMap {
            attribute occupancyGrid : Real[0..*];
            attribute resolution : Distance default 0.05;
            attribute fieldOfViewDeg : Real default 360.0;
            attribute timestamp : Duration;
        }

        item def Pose {
            attribute x : Distance;
            attribute y : Distance;
            attribute heading : Heading;
            attribute confidence : Real default 1.0;
        }

        item def Route {
            attribute waypoints : Pose[0..*];
            attribute totalDistance : Distance;
            attribute estimatedTime : Duration;
            attribute safeCorridorWidth : Distance default 1.0;
        }

        item def MotionCommand {
            attribute targetSpeed : Speed;
            attribute targetSteering : Angle;
            attribute targetAcceleration : Acceleration;
            attribute emergencyBrake : Boolean default false;
        }

        item def MotorCommand {
            attribute wheelIndex : Integer;
            attribute torque : Real;
            attribute direction : Integer;
        }

        item def ObstacleAlert {
            attribute detected : Boolean;
            attribute distance : Distance;
            attribute bearing : Angle;
            attribute classification : String;
            attribute severity : Integer default 0;
        }

        item def BatteryStatus {
            attribute chargeLevel : BatteryLevel;
            attribute voltage : Voltage;
            attribute estimatedRemaining : Duration;
            attribute charging : Boolean default false;
        }

        item def TelemetryPacket {
            attribute pose : Pose;
            attribute speed : Speed;
            attribute battery : BatteryStatus;
            attribute missionId : String;
            attribute timestamp : Duration;
        }
    }

    package Ports {

        port def OrderPort {
            in item orders : Items::DeliveryOrder;
            out item acknowledgements : String;
        }

        port def TelemetryPort {
            out item telemetry : Items::TelemetryPacket;
        }

        port def LidarDataPort {
            out item scans : Items::LidarScan;
        }

        port def CameraDataPort {
            out item images : Items::CameraImage;
        }

        port def UltrasonicDataPort {
            out item echoes : Items::UltrasonicEcho;
        }

        port def GPSDataPort {
            out item fixes : Items::GPSFix;
        }

        port def IMUDataPort {
            out item measurements : Items::IMUMeasurement;
        }

        port def MapPort {
            out item maps : Items::EnvironmentMap;
        }

        port def PosePort {
            out item poses : Items::Pose;
        }

        port def RoutePort {
            out item routes : Items::Route;
        }

        port def MotionCommandPort {
            out item commands : Items::MotionCommand;
        }

        port def MotorCommandPort {
            out item motorCommands : Items::MotorCommand;
        }

        port def ObstacleAlertPort {
            out item alerts : Items::ObstacleAlert;
        }

        port def BatteryPort {
            out item status : Items::BatteryStatus;
        }

        port def CargoAccessPort {
            in item codes : Items::SecurityCode;
            out item lockState : String;
        }

        port def PackagePort {
            in item packages : Items::Package;
        }
    }

    package Components {

        part def CommunicationModule {
            port orderPort : Ports::OrderPort;
            port telemetryPort : Ports::TelemetryPort;
            attribute connected : Boolean default false;
            attribute signalStrength : Real default 0.0;

            action def receiveOrder {
                in item incomingOrder : Items::DeliveryOrder;
                out item acceptedOrder : Items::DeliveryOrder;
            }

            perform receiveOrder;
        }

        part def LidarSensor {
            port dataPort : Ports::LidarDataPort;
            attribute maxRange : Distance default 100.0;
            attribute scanRate : Frequency default 10.0;
            attribute powerConsumption : Power default 8.0;

            action def scan {
                out item scan : Items::LidarScan;
            }

            perform scan;
        }

        part def CameraUnit {
            port dataPort : Ports::CameraDataPort;
            attribute fieldOfViewDeg : Real default 120.0;
            attribute frameRate : Frequency default 30.0;

            action def capture {
                out item image : Items::CameraImage;
            }

            perform capture;
        }

        part def CameraArray {
            part frontCamera : CameraUnit;
            part rearCamera : CameraUnit;
            part leftCamera : CameraUnit;
            part rightCamera : CameraUnit;
            attribute totalUnits : Integer default 4;
        }

        part def UltrasonicSensor {
            port dataPort : Ports::UltrasonicDataPort;
            attribute maxRange : Distance default 2.0;
            attribute beamAngle : Angle default 0.35;

            action def ping {
                out item echo : Items::UltrasonicEcho;
            }

            perform ping;
        }

        part def UltrasonicArray {
            part frontSensor : UltrasonicSensor;
            part rearSensor : UltrasonicSensor;
            part leftFrontSensor : UltrasonicSensor;
            part rightFrontSensor : UltrasonicSensor;
            part leftRearSensor : UltrasonicSensor;
            part rightRearSensor : UltrasonicSensor;
        }

        part def PerceptionSystem {
            part lidar : LidarSensor;
            part cameras : CameraArray;
            part ultrasonics : UltrasonicArray;
            port mapPort : Ports::MapPort;
            port obstaclePort : Ports::ObstacleAlertPort;

            action def fuseSensors {
                in item scans : Items::LidarScan;
                in item images : Items::CameraImage;
                in item echoes : Items::UltrasonicEcho;
                out item map : Items::EnvironmentMap;
                out item alert : Items::ObstacleAlert;
            }

            perform fuseSensors;
        }

        part def GPSReceiver {
            port dataPort : Ports::GPSDataPort;
            attribute updateRate : Frequency default 10.0;
            attribute accuracy : Distance default 0.5;

            action def computeFix {
                out item fix : Items::GPSFix;
            }

            perform computeFix;
        }

        part def IMU {
            port dataPort : Ports::IMUDataPort;
            attribute updateRate : Frequency default 100.0;
            attribute driftPerHour : Angle default 1.0;

            action def measure {
                out item measurement : Items::IMUMeasurement;
            }

            perform measure;
        }

        part def LocalizationSystem {
            part gps : GPSReceiver;
            part imu : IMU;
            port posePort : Ports::PosePort;

            action def fuseLocalization {
                in item fix : Items::GPSFix;
                in item measurement : Items::IMUMeasurement;
                out item pose : Items::Pose;
            }

            perform fuseLocalization;
        }

        part def PathPlanner {
            port mapPort : Ports::MapPort;
            port posePort : Ports::PosePort;
            port routePort : Ports::RoutePort;
            attribute currentDestination : String;
            attribute replanningEnabled : Boolean default true;

            action def planRoute {
                in item map : Items::EnvironmentMap;
                in item pose : Items::Pose;
                in item destination : String;
                out item route : Items::Route;
            }

            perform planRoute;
        }

        part def MotionController {
            port routePort : Ports::RoutePort;
            port posePort : Ports::PosePort;
            port obstaclePort : Ports::ObstacleAlertPort;
            port commandPort : Ports::MotionCommandPort;
            attribute maxSpeed : Speed default 2.0;
            attribute maxAcceleration : Acceleration default 1.0;
            attribute maxSteering : Angle default 0.5;

            action def computeCommand {
                in item route : Items::Route;
                in item pose : Items::Pose;
                in item alert : Items::ObstacleAlert;
                out item command : Items::MotionCommand;
            }

            action def emergencyStop {
                out item command : Items::MotionCommand;
            }

            perform computeCommand;
            perform emergencyStop;
        }

        part def Wheel {
            port commandPort : Ports::MotorCommandPort;
            attribute wheelIndex : Integer;
            attribute radius : Distance default 0.15;
            attribute maxTorque : Real default 5.0;
            attribute powered : Boolean default true;

            action def applyTorque {
                in item command : Items::MotorCommand;
            }

            perform applyTorque;
        }

        part def Drivetrain {
            part wheel1 : Wheel { :>> wheelIndex = 1; }
            part wheel2 : Wheel { :>> wheelIndex = 2; }
            part wheel3 : Wheel { :>> wheelIndex = 3; }
            part wheel4 : Wheel { :>> wheelIndex = 4; }
            part wheel5 : Wheel { :>> wheelIndex = 5; }
            part wheel6 : Wheel { :>> wheelIndex = 6; }
            port commandPort : Ports::MotionCommandPort;
            attribute wheelCount : Integer default 6;
            attribute driveConfiguration : String default "six-wheel skid-steer";

            action def distributeCommand {
                in item command : Items::MotionCommand;
                out item motorCommands : Items::MotorCommand[6];
            }

            perform distributeCommand;
        }

        part def CargoCompartment {
            port accessPort : Ports::CargoAccessPort;
            port packagePort : Ports::PackagePort;
            attribute locked : Boolean default true;
            attribute temperatureControlled : Boolean default true;
            attribute internalTemperature : Temperature default 4.0;
            attribute targetTemperature : Temperature default 4.0;
            attribute capacityMass : Mass default 20.0;
            attribute currentLoad : Mass default 0.0;
            attribute packagePresent : Boolean default false;

            action def secureCargo {
                in item pkg : Items::Package;
                attribute :>> locked = true;
                attribute :>> packagePresent = true;
            }

            action def releaseCargo {
                in item code : Items::SecurityCode;
                attribute :>> locked = false;
            }

            action def regulateTemperature {
                attribute :>> internalTemperature = targetTemperature;
            }

            perform secureCargo;
            perform releaseCargo;
            perform regulateTemperature;
        }

        part def BatterySystem {
            port batteryPort : Ports::BatteryPort;
            attribute capacity : Current default 30.0;
            attribute chargeLevel : BatteryLevel default 100.0;
            attribute voltage : Voltage default 24.0;
            attribute lowThreshold : BatteryLevel default 20.0;
            attribute criticalThreshold : BatteryLevel default 5.0;
            attribute charging : Boolean default false;

            action def monitorCharge {
                out item status : Items::BatteryStatus;
            }

            action def charge {
                attribute :>> charging = true;
                attribute :>> chargeLevel = 100.0;
            }

            perform monitorCharge;
            perform charge;
        }

        part def SafetyMonitor {
            port obstaclePort : Ports::ObstacleAlertPort;
            port batteryPort : Ports::BatteryPort;
            attribute emergencyStopActive : Boolean default false;
            attribute returnToBaseRequested : Boolean default false;

            action def evaluateSafety {
                in item alert : Items::ObstacleAlert;
                in item battery : Items::BatteryStatus;
                attribute :>> emergencyStopActive = alert.detected and alert.severity >= 3;
                attribute :>> returnToBaseRequested = battery.chargeLevel < 20.0;
            }

            perform evaluateSafety;
        }
    }

    package Behaviors {

        state def RobotLifecycle {
            attribute missionId : String;
            attribute currentOrder : Items::DeliveryOrder;
            attribute currentPose : Items::Pose;
            attribute currentRoute : Items::Route;
            attribute currentBattery : Items::BatteryStatus;
            attribute obstacleDetected : Boolean default false;
            attribute arrivedAtPickup : Boolean default false;
            attribute cargoSecured : Boolean default false;
            attribute arrivedAtDelivery : Boolean default false;
            attribute codeVerified : Boolean default false;
            attribute lowBattery : Boolean default false;
            attribute orderReceived : Boolean default false;

            state idle {
                entry :>> orderReceived = false;
            }

            state navigatingToPickup;
            state securingCargo;
            state navigatingToDelivery;
            state awaitingRecipientCode;
            state cargoReleased;
            state obstacleAvoidance;
            state returningToBase;
            state charging;

            transition t1
                from idle to navigatingToPickup
                when orderReceived
                accept Items::DeliveryOrder;

            transition t2
                from navigatingToPickup to securingCargo
                when arrivedAtPickup;

            transition t3
                from securingCargo to navigatingToDelivery
                when cargoSecured;

            transition t4
                from navigatingToDelivery to awaitingRecipientCode
                when arrivedAtDelivery;

            transition t5
                from awaitingRecipientCode to cargoReleased
                when codeVerified
                accept Items::SecurityCode;

            transition t6
                from cargoReleased to idle;

            transition t7
                from navigatingToPickup to obstacleAvoidance
                when obstacleDetected;

            transition t8
                from navigatingToDelivery to obstacleAvoidance
                when obstacleDetected;

            transition t9
                from obstacleAvoidance to navigatingToPickup
                when not obstacleDetected and not arrivedAtPickup and not lowBattery;

            transition t10
                from obstacleAvoidance to navigatingToDelivery
                when not obstacleDetected and not arrivedAtDelivery and not lowBattery;

            transition t11
                from navigatingToPickup to returningToBase
                when lowBattery;

            transition t12
                from navigatingToDelivery to returningToBase
                when lowBattery;

            transition t13
                from obstacleAvoidance to returningToBase
                when lowBattery;

            transition t14
                from returningToBase to charging
                when arrivedAtPickup and currentOrder.orderId == "BASE";

            transition t15
                from charging to idle
                when currentBattery.chargeLevel >= 99.0;
        }
    }

    package System {

        part def StarshipRobot {
            part communication : Components::CommunicationModule;
            part perception : Components::PerceptionSystem;
            part localization : Components::LocalizationSystem;
            part planner : Components::PathPlanner;
            part motion : Components::MotionController;
            part drivetrain : Components::Drivetrain;
            part cargo : Components::CargoCompartment;
            part battery : Components::BatterySystem;
            part safety : Components::SafetyMonitor;

            port orderPort : Ports::OrderPort;
            port telemetryPort : Ports::TelemetryPort;
            port cargoAccessPort : Ports::CargoAccessPort;

            state robotLifecycle : Behaviors::RobotLifecycle;

            connect communication.orderPort to orderPort;
            connect communication.telemetryPort to telemetryPort;
            connect cargo.accessPort to cargoAccessPort;

            connect perception.lidar.dataPort to perception.mapPort;
            connect perception.cameras.frontCamera.dataPort to perception.mapPort;
            connect perception.cameras.rearCamera.dataPort to perception.mapPort;
            connect perception.cameras.leftCamera.dataPort to perception.mapPort;
            connect perception.cameras.rightCamera.dataPort to perception.mapPort;
            connect perception.ultrasonics.frontSensor.dataPort to perception.mapPort;
            connect perception.ultrasonics.rearSensor.dataPort to perception.mapPort;
            connect perception.ultrasonics.leftFrontSensor.dataPort to perception.mapPort;
            connect perception.ultrasonics.rightFrontSensor.dataPort to perception.mapPort;
            connect perception.ultrasonics.leftRearSensor.dataPort to perception.mapPort;
            connect perception.ultrasonics.rightRearSensor.dataPort to perception.mapPort;

            connect perception.mapPort to planner.mapPort;
            connect perception.obstaclePort to motion.obstaclePort;
            connect perception.obstaclePort to safety.obstaclePort;

            connect localization.gps.dataPort to localization.posePort;
            connect localization.imu.dataPort to localization.posePort;
            connect localization.posePort to planner.posePort;
            connect localization.posePort to motion.posePort;

            connect planner.routePort to motion.routePort;
            connect motion.commandPort to drivetrain.commandPort;

            connect drivetrain.commandPort to drivetrain.wheel1.commandPort;
            connect drivetrain.commandPort to drivetrain.wheel2.commandPort;
            connect drivetrain.commandPort to drivetrain.wheel3.commandPort;
            connect drivetrain.commandPort to drivetrain.wheel4.commandPort;
            connect drivetrain.commandPort to drivetrain.wheel5.commandPort;
            connect drivetrain.commandPort to drivetrain.wheel6.commandPort;

            connect battery.batteryPort to safety.batteryPort;

            attribute vehicleMass : Mass default 40.0;
            attribute maxPayload : Mass default 20.0;
            attribute topSpeed : Speed default 2.0;
            attribute operatingTemperatureRangeMin : Temperature default -10.0;
            attribute operatingTemperatureRangeMax : Temperature default 45.0;
            attribute wheelCount : Integer default 6;
        }
    }

    package Requirements {

        requirement def AutonomousDeliveryRequirement {
            doc "The robot shall execute a complete last-mile delivery mission autonomously.";
            subject robot : System::StarshipRobot;
            attribute missionComplete : Boolean;
            require missionComplete == true;
        }

        requirement def SixWheelConfigurationRequirement {
            doc "The robot shall be a six-wheeled self-driving ground vehicle.";
            subject robot : System::StarshipRobot;
            require robot.wheelCount == 6;
        }

        requirement def SecureCargoRequirement {
            doc "The cargo compartment shall remain locked until the recipient provides the correct security code.";
            subject cargo : Components::CargoCompartment;
            attribute codeCorrect : Boolean;
            require cargo.locked == true when not codeCorrect;
            require cargo.locked == false when codeCorrect;
        }

        requirement def TemperatureControlRequirement {
            doc "The cargo compartment shall maintain temperature-controlled conditions for sensitive packages.";
            subject cargo : Components::CargoCompartment;
            require cargo.temperatureControlled == true;
            require cargo.internalTemperature == cargo.targetTemperature;
        }

        requirement def Perception360Requirement {
            doc "The robot shall build a real-time 360-degree environment model using Lidar, cameras, and ultrasonic sensors.";
            subject perception : Components::PerceptionSystem;
            require perception.lidar.maxRange >= 50.0;
            require perception.cameras.totalUnits >= 4;
            require perception.mapPort.maps.fieldOfViewDeg == 360.0;
        }

        requirement def LocalizationRequirement {
            doc "The robot shall determine its precise location by fusing GPS and IMU data.";
            subject localization : Components::LocalizationSystem;
            require localization.gps.accuracy <= 1.0;
            require localization.imu.updateRate >= 50.0;
        }

        requirement def PathPlanningRequirement {
            doc "The path planner shall calculate the safest and most efficient route to the destination.";
            subject planner : Components::PathPlanner;
            require planner.replanningEnabled == true;
        }

        requirement def MotionControlRequirement {
            doc "The motion controller shall translate routes into motor commands managing acceleration, speed, and steering.";
            subject motion : Components::MotionController;
            require motion.maxSpeed <= 2.0;
            require motion.maxAcceleration <= 1.5;
        }

        requirement def ObstacleAvoidanceRequirement {
            doc "The robot shall execute an evasive maneuver or complete stop when an unexpected obstacle is detected.";
            subject safety : Components::SafetyMonitor;
            subject motion : Components::MotionController;
            require safety.emergencyStopActive == true when perception.obstaclePort.alerts.severity >= 3;
        }

        requirement def LowBatteryReturnRequirement {
            doc "The robot shall autonomously return to base for charging when battery charge falls below threshold.";
            subject battery : Components::BatterySystem;
            subject safety : Components::SafetyMonitor;
            require safety.returnToBaseRequested == true when battery.chargeLevel < battery.lowThreshold;
        }

        requirement def LifecycleRequirement {
            doc "The robot operational lifecycle shall include idle, navigation, cargo securing, delivery, obstacle avoidance, and charging states.";
            subject lifecycle : Behaviors::RobotLifecycle;
            require lifecycle.idle.isExists();
            require lifecycle.navigatingToPickup.isExists();
            require lifecycle.securingCargo.isExists();
            require lifecycle.navigatingToDelivery.isExists();
            require lifecycle.awaitingRecipientCode.isExists();
            require lifecycle.obstacleAvoidance.isExists();
            require lifecycle.returningToBase.isExists();
            require lifecycle.charging.isExists();
        }

        requirement def CommunicationRequirement {
            doc "The robot shall receive delivery orders through its wireless communication module.";
            subject comm : Components::CommunicationModule;
            require comm.orderPort.orders.isExists();
        }

        requirement deliveryRequirement : AutonomousDeliveryRequirement;
        requirement sixWheelRequirement : SixWheelConfigurationRequirement;
        requirement secureCargoRequirement : SecureCargoRequirement;
        requirement temperatureControlRequirement : TemperatureControlRequirement;
        requirement perceptionRequirement : Perception360Requirement;
        requirement localizationRequirement : LocalizationRequirement;
        requirement pathPlanningRequirement : PathPlanningRequirement;
        requirement motionControlRequirement : MotionControlRequirement;
        requirement obstacleAvoidanceRequirement : ObstacleAvoidanceRequirement;
        requirement lowBatteryReturnRequirement : LowBatteryReturnRequirement;
        requirement lifecycleRequirement : LifecycleRequirement;
        requirement communicationRequirement : CommunicationRequirement;
    }

    package Verification {

        verification def VerifySixWheelConfiguration {
            subject robot : System::StarshipRobot;
            objective {
                doc "Confirm the robot has six powered wheels.";
            }
            require robot.wheelCount == 6;
        }

        verification def VerifyCargoLock {
            subject cargo : Components::CargoCompartment;
            objective {
                doc "Confirm cargo remains locked without correct code and unlocks with correct code.";
            }
            require cargo.locked == true when not cargo.accessPort.codes.valid;
            require cargo.locked == false when cargo.accessPort.codes.valid;
        }

        verification def VerifyObstacleResponse {
            subject safety : Components::SafetyMonitor;
            objective {
                doc "Confirm emergency stop activates for high-severity obstacles.";
            }
            require safety.emergencyStopActive == true when safety.obstaclePort.alerts.severity >= 3;
        }

        verification def VerifyLowBatteryReturn {
            subject battery : Components::BatterySystem;
            subject safety : Components::SafetyMonitor;
            objective {
                doc "Confirm return-to-base is requested below threshold.";
            }
            require safety.returnToBaseRequested == true when battery.chargeLevel < battery.lowThreshold;
        }
    }
}
