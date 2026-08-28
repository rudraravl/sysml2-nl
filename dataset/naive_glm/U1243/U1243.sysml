package AutonomousUGV {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    value def MassValue :> Real { unit 'kg'; }
    value def DistanceValue :> Real { unit 'm'; }
    value def SpeedValue :> Real { unit 'm/s'; }
    value def EnergyValue :> Real { unit 'Wh'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def Percentage :> Real { unit '%'; }
    value def AngleValue :> Real { unit 'rad'; }
    value def FrequencyValue :> Real { unit 'Hz'; }
    value def DataRateValue :> Real { unit 'kbps'; }
    
    // ===== Item Types =====
    item def TelemetryPacket {
        attribute status : String;
        attribute position : GPSPosition;
        attribute batteryLevel : Percentage;
        attribute sensorData : String;
    }
    
    item def MissionPlan {
        attribute missionId : String;
        attribute waypoints : GPSPosition[0..*];
        attribute priority : Integer;
    }
    
    item def GPSPosition {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Real;
    }
    
    item def ThrottleCommand {
        attribute throttle : Real; // 0.0 to 1.0
    }
    
    item def SteeringCommand {
        attribute angle : AngleValue;
    }
    
    item def SensorData {
        attribute lidarData : String;
        attribute imageData : String;
        attribute gpsPosition : GPSPosition;
    }
    
    item def ObstacleInfo {
        attribute detected : Boolean;
        attribute distance : DistanceValue;
        attribute bearing : AngleValue;
    }
    
    item def PowerFlow;
    
    // ===== Port Definitions =====
    port def PowerPort {
        out power : PowerFlow;
    }
    
    port def PowerInPort {
        in power : PowerFlow;
    }
    
    port def DataPort {
        out data : SensorData;
    }
    
    port def DataInPort {
        in data : SensorData;
    }
    
    port def CommandPort {
        out throttleCmd : ThrottleCommand;
        out steeringCmd : SteeringCommand;
    }
    
    port def CommandInPort {
        in throttleCmd : ThrottleCommand;
        in steeringCmd : SteeringCommand;
    }
    
    port def TelemetryPort {
        out telemetry : TelemetryPacket;
        in missionCmd : MissionPlan;
    }
    
    port def TelemetryInPort {
        in telemetry : TelemetryPacket;
        out missionCmd : MissionPlan;
    }
    
    port def LidarDataPort {
        out obstacleInfo : ObstacleInfo;
        out pointCloud : String;
    }
    
    port def LidarDataInPort {
        in obstacleInfo : ObstacleInfo;
        in pointCloud : String;
    }
    
    port def GPSDataPort {
        out position : GPSPosition;
    }
    
    port def GPSDataInPort {
        in position : GPSPosition;
    }
    
    port def ImageDataPort {
        out imageFrame : String;
    }
    
    port def ImageDataInPort {
        in imageFrame : String;
    }
    
    // ===== Requirements =====
    requirement def PlatformRequirements {
        attribute maxMass : MassValue = 150[kg];
        attribute maxRange : DistanceValue = 50000[m];
        attribute topSpeed : SpeedValue = 15[m/s];
        
        requirement MassRequirement {
            doc "The UGV platform mass shall not exceed 150 kg."
        }
        
        requirement RangeRequirement {
            doc "The UGV shall travel up to 50 km on a single charge."
        }
        
        requirement TopSpeedRequirement {
            doc "The UGV shall achieve a top speed of 15 m/s."
        }
    }
    
    requirement def LidarRangeRequirement {
        doc "The Lidar sensor shall detect obstacles up to 50 meters away."
        attribute minRange : DistanceValue = 50[m];
    }
    
    requirement def ObstacleAvoidanceRequirement {
        doc "The UGV shall avoid obstacles detected by the Lidar sensor."
    }
    
    requirement def EmergencyStopRequirement {
        doc "The UGV shall execute an emergency stop when a critical fault is detected."
    }
    
    requirement def ReturnHomeRequirement {
        doc "The UGV shall autonomously return to base if battery level becomes critical."
        attribute criticalBatteryThreshold : Percentage = 15[%];
    }
    
    requirement def TelemetryRequirement {
        doc "The UGV shall transmit telemetry packets containing status, position, and sensor data."
    }
    
    // ===== Parts =====
    part def BatteryPack {
        attribute capacity : EnergyValue = 2000[Wh];
        attribute nominalVoltage : VoltageValue = 48[V];
        attribute currentLevel : Percentage = 100[%];
        
        port powerOut : PowerPort;
        
        action def Discharge {
            in amount : EnergyValue;
            out newLevel : Percentage;
        }
    }
    
    part def ElectricMotor {
        attribute maxPower : Real = 3000;
        attribute currentThrottle : Real = 0.0;
        
        port powerIn : PowerInPort;
        port cmdIn : CommandInPort;
        
        action def ApplyThrottle {
            in cmd : ThrottleCommand;
            out torque : Real;
        }
    }
    
    part def SteeringActuator {
        attribute maxAngle : AngleValue = 0.785[rad]; // ~45 degrees
        attribute currentAngle : AngleValue = 0[rad];
        
        port powerIn : PowerInPort;
        port cmdIn : CommandInPort;
        
        action def ApplySteering {
            in cmd : SteeringCommand;
            out wheelAngle : AngleValue;
        }
    }
    
    part def LidarSensor {
        attribute maxRange : DistanceValue = 50[m];
        attribute scanRate : FrequencyValue = 10[Hz];
        
        port dataOut : LidarDataPort;
        
        action def Scan {
            out pointCloud : String;
            out obstacleInfo : ObstacleInfo;
        }
    }
    
    part def HDCamera {
        attribute resolution : String = "1920x1080";
        attribute frameRate : FrequencyValue = 30[Hz];
        
        port dataOut : ImageDataPort;
        
        action def Capture {
            out imageFrame : String;
        }
    }
    
    part def GPSReceiver {
        attribute accuracy : DistanceValue = 2[m];
        attribute updateRate : FrequencyValue = 10[Hz];
        
        port dataOut : GPSDataPort;
        
        action def GetPosition {
            out position : GPSPosition;
        }
    }
    
    part def NavigationComputer {
        port sensorDataIn : DataInPort;
        port lidarDataIn : LidarDataInPort;
        port gpsDataIn : GPSDataInPort;
        port imageDataIn : ImageDataInPort;
        port missionIn : DataInPort;
        port cmdOut : CommandPort;
        
        attribute currentPath : GPSPosition[0..*];
        
        action def CalculatePath {
            in sensorInput : SensorData;
            in mission : MissionPlan;
            out throttleCmd : ThrottleCommand;
            out steeringCmd : SteeringCommand;
        }
        
        action def PlanObstacleAvoidance {
            in obstacle : ObstacleInfo;
            out throttleCmd : ThrottleCommand;
            out steeringCmd : SteeringCommand;
        }
    }
    
    part def AutonomousController {
        port navCmdIn : CommandInPort;
        port telemetryOut : TelemetryPort;
        
        attribute currentState : String;
        attribute batteryCriticalThreshold : Percentage = 15[%];
        
        state def ControllerStates {
            initialState standby;
            state standby {
                entry { /* await mission plan */ }
                transition standby_to_navigating first standby if (missionReceived) to navigating;
            }
            
            state navigating {
                entry { /* move to next waypoint */ }
                transition navigating_to_obstacleAvoidance if (obstacleDetected) to obstacleAvoidance;
                transition navigating_to_missionComplete if (finalWaypointReached) to missionComplete;
                transition navigating_to_returnHome if (batteryCritical) to returnHome;
                transition navigating_to_emergencyStop if (emergencyCondition) to emergencyStop;
            }
            
            state obstacleAvoidance {
                entry { /* maneuver around obstacle */ }
                transition obstacleAvoidance_to_navigating if (obstacleCleared) to navigating;
                transition obstacleAvoidance_to_emergencyStop if (emergencyCondition) to emergencyStop;
            }
            
            state missionComplete {
                entry { /* mission accomplished */ }
                transition missionComplete_to_returnHome if (true) to returnHome;
            }
            
            state returnHome {
                entry { /* return to base */ }
                transition returnHome_to_standby if (baseReached) to standby;
                transition returnHome_to_emergencyStop if (emergencyCondition) to emergencyStop;
            }
            
            state emergencyStop {
                entry { /* safe shutdown */ }
                transition emergencyStop_to_standby if (systemReset) to standby;
            }
            
            attribute missionReceived : Boolean;
            attribute obstacleDetected : Boolean;
            attribute obstacleCleared : Boolean;
            attribute finalWaypointReached : Boolean;
            attribute batteryCritical : Boolean;
            attribute baseReached : Boolean;
            attribute emergencyCondition : Boolean;
            attribute systemReset : Boolean;
        }
    }
    
    part def CommunicationModule {
        attribute dataRate : DataRateValue = 100[kbps];
        attribute frequency : FrequencyValue = 2.4[GHz];
        
        port telemetryOut : TelemetryPort;
        port telemetryIn : TelemetryInPort;
        
        action def TransmitTelemetry {
            in packet : TelemetryPacket;
        }
        
        action def ReceiveMission {
            out mission : MissionPlan;
        }
    }
    
    part def ControlStation {
        port telemetryIn : TelemetryInPort;
        
        action def MonitorTelemetry {
            in packet : TelemetryPacket;
        }
        
        action def SendMission {
            out mission : MissionPlan;
        }
    }
    
    part def PropulsionSystem {
        part motor : ElectricMotor;
        part steering : SteeringActuator;
        
        port powerIn : PowerInPort;
        port cmdIn : CommandInPort;
    }
    
    part def SensorSuite {
        part lidar : LidarSensor;
        part camera : HDCamera;
        part gps : GPSReceiver;
        
        port lidarDataOut : LidarDataPort;
        port imageDataOut : ImageDataPort;
        port gpsDataOut : GPSDataPort;
    }
    
    // ===== Top-level UGV System =====
    part def UGVSystem {
        satisfy PlatformRequirements::MassRequirement;
        satisfy PlatformRequirements::RangeRequirement;
        satisfy PlatformRequirements::TopSpeedRequirement;
        satisfy ObstacleAvoidanceRequirement;
        satisfy EmergencyStopRequirement;
        satisfy ReturnHomeRequirement;
        satisfy TelemetryRequirement;
        
        attribute platformMass : MassValue = 150[kg];
        attribute maxRange : DistanceValue = 50000[m];
        attribute topSpeed : SpeedValue = 15[m/s];
        
        part battery : BatteryPack {
            port powerOut : PowerPort;
        }
        
        part propulsion : PropulsionSystem {
            part motor : ElectricMotor;
            part steering : SteeringActuator;
            port powerIn : PowerInPort;
            port cmdIn : CommandInPort;
        }
        
        part sensors : SensorSuite {
            part lidar : LidarSensor;
            part camera : HDCamera;
            part gps : GPSReceiver;
            port lidarDataOut : LidarDataPort;
            port imageDataOut : ImageDataPort;
            port gpsDataOut : GPSDataPort;
        }
        
        part navComputer : NavigationComputer;
        part controller : AutonomousController;
        part comm : CommunicationModule;
        
        // Power connections
        connection battery.powerOut to propulsion.powerIn;
        connection battery.powerOut to sensors.lidar.powerIn;
        connection battery.powerOut to sensors.camera.powerIn;
        connection battery.powerOut to sensors.gps.powerIn;
        connection battery.powerOut to navComputer.powerIn;
        connection battery.powerOut to controller.powerIn;
        connection battery.powerOut to comm.powerIn;
        
        // Sensor data connections
        connection sensors.lidar.dataOut to navComputer.lidarDataIn;
        connection sensors.camera.dataOut to navComputer.imageDataIn;
        connection sensors.gps.dataOut to navComputer.gpsDataIn;
        
        // Navigation command connections
        connection navComputer.cmdOut to propulsion.cmdIn;
        connection navComputer.cmdOut to controller.navCmdIn;
        
        // Telemetry connections
        connection controller.telemetryOut to comm.telemetryIn;
        connection comm.telemetryOut to externalControlStation.telemetryIn;
        
        // Mission plan flow
        connection comm.telemetryIn.missionCmd to navComputer.missionIn;
        
        // UGV operational state machine
        state def UGVOperationalStates {
            initialState standbyState;
            
            state standbyState {
                entry { /* await mission plan from control station */ }
                transition to navigatingState if (missionPlanReceived);
            }
            
            state navigatingState {
                entry { /* navigate to waypoints */ }
                transition to obstacleAvoidanceState if (lidarObstacleDetected);
                transition to missionCompleteState if (finalWaypointReached);
                transition to returnHomeState if (batteryLevelCritical);
                transition to emergencyStopState if (emergencyConditionDetected);
            }
            
            state obstacleAvoidanceState {
                entry { /* maneuver around obstacle */ }
                transition to navigatingState if (obstacleCleared);
                transition to emergencyStopState if (emergencyConditionDetected);
            }
            
            state missionCompleteState {
                entry { /* mark mission complete */ }
                transition to returnHomeState;
            }
            
            state returnHomeState {
                entry { /* autonomously return to base */ }
                transition to standbyState if (baseReached);
                transition to emergencyStopState if (emergencyConditionDetected);
            }
            
            state emergencyStopState {
                entry { /* safe shutdown procedure */ }
                transition to standbyState if (systemReset);
            }
            
            attribute missionPlanReceived : Boolean;
            attribute lidarObstacleDetected : Boolean;
            attribute obstacleCleared : Boolean;
            attribute finalWaypointReached : Boolean;
            attribute batteryLevelCritical : Boolean;
            attribute baseReached : Boolean;
            attribute emergencyConditionDetected : Boolean;
            attribute systemReset : Boolean;
        }
        
        action def ExecuteMission {
            in mission : MissionPlan;
            out result : String;
            
            // Receive mission plan
            // Transition from standby to navigating
            // Process waypoints sequentially
            // Handle obstacles via avoidance maneuvers
            // Return to base upon completion or critical battery
        }
        
        action def EmergencyStop {
            out status : String;
            // Cut power to propulsion
            // Apply brakes
            // Transmit emergency telemetry
        }
        
        action def ReturnToBase {
            out status : String;
            // Calculate return path to home position
            // Navigate autonomously
        }
    }
    
    // ===== External Control Station Part =====
    part def ExternalControlStation {
        part station : ControlStation;
        port telemetryIn : TelemetryInPort;
        
        action def Monitor {
            in packet : TelemetryPacket;
        }
    }
    
    part externalControlStation : ExternalControlStation;
}
