package PumpingSubsystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure;
    attribute def VolumeFlowRate :> ISQ::volumeFlowRate;
    attribute def RotationalSpeed :> ISQ::frequency;
    attribute def Torque :> ISQ::torque;
    attribute def Temperature :> ISQ::thermodynamicTemperature;
    attribute def Power :> ISQ::power;
    attribute def Efficiency :> ScalarValues::Real;
    attribute def Length :> ISQ::length;
    attribute def Time :> ISQ::time;

    item def HydraulicFluid {
        attribute density : ISQ::density;
        attribute dynamicViscosity : ISQ::dynamicViscosity;
        attribute bulkModulus : ISQ::pressure;
        attribute temperature : Temperature;
        attribute contaminationCode : String;
    }

    item def ElectricalPower {
        attribute voltage : ISQ::electricPotential;
        attribute current : ISQ::electricCurrent;
        attribute frequency : ISQ::frequency;
    }

    item def ShaftPower {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute mechanicalPower : Power;
    }

    item def ControlSignal {
        attribute enable : Boolean;
        attribute commandedSpeed : RotationalSpeed;
        attribute commandedPressure : Pressure;
        attribute emergencyStop : Boolean;
    }

    item def PumpStatus {
        attribute running : Boolean;
        attribute outletPressure : Pressure;
        attribute inletPressure : Pressure;
        attribute deliveredFlow : VolumeFlowRate;
        attribute caseTemperature : Temperature;
        attribute faultCode : String;
    }

    port def FluidInletPort {
        in item fluidIn : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def FluidOutletPort {
        out item fluidOut : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def ElectricPowerPort {
        in item powerIn : ElectricalPower;
    }

    port def RotationalMechanicalPort {
        out item shaftOut : ShaftPower;
        in item shaftIn : ShaftPower;
    }

    port def ControlInputPort {
        in item command : ControlSignal;
    }

    port def StatusOutputPort {
        out item status : PumpStatus;
    }

    port def DrainPort {
        out item leakageFluid : HydraulicFluid;
        attribute leakageFlow : VolumeFlowRate;
        attribute casePressure : Pressure;
    }

    part def ElectricMotor {
        port electricalInput : ElectricPowerPort;
        port shaftOutput : RotationalMechanicalPort;

        attribute ratedPower : Power = 7500 [W];
        attribute ratedSpeed : RotationalSpeed = 50 [Hz];
        attribute ratedTorque : Torque = 140 [N*m];
        attribute motorEfficiency : Efficiency = 0.91;

        action convertElectricalToShaftPower {
            in item electrical : ElectricalPower;
            out item shaft : ShaftPower;
            attribute outputSpeed : RotationalSpeed;
            attribute outputTorque : Torque;
        }
    }

    part def Coupling {
        port motorSide : RotationalMechanicalPort;
        port pumpSide : RotationalMechanicalPort;

        attribute torsionalStiffness : Real = 8500;
        attribute maximumTorque : Torque = 180 [N*m];
        attribute alignmentTolerance : Length = 0.15 [mm];
    }

    part def RadialPistonPump {
        port shaftInput : RotationalMechanicalPort;
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port caseDrain : DrainPort;

        attribute pistonCount : Integer = 7;
        attribute pistonDiameter : Length = 14 [mm];
        attribute pistonStroke : Length = 8 [mm];
        attribute displacementPerRevolution : ISQ::volume = 8.6 [cm^3];
        attribute nominalSpeed : RotationalSpeed = 40 [Hz];
        attribute maximumSpeed : RotationalSpeed = 60 [Hz];
        attribute minimumInletPressure : Pressure = 120000 [Pa];
        attribute ratedOutletPressure : Pressure = 21000000 [Pa];
        attribute maximumOutletPressure : Pressure = 25000000 [Pa];
        attribute volumetricEfficiency : Efficiency = 0.94;
        attribute mechanicalEfficiency : Efficiency = 0.88;
        attribute maximumCasePressure : Pressure = 300000 [Pa];
        attribute maximumFluidTemperature : Temperature = 353.15 [K];

        part cylinderBlock {
            attribute radialBoreCount : Integer = 7;
            attribute boreDiameter : Length = 14 [mm];
        }

        part pistons[7] {
            attribute diameter : Length = 14 [mm];
            attribute stroke : Length = 8 [mm];
            attribute shoeClearance : Length = 0.02 [mm];
        }

        part eccentricRing {
            attribute eccentricity : Length = 4 [mm];
            attribute surfaceHardness : Real = 58;
        }

        part inletCheckValve {
            port inlet : FluidInletPort;
            port outlet : FluidOutletPort;
            attribute crackingPressure : Pressure = 25000 [Pa];
            attribute reverseLeakageFlow : VolumeFlowRate = 0.02 [L/min];
        }

        part outletCheckValve {
            port inlet : FluidInletPort;
            port outlet : FluidOutletPort;
            attribute crackingPressure : Pressure = 45000 [Pa];
            attribute reverseLeakageFlow : VolumeFlowRate = 0.01 [L/min];
        }

        action drawFluid {
            in item suctionFluid : HydraulicFluid;
            out item chamberCharge : HydraulicFluid;
            attribute inletPressure : Pressure;
        }

        action compressFluid {
            in item chamberCharge : HydraulicFluid;
            out item pressurizedCharge : HydraulicFluid;
            attribute chamberPressure : Pressure;
        }

        action dischargeFluid {
            in item pressurizedCharge : HydraulicFluid;
            out item outletFluid : HydraulicFluid;
            attribute outletPressure : Pressure;
            attribute deliveredFlow : VolumeFlowRate;
        }

        state machine pumpCycle {
            state stopped;
            state priming;
            state rotating;
            state suctionStroke;
            state compressionStroke;
            state dischargeStroke;
            state pressureLimited;
            state faulted;

            transition initial then stopped;
            transition stopped_to_priming
                first stopped
                accept ControlSignal
                if command.enable and not command.emergencyStop
                then priming;

            transition priming_to_rotating
                first priming
                if suction.pressure >= minimumInletPressure
                then rotating;

            transition rotating_to_suction
                first rotating
                then suctionStroke
                do drawFluid;

            transition suction_to_compression
                first suctionStroke
                then compressionStroke
                do compressFluid;

            transition compression_to_discharge
                first compressionStroke
                if discharge.pressure <= maximumOutletPressure
                then dischargeStroke
                do dischargeFluid;

            transition discharge_to_suction
                first dischargeStroke
                then suctionStroke;

            transition pressure_limit
                first dischargeStroke
                if discharge.pressure > ratedOutletPressure
                then pressureLimited;

            transition pressure_recovered
                first pressureLimited
                if discharge.pressure <= ratedOutletPressure
                then suctionStroke;

            transition low_inlet_fault
                first priming, rotating, suctionStroke, compressionStroke, dischargeStroke, pressureLimited
                if suction.pressure < minimumInletPressure
                then faulted;

            transition overpressure_fault
                first compressionStroke, dischargeStroke, pressureLimited
                if discharge.pressure > maximumOutletPressure
                then faulted;

            transition overtemperature_fault
                first rotating, suctionStroke, compressionStroke, dischargeStroke, pressureLimited
                if caseDrain.leakageFluid.temperature > maximumFluidTemperature
                then faulted;

            transition emergency_stop
                first priming, rotating, suctionStroke, compressionStroke, dischargeStroke, pressureLimited
                accept ControlSignal
                if command.emergencyStop
                then stopped;

            transition reset_fault
                first faulted
                accept ControlSignal
                if not command.enable
                then stopped;
        }
    }

    part def SuctionFilter {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute absoluteRating : Length = 10 [um];
        attribute cleanPressureDrop : Pressure = 15000 [Pa];
        attribute cloggedPressureDrop : Pressure = 80000 [Pa];
        attribute maximumFlow : VolumeFlowRate = 35 [L/min];

        action filterFluid {
            in item unfilteredFluid : HydraulicFluid;
            out item filteredFluid : HydraulicFluid;
        }
    }

    part def ReliefValve {
        port inlet : FluidInletPort;
        port returnOutlet : FluidOutletPort;

        attribute crackingPressure : Pressure = 23000000 [Pa];
        attribute fullFlowPressure : Pressure = 24500000 [Pa];
        attribute ratedBypassFlow : VolumeFlowRate = 28 [L/min];

        state machine reliefValveState {
            state closed;
            state opening;
            state bypassing;

            transition initial then closed;
            transition closed_to_opening
                first closed
                if inlet.pressure >= crackingPressure
                then opening;

            transition opening_to_bypassing
                first opening
                if inlet.pressure >= fullFlowPressure
                then bypassing;

            transition bypassing_to_closed
                first bypassing
                if inlet.pressure < crackingPressure
                then closed;
        }
    }

    part def CheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute crackingPressure : Pressure = 30000 [Pa];
        attribute reverseLeakage : VolumeFlowRate = 0.01 [L/min];

        state machine checkValveState {
            state closed;
            state open;

            transition initial then closed;
            transition open_forward
                first closed
                if inlet.pressure > outlet.pressure + crackingPressure
                then open;

            transition close_reverse
                first open
                if inlet.pressure <= outlet.pressure
                then closed;
        }
    }

    part def Accumulator {
        port hydraulicPort : FluidInletPort;

        attribute prechargePressure : Pressure = 9000000 [Pa];
        attribute gasVolume : ISQ::volume = 1.5 [L];
        attribute maximumPressure : Pressure = 25000000 [Pa];
        attribute storedFluidVolume : ISQ::volume = 0.6 [L];

        action dampPressurePulsation {
            in item incomingFluid : HydraulicFluid;
            out item conditionedFluid : HydraulicFluid;
        }
    }

    part def Reservoir {
        port returnPort : FluidInletPort;
        port supplyPort : FluidOutletPort;
        port drainReturn : FluidInletPort;

        attribute usableVolume : ISQ::volume = 40 [L];
        attribute minimumFluidLevel : Length = 150 [mm];
        attribute normalFluidTemperature : Temperature = 313.15 [K];
    }

    part def PressureSensor {
        port sensedPort : FluidInletPort;
        port statusPort : StatusOutputPort;

        attribute rangeMinimum : Pressure = 0 [Pa];
        attribute rangeMaximum : Pressure = 25000000 [Pa];
        attribute accuracyPercentFullScale : Real = 0.5;
        attribute responseTime : Time = 0.01 [s];

        action measurePressure {
            in item fluid : HydraulicFluid;
            out attribute measuredPressure : Pressure;
        }
    }

    part def TemperatureSensor {
        port sensedPort : FluidInletPort;
        port statusPort : StatusOutputPort;

        attribute rangeMinimum : Temperature = 273.15 [K];
        attribute rangeMaximum : Temperature = 373.15 [K];
        attribute accuracy : Temperature = 1 [K];

        action measureTemperature {
            in item fluid : HydraulicFluid;
            out attribute measuredTemperature : Temperature;
        }
    }

    part def PumpController {
        port commandInput : ControlInputPort;
        port motorCommand : ControlInputPort;
        port pumpStatusInput : StatusOutputPort;
        port systemStatusOutput : StatusOutputPort;

        attribute pressureSetpoint : Pressure = 18000000 [Pa];
        attribute minimumStartPressure : Pressure = 120000 [Pa];
        attribute shutdownTemperature : Temperature = 353.15 [K];
        attribute speedCommandLimit : RotationalSpeed = 60 [Hz];

        action regulatePressure {
            in item status : PumpStatus;
            in item operatorCommand : ControlSignal;
            out item motorCommandSignal : ControlSignal;
        }

        state machine controllerState {
            state disabled;
            state standby;
            state starting;
            state regulating;
            state shutdown;
            state faulted;

            transition initial then disabled;
            transition enable_to_standby
                first disabled
                accept ControlSignal
                if command.enable and not command.emergencyStop
                then standby;

            transition standby_to_starting
                first standby
                if command.commandedPressure > 0 [Pa]
                then starting;

            transition starting_to_regulating
                first starting
                if pumpStatusInput.status.outletPressure >= minimumStartPressure
                then regulating
                do regulatePressure;

            transition regulating_to_standby
                first regulating
                accept ControlSignal
                if not command.enable
                then standby;

            transition overtemperature_shutdown
                first starting, regulating
                if pumpStatusInput.status.caseTemperature >= shutdownTemperature
                then shutdown;

            transition emergency_shutdown
                first standby, starting, regulating
                accept ControlSignal
                if command.emergencyStop
                then shutdown;

            transition shutdown_to_faulted
                first shutdown
                then faulted;

            transition reset
                first faulted
                accept ControlSignal
                if not command.enable and not command.emergencyStop
                then disabled;
        }
    }

    part def RadialPistonPumpingSubsystem {
        port suctionInterface : FluidInletPort;
        port dischargeInterface : FluidOutletPort;
        port electricalInterface : ElectricPowerPort;
        port commandInterface : ControlInputPort;
        port statusInterface : StatusOutputPort;
        port caseDrainInterface : DrainPort;

        attribute ratedSystemPressure : Pressure = 21000000 [Pa];
        attribute ratedSystemFlow : VolumeFlowRate = 20 [L/min];
        attribute maximumSystemPressure : Pressure = 25000000 [Pa];
        attribute continuousDutyPower : Power = 7500 [W];
        attribute allowableFluidTemperature : Temperature = 353.15 [K];

        part reservoir : Reservoir;
        part suctionFilter : SuctionFilter;
        part driveMotor : ElectricMotor;
        part coupling : Coupling;
        part pump : RadialPistonPump;
        part outletCheckValve : CheckValve;
        part reliefValve : ReliefValve;
        part accumulator : Accumulator;
        part dischargePressureSensor : PressureSensor;
        part inletPressureSensor : PressureSensor;
        part caseTemperatureSensor : TemperatureSensor;
        part controller : PumpController;

        connect electricalInterface to driveMotor.electricalInput;
        connect driveMotor.shaftOutput to coupling.motorSide;
        connect coupling.pumpSide to pump.shaftInput;

        connect suctionInterface to suctionFilter.inlet;
        connect suctionFilter.outlet to pump.suction;

        connect pump.discharge to outletCheckValve.inlet;
        connect outletCheckValve.outlet to dischargeInterface;
        connect outletCheckValve.outlet to accumulator.hydraulicPort;
        connect outletCheckValve.outlet to reliefValve.inlet;
        connect reliefValve.returnOutlet to reservoir.returnPort;

        connect pump.caseDrain to caseDrainInterface;
        connect caseDrainInterface to reservoir.drainReturn;

        connect pump.suction to inletPressureSensor.sensedPort;
        connect pump.discharge to dischargePressureSensor.sensedPort;
        connect pump.caseDrain to caseTemperatureSensor.sensedPort;

        connect commandInterface to controller.commandInput;
        connect controller.motorCommand to driveMotor.electricalInput;
        connect dischargePressureSensor.statusPort to controller.pumpStatusInput;
        connect controller.systemStatusOutput to statusInterface;

        action startSubsystem {
            in item command : ControlSignal;
            out item status : PumpStatus;
            first startController : controller.regulatePressure;
            then energizeMotor : driveMotor.convertElectricalToShaftPower;
            then primePump : pump.drawFluid;
        }

        action deliverPressurizedFluid {
            in item suctionFluid : HydraulicFluid;
            out item deliveredFluid : HydraulicFluid;
            first filter : suctionFilter.filterFluid;
            then draw : pump.drawFluid;
            then compress : pump.compressFluid;
            then discharge : pump.dischargeFluid;
            then dampPulsation : accumulator.dampPressurePulsation;
        }

        action protectAgainstOverpressure {
            in item pressurizedFluid : HydraulicFluid;
            out item bypassFluid : HydraulicFluid;
            if dischargeInterface.pressure >= reliefValve.crackingPressure {
                then bypassToReservoir;
            }
        }

        state machine subsystemOperation {
            state off;
            state ready;
            state priming;
            state pumping;
            state pressureHolding;
            state protectedByRelief;
            state stopped;
            state fault;

            transition initial then off;
            transition off_to_ready
                first off
                accept ControlSignal
                if command.enable and not command.emergencyStop
                then ready;

            transition ready_to_priming
                first ready
                if suctionInterface.pressure >= pump.minimumInletPressure
                then priming
                do startSubsystem;

            transition priming_to_pumping
                first priming
                if dischargeInterface.pressure > suctionInterface.pressure
                then pumping
                do deliverPressurizedFluid;

            transition pumping_to_holding
                first pumping
                if dischargeInterface.pressure >= controller.pressureSetpoint
                then pressureHolding;

            transition holding_to_pumping
                first pressureHolding
                if dischargeInterface.pressure < controller.pressureSetpoint
                then pumping;

            transition pressure_protection
                first pumping, pressureHolding
                if dischargeInterface.pressure >= reliefValve.crackingPressure
                then protectedByRelief
                do protectAgainstOverpressure;

            transition relief_recovered
                first protectedByRelief
                if dischargeInterface.pressure < controller.pressureSetpoint
                then pumping;

            transition command_stop
                first ready, priming, pumping, pressureHolding, protectedByRelief
                accept ControlSignal
                if not command.enable
                then stopped;

            transition emergency_stop
                first ready, priming, pumping, pressureHolding, protectedByRelief
                accept ControlSignal
                if command.emergencyStop
                then stopped;

            transition low_suction_fault
                first priming, pumping, pressureHolding
                if suctionInterface.pressure < pump.minimumInletPressure
                then fault;

            transition overpressure_fault
                first pumping, pressureHolding, protectedByRelief
                if dischargeInterface.pressure > maximumSystemPressure
                then fault;

            transition overtemperature_fault
                first pumping, pressureHolding
                if caseDrainInterface.leakageFluid.temperature > allowableFluidTemperature
                then fault;

            transition stopped_to_off
                first stopped
                then off;

            transition reset_fault
                first fault
                accept ControlSignal
                if not command.enable
                then off;
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : RadialPistonPumpingSubsystem;

        require constraint {
            subsystem.ratedSystemPressure >= 21000000 [Pa]
        }

        require constraint {
            subsystem.ratedSystemFlow >= 20 [L/min]
        }

        require constraint {
            subsystem.maximumSystemPressure <= 25000000 [Pa]
        }
    }

    requirement def RadialPistonPumpRequirement {
        subject pump : RadialPistonPump;

        require constraint {
            pump.pistonCount >= 5
        }

        require constraint {
            pump.volumetricEfficiency >= 0.90
        }

        require constraint {
            pump.maximumOutletPressure >= 25000000 [Pa]
        }

        require constraint {
            pump.minimumInletPressure <= 120000 [Pa]
        }
    }

    requirement def SafetyProtectionRequirement {
        subject subsystem : RadialPistonPumpingSubsystem;

        require constraint {
            subsystem.reliefValve.crackingPressure < subsystem.maximumSystemPressure
        }

        require constraint {
            subsystem.controller.shutdownTemperature <= subsystem.allowableFluidTemperature
        }
    }

    requirement def FluidCompatibilityRequirement {
        subject fluid : HydraulicFluid;

        require constraint {
            fluid.temperature <= 353.15 [K]
        }

        require constraint {
            fluid.dynamicViscosity >= 0.015 [Pa*s]
        }

        require constraint {
            fluid.dynamicViscosity <= 0.1 [Pa*s]
        }
    }

    part pumpingSubsystem : RadialPistonPumpingSubsystem;

    satisfy PumpingSubsystemRequirement by pumpingSubsystem;
    satisfy RadialPistonPumpRequirement by pumpingSubsystem.pump;
    satisfy SafetyProtectionRequirement by pumpingSubsystem;
}