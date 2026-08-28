package DeliveryDroneSystem {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    value type MassValue :> Mass;
    value type DistanceValue :> Length;
    value type SpeedValue :> Speed;
    value type AltitudeValue :> Length;
    value type BatteryLevel :> Real;
    value type Coordinate :> Real;

    // Items
    item def Package {
        attribute weight : MassValue;
    }
    item def TelemetryData {
        attribute position : Coordinate;
        attribute altitude : AltitudeValue;
        attribute speed : SpeedValue;
        attribute batteryLevel : BatteryLevel;
        attribute status : String;
    }
    item def MissionCommand {
        attribute destinationCoordinates : Coordinate;
        attribute package : Package;
    }
    item def GPSData {
        attribute latitude : Coordinate;
        attribute longitude : Coordinate;
        attribute altitude : AltitudeValue;
        attribute speed : SpeedValue;
    }
    item def ImageData;
    item def LidarData {
        attribute distance : DistanceValue;
    }
    item def MotorControlSignal;
    item def PayloadControlSignal;
    item def ElectricalPower;

    // Ports
    port def DataOutPort {
        out item data;
    }
    port def DataInPort {
        in item data;
    }
    port def PowerOutPort {
        out item power : ElectricalPower;
    }
    port def PowerInPort {
        in item power : ElectricalPower;
    }
    port def ControlOutPort {
        out item signal;
    }
    port def ControlInPort {
        in item signal;
    }

    // Requirements
    requirement def DroneRequirements {
        requirement PropulsionReq {
            doc /* The drone shall use a four-motor propulsion system. */
        }
        requirement PowerReq {
            doc /* The drone shall be powered by a high-capacity rechargeable battery pack. */
        }
        requirement NavigationReq {
            doc /* The drone shall use a high-precision GPS module for location, altitude, and speed. */
        }
        requirement PerceptionReq {
            doc /* The drone shall be equipped with a high-resolution camera and Lidar sensor for obstacle detection. */
        }
        requirement ControlReq {
            doc /* The drone shall have a central flight controller to process data, plan routes, stabilize flight, and execute missions. */
        }
        requirement CommunicationReq {
            doc /* The drone shall have a wireless module to transmit telemetry and receive mission commands. */
        }
        requirement PayloadReq {
            doc /* The drone shall securely carry a package up to 5 kg. */
            constraint { package.weight <= 5 [kg] }
        }
        requirement DeliveryMissionReq {
            doc /* The drone shall fly to destination, descend, release package, return to base, and land. */
        }
    }

    // Parts
    part def Motor {
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        attribute thrust : Real;
    }

    part def PropulsionSystem {
        port controlIn : ControlInPort;
        part motor1 : Motor;
        part motor2 : Motor;
        part motor3 : Motor;
        part motor4 : Motor;
        
        connect controlIn to motor1.controlIn;
        connect controlIn to motor2.controlIn;
        connect controlIn to motor3.controlIn;
        connect controlIn to motor4.controlIn;
    }

    part def BatteryPack {
        port powerOut : PowerOutPort;
        attribute capacity : Real;
        attribute level : BatteryLevel;
    }

    part def GPSModule {
        port dataOut : DataOutPort;
        item data : GPSData;
        attribute altitude : AltitudeValue;
        attribute atDestination : Boolean;
        attribute atBase : Boolean;
    }

    part def Camera {
        port dataOut : DataOutPort;
        item data : ImageData;
    }

    part def LidarSensor {
        port dataOut : DataOutPort;
        item data : LidarData;
    }

    part def WirelessModule {
        port telemetryOut : DataOutPort;
        port commandIn : DataInPort;
        item telemetry : TelemetryData;
        item command : MissionCommand;
        attribute commandReceived : Boolean;
    }

    part def PayloadBay {
        port packageIn : DataInPort;
        port controlIn : ControlInPort;
        attribute maxWeight : MassValue = 5 [kg];
        part package : Package;
        attribute packageReleased : Boolean;
        
        action def releasePackage {
            // release logic
        }
    }

    part def FlightController {
        port gpsIn : DataInPort;
        port cameraIn : DataInPort;
        port lidarIn : DataInPort;
        port commandIn : DataInPort;
        port telemetryOut : DataOutPort;
        port motorControlOut : ControlOutPort;
        port payloadControlOut : ControlOutPort;
        
        attribute currentRoute : Coordinate;
        attribute routePlanned : Boolean;
        
        action def processSensorData {
            in gpsData : GPSData;
            in imageData : ImageData;
            in lidarData : LidarData;
        }
        action def planRoute {
            in destination : Coordinate;
        }
        action def stabilizeFlight {
            // stabilization logic
        }
    }

    part def Drone :> DroneRequirements {
        port telemetryOut : DataOutPort;
        port commandIn : DataInPort;
        
        part battery : BatteryPack;
        part propulsion : PropulsionSystem;
        part gps : GPSModule;
        part camera : Camera;
        part lidar : LidarSensor;
        part wireless : WirelessModule;
        part payloadBay : PayloadBay;
        part controller : FlightController;
        
        // Connections
        connect battery.powerOut to propulsion.motor1.powerIn;
        connect battery.powerOut to propulsion.motor2.powerIn;
        connect battery.powerOut to propulsion.motor3.powerIn;
        connect battery.powerOut to propulsion.motor4.powerIn;
        
        connect gps.dataOut to controller.gpsIn;
        connect camera.dataOut to controller.cameraIn;
        connect lidar.dataOut to controller.lidarIn;
        
        connect wireless.commandIn to controller.commandIn;
        connect controller.telemetryOut to wireless.telemetryOut;
        
        connect controller.motorControlOut to propulsion.controlIn;
        connect controller.payloadControlOut to payloadBay.controlIn;
        
        // State Machine
        state def DroneMissionStateMachine {
            state Idle;
            state ReceivingCommand;
            state TakingOff;
            state FlyingToDestination;
            state Descending;
            state ReleasingPackage;
            state ReturningToBase;
            state Landing;
            
            transition from Idle to ReceivingCommand when wireless.commandReceived;
            transition from ReceivingCommand to TakingOff when controller.routePlanned;
            transition from TakingOff to FlyingToDestination when gps.altitude > 0 [m];
            transition from FlyingToDestination to Descending when gps.atDestination;
            transition from Descending to ReleasingPackage when gps.altitude == 0 [m];
            transition from ReleasingPackage to ReturningToBase when payloadBay.packageReleased;
            transition from ReturningToBase to Landing when gps.atBase;
            transition from Landing to Idle when gps.altitude == 0 [m];
        }
        
        // Requirement satisfaction
        satisfy PropulsionReq by propulsion;
        satisfy PowerReq by battery;
        satisfy NavigationReq by gps;
        satisfy PerceptionReq by camera, lidar;
        satisfy ControlReq by controller;
        satisfy CommunicationReq by wireless;
        satisfy PayloadReq by payloadBay;
        satisfy DeliveryMissionReq by DroneMissionStateMachine;
    }
}
