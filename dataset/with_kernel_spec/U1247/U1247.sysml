package UGVSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    enum def MissionMode {
        manual;
        waypoint;
        patrol;
    }

    attribute def Waypoint {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude :> ISQ::length;
    }

    attribute def TelemetryData {
        attribute position :> ISQ::length;
        attribute speed :> ISQ::speed;
        attribute batteryLevel : Real;
    }

    attribute def ObstacleData {
        attribute distance :> ISQ::length;
        attribute isDetected : Boolean;
    }

    attribute def EnvironmentModel {
        attribute mapData : String;
        attribute obstacles : ObstacleData[*];
    }

    attribute def MissionCommand {
        attribute mode : MissionMode;
        attribute waypoints : Waypoint[*];
    }

    attribute def DriveCommand {
        attribute targetSpeed :> ISQ::speed;
        attribute steeringAngle :> ISQ::planeAngle;
    }

    attribute def StartMission;
    attribute def TaskComplete;
    attribute def CriticalAlert;
    attribute def Reset;

    port def PowerPort {
        out attribute voltage :> ISQ::electricPotentialDifference;
        out attribute current :> ISQ::electricCurrent;
    }

    port def SensorDataPort {
        out attribute data : String;
    }

    port def DriveCmdPort {
        out attribute cmd : DriveCommand;
    }

    port def TelemetryPort {
        out attribute telemetry : TelemetryData;
    }

    port def MissionPort {
        out attribute missionCmd : MissionCommand;
    }

    part def BatteryPack {
        port powerOut : PowerPort;
        attribute capacity :> ISQ::energy;
        attribute currentCharge :> ISQ::energy;
    }

    part def LidarSensor {
        port dataOut : SensorDataPort;
        port powerIn : ~PowerPort;
        perform action scanEnvironment;
    }

    part def CameraSensor {
        port dataOut : SensorDataPort;
        port powerIn : ~PowerPort;
        perform action captureImage;
    }

    part def GpsReceiver {
        port dataOut : SensorDataPort;
        port powerIn : ~PowerPort;
        perform action getFix;
    }

    part def InertialMeasurementUnit {
        port dataOut : SensorDataPort;
        port powerIn : ~PowerPort;
        perform action measureOrientation;
    }

    part def DriveMotor {
        port powerIn : ~PowerPort;
        port cmdIn : ~DriveCmdPort;
        attribute rpm :> ISQ::frequency;
    }

    part def SteeringActuator {
        port powerIn : ~PowerPort;
        port cmdIn : ~DriveCmdPort;
        attribute angle :> ISQ::planeAngle;
    }

    part def DriveSystem {
        port cmdIn : ~DriveCmdPort;
        port powerIn : ~PowerPort;
        part motor1 : DriveMotor;
        part motor2 : DriveMotor;
        part steeringActuator : SteeringActuator;
        connect powerIn to motor1.powerIn;
        connect powerIn to motor2.powerIn;
        connect powerIn to steeringActuator.powerIn;
        connect cmdIn to motor1.cmdIn;
        connect cmdIn to motor2.cmdIn;
        connect cmdIn to steeringActuator.cmdIn;
    }

    part def CommunicationModule {
        port telemetryIn : ~TelemetryPort;
        port missionOut : MissionPort;
        port powerIn : ~PowerPort;
        perform action transmitTelemetry;
        perform action receiveCommand;
    }

    part def NavigationController {
        port lidarIn : ~SensorDataPort;
        port cameraIn : ~SensorDataPort;
        port gpsIn : ~SensorDataPort;
        port imuIn : ~SensorDataPort;
        port commsTelemetryOut : TelemetryPort;
        port commsMissionIn : ~MissionPort;
        port driveCmdOut : DriveCmdPort;
        port powerIn : ~PowerPort;
        
        attribute currentMode : MissionMode;
        attribute envModel : EnvironmentModel;
        
        perform action processSensorData;
        perform action planPath;
        perform action computeDriveCommands;
        perform action avoidObstacle;
    }

    part def UGV {
        attribute mass :> ISQ::mass;
        attribute maxSpeed :> ISQ::speed;
        
        part battery : BatteryPack;
        part controller : NavigationController;
        part comms : CommunicationModule;
        part driveSystem : DriveSystem;
        part sensorLidar : LidarSensor;
        part sensorCamera : CameraSensor;
        part sensorGps : GpsReceiver;
        part sensorImu : InertialMeasurementUnit;
        
        connect battery.powerOut to controller.powerIn;
        connect battery.powerOut to driveSystem.powerIn;
        connect battery.powerOut to comms.powerIn;
        connect battery.powerOut to sensorLidar.powerIn;
        connect battery.powerOut to sensorCamera.powerIn;
        connect battery.powerOut to sensorGps.powerIn;
        connect battery.powerOut to sensorImu.powerIn;
        
        connect sensorLidar.dataOut to controller.lidarIn;
        connect sensorCamera.dataOut to controller.cameraIn;
        connect sensorGps.dataOut to controller.gpsIn;
        connect sensorImu.dataOut to controller.imuIn;
        
        connect controller.driveCmdOut to driveSystem.cmdIn;
        connect comms.missionOut to controller.commsMissionIn;
        connect controller.commsTelemetryOut to comms.telemetryIn;
        
        exhibit state UGVOperationalStates {
            entry; then idle;
            state idle;
            transition idle_to_navigating
                first idle
                accept StartMission
                then navigating;
            state navigating;
            transition navigating_to_stopped
                first navigating
                accept TaskComplete
                then stopped;
            state stopped;
            transition navigating_to_emergency
                first navigating
                accept CriticalAlert
                then emergency;
            state emergency;
            transition emergency_to_idle
                first emergency
                accept Reset
                then idle;
            transition stopped_to_idle
                first stopped
                accept Reset
                then idle;
        }
    }

    part ugv : UGV;

    requirement def UGVRequirements {
        doc /* The UGV shall autonomously navigate pre-programmed waypoints. */
        doc /* The UGV shall dynamically avoid obstacles using Lidar. */
        doc /* The UGV shall transmit telemetry including position, speed, and battery level via long-range communication. */
    }
}
