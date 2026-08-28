package AmazonScoutDeliveryRobot {

    import ScalarValues::*;

    package ValueTypes {
        value type Distance :> Real { :>> unit = "m"; }
        value type Speed :> Real { :>> unit = "m/s"; }
        value type Acceleration :> Real { :>> unit = "m/s^2"; }
        value type Angle :> Real { :>> unit = "rad"; }
        value type AngularVelocity :> Real { :>> unit = "rad/s"; }
        value type Temperature :> Real { :>> unit = "K"; }
        value type Mass :> Real { :>> unit = "kg"; }
        value type Duration :> Real { :>> unit = "s"; }
        value type Energy :> Real { :>> unit = "J"; }
        value type Power :> Real { :>> unit = "W"; }
        value type Voltage :> Real { :>> unit = "V"; }
        value type Current :> Real { :>> unit = "A"; }
        value type Charge :> Real { :>> unit = "C"; }
        value type Force :> Real { :>> unit = "N"; }
        value type Percent :> Real { :>> unit = "%"; }
        value type Frequency :> Real { :>> unit = "Hz"; }
        value type Torque :> Real { :>> unit = "N*m"; }
        value type DataRate :> Real { :>> unit = "bit/s"; }
    }

    package Items {
        import ValueTypes::*;

        item def LidarScan {
            attribute timestamp : Duration;
            attribute sensorId : String;
            attribute maxRange : Distance;
            attribute fieldOfView : Angle;
            attribute pointCloudData : String;
        }

        item def CameraImage {
            attribute timestamp : Duration;
            attribute sensorId : String;
            attribute width : Integer;
            attribute height : Integer;
            attribute encoding : String;
            attribute imageData : String;
        }

        item def GPSFix {
            attribute timestamp : Duration;
            attribute latitude : Angle;
            attribute longitude : Angle;
            attribute altitude : Distance;
            attribute horizontalAccuracy : Distance;
            attribute verticalAccuracy : Distance;
            attribute satellitesVisible : Integer;
        }

        item def IMUReading {
            attribute timestamp : Duration;
            attribute accelX : Acceleration;
            attribute accelY : Acceleration;
            attribute accelZ : Acceleration;
            attribute gyroX : AngularVelocity;
            attribute gyroY : AngularVelocity;
            attribute gyroZ : AngularVelocity;
            attribute roll : Angle;
            attribute pitch : Angle;
            attribute yaw : Angle;
        }

        item def Obstacle {
            attribute obstacleId : String;
            attribute positionX : Distance;
            attribute positionY : Distance;
            attribute velocityX : Speed;
            attribute velocityY : Speed;
            attribute radius : Distance;
            attribute classification : String;
            attribute confidence : Percent;
        }

        item def ObstacleList {
            attribute timestamp : Duration;
            attribute obstacles : Obstacle[0..*];
        }

        item def LocalMap {
            attribute timestamp : Duration;
            attribute resolution : Distance;
            attribute mapWidth : Distance;
            attribute mapHeight : Distance;
            attribute mapData : String;
        }

        item def PoseEstimate {
            attribute timestamp : Duration;
            attribute positionX : Distance;
            attribute positionY : Distance;
            attribute heading : Angle;
            attribute velocity : Speed;
            attribute confidence : Percent;
        }

        item def DeliveryMission {
            attribute missionId : String;
            attribute destinationLatitude : Angle;
            attribute destinationLongitude : Angle;
            attribute destinationAddress : String;
            attribute customerId : String;
            attribute priority : Integer;
            attribute assignedAt : Duration;
            attribute maxDeliveryTime : Duration;
        }

        item def RoutePlan {
            attribute missionId : String;
            attribute totalDistance : Distance;
            attribute estimatedDuration : Duration;
            attribute waypoints : String;
        }

        item def DriveCommand {
            attribute timestamp : Duration;
            attribute targetSpeed : Speed;
            attribute targetAcceleration : Acceleration;
        }

        item def SteeringCommand {
            attribute timestamp : Duration;
            attribute targetSteeringAngle : Angle;
        }

        item def BrakeCommand {
            attribute timestamp : Duration;
            attribute engage : Boolean;
            attribute brakeForce : Force;
        }

        item def AuthenticationToken {
            attribute customerId : String;
            attribute missionId : String;
            attribute oneTimeCode : String;
            attribute cryptographicSignature : String;
            attribute issuedAt : Duration;
            attribute expiresAt : Duration;
        }

        item def Package {
            attribute packageId : String;
            attribute mass : Mass;
            attribute requiresTemperatureControl : Boolean;
            attribute targetTemperature : Temperature;
            attribute fragile : Boolean;
        }

        item def DeliveryConfirmation {
            attribute missionId : String;
            attribute customerId : String;
            attribute timestamp : Duration;
            attribute customerSignature : String;
            attribute photoEvidence : String;
        }

        item def MissionStatus {
            attribute missionId : String;
            attribute status : String;
            attribute timestamp : Duration;
            attribute batteryLevel : Percent;
            attribute positionX : Distance;
            attribute positionY : Distance;
        }

        item def PowerStatus {
            attribute voltage : Voltage;
            attribute current : Current;
            attribute stateOfCharge : Percent;
            attribute temperature : Temperature;
        }
    }

    package Ports {
        import Items::*;

        port def LidarDataPort {
            out scan : LidarScan;
        }

        port def CameraDataPort {
            out image : CameraImage;
        }

        port def GPSDataPort {
            out fix : GPSFix;
        }

        port def IMUDataPort {
            out reading : IMUReading;
        }

        port def PerceptionOutputPort {
            out obstacles : ObstacleList;
            out localMap : LocalMap;
            out pose : PoseEstimate;
        }

        port def ControllerSensorInputPort {
            in lidarScan : LidarScan;
            in cameraImage : CameraImage;
            in gpsFix : GPSFix;
            in imuReading : IMUReading;
            in obstacles : ObstacleList;
            in localMap : LocalMap;
            in pose : PoseEstimate;
        }

        port def MobilityCommandPort {
            in driveCmd : DriveCommand;
            in steeringCmd : SteeringCommand;
            in brakeCmd : BrakeCommand;
        }

        port def PowerPort {
            out voltage : Voltage;
            out current : Current;
            out status : PowerStatus;
            in demand : Power;
        }

        port def MissionCommPort {
            in mission : DeliveryMission;
            out status : MissionStatus;
            out confirmation : DeliveryConfirmation;
        }

        port def CargoAccessPort {
            in authToken : AuthenticationToken;
            out packageItem : Package;
            out confirmation : DeliveryConfirmation;
        }

        port def TelemetryPort {
            out pose : PoseEstimate;
            out powerStatus : PowerStatus;
            out missionStatus : MissionStatus;
        }
    }

    package Behaviors {
        import ValueTypes::*;
        import Items::*;

        state def AutonomyControllerStateMachine {
            entry; then Idle;

            state Idle {
                entry action { /* Await mission assignment from communication module */ }
            }
            state Planning {
                entry action { /* Compute optimal route from current pose to destination */ }
            }
            state Navigating {
                entry action { /* Follow planned route, continuously update local map and pose */ }
            }
            state AvoidingObstacle {
                entry action { /* Compute evasive maneuver around detected obstacle */ }
            }
            state ArrivedAtDestination {
                entry action { /* Notify customer via communication module, request authentication */ }
            }
            state AuthenticatingCustomer {
                entry action { /* Validate customer authentication token */ }
            }
            state AwaitingRetrieval {
                entry action { /* Cargo compartment unlocked, wait for package pickup */ }
            }
            state ConfirmingDelivery {
                entry action { /* Generate and transmit delivery confirmation */ }
            }
            state ReturningToDepot {
                entry action { /* Navigate back to depot for charging and next mission */ }
            }
            state EmergencyStop {
                entry action { /* Halt all motion immediately, alert remote operations center */ }
            }

            transition from Idle to Planning
                when missionReceived;
            transition from Planning to Navigating
                when routePlanComplete;
            transition from Navigating to AvoidingObstacle
                when obstacleDetected;
            transition from AvoidingObstacle to Navigating
                when obstacleCleared;
            transition from Navigating to ArrivedAtDestination
                when destinationReached;
            transition from ArrivedAtDestination to AuthenticatingCustomer
                when customerNotified;
            transition from AuthenticatingCustomer to AwaitingRetrieval
                when authenticationSuccessful;
            transition from AuthenticatingCustomer to ArrivedAtDestination
                when authenticationFailed;
            transition from AwaitingRetrieval to ConfirmingDelivery
                when packageRetrieved;
            transition from ConfirmingDelivery to Idle
                when moreMissionsAvailable;
            transition from ConfirmingDelivery to ReturningToDepot
                when noMoreMissions;
            transition from ReturningToDepot to Idle
                when depotReached;
            transition from Navigating to EmergencyStop
                when criticalFault;
            transition from AvoidingObstacle to EmergencyStop
                when criticalFault;
            transition from EmergencyStop to Idle
                when faultCleared;
        }

        state def CargoCompartmentStateMachine {
            entry; then Empty;

            state Empty;
            state Loading;
            state Locked;
            state TemperatureControlled;
            state Unlocked;
            state Unloading;

            transition from Empty to Loading
                when packageLoaded;
            transition from Loading to Locked
                when loadingComplete;
            transition from Locked to TemperatureControlled
                when tempControlRequired;
            transition from TemperatureControlled to Locked
                when tempControlNotRequired;
            transition from Locked to Unlocked
                when customerAuthenticated;
            transition from TemperatureControlled to Unlocked
                when customerAuthenticated;
            transition from Unlocked to Unloading
                when packageRetrieved;
            transition from Unloading to Empty
                when unloadingComplete;
        }

        state def BatteryStateMachine {
            entry; then Discharging;

            state Discharging;
            state Charging;
            state Critical;
            state Faulted;

            transition from Discharging to Charging
                when chargerConnected;
            transition from Charging to Discharging
                when chargerDisconnected;
            transition from Discharging to Critical
                when stateOfChargeBelow10;
            transition from Critical to Charging
                when chargerConnected;
            transition from Discharging to Faulted
                when batteryFault;
            transition from Critical to Faulted
                when batteryFault;
            transition from Faulted to Discharging
                when faultCleared;
        }

        state def ScoutMissionStateMachine {
            entry; then Standby;

            state Standby;
            state MissionReceived;
            state PackageLoaded;
            state InTransit;
            state AtDestination;
            state DeliveryComplete;
            state ReturningHome;

            transition from Standby to MissionReceived
                when missionAssigned;
            transition from MissionReceived to PackageLoaded
                when packageLoaded;
            transition from PackageLoaded to InTransit
                when routeStarted;
            transition from InTransit to AtDestination
                when arrived;
            transition from AtDestination to DeliveryComplete
                when packageRetrieved;
            transition from DeliveryComplete to Standby
                when moreMissions;
            transition from DeliveryComplete to ReturningHome
                when noMoreMissions;
            transition from ReturningHome to Standby
                when homeReached;
        }
    }

    package Subsystems {
        import Items::*;
        import Ports::*;
        import ValueTypes::*;
        import Behaviors::*;

        part def LidarSensor {
            attribute sensorId : String;
            attribute maxRange : Distance = 100 [m];
            attribute scanRate : Frequency = 10 [Hz];
            attribute fieldOfView : Angle = 6.2832 [rad];
            attribute angularResolution : Angle = 0.01745 [rad];
            attribute powerConsumption : Power = 8 [W];
            port dataOut : LidarDataPort;
            port powerIn : PowerPort;

            action def ScanEnvironment {
                out scanResult : LidarScan;
            }
        }

        part def Camera {
            attribute sensorId : String;
            attribute horizontalFieldOfView : Angle = 1.5708 [rad];
            attribute verticalFieldOfView : Angle = 1.0472 [rad];
            attribute resolutionWidth : Integer = 1920;
            attribute resolutionHeight : Integer = 1080;
            attribute frameRate : Frequency = 30 [Hz];
            attribute powerConsumption : Power = 5 [W];
            port dataOut : CameraDataPort;
            port powerIn : PowerPort;

            action def CaptureImage {
                out image : CameraImage;
            }
        }

        part def GPSReceiver {
            attribute updateRate : Frequency = 10 [Hz];
            attribute horizontalAccuracy : Distance = 2.0 [m];
            attribute verticalAccuracy : Distance = 5.0 [m];
            attribute powerConsumption : Power = 0.5 [W];
            port dataOut : GPSDataPort;
            port powerIn : PowerPort;

            action def AcquireFix {
                out fix : GPSFix;
            }
        }

        part def InertialMeasurementUnit {
            attribute updateRate : Frequency = 200 [Hz];
            attribute accelRange : Acceleration = 78.4 [m/s^2];
            attribute gyroRange : AngularVelocity = 7.854 [rad/s];
            attribute powerConsumption : Power = 0.2 [W];
            port dataOut : IMUDataPort;
            port powerIn : PowerPort;

            action def SampleIMU {
                out reading : IMUReading;
            }
        }

        part def PerceptionSystem {
            attribute processingRate : Frequency = 20 [Hz];
            attribute detectionRange : Distance = 50 [m];
            attribute powerConsumption : Power = 15 [W];

            part frontLidar : LidarSensor {
                :>> sensorId = "front_lidar";
            }
            part rearLidar : LidarSensor {
                :>> sensorId = "rear_lidar";
            }
            part frontCamera : Camera {
                :>> sensorId = "front_camera";
            }
            part leftCamera : Camera {
                :>> sensorId = "left_camera";
            }
            part rightCamera : Camera {
                :>> sensorId = "right_camera";
            }
            part gps : GPSReceiver;
            part imu : InertialMeasurementUnit;

            port perceptionOut : PerceptionOutputPort;
            port powerIn : PowerPort;

            action def FuseSensorData {
                in lidarScans : LidarScan[2];
                in cameraImages : CameraImage[3];
                in gpsFix : GPSFix;
                in imuReading : IMUReading;
                out obstacles : ObstacleList;
                out localMap : LocalMap;
                out pose : PoseEstimate;
            }

            action def DetectObstacles {
                in scans : LidarScan[0..*];
                in images : CameraImage[0..*];
                out obstacles : ObstacleList;
            }

            action def EstimatePose {
                in gpsFix : GPSFix;
                in imuReading : IMUReading;
                out pose : PoseEstimate;
            }

            action def BuildLocalMap {
                in scans : LidarScan[0..*];
                in pose : PoseEstimate;
                out localMap : LocalMap;
            }
        }

        part def AutonomyController {
            attribute clockSpeed : Frequency = 2000 [MHz];
            attribute memoryGB : Real = 16;
            attribute powerConsumption : Power = 30 [W];

            port sensorIn : ControllerSensorInputPort;
            port mobilityCmdOut : MobilityCommandPort;
            port missionComm : MissionCommPort;
            port cargoAccess : CargoAccessPort;
            port telemetryOut : TelemetryPort;
            port powerIn : PowerPort;

            exhibit AutonomyControllerStateMachine;

            action def PlanRoute {
                in mission : DeliveryMission;
                in localMap : LocalMap;
                in pose : PoseEstimate;
                out route : RoutePlan;
            }

            action def NavigateRoute {
                in route : RoutePlan;
                in pose : PoseEstimate;
                in obstacles : ObstacleList;
                out driveCmd : DriveCommand;
                out steeringCmd : SteeringCommand;
                out brakeCmd : BrakeCommand;
            }

            action def AvoidObstacle {
                in obstacles : ObstacleList;
                in pose : PoseEstimate;
                out driveCmd : DriveCommand;
                out steeringCmd : SteeringCommand;
                out brakeCmd : BrakeCommand;
            }

            action def AuthenticateCustomer {
                in authToken : AuthenticationToken;
                out authenticated : Boolean;
            }

            action def ConfirmDelivery {
                in missionId : String;
                in customerId : String;
                out confirmation : DeliveryConfirmation;
            }
        }

        part def DriveMotor {
            attribute motorId : String;
            attribute maxPower : Power = 150 [W];
            attribute maxTorque : Torque = 5 [N*m];
            attribute maxSpeed : Speed = 1.5 [m/s];
            attribute powerConsumption : Power = 100 [W];
            port cmdIn : MobilityCommandPort;
            port powerIn : PowerPort;

            action def ApplyDriveCommand {
                in cmd : DriveCommand;
                out appliedTorque : Torque;
            }
        }

        part def SteeringActuator {
            attribute maxSteeringAngle : Angle = 0.5236 [rad];
            attribute responseTime : Duration = 0.1 [s];
            attribute powerConsumption : Power = 10 [W];
            port cmdIn : MobilityCommandPort;
            port powerIn : PowerPort;

            action def ApplySteeringCommand {
                in cmd : SteeringCommand;
                out appliedAngle : Angle;
            }
        }

        part def BrakeSystem {
            attribute maxBrakeForce : Force = 200 [N];
            attribute responseTime : Duration = 0.05 [s];
            attribute powerConsumption : Power = 5 [W];
            port cmdIn : MobilityCommandPort;
            port powerIn : PowerPort;

            action def ApplyBrakeCommand {
                in cmd : BrakeCommand;
                out appliedForce : Force;
            }
        }

        part def MobilitySystem {
            attribute wheelCount : Integer = 6;
            attribute maxSpeed : Speed = 1.5 [m/s];
            attribute maxAcceleration : Acceleration = 0.5 [m/s^2];
            attribute minTurningRadius : Distance = 0.5 [m];

            part driveMotors : DriveMotor[6];
            part steering : SteeringActuator;
            part brakes : BrakeSystem;

            port cmdIn : MobilityCommandPort;
            port powerIn : PowerPort;
        }

        part def BatteryPack {
            attribute capacity : Charge = 20000 [C];
            attribute nominalVoltage : Voltage = 24 [V];
            attribute maxDischargeCurrent : Current = 30 [A];
            attribute maxChargeCurrent : Current = 10 [A];
            attribute energyCapacity : Energy = 480000 [J];
            attribute stateOfCharge : Percent = 100 [%];
            attribute operatingTemperatureMin : Temperature = 263.15 [K];
            attribute operatingTemperatureMax : Temperature = 323.15 [K];

            port powerOut : PowerPort;

            exhibit BatteryStateMachine;

            action def Discharge {
                out voltage : Voltage;
                out current : Current;
            }

            action def Charge {
                in chargeCurrent : Current;
            }
        }

        part def CargoLock {
            attribute locked : Boolean = true;
            attribute actuationTime : Duration = 0.5 [s];
            attribute powerConsumption : Power = 2 [W];
            port powerIn : PowerPort;

            action def Lock {
                out locked : Boolean = true;
            }
            action def Unlock {
                out locked : Boolean = false;
            }
        }

        part def TemperatureControlUnit {
            attribute minTemperature : Temperature = 263.15 [K];
            attribute maxTemperature : Temperature = 323.15 [K];
            attribute coolingPower : Power = 20 [W];
            attribute heatingPower : Power = 15 [W];
            attribute currentSetpoint : Temperature = 293.15 [K];
            attribute powerConsumption : Power = 20 [W];
            port powerIn : PowerPort;

            action def RegulateTemperature {
                in setpoint : Temperature;
                in currentTemp : Temperature;
                out heatingEnabled : Boolean;
                out coolingEnabled : Boolean;
            }
        }

        part def CargoCompartment {
            attribute compartmentId : String;
            attribute maxPayloadMass : Mass = 10 [kg];
            attribute volumeLiters : Real = 50;
            attribute insulated : Boolean = true;
            attribute currentTemperature : Temperature = 293.15 [K];

            part lock : CargoLock;
            part tempControl : TemperatureControlUnit;

            port cargoAccess : CargoAccessPort;
            port powerIn : PowerPort;

            exhibit CargoCompartmentStateMachine;
        }

        part def CommunicationModule {
            attribute protocol : String = "LTE/5G";
            attribute maxRange : Distance = 10000 [m];
            attribute dataRate : DataRate = 1000000 [bit/s];
            attribute powerConsumption : Power = 3 [W];
            port missionComm : MissionCommPort;
            port powerIn : PowerPort;

            action def ReceiveMission {
                out mission : DeliveryMission;
            }
            action def SendStatus {
                in status : MissionStatus;
            }
            action def SendConfirmation {
                in confirmation : DeliveryConfirmation;
            }
        }
    }

    package ScoutAssembly {
        import Subsystems::*;
        import Ports::*;
        import Items::*;
        import ValueTypes::*;
        import Behaviors::*;

        part def ScoutRobot {
            attribute robotId : String;
            attribute firmwareVersion : String = "1.0.0";
            attribute maxPayload : Mass = 10 [kg];
            attribute operatingSpeed : Speed = 1.5 [m/s];
            attribute wheelCount : Integer = 6;
            attribute totalMass : Mass = 35 [kg];

            part perception : PerceptionSystem;
            part controller : AutonomyController;
            part mobility : MobilitySystem;
            part battery : BatteryPack;
            part cargo : CargoCompartment;
            part comm : CommunicationModule;

            port externalMission : MissionCommPort;
            port telemetry : TelemetryPort;

            exhibit ScoutMissionStateMachine;

            connection connect perception.frontLidar.dataOut to controller.sensorIn;
            connection connect perception.rearLidar.dataOut to controller.sensorIn;
            connection connect perception.frontCamera.dataOut to controller.sensorIn;
            connection connect perception.leftCamera.dataOut to controller.sensorIn;
            connection connect perception.rightCamera.dataOut to controller.sensorIn;
            connection connect perception.gps.dataOut to controller.sensorIn;
            connection connect perception.imu.dataOut to controller.sensorIn;
            connection connect perception.perceptionOut to controller.sensorIn;

            connection connect controller.mobilityCmdOut to mobility.cmdIn;

            connection connect controller.cargoAccess to cargo.cargoAccess;

            connection connect comm.missionComm to controller.missionComm;
            connection connect externalMission to comm.missionComm;

            connection connect battery.powerOut to perception.powerIn;
            connection connect battery.powerOut to controller.powerIn;
            connection connect battery.powerOut to mobility.powerIn;
            connection connect battery.powerOut to cargo.powerIn;
            connection connect battery.powerOut to comm.powerIn;

            connection connect controller.telemetryOut to telemetry;
        }

        part def DeliveryDepot {
            attribute depotId : String;
            attribute locationLatitude : Angle;
            attribute locationLongitude : Angle;
            attribute chargingBays : Integer = 10;

            part fleet : ScoutRobot[0..*];
            port missionDispatch : MissionCommPort;
            port powerSupply : PowerPort;
        }

        part def Customer {
            attribute customerId : String;
            attribute deliveryAddress : String;
            attribute mobileNumber : String;
            attribute authenticationCredential : String;

            port customerApp : MissionCommPort;
            port cargoAccess : CargoAccessPort;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import ScoutAssembly::*;

        requirement def ObstacleDetectionRequirement {
            doc /* The Scout shall detect obstacles in 360 degrees using front and rear Lidar sensors. */
            attribute minDetectionRange : Distance = 50 [m];
            attribute responseTime : Duration = 0.5 [s];
            subject scout : ScoutRobot;
            require scout.perception.detectionRange >= minDetectionRange;
        }

        requirement def SafeNavigationRequirement {
            doc /* The Scout shall navigate sidewalks safely, stopping for pedestrians, pets, and discarded items. */
            attribute maxOperatingSpeed : Speed = 1.5 [m/s];
            attribute emergencyStopDistance : Distance = 1.0 [m];
            attribute obstacleResponseTime : Duration = 0.3 [s];
            subject scout : ScoutRobot;
            require scout.mobility.maxSpeed <= maxOperatingSpeed;
        }

        requirement def BatteryEnduranceRequirement {
            doc /* The battery shall provide sufficient energy for a typical delivery route on a single charge. */
            attribute minRouteDistance : Distance = 10000 [m];
            attribute minOperatingTime : Duration = 14400 [s];
            attribute minStateOfCharge : Percent = 15 [%];
            subject scout : ScoutRobot;
            require scout.battery.energyCapacity >= 432000 [J];
        }

        requirement def CargoSecurityRequirement {
            doc /* The cargo compartment shall remain locked during transit and only open upon authenticated customer arrival. */
            subject scout : ScoutRobot;
            require scout.cargo.lock.locked == true;
        }

        requirement def TemperatureControlRequirement {
            doc /* The cargo compartment shall maintain temperature-sensitive packages within the specified range. */
            attribute minTemp : Temperature = 263.15 [K];
            attribute maxTemp : Temperature = 323.15 [K];
            subject scout : ScoutRobot;
            require scout.cargo.tempControl.minTemperature >= minTemp;
            require scout.cargo.tempControl.maxTemperature <= maxTemp;
        }

        requirement def AutonomousDeliveryRequirement {
            doc /* The Scout shall autonomously plan and execute delivery routes without human intervention. */
            subject scout : ScoutRobot;
            require scout.controller != null;
        }

        requirement def SixWheelMobilityRequirement {
            doc /* The Scout shall have six wheels for stable mobility on sidewalks and pedestrian areas. */
            attribute requiredWheelCount : Integer = 6;
            subject scout : ScoutRobot;
            require scout.mobility.wheelCount == requiredWheelCount;
        }

        requirement def CustomerAuthenticationRequirement {
            doc /* The Scout shall authenticate the customer before unlocking the cargo bay. */
            subject scout : ScoutRobot;
            require scout.cargo.lock.locked == true;
        }

        requirement def SensorSuiteRequirement {
            doc /* The Scout shall be equipped with front and rear Lidar, front and side cameras, GPS, and IMU. */
            subject scout : ScoutRobot;
            require scout.perception.frontLidar != null;
            require scout.perception.rearLidar != null;
            require scout.perception.frontCamera != null;
            require scout.perception.leftCamera != null;
            require scout.perception.rightCamera != null;
            require scout.perception.gps != null;
            require scout.perception.imu != null;
        }

        requirement def DeliveryConfirmationRequirement {
            doc /* The Scout shall confirm delivery after package retrieval and transmit confirmation to the depot. */
            subject scout : ScoutRobot;
            require scout.comm != null;
        }

        requirement def EmergencyStopRequirement {
            doc /* The Scout shall be able to stop within 1.0 m when an obstacle is detected at close range. */
            attribute maxStopDistance : Distance = 1.0 [m];
            attribute maxResponseTime : Duration = 0.3 [s];
            subject scout : ScoutRobot;
            require scout.mobility.brakes.maxBrakeForce >= 200 [N];
        }
    }
}
