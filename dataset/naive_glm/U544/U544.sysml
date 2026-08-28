package PulserPumpingSubsystem {
    import SI::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value def Pressure :> Real { unit "Pa"; }
    value def FlowRate :> Real { unit "m3/s"; }
    value def Volume :> Real { unit "m3"; }
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Frequency :> Real { unit "Hz"; }
    value def RotationalSpeed :> Real { unit "rad/s"; }
    value def Temperature :> Real { unit "K"; }
    value def Dimensionless :> Real { unit "1"; }

    // ---------- Item Types ----------
    item def HydraulicFluid;
    item def ElectricalPower;
    item def ControlSignal;
    item def PressureFeedback;
    item def FlowFeedback;

    // ---------- Port Definitions ----------
    port def FluidPort {
        out item HydraulicFluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }
    port def ElectricalPort {
        out item ElectricalPower;
        attribute voltage : Voltage;
        attribute current : Current;
    }
    port def ControlPort {
        out item ControlSignal;
        attribute commandFreq : Frequency;
    }
    port def FeedbackPort {
        out item PressureFeedback;
        attribute measuredPressure : Pressure;
    }
    port def FlowFeedbackPort {
        out item FlowFeedback;
        attribute measuredFlowRate : FlowRate;
        attribute totalVolume : Volume;
    }

    // ---------- Component Parts ----------
    part def SupplyTank {
        port fluidOut : FluidPort;
        attribute capacity : Volume = 0.05;
        attribute currentVolume : Volume = 0.05;
        attribute fluidTemp : Temperature = 293.15;
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute crackingPressure : Pressure = 5000.0;
        attribute isOpen : Boolean = false;
    }

    part def PulserPump {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port powerIn : ElectricalPort;
        port commandIn : ControlPort;
        attribute diaphragmFreq : Frequency = 0.0;
        attribute maxFreq : Frequency = 50.0;
        attribute displacement : Volume = 5.0e-5;
        attribute efficiency : Dimensionless = 0.85;
        attribute currentPressure : Pressure = 0.0;
    }

    part def PowerSupply {
        port powerOut : ElectricalPort;
        attribute outputVoltage : Voltage = 24.0;
        attribute maxCurrent : Current = 10.0;
        attribute isEnabled : Boolean = false;
    }

    part def Controller {
        port pressureFeedback : FeedbackPort;
        port flowFeedback : FlowFeedbackPort;
        port pumpCommand : ControlPort;
        port powerEnable :>> ElectricalPort;
        attribute setpoint : Pressure = 2.0e5;
        attribute actualPressure : Pressure = 0.0;
        attribute measuredFlow : FlowRate = 0.0;
        attribute totalVolume : Volume = 0.0;
        attribute kp : Dimensionless = 0.5;
        attribute ki : Dimensionless = 0.1;
        attribute integralError : Pressure = 0.0;
        attribute commandOutput : Frequency = 0.0;
        attribute highPressureThreshold : Pressure = 3.0e5;
        attribute lowFlowThreshold : FlowRate = 1.0e-6;
    }

    part def Accumulator {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute gasPrecharge : Pressure = 1.5e5;
        attribute volume : Volume = 0.001;
        attribute currentGasVolume : Volume = 0.001;
        attribute smoothingFactor : Dimensionless = 0.7;
    }

    part def FlowMeter {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port flowOut : FlowFeedbackPort;
        attribute measuredFlowRate : FlowRate = 0.0;
        attribute totalVolume : Volume = 0.0;
        attribute accuracy : Dimensionless = 0.01;
    }

    part def DischargeManifold {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute outputPressure : Pressure = 0.0;
    }

    part def PressureSensor {
        port sensePort : FluidPort;
        port feedbackOut : FeedbackPort;
        attribute measuredPressure : Pressure = 0.0;
        attribute accuracy : Dimensionless = 0.005;
    }

    // ---------- System ----------
    part def PulserPumpingSystem {
        // Subcomponents
        part supplyTank : SupplyTank;
        part inletCheckValve : CheckValve;
        part pulserPump : PulserPump;
        part powerSupply : PowerSupply;
        part controller : Controller;
        part outletCheckValve : CheckValve;
        part accumulator : Accumulator;
        part flowMeter : FlowMeter;
        part dischargeManifold : DischargeManifold;
        part pressureSensor : PressureSensor;

        // Connections
        connection supplyTank.fluidOut to inletCheckValve.inlet;
        connection inletCheckValve.outlet to pulserPump.inlet;
        connection powerSupply.powerOut to pulserPump.powerIn;
        connection controller.pumpCommand to pulserPump.commandIn;
        connection pulserPump.outlet to outletCheckValve.inlet;
        connection outletCheckValve.outlet to accumulator.inlet;
        connection accumulator.outlet to flowMeter.inlet;
        connection flowMeter.outlet to dischargeManifold.inlet;
        connection dischargeManifold.outlet to pressureSensor.sensePort;
        connection pressureSensor.feedbackOut to controller.pressureFeedback;
        connection flowMeter.flowOut to controller.flowFeedback;

        // System attributes
        attribute systemEnabled : Boolean = false;
        attribute targetPressure : Pressure = 2.0e5;
        attribute totalTransferred : Volume = 0.0;

        // ---------- State Machine ----------
        state behavior SystemOperation {
            entry; then Idle;

            state Idle {
                entry {
                    systemEnabled = false;
                    powerSupply.isEnabled = false;
                    pulserPump.diaphragmFreq = 0.0;
                }
            }

            transition Idle to Priming
                when systemEnabled == true;

            state Priming {
                entry {
                    powerSupply.isEnabled = true;
                    pulserPump.diaphragmFreq = 5.0;
                }
                do {
                    // Run pump at low frequency to fill lines
                    pulserPump.diaphragmFreq = 5.0;
                }
            }

            transition Priming to Running
                when controller.actualPressure > 0.5 * controller.setpoint;

            state Running {
                entry {
                    powerSupply.isEnabled = true;
                }
                do {
                    // Closed-loop pressure control
                    controller.integralError = controller.integralError +
                        (controller.setpoint - controller.actualPressure) * 0.1;
                    controller.commandOutput = controller.kp *
                        (controller.setpoint - controller.actualPressure) +
                        controller.ki * controller.integralError;
                    if (controller.commandOutput > pulserPump.maxFreq) {
                        controller.commandOutput = pulserPump.maxFreq;
                    }
                    if (controller.commandOutput < 0.0) {
                        controller.commandOutput = 0.0;
                    }
                    pulserPump.diaphragmFreq = controller.commandOutput;
                }
            }

            transition Running to Fault
                when controller.actualPressure > controller.highPressureThreshold
                    or controller.measuredFlow < controller.lowFlowThreshold;

            transition Running to Idle
                when systemEnabled == false;

            state Fault {
                entry {
                    systemEnabled = false;
                    powerSupply.isEnabled = false;
                    pulserPump.diaphragmFreq = 0.0;
                }
            }

            transition Fault to Idle
                when systemEnabled == false;
        }
    }

    // ---------- Requirements ----------
    requirement def PressureControlRequirement {
        doc "The system shall maintain discharge pressure within 5% of the setpoint during normal operation.";
        attribute setpoint : Pressure = 2.0e5;
        attribute tolerance : Dimensionless = 0.05;
        subject system : PulserPumpingSystem;
        require {
            abs(system.controller.actualPressure - system.controller.setpoint) <=
                system.controller.setpoint * tolerance
        }
    }

    requirement def FlowMeasurementRequirement {
        doc "The system shall measure flow rate and total volume transferred with at least 1% accuracy.";
        attribute minAccuracy : Dimensionless = 0.01;
        subject system : PulserPumpingSystem;
        require {
            system.flowMeter.accuracy <= minAccuracy
        }
    }

    requirement def SafetyRequirement {
        doc "The system shall enter a fault state and halt pump operation if discharge pressure exceeds the high-pressure threshold or flow falls below the low-flow threshold.";
        attribute highPressureLimit : Pressure = 3.0e5;
        attribute lowFlowLimit : FlowRate = 1.0e-6;
        subject system : PulserPumpingSystem;
        require {
            (system.controller.actualPressure > highPressureLimit or
             system.controller.measuredFlow < lowFlowLimit)
                implies system.SystemOperation.Fault.isActive
        }
    }

    requirement def PrimingRequirement {
        doc "The system shall support a priming state that operates the pump at reduced frequency until discharge pressure reaches at least 50% of setpoint.";
        subject system : PulserPumpingSystem;
        require {
            system.SystemOperation.Priming.isActive implies
                system.pulserPump.diaphragmFreq <= 10.0
        }
    }

    requirement def PowerRequirement {
        doc "The power supply shall provide 24 V DC at up to 10 A to drive the pulser pump.";
        attribute requiredVoltage : Voltage = 24.0;
        attribute requiredCurrent : Current = 10.0;
        subject system : PulserPumpingSystem;
        require {
            system.powerSupply.outputVoltage == requiredVoltage and
            system.powerSupply.maxCurrent >= requiredCurrent
        }
    }

    requirement def BackflowPreventionRequirement {
        doc "The system shall include check valves at pump inlet and outlet to prevent backflow of fluid.";
        subject system : PulserPumpingSystem;
        require {
            system.inletCheckValve :>> CheckValve and
            system.outletCheckValve :>> CheckValve
        }
    }

    requirement def AccumulatorSmoothingRequirement {
        doc "The accumulator shall smooth pressure pulses from the pulser pump to provide a continuous discharge stream.";
        attribute smoothingFactor : Dimensionless = 0.7;
        subject system : PulserPumpingSystem;
        require {
            system.accumulator.smoothingFactor >= smoothingFactor
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction satisfyPressureControl by PulserPumpingSystem satisfies PressureControlRequirement;
    satisfaction satisfyFlowMeasurement by PulserPumpingSystem satisfies FlowMeasurementRequirement;
    satisfaction satisfySafety by PulserPumpingSystem satisfies SafetyRequirement;
    satisfaction satisfyPriming by PulserPumpingSystem satisfies PrimingRequirement;
    satisfaction satisfyPower by PulserPumpingSystem satisfies PowerRequirement;
    satisfaction satisfyBackflow by PulserPumpingSystem satisfies BackflowPreventionRequirement;
    satisfaction satisfySmoothing by PulserPumpingSystem satisfies AccumulatorSmoothingRequirement;
}
