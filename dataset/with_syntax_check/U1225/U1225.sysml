package 'Technological Convergence - Autonomous Delivery Drone' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def Latitude :> Real;
    attribute def Longitude :> Real;
    attribute def Altitude :> ISQ::LengthValue;
    attribute def Confidence :> Real;
    attribute def DataRate :> ISQ::FrequencyValue;
    attribute def SignalStrength :> Real;
    attribute def BatteryPercentage :> Real;

    item def NavigationData {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute altitude : Altitude;
        attribute timestamp : String;
    }

    item def ImageData {
        attribute resolution : Integer;
        attribute format : String;
        attribute timestamp : String;
    }

    item def ObstacleData {
        attribute distance : ISQ::LengthValue;
        attribute bearing : Real;
        attribute classification : String;
    }

    item def FlightCommand {
        attribute targetLatitude : Latitude;
        attribute targetLongitude : Longitude;
        attribute targetAltitude : Altitude;
        attribute speed : ISQ::SpeedValue;
    }

    item def PackageItem {
        attribute weight : ISQ::MassValue;
        attribute dimensions : String;
        attribute deliveryId : String;
    }

    item def TelemetryData {
        attribute position : NavigationData;
        attribute batteryLevel : BatteryPercentage;
        attribute systemStatus : String;
    }

    port def NavigationPort {
        out navData : NavigationData;
    }

    port def SensorPort {
        out obstacleData : ObstacleData;
        out imageData : ImageData;
    }

    port def CommunicationPort {
        attribute signalStrength : SignalStrength;
    }

    port def PowerPort {
        out power : ISQ::PowerValue;
    }

    port def ControlPort;

    part def GPSModule {
        attribute accuracy : ISQ::LengthValue;
        attribute updateRate : ISQ::FrequencyValue;
        port navOutput : NavigationPort;

        action acquirePosition {
            out position : NavigationData;
        }
    }

    part def VisionSystem {
        attribute cameraResolution : Integer;
        attribute fieldOfView : Real;
        port sensorOutput : SensorPort;

        action captureImage {
            out image : ImageData;
        }

        action detectObstacles {
            in image : ImageData;
            out obstacles : ObstacleData;
        }
    }

    part def LidarSensor {
        attribute range : ISQ::LengthValue;
        attribute scanRate : ISQ::FrequencyValue;
        port sensorOutput : SensorPort;

        action scanEnvironment {
            out obstacles : ObstacleData;
        }
    }

    part def WirelessCommunicationModule {
        attribute frequency : ISQ::FrequencyValue;
        attribute bandwidth : DataRate;
        port commPort : CommunicationPort;

        action transmitTelemetry {
            in telemetry : TelemetryData;
            out success : Boolean;
        }

        action receiveCommands {
            out command : FlightCommand;
        }
    }

    part def FlightController {
        attribute processorSpeed : ISQ::FrequencyValue;
        attribute memoryCapacity : Integer;
        port controlInput : ControlPort;

        action computeFlightPath {
            in currentPosition : NavigationData;
            in targetPosition : NavigationData;
            in obstacles : ObstacleData;
            out flightCommand : FlightCommand;
        }

        action stabilizeFlight {
            in sensorData : NavigationData;
            out motorCommands : String;
        }
    }

    part def PropulsionSystem {
        attribute numberOfMotors : Integer;
        attribute maxThrust : ISQ::ForceValue;
        port powerInput : PowerPort;
        port controlInput : ControlPort;

        action generateThrust {
            in motorCommand : String;
            in power : ISQ::PowerValue;
            out thrust : ISQ::ForceValue;
        }
    }

    part def BatteryPack {
        attribute capacity : ISQ::EnergyValue;
        attribute currentCharge : BatteryPercentage;
        port powerOutput : PowerPort;

        action supplyPower {
            out power : ISQ::PowerValue;
        }

        action monitorCharge {
            out chargeLevel : BatteryPercentage;
        }
    }

    part def PayloadBay {
        attribute maxCapacity : ISQ::MassValue;
        attribute currentLoad : PackageItem;

        action securePackage {
            in package : PackageItem;
            out secured : Boolean;
        }

        action releasePackage {
            out package : PackageItem;
            out released : Boolean;
        }
    }

    action def AcquireNavigationData {
        out navData : NavigationData;
    }

    action def SenseEnvironment {
        out obstacles : ObstacleData;
        out visualData : ImageData;
    }

    action def PlanFlightPath {
        in currentPosition : NavigationData;
        in destination : NavigationData;
        in obstacles : ObstacleData;
        out flightPlan : FlightCommand;
    }

    action def ExecuteFlight {
        in flightPlan : FlightCommand;
        in power : ISQ::PowerValue;
        out flightStatus : String;
    }

    action def CommunicateStatus {
        in telemetry : TelemetryData;
        out transmissionSuccess : Boolean;
    }

    action def DeliverPackage {
        in package : PackageItem;
        in destination : NavigationData;
        out deliveryStatus : String;
    }

    part def AutonomousDeliveryDrone {
        attribute droneId : String;
        attribute maxRange : ISQ::LengthValue;
        attribute maxPayload : ISQ::MassValue;

        part gps : GPSModule {
            attribute accuracy = 2.5 [SI::m];
            attribute updateRate = 10.0 [SI::Hz];
        }

        part camera : VisionSystem {
            attribute cameraResolution = 4096;
            attribute fieldOfView = 120.0;
        }

        part lidar : LidarSensor {
            attribute range = 100.0 [SI::m];
            attribute scanRate = 20.0 [SI::Hz];
        }

        part wireless : WirelessCommunicationModule {
            attribute frequency = 2.4 [SI::GHz];
        }

        part flightController : FlightController {
            attribute processorSpeed = 2.5 [SI::GHz];
            attribute memoryCapacity = 8192;
        }

        part propulsion : PropulsionSystem {
            attribute numberOfMotors = 4;
            attribute maxThrust = 50.0 [SI::N];
        }

        part battery : BatteryPack {
            attribute capacity = 5000.0 [SI::Wh];
            attribute currentCharge = 100.0;
        }

        part payload : PayloadBay {
            attribute maxCapacity = 5.0 [SI::kg];
        }

        connection gpsToController connect gps.navOutput to flightController.controlInput;
        connection cameraToController connect camera.sensorOutput to flightController.controlInput;
        connection lidarToController connect lidar.sensorOutput to flightController.controlInput;
        connection wirelessToController connect wireless.commPort to flightController.controlInput;
        connection batteryToPropulsion connect battery.powerOutput to propulsion.powerInput;
        connection controllerToPropulsion connect flightController.controlInput to propulsion.controlInput;

        perform action executeDeliveryMission;
    }

    action executeDeliveryMission {
        first start;
        then action loadPackage {
            out loaded : Boolean;
        }
        then merge missionLoop;

        action missionLoop {
            first action acquireNav : AcquireNavigationData {
                out navData : NavigationData;
            }
            then action senseEnv : SenseEnvironment {
                out obstacles : ObstacleData;
                out visualData : ImageData;
            }
            then action planPath : PlanFlightPath {
                in currentPosition = acquireNav.navData;
                in destination : NavigationData;
                in obstacles = senseEnv.obstacles;
                out flightPlan : FlightCommand;
            }
            then action executeFlight : ExecuteFlight {
                in flightPlan = planPath.flightPlan;
                in power : ISQ::PowerValue;
                out flightStatus : String;
            }
            then action communicateStatus : CommunicateStatus {
                in telemetry : TelemetryData;
                out transmissionSuccess : Boolean;
            }
            then decide;

            if executeFlight.flightStatus == "destination_reached" then deliverPackage;
            if executeFlight.flightStatus != "destination_reached" then missionLoop;

            action deliverPackage : DeliverPackage {
                in package : PackageItem;
                in destination : NavigationData;
                out deliveryStatus : String;
            }
            then returnToBase;

            action returnToBase {
                out returnStatus : String;
            }
            then done;
        }
    }

    state machine DroneOperationalStateMachine {
        initial state idle;
        state preflight;
        state inFlight;
        state delivering;
        state returning;
        state landed;

        transition idleToPreflight
            first idle
            accept missionCommand : FlightCommand
            then preflight;

        transition preflightToInFlight
            first preflight
            then inFlight;

        state inFlight {
            entry action {
                perform executeDeliveryMission;
            }
        }

        transition inFlightToDelivering
            first inFlight
            then delivering;

        transition deliveringToReturning
            first delivering
            then returning;

        transition returningToLanded
            first returning
            then landed;

        transition landedToIdle
            first landed
            then idle;
    }

    requirement def ConvergenceRequirement {
        doc /* The system shall integrate multiple independent technologies into a unified autonomous platform. */

        subject drone : AutonomousDeliveryDrone;

        require constraint hasNavigation {
            drone.gps != null
        }

        require constraint hasVision {
            drone.camera != null
        }

        require constraint hasRanging {
            drone.lidar != null
        }

        require constraint hasCommunication {
            drone.wireless != null
        }

        require constraint hasAutonomy {
            drone.flightController != null
        }

        require constraint hasPropulsion {
            drone.propulsion != null
        }
    }

    requirement def AutonomousDeliveryRequirement {
        doc /* The system shall autonomously navigate to a destination and deliver a package without human intervention. */

        subject drone : AutonomousDeliveryDrone;

        require constraint canNavigate {
            drone.gps.accuracy <= 5.0 [SI::m]
        }

        require constraint canAvoidObstacles {
            drone.lidar.range >= 50.0 [SI::m]
        }

        require constraint canCarryPayload {
            drone.payload.maxCapacity >= 2.0 [SI::kg]
        }

        require constraint hasSufficientRange {
            drone.maxRange >= 10.0 [SI::km]
        }
    }

    requirement def SafetyRequirement {
        doc /* The system shall operate safely in populated areas with obstacle detection and avoidance. */

        subject drone : AutonomousDeliveryDrone;

        require constraint hasRedundantSensing {
            drone.camera != null and drone.lidar != null
        }

        require constraint maintainsCommunication {
            drone.wireless != null
        }

        require constraint hasEmergencyPower {
            drone.battery.currentCharge >= 20.0
        }
    }

    requirement <'CONV-DRONE-001'> primaryConvergenceRequirement {
        doc /* The autonomous delivery drone shall integrate GPS navigation, computer vision, 
               wireless communication, autonomous flight control, and payload delivery into a 
               single system capable of autonomous package delivery. */

        assume constraint operationalEnvironment {
            doc /* System operates in urban and suburban environments with wireless coverage. */
        }

        require convergenceReq : ConvergenceRequirement;
        require deliveryReq : AutonomousDeliveryRequirement;
        require safetyReq : SafetyRequirement;
    }

    part deliveryDrone : AutonomousDeliveryDrone {
        attribute droneId = "DRONE-CONV-001";
        attribute maxRange = 15.0 [SI::km];
        attribute maxPayload = 5.0 [SI::kg];

        perform action executeDeliveryMission;
    }
}
