package UncrewedVehicleSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GPSCoordinate {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def MissionCommand {
        attribute commandType : String;
        attribute targetWaypoint : GPSCoordinate;
        attribute priority : Integer;
    }
    
    attribute def VehicleStatus {
        attribute position : GPSCoordinate;
        attribute velocity : SpeedValue;
        attribute heading : Real;
        attribute batteryLevel : Real;
        attribute systemHealth : String;
    }
    
    attribute def SensorReading {
        attribute obstacleDetected : Boolean;
        attribute obstacleDistance : LengthValue;
        attribute terrainType : String;
    }
    
    attribute def ControlCommand {
        attribute throttle : Real;
        attribute steering : Real;
        attribute braking : Real;
    }
    
    item def MissionPlan {
        attribute waypoints : GPSCoordinate[1..*] ordered;
        attribute missionType : String;
        attribute estimatedDuration : TimeValue;
    }
    
    item def TelemetryPacket {
        attribute timestamp : TimeValue;
        attribute vehicleStatus : VehicleStatus;
        attribute sensorData : SensorReading;
    }
    
    port def CommandPort {
        in item missionCmd : MissionCommand;
        out item statusReport : VehicleStatus;
    }
    
    port def SensorDataPort {
        out item sensorReading : SensorReading;
    }
    
    port def ControlPort {
        in item controlCmd : ControlCommand;
    }
    
    port def PowerPort {
        out attribute powerOutput : PowerValue;
    }
    
    port def TelemetryPort {
        out item telemetry : TelemetryPacket;
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute currentCharge : Real;
        attribute voltage : ElectricPotentialValue;
        
        port powerOut : PowerPort;
        
        action dischargeBattery {
            in powerDemand : PowerValue;
            out remainingCharge : Real;
        }
    }
    
    part def ElectricMotor {
        attribute maxPower : PowerValue;
        attribute efficiency : Real;
        
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        
        action generatePropulsion {
            in throttleCommand : Real;
            in powerAvailable : PowerValue;
            out propulsionForce : ForceValue;
        }
    }
    
    part def SteeringActuator {
        attribute maxSteeringAngle : Real;
        attribute responseTime : TimeValue;
        
        port controlIn : ControlPort;
        
        action adjustSteering {
            in steeringCommand : Real;
            out steeringAngle : Real;
        }
    }
    
    part def PropulsionSystem {
        part motor : ElectricMotor {
            maxPower = 5000.0 [W];
            efficiency = 0.85;
        }
        part steering : SteeringActuator {
            maxSteeringAngle = 45.0;
            responseTime = 0.2 [s];
        }
        
        port powerConnection : PowerPort;
        port controlInterface : ControlPort;
        
        connect powerConnection to motor.powerIn;
        connect controlInterface to motor.controlIn;
        connect controlInterface to steering.controlIn;
    }
    
    part def LidarSensor {
        attribute scanRange : LengthValue;
        attribute scanRate : FrequencyValue;
        attribute resolution : Real;
        
        port sensorOut : SensorDataPort;
        
        action scanEnvironment {
            out obstacleData : SensorReading;
        }
    }
    
    part def CameraSensor {
        attribute resolution : Integer;
        attribute frameRate : FrequencyValue;
        attribute fieldOfView : Real;
        
        action captureImage {
            out imageData;
        }
    }
    
    part def GPSReceiver {
        attribute accuracy : LengthValue;
        attribute updateRate : FrequencyValue;
        
        action determinePosition {
            out currentPosition : GPSCoordinate;
        }
    }
    
    part def SensorSuite {
        part lidar : LidarSensor {
            scanRange = 50.0 [m];
            scanRate = 10.0 [Hz];
            resolution = 0.1;
        }
        part camera : CameraSensor {
            resolution = 1920;
            frameRate = 30.0 [Hz];
            fieldOfView = 120.0;
        }
        part gps : GPSReceiver {
            accuracy = 2.0 [m];
            updateRate = 5.0 [Hz];
        }
        
        port sensorOutput : SensorDataPort;
    }
    
    part def NavigationComputer {
        attribute processingPower : Real;
        
        port commandIn : CommandPort;
        port sensorIn : SensorDataPort;
        port controlOut : ControlPort;
        
        action computeNavigation {
            in missionCmd : MissionCommand;
            in currentStatus : VehicleStatus;
            in sensorData : SensorReading;
            out navigationControl : ControlCommand;
        }
        
        action planPath {
            in startPosition : GPSCoordinate;
            in targetPosition : GPSCoordinate;
            in obstacles : SensorReading;
            out plannedPath : GPSCoordinate[*] ordered;
        }
    }
    
    part def CommunicationModule {
        attribute transmitPower : PowerValue;
        attribute frequency : FrequencyValue;
        attribute dataRate : Real;
        
        port commandInterface : CommandPort;
        port telemetryOut : TelemetryPort;
        
        action transmitTelemetry {
            in telemetryData : TelemetryPacket;
        }
        
        action receiveCommand {
            out receivedCommand : MissionCommand;
        }
    }
    
    part def AutonomousController {
        attribute autonomyLevel : Integer;
        
        action makeDecision {
            in currentState : VehicleStatus;
            in sensorInput : SensorReading;
            in missionObjective : MissionPlan;
            out decision : ControlCommand;
        }
        
        exhibit state vehicleStates {
            entry; then standby;
            
            state standby;
            accept missionReceived : MissionPlan
                then navigating;
            
            state navigating {
                do action executeNavigation {
                    in mission : MissionPlan;
                    in currentPos : GPSCoordinate;
                    out progress : Real;
                }
            }
            accept obstacleDetected : SensorReading
                then obstacleAvoidance;
            accept waypointReached
                then checkingMission;
            
            state obstacleAvoidance {
                do action avoidObstacle {
                    in obstacleData : SensorReading;
                    out evasiveManeuver : ControlCommand;
                }
            }
            accept obstacleClear
                then navigating;
            
            state checkingMission {
                do action updateMission;
            }
            accept moreWaypoints
                then navigating;
            accept finalWaypoint
                then missionComplete;
            
            state missionComplete {
                do action reportCompletion;
            }
            then returningToBase;
            
            state returningToBase {
                do action navigateHome {
                    out homePosition : GPSCoordinate;
                }
            }
            then standby;
            
            accept emergencyStop then emergency;
            
            state emergency {
                do action executeEmergencyStop;
            }
            then standby;
        }
    }
    
    part uncrewedVehicle {
        attribute vehicleMass : MassValue = 150.0 [kg];
        attribute maxSpeed : SpeedValue = 15.0 [m/s];
        attribute maxRange : LengthValue = 50.0 [km];
        attribute operatingTemperatureRange : Real = 40.0;
        
        part battery : BatteryPack {
            capacity = 10.0 [kW*h];
            currentCharge = 1.0;
            voltage = 48.0 [V];
        }
        
        part propulsion : PropulsionSystem;
        part sensors : SensorSuite;
        part navigation : NavigationComputer {
            processingPower = 100.0;
        }
        part communications : CommunicationModule {
            transmitPower = 10.0 [W];
            frequency = 2.4e9 [Hz];
            dataRate = 1.0e6;
        }
        part controller : AutonomousController {
            autonomyLevel = 4;
        }
        
        connect battery.powerOut to propulsion.powerConnection;
        connect sensors.sensorOutput to navigation.sensorIn;
        connect navigation.controlOut to propulsion.controlInterface;
        connect communications.commandInterface to navigation.commandIn;
    }
    
    action def ExecuteAutonomousMission {
        in assignedMission : MissionPlan;
        out missionResult : VehicleStatus;
        
        first start;
        then merge missionLoop;
        
        then action receiveMissionPlan {
            in mission : MissionPlan;
            out activeMission : MissionPlan;
        }
        
        then action initializeSystems {
            out systemsReady : Boolean;
        }
        
        then action navigateToNextWaypoint {
            in waypoint : GPSCoordinate;
            in currentPosition : GPSCoordinate;
            out newPosition : GPSCoordinate;
        }
        
        then action monitorEnvironment {
            out environmentData : SensorReading;
        }
        
        then action assessSituation {
            in sensorData : SensorReading;
            in vehicleState : VehicleStatus;
            out threatLevel : Integer;
        }
        
        then decide;
            if assessSituation.threatLevel > 5 then executeAvoidance;
            if assessSituation.threatLevel <= 5 then continueNavigation;
        
        action executeAvoidance {
            in threat : SensorReading;
            out avoidanceManeuver : ControlCommand;
        }
        then continueNavigation;
        
        action continueNavigation {
            out navigationProgress : Real;
        }
        
        then action updateTelemetry {
            in currentState : VehicleStatus;
            out telemetryUpdate : TelemetryPacket;
        }
        
        then decide;
            if continueNavigation.navigationProgress < 100.0 then missionLoop;
            if continueNavigation.navigationProgress >= 100.0 then finalizeMission;
        
        action finalizeMission {
            out finalStatus : VehicleStatus;
        }
        
        then done;
    }
    
    requirement def AutonomousOperationRequirement {
        doc /* The uncrewed vehicle shall operate autonomously to execute assigned missions 
                without human intervention. */
        
        subject vehicle : uncrewedVehicle;
        
        require constraint {
            doc /* Vehicle shall navigate to specified waypoints autonomously. */
        }
        
        require constraint {
            doc /* Vehicle shall detect and avoid obstacles in real-time. */
        }
        
        require constraint {
            doc /* Vehicle shall maintain continuous communication with ground control. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The uncrewed vehicle shall meet specified performance criteria for mission execution. */
        
        subject vehicle : uncrewedVehicle;
        
        require constraint {
            vehicle.maxSpeed >= 10.0 [m/s]
        }
        
        require constraint {
            vehicle.maxRange >= 30.0 [km]
        }
        
        require constraint {
            vehicle.battery.currentCharge >= 0.15
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The uncrewed vehicle shall operate safely under all operational conditions. */
        
        subject vehicle : uncrewedVehicle;
        
        require constraint {
            doc /* Vehicle shall execute emergency stop within 3 seconds of command. */
        }
        
        require constraint {
            doc /* Vehicle shall maintain minimum safe distance of 2 meters from obstacles. */
        }
        
        require constraint {
            doc /* Vehicle shall return to base autonomously if battery level falls below 20%. */
        }
    }
    
    requirement vehicleSystemRequirement : AutonomousOperationRequirement {
        doc /* Top-level requirement for uncrewed vehicle autonomous operation capability. */
        
        assume constraint {
            doc /* Mission plans are valid and achievable within vehicle capabilities. */
        }
        
        assume constraint {
            doc /* Communication link with ground control is available. */
        }
        
        require performanceReq : PerformanceRequirement;
        require safetyReq : SafetyRequirement;
    }
    
    action primaryMissionFunction : ExecuteAutonomousMission {
        doc /* 
        Primary Function: The uncrewed vehicle system autonomously executes assigned missions
        by navigating to specified waypoints, continuously monitoring its environment through
        onboard sensors, detecting and avoiding obstacles, maintaining communication with
        ground control, and managing onboard power resources to ensure mission completion
        and safe return to base.
        */
        
        in missionAssignment : MissionPlan {
            attribute waypoints = (
                GPSCoordinate(latitude = 37.7749, longitude = -122.4194, altitude = 0.0[m]),
                GPSCoordinate(latitude = 37.7849, longitude = -122.4094, altitude = 0.0[m]),
                GPSCoordinate(latitude = 37.7949, longitude = -122.3994, altitude = 0.0[m])
            );
            attribute missionType = "reconnaissance";
            attribute estimatedDuration = 1800.0 [s];
        }
        
        out missionOutcome : VehicleStatus;
    }
}
