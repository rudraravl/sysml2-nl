package 'Unmanned Aerial Vehicle System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GPSCoordinates {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def Attitude {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def VehicleState {
        attribute position : GPSCoordinates;
        attribute attitude : Attitude;
        attribute velocity : SpeedValue;
        attribute batteryLevel : Real;
    }
    
    item def MissionPlan {
        attribute waypoints : GPSCoordinates[*];
        attribute missionType : String;
        attribute targetAltitude : LengthValue;
    }
    
    item def FlightCommand {
        attribute commandType : String;
        attribute targetPosition : GPSCoordinates;
        attribute targetSpeed : SpeedValue;
    }
    
    item def TelemetryData {
        attribute vehicleState : VehicleState;
        attribute timestamp : TimeValue;
        attribute systemHealth : String;
    }
    
    item def MotorControl {
        attribute motorSpeed : Real[4];
        attribute thrustVector : ForceValue[4];
    }
    
    item def SensorReading {
        attribute gpsData : GPSCoordinates;
        attribute imuData : Attitude;
        attribute obstacleDistance : LengthValue;
    }
    
    item def TakeoffCommand :> FlightCommand;
    item def AltitudeReached;
    item def WaypointReached;
    item def NextWaypoint;
    item def ReturnCommand :> FlightCommand;
    item def HomeReached;
    item def Touchdown;
    
    port def CommandPort {
        in item command : FlightCommand;
    }
    
    port def TelemetryPort {
        out item telemetry : TelemetryData;
    }
    
    port def SensorDataPort {
        out item sensorData : SensorReading;
    }
    
    port def MotorControlPort {
        in item motorControl : MotorControl;
    }
    
    port def CommunicationPort {
        in item missionPlan : MissionPlan;
        out item statusReport : TelemetryData;
    }
    
    part def FlightController {
        attribute currentState : VehicleState;
        attribute targetWaypoint : GPSCoordinates;
        
        port commandInput : CommandPort;
        port sensorInput : SensorDataPort;
        port motorOutput : MotorControlPort;
        port telemetryOutput : TelemetryPort;
        
        state flightControlState {
            entry; then standby;
            
            state standby;
            accept FlightCommand
            then preflight;
            
            state preflight {
                entry; then systemCheck;
                state systemCheck;
                then armed;
                state armed;
            }
            accept TakeoffCommand
            then active;
            
            state active {
                state takeoff;
                accept AltitudeReached
                then cruise;
                
                state cruise {
                    state navigating;
                    accept WaypointReached
                    then loitering;
                    
                    state loitering;
                    accept NextWaypoint
                    then navigating;
                }
                accept ReturnCommand
                then returning;
                
                state returning;
                accept HomeReached
                then landing;
            }
            
            state landing;
            accept Touchdown
            then standby;
        }
    }
    
    part def GPSReceiver {
        attribute accuracy : LengthValue;
        attribute currentPosition : GPSCoordinates;
        
        port dataOutput : SensorDataPort;
    }
    
    part def IMUSensor {
        attribute currentAttitude : Attitude;
        attribute angularVelocity : Real[3];
        
        port dataOutput : SensorDataPort;
    }
    
    part def ObstacleAvoidanceSensor {
        attribute detectionRange : LengthValue;
        attribute minSafeDistance : LengthValue;
        
        port dataOutput : SensorDataPort;
    }
    
    part def BrushlessMotor {
        attribute maxRPM : Real;
        attribute maxThrust : ForceValue;
        attribute efficiency : Real;
        
        port controlInput : MotorControlPort;
    }
    
    part def ElectronicSpeedController {
        attribute maxCurrent : Real;
        
        port motorCommand : MotorControlPort;
    }
    
    part def LithiumPolymerBattery {
        attribute capacity : Real;
        attribute voltage : Real;
        attribute currentCharge : Real;
        attribute dischargeCurrent : Real;
    }
    
    part def Propeller {
        attribute diameter : LengthValue;
        attribute pitch : LengthValue;
    }
    
    part def CarbonFiberAirframe {
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
    }
    
    part def RadioTransceiver {
        attribute frequency : Real;
        attribute range : LengthValue;
        attribute dataRate : Real;
        
        port groundLink : CommunicationPort;
    }
    
    part def PayloadCamera {
        attribute resolution : Integer[2];
        attribute frameRate : Real;
        attribute isRecording : Boolean;
    }
    
    part def UnmannedAerialVehicle {
        part flightController : FlightController;
        part gpsReceiver : GPSReceiver;
        part imuSensor : IMUSensor;
        part obstacleAvoidance : ObstacleAvoidanceSensor;
        part motor1 : BrushlessMotor;
        part motor2 : BrushlessMotor;
        part motor3 : BrushlessMotor;
        part motor4 : BrushlessMotor;
        part esc1 : ElectronicSpeedController;
        part esc2 : ElectronicSpeedController;
        part esc3 : ElectronicSpeedController;
        part esc4 : ElectronicSpeedController;
        part propeller1 : Propeller;
        part propeller2 : Propeller;
        part propeller3 : Propeller;
        part propeller4 : Propeller;
        part battery : LithiumPolymerBattery;
        part airframe : CarbonFiberAirframe;
        part radio : RadioTransceiver;
        part camera : PayloadCamera;
        
        port groundControlLink : CommunicationPort;
        
        connection gpsToController connect gpsReceiver.dataOutput to flightController.sensorInput;
        connection imuToController connect imuSensor.dataOutput to flightController.sensorInput;
        connection obstacleToController connect obstacleAvoidance.dataOutput to flightController.sensorInput;
        connection controllerToESC1 connect flightController.motorOutput to esc1.motorCommand;
        connection controllerToESC2 connect flightController.motorOutput to esc2.motorCommand;
        connection controllerToESC3 connect flightController.motorOutput to esc3.motorCommand;
        connection controllerToESC4 connect flightController.motorOutput to esc4.motorCommand;
        connection esc1ToMotor1 connect esc1.motorCommand to motor1.controlInput;
        connection esc2ToMotor2 connect esc2.motorCommand to motor2.controlInput;
        connection esc3ToMotor3 connect esc3.motorCommand to motor3.controlInput;
        connection esc4ToMotor4 connect esc4.motorCommand to motor4.controlInput;
        connection radioToGround connect radio.groundLink to groundControlLink;
    }
    
    action def InitializeMission {
        in missionPlan : MissionPlan;
        out systemReady : Boolean;
    }
    
    action def Takeoff {
        in targetAltitude : LengthValue;
        in currentPosition : GPSCoordinates;
        out climbComplete : Boolean;
        out reachedAltitude : LengthValue;
    }
    
    action def NavigateToWaypoint {
        in startPosition : GPSCoordinates;
        in targetWaypoint : GPSCoordinates;
        in cruiseSpeed : SpeedValue;
        out arrivalPosition : GPSCoordinates;
        out waypointReached : Boolean;
    }
    
    action def PerformSurveillance {
        in targetArea : GPSCoordinates;
        in loiterTime : TimeValue;
        out imageryCollected : Boolean;
    }
    
    action def AvoidObstacle {
        in obstacleDistance : LengthValue;
        in currentVelocity : SpeedValue;
        out avoidanceManeuver : MotorControl;
    }
    
    action def MonitorBatteryStatus {
        in currentCharge : Real;
        in dischargeRate : Real;
        out remainingFlightTime : TimeValue;
        out returnHomeRequired : Boolean;
    }
    
    action def ReturnToLaunchPoint {
        in currentPosition : GPSCoordinates;
        in launchPosition : GPSCoordinates;
        out returnPath : GPSCoordinates[*];
    }
    
    action def Land {
        in currentAltitude : LengthValue;
        in descentRate : SpeedValue;
        out touchdownComplete : Boolean;
    }
    
    action def TransmitTelemetry {
        in vehicleState : VehicleState;
        out transmissionSuccess : Boolean;
    }
    
    action def ExecuteAutonomousMission {
        in mission : MissionPlan;
        out missionSuccess : Boolean;
        
        first start;
        then action initialize : InitializeMission {
            in missionPlan = mission;
            out systemReady;
        }
        then action takeoff : Takeoff {
            in targetAltitude = mission.targetAltitude;
            out climbComplete;
            out reachedAltitude;
        }
        then merge waypointLoop;
        
        then action waypointLoop {
            first action monitorBattery : MonitorBatteryStatus {
                out remainingFlightTime;
                out returnHomeRequired;
            }
            then decide;
                if monitorBattery.returnHomeRequired then returnHome;
                if not monitorBattery.returnHomeRequired then continueWaypoints;
            
            then action continueWaypoints {
                first action navigate : NavigateToWaypoint {
                    in cruiseSpeed = 15.0[m/s];
                    out arrivalPosition;
                    out waypointReached;
                }
                then action surveillance : PerformSurveillance {
                    in targetArea = navigate.arrivalPosition;
                    in loiterTime = 60.0[s];
                    out imageryCollected;
                }
                then action transmit : TransmitTelemetry {
                    out transmissionSuccess;
                }
            }
            then waypointLoop;
            
            then action returnHome : ReturnToLaunchPoint {
                out returnPath;
            }
            then landAction;
        }
        
        then action landAction : Land {
            in descentRate = 1.0[m/s];
            out touchdownComplete;
        }
        then assign missionSuccess := landAction.touchdownComplete;
        then done;
    }
    
    requirement def <'UAV-REQ-001'> AutonomousNavigationRequirement {
        doc /* The UAV shall autonomously navigate to specified waypoints using GPS coordinates
               with a position accuracy of 2.5 meters or better. */
        
        subject uav : UnmannedAerialVehicle;
        
        require constraint {
            uav.gpsReceiver.accuracy <= 2.5[m]
        }
    }
    
    requirement def <'UAV-REQ-002'> ObstacleDetectionRequirement {
        doc /* The UAV shall detect obstacles within 15 meters and execute avoidance maneuvers
               to maintain a minimum safe distance of 5 meters. */
        
        subject uav : UnmannedAerialVehicle;
        
        require constraint {
            uav.obstacleAvoidance.detectionRange >= 15.0[m] and
            uav.obstacleAvoidance.minSafeDistance >= 5.0[m]
        }
    }
    
    requirement def <'UAV-REQ-003'> FlightEnduranceRequirement {
        doc /* The UAV shall maintain flight operations for a minimum of 30 minutes
               under nominal payload and environmental conditions. */
        
        subject uav : UnmannedAerialVehicle;
        
        require constraint {
            uav.battery.capacity >= 5000.0
        }
    }
    
    requirement def <'UAV-REQ-004'> CommunicationRangeRequirement {
        doc /* The UAV shall maintain reliable communication with the ground control station
               at ranges up to 10 kilometers. */
        
        subject uav : UnmannedAerialVehicle;
        
        require constraint {
            uav.radio.range >= 10000.0[m]
        }
    }
    
    requirement def <'UAV-REQ-005'> PayloadCapabilityRequirement {
        doc /* The UAV shall carry and operate a camera payload capable of capturing
               high-resolution imagery at 30 frames per second. */
        
        subject uav : UnmannedAerialVehicle;
        
        require constraint {
            uav.camera.frameRate >= 30.0
        }
    }
    
    requirement <'UAV-MISSION-001'> primaryMissionRequirement {
        doc /* The primary function of the UAV system is to autonomously execute reconnaissance
               and surveillance missions by navigating to predefined waypoints, collecting imagery
               of target areas, avoiding obstacles, monitoring system health, and safely returning
               to the launch point while maintaining continuous communication with ground control. */
        
        assume constraint {
            doc /* Mission waypoints are within operational range and environmental conditions
                   are within acceptable flight parameters. */
        }
        
        require autonomousNav : AutonomousNavigationRequirement;
        require obstacleDetection : ObstacleDetectionRequirement;
        require flightEndurance : FlightEnduranceRequirement;
        require commRange : CommunicationRangeRequirement;
        require payloadCap : PayloadCapabilityRequirement;
    }
    
    part quadcopterUAV : UnmannedAerialVehicle {
        part :>> airframe {
            attribute :>> mass = 1.2[kg];
            attribute :>> length = 0.45[m];
            attribute :>> width = 0.45[m];
        }
        part :>> battery {
            attribute :>> capacity = 5200.0;
            attribute :>> voltage = 14.8;
            attribute :>> currentCharge = 100.0;
        }
        part :>> gpsReceiver {
            attribute :>> accuracy = 2.0[m];
        }
        part :>> obstacleAvoidance {
            attribute :>> detectionRange = 20.0[m];
            attribute :>> minSafeDistance = 5.0[m];
        }
        part :>> radio {
            attribute :>> frequency = 2400.0;
            attribute :>> range = 12000.0[m];
            attribute :>> dataRate = 250000.0;
        }
        part :>> camera {
            attribute :>> resolution = (1920, 1080);
            attribute :>> frameRate = 30.0;
            attribute :>> isRecording = false;
        }
    }
}
