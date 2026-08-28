package AutomatedHighwaySystem {
    import ScalarValues::*;

    // ---- Units ----
    unit def km_per_h;
    unit def meter;
    unit def degree;
    unit def millisecond;

    // ---- Value Types ----
    value def SpeedValue :> Real { unit km_per_h; }
    value def DistanceValue :> Real { unit meter; }
    value def HeadingValue :> Real { unit degree; }
    value def LatencyValue :> Real { unit millisecond; }
    value def VisibilityValue :> Real { unit meter; }
    value def RiskLevel :> Integer;

    // ---- Item Definitions ----
    item def VehicleStatus {
        attribute vehicleId : String;
        attribute positionX : DistanceValue;
        attribute positionY : DistanceValue;
        attribute speed : SpeedValue;
        attribute heading : HeadingValue;
        attribute lane : Integer;
    }

    item def RoadCondition {
        attribute roadFriction : Real;
        attribute visibility : VisibilityValue;
        attribute laneClosure : Boolean = false;
    }

    item def TrafficData {
        attribute vehicles : VehicleStatus[0..*];
        attribute roadCondition : RoadCondition;
        attribute timestamp : String;
    }

    item def DrivingCommand {
        attribute vehicleId : String;
        attribute targetSpeed : SpeedValue;
        attribute targetLane : Integer;
        attribute targetSpacing : DistanceValue;
        attribute emergencyBrake : Boolean = false;
    }

    item def EmergencyAlert {
        attribute alertId : String;
        attribute severity : RiskLevel = 0;
        attribute affectedVehicles : String[0..*];
        attribute description : String;
    }

    // ---- Port Definitions ----
    port def VehicleCommPort {
        out item status : VehicleStatus;
        in item command : DrivingCommand;
    }

    port def SensorDataPort {
        out item trafficData : TrafficData;
    }

    port def ControllerPort {
        in item trafficData : TrafficData;
        in item vehicleStatus : VehicleStatus;
        out item command : DrivingCommand;
        in item alert : EmergencyAlert;
    }

    port def SafetyPort {
        in item trafficData : TrafficData;
        out item emergencyCommand : DrivingCommand;
        out item alert : EmergencyAlert;
    }

    port def CommVehiclePort {
        in item status : VehicleStatus;
        out item command : DrivingCommand;
    }

    port def CommControllerPort {
        out item vehicleStatus : VehicleStatus;
        in item command : DrivingCommand;
    }

    port def CommSafetyPort {
        in item emergencyCommand : DrivingCommand;
    }

    // ---- Part Definitions ----
    part def ConnectedVehicle {
        doc "Level 4 automated car equipped to communicate with highway infrastructure.";
        attribute vehicleId : String;
        attribute automationLevel : Integer = 4;
        port commPort : VehicleCommPort;

        attribute currentSpeed : SpeedValue;
        attribute currentLane : Integer;
        attribute currentSpacing : DistanceValue;
        attribute onManagedHighway : Boolean = false;

        state vehicleControl {
            initial; then manual;
            state manual {
                doc "Driver has full control of the vehicle.";
            }
            state automated {
                doc "Central system controls speed, lane, and spacing.";
            }
            transition manual_to_automated
                from manual to automated
                when onManagedHighway == true;
            transition automated_to_manual
                from automated to manual
                when onManagedHighway == false;
        }

        action reportStatus {
            out report : VehicleStatus;
        }

        action executeCommand {
            in cmd : DrivingCommand;
        }
    }

    part def RoadwaySensor {
        doc "Network sensor monitoring traffic conditions in real time.";
        attribute sensorId : String;
        attribute location : String;
        port sensorDataPort : SensorDataPort;

        action scanHighway {
            out data : TrafficData;
        }
    }

    part def CommunicationNode {
        doc "Wireless communication backbone relaying data between controller and vehicles.";
        attribute nodeId : String;
        attribute maxLatency : LatencyValue = 50;
        port commVehiclePort : CommVehiclePort;
        port commControllerPort : CommControllerPort;
        port commSafetyPort : CommSafetyPort;

        action relayCommands {
            in cmd : DrivingCommand;
            out forwarded : DrivingCommand;
        }

        action relayStatus {
            in stat : VehicleStatus;
            out forwarded : VehicleStatus;
        }
    }

    part def CentralTrafficController {
        doc "Central brain aggregating sensor data and computing optimal traffic flow.";
        port controllerPort : ControllerPort;

        attribute systemMode : String;
        attribute defaultSpeed : SpeedValue = 100;
        attribute defaultSpacing : DistanceValue = 30;
        attribute reducedSpeed : SpeedValue = 60;
        attribute reducedSpacing : DistanceValue = 60;

        state controllerMode {
            initial; then normal;
            state normal {
                doc "Optimal conditions; maximize throughput with standard speed and spacing.";
            }
            state reducedCapacity {
                doc "Bad weather; lower speed limits and increase spacing.";
            }
            state safe {
                doc "Critical failure; manage safety overrides.";
            }
            transition normal_to_reduced
                from normal to reducedCapacity
                when controllerPort.trafficData.roadCondition.visibility < 500;
            transition reduced_to_normal
                from reducedCapacity to normal
                when controllerPort.trafficData.roadCondition.visibility >= 500;
            transition normal_to_safe
                from normal to safe
                when controllerPort.alert.severity > 5;
            transition reduced_to_safe
                from reducedCapacity to safe
                when controllerPort.alert.severity > 5;
            transition safe_to_normal
                from safe to normal
                when controllerPort.alert.severity <= 5;
        }

        action computeOptimalFlow {
            in data : TrafficData;
            in status : VehicleStatus;
            out commands : DrivingCommand[0..*];
        }

        action generateCommands {
            in targetSpeed : SpeedValue;
            in targetSpacing : DistanceValue;
            out commands : DrivingCommand[0..*];
        }
    }

    part def SafetyManagementSystem {
        doc "Dedicated safety monitor evaluating data to detect and prevent hazards.";
        port safetyPort : SafetyPort;

        attribute riskThreshold : RiskLevel = 3;
        attribute minSafeSpacing : DistanceValue = 10;
        attribute maxSafeSpeed : SpeedValue = 120;

        action evaluateRisk {
            in data : TrafficData;
            out alert : EmergencyAlert;
            out emergencyCommand : DrivingCommand;
        }

        action detectFollowingTooClose {
            in data : TrafficData;
            out riskDetected : Boolean;
        }

        action detectUnsafeSpeed {
            in data : TrafficData;
            out riskDetected : Boolean;
        }

        action issueEmergencyBrake {
            in vehicleId : String;
            out command : DrivingCommand;
        }
    }

    // ---- System Definition ----
    part def AutomatedHighwaySystem {
        doc "Comprehensive Automated Highway System managing connected autonomous vehicles on a dedicated roadway.";

        part vehicles : ConnectedVehicle[0..*];
        part sensors : RoadwaySensor[0..*];
        part commNodes : CommunicationNode[0..*];
        part controller : CentralTrafficController;
        part safetySystem : SafetyManagementSystem;

        connection vehicleToComm connect vehicles.commPort to commNodes.commVehiclePort;
        connection commToController connect commNodes.commControllerPort to controller.controllerPort;
        connection sensorToController connect sensors.sensorDataPort to controller.controllerPort;
        connection sensorToSafety connect sensors.sensorDataPort to safetySystem.safetyPort;
        connection safetyToController connect safetySystem.safetyPort to controller.controllerPort;
        connection safetyToComm connect safetySystem.safetyPort to commNodes.commSafetyPort;

        action continuousOperationLoop {
            action sense {
                out data : TrafficData;
            }
            action compute {
                in data : TrafficData;
                out commands : DrivingCommand[0..*];
            }
            action evaluate {
                in data : TrafficData;
                out emergencyCommands : DrivingCommand[0..*];
                out alerts : EmergencyAlert[0..*];
            }
            action command {
                in commands : DrivingCommand[0..*];
                in emergencyCommands : DrivingCommand[0..*];
            }

            succession from sense to compute;
            succession from sense to evaluate;
            succession from compute to command;
            succession from evaluate to command;
            succession from command to sense;
        }
    }

    // ---- Requirements ----
    requirement def SystemGoal {
        subject system : AutomatedHighwaySystem;
        objective {
            doc "The system shall increase traffic capacity and enhance safety by centrally coordinating vehicle movements on a dedicated roadway.";
        }
    }

    requirement def VehicleCommunication {
        subject vehicle : ConnectedVehicle;
        objective {
            doc "Connected vehicles shall be Level 4 automated cars equipped to communicate with highway infrastructure, receive and execute commands for speed, lane changes, and spacing, and continuously report position, speed, and heading.";
        }
    }

    requirement def SensorMonitoring {
        subject sensors : RoadwaySensor[0..*];
        objective {
            doc "Roadway sensors shall monitor traffic conditions in real time, gathering data on vehicle positions, speed, road conditions, and visibility to provide a complete picture of the current traffic situation.";
        }
    }

    requirement def CommunicationBackbone {
        subject comm : CommunicationNode[0..*];
        objective {
            doc "Communication nodes shall act as the wireless communication backbone, relaying information between central controllers and vehicles with low-latency transmission of control commands and status updates.";
        }
    }

    requirement def CentralControl {
        subject controller : CentralTrafficController;
        objective {
            doc "The central traffic controller shall aggregate data from all roadway sensors, analyze overall traffic flow, compute optimal speed and spacing for all vehicles to prevent congestion and maximize throughput, and send specific driving instructions to each vehicle.";
        }
    }

    requirement def SafetyMonitoring {
        subject safety : SafetyManagementSystem;
        objective {
            doc "The safety management system shall constantly evaluate data from sensors and vehicles to detect hazardous situations such as vehicles following too closely or unsafe speeds, and shall issue emergency alerts and commands to affected vehicles to prevent accidents.";
        }
    }

    requirement def EmergencyOverride {
        subject safety : SafetyManagementSystem;
        subject controller : CentralTrafficController;
        objective {
            doc "If the safety system detects a risk, it shall override the controller and issue emergency instructions, including commanding a vehicle to brake.";
        }
    }

    requirement def ContinuousLoop {
        subject system : AutomatedHighwaySystem;
        objective {
            doc "The system shall function in a continuous loop: sensors scan the highway, data is sent to the controller and safety system, the controller calculates ideal traffic flow and sends normal driving commands, and the safety system can override with emergency instructions.";
        }
    }

    requirement def SystemModes {
        subject system : AutomatedHighwaySystem;
        objective {
            doc "The system shall operate in a normal mode for optimal conditions, a reduced capacity mode that lowers speed limits and increases spacing during bad weather, and a safe mode to manage critical failures.";
        }
    }

    requirement def VehicleModes {
        subject vehicle : ConnectedVehicle;
        objective {
            doc "Individual vehicles shall transition between manual driver control and automated control when entering or exiting the system-managed highway segment.";
        }
    }

    requirement def WeatherAdaptation {
        subject controller : CentralTrafficController;
        objective {
            doc "In reduced capacity mode, the controller shall lower speed limits and increase vehicle spacing during bad weather conditions.";
        }
    }

    requirement def SafeModeManagement {
        subject controller : CentralTrafficController;
        objective {
            doc "In safe mode, the controller shall manage critical failures to maintain safety of all vehicles on the managed highway.";
        }
    }

    requirement def LowLatencyTransmission {
        subject comm : CommunicationNode;
        attribute maxLatency : LatencyValue = 50;
        objective {
            doc "Communication nodes shall transmit control commands and status updates with latency not exceeding maxLatency.";
        }
    }

    requirement def HazardDetection {
        subject safety : SafetyManagementSystem;
        objective {
            doc "The safety system shall detect vehicles following too closely and unsafe speeds for current road conditions.";
        }
    }

    requirement def ThroughputOptimization {
        subject controller : CentralTrafficController;
        objective {
            doc "The controller shall compute optimal speed and spacing for all vehicles to maximize throughput and prevent congestion.";
        }
    }

    // ---- Requirement Group ----
    requirement def AHSRequirements {
        requirement goal : SystemGoal;
        requirement vehicleComm : VehicleCommunication;
        requirement sensorMon : SensorMonitoring;
        requirement commBackbone : CommunicationBackbone;
        requirement centralCtrl : CentralControl;
        requirement safetyMon : SafetyMonitoring;
        requirement emergencyOverride : EmergencyOverride;
        requirement continuousLoop : ContinuousLoop;
        requirement sysModes : SystemModes;
        requirement vehicleModes : VehicleModes;
        requirement weatherAdapt : WeatherAdaptation;
        requirement safeMode : SafeModeManagement;
        requirement lowLatency : LowLatencyTransmission;
        requirement hazardDetect : HazardDetection;
        requirement throughputOpt : ThroughputOptimization;
    }
}
