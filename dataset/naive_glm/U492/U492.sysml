package ElectromagneticPumpingSubsystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Pressure :> Real { unit 'Pa'; }
    value def FlowRate :> Real { unit 'm3/s'; }
    value def ElectricCurrent :> Real { unit 'A'; }
    value def Voltage :> Real { unit 'V'; }
    value def MagneticFluxDensity :> Real { unit 'T'; }
    value def Temperature :> Real { unit 'K'; }
    value def Power :> Real { unit 'W'; }
    value def Volume :> Real { unit 'm3'; }
    value def Length :> Real { unit 'm'; }
    value def Area :> Real { unit 'm2'; }

    // ===== Items =====
    item def ConductiveFluid {
        attribute electricalConductivity : Real = 1.0e6;
        attribute density : Real = 8000.0;
        attribute temperature : Temperature = 600.0;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        in out item fluid : ConductiveFluid;
        ref pressure : Pressure;
        ref flowRate : FlowRate;
    }

    port def ElectricalPowerPort {
        ref voltage : Voltage;
        ref current : ElectricCurrent;
    }

    port def PressureSignalPort {
        value pressure : Pressure;
    }

    port def FlowSignalPort {
        value flowRate : FlowRate;
    }

    port def CommandPort {
        value command : Real;
    }

    // ===== Requirements =====
    requirement def TransferFluidRequirement {
        doc "The subsystem shall transfer conductive fluid from the source tank to the destination tank at a desired flow rate."
        subject :> ConductiveFluid;
        attribute desiredFlowRate : FlowRate = 0.001;
        constraint { actualFlowRate >= desiredFlowRate * 0.95 }
    }

    requirement def SafetyRequirement {
        doc "The subsystem shall perform an emergency shutdown if the outlet pressure exceeds the safe limit."
        attribute safePressureLimit : Pressure = 5.0e6;
        constraint { outletPressure <= safePressureLimit }
    }

    requirement def ReliabilityRequirement {
        doc "The electromagnetic pump shall operate without any moving mechanical parts."
    }

    requirement def PrimingRequirement {
        doc "The subsystem shall prime the pump channel before normal operation by verifying inlet pressure."
        attribute minInletPressure : Pressure = 1.0e5;
        constraint { inletPressure >= minInletPressure }
    }

    // ===== Part Definitions =====

    part def SourceTank {
        port fluidOut : FluidPort;
        attribute capacity : Volume = 2.0;
        attribute currentVolume : Volume = 1.5;
        attribute fluidTemperature : Temperature = 600.0;
        doc "Holds the initial supply of conductive fluid.";
    }

    part def DestinationTank {
        port fluidIn : FluidPort;
        attribute capacity : Volume = 2.0;
        attribute currentVolume : Volume = 0.0;
        doc "Collects fluid after it has been pumped.";
    }

    part def InletValve {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        in port commandIn : CommandPort;
        attribute isOpen : Boolean = false;
        attribute openFraction : Real = 0.0;

        action def Open {
            doc "Fully open the inlet valve.";
        }
        action def Close {
            doc "Fully close the inlet valve.";
        }
        action def SetPosition(in fraction : Real) {
            doc "Set the valve to a partially open position.";
        }
    }

    part def PressureSensor {
        port fluidPort : FluidPort;
        out port signalOut : PressureSignalPort;
        attribute measuredPressure : Pressure = 0.0;
        attribute samplingRate : Real = 100.0;
        attribute accuracy : Real = 0.01;
        doc "Monitors pressure at the pump inlet or outlet.";
    }

    part def FlowMeter {
        port fluidPort : FluidPort;
        out port signalOut : FlowSignalPort;
        attribute measuredFlowRate : FlowRate = 0.0;
        attribute samplingRate : Real = 50.0;
        attribute accuracy : Real = 0.02;
        doc "Measures the actual rate of fluid transfer.";
    }

    part def PowerSupply {
        out port powerOut : ElectricalPowerPort;
        in port commandIn : CommandPort;
        attribute outputVoltage : Voltage = 0.0;
        attribute outputCurrent : ElectricCurrent = 0.0;
        attribute maxPower : Power = 100000.0;
        attribute maxVoltage : Voltage = 500.0;
        attribute maxCurrent : ElectricCurrent = 200.0;
        doc "High-capacity power supply providing electrical energy to the electromagnetic pump.";

        action def SetOutput(in targetVoltage : Voltage) {
            doc "Adjust the output voltage of the power supply.";
        }
        action def Shutdown {
            doc "Immediately reduce output to zero.";
        }
    }

    part def ElectromagneticPump {
        in port fluidIn : FluidPort;
        out port fluidOut : FluidPort;
        in port powerIn : ElectricalPowerPort;
        attribute magneticFieldStrength : MagneticFluxDensity = 1.5;
        attribute operatingCurrent : ElectricCurrent = 0.0;
        attribute maxOperatingPressure : Pressure = 5.0e6;
        attribute efficiency : Real = 0.85;
        attribute channelLength : Length = 0.5;
        attribute channelCrossSection : Area = 0.01;
        doc "Electromagnetic pump with no moving parts. Uses Lorentz force (J x B) to propel conductive fluid through the channel.";

        action def GenerateMagneticField {
            doc "Energize magnets to create the magnetic field across the channel.";
        }
        action def PassCurrentThroughFluid(in current : ElectricCurrent) {
            doc "Pass electric current through the conductive fluid in the channel.";
        }
    }

    part def Controller {
        in port inletPressureIn : PressureSignalPort;
        in port outletPressureIn : PressureSignalPort;
        in port flowRateIn : FlowSignalPort;
        out port powerCommandOut : CommandPort;
        out port valveCommandOut : CommandPort;

        attribute desiredFlowRate : FlowRate = 0.001;
        attribute safePressureLimit : Pressure = 5.0e6;
        attribute minInletPressure : Pressure = 1.0e5;
        attribute currentFlowRate : FlowRate = 0.0;
        attribute currentInletPressure : Pressure = 0.0;
        attribute currentOutletPressure : Pressure = 0.0;
        attribute proportionalGain : Real = 10.0;
        attribute integralGain : Real = 0.5;
        attribute integralError : Real = 0.0;
        attribute powerCommandValue : Real = 0.0;
        attribute valveCommandValue : Real = 0.0;

        doc "Integrated controller that monitors sensors, adjusts power, and manages operational states.";

        action def ComputeFlowError {
            in measuredFlow : FlowRate;
            in desiredFlow : FlowRate;
            out error : Real;
            doc "Compute the difference between desired and measured flow rate.";
        }

        action def AdjustPower {
            in flowError : Real;
            out powerCommand : Real;
            doc "PID control to adjust power supply output to maintain desired flow rate.";
        }

        action def EmergencyShutdown {
            doc "Set valve command to close and power command to zero.";
        }

        action def StartPriming {
            doc "Open inlet valve and begin ramping power supply.";
        }

        state machine PumpingStateMachine {
            state off {
                entry { /* Initialize outputs: powerCommandValue = 0.0; valveCommandValue = 0.0; */ }
                doc "System is powered down.";
            }
            state priming {
                entry { /* Call StartPriming: open valve, begin low-power ramp. */ }
                do { /* Monitor inlet pressure until priming is confirmed. */ }
                doc "Preparing the pump channel for operation.";
            }
            state running {
                entry { /* Normal operation begins; enable PID control. */ }
                do { /* Continuously adjust power to maintain desired flow rate. */ }
                doc "Normal pumping operation.";
            }
            state fault {
                entry { /* Call EmergencyShutdown: close valve, cut power. */ }
                do { /* Log fault condition and await manual reset. */ }
                doc "Fault condition detected; system shut down for safety.";
            }

            transition from off to priming when valveCommandOut.command > 0.0;
            transition from priming to running when flowRateIn.flowRate > 0.0;
            transition from priming to fault when inletPressureIn.pressure < minInletPressure;
            transition from running to fault when outletPressureIn.pressure > safePressureLimit;
            transition from running to off when valveCommandOut.command == 0.0;
            transition from fault to off when valveCommandOut.command < 0.0;
        }
    }

    // ===== Subsystem Assembly =====
    part pumpingSubsystem :> TransferFluidRequirement {
        doc "Automated electromagnetic pumping subsystem for transferring conductive fluids between two tanks.";

        part sourceTank : SourceTank;
        part inletValve : InletValve;
        part pump : ElectromagneticPump;
        part destinationTank : DestinationTank;
        part powerSupply : PowerSupply;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part controller : Controller;

        // Fluid pathway connections
        connection sourceToValve connect sourceTank.fluidOut to inletValve.fluidIn;
        connection valveToPump connect inletValve.fluidOut to pump.fluidIn;
        connection pumpToDestination connect pump.fluidOut to destinationTank.fluidIn;

        // Sensor fluid tap connections
        connection inletSensorTap connect pump.fluidIn to inletPressureSensor.fluidPort;
        connection outletSensorTap connect pump.fluidOut to outletPressureSensor.fluidPort;
        connection flowMeterTap connect pump.fluidOut to flowMeter.fluidPort;

        // Signal connections from sensors to controller
        connection inletPressureSignal connect inletPressureSensor.signalOut to controller.inletPressureIn;
        connection outletPressureSignal connect outletPressureSensor.signalOut to controller.outletPressureIn;
        connection flowRateSignal connect flowMeter.signalOut to controller.flowRateIn;

        // Electrical power connection
        connection powerConnection connect powerSupply.powerOut to pump.powerIn;

        // Control command connections
        connection powerCommandConnection connect controller.powerCommandOut to powerSupply.commandIn;
        connection valveCommandConnection connect controller.valveCommandOut to inletValve.commandIn;

        // Requirement satisfactions
        satisfy SafetyRequirement {
            subject outletPressureSensor.measuredPressure;
        }
        satisfy ReliabilityRequirement {
            subject pump;
        }
        satisfy PrimingRequirement {
            subject inletPressureSensor.measuredPressure;
        }
    }
}
