package VehiclePrimaryFunctionModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import USCustomaryUnits::*;

    value def Speed :> ISQ::speed {
        unit = SI::km / SI::h;
    }

    value def Distance :> ISQ::length {
        unit = SI::km;
    }

    value def Mass :> ISQ::mass {
        unit = SI::kg;
    }

    value def Energy :> ISQ::energy {
        unit = SI::kJ;
    }

    value def Power :> ISQ::power {
        unit = SI::kW;
    }

    value def Force :> ISQ::force {
        unit = SI::N;
    }

    value def Time :> ISQ::time {
        unit = SI::s;
    }

    value def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degC;
    }

    value def ElectricPotential :> ISQ::electricPotential {
        unit = SI::V;
    }

    value def StateOfCharge {
        unit = SI::percent;
    }

    value def PassengerCount {
        unit = one;
    }

    enum def VehicleOperatingMode {
        enum idle;
        enum accelerating;
        enum cruising;
        enum braking;
        enum parked;
        enum faulted;
    }

    enum def GearSelection {
        enum park;
        enum reverse;
        enum neutral;
        enum drive;
    }

    item def Occupant {
        attribute mass : Mass;
        attribute seated : Boolean;
        attribute restrained : Boolean;
    }

    item def Driver :> Occupant {
        attribute licensed : Boolean;
        attribute alert : Boolean;
    }

    item def Passenger :> Occupant;

    item def Cargo {
        attribute mass : Mass;
        attribute secured : Boolean;
    }

    item def ElectricalEnergy {
        attribute amount : Energy;
        attribute voltage : ElectricPotential;
    }

    item def MechanicalPower {
        attribute power : Power;
        attribute torqueForceEquivalent : Force;
    }

    item def DriverCommand {
        attribute requestedAcceleration : ISQ::acceleration;
        attribute requestedBrakeForce : Force;
        attribute steeringAngle : ISQ::planeAngle;
        attribute gear : GearSelection;
    }

    item def VehicleMotion {
        attribute speed : Speed;
        attribute distanceTraveled : Distance;
        attribute heading : ISQ::planeAngle;
    }

    port def PassengerAccessPort {
        in item enteringOccupant : Occupant;
        out item exitingOccupant : Occupant;
    }

    port def CargoAccessPort {
        in item loadedCargo : Cargo;
        out item unloadedCargo : Cargo;
    }

    port def DriverControlPort {
        in item command : DriverCommand;
        out item motionFeedback : VehicleMotion;
        out attribute operatingMode : VehicleOperatingMode;
    }

    port def EnergyChargePort {
        in item suppliedEnergy : ElectricalEnergy;
        out attribute chargeAccepted : Boolean;
    }

    port def ElectricalPowerPort {
        inout item energyFlow : ElectricalEnergy;
    }

    port def MechanicalDrivePort {
        out item deliveredPower : MechanicalPower;
    }

    port def BrakeForcePort {
        in item requestedBrakeForce : Force;
        out item generatedBrakeForce : Force;
    }

    port def RoadInterfacePort {
        out item propulsionForce : Force;
        out item brakingForce : Force;
        in item roadLoadForce : Force;
        out item motion : VehicleMotion;
    }

    part def Vehicle {
        attribute curbMass : Mass = 1700 [SI::kg];
        attribute maximumPayloadMass : Mass = 550 [SI::kg];
        attribute maximumOccupants : PassengerCount = 5;
        attribute maximumSpeed : Speed = 180 [SI::km / SI::h];
        attribute nominalRange : Distance = 480 [SI::km];
        attribute operatingMode : VehicleOperatingMode = VehicleOperatingMode::parked;
        attribute currentSpeed : Speed = 0 [SI::km / SI::h];
        attribute odometer : Distance = 0 [SI::km];

        port passengerAccess : PassengerAccessPort;
        port cargoAccess : CargoAccessPort;
        port driverControls : DriverControlPort;
        port chargeInlet : EnergyChargePort;
        port roadInterface : RoadInterfacePort;

        part chassis : Chassis;
        part cabin : Cabin;
        part energyStorage : EnergyStorage;
        part propulsionSystem : PropulsionSystem;
        part brakingSystem : BrakingSystem;
        part steeringSystem : SteeringSystem;
        part vehicleController : VehicleController;
        part safetySystem : SafetySystem;

        connect chargeInlet to energyStorage.chargePort;
        connect energyStorage.powerOutput to propulsionSystem.powerInput;
        connect propulsionSystem.driveOutput to roadInterface;
        connect brakingSystem.brakeOutput to roadInterface;
        connect driverControls to vehicleController.driverInput;
        connect vehicleController.propulsionCommand to propulsionSystem.controlInput;
        connect vehicleController.brakeCommand to brakingSystem.controlInput;
        connect vehicleController.steeringCommand to steeringSystem.controlInput;
        connect safetySystem.vehicleStatus to vehicleController.safetyInput;
        connect cabin.passengerAccess to passengerAccess;
        connect cabin.cargoAccess to cargoAccess;

        perform action transportOccupantsAndCargo;
        exhibit state vehicleOperationalStates;
    }

    part def Chassis {
        attribute mass : Mass = 420 [SI::kg];
        attribute structuralLoadCapacity : Mass = 2300 [SI::kg];

        part frontAxle : Axle;
        part rearAxle : Axle;
        part suspension : Suspension;
        part bodyStructure : BodyStructure;
    }

    part def Axle {
        attribute ratedLoad : Mass = 1200 [SI::kg];
        part leftWheel : Wheel;
        part rightWheel : Wheel;
    }

    part def Wheel {
        attribute radius : ISQ::length = 0.34 [SI::m];
        attribute tirePressure : ISQ::pressure = 240 [SI::kPa];
    }

    part def Suspension {
        attribute rideHeight : ISQ::length = 0.16 [SI::m];
        attribute dampingCoefficient : ISQ::mechanicalImpedance = 3500 [SI::N * SI::s / SI::m];
    }

    part def BodyStructure {
        attribute aerodynamicDragCoefficient : Real = 0.29;
        attribute frontalArea : ISQ::area = 2.25 [SI::m ** 2];
    }

    part def Cabin {
        attribute seatCount : PassengerCount = 5;
        attribute interiorTemperature : Temperature = 22 [SI::degC];

        port passengerAccess : PassengerAccessPort;
        port cargoAccess : CargoAccessPort;

        part driverSeat : Seat;
        part frontPassengerSeat : Seat;
        part rearLeftSeat : Seat;
        part rearCenterSeat : Seat;
        part rearRightSeat : Seat;
        part climateControl : ClimateControl;
        part instrumentCluster : InstrumentCluster;
        part cargoCompartment : CargoCompartment;
    }

    part def Seat {
        attribute occupied : Boolean = false;
        attribute restraintLatched : Boolean = false;
        attribute occupantMass : Mass = 0 [SI::kg];
    }

    part def ClimateControl {
        attribute targetTemperature : Temperature = 22 [SI::degC];
        attribute blowerPower : Power = 0.8 [SI::kW];
    }

    part def InstrumentCluster {
        attribute displayedSpeed : Speed = 0 [SI::km / SI::h];
        attribute displayedRange : Distance = 0 [SI::km];
        attribute warningActive : Boolean = false;
    }

    part def CargoCompartment {
        attribute availableVolume : ISQ::volume = 0.55 [SI::m ** 3];
        attribute loadedMass : Mass = 0 [SI::kg];
    }

    part def EnergyStorage {
        attribute capacity : Energy = 270000 [SI::kJ];
        attribute usableEnergy : Energy = 248400 [SI::kJ];
        attribute stateOfCharge : StateOfCharge = 80 [SI::percent];
        attribute maximumDischargePower : Power = 180 [SI::kW];
        attribute maximumChargePower : Power = 120 [SI::kW];

        port chargePort : EnergyChargePort;
        port powerOutput : ElectricalPowerPort;

        exhibit state energyStorageStates;
    }

    part def PropulsionSystem {
        attribute peakPower : Power = 160 [SI::kW];
        attribute continuousPower : Power = 85 [SI::kW];
        attribute driveEfficiency : Real = 0.91;

        port powerInput : ElectricalPowerPort;
        port controlInput : DriverControlPort;
        port driveOutput : MechanicalDrivePort;

        part tractionInverter : TractionInverter;
        part tractionMotor : TractionMotor;
        part reductionGear : ReductionGear;

        connect powerInput to tractionInverter.dcInput;
        connect tractionInverter.acOutput to tractionMotor.electricalInput;
        connect tractionMotor.shaftOutput to reductionGear.motorInput;
        connect reductionGear.wheelOutput to driveOutput;
    }

    part def TractionInverter {
        attribute conversionEfficiency : Real = 0.96;
        attribute maximumVoltage : ElectricPotential = 420 [SI::V];

        port dcInput : ElectricalPowerPort;
        port acOutput : ElectricalPowerPort;
    }

    part def TractionMotor {
        attribute ratedPower : Power = 120 [SI::kW];
        attribute peakTorqueEquivalentForce : Force = 4200 [SI::N];

        port electricalInput : ElectricalPowerPort;
        port shaftOutput : MechanicalDrivePort;
    }

    part def ReductionGear {
        attribute gearRatio : Real = 9.1;

        port motorInput : MechanicalDrivePort;
        port wheelOutput : MechanicalDrivePort;
    }

    part def BrakingSystem {
        attribute maximumBrakeForce : Force = 9500 [SI::N];
        attribute regenerativeBrakePowerLimit : Power = 70 [SI::kW];

        port controlInput : DriverControlPort;
        port brakeOutput : BrakeForcePort;

        part hydraulicBrakes : FrictionBrakeSubsystem;
        part regenerativeBrakes : RegenerativeBrakeSubsystem;
    }

    part def FrictionBrakeSubsystem {
        attribute frontBrakeForceCapacity : Force = 6200 [SI::N];
        attribute rearBrakeForceCapacity : Force = 3300 [SI::N];
    }

    part def RegenerativeBrakeSubsystem {
        attribute maximumRecoveryPower : Power = 70 [SI::kW];
        attribute recoveryEfficiency : Real = 0.68;
    }

    part def SteeringSystem {
        attribute maximumSteeringAngle : ISQ::planeAngle = 35 [SI::deg];
        attribute steeringAssistPower : Power = 0.7 [SI::kW];

        port controlInput : DriverControlPort;
    }

    part def VehicleController {
        attribute selectedGear : GearSelection = GearSelection::park;
        attribute commandedMode : VehicleOperatingMode = VehicleOperatingMode::parked;
        attribute tractionEnabled : Boolean = false;
        attribute brakingEnabled : Boolean = true;

        port driverInput : DriverControlPort;
        port safetyInput : DriverControlPort;
        port propulsionCommand : DriverControlPort;
        port brakeCommand : DriverControlPort;
        port steeringCommand : DriverControlPort;

        perform action interpretDriverCommand;
        perform action coordinateLongitudinalMotion;
    }

    part def SafetySystem {
        attribute restraintReady : Boolean = true;
        attribute collisionWarningActive : Boolean = false;
        attribute emergencyStopRequested : Boolean = false;

        port vehicleStatus : DriverControlPort;

        part restraints : OccupantRestraintSystem;
        part stabilityControl : StabilityControlSystem;
        part diagnostics : DiagnosticSystem;
    }

    part def OccupantRestraintSystem {
        attribute airbagArmed : Boolean = true;
        attribute beltPretensionerReady : Boolean = true;
    }

    part def StabilityControlSystem {
        attribute yawRateLimit : ISQ::frequency = 0.8 [SI::Hz];
        attribute wheelSlipLimit : Real = 0.12;
    }

    part def DiagnosticSystem {
        attribute activeFaultCount : Integer = 0;
        attribute propulsionFault : Boolean = false;
        attribute brakeFault : Boolean = false;
        attribute energyStorageFault : Boolean = false;
    }

    action def TransportOccupantsAndCargo {
        in item driver : Driver;
        in item passengers : Passenger[0..4];
        in item cargo : Cargo[0..*];
        in attribute destinationDistance : Distance;
        in attribute requestedCruiseSpeed : Speed;
        out item completedMotion : VehicleMotion;
        out attribute deliveredSafely : Boolean;

        first start;
        then verifyReadiness;
        then acceptOccupantsAndCargo;
        then enablePropulsion;
        then travelToDestination;
        then stopVehicle;
        then releaseOccupantsAndCargo;
        then done;

        action start;
        action verifyReadiness;
        action acceptOccupantsAndCargo;
        action enablePropulsion;
        action travelToDestination;
        action stopVehicle;
        action releaseOccupantsAndCargo;
        action done;
    }

    action def InterpretDriverCommand {
        in item command : DriverCommand;
        out attribute selectedGear : GearSelection;
        out attribute requestedMode : VehicleOperatingMode;
    }

    action def CoordinateLongitudinalMotion {
        in item command : DriverCommand;
        in attribute currentSpeed : Speed;
        in attribute safetyInterlockOk : Boolean;
        out item propulsionRequest : MechanicalPower;
        out item brakeRequest : Force;
    }

    state def VehicleOperationalStates {
        entry action initializeVehicle;

        state parked;
        state ready;
        state moving;
        state braking;
        state charging;
        state faulted;

        transition initial then parked;

        transition parked_to_ready
            first parked
            accept DriverCommand
            if gear == GearSelection::drive and requestedAcceleration > 0 [SI::m / SI::s ** 2]
            then ready;

        transition ready_to_moving
            first ready
            accept DriverCommand
            if requestedAcceleration > 0 [SI::m / SI::s ** 2]
            then moving;

        transition moving_to_braking
            first moving
            accept DriverCommand
            if requestedBrakeForce > 0 [SI::N]
            then braking;

        transition braking_to_moving
            first braking
            accept DriverCommand
            if requestedBrakeForce == 0 [SI::N] and requestedAcceleration > 0 [SI::m / SI::s ** 2]
            then moving;

        transition moving_to_parked
            first moving
            accept DriverCommand
            if gear == GearSelection::park and requestedBrakeForce > 0 [SI::N]
            then parked;

        transition parked_to_charging
            first parked
            accept ElectricalEnergy
            then charging;

        transition charging_to_parked
            first charging
            if stateOfCharge >= 95 [SI::percent]
            then parked;

        transition any_to_faulted
            first parked, ready, moving, braking, charging
            if emergencyStopRequested or activeFaultCount > 0
            then faulted;

        state moving {
            entry action enableTraction;
            do action maintainDirectedMotion;
            exit action recordDistance;
        }

        state braking {
            entry action commandBrakeForce;
            do action reduceSpeed;
            exit action releaseBrakeForce;
        }

        state faulted {
            entry action disablePropulsion;
            do action holdSafeState;
        }
    }

    state def EnergyStorageStates {
        state idle;
        state discharging;
        state charging;
        state depleted;
        state protected;

        transition initial then idle;

        transition idle_to_discharging
            first idle
            if tractionEnabled and stateOfCharge > 5 [SI::percent]
            then discharging;

        transition discharging_to_idle
            first discharging
            if not tractionEnabled
            then idle;

        transition idle_to_charging
            first idle
            accept ElectricalEnergy
            then charging;

        transition charging_to_idle
            first charging
            if stateOfCharge >= 95 [SI::percent]
            then idle;

        transition discharging_to_depleted
            first discharging
            if stateOfCharge <= 5 [SI::percent]
            then depleted;

        transition idle_to_protected
            first idle
            if energyStorageFault
            then protected;
    }

    requirement def PrimaryVehicleFunctionRequirement {
        doc /* The vehicle shall transport a driver, optional passengers, and cargo from an origin to a destination over a road interface under driver control. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.maximumOccupants >= 1 and
            vehicle.nominalRange >= 100 [SI::km] and
            vehicle.maximumSpeed >= 100 [SI::km / SI::h]
        }
    }

    requirement def OccupantCapacityRequirement {
        doc /* The vehicle shall provide seating and restraint interfaces for up to five occupants including the driver. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.cabin.seatCount == 5
        }
    }

    requirement def PropulsionRequirement {
        doc /* The vehicle shall convert stored electrical energy into mechanical drive power sufficient for controlled road motion. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.propulsionSystem.peakPower >= 100 [SI::kW] and
            vehicle.energyStorage.maximumDischargePower >= vehicle.propulsionSystem.peakPower
        }
    }

    requirement def BrakingRequirement {
        doc /* The vehicle shall provide friction and regenerative braking to reduce vehicle speed and hold the vehicle stopped. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.brakingSystem.maximumBrakeForce >= 8000 [SI::N]
        }
    }

    requirement def DriverControlRequirement {
        doc /* The vehicle shall accept driver commands for acceleration, braking, steering, and gear selection. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.vehicleController.tractionEnabled implies vehicle.vehicleController.selectedGear == GearSelection::drive
        }
    }

    requirement def SafeTransportRequirement {
        doc /* The vehicle shall inhibit propulsion when a safety-critical fault is active. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.safetySystem.diagnostics.activeFaultCount > 0 implies
            vehicle.vehicleController.tractionEnabled == false
        }
    }

    requirement def EnergyRangeRequirement {
        doc /* The vehicle shall store enough usable energy to support the nominal high-level transport mission. */
        subject vehicle : Vehicle;
        require constraint {
            vehicle.energyStorage.usableEnergy >= 200000 [SI::kJ] and
            vehicle.nominalRange >= 400 [SI::km]
        }
    }

    satisfy PrimaryVehicleFunctionRequirement by Vehicle::transportOccupantsAndCargo;
    satisfy OccupantCapacityRequirement by Vehicle::cabin;
    satisfy PropulsionRequirement by Vehicle::propulsionSystem;
    satisfy BrakingRequirement by Vehicle::brakingSystem;
    satisfy DriverControlRequirement by Vehicle::vehicleController;
    satisfy SafeTransportRequirement by Vehicle::safetySystem;
    satisfy EnergyRangeRequirement by Vehicle::energyStorage;

    part vehicleSystem : Vehicle {
        attribute curbMass = 1700 [SI::kg];
        attribute maximumPayloadMass = 550 [SI::kg];
        attribute maximumOccupants = 5;
        attribute maximumSpeed = 180 [SI::km / SI::h];
        attribute nominalRange = 480 [SI::km];
    }
}