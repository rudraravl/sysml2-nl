package UGVSystem {

    // ---- Value Types with Units ----
    package ValueTypes {
        import ScalarValues::*;
        import ISQ::*;
        import ISQSpace::*;
        import ISQTime::*;
        import ISQElectricity::*;

        value type Distance :> Real { unit "m"; }
        value type Velocity :> Real { unit "m/s"; }
        value type Angle :> Real { unit "rad"; }
        value type AngularVelocity :> Real { unit "rad/s"; }
        value type Power :> Real { unit "W"; }
        value type Voltage :> Real { unit "V"; }
        value type Current :> Real { unit "A"; }
        value type BatteryLevel :> Real { unit "%"; }
        value type Frequency :> Real { unit "Hz"; }
        value type Mass :> Real { unit "kg"; }
        value type Temperature :> Real { unit "K"; }
        value type SignalStrength :> Real { unit "dBm"; }
    }

    // ---- Item Definitions ----
    package Items {
        import ValueTypes::*;

        item def Waypoint {
            attribute x : Distance;
            attribute y : Distance;
            attribute tolerance : Distance = 0.5 [m];
        }

        item def MissionPlan {
            attribute waypoints : Waypoint[0..*];
            attribute mode : MissionMode;
        }

        enum def MissionMode {
            MANUAL;
            WAYPOINT_FOLLOWING;
            PATROLLING;
        }

        item def ObstacleDetection {
            attribute distance : Distance;
            attribute bearing : Angle;
            attribute severity : SeverityKind;
        }

        enum def SeverityKind {
            NONE;
            LOW;
            MEDIUM;
            HIGH;
            CRITICAL;
        }

        item def LidarScan {
            attribute ranges : Distance[0..*];
            attribute angles : Angle[0..*];
            attribute timestamp : Time;
        }

        item def CameraImage {
            attribute width : Integer;
            attribute height : Integer;
            attribute data : String;
            attribute timestamp : Time;
        }

        item def GPSFix {
            attribute latitude : Angle;
            attribute longitude : Angle;
            attribute altitude : Distance;
            attribute accuracy : Distance;
            attribute timestamp : Time;
        }

        item def IMUData {
            attribute roll : Angle;
            attribute pitch : Angle;
            attribute yaw : Angle;
            attribute rollRate : AngularVelocity;
            attribute pitchRate : AngularVelocity;
            attribute yawRate : AngularVelocity;
            attribute accelX : Velocity;
            attribute accelY : Velocity;
            attribute accelZ : Velocity;
            attribute timestamp : Time;
        }

        item def DriveCommand {
            attribute leftMotorSpeed : Velocity;
            attribute rightMotorSpeed : Velocity;
            attribute steeringAngle : Angle;
        }

        item def Telemetry {
            attribute position : GPSFix;
            attribute speed : Velocity;
            attribute heading : Angle;
            attribute batteryLevel : BatteryLevel;
            attribute status : UGVStateKind;
            attribute timestamp : Time;
        }

        item def OperatorCommand {
            attribute mode : MissionMode;
            attribute plan : MissionPlan;
            attribute emergencyStop : Boolean = false;
        }

        enum def UGVStateKind {
            IDLE;
            NAVIGATING;
            STOPPED;
            EMERGENCY;
        }
    }

    // ---- Requirements ----
    package Requirements {
        import Items::*;
        import ValueTypes::*;

        requirement def AutonomousNavigation {
            doc "The UGV shall autonomously navigate a series of pre-programmed waypoints."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall follow waypoints with a tolerance of at most 0.5 [m].
            }
            requirement {
                subject ugv;
                the ugv shall compute a new path when an obstacle is detected.
            }
        }

        requirement def ObstacleAvoidance {
            doc "The UGV shall detect and avoid obstacles using Lidar data."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall detect obstacles within 10 [m].
            }
            requirement {
                subject ugv;
                the ugv shall stop or reroute within 0.5 [s] of detecting a critical obstacle.
            }
        }

        requirement def SensorSuiteIntegration {
            doc "The UGV shall integrate Lidar, camera, GPS, and IMU data."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall process sensor data at least 10 [Hz].
            }
        }

        requirement def DriveSystemControl {
            doc "The UGV drive system shall execute speed and steering commands."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall achieve a maximum speed of at least 5 [m/s].
            }
            requirement {
                subject ugv;
                the ugv shall steer within a range of -0.5 [rad] to 0.5 [rad].
            }
        }

        requirement def PowerEndurance {
            doc "The UGV shall operate for at least 4 hours on a single battery charge."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall maintain battery level above 10 [%] during normal operation.
            }
        }

        requirement def LongRangeCommunication {
            doc "The UGV shall maintain communication with the control station over long distances."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall transmit telemetry at least 1 [Hz].
            }
            requirement {
                subject ugv;
                the ugv shall maintain signal strength above -90 [dBm].
            }
        }

        requirement def StateManagement {
            doc "The UGV shall operate in idle, navigating, stopped, and emergency states."
            subject ugv : UGV;
            requirement {
                subject ugv;
                the ugv shall enter the emergency state upon critical failure.
            }
        }
    }

    // ---- Port Definitions ----
    package Ports {
        import Items::*;

        port def LidarOut {
            out scan : LidarScan;
        }

        port def CameraOut {
            out image : CameraImage;
        }

        port def GPSOut {
            out fix : GPSFix;
        }

        port def IMUOut {
            out data : IMUData;
        }

        port def DriveCmdPort {
            in cmd : DriveCommand;
        }

        port def TelemetryPort {
            out telemetry : Telemetry;
            in command : OperatorCommand;
        }

        port def PowerPort {
            out voltage : Voltage;
            out current : Current;
        }

        port def MotorDrivePort {
            in speed : Velocity;
        }

        port def SteeringPort {
            in angle : Angle;
        }
    }

    // ---- Component Parts ----
    package Components {
        import Items::*;
        import Ports::*;
        import ValueTypes::*;

        part def LidarSensor {
            attribute maxRange : Distance = 30 [m];
            attribute scanRate : Frequency = 10 [Hz];
            port lidarOut : LidarOut;
            exhibit state machine LidarBehavior {
                entry; then Scanning;
                state Scanning {
                    entry; then send LidarScan(lidarOut.scan);
                }
            }
        }

        part def CameraSensor {
            attribute resolution : String = "1920x1080";
            attribute frameRate : Frequency = 30 [Hz];
            port cameraOut : CameraOut;
            exhibit state machine CameraBehavior {
                entry; then Capturing;
                state Capturing {
                    entry; then send CameraImage(cameraOut.image);
                }
            }
        }

        part def GPSReceiver {
            attribute updateRate : Frequency = 5 [Hz];
            port gpsOut : GPSOut;
            exhibit state machine GPSBehavior {
                entry; then Acquiring;
                state Acquiring {
                    entry; then Tracking;
                }
                state Tracking {
                    entry; then send GPSFix(gpsOut.fix);
                }
            }
        }

        part def IMU {
            attribute updateRate : Frequency = 100 [Hz];
            port imuOut : IMUOut;
            exhibit state machine IMUBehavior {
                entry; then Sampling;
                state Sampling {
                    entry; then send IMUData(imuOut.data);
                }
            }
        }

        part def DriveMotor {
            attribute maxSpeed : Velocity = 5 [m/s];
            attribute maxTorque : Real = 10.0;
            port motorIn : MotorDrivePort;
            exhibit state machine MotorBehavior {
                entry; then Idle;
                state Idle;
                state Running {
                    entry; then apply(motorIn.speed);
                }
            }
        }

        part def SteeringActuator {
            attribute maxAngle : Angle = 0.5 [rad];
            port steerIn : SteeringPort;
            exhibit state machine SteeringBehavior {
                entry; then Centered;
                state Centered;
                state Adjusting {
                    entry; then apply(steerIn.angle);
                }
            }
        }

        part def DriveSystem {
            part leftMotor : DriveMotor;
            part rightMotor : DriveMotor;
            part steering : SteeringActuator;
            port driveCmd : DriveCmdPort;
            exhibit state machine DriveSystemBehavior {
                entry; then Idle;
                state Idle;
                state Active {
                    entry; then distribute(driveCmd.cmd);
                }
            }
        }

        part def BatteryPack {
            attribute capacity : Real = 100.0;
            attribute nominalVoltage : Voltage = 24 [V];
            attribute level : BatteryLevel = 100 [%];
            port powerOut : PowerPort;
            exhibit state machine BatteryBehavior {
                entry; then Discharging;
                state Discharging {
                    entry; then supply(powerOut.voltage, powerOut.current);
                }
                state Low {
                    entry; then alert;
                }
                state Depleted;
            }
        }

        part def CommunicationModule {
            attribute range : Distance = 5000 [m];
            attribute signalStrength : SignalStrength = -70 [dBm];
            port comm : TelemetryPort;
            exhibit state machine CommBehavior {
                entry; then Connected;
                state Connected {
                    entry; then send Telemetry(comm.telemetry);
                }
                state Disconnected;
            }
        }

        part def NavigationController {
            attribute mode : MissionMode = MissionMode::WAYPOINT_FOLLOWING;
            attribute currentPlan : MissionPlan;
            attribute currentSpeed : Velocity = 0 [m/s];
            attribute currentHeading : Angle = 0 [rad];
            port lidarIn : LidarOut;
            port cameraIn : CameraOut;
            port gpsIn : GPSOut;
            port imuIn : IMUOut;
            port driveOut : DriveCmdPort;
            port comm : TelemetryPort;
            exhibit state machine ControllerBehavior {
                entry; then Idle;
                state Idle {
                    entry; then wait;
                }
                state Navigating {
                    entry; then planPath;
                    do { processSensors; }
                }
                state ObstacleAvoidance {
                    entry; then computeAlternatePath;
                }
                state Stopped {
                    entry; then halt;
                }
                state Emergency {
                    entry; then emergencyStop;
                }
                transition from Idle to Navigating when received(comm.command);
                transition from Navigating to ObstacleAvoidance when obstacleDetected(lidarIn.scan);
                transition from ObstacleAvoidance to Navigating when pathCleared;
                transition from Navigating to Stopped when missionComplete;
                transition from Idle to Emergency when criticalFault;
                transition from Navigating to Emergency when criticalFault;
                transition from Stopped to Idle when reset;
                transition from Emergency to Idle when faultCleared;
            }
        }
    }

    // ---- Top-level UGV System ----
    package System {
        import Components::*;
        import Items::*;
        import Ports::*;
        import ValueTypes::*;
        import Requirements::*;

        part def UGV {
            attribute name : String = "UGV-Alpha";
            attribute mass : Mass = 50 [kg];

            part lidar : LidarSensor;
            part camera : CameraSensor;
            part gps : GPSReceiver;
            part imu : IMU;
            part controller : NavigationController;
            part drive : DriveSystem;
            part battery : BatteryPack;
            part comm : CommunicationModule;

            // Power distribution
            connection powerToController : PowerPort connect battery.powerOut to controller.powerIn;
            connection powerToLidar : PowerPort connect battery.powerOut to lidar.powerIn;
            connection powerToCamera : PowerPort connect battery.powerOut to camera.powerIn;
            connection powerToGPS : PowerPort connect battery.powerOut to gps.powerIn;
            connection powerToIMU : PowerPort connect battery.powerOut to imu.powerIn;
            connection powerToDrive : PowerPort connect battery.powerOut to drive.powerIn;
            connection powerToComm : PowerPort connect battery.powerOut to comm.powerIn;

            // Sensor data to controller
            connection lidarToController : LidarOut connect lidar.lidarOut to controller.lidarIn;
            connection cameraToController : CameraOut connect camera.cameraOut to controller.cameraIn;
            connection gpsToController : GPSOut connect gps.gpsOut to controller.gpsIn;
            connection imuToController : IMUOut connect imu.imuOut to controller.imuIn;

            // Controller to drive system
            connection controllerToDrive : DriveCmdPort connect controller.driveOut to drive.driveCmd;

            // Controller to communication module
            connection controllerToComm : TelemetryPort connect controller.comm to comm.comm;

            // Requirements satisfaction
            satisfy AutonomousNavigation by ugv;
            satisfy ObstacleAvoidance by ugv;
            satisfy SensorSuiteIntegration by ugv;
            satisfy DriveSystemControl by ugv;
            satisfy PowerEndurance by ugv;
            satisfy LongRangeCommunication by ugv;
            satisfy StateManagement by ugv;

            exhibit state machine UGVStateMachine {
                entry; then idle;
                state idle {
                    doc "Waiting for instructions.";
                }
                state navigating {
                    doc "Actively performing a mission.";
                }
                state stopped {
                    doc "Task completed.";
                }
                state emergency {
                    doc "Critical issue detected.";
                }
                transition from idle to navigating when missionReceived;
                transition from navigating to stopped when missionComplete;
                transition from navigating to emergency when criticalIssue;
                transition from idle to emergency when criticalIssue;
                transition from stopped to idle when newMission;
                transition from emergency to idle when faultResolved;
            }
        }
    }
}
