package ElectroosmoticPumpingSubsystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // Value types with units
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type FlowRate :> Real { unit "uL/min"; }
    value type Pressure :> Real { unit "Pa"; }
    value type pHValue :> Real;
    value type IonicStrength :> Real { unit "mol/L"; }
    value type ChannelLength :> Real { unit "mm"; }
    value type ChannelDiameter :> Real { unit "um"; }
    value type ElectricField :> Real { unit "V/m"; }
    value type TimeValue :> Real { unit "s"; }
    value type Temperature :> Real { unit "K"; }
    value type ZetaPotential :> Real { unit "mV"; }
    value type Viscosity :> Real { unit "mPa.s"; }
    value type Permittivity :> Real { unit "F/m"; }
    value type VolumeValue :> Real { unit "mL"; }
    value type CrossSectionalArea :> Real { unit "m2"; }

    // Enumerations
    enum def PumpState {
        idle = 0;
        priming = 1;
        operating = 2;
        fault = 3;
    }

    enum def FlowMode {
        normal = 0;
        highFlow = 1;
        lowFlow = 2;
    }

    // Signals
    signal def ActivateSignal;
    signal def FaultSignal;
    signal def ResetSignal;
    signal def HighFlowCommand;
    signal def LowFlowCommand;
    signal def NormalFlowCommand;
    signal def PrimingCompleteSignal;

    // Item definition
    item def PumpingFluid {
        attribute pH : pHValue = 7.0;
        attribute ionicStrength : IonicStrength = 0.01;
        attribute temperature : Temperature = 298.15;
        attribute viscosity : Viscosity = 1.0;
        attribute permittivity : Permittivity = 7.1e-10;
    }

    // Port definitions
    port def FluidPort {
        attribute flowRate : FlowRate = 0.0;
        item fluid : PumpingFluid;
    }

    port def ElectricalPowerPort {
        attribute voltage : Voltage = 0.0;
        attribute current : Current = 0.0;
    }

    port def ControlPort {
        attribute setVoltage : Voltage = 0.0;
        attribute enableSignal : Boolean = false;
        attribute flowMode : FlowMode = FlowMode::normal;
    }

    port def MeasurementPort {
        attribute measuredFlowRate : FlowRate = 0.0;
        attribute measuredPressure : Pressure = 0.0;
        attribute status : PumpState = PumpState::idle;
    }

    // Action definitions
    action def ComputeEOF {
        in appliedVoltage : Voltage;
        in viscosity : Viscosity;
        in permittivity : Permittivity;
        in zetaPotential : ZetaPotential;
        in channelLength : ChannelLength;
        in channelDiameter : ChannelDiameter;
        out resultingFlowRate : FlowRate;
    }

    action def RegulateVoltage {
        in targetVoltage : Voltage;
        in enableSignal : Boolean;
        out actualVoltage : Voltage;
        out outputCurrent : Current;
    }

    action def MeasureFlow {
        in fluidStream : PumpingFluid;
        out flowReading : FlowRate;
    }

    action def MeasurePressure {
        in fluidStream : PumpingFluid;
        out pressureReading : Pressure;
    }

    action def MonitorFlow {
        in flowReading : FlowRate;
        in pressureReading : Pressure;
        out adjustment : Voltage;
    }

    action def DetectFault {
        in flowReading : FlowRate;
        in pressureReading : Pressure;
        in voltage : Voltage;
        in current : Current;
        out faultStatus : Boolean;
    }

    action def AdjustVoltageForMode {
        in flowMode : FlowMode;
        in currentFlowRate : FlowRate;
        out newVoltage : Voltage;
    }

    action def Prime {
        in channelLength : ChannelLength;
        out complete : Boolean;
    }

    // Component definitions
    part def Microchannel {
        attribute length : ChannelLength = 50.0;
        attribute diameter : ChannelDiameter = 20.0;
        attribute zetaPotential : ZetaPotential = -50.0;
        attribute crossSectionalArea : CrossSectionalArea = 3.14159e-10;

        port inlet : FluidPort;
        port outlet : FluidPort;

        action computeFlow : ComputeEOF;
    }

    part def PlatinumElectrode {
        attribute electrodeType : String;
        attribute surfaceArea : Real = 1.0e-6;
        port electricalConnection : ElectricalPowerPort;
    }

    part def ElectroosmoticPump {
        part microchannel : Microchannel;
        part anode : PlatinumElectrode { :>> electrodeType = "anode"; }
        part cathode : PlatinumElectrode { :>> electrodeType = "cathode"; }

        attribute maxBackPressure : Pressure = 50000.0;
        attribute operatingVoltage : Voltage = 1000.0;
        attribute maxContinuousTime : TimeValue = 86400.0;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port powerInput : ElectricalPowerPort;
        port controlPort : ControlPort;

        connection fluidInlet_to_microchannel
            connect fluidInlet to microchannel.inlet;
        connection microchannel_to_fluidOutlet
            connect microchannel.outlet to fluidOutlet;
        connection anode_power
            connect anode.electricalConnection to powerInput;
        connection cathode_power
            connect cathode.electricalConnection to powerInput;
    }

    part def PowerSupply {
        attribute maxVoltage : Voltage = 3000.0;
        attribute currentLimit : Current = 0.1;
        attribute outputVoltage : Voltage = 0.0;
        attribute outputEnabled : Boolean = false;

        port powerOutput : ElectricalPowerPort;
        port controlInput : ControlPort;

        action regulateVoltage : RegulateVoltage;
    }

    part def SourceReservoir {
        attribute volume : VolumeValue = 10.0;
        attribute temperature : Temperature = 298.15;

        item storedFluid : PumpingFluid;
        port fluidOutput : FluidPort;

        action dispenseFluid {
            out fluid : PumpingFluid;
        }
    }

    part def CollectionChamber {
        attribute volume : VolumeValue = 50.0;

        item collectedFluid : PumpingFluid;
        port fluidInput : FluidPort;
    }

    part def FlowSensor {
        attribute measuringRange : FlowRate = 1000.0;
        attribute accuracy : Real = 0.01;

        port sensingPort : FluidPort;
        port measurementOutput : MeasurementPort;

        action measureFlow : MeasureFlow;
    }

    part def PressureSensor {
        attribute measuringRange : Pressure = 100000.0;
        attribute accuracy : Real = 0.02;

        port sensingPort : FluidPort;
        port measurementOutput : MeasurementPort;

        action measurePressure : MeasurePressure;
    }

    // State machine definition
    state def PumpOperationStateMachine {
        state idle;
        state priming;
        state operating;
        state fault;

        transition idle_to_priming
            first idle
            second priming
            accept ActivateSignal;

        transition priming_to_operating
            first priming
            second operating
            guard primingComplete
            accept PrimingCompleteSignal;

        // Operating substates
        state operating {
            state normalFlowMode;
            state highFlowMode;
            state lowFlowMode;

            transition normal_to_high
                first normalFlowMode
                second highFlowMode
                accept HighFlowCommand;

            transition high_to_normal
                first highFlowMode
                second normalFlowMode
                accept NormalFlowCommand;

            transition normal_to_low
                first normalFlowMode
                second lowFlowMode
                accept LowFlowCommand;

            transition low_to_normal
                first lowFlowMode
                second normalFlowMode
                accept NormalFlowCommand;

            entry action {
                // Begin normal flow on entry
            }
        }

        transition operating_to_fault
            first operating
            second fault
            guard faultDetected
            accept FaultSignal;

        transition fault_to_idle
            first fault
            second idle
            accept ResetSignal;
    }

    part def Controller {
        attribute currentState : PumpState = PumpState::idle;
        attribute flowMode : FlowMode = FlowMode::normal;
        attribute setVoltage : Voltage = 0.0;
        attribute faultDetected : Boolean = false;
        attribute primingComplete : Boolean = false;

        state pumpStateMachine : PumpOperationStateMachine;

        action monitorFlow : MonitorFlow;
        action detectFault : DetectFault;
        action adjustVoltageForMode : AdjustVoltageForMode;
        action prime : Prime;
    }

    // Top-level subsystem
    part ElectroosmoticPumpingSystem {
        part reservoir : SourceReservoir;
        part pump : ElectroosmoticPump;
        part powerSupply : PowerSupply;
        part collection : CollectionChamber;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part controller : Controller;

        // Fluid connections
        connection reservoir_to_pump
            connect reservoir.fluidOutput to pump.fluidInlet;
        connection pump_to_collection
            connect pump.fluidOutlet to collection.fluidInput;
        connection pump_to_flowSensor
            connect pump.fluidOutlet to flowSensor.sensingPort;
        connection pump_to_pressureSensor
            connect pump.fluidOutlet to pressureSensor.sensingPort;

        // Power connections
        connection powerSupply_to_pump
            connect powerSupply.powerOutput to pump.powerInput;

        // Control connections
        connection controller_to_powerSupply
            connect controller to powerSupply.controlInput;
        connection controller_to_pump
            connect controller to pump.controlPort;
        connection flowSensor_to_controller
            connect flowSensor.measurementOutput to controller;
        connection pressureSensor_to_controller
            connect pressureSensor.measurementOutput to controller;
    }

    // Requirements
    requirement def PumpingSystemRequirement {
        doc /* Base requirement for the electroosmotic pumping subsystem. */
    }

    requirement fluidTransport :> PumpingSystemRequirement {
        doc /* The system shall transport fluid through the microchannel by applying an electric field. */
    }

    requirement noMovingParts :> PumpingSystemRequirement {
        doc /* The electroosmotic pump shall have no moving parts. */
    }

    requirement highAccuracyHandling :> PumpingSystemRequirement {
        doc /* The system shall handle small fluid volumes with high accuracy. */
    }

    requirement preciseFlowControl :> PumpingSystemRequirement {
        doc /* The flow rate shall be precisely controlled by adjusting the voltage from the power supply. */
    }

    requirement flowModeControl :> PumpingSystemRequirement {
        doc /* The system shall support normal, high-flow, and low-flow operating modes. */
    }

    requirement reliableOperation :> PumpingSystemRequirement {
        doc /* The system shall be capable of operating continuously for long periods up to 86400 seconds. */
    }

    requirement backPressureHandling :> PumpingSystemRequirement {
        doc /* The system shall handle a defined amount of back pressure up to 50000 Pa. */
    }

    requirement safeShutdown :> PumpingSystemRequirement {
        doc /* The system shall enter a fault state to shut down safely if an error occurs. */
    }

    requirement definedChemicalProperties :> PumpingSystemRequirement {
        doc /* The fluid shall have defined chemical properties including pH and ionic strength. */
    }

    requirement stateBasedOperation :> PumpingSystemRequirement {
        doc /* The pump shall operate through idle, priming, and operating states. */
    }

    requirement platinumElectrodes :> PumpingSystemRequirement {
        doc /* The pump shall use platinum electrodes with an anode at the inlet and a cathode at the outlet. */
    }

    requirement monitoring :> PumpingSystemRequirement {
        doc /* The system shall monitor performance using dedicated flow and pressure sensors. */
    }

    // Requirement satisfactions
    satisfaction fluidTransport satisfy ElectroosmoticPumpingSystem;
    satisfaction noMovingParts satisfy pump;
    satisfaction preciseFlowControl satisfy controller.adjustVoltageForMode;
    satisfaction flowModeControl satisfy controller.flowMode;
    satisfaction reliableOperation satisfy pump.maxContinuousTime;
    satisfaction backPressureHandling satisfy pump.maxBackPressure;
    satisfaction safeShutdown satisfy controller.pumpStateMachine;
    satisfaction definedChemicalProperties satisfy reservoir.storedFluid;
    satisfaction stateBasedOperation satisfy controller.pumpStateMachine;
    satisfaction monitoring satisfy flowSensor;
}
