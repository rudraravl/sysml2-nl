package PickupTruckModel {
    public import ScalarValues::*;
    public import ISQ::*;
    
    package Definitions {
        package AttributeDefinitions {
            attribute def ThrottleCmd;
            attribute def FuelCmd;
            enum def IgnitionOnOff { on; off; }
            attribute def IgnitionCmd {
                attribute ignitionOnOff: IgnitionOnOff;
            }
            attribute def VehicleOnSignal;
            attribute def VehicleOffSignal;
            attribute def PayloadSpec {
                attribute payloadMass: ISQ::MassValue;
                attribute description: String;
            }
            attribute def MissionPlan {
                attribute origin: String;
                attribute destination: String;
                attribute payload: PayloadSpec;
            }
        }
        
        package ItemDefinitions {
            item def Fuel;
            item def BuildingMaterials;
            item def Cargo {
                attribute mass: ISQ::MassValue;
            }
        }
        
        package PortDefinitions {
            port def FuelCmdPort { in fuelCmd: AttributeDefinitions::FuelCmd; }
            port def DrivePwrPort { out engineTorque: ISQ::TorqueValue; }
            port def ClutchPort { in engineTorque: ISQ::TorqueValue; }
            port def ShaftPortA { out transmissionTorque: ISQ::TorqueValue; }
            port def ShaftPortB { in transmissionTorque: ISQ::TorqueValue; }
            port def ShaftPortC { out driveshaftTorque: ISQ::TorqueValue; }
            port def ShaftPortD { in driveshaftTorque: ISQ::TorqueValue; }
            port def AxleToWheelPort { out wheelTorque: ISQ::TorqueValue; }
            port def WheelToRoadPort;
            port def IgnitionCmdPort { in ignitionCmd: AttributeDefinitions::IgnitionCmd; }
        }
        
        package ActionDefinitions {
            action def GeneratePower {
                in throttle: AttributeDefinitions::ThrottleCmd;
                out engineTorque: ISQ::TorqueValue;
            }
            action def AmplifyTorque {
                in engineTorque: ISQ::TorqueValue;
                out transmissionTorque: ISQ::TorqueValue;
            }
            action def TransferTorque {
                in transmissionTorque: ISQ::TorqueValue;
                out driveshaftTorque: ISQ::TorqueValue;
            }
            action def DistributeTorque {
                in driveshaftTorque: ISQ::TorqueValue;
                out wheelTorque1: ISQ::TorqueValue;
                out wheelTorque2: ISQ::TorqueValue;
            }
            action def ProvidePower {
                in throttle: AttributeDefinitions::ThrottleCmd;
                out wheelTorque1: ISQ::TorqueValue;
                out wheelTorque2: ISQ::TorqueValue;
            }
            action def LoadCargo {
                in payload: AttributeDefinitions::PayloadSpec;
                out cargo: ItemDefinitions::Cargo;
            }
            action def DriveToDestination {
                in throttle: AttributeDefinitions::ThrottleCmd;
                in cargo: ItemDefinitions::Cargo;
            }
            action def UnloadCargo {
                in cargo: ItemDefinitions::Cargo;
            }
            action def TransportMission {
                in plan: AttributeDefinitions::MissionPlan;
            }
            action def PerformSelfTest;
            action def ApplyParkingBrake;
        }
        
        package PartDefinitions {
            part def Vehicle {
                attribute grossVehicleWeight: ISQ::MassValue = 3500[ISQ::kg];
                attribute maxPayload: ISQ::MassValue = 1200[ISQ::kg];
                attribute seatingCapacity: Integer = 5;
                attribute currentPayload: ISQ::MassValue;
                port ignitionCmdPort: PortDefinitions::IgnitionCmdPort;
                port fuelCmdPort: PortDefinitions::FuelCmdPort;
                perform action providePower;
                perform action performSelfTest;
                perform action applyParkingBrake;
                exhibit state vehicleStates {
                    entry action initial;
                    state off;
                    state starting;
                    state on {
                        entry performSelfTest;
                        do providePower;
                        exit applyParkingBrake;
                    }
                    transition initial then off;
                    transition off_to_starting
                        first off
                        accept ignitionCmd: AttributeDefinitions::IgnitionCmd
                        if ignitionCmd.ignitionOnOff == AttributeDefinitions::IgnitionOnOff::on
                        then starting;
                    transition starting_to_on
                        first starting
                        accept AttributeDefinitions::VehicleOnSignal
                        then on;
                    transition on_to_off
                        first on
                        accept AttributeDefinitions::VehicleOffSignal
                        then off;
                }
            }
            part def Chassis {
                attribute maxWeightRating: ISQ::MassValue = 3500[ISQ::kg];
            }
            part def Cabin {
                attribute seatCount: Integer = 5;
            }
            part def CargoBed {
                attribute maxPayload: ISQ::MassValue = 1200[ISQ::kg];
                ref item cargo: ItemDefinitions::Cargo;
            }
            part def Engine {
                attribute displacement: ISQ::VolumeValue = 5.0[ISQ::L];
                port fuelCmdPort: PortDefinitions::FuelCmdPort;
                port drivePwrPort: PortDefinitions::DrivePwrPort;
                perform action generatePower: ActionDefinitions::GeneratePower;
            }
            part def FuelTank {
                attribute capacity: ISQ::VolumeValue = 110[ISQ::L];
                ref item fuel: ItemDefinitions::Fuel;
            }
            part def Transmission {
                attribute gearCount: Integer = 6;
                port clutchPort: PortDefinitions::ClutchPort;
                port shaftPortA: PortDefinitions::ShaftPortA;
                perform action amplifyTorque: ActionDefinitions::AmplifyTorque;
            }
            part def Driveshaft {
                port shaftPortB: PortDefinitions::ShaftPortB;
                port shaftPortC: PortDefinitions::ShaftPortC;
                perform action transferTorque: ActionDefinitions::TransferTorque;
            }
            part def RearAxleAssembly {
                port shaftPortD: PortDefinitions::ShaftPortD;
                part differential: Differential;
                part leftHalfAxle: HalfAxle {
                    port axleToWheelPort: PortDefinitions::AxleToWheelPort;
                }
                part rightHalfAxle: HalfAxle {
                    port axleToWheelPort: PortDefinitions::AxleToWheelPort;
                }
                part leftWheel: Wheel;
                part rightWheel: Wheel;
                perform action distributeTorque: ActionDefinitions::DistributeTorque;
            }
            part def Differential;
            part def HalfAxle;
            part def Wheel {
                attribute diameter: ISQ::LengthValue;
                port wheelToRoadPort: PortDefinitions::WheelToRoadPort;
            }
            part def FrontAxle {
                part leftWheel: Wheel;
                part rightWheel: Wheel;
            }
        }
        
        package RequirementDefinitions {
            requirement def WeightRequirement {
                attribute maxGVW: ISQ::MassValue = 3500[ISQ::kg];
                subject vehicle: PartDefinitions::Vehicle;
                constraint { vehicle.grossVehicleWeight <= maxGVW }
            }
            requirement def PayloadRequirement {
                attribute maxPayload: ISQ::MassValue = 1200[ISQ::kg];
                subject bed: PartDefinitions::CargoBed;
                constraint { bed.maxPayload <= maxPayload }
            }
            requirement def SeatingRequirement {
                attribute requiredSeats: Integer = 5;
                subject cabin: PartDefinitions::Cabin;
                constraint { cabin.seatCount >= requiredSeats }
            }
            requirement def FuelCapacityRequirement {
                attribute minCapacity: ISQ::VolumeValue = 110[ISQ::L];
                subject tank: PartDefinitions::FuelTank;
                constraint { tank.capacity >= minCapacity }
            }
            requirement def EngineDisplacementRequirement {
                attribute requiredDisplacement: ISQ::VolumeValue = 5.0[ISQ::L];
                subject engine: PartDefinitions::Engine;
                constraint { engine.displacement >= requiredDisplacement }
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part pickupTruck :> PartDefinitions::Vehicle {
            part chassis: PartDefinitions::Chassis;
            part cabin: PartDefinitions::Cabin;
            part cargoBed: PartDefinitions::CargoBed;
            part fuelTank: PartDefinitions::FuelTank;
            part engine: PartDefinitions::Engine;
            part transmission: PartDefinitions::Transmission;
            part driveshaft: PartDefinitions::Driveshaft;
            part rearAxleAssembly: PartDefinitions::RearAxleAssembly;
            part frontAxle: PartDefinitions::FrontAxle;
            
            perform providePower {
                in throttle: AttributeDefinitions::ThrottleCmd;
                out wheelTorque1: ISQ::TorqueValue;
                out wheelTorque2: ISQ::TorqueValue;
                
                action generateTorque: ActionDefinitions::GeneratePower {
                    in throttle = providePower.throttle;
                    out engineTorque = engine.drivePwrPort.engineTorque;
                }
                flow generateTorque.engineTorque to amplifyTorque.engineTorque;
                action amplifyTorque: ActionDefinitions::AmplifyTorque;
                flow amplifyTorque.transmissionTorque to transferTorque.transmissionTorque;
                action transferTorque: ActionDefinitions::TransferTorque;
                flow transferTorque.driveshaftTorque to distributeTorque.driveshaftTorque;
                action distributeTorque: ActionDefinitions::DistributeTorque {
                    out wheelTorque1 = providePower.wheelTorque1;
                    out wheelTorque2 = providePower.wheelTorque2;
                }
            }
            
            connect engine.drivePwrPort to transmission.clutchPort;
            connect transmission.shaftPortA to driveshaft.shaftPortB;
            connect driveshaft.shaftPortC to rearAxleAssembly.shaftPortD;
            connect rearAxleAssembly.leftHalfAxle.axleToWheelPort to rearAxleAssembly.leftWheel.wheelToRoadPort;
            connect rearAxleAssembly.rightHalfAxle.axleToWheelPort to rearAxleAssembly.rightWheel.wheelToRoadPort;
        }
        
        action transportMission :> ActionDefinitions::TransportMission {
            in plan: AttributeDefinitions::MissionPlan;
            action loadCargo: ActionDefinitions::LoadCargo {
                in payload = plan.payload;
                out loadedCargo: ItemDefinitions::Cargo;
            }
            flow loadCargo.loadedCargo to driveToDestination.cargo;
            action driveToDestination: ActionDefinitions::DriveToDestination {
                in cargo: ItemDefinitions::Cargo;
                in throttle: AttributeDefinitions::ThrottleCmd;
            }
            flow driveToDestination.cargo to unloadCargo.cargo;
            action unloadCargo: ActionDefinitions::UnloadCargo;
        }
        
        requirement weightCheck :> RequirementDefinitions::WeightRequirement {
            subject vehicle :> pickupTruck;
        }
        requirement payloadCheck :> RequirementDefinitions::PayloadRequirement {
            subject bed :> pickupTruck.cargoBed;
        }
        requirement seatingCheck :> RequirementDefinitions::SeatingRequirement {
            subject cabin :> pickupTruck.cabin;
        }
        requirement fuelCapacityCheck :> RequirementDefinitions::FuelCapacityRequirement {
            subject tank :> pickupTruck.fuelTank;
        }
        requirement engineDisplacementCheck :> RequirementDefinitions::EngineDisplacementRequirement {
            subject engine :> pickupTruck.engine;
        }
    }
}
