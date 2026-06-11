package PistonPumpSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def FlowRate :> Real {
        unit = "m^3/s";
    }

    attribute def Volume :> Real {
        unit = "m^3";
    }

    attribute def Length :> Real {
        unit = "m";
    }

    attribute def Area :> Real {
        unit = "m^2";
    }

    attribute def Force :> Real {
        unit = "N";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rev/min";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    attribute def ElectricalPower :> Real {
        unit = "W";
    }

    attribute def Current :> Real {
        unit = "A";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    item def HydraulicFluid {
        attribute density : Real = 850.0;
        attribute dynamicViscosity : Real = 0.032;
        attribute bulkModulus : Pressure = 1.4e9;
        attribute temperature : Temperature;
        attribute contaminationClass : String;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : ElectricalPower;
    }

    item def ControlSignal {
        attribute command : String;
        attribute setpointFlow : FlowRate;
        attribute setpointPressure : Pressure;
        attribute enable : Boolean;
    }

    item def SensorSignal {
        attribute measuredValue : Real;
        attribute valid : Boolean;
        attribute timestamp_s : Real;
    }

    port def FluidPort {
        inout item fluid : HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPort {
        in item energy : ElectricalEnergy;
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item status : SensorSignal;
    }

    port def SensorPort {
        out item signal : SensorSignal;
    }

    port def MechanicalDrivePort {
        attribute torque_Nm : Real;
        attribute speed : RotationalSpeed;
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute crackingPressure : Pressure = 25000.0;
        attribute reverseLeakageFlow : FlowRate = 1.0e-7;
        attribute open : Boolean;

        constraint noReverseFlow {
            outlet.flowRate >= 0.0;
        }

        state def ValveStates {
            state closed;
            state opening;
            state openState;
            state closing;

            initial then closed;

            transition closed_to_opening
                first closed
                accept when inlet.pressure > outlet.pressure + crackingPressure
                then opening;

            transition opening_to_open
                first opening
                then openState;

            transition open_to_closing
                first openState
                accept when inlet.pressure <= outlet.pressure
                then closing;

            transition closing_to_closed
                first closing
                then closed;
        }

        exhibit state valveBehavior : ValveStates;
    }

    part def Cylinder {
        port suction : FluidPort;
        port discharge : FluidPort;

        attribute boreArea : Area = 0.0020;
        attribute strokeLength : Length = 0.075;
        attribute clearanceVolume : Volume = 4.0e-5;
        attribute chamberVolume : Volume;
        attribute chamberPressure : Pressure;
        attribute internalLeakageFlow : FlowRate = 2.5e-6;

        constraint volumeBounds {
            chamberVolume >= clearanceVolume and
            chamberVolume <= clearanceVolume + boreArea * strokeLength;
        }

        action fill {
            in item incomingFluid : HydraulicFluid;
            out item chamberFluid : HydraulicFluid;
        }

        action compress {
            in item chamberFluid : HydraulicFluid;
            out item pressurizedFluid : HydraulicFluid;
        }

        action expel {
            in item pressurizedFluid : HydraulicFluid;
            out item deliveredFluid : HydraulicFluid;
        }
    }

    part def PistonAssembly {
        port hydraulicInterface : FluidPort;
        port driveInterface : MechanicalDrivePort;

        attribute pistonArea : Area = 0.0020;
        attribute stroke : Length = 0.075;
        attribute position : Length;
        attribute velocity_mps : Real;
        attribute hydraulicForce : Force;
        attribute sealLeakageFlow : FlowRate = 1.5e-6;

        constraint travelLimits {
            position >= 0.0 and position <= stroke;
        }

        constraint forceBalance {
            hydraulicForce == hydraulicInterface.pressure * pistonArea;
        }

        state def ReciprocatingMotion {
            state bottomDeadCenter;
            state suctionStroke;
            state topDeadCenter;
            state dischargeStroke;

            initial then bottomDeadCenter;

            transition start_suction
                first bottomDeadCenter
                then suctionStroke;

            transition reach_top
                first suctionStroke
                accept when position >= stroke
                then topDeadCenter;

            transition start_discharge
                first topDeadCenter
                then dischargeStroke;

            transition reach_bottom
                first dischargeStroke
                accept when position <= 0.0
                then bottomDeadCenter;
        }

        exhibit state pistonMotion : ReciprocatingMotion;
    }

    part def ElectricMotor {
        port electricalInput : ElectricalPort;
        port shaftOutput : MechanicalDrivePort;
        port control : ControlPort;

        attribute ratedPower : ElectricalPower = 1500.0;
        attribute ratedVoltage : Voltage = 48.0;
        attribute ratedSpeed : RotationalSpeed = 1800.0;
        attribute motorEfficiency : Efficiency = 0.88;
        attribute enabled : Boolean;
        attribute actualSpeed : RotationalSpeed;

        action startMotor {
            in item cmd : ControlSignal;
            out success : Boolean;
        }

        action stopMotor {
            out success : Boolean;
        }

        action regulateSpeed {
            in targetSpeed : RotationalSpeed;
            out actualSpeedOut : RotationalSpeed;
        }

        state def MotorOperatingStates {
            state off;
            state starting;
            state running;
            state stopping;
            state faulted;

            initial then off;

            transition off_to_starting
                first off
                accept ControlSignal
                if control.command.enable
                then starting;

            transition starting_to_running
                first starting
                then running;

            transition running_to_stopping
                first running
                accept ControlSignal
                if not control.command.enable
                then stopping;

            transition stopping_to_off
                first stopping
                then off;

            transition any_to_faulted
                first running
                accept when electricalInput.supplyVoltage < 42.0
                then faulted;
        }

        exhibit state motorBehavior : MotorOperatingStates;
    }

    part def PressureSensor {
        port sensedFluid : FluidPort;
        port output : SensorPort;

        attribute rangeMin : Pressure = 0.0;
        attribute rangeMax : Pressure = 2.0e7;
        attribute accuracy : Pressure = 50000.0;
        attribute measuredPressure : Pressure;

        action samplePressure {
            out item signal : SensorSignal;
        }
    }

    part def FlowSensor {
        port sensedFluid : FluidPort;
        port output : SensorPort;

        attribute rangeMin : FlowRate = 0.0;
        attribute rangeMax : FlowRate = 0.002;
        attribute accuracy : FlowRate = 1.0e-5;
        attribute measuredFlow : FlowRate;

        action sampleFlow {
            out item signal : SensorSignal;
        }
    }

    part def PumpController {
        port operatorCommand : ControlPort;
        port motorCommand : ControlPort;
        port pressureFeedback : SensorPort;
        port flowFeedback : SensorPort;

        attribute demandedFlow : FlowRate = 6.0e-4;
        attribute pressureLimit : Pressure = 1.2e7;
        attribute lowPressureLimit : Pressure = 5.0e4;
        attribute commandedSpeed : RotationalSpeed;
        attribute shutdownRequested : Boolean;
        attribute faultActive : Boolean;

        action computeSpeedCommand {
            in requestedFlow : FlowRate;
            in measuredFlow : FlowRate;
            out speedSetpoint : RotationalSpeed;
        }

        action monitorProtection {
            in measuredPressure : Pressure;
            in measuredFlow : FlowRate;
            out trip : Boolean;
        }

        state def ControlStates {
            state disabled;
            state priming;
            state regulating;
            state pressureLimited;
            state shutdown;
            state fault;

            initial then disabled;

            transition enable_to_priming
                first disabled
                accept ControlSignal
                if operatorCommand.command.enable
                then priming;

            transition primed_to_regulating
                first priming
                accept when pressureFeedback.signal.valid and flowFeedback.signal.valid
                then regulating;

            transition regulating_to_pressureLimited
                first regulating
                accept when pressureFeedback.signal.measuredValue >= pressureLimit
                then pressureLimited;

            transition pressureLimited_to_regulating
                first pressureLimited
                accept when pressureFeedback.signal.measuredValue < pressureLimit * 0.92
                then regulating;

            transition regulating_to_shutdown
                first regulating
                accept ControlSignal
                if not operatorCommand.command.enable
                then shutdown;

            transition shutdown_to_disabled
                first shutdown
                then disabled;

            transition protection_trip
                first regulating
                accept when faultActive
                then fault;
        }

        exhibit state controllerBehavior : ControlStates;
    }

    part def ReliefValve {
        port inlet : FluidPort;
        port returnPort : FluidPort;

        attribute setPressure : Pressure = 1.3e7;
        attribute reseatPressure : Pressure = 1.1e7;
        attribute bypassFlow : FlowRate;
        attribute open : Boolean;

        state def ReliefStates {
            state closed;
            state relieving;

            initial then closed;

            transition open_relief
                first closed
                accept when inlet.pressure >= setPressure
                then relieving;

            transition close_relief
                first relieving
                accept when inlet.pressure <= reseatPressure
                then closed;
        }

        exhibit state reliefBehavior : ReliefStates;
    }

    part def FluidReservoir {
        port outlet : FluidPort;
        port returnInlet : FluidPort;

        attribute capacity : Volume = 0.020;
        attribute usableVolume : Volume = 0.016;
        attribute fluidLevel : Volume;
        attribute vented : Boolean = true;
        attribute reservoirPressure : Pressure = 101325.0;

        constraint levelLimits {
            fluidLevel >= 0.0 and fluidLevel <= capacity;
        }
    }

    part def PistonPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port drivePort : MechanicalDrivePort;

        part piston : PistonAssembly;
        part chamber : Cylinder;
        part suctionValve : CheckValve {
            crackingPressure = 15000.0;
        }
        part dischargeValve : CheckValve {
            crackingPressure = 30000.0;
        }

        attribute displacementPerStroke : Volume = 1.5e-4;
        attribute volumetricEfficiency : Efficiency = 0.91;
        attribute mechanicalEfficiency : Efficiency = 0.84;
        attribute maximumDischargePressure : Pressure = 1.5e7;
        attribute nominalFlowRate : FlowRate = 5.5e-4;
        attribute actualFlowRate : FlowRate;

        connect suctionPort to suctionValve.inlet;
        connect suctionValve.outlet to chamber.suction;
        connect chamber.discharge to dischargeValve.inlet;
        connect dischargeValve.outlet to dischargePort;
        connect piston.hydraulicInterface to chamber.discharge;
        connect drivePort to piston.driveInterface;

        constraint theoreticalFlow {
            actualFlowRate == displacementPerStroke * drivePort.speed * volumetricEfficiency / 60.0;
        }

        constraint pressureLimit {
            dischargePort.pressure <= maximumDischargePressure;
        }

        action pumpCycle {
            first chamber.fill;
            then chamber.compress;
            then chamber.expel;
        }

        state def PumpOperatingStates {
            state idle;
            state suction;
            state compression;
            state discharge;
            state cavitationRisk;
            state overPressure;

            initial then idle;

            transition idle_to_suction
                first idle
                accept when drivePort.speed > 0.0
                then suction;

            transition suction_to_compression
                first suction
                accept when piston.position >= piston.stroke
                then compression;

            transition compression_to_discharge
                first compression
                accept when chamber.chamberPressure > dischargePort.pressure + dischargeValve.crackingPressure
                then discharge;

            transition discharge_to_suction
                first discharge
                accept when piston.position <= 0.0
                then suction;

            transition suction_to_cavitationRisk
                first suction
                accept when suctionPort.pressure < 40000.0
                then cavitationRisk;

            transition any_to_overPressure
                first discharge
                accept when dischargePort.pressure > maximumDischargePressure
                then overPressure;
        }

        exhibit state pumpBehavior : PumpOperatingStates;
    }

    part def PistonPumpingSubsystem {
        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port electricalSupply : ElectricalPort;
        port commandInterface : ControlPort;
        port returnLine : FluidPort;

        part reservoir : FluidReservoir;
        part motor : ElectricMotor;
        part pump : PistonPump;
        part controller : PumpController;
        part outletPressureSensor : PressureSensor;
        part outletFlowSensor : FlowSensor;
        part reliefValve : ReliefValve;

        attribute subsystemNominalFlow : FlowRate = 5.5e-4;
        attribute subsystemMaxPressure : Pressure = 1.3e7;
        attribute allowedFluidTemperatureMin : Temperature = 273.15;
        attribute allowedFluidTemperatureMax : Temperature = 353.15;
        attribute primeTimeLimit_s : Real = 8.0;
        attribute dryRunDetected : Boolean;
        attribute maintenanceInterval_h : Real = 2000.0;

        connect electricalSupply to motor.electricalInput;
        connect commandInterface to controller.operatorCommand;
        connect controller.motorCommand to motor.control;
        connect motor.shaftOutput to pump.drivePort;

        connect fluidInlet to reservoir.outlet;
        connect reservoir.outlet to pump.suctionPort;
        connect pump.dischargePort to outletPressureSensor.sensedFluid;
        connect pump.dischargePort to outletFlowSensor.sensedFluid;
        connect pump.dischargePort to reliefValve.inlet;
        connect reliefValve.returnPort to reservoir.returnInlet;
        connect pump.dischargePort to fluidOutlet;
        connect returnLine to reservoir.returnInlet;

        connect outletPressureSensor.output to controller.pressureFeedback;
        connect outletFlowSensor.output to controller.flowFeedback;

        constraint deliveredPressureCapability {
            fluidOutlet.pressure <= subsystemMaxPressure;
        }

        constraint suctionAvailable {
            pump.suctionPort.pressure >= 40000.0;
        }

        constraint operatingTemperature {
            pump.suctionPort.fluid.temperature >= allowedFluidTemperatureMin and
            pump.suctionPort.fluid.temperature <= allowedFluidTemperatureMax;
        }

        action initializeSubsystem {
            first motor.stopMotor;
            then outletPressureSensor.samplePressure;
            then outletFlowSensor.sampleFlow;
        }

        action startPumping {
            first controller.computeSpeedCommand;
            then motor.startMotor;
            then pump.pumpCycle;
        }

        action controlledOperation {
            first outletPressureSensor.samplePressure;
            then outletFlowSensor.sampleFlow;
            then controller.monitorProtection;
            then controller.computeSpeedCommand;
            then motor.regulateSpeed;
            then pump.pumpCycle;
        }

        action shutdownSubsystem {
            first motor.stopMotor;
        }

        state def SubsystemLifecycle {
            state off;
            state initializing;
            state ready;
            state pumping;
            state relieving;
            state controlledStop;
            state faulted;

            initial then off;

            transition power_on
                first off
                accept ControlSignal
                if commandInterface.command.enable
                then initializing;

            transition initialized
                first initializing
                then ready;

            transition start_flow
                first ready
                accept when controller.demandedFlow > 0.0
                then pumping;

            transition pressure_relief
                first pumping
                accept when fluidOutlet.pressure >= reliefValve.setPressure
                then relieving;

            transition relief_complete
                first relieving
                accept when fluidOutlet.pressure <= reliefValve.reseatPressure
                then pumping;

            transition stop_requested
                first pumping
                accept ControlSignal
                if not commandInterface.command.enable
                then controlledStop;

            transition stopped
                first controlledStop
                then off;

            transition fault_low_suction
                first pumping
                accept when pump.suctionPort.pressure < 40000.0
                then faulted;

            transition fault_overpressure
                first pumping
                accept when fluidOutlet.pressure > subsystemMaxPressure
                then faulted;
        }

        exhibit state subsystemBehavior : SubsystemLifecycle;
    }

    requirement def PumpFluidRequirement {
        subject subsystem : PistonPumpingSubsystem;

        require constraint {
            subsystem.fluidOutlet.flowRate >= 5.0e-4 and
            subsystem.fluidOutlet.pressure <= subsystem.subsystemMaxPressure
        }

        doc /* The subsystem shall deliver hydraulic fluid from inlet to outlet at no less than 5.0e-4 m^3/s while remaining below the maximum operating pressure. */
    }

    requirement def PistonPumpArchitectureRequirement {
        subject subsystem : PistonPumpingSubsystem;

        require constraint {
            subsystem.pump.displacementPerStroke > 0.0 and
            subsystem.pump.piston.stroke > 0.0 and
            subsystem.pump.chamber.boreArea > 0.0
        }

        doc /* The subsystem shall use a reciprocating piston pump with a positive displacement chamber, piston assembly, suction check valve, and discharge check valve. */
    }

    requirement def PressureProtectionRequirement {
        subject subsystem : PistonPumpingSubsystem;

        require constraint {
            subsystem.reliefValve.setPressure <= subsystem.subsystemMaxPressure and
            subsystem.pump.maximumDischargePressure >= subsystem.subsystemMaxPressure
        }

        doc /* The subsystem shall protect downstream equipment from overpressure using controller shutdown and a relief valve returning fluid to the reservoir. */
    }

    requirement def PrimingRequirement {
        subject subsystem : PistonPumpingSubsystem;

        require constraint {
            subsystem.primeTimeLimit_s <= 8.0 and
            subsystem.pump.suctionPort.pressure >= 40000.0
        }

        doc /* The subsystem shall complete priming within 8 seconds when suction pressure is sufficient. */
    }

    requirement def SensorFeedbackRequirement {
        subject subsystem : PistonPumpingSubsystem;

        require constraint {
            subsystem.outletPressureSensor.rangeMax >= subsystem.subsystemMaxPressure and
            subsystem.outletFlowSensor.rangeMax >= subsystem.subsystemNominalFlow
        }

        doc /* The subsystem shall measure outlet pressure and flow for closed-loop control and protective shutdown. */
    }

    requirement def ElectricalSupplyRequirement {
        subject subsystem : PistonPumpingSubsystem;

        require constraint {
            subsystem.electricalSupply.supplyVoltage >= 42.0 and
            subsystem.electricalSupply.supplyVoltage <= 56.0
        }

        doc /* The subsystem shall operate from a nominal 48 V DC electrical supply with allowable voltage range from 42 V to 56 V. */
    }

    part pistonPumpSubsystem : PistonPumpingSubsystem;

    satisfy PumpFluidRequirement by pistonPumpSubsystem;
    satisfy PistonPumpArchitectureRequirement by pistonPumpSubsystem;
    satisfy PressureProtectionRequirement by pistonPumpSubsystem;
    satisfy PrimingRequirement by pistonPumpSubsystem;
    satisfy SensorFeedbackRequirement by pistonPumpSubsystem;
    satisfy ElectricalSupplyRequirement by pistonPumpSubsystem;
}