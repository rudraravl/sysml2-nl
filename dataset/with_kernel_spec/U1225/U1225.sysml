package AutonomousDeliveryDrone {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    
    attribute def SigStartMission;
    attribute def SigDestinationReached;
    attribute def SigReachedGround;
    attribute def SigPackageReleased;
    attribute def SigBaseReached;
    attribute def SigLanded;
    
    item def Position3D {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : Real;
    }
    
    item def TelemetryData {
        attribute position : Position3D;
        attribute batteryLevel : Real;
        attribute systemStatus : String;
    }
    
    item def MissionCommand {
        attribute targetPosition : Position3D;
    }
    
    item def VisualData;
    
    item def LidarScan {
        attribute distance : Real;
    }
    
    item def ThrottleCommand {
        attribute value : Real;
    }
    
    item def Electricity;
    
    item def DeliveryPackage {
        attribute mass : Real;
    }
    
    action def FuseSensorData;
    action def PlanRoute;
    action def ComputeStabilization;
    
    part def BatteryPack {
        attribute capacity : Real = 400;
        out port powerOut : Electricity;
        port statusOut {
            out attribute level : Real;
        }
    }
    
    part def Motor {
        in port powerIn : Electricity;
        port controlIn {
            in attribute command : ThrottleCommand;
        }
    }
    
    part def Propeller {
        attribute diameter : Real = 0.25;
    }
    
    part def GPSModule {
        port dataOut {
            out attribute position : Position3D;
            out attribute speed : Real;
        }
    }
    
    part def Camera {
        port dataOut {
            out attribute image : VisualData;
        }
    }
    
    part def LidarSensor {
        port dataOut {
            out attribute scan : LidarScan;
        }
    }
    
    part def WirelessModule {
        port telemetryIn {
            in attribute telemetry : TelemetryData;
        }
        port commandOut {
            out attribute command : MissionCommand;
        }
    }
    
    part def PayloadBay {
        attribute maxPayloadMass : Real = 5;
        port controlIn {
            in attribute release : Boolean;
        }
        item cargo : DeliveryPackage;
    }
    
    part def FlightController {
        port gpsIn {
            in attribute position : Position3D;
            in attribute speed : Real;
        }
        port cameraIn {
            in attribute image : VisualData;
        }
        port lidarIn {
            in attribute scan : LidarScan;
        }
        port batteryStatusIn {
            in attribute level : Real;
        }
        port missionIn {
            in attribute command : MissionCommand;
        }
        port motorControlOut[4] {
            out attribute command : ThrottleCommand;
        }
        port payloadControlOut {
            out attribute release : Boolean;
        }
        port telemetryOut {
            out attribute telemetry : TelemetryData;
        }
        
        perform action processMission {
            first start;
            then action fuseSensorData : FuseSensorData;
            then action planRoute : PlanRoute;
            then action computeStabilization : ComputeStabilization;
            then done;
        }
    }
    
    part def Drone {
        attribute totalMass : Real = 2.5;
        
        part battery : BatteryPack;
        part motors[4] : Motor;
        part propellers[4] : Propeller;
        part gps : GPSModule;
        part camera : Camera;
        part lidar : LidarSensor;
        part wireless : WirelessModule;
        part payloadBay : PayloadBay;
        part flightController : FlightController;
        
        connect battery.powerOut to motors.powerIn;
        connect gps.dataOut to flightController.gpsIn;
        connect camera.dataOut to flightController.cameraIn;
        connect lidar.dataOut to flightController.lidarIn;
        connect battery.statusOut to flightController.batteryStatusIn;
        connect wireless.commandOut to flightController.missionIn;
        connect flightController.motorControlOut to motors.controlIn;
        connect flightController.payloadControlOut to payloadBay.controlIn;
        connect flightController.telemetryOut to wireless.telemetryIn;
        
        state missionStateMachine {
            entry; then standby;
            state standby;
            accept SigStartMission then flyingToDestination;
            state flyingToDestination;
            accept SigDestinationReached then descending;
            state descending;
            accept SigReachedGround then releasingPackage;
            state releasingPackage;
            accept SigPackageReleased then returningToBase;
            state returningToBase;
            accept SigBaseReached then landing;
            state landing;
            accept SigLanded then standby;
        }
    }
    
    part deliveryDrone : Drone;
    
    requirement <'REQ-001'> autonomousOperation {
        doc /* The drone shall operate without direct human piloting. */
        subject deliveryDrone : Drone;
    }
    
    requirement <'REQ-002'> payloadCapacity {
        doc /* The payload bay shall securely carry a package up to 5 kg. */
        subject deliveryDrone : Drone;
        assert constraint {
            deliveryDrone.payloadBay.maxPayloadMass >= 5
        }
    }
    
    requirement <'REQ-003'> obstacleAvoidance {
        doc /* The drone shall detect and avoid obstacles using camera and Lidar. */
        subject deliveryDrone : Drone;
    }
    
    requirement <'REQ-004'> communication {
        doc /* The drone shall transmit telemetry and receive mission commands. */
        subject deliveryDrone : Drone;
    }
    
    satisfy autonomousOperation by deliveryDrone;
    satisfy payloadCapacity by deliveryDrone;
    satisfy obstacleAvoidance by deliveryDrone;
    satisfy communication by deliveryDrone;
}
