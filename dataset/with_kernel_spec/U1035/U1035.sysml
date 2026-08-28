package UAM_Network {
    public import ISQ::*;
    public import ScalarValues::*;

    package Definitions {
        enum def FlightPhaseKind {
            preflight;
            takeoff;
            transitionPhase;
            cruise;
            approach;
            landing;
        }
        attribute def BookingRequest {
            attribute origin : String;
            attribute destination : String;
            attribute passengerCount : Integer;
        }
        attribute def ClearanceSignal {
            attribute granted : Boolean;
        }
        attribute def FlightPath {
            attribute distance :> ISQ::length;
            attribute estimatedTime :> ISQ::time;
        }
        attribute def BatteryCharge :> Real;
        attribute def RotorTiltAngle :> ISQ::planeAngle;
        attribute def TelemetryData {
            attribute position :> ISQ::length;
            attribute velocity :> ISQ::speed;
            attribute phase : FlightPhaseKind;
        }
        attribute def ControlCommand {
            attribute targetTiltAngle : RotorTiltAngle;
            attribute targetThrust :> ISQ::power;
        }

        item def Passenger;
        item def ElectricEnergy;

        port def PowerPort {
            out item energy : ElectricEnergy;
            in attribute chargeLevel : BatteryCharge;
        }
        port def SensorDataPort {
            out attribute data;
        }
        port def ControlPort {
            out attribute cmd : ControlCommand;
        }
        port def CommPort {
            in attribute bookingRequest : BookingRequest;
            in attribute clearance : ClearanceSignal;
            out attribute telemetry : TelemetryData;
        }

        flow def ElectricPowerFlow {
            ref :>> payload : ElectricEnergy;
            end port supplier : PowerPort;
            end port consumer : PowerPort;
        }

        part def BatteryPack {
            attribute capacity :> ISQ::energy;
            attribute chargeLevel : BatteryCharge;
            port powerOut : PowerPort;
        }

        part def ElectricMotor {
            attribute powerRating :> ISQ::power;
            port powerIn : PowerPort;
        }

        part def TiltRotor {
            attribute tiltAngle : RotorTiltAngle;
            part motor : ElectricMotor;
        }

        part def LiDAR {
            attribute range :> ISQ::length;
            port dataOut : SensorDataPort;
        }

        part def Radar {
            attribute range :> ISQ::length;
            port dataOut : SensorDataPort;
        }

        part def Camera {
            attribute resolution : Integer;
            port dataOut : SensorDataPort;
        }

        part def FlightComputer {
            port sensorIn1 : SensorDataPort;
            port sensorIn2 : SensorDataPort;
            port sensorIn3 : SensorDataPort;
            port controlOut : ControlPort;
            port commPort : CommPort;
        }

        part def PropulsionSystem {
            part tiltRotor[8] : TiltRotor;
            port powerInput : PowerPort;
            port controlInput : ControlPort;
        }

        part def PowerSystem {
            part batteryPack[4] : BatteryPack;
            port powerOutput : PowerPort;
        }

        part def SensorSuite {
            part lidar : LiDAR;
            part radar : Radar;
            part camera : Camera;
        }

        part def EVTOL {
            attribute maxPassengers : Integer = 4;
            attribute batteryPackCount : Integer = 4;
            attribute flightComputerCount : Integer = 3;
            attribute rotorCount : Integer = 8;
            attribute currentAltitude :> ISQ::length;
            attribute currentVelocity :> ISQ::speed;

            part propulsionSystem : PropulsionSystem;
            part powerSystem : PowerSystem;
            part flightComputer1 : FlightComputer;
            part flightComputer2 : FlightComputer;
            part flightComputer3 : FlightComputer;
            part sensorSuite : SensorSuite;
            port commPort : CommPort;

            connect powerSystem.powerOutput to propulsionSystem.powerInput;
            connect flightComputer1.controlOut to propulsionSystem.controlInput;
            connect flightComputer1.sensorIn1 to sensorSuite.lidar.dataOut;
            connect flightComputer1.sensorIn2 to sensorSuite.radar.dataOut;
            connect flightComputer1.sensorIn3 to sensorSuite.camera.dataOut;
            connect flightComputer2.sensorIn1 to sensorSuite.lidar.dataOut;
            connect flightComputer2.sensorIn2 to sensorSuite.radar.dataOut;
            connect flightComputer2.sensorIn3 to sensorSuite.camera.dataOut;
            connect flightComputer3.sensorIn1 to sensorSuite.lidar.dataOut;
            connect flightComputer3.sensorIn2 to sensorSuite.radar.dataOut;
            connect flightComputer3.sensorIn3 to sensorSuite.camera.dataOut;

            exhibit state flightStates {
                entry action initial;
                state preflight;
                state takeoff;
                state transitionState;
                state cruise;
                state approach;
                state landing;

                transition initial then preflight;
                transition preflight_to_takeoff
                    first preflight
                    accept clearance : ClearanceSignal via commPort
                    if clearance.granted
                    then takeoff;
                transition takeoff_to_transition
                    first takeoff
                    if currentAltitude >= 100 [m]
                    then transitionState;
                transition transition_to_cruise
                    first transitionState
                    if currentVelocity >= 150 [km/h]
                    then cruise;
                transition cruise_to_approach
                    first cruise
                    if currentAltitude <= 500 [m]
                    then approach;
                transition approach_to_landing
                    first approach
                    if currentAltitude <= 50 [m]
                    then landing;
            }
        }

        part def Vertiport {
            attribute name : String;
            attribute location :> ISQ::length;
            port groundCommPort : CommPort;
            part landingPad;
            part chargingStation {
                port chargePort : PowerPort;
            }
        }

        part def NetworkOperationsCenter {
            port nocCommPort : CommPort;
            part fleetManager;
            part trafficManager;
            part weatherService;
        }

        part def UAMNetwork {
            part evtolFleet : EVTOL;
            part vertiports : Vertiport;
            part operationsCenter : NetworkOperationsCenter;
        }

        action def PreflightCheck {
            out attribute status : Boolean;
        }
        action def CalculateFlightPath {
            in attribute bookingRequest : BookingRequest;
            out attribute flightPath : FlightPath;
        }
        action def ReceiveClearance {
            out attribute clearance : ClearanceSignal;
        }
        action def VerticalTakeoff {
            out attribute altitude :> ISQ::length;
        }
        action def TransitionToForward {
            in attribute rotorTiltAngle : RotorTiltAngle;
        }
        action def CruiseFlight {
            in attribute flightPath : FlightPath;
            out attribute distanceTraveled :> ISQ::length;
        }
        action def Approach {
            out attribute altitude :> ISQ::length;
        }
        action def VerticalLanding {
            out attribute landed : Boolean;
        }
        action def ExecuteMission {
            in attribute bookingRequest : BookingRequest;
            out attribute missionComplete : Boolean;
        }

        requirement def EmissionFreePropulsionRequirement {
            doc "The vehicle shall use electric motors for emission-free propulsion.";
            subject vehicle : EVTOL;
        }
        requirement def PassengerCapacityRequirement {
            doc "The vehicle shall carry at least 4 passengers.";
            subject vehicle : EVTOL;
        }
        requirement def RedundantPowerRequirement {
            doc "The vehicle shall have at least 4 redundant battery packs.";
            subject vehicle : EVTOL;
        }
        requirement def TripleRedundantFlightComputerRequirement {
            doc "The vehicle shall have a triple-redundant flight computer.";
            subject vehicle : EVTOL;
        }
        requirement def EightRotorRequirement {
            doc "The vehicle shall have 8 tilt-rotors.";
            subject vehicle : EVTOL;
        }
    }

    package Usages {
        public import Definitions::*;

        part uamNetwork : UAMNetwork {
            requirement emissionFreeReq : EmissionFreePropulsionRequirement;
            requirement passengerCapReq : PassengerCapacityRequirement;
            requirement redundantPowerReq : RedundantPowerRequirement;
            requirement tripleRedundantReq : TripleRedundantFlightComputerRequirement;
            requirement eightRotorReq : EightRotorRequirement;

            satisfy emissionFreeReq by evtolFleet;
            satisfy passengerCapReq by evtolFleet;
            satisfy redundantPowerReq by evtolFleet;
            satisfy tripleRedundantReq by evtolFleet;
            satisfy eightRotorReq by evtolFleet;

            connect operationsCenter.nocCommPort to evtolFleet.commPort;
            connect vertiports.groundCommPort to evtolFleet.commPort;
            connect vertiports.chargingStation.chargePort to evtolFleet.powerSystem.powerOutput;
        }

        action executeMission : ExecuteMission {
            in bookingRequest : BookingRequest;
            out missionComplete : Boolean;

            action preflightCheck : PreflightCheck {
                out status : Boolean;
            }
            action calculateFlightPath : CalculateFlightPath {
                in bookingRequest = executeMission::bookingRequest;
                out flightPath : FlightPath;
            }
            action receiveClearance : ReceiveClearance {
                out clearance : ClearanceSignal;
            }
            action verticalTakeoff : VerticalTakeoff {
                out altitude;
            }
            action transitionToForward : TransitionToForward {
                in rotorTiltAngle : RotorTiltAngle;
            }
            action cruiseFlight : CruiseFlight {
                in flightPath : FlightPath;
                out distanceTraveled;
            }
            action approachAction : Approach {
                out altitude;
            }
            action verticalLanding : VerticalLanding {
                out landed;
            }

            flow calculateFlightPath.flightPath to cruiseFlight.flightPath;

            first preflightCheck;
            then calculateFlightPath;
            then receiveClearance;
            then verticalTakeoff;
            then transitionToForward;
            then cruiseFlight;
            then approachAction;
            then verticalLanding;
        }
    }
}
