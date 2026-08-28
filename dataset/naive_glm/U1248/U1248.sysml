package AutonomousUAVSystem {
    import ScalarValues::*;
    
    package ValueTypes {
        value type Voltage :> Real {
            attribute unit : String = "V";
        }
        value type Current :> Real {
            attribute unit : String = "A";
        }
        value type Power :> Real {
            attribute unit : String = "W";
        }
        value type Energy :> Real {
            attribute unit : String = "Wh";
        }
        value type Speed :> Real {
            attribute unit : String = "m/s";
        }
        value type Altitude :> Real {
            attribute unit : String = "m";
        }
        value type Distance :> Real {
            attribute unit : String = "m";
        }
        value type Latitude :> Real {
            attribute unit : String = "deg";
        }
        value type Longitude :> Real {
            attribute unit : String = "deg";
        }
        value type HeadingAngle :> Real {
            attribute unit : String = "deg";
        }
        value type Thrust :> Real {
            attribute unit : String = "N";
        }
        value type BatteryLevel :> Real {
            attribute unit : String = "%";
        }
        value type DataRate :> Real {
            attribute unit : String = "bps";
        }
        value type Frequency :> Real {
            attribute unit : String = "Hz";
        }
        value type Mass :> Real {
            attribute unit : String = "kg";
        }
        value type Duration :> Real {
            attribute unit : String = "s";
        }
        value type Percent :> Real {
            attribute unit : String = "%";
        }
    }
    
    package Items {
        import ValueTypes::*;
        
        item GPSData {
            attribute latitude : Latitude;
            attribute longitude : Longitude;
            attribute timestamp : Duration;
        }
        
        item IMUData {
            attribute roll : HeadingAngle;
            attribute pitch : HeadingAngle;
            attribute yaw : HeadingAngle;
            attribute timestamp : Duration;
        }
        
        item LidarData {
            attribute distanceToObstacle : Distance;
            attribute azimuth : HeadingAngle;
            attribute elevation : HeadingAngle;
            attribute timestamp : Duration;
        }
        
        item CameraImage {
            attribute imageData : String;
            attribute captureTime : Duration;
            attribute exposureTime : Duration;
        }
        
        item Waypoint {
            attribute sequence : Integer;
            attribute latitude : Latitude;
            attribute longitude : Longitude;
            attribute altitude : Altitude;
            attribute cruiseSpeed : Speed;
            attribute loiterTime : Duration;
        }
        
        item MissionPlan {
            attribute planID : String;
            attribute waypoints : Waypoint[0..*] ordered;
            attribute uploadTime : Duration;
            attribute estimatedDuration : Duration;
        }
        
        item Telemetry {
            attribute latitude : Latitude;
            attribute longitude : Longitude;
            attribute altitude : Altitude;
            attribute speed : Speed;
            attribute heading : HeadingAngle;
            attribute batteryLevel : BatteryLevel;
            attribute healthStatus : String;
            attribute timestamp : Duration;
        }
        
        item Command {
            attribute commandType : String;
            attribute parameterValue : String;
            attribute timestamp : Duration;
        }
        
        item PowerSupply {
            attribute voltage : Voltage;
            attribute current : Current;
            attribute available : Boolean;
        }
        
        item ThrustCommand {
            attribute throttle : Percent;
            attribute rollControl : Percent;
            attribute pitchControl : Percent;
            attribute yawControl : Percent;
        }
    }
    
    package Ports {
        import Items::*;
        
        port def PowerOutPort {
            out supply : PowerSupply;
        }
        port def PowerInPort {
            in supply : PowerSupply;
        }
        port def GPSOutPort {
            out gpsData : GPSData;
        }
        port def GPSInPort {
            in gpsData : GPSData;
        }
        port def IMUOutPort {
            out imuData : IMUData;
        }
        port def IMUInPort {
            in imuData : IMUData;
        }
        port def LidarOutPort {
            out lidarData : LidarData;
        }
        port def LidarInPort {
            in lidarData : LidarData;
        }
        port def ImageOutPort {
            out image : CameraImage;
        }
        port def ThrustOutPort {
            out thrustCmd : ThrustCommand;
        }
        port def ThrustInPort {
            in thrustCmd : ThrustCommand;
        }
        port def TelemetryOutPort {
            out telemetry : Telemetry;
        }
        port def TelemetryInPort {
            in telemetry : Telemetry;
        }
        port def CommandOutPort {
            out command : Command;
        }
        port def CommandInPort {
            in command : Command;
        }
        port def MissionPlanOutPort {
            out plan : MissionPlan;
        }
        port def MissionPlanInPort {
            in plan : MissionPlan;
        }
    }
    
    package Subsystems {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        
        part def Battery {
            attribute capacity : Energy;
            attribute nominalVoltage : Voltage;
            attribute chargeLevel : BatteryLevel;
            attribute rechargeable : Boolean = true;
        }
        
        part def PowerSystem {
            attribute nominalVoltage : Voltage;
            attribute maxCurrent : Current;
            attribute powerAvailable : Boolean;
            part battery : Battery;
            port powerOut : PowerOutPort;
        }
        
        part def Motor {
            attribute maxThrust : Thrust;
            attribute currentThrottle : Percent;
            attribute speedRPM : Frequency;
        }
        
        part def Propeller {
            attribute diameter : Distance;
            attribute pitch : Distance;
        }
        
        part def PropulsionSystem {
            part motor : Motor;
            part propeller : Propeller;
            port thrustCmdIn : ThrustInPort;
            port powerIn : PowerInPort;
        }
        
        part def GPS {
            attribute updateRate : Frequency;
            attribute positionAccuracy : Distance;
            port dataOut : GPSOutPort;
            port powerIn : PowerInPort;
        }
        
        part def IMU {
            attribute updateRate : Frequency;
            attribute driftRate : Frequency;
            port dataOut : IMUOutPort;
            port powerIn : PowerInPort;
        }
        
        part def Camera {
            attribute resolution : Integer;
            attribute fieldOfView : HeadingAngle;
            attribute frameRate : Frequency;
            port imageOut : ImageOutPort;
            port powerIn : PowerInPort;
        }
        
        part def Lidar {
            attribute maxRange : Distance;
            attribute updateRate : Frequency;
            attribute angularResolution : HeadingAngle;
            port dataOut : LidarOutPort;
            port powerIn : PowerInPort;
        }
        
        part def SensorSuite {
            part gps : GPS;
            part imu : IMU;
            part camera : Camera;
            part lidar : Lidar;
        }
        
        part def NavigationSystem {
            attribute currentWaypointIndex : Integer;
            attribute totalWaypoints : Integer;
            attribute currentSpeed : Speed;
            attribute currentAltitude : Altitude;
            attribute missionPlan : MissionPlan;
            port missionPlanIn : MissionPlanInPort;
            port navDataOut : TelemetryOutPort;
            port gpsDataIn : GPSInPort;
            port imuDataIn : IMUInPort;
            port powerIn : PowerInPort;
        }
        
        part def CommunicationSystem {
            attribute linkFrequency : Frequency;
            attribute dataRate : DataRate;
            attribute linkActive : Boolean;
            port telemetryOut : TelemetryOutPort;
            port telemetryIn : TelemetryInPort;
            port commandIn : CommandInPort;
            port commandOut : CommandOutPort;
            port missionPlanIn : MissionPlanInPort;
            port missionPlanOut : MissionPlanOutPort;
            port powerIn : PowerInPort;
        }
        
        part def FlightController {
            attribute mode : String;
            attribute cruiseSpeed : Speed;
            attribute maxSafeAltitude : Altitude;
            attribute stabilizationActive : Boolean;
            port sensorGPSIn : GPSInPort;
            port sensorIMUIn : IMUInPort;
            port sensorLidarIn : LidarInPort;
            port navDataIn : TelemetryInPort;
            port commandIn : CommandInPort;
            port thrustCmdOut : ThrustOutPort;
            port telemetryOut : TelemetryOutPort;
            port powerIn : PowerInPort;
        }
    }
    
    package Systems {
        import Subsystems::*;
        
        part def UnmannedVehicle {
            attribute id : String;
            attribute maxSpeed : Speed;
            attribute mass : Mass;
            attribute endurance : Duration;
            attribute lowBatteryThreshold : BatteryLevel = 20;
            attribute criticalBatteryThreshold : BatteryLevel = 10;
            
            part powerSystem : PowerSystem;
            part propulsionSystem : PropulsionSystem;
            part sensorSuite : SensorSuite;
            part flightController : FlightController;
            part navigationSystem : NavigationSystem;
            part communicationSystem : CommunicationSystem;
            
            flow power2Propulsion : PowerSupply from powerSystem.powerOut to propulsionSystem.powerIn;
            flow power2GPS : PowerSupply from powerSystem.powerOut to sensorSuite.gps.powerIn;
            flow power2IMU : PowerSupply from powerSystem.powerOut to sensorSuite.imu.powerIn;
            flow power2Camera : PowerSupply from powerSystem.powerOut to sensorSuite.camera.powerIn;
            flow power2Lidar : PowerSupply from powerSystem.powerOut to sensorSuite.lidar.powerIn;
            flow power2FC : PowerSupply from powerSystem.powerOut to flightController.powerIn;
            flow power2Nav : PowerSupply from powerSystem.powerOut to navigationSystem.powerIn;
            flow power2Comm : PowerSupply from powerSystem.powerOut to communicationSystem.powerIn;
            
            flow gps2FC : GPSData from sensorSuite.gps.dataOut to flightController.sensorGPSIn;
            flow gps2Nav : GPSData from sensorSuite.gps.dataOut to navigationSystem.gpsDataIn;
            flow imu2FC : IMUData from sensorSuite.imu.dataOut to flightController.sensorIMUIn;
            flow imu2Nav : IMUData from sensorSuite.imu.dataOut to navigationSystem.imuDataIn;
            flow lidar2FC : LidarData from sensorSuite.lidar.dataOut to flightController.sensorLidarIn;
            
            flow nav2FC : Telemetry from navigationSystem.navDataOut to flightController.navDataIn;
            flow thrustCmd2Propulsion : ThrustCommand from flightController.thrustCmdOut to propulsionSystem.thrustCmdIn;
            flow fcTelemetry2Comm : Telemetry from flightController.telemetryOut to communicationSystem.telemetryIn;
            flow commCmd2FC : Command from communicationSystem.commandOut to flightController.commandIn;
            flow planComm2Nav : MissionPlan from communicationSystem.missionPlanOut to navigationSystem.missionPlanIn;
            
            state machine lifecycle {
                attribute missionPlanReceived : Boolean;
                attribute targetAltitudeReached : Boolean;
                attribute checksPassed : Boolean;
                attribute waypointReached : Boolean;
                attribute lastWaypointReached : Boolean;
                attribute arrivedAtBase : Boolean;
                attribute landed : Boolean;
                attribute criticalAlert : Boolean;
                attribute currentBattery : BatteryLevel;
                
                state Idle {
                    entry { /* Power systems standby, await mission plan */ }
                }
                state PreFlightCheck {
                    entry { /* Verify battery, sensor health, communication link */ }
                }
                state Takeoff {
                    entry { /* Engage propulsion to climb to cruise altitude */ }
                }
                state Transit {
                    entry { /* Activate obstacle avoidance using LIDAR */ }
                }
                state Surveillance {
                    entry { /* Capture imagery and collect sensor data at waypoint */ }
                }
                state ReturnToBase {
                    entry { /* Compute shortest safe route to launch point */ }
                }
                state Landing {
                    entry { /* Descend and touch down at base */ }
                }
                state Emergency {
                    entry { /* Prioritize safe landing on critical alert */ }
                }
                
                transition initial then Idle;
                transition from Idle to PreFlightCheck when missionPlanReceived == true;
                transition from PreFlightCheck to Takeoff when checksPassed == true;
                transition from PreFlightCheck to Idle when checksPassed == false;
                transition from Takeoff to Transit when targetAltitudeReached == true;
                transition from Transit to Surveillance when waypointReached == true;
                transition from Surveillance to Transit when lastWaypointReached == false;
                transition from Surveillance to ReturnToBase when lastWaypointReached == true;
                transition from Transit to ReturnToBase when lastWaypointReached == true;
                transition from ReturnToBase to Landing when arrivedAtBase == true;
                transition from Landing to Idle when landed == true;
                transition from Idle to Emergency when criticalAlert == true;
                transition from PreFlightCheck to Emergency when criticalAlert == true;
                transition from Takeoff to Emergency when criticalAlert == true;
                transition from Transit to Emergency when criticalAlert == true;
                transition from Surveillance to Emergency when criticalAlert == true;
                transition from ReturnToBase to Emergency when criticalAlert == true;
                transition from Emergency to Landing;
            }
        }
        
        part def GroundControlStation {
            attribute stationID : String;
            attribute operatorID : String;
            attribute location : String;
            attribute monitoringActive : Boolean;
            port commandOut : CommandOutPort;
            port missionPlanOut : MissionPlanOutPort;
            port telemetryIn : TelemetryInPort;
        }
        
        part def UAVSystem {
            attribute systemID : String;
            attribute operational : Boolean;
            
            part vehicle : UnmannedVehicle;
            part groundControl : GroundControlStation;
            
            flow telemetry2GCS : Telemetry from vehicle.communicationSystem.telemetryOut to groundControl.telemetryIn;
            flow command2Vehicle : Command from groundControl.commandOut to vehicle.communicationSystem.commandIn;
            flow plan2Vehicle : MissionPlan from groundControl.missionPlanOut to vehicle.communicationSystem.missionPlanIn;
        }
    }
    
    package Requirements {
        import Systems::*;
        import Subsystems::*;
        import Items::*;
        import ValueTypes::*;
        
        requirement def AutonomousMissionExecution {
            doc /* The UAV shall execute pre-planned missions without continuous human intervention. */;
            subject uav : UnmannedVehicle;
            attribute missionPlan : MissionPlan;
        }
        
        requirement def SensorBasedObstacleAvoidance {
            doc /* The UAV shall use onboard sensors including LIDAR to detect and avoid obstacles during transit. */;
            subject uav : UnmannedVehicle;
            subject lidar : Lidar;
        }
        
        requirement def EmergencyLandingCapability {
            doc /* The UAV shall initiate an emergency landing when critical issues such as low battery are detected. */;
            subject uav : UnmannedVehicle;
            attribute criticalThreshold : BatteryLevel = 10;
        }
        
        requirement def TelemetryStreaming {
            doc /* The communication system shall continuously stream telemetry including position, status, and sensor data to the ground control station. */;
            subject uav : UnmannedVehicle;
            subject gcs : GroundControlStation;
        }
        
        requirement def GroundControlMonitoring {
            doc /* The ground control station shall monitor the vehicle health and mission progress in real time. */;
            subject gcs : GroundControlStation;
        }
        
        requirement def BatteryRechargeability {
            doc /* The power system battery shall be rechargeable. */;
            subject battery : Battery;
        }
        
        requirement def MissionWaypointDefinition {
            doc /* A mission shall be defined by a series of waypoints with specific speeds and altitudes. */;
            subject missionPlan : MissionPlan;
        }
        
        requirement def FlightControllerModes {
            doc /* The flight controller shall operate in autonomous, manual, or return-to-base modes. */;
            subject fc : FlightController;
        }
        
        requirement def PropulsionThrustControl {
            doc /* The propulsion system shall generate thrust based on commands from the flight controller. */;
            subject propulsion : PropulsionSystem;
            subject fc : FlightController;
        }
        
        requirement def PowerDistributionToAllSubsystems {
            doc /* The power system shall supply electricity to all onboard components of the unmanned vehicle. */;
            subject power : PowerSystem;
            subject uav : UnmannedVehicle;
        }
    }
}
