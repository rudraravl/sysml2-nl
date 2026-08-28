package AutonomousQuadcopterUAV {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def GPSPosition {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def Orientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def Waypoint {
        attribute position : GPSPosition;
        attribute loiterTime : Real;
    }
    
    attribute def TelemetryData {
        attribute position : GPSPosition;
        attribute speed : SpeedValue;
        attribute batteryLevel : Real;
        attribute systemHealth : String;
    }
    
    attribute def UploadMissionCommand;
    attribute def PreFlightCheckPassed;
    attribute def PreFlightCheckFailed;
    attribute def MotorsArmed;
    attribute def TakeoffComplete;
    attribute def WaypointReachedEvent;
    attribute def LoiterComplete;
    attribute def MissionComplete;
    attribute def ObstacleDetectedEvent;
    attribute def ObstacleClearedEvent;
    attribute def LowBatteryEvent;
    attribute def ReturnToLaunchCommand;
    attribute def HomeReachedEvent;
    attribute def LandingComplete;
    
    part def Airframe {
        attribute material : String = "Carbon Fiber";
    }
    
    part def BrushlessMotor {
        port driveIn;
        port powerIn;
    }
    
    part def Propeller;
    
    part def ESC {
        port cmdIn {
            in attribute speedCmd : Real;
        }
        port motorOut;
        port powerIn;
    }
    
    part def LiPoBattery {
        attribute capacity : ElectricChargeValue;
        attribute chargeLevel : Real;
        port levelOut {
            out attribute level : Real;
        }
        port powerOut;
    }
    
    part def FlightController {
        port gpsIn {
            in attribute position : GPSPosition;
            in attribute speed : SpeedValue;
        }
        port imuIn {
            in attribute orientation : Orientation;
        }
        port obstacleIn {
            in attribute distance : LengthValue;
        }
        port batteryIn {
            in attribute level : Real;
        }
        port esc1Out {
            out attribute speedCmd : Real;
        }
        port esc2Out {
            out attribute speedCmd : Real;
        }
        port esc3Out {
            out attribute speedCmd : Real;
        }
        port esc4Out {
            out attribute speedCmd : Real;
        }
        port radioPort {
            out attribute telemetry : TelemetryData;
            in attribute missionPlan : Waypoint[0..*];
            in attribute command : String;
        }
        port powerIn;
        attribute waypoints : Waypoint[0..*];
        attribute currentWaypointIndex : Integer = 0;
        attribute homePosition : GPSPosition;
        attribute criticalBatteryLevel : Real = 0.2;
        attribute safeObstacleDistance : LengthValue = 15;
    }
    
    part def GPSReceiver {
        port dataOut {
            out attribute position : GPSPosition;
            out attribute speed : SpeedValue;
        }
        port powerIn;
    }
    
    part def IMU {
        port dataOut {
            out attribute orientation : Orientation;
        }
        port powerIn;
    }
    
    part def ObstacleAvoidanceSensor {
        attribute range : LengthValue = 15;
        attribute currentDistance : LengthValue;
        port dataOut {
            out attribute distance : LengthValue;
        }
        port powerIn;
    }
    
    part def Camera {
        port powerIn;
        port dataOut;
    }
    
    part def RadioTransceiver {
        attribute range : LengthValue = 10000;
        port fcPort {
            in attribute telemetry : TelemetryData;
            out attribute missionPlan : Waypoint[0..*];
            out attribute command : String;
        }
        port groundUplinkPort {
            in attribute missionPlan : Waypoint[0..*];
            in attribute command : String;
        }
        port groundDownlinkPort {
            out attribute telemetry : TelemetryData;
        }
        port powerIn;
        part antenna;
    }
    
    part def GroundControlStation {
        port missionSendPort {
            out attribute missionPlan : Waypoint[0..*];
        }
        port telemetryReceivePort {
            in attribute telemetry : TelemetryData;
        }
    }
    
    action def PreFlightCheck;
    action def ArmMotors;
    action def Takeoff;
    action def NavigateWaypoints;
    action def Loiter;
    action def ReturnToLaunch;
    action def Land;
    action def TransmitTelemetry;
    action def AvoidObstacle;
    action def NavigateAndTransmit;
    action def LoiterAndTransmit;
    action def ReturnAndTransmit;
    
    state def UAVOperationalStates;
    
    requirement def FlightTimeRequirement {
        doc /* The UAV shall provide a flight time of over 30 minutes. */
        attribute minFlightTime : Real = 30;
    }
    
    requirement def ObstacleAvoidanceRequirement {
        doc /* The obstacle avoidance sensor shall detect and prevent collisions within a 15-meter range. */
        attribute maxDetectionRange : LengthValue = 15;
    }
    
    requirement def RadioRangeRequirement {
        doc /* The radio transceiver shall communicate with a ground control station up to 10 kilometers away. */
        attribute maxCommRange : LengthValue = 10000;
    }
    
    requirement def AutonomousMissionRequirement {
        doc /* The UAV shall execute missions autonomously by navigating through uploaded GPS waypoints. */
    }
    
    requirement def BatterySafetyRequirement {
        doc /* The system shall trigger an automatic return-to-launch command if battery charge drops to a critical level. */
        attribute criticalLevel : Real = 0.2;
    }
    
    requirement def TelemetryRequirement {
        doc /* The system shall continuously transmit telemetry data including position, speed, battery level, and system health. */
    }
    
    part def UAVSystem {
        perform action preFlightCheckAct : PreFlightCheck;
        perform action armMotorsAct : ArmMotors;
        perform action takeoffAct : Takeoff;
        perform action navigateWaypointsAct : NavigateWaypoints;
        perform action loiterAct : Loiter;
        perform action returnToLaunchAct : ReturnToLaunch;
        perform action landAct : Land;
        perform action transmitTelemetryAct : TransmitTelemetry;
        perform action avoidObstacleAct : AvoidObstacle;
        perform action navigateAndTransmitAct : NavigateAndTransmit;
        perform action loiterAndTransmitAct : LoiterAndTransmit;
        perform action returnAndTransmitAct : ReturnAndTransmit;
        
        part airframe : Airframe;
        part motor1 : BrushlessMotor;
        part motor2 : BrushlessMotor;
        part motor3 : BrushlessMotor;
        part motor4 : BrushlessMotor;
        part propeller1 : Propeller;
        part propeller2 : Propeller;
        part propeller3 : Propeller;
        part propeller4 : Propeller;
        part esc1 : ESC;
        part esc2 : ESC;
        part esc3 : ESC;
        part esc4 : ESC;
        part battery : LiPoBattery;
        part flightController : FlightController;
        part gps : GPSReceiver;
        part imu : IMU;
        part obstacleSensor : ObstacleAvoidanceSensor;
        part camera : Camera;
        part radio : RadioTransceiver;
        
        connect battery.powerOut to flightController.powerIn;
        connect battery.powerOut to esc1.powerIn;
        connect battery.powerOut to esc2.powerIn;
        connect battery.powerOut to esc3.powerIn;
        connect battery.powerOut to esc4.powerIn;
        connect battery.powerOut to gps.powerIn;
        connect battery.powerOut to imu.powerIn;
        connect battery.powerOut to obstacleSensor.powerIn;
        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to radio.powerIn;
        
        connect battery.levelOut to flightController.batteryIn;
        connect gps.dataOut to flightController.gpsIn;
        connect imu.dataOut to flightController.imuIn;
        connect obstacleSensor.dataOut to flightController.obstacleIn;
        
        connect flightController.esc1Out to esc1.cmdIn;
        connect flightController.esc2Out to esc2.cmdIn;
        connect flightController.esc3Out to esc3.cmdIn;
        connect flightController.esc4Out to esc4.cmdIn;
        
        connect esc1.motorOut to motor1.driveIn;
        connect esc2.motorOut to motor2.driveIn;
        connect esc3.motorOut to motor3.driveIn;
        connect esc4.motorOut to motor4.driveIn;
        
        connect motor1 to propeller1;
        connect motor2 to propeller2;
        connect motor3 to propeller3;
        connect motor4 to propeller4;
        
        connect flightController.radioPort to radio.fcPort;
        
        exhibit state operationalStates : UAVOperationalStates {
            entry; then idle;
            state idle;
            accept UploadMissionCommand then preFlightCheck;
            state preFlightCheck {
                do preFlightCheckAct;
            }
            accept PreFlightCheckPassed then arming;
            accept PreFlightCheckFailed then idle;
            state arming {
                do armMotorsAct;
            }
            accept MotorsArmed then takingOff;
            state takingOff {
                do takeoffAct;
            }
            accept TakeoffComplete then navigating;
            state navigating {
                do navigateAndTransmitAct;
            }
            accept WaypointReachedEvent then loitering;
            accept MissionComplete then returning;
            accept LowBatteryEvent
                if battery.chargeLevel < flightController.criticalBatteryLevel
                then returning;
            accept ReturnToLaunchCommand then returning;
            accept ObstacleDetectedEvent
                if obstacleSensor.currentDistance < flightController.safeObstacleDistance
                then avoidingObstacle;
            state loitering {
                do loiterAndTransmitAct;
            }
            accept LoiterComplete then navigating;
            accept LowBatteryEvent
                if battery.chargeLevel < flightController.criticalBatteryLevel
                then returning;
            accept ReturnToLaunchCommand then returning;
            state avoidingObstacle {
                do avoidObstacleAct;
            }
            accept ObstacleClearedEvent then navigating;
            state returning {
                do returnAndTransmitAct;
            }
            accept HomeReachedEvent then landing;
            state landing {
                do landAct;
            }
            accept LandingComplete then idle;
        }
    }
    
    part uavSystem : UAVSystem;
    part groundStation : GroundControlStation;
    
    connect groundStation.missionSendPort to uavSystem.radio.groundUplinkPort;
    connect uavSystem.radio.groundDownlinkPort to groundStation.telemetryReceivePort;
    
    requirement flightTimeReq : FlightTimeRequirement;
    requirement obstacleAvoidanceReq : ObstacleAvoidanceRequirement;
    requirement radioRangeReq : RadioRangeRequirement;
    requirement autonomousMissionReq : AutonomousMissionRequirement;
    requirement batterySafetyReq : BatterySafetyRequirement;
    requirement telemetryReq : TelemetryRequirement;
    
    satisfy flightTimeReq by uavSystem;
    satisfy obstacleAvoidanceReq by uavSystem;
    satisfy radioRangeReq by uavSystem;
    satisfy autonomousMissionReq by uavSystem;
    satisfy batterySafetyReq by uavSystem;
    satisfy telemetryReq by uavSystem;
}
