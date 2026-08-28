package AutomobileModel {
    public import Definitions::*;
    public import Usages::*;
    public import Requirements::*;

    package Definitions {
        public import ScalarValues::*;
        public import ISQ::*;
        public import SI::*;
        public import ItemDefinitions::*;
        public import PortDefinitions::*;
        public import SignalDefinitions::*;
        public import InterfaceDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            public import ISQ::*;
            item def Fuel {
                attribute volume :> ISQ::VolumeValue;
            }
            item def Passenger;
            item def Cargo {
                attribute mass :> ISQ::MassValue;
            }
        }

        package PortDefinitions {
            port def FuelPort;
            port def TorquePort;
            port def ThrottleCmdPort;
            port def BrakeCmdPort;
            port def SteeringCmdPort;
            port def NavigationPort;
            port def IgnitionPort;
        }

        package SignalDefinitions {
            item def StartSignal;
            item def EngineRunningSignal;
            item def TargetSpeedReached;
            item def BrakeSignal;
            item def StopSignal;
        }

        package InterfaceDefinitions {
            public import PortDefinitions::*;
            interface def FuelInterface {
                end fuelSupplier : FuelPort;
                end fuelConsumer : FuelPort;
            }
            interface def TorqueTransferInterface {
                end torqueSource : TorquePort;
                end torqueSink : TorquePort;
            }
            interface def NavigationToControlInterface {
                end navPort : NavigationPort;
                end controlPort : NavigationPort;
            }
        }

        package ActionDefinitions {
            public import ItemDefinitions::*;
            public import PortDefinitions::*;
            public import ScalarValues::*;
            public import ISQ::*;

            action def GenerateTorque {
                in fuel : Fuel;
                out engineTorque : ISQ::TorqueValue;
            }
            action def AmplifyTorque {
                in engineTorque : ISQ::TorqueValue;
                out transmissionTorque : ISQ::TorqueValue;
            }
            action def TransferTorque {
                in transmissionTorque : ISQ::TorqueValue;
                out driveshaftTorque : ISQ::TorqueValue;
            }
            action def DistributeTorque {
                in driveshaftTorque : ISQ::TorqueValue;
                out leftWheelTorque : ISQ::TorqueValue;
                out rightWheelTorque : ISQ::TorqueValue;
            }
            action def ProvidePower {
                in fuel : Fuel;
                out leftWheelTorque : ISQ::TorqueValue;
                out rightWheelTorque : ISQ::TorqueValue;

                action generateTorque : GenerateTorque {
                    in fuel = ProvidePower::fuel;
                    out engineTorque;
                }
                flow generateTorque.engineTorque to amplifyTorque.engineTorque;
                action amplifyTorque : AmplifyTorque {
                    in engineTorque;
                    out transmissionTorque;
                }
                flow amplifyTorque.transmissionTorque to transferTorque.transmissionTorque;
                action transferTorque : TransferTorque {
                    in transmissionTorque;
                    out driveshaftTorque;
                }
                flow transferTorque.driveshaftTorque to distributeTorque.driveshaftTorque;
                action distributeTorque : DistributeTorque {
                    in driveshaftTorque;
                    out leftWheelTorque;
                    out rightWheelTorque;
                }
            }
            action def LoadPayload {
                in passengers : Passenger[0..5];
                in cargo : Cargo;
            }
            action def PlanRoute {
                in startPosition : ISQ::LengthValue;
                in destination : ISQ::LengthValue;
                out route : String;
            }
            action def UpdatePosition {
                inout currentPosition : ISQ::LengthValue;
            }
            action def ConsumeFuel {
                inout fuelLevel : ISQ::VolumeValue;
                in consumptionRate : Real;
            }
            action def TravelToDestination {
                in route : String;
                in destination : ISQ::LengthValue;
                inout currentPosition : ISQ::LengthValue;
                inout fuelLevel : ISQ::VolumeValue;
                in consumptionRate : Real;

                loop {
                    action updatePosition : UpdatePosition {
                        inout currentPosition = TravelToDestination::currentPosition;
                    }
                    action consumeFuel : ConsumeFuel {
                        inout fuelLevel = TravelToDestination::fuelLevel;
                        in consumptionRate = TravelToDestination::consumptionRate;
                    }
                }
            }
            action def UnloadPayload {
                out passengers : Passenger[0..5];
                out cargo : Cargo;
            }
            action def TransportMission {
                in startPosition : ISQ::LengthValue;
                in destination : ISQ::LengthValue;
                in passengers : Passenger[0..5];
                in cargo : Cargo;
                inout fuelLevel : ISQ::VolumeValue;
                in consumptionRate : Real;

                action loadPayload : LoadPayload {
                    in passengers = TransportMission::passengers;
                    in cargo = TransportMission::cargo;
                }
                then action planRoute : PlanRoute {
                    in startPosition = TransportMission::startPosition;
                    in destination = TransportMission::destination;
                    out route;
                }
                then action travelToDestination : TravelToDestination {
                    in route = planRoute::route;
                    in destination = TransportMission::destination;
                    inout currentPosition = TransportMission::startPosition;
                    inout fuelLevel = TransportMission::fuelLevel;
                    in consumptionRate = TransportMission::consumptionRate;
                }
                then action unloadPayload : UnloadPayload {
                    out passengers;
                    out cargo;
                }
            }
            action def ComputeCommands {
                in currentPosition : ISQ::LengthValue;
                in destination : ISQ::LengthValue;
                in targetSpeed : ISQ::SpeedValue;
                out throttleCmd : Real;
                out brakeCmd : Real;
                out steeringCmd : Real;
            }
        }

        package StateDefinitions {
            public import SignalDefinitions::*;
            state def VehicleStates {
                entry action initial;
                state parked;
                state starting;
                state accelerating;
                state cruising;
                state decelerating;

                transition initial then parked;
                transition parked_to_starting
                    first parked
                    accept StartSignal
                    then starting;
                transition starting_to_accelerating
                    first starting
                    accept EngineRunningSignal
                    then accelerating;
                transition accelerating_to_cruising
                    first accelerating
                    accept TargetSpeedReached
                    then cruising;
                transition cruising_to_decelerating
                    first cruising
                    accept BrakeSignal
                    then decelerating;
                transition decelerating_to_parked
                    first decelerating
                    accept StopSignal
                    then parked;
            }
        }

        package PartDefinitions {
            public import PortDefinitions::*;
            public import ItemDefinitions::*;
            public import ActionDefinitions::*;
            public import StateDefinitions::*;
            public import InterfaceDefinitions::*;
            public import ISQ::*;
            public import SI::*;
            public import ScalarValues::*;

            part def Vehicle {
                attribute mass :> ISQ::MassValue;
                attribute dryMass :> ISQ::MassValue;
                attribute cargoMass :> ISQ::MassValue;
                attribute totalMass :> ISQ::MassValue;
                attribute currentPosition :> ISQ::LengthValue;
                attribute destination :> ISQ::LengthValue;
                attribute currentSpeed :> ISQ::SpeedValue;
                attribute targetSpeed :> ISQ::SpeedValue;
                attribute fuelLevel :> ISQ::VolumeValue;
                attribute brakePedalDepressed : Boolean;

                port ignitionPort : IgnitionPort;
                port throttleCmdPort : ThrottleCmdPort;
                port brakeCmdPort : BrakeCmdPort;
                port steeringCmdPort : SteeringCmdPort;
                port navPort : NavigationPort;

                perform action providePower : ProvidePower;
                perform action transportMission : TransportMission;
                exhibit state vehicleStates : VehicleStates;

                part engine : Engine;
                part fuelTank : FuelTank;
                part transmission : Transmission;
                part driveshaft : Driveshaft;
                part differential : Differential;
                part frontLeftWheel : Wheel;
                part frontRightWheel : Wheel;
                part rearLeftWheel : Wheel;
                part rearRightWheel : Wheel;
                part passengerCompartment : PassengerCompartment;
                part cargoCompartment : CargoCompartment;
                part controlSystem : ControlSystem;
                part navigationSystem : NavigationSystem;

                interface fuelSupply : FuelInterface
                    connect fuelTank.fuelPort to engine.fuelPort;
                interface engineToTransmission : TorqueTransferInterface
                    connect engine.torqueOut to transmission.torqueIn;
                interface transmissionToDriveshaft : TorqueTransferInterface
                    connect transmission.torqueOut to driveshaft.torqueIn;
                interface driveshaftToDifferential : TorqueTransferInterface
                    connect driveshaft.torqueOut to differential.torqueIn;
                interface differentialToLeftWheel : TorqueTransferInterface
                    connect differential.torqueOutLeft to rearLeftWheel.torqueIn;
                interface differentialToRightWheel : TorqueTransferInterface
                    connect differential.torqueOutRight to rearRightWheel.torqueIn;
                interface navigationToControl : NavigationToControlInterface
                    connect navigationSystem.navPort to controlSystem.navPort;

                connect controlSystem.throttleCmdOut to throttleCmdPort;
                connect controlSystem.brakeCmdOut to brakeCmdPort;
                connect controlSystem.steeringCmdOut to steeringCmdPort;
            }

            part def Engine {
                attribute displacement :> ISQ::VolumeValue = 2.0 [L];
                attribute power :> ISQ::PowerValue = 150 [kW];
                port fuelPort : FuelPort;
                port torqueOut : TorquePort;
                perform action generateTorque : GenerateTorque;
            }

            part def FuelTank {
                attribute capacity :> ISQ::VolumeValue = 60 [L];
                attribute fuelLevel :> ISQ::VolumeValue;
                ref item fuel : Fuel;
                port fuelPort : FuelPort;
                assert constraint { fuelLevel <= capacity }
            }

            part def Transmission {
                port torqueIn : TorquePort;
                port torqueOut : TorquePort;
                perform action amplifyTorque : AmplifyTorque;
            }

            part def Driveshaft {
                port torqueIn : TorquePort;
                port torqueOut : TorquePort;
                perform action transferTorque : TransferTorque;
            }

            part def Differential {
                port torqueIn : TorquePort;
                port torqueOutLeft : TorquePort;
                port torqueOutRight : TorquePort;
                perform action distributeTorque : DistributeTorque;
            }

            part def Wheel {
                attribute radius :> ISQ::LengthValue = 0.35 [m];
                port torqueIn : TorquePort;
            }

            part def PassengerCompartment {
                attribute maxPassengers : Integer = 5;
                attribute currentPassengers : Integer;
                ref item passengers : Passenger[0..5];
                assert constraint { currentPassengers <= maxPassengers }
            }

            part def CargoCompartment {
                attribute maxCargoMass :> ISQ::MassValue = 500 [kg];
                attribute currentCargoMass :> ISQ::MassValue;
                ref item cargo : Cargo;
                assert constraint { currentCargoMass <= maxCargoMass }
            }

            part def ControlSystem {
                port throttleCmdOut : ThrottleCmdPort;
                port brakeCmdOut : BrakeCmdPort;
                port steeringCmdOut : SteeringCmdPort;
                port navPort : NavigationPort;
                perform action computeCommands : ComputeCommands;
            }

            part def NavigationSystem {
                attribute currentPosition :> ISQ::LengthValue;
                attribute destination :> ISQ::LengthValue;
                port navPort : NavigationPort;
                perform action planRoute : PlanRoute;
                perform action updatePosition : UpdatePosition;
            }
        }

        package RequirementDefinitions {
            public import PartDefinitions::*;
            public import ISQ::*;
            public import SI::*;
            public import ScalarValues::*;

            requirement def <'1'> MassLimitationRequirement {
                doc /* The total mass of the vehicle shall not exceed 2500 kg. */
                subject vehicle : Vehicle;
                attribute massActual :> ISQ::MassValue = vehicle.totalMass;
                attribute massReqd :> ISQ::MassValue = 2500 [kg];
                require constraint { massActual <= massReqd }
            }

            requirement def <'2'> SpeedLimitRequirement {
                doc /* The vehicle shall not exceed an operational speed of 130 km/h. */
                subject vehicle : Vehicle;
                attribute speedActual :> ISQ::SpeedValue = vehicle.currentSpeed;
                attribute speedReqd :> ISQ::SpeedValue = 130 [km/h];
                require constraint { speedActual <= speedReqd }
            }

            requirement def <'3'> FuelEfficiencyRequirement {
                doc /* The vehicle fuel consumption shall not exceed 8.0 L/100km. */
                subject vehicle : Vehicle;
                attribute fuelEfficiencyActual : Real;
                attribute fuelEfficiencyReqd : Real = 8.0;
                require constraint { fuelEfficiencyActual <= fuelEfficiencyReqd }
            }
        }
    }

    package Usages {
        public import Definitions::*;

        part vehicleInstance : Vehicle {
            attribute :>> mass = 2000 [kg];
            attribute :>> dryMass = 1800 [kg];
            attribute :>> currentSpeed = 0 [km/h];
            attribute :>> targetSpeed = 100 [km/h];
            attribute :>> fuelLevel = 50 [L];

            part :>> engine {
                attribute :>> displacement = 2.0 [L];
                attribute :>> power = 150 [kW];
                port :>> fuelPort;
                port :>> torqueOut;
            }
            part :>> fuelTank {
                attribute :>> capacity = 60 [L];
                attribute :>> fuelLevel = 50 [L];
            }
            part :>> transmission {
                port :>> torqueIn;
                port :>> torqueOut;
            }
            part :>> driveshaft {
                port :>> torqueIn;
                port :>> torqueOut;
            }
            part :>> differential {
                port :>> torqueIn;
                port :>> torqueOutLeft;
                port :>> torqueOutRight;
            }
            part :>> frontLeftWheel {
                attribute :>> radius = 0.35 [m];
            }
            part :>> frontRightWheel {
                attribute :>> radius = 0.35 [m];
            }
            part :>> rearLeftWheel {
                attribute :>> radius = 0.35 [m];
            }
            part :>> rearRightWheel {
                attribute :>> radius = 0.35 [m];
            }
            part :>> passengerCompartment {
                attribute :>> maxPassengers = 5;
            }
            part :>> cargoCompartment {
                attribute :>> maxCargoMass = 500 [kg];
            }
            part :>> controlSystem {
                port :>> throttleCmdOut;
                port :>> brakeCmdOut;
                port :>> steeringCmdOut;
                port :>> navPort;
            }
            part :>> navigationSystem {
                port :>> navPort;
            }
        }
    }

    package Requirements {
        public import Definitions::*;

        requirement vehicleMass : MassLimitationRequirement {
            subject :>> vehicle = vehicleInstance;
        }
        requirement vehicleSpeed : SpeedLimitRequirement {
            subject :>> vehicle = vehicleInstance;
        }
        requirement vehicleFuelEff : FuelEfficiencyRequirement {
            subject :>> vehicle = vehicleInstance;
        }
    }
}
