package PickupTruckModel {
    import ScalarValues::*;

    // ===== Units =====
    unit kg;
    unit L;
    unit kW;
    unit Nm;
    unit rpm;
    unit kmh;
    unit km;
    unit N;

    // ===== Value Types =====
    value type MassValue :> Real { unit kg; }
    value type VolumeValue :> Real { unit L; }
    value type PowerValue :> Real { unit kW; }
    value type TorqueValue :> Real { unit Nm; }
    value type RotationalSpeedValue :> Real { unit rpm; }
    value type LinearSpeedValue :> Real { unit kmh; }
    value type DistanceValue :> Real { unit km; }
    value type ForceValue :> Real { unit N; }
    value type GearRatioValue :> Real;
    value type DisplacementValue :> Real { unit L; }
    value type ThrottlePosition :> Real;

    // ===== Item Definitions =====
    item def Fuel;
    item def MechanicalPower;
    item def TorqueSignal;
    item def Cargo {
        attribute mass : MassValue;
    }
    item def BuildingMaterials :> Cargo;

    // ===== Port Definitions =====
    port def FuelFlowPort {
        inout fuel : Fuel;
    }
    port def PowerFlowPort {
        inout power : MechanicalPower;
    }
    port def DriverCommandPort {
        inout throttle : ThrottlePosition;
    }

    // ===== Requirements =====
    requirement def VehicleWeightRequirement {
        doc "The chassis shall support a total vehicle weight of up to 3500 kg.";
        attribute maxVehicleWeight : MassValue = 3500 [kg];
        subject vehicle;
        constraint { vehicle.totalWeight <= maxVehicleWeight }
    }

    requirement def PayloadCapacityRequirement {
        doc "The cargo bed shall carry a payload of up to 1200 kg.";
        attribute maxPayload : MassValue = 1200 [kg];
        subject cargoBed;
        constraint { cargoBed.payloadMass <= maxPayload }
    }

    requirement def SeatingCapacityRequirement {
        doc "The cabin shall seat up to five people including the driver.";
        attribute seatCount : Integer = 5;
        subject cabin;
        constraint { cabin.seatingCapacity == seatCount }
    }

    requirement def EngineDisplacementRequirement {
        doc "The engine shall have a displacement of 5.0 liters.";
        attribute requiredDisplacement : DisplacementValue = 5.0 [L];
        subject engine;
        constraint { engine.displacement == requiredDisplacement }
    }

    requirement def FuelTankCapacityRequirement {
        doc "The fuel tank shall hold 110 liters.";
        attribute requiredCapacity : VolumeValue = 110 [L];
        subject fuelTank;
        constraint { fuelTank.capacity == requiredCapacity }
    }

    requirement def RearWheelDriveRequirement {
        doc "Only the rear two wheels shall be powered by the engine.";
        subject powertrain;
        constraint { powertrain.drivenWheelCount == 2 and powertrain.drivenAxlePosition == "rear" }
    }

    requirement def FourWheelRequirement {
        doc "The truck shall include four wheels.";
        attribute wheelCount : Integer = 4;
        subject truck;
        constraint { truck.wheelCount == wheelCount }
    }

    // ===== Part Definitions =====
    part def Chassis {
        doc "Strong chassis frame supporting the vehicle structure.";
        attribute maxSupportedWeight : MassValue = 3500 [kg];
        attribute totalWeight : MassValue;
    }

    part def CargoBed {
        doc "Open-air cargo bed for hauling goods.";
        attribute maxPayload : MassValue = 1200 [kg];
        attribute payloadMass : MassValue;
        attribute isOpenAir : Boolean = true;
        ref item payload : Cargo;

        action loadCargo {
            in cargo : Cargo;
            doc "Load cargo into the bed at origin.";
        }

        action unloadCargo {
            out cargo : Cargo;
            doc "Unload cargo from the bed at destination.";
        }
    }

    part def Cabin {
        doc "Cabin seating up to five people including the driver.";
        attribute seatingCapacity : Integer = 5;
        attribute occupiedSeats : Integer;
        attribute hasDriver : Boolean;
    }

    part def Engine {
        doc "5.0-liter internal combustion engine.";
        attribute displacement : DisplacementValue = 5.0 [L];
        attribute maxPower : PowerValue = 300 [kW];
        attribute maxTorque : TorqueValue = 500 [Nm];
        attribute currentPower : PowerValue;
        attribute currentTorque : TorqueValue;
        attribute currentSpeed : RotationalSpeedValue;

        port fuelIn : FuelFlowPort;
        port powerOut : PowerFlowPort;
        port commandIn : DriverCommandPort;

        action generatePower {
            in throttle : ThrottlePosition;
            in fuel : Fuel;
            out power : MechanicalPower;
            out torque : TorqueSignal;
            doc "Generate mechanical power based on driver throttle command.";
        }
    }

    part def FuelTank {
        doc "110-liter fuel tank supplying fuel to the engine.";
        attribute capacity : VolumeValue = 110 [L];
        attribute currentFuelLevel : VolumeValue;
        port fuelOut : FuelFlowPort;

        action supplyFuel {
            out fuel : Fuel;
            doc "Supply fuel to the engine.";
        }
    }

    part def Transmission {
        doc "Multi-gear transmission adjusting torque and speed.";
        attribute gearCount : Integer = 6;
        attribute currentGear : Integer = 1;
        attribute gearRatios : GearRatioValue[6] = (4.5, 2.5, 1.6, 1.2, 1.0, 0.8);
        attribute currentRatio : GearRatioValue;

        port powerIn : PowerFlowPort;
        port powerOut : PowerFlowPort;

        action shiftGear {
            in targetGear : Integer;
            doc "Shift to the target gear.";
        }

        action adjustTorqueSpeed {
            in inputPower : MechanicalPower;
            out outputPower : MechanicalPower;
            doc "Adjust torque and speed according to current gear ratio.";
        }
    }

    part def Driveshaft {
        doc "Transfers mechanical power from transmission to rear differential.";
        port powerIn : PowerFlowPort;
        port powerOut : PowerFlowPort;

        action transferPower {
            in inputPower : MechanicalPower;
            out outputPower : MechanicalPower;
            doc "Transfer mechanical power to the rear axle.";
        }
    }

    part def Differential {
        doc "Rear axle differential distributing power to two rear wheels.";
        attribute location : String = "rear";
        attribute allowsSpeedDifference : Boolean = true;

        port powerIn : PowerFlowPort;
        port leftOut : PowerFlowPort;
        port rightOut : PowerFlowPort;

        action distributePower {
            in inputPower : MechanicalPower;
            out leftPower : MechanicalPower;
            out rightPower : MechanicalPower;
            doc "Distribute power to left and right rear wheels, allowing them to turn at different speeds for smooth cornering.";
        }
    }

    part def Wheel {
        doc "Vehicle wheel.";
        attribute isPowered : Boolean;
        attribute position : String;
        attribute tirePressure : Real;

        port powerIn : PowerFlowPort;

        action propel {
            in power : MechanicalPower;
            out tractionForce : ForceValue;
            doc "Convert mechanical power to tractive force.";
        }
    }

    part def RearAxle {
        doc "Rear axle assembly with differential and two powered wheels.";
        part differential : Differential;
        part leftWheel : Wheel {
            isPowered = true;
            position = "rear-left";
        }
        part rightWheel : Wheel {
            isPowered = true;
            position = "rear-right";
        }

        connect differential.leftOut to leftWheel.powerIn;
        connect differential.rightOut to rightWheel.powerIn;
    }

    part def Powertrain {
        doc "Complete powertrain from engine to rear wheels.";
        attribute drivenWheelCount : Integer = 2;
        attribute drivenAxlePosition : String = "rear";

        part engine : Engine;
        part fuelTank : FuelTank;
        part transmission : Transmission;
        part driveshaft : Driveshaft;
        part rearAxle : RearAxle;

        connect fuelTank.fuelOut to engine.fuelIn;
        connect engine.powerOut to transmission.powerIn;
        connect transmission.powerOut to driveshaft.powerIn;
        connect driveshaft.powerOut to rearAxle.differential.powerIn;
    }

    // ===== Truck =====
    part def Truck {
        doc "Conventional rear-wheel-drive pickup truck for transporting heavy cargo.";

        attribute totalWeight : MassValue;
        attribute drivenWheelCount : Integer = 2;
        attribute drivenAxlePosition : String = "rear";
        attribute wheelCount : Integer = 4;
        attribute vehicleSpeed : LinearSpeedValue;
        attribute steeringAngle : Real;
        attribute cargoLoaded : Boolean;
        attribute atDestination : Boolean;
        attribute cargoUnloaded : Boolean;

        part chassis : Chassis;
        part cargoBed : CargoBed;
        part cabin : Cabin;
        part powertrain : Powertrain;
        part frontLeftWheel : Wheel {
            isPowered = false;
            position = "front-left";
        }
        part frontRightWheel : Wheel {
            isPowered = false;
            position = "front-right";
        }

        satisfy VehicleWeightRequirement by chassis;
        satisfy PayloadCapacityRequirement by cargoBed;
        satisfy SeatingCapacityRequirement by cabin;
        satisfy EngineDisplacementRequirement by powertrain.engine;
        satisfy FuelTankCapacityRequirement by powertrain.fuelTank;
        satisfy RearWheelDriveRequirement by powertrain;
        satisfy FourWheelRequirement by self;

        action drive {
            in throttle : ThrottlePosition;
            doc "Core driving function: engine generates power based on driver commands, managed through transmission and drivetrain to propel the vehicle forward.";

            action generatePower {
                doc "Engine generates power based on throttle input.";
            }
            action adjustTorqueSpeed {
                doc "Transmission adjusts torque and speed.";
            }
            action transferPower {
                doc "Driveshaft transfers mechanical power to rear differential.";
            }
            action distributePower {
                doc "Differential distributes power to rear wheels.";
            }
            action propel {
                doc "Rear wheels propel the vehicle forward.";
            }

            succession generatePower then adjustTorqueSpeed;
            succession adjustTorqueSpeed then transferPower;
            succession transferPower then distributePower;
            succession distributePower then propel;
        }

        exhibit state def MissionStateMachine {
            doc "State machine governing truck transport mission lifecycle.";

            state Loading {
                doc "Payload is being loaded at origin.";
                entry action {
                    // Load cargo into the cargo bed at origin
                }
            }

            state Driving {
                doc "Vehicle is in motion transporting payload to destination.";
                entry action {
                    // Begin driving to destination
                }

                state Accelerating {
                    doc "Vehicle speed is increasing.";
                }

                state Cruising {
                    doc "Vehicle maintaining steady speed.";
                }

                state Cornering {
                    doc "Vehicle navigating a turn, differential allowing wheel speed difference.";
                }

                transition Accelerating -> Cruising when vehicleSpeed >= 50 [kmh];
                transition Cruising -> Accelerating when vehicleSpeed < 40 [kmh];
                transition Cruising -> Cornering when steeringAngle != 0;
                transition Cornering -> Cruising when steeringAngle == 0;
            }

            state Unloading {
                doc "Payload is being unloaded at destination.";
                entry action {
                    // Unload cargo from the bed at destination
                }
            }

            state Complete {
                doc "Mission is complete.";
            }

            transition Loading -> Driving when cargoLoaded;
            transition Driving -> Unloading when atDestination;
            transition Unloading -> Complete when cargoUnloaded;
        }
    }

    // ===== Transport Mission =====
    part def TransportMission {
        doc "A transport mission involving loading, driving, and unloading cargo.";

        attribute origin : String;
        attribute destination : String;
        attribute distance : DistanceValue;
        attribute missionComplete : Boolean = false;

        ref item payload : Cargo;
        ref part truck : Truck;

        action executeMission {
            doc "Execute the complete transport mission.";

            action loadPayload {
                doc "Load specific payload at origin.";
                in payload : Cargo;
                in origin : String;
            }

            action driveToDestination {
                doc "Driver operates vehicle to transport payload to destination.";
                in destination : String;
                in throttle : ThrottlePosition;
            }

            action unloadPayload {
                doc "Unload cargo at destination to complete mission.";
                out cargo : Cargo;
            }

            succession loadPayload then driveToDestination;
            succession driveToDestination then unloadPayload;
        }
    }

    // ===== Concrete Instances =====
    part pickupTruck : Truck {
        doc "Concrete pickup truck instance.";
        attribute totalWeight = 3200 [kg];

        part chassis : Chassis {
            totalWeight = 3200 [kg];
        }
        part cargoBed : CargoBed {
            payloadMass = 950 [kg];
        }
        part cabin : Cabin {
            occupiedSeats = 1;
            hasDriver = true;
        }
        part powertrain : Powertrain {
            part engine : Engine {
                displacement = 5.0 [L];
            }
            part fuelTank : FuelTank {
                capacity = 110 [L];
                currentFuelLevel = 85 [L];
            }
            part transmission : Transmission {
                currentGear = 1;
            }
        }
    }

    part buildingMaterialsDelivery : TransportMission {
        doc "Typical mission: transport 950 kg of building materials from distribution center to construction site.";

        attribute origin = "Distribution Center";
        attribute destination = "Construction Site";
        attribute distance = 25 [km];

        ref item payload : BuildingMaterials {
            mass = 950 [kg];
        }

        ref part truck : Truck = pickupTruck;
    }
}
