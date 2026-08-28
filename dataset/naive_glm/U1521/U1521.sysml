package AutomobileModel {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    // ===== Custom Units =====
    unit km = 1000 [m];
    unit h = 3600 [s];
    unit km_per_h = km / h;
    unit liter = 0.001 [m^3];
    unit kW = 1000 [W];
    unit L_per_100km = liter / (100 * km);

    // ===== Value Types =====
    value type LengthValue :> Real { unit = km; }
    value type SpeedValue :> Real { unit = km_per_h; }
    value type VolumeValue :> Real { unit = liter; }
    value type PowerValue :> Real { unit = kW; }
    value type MassValue :> Real { unit = kg; }
    value type FuelEfficiencyValue :> Real { unit = L_per_100km; }
    value type RadiusValue :> Real { unit = m; }
    value type TorqueValue :> Real { unit = N * m; }
    value type RotationalSpeedValue :> Real { unit = rad / s; }

    // ===== Item Definitions =====
    item def Fuel;

    item def Passenger;

    item def Cargo;

    item def Position {
        attribute latitude : Real;
        attribute longitude : Real;
    }

    item def Route {
        attribute startPoint : Position;
        attribute destination : Position;
        attribute estimatedDistance : LengthValue;
    }

    item def ThrottleCommand {
        attribute value : Real;
    }

    item def BrakeCommand {
        attribute value : Real;
    }

    item def SteeringCommand {
        attribute angle : Real;
    }

    // ===== Port Definitions =====
    port def FuelFlowPort {
        out item fuel : Fuel;
    }

    port def FuelIntakePort {
        in item fuel : Fuel;
    }

    port def MechanicalPowerOutputPort {
        out attribute torque : TorqueValue;
        out attribute rotationalSpeed : RotationalSpeedValue;
    }

    port def MechanicalPowerInputPort {
        in attribute torque : TorqueValue;
        in attribute rotationalSpeed : RotationalSpeedValue;
    }

    port def WheelDrivePort {
        in attribute torque : TorqueValue;
        in attribute rotationalSpeed : RotationalSpeedValue;
    }

    port def NavigationOutputPort {
        out item currentPosition : Position;
        out item plannedRoute : Route;
    }

    port def NavigationInputPort {
        in item currentPosition : Position;
        in item plannedRoute : Route;
    }

    port def CommandOutputPort {
        out item throttle : ThrottleCommand;
        out item brake : BrakeCommand;
        out item steering : SteeringCommand;
    }

    port def CommandInputPort {
        in item throttle : ThrottleCommand;
        in item brake : BrakeCommand;
        in item steering : SteeringCommand;
    }

    // ===== Part Definitions =====

    part def InternalCombustionEngine {
        attribute displacement : VolumeValue = 2.0 [liter];
        attribute maxPower : PowerValue = 150 [kW];
        attribute currentPower : PowerValue;
        attribute isRunning : Boolean = false;
        attribute fuelConsumptionRate : VolumeValue;

        port fuelIntake : FuelIntakePort;
        port powerOutput : MechanicalPowerOutputPort;

        attribute startSignal : Boolean = false;
        attribute stopSignal : Boolean = false;

        state engineStateMachine {
            entry; then Off;

            state Off {
                entry { isRunning = false; currentPower = 0 [kW]; }
            }

            state Running {
                entry { isRunning = true; }
            }

            transition off_to_running
                first Off then Running
                if startSignal;

            transition running_to_off
                first Running then Off
                if stopSignal;
        }
    }

    part def FuelTank {
        attribute capacity : VolumeValue = 60 [liter];
        attribute currentLevel : VolumeValue = 60 [liter];

        port fuelOutput : FuelFlowPort;

        action consumeFuel {
            in amount : VolumeValue;
        }

        action refuel {
            in amount : VolumeValue;
        }
    }

    part def Transmission {
        attribute gearRatio : Real = 3.5;
        attribute currentGear : Integer = 0;
        attribute minGear : Integer = 1;
        attribute maxGear : Integer = 6;

        port powerInput : MechanicalPowerInputPort;
        port powerOutput : MechanicalPowerOutputPort;

        action shiftGear {
            in targetGear : Integer;
        }
    }

    part def Differential {
        attribute gearRatio : Real = 3.0;
        attribute torqueSplitLeft : Real = 0.5;
        attribute torqueSplitRight : Real = 0.5;

        port powerInput : MechanicalPowerInputPort;
        port leftWheelOutput : WheelDrivePort;
        port rightWheelOutput : WheelDrivePort;
    }

    part def Drivetrain {
        part transmission : Transmission;
        part differential : Differential;

        connect transmission.powerOutput to differential.powerInput;
    }

    part def Wheel {
        attribute radius : RadiusValue = 0.35 [m];
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute slipRatio : Real = 0.0;
        attribute rollingResistance : Real;

        port driveInput : WheelDrivePort;
    }

    part def PassengerCompartment {
        attribute capacity : Integer = 5;
        attribute currentOccupancy : Integer = 0;

        in item passengers : Passenger[0..5];

        action loadPassengers {
            in count : Integer;
        }

        action unloadPassengers;
    }

    part def CargoCompartment {
        attribute maxPayload : MassValue = 500 [kg];
        attribute currentPayload : MassValue = 0 [kg];

        in item cargo : Cargo;

        action loadCargo {
            in weight : MassValue;
        }

        action unloadCargo;
    }

    part def NavigationSystem {
        attribute currentPosition : Position;
        attribute destination : Position;
        attribute plannedRoute : Route;
        attribute arrived : Boolean = false;
        attribute distanceRemaining : LengthValue;

        port navOutput : NavigationOutputPort;

        action planRoute {
            in start : Position;
            in dest : Position;
            out route : Route;
        }

        action updatePosition {
            in deltaLatitude : Real;
            in deltaLongitude : Real;
            out position : Position;
        }

        action checkArrival {
            in position : Position;
            in dest : Position;
            out isArrived : Boolean;
        }
    }

    part def ControlSystem {
        attribute targetSpeed : SpeedValue;
        attribute currentSpeed : SpeedValue;
        attribute speedLimit : SpeedValue = 130 [km_per_h];
        attribute heading : Real;

        port navInput : NavigationInputPort;
        port cmdOutput : CommandOutputPort;

        action manageThrottle {
            in target : SpeedValue;
            in current : SpeedValue;
            out throttle : ThrottleCommand;
        }

        action manageBrake {
            in target : SpeedValue;
            in current : SpeedValue;
            out brake : BrakeCommand;
        }

        action manageSteering {
            in route : Route;
            in position : Position;
            out steering : SteeringCommand;
        }
    }

    // ===== Connection Definitions =====
    connection def FuelLine {
        end source : FuelFlowPort;
        end target : FuelIntakePort;
    }

    connection def PowerShaft {
        end source : MechanicalPowerOutputPort;
        end target : MechanicalPowerInputPort;
    }

    connection def DriveShaft {
        end source : MechanicalPowerOutputPort;
        end target : WheelDrivePort;
    }

    connection def NavDataLink {
        end source : NavigationOutputPort;
        end target : NavigationInputPort;
    }

    connection def CommandLink {
        end source : CommandOutputPort;
        end target : CommandInputPort;
    }

    // ===== Automobile Part Definition =====
    part def Automobile {
        attribute totalMass : MassValue;
        attribute maxMass : MassValue = 2500 [kg];
        attribute speedLimit : SpeedValue = 130 [km_per_h];
        attribute fuelEfficiency : FuelEfficiencyValue;
        attribute currentSpeed : SpeedValue = 0 [km_per_h];
        attribute targetSpeed : SpeedValue;
        attribute ignitionOn : Boolean = false;
        attribute approachDestination : Boolean = false;
        attribute arrived : Boolean = false;

        part engine : InternalCombustionEngine;
        part fuelTank : FuelTank;
        part drivetrain : Drivetrain;
        part frontLeftWheel : Wheel;
        part frontRightWheel : Wheel;
        part rearLeftWheel : Wheel;
        part rearRightWheel : Wheel;
        part passengerCompartment : PassengerCompartment;
        part cargoCompartment : CargoCompartment;
        part navigationSystem : NavigationSystem;
        part controlSystem : ControlSystem;

        // Fuel system connection
        connect fuelTank.fuelOutput to engine.fuelIntake;

        // Powertrain connections
        connect engine.powerOutput to drivetrain.transmission.powerInput;

        // Drivetrain to drive wheels (rear-wheel drive configuration)
        connect drivetrain.differential.leftWheelOutput to rearLeftWheel.driveInput;
        connect drivetrain.differential.rightWheelOutput to rearRightWheel.driveInput;

        // Navigation to control system data link
        connect navigationSystem.navOutput to controlSystem.navInput;

        // Vehicle operational state machine
        state vehicleStateMachine {
            entry; then Parked;

            state Parked {
                entry { currentSpeed = 0 [km_per_h]; ignitionOn = false; }
            }

            state StartingUp {
                entry { ignitionOn = true; engine.startSignal = true; }
                exit { engine.startSignal = false; }
            }

            state Accelerating {
                entry { controlSystem.manageThrottle; }
            }

            state Cruising {
                entry { controlSystem.manageThrottle; controlSystem.manageSteering; }
            }

            state Decelerating {
                entry { controlSystem.manageBrake; }
            }

            transition parked_to_starting
                first Parked then StartingUp
                if ignitionOn;

            transition starting_to_accelerating
                first StartingUp then Accelerating
                if engine.isRunning;

            transition accelerating_to_cruising
                first Accelerating then Cruising
                if currentSpeed >= targetSpeed;

            transition cruising_to_decelerating
                first Cruising then Decelerating
                if approachDestination;

            transition decelerating_to_parked
                first Decelerating then Parked
                if currentSpeed == 0 [km_per_h];
        }

        // Transport mission action sequence
        action transportMission {
            in passengers : Passenger[0..5];
            in cargo : Cargo;
            in start : Position;
            in destination : Position;

            action loadPayload {
                in pax : Passenger[*] = passengers;
                in goods : Cargo = cargo;
            }

            action planRoute {
                in startPos : Position = start;
                in destPos : Position = destination;
                out route : Route;
            }

            action travel {
                in route : Route;

                action updatePosition;
                action consumeFuel;
                action checkArrival;

                succession first updatePosition then consumeFuel;
                succession first consumeFuel then checkArrival;
                succession first checkArrival then updatePosition if not arrived;
            }

            action unloadPayload;

            succession first loadPayload then planRoute;
            succession first planRoute then travel;
            succession first travel then unloadPayload;
        }
    }

    // ===== Requirement Definitions =====

    requirement def MaxMassRequirement {
        subject vehicle : Automobile;
        attribute maxTotalMass : MassValue = 2500 [kg];
        require vehicle.totalMass <= maxTotalMass;
    }

    requirement def SpeedLimitRequirement {
        subject vehicle : Automobile;
        attribute operationalSpeedLimit : SpeedValue = 130 [km_per_h];
        require vehicle.currentSpeed <= operationalSpeedLimit;
    }

    requirement def FuelEfficiencyRequirement {
        subject vehicle : Automobile;
        attribute targetEfficiency : FuelEfficiencyValue = 8.0 [L_per_100km];
        require vehicle.fuelEfficiency <= targetEfficiency;
    }

    requirement def EngineDisplacementRequirement {
        subject vehicle : Automobile;
        attribute requiredDisplacement : VolumeValue = 2.0 [liter];
        require vehicle.engine.displacement == requiredDisplacement;
    }

    requirement def EnginePowerRequirement {
        subject vehicle : Automobile;
        attribute requiredPower : PowerValue = 150 [kW];
        require vehicle.engine.maxPower == requiredPower;
    }

    requirement def FuelTankCapacityRequirement {
        subject vehicle : Automobile;
        attribute requiredCapacity : VolumeValue = 60 [liter];
        require vehicle.fuelTank.capacity == requiredCapacity;
    }

    requirement def PassengerCapacityRequirement {
        subject vehicle : Automobile;
        attribute requiredCapacity : Integer = 5;
        require vehicle.passengerCompartment.capacity == requiredCapacity;
    }

    requirement def CargoCapacityRequirement {
        subject vehicle : Automobile;
        attribute requiredMaxPayload : MassValue = 500 [kg];
        require vehicle.cargoCompartment.maxPayload == requiredMaxPayload;
    }

    requirement def WheelCountRequirement {
        subject vehicle : Automobile;
        attribute requiredWheelCount : Integer = 4;
        require requiredWheelCount == 4;
    }

    requirement def WheelRadiusRequirement {
        subject vehicle : Automobile;
        attribute requiredRadius : RadiusValue = 0.35 [m];
        require vehicle.frontLeftWheel.radius == requiredRadius;
    }

    requirement def NavigationSystemRequirement {
        subject vehicle : Automobile;
        require vehicle.navigationSystem.currentPosition <> vehicle.navigationSystem.destination;
    }

    requirement def ControlSystemRequirement {
        subject vehicle : Automobile;
        require vehicle.controlSystem.currentSpeed <= vehicle.controlSystem.speedLimit;
    }

    // ===== Requirement Usages =====
    requirement maxMassReq : MaxMassRequirement;
    requirement speedLimitReq : SpeedLimitRequirement;
    requirement fuelEfficiencyReq : FuelEfficiencyRequirement;
    requirement engineDispReq : EngineDisplacementRequirement;
    requirement enginePowerReq : EnginePowerRequirement;
    requirement fuelTankReq : FuelTankCapacityRequirement;
    requirement passengerCapReq : PassengerCapacityRequirement;
    requirement cargoCapReq : CargoCapacityRequirement;
    requirement wheelCountReq : WheelCountRequirement;
    requirement wheelRadiusReq : WheelRadiusRequirement;
    requirement navSysReq : NavigationSystemRequirement;
    requirement controlSysReq : ControlSystemRequirement;

    // ===== Automobile Instance with Requirement Satisfaction =====
    part automobileInstance : Automobile {
        attribute totalMass : MassValue = 2200 [kg];
        attribute fuelEfficiency : FuelEfficiencyValue = 7.5 [L_per_100km];

        satisfy maxMassReq;
        satisfy speedLimitReq;
        satisfy fuelEfficiencyReq;
        satisfy engineDispReq;
        satisfy enginePowerReq;
        satisfy fuelTankReq;
        satisfy passengerCapReq;
        satisfy cargoCapReq;
        satisfy wheelCountReq;
        satisfy wheelRadiusReq;
        satisfy navSysReq;
        satisfy controlSysReq;
    }
}
