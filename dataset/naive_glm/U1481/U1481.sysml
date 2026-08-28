package ACtoDCConverter {
    public import ISQ::*;

    value type ACVoltage :> Real { unit = "V"; }
    value type DCVoltage :> Real { unit = "V"; }
    value type RippleVoltage :> Real { unit = "V"; }
    value type FrequencyValue :> Real { unit = "Hz"; }
    value type CurrentValue :> Real { unit = "A"; }
    value type ResistanceValue :> Real { unit = "Ω"; }
    value type CapacitanceValue :> Real { unit = "F"; }

    item def ACPower {
        attribute voltage : ACVoltage;
        attribute frequency : FrequencyValue;
    }

    item def PulsatingDCPower {
        attribute voltage : DCVoltage;
        attribute ripple : RippleVoltage;
    }

    item def SmoothDCPower {
        attribute voltage : DCVoltage;
        attribute ripple : RippleVoltage;
    }

    port def ACPort {
        flow power : ACPower;
    }

    port def PulsatingDCPort {
        flow power : PulsatingDCPower;
    }

    port def SmoothDCPort {
        flow power : SmoothDCPower;
    }

    port def MonitorPort {
        attribute measuredVoltage : DCVoltage;
        attribute status : String;
    }

    requirement def PowerConversionRequirement {
        doc /* The system shall convert 120V 60Hz AC input to a stable DC output suitable for powering electronic devices. */

        requirement ACInputRequirement {
            doc /* The system shall accept a 120V, 60Hz AC input from a standard wall outlet. */
            attribute nominalVoltage : ACVoltage = 120;
            attribute nominalFrequency : FrequencyValue = 60;
        }

        requirement DCOutputRequirement {
            doc /* The system shall provide a smoothed DC output within a safe and acceptable range. */
            attribute minVoltage : DCVoltage = 110;
            attribute maxVoltage : DCVoltage = 130;
            attribute maxRipple : RippleVoltage = 5;
        }

        requirement FaultProtectionRequirement {
            doc /* The system shall enter a fault state if the monitored output voltage is too high or too low. */
        }
    }

    part def Diode {
        attribute forwardVoltageDrop : DCVoltage = 0.7;
        attribute maxCurrent : CurrentValue = 1.0;
        port anode : ACPort;
        port cathode : PulsatingDCPort;
    }

    part def ACSource {
        attribute nominalVoltage : ACVoltage = 120;
        attribute nominalFrequency : FrequencyValue = 60;
        port acOut : ACPort;
    }

    part def BridgeRectifier {
        doc /* Full-wave bridge rectifier constructed from four diodes to flip the negative half of the AC sine wave. */
        attribute totalForwardVoltageDrop : DCVoltage = 1.4;
        port acIn : ACPort;
        port dcOut : PulsatingDCPort;

        part diode1 : Diode;
        part diode2 : Diode;
        part diode3 : Diode;
        part diode4 : Diode;

        flow connection from acIn to diode1.anode;
        flow connection from acIn to diode2.anode;
        flow connection from diode1.cathode to dcOut;
        flow connection from diode2.cathode to dcOut;
        flow connection from dcOut to diode3.anode;
        flow connection from dcOut to diode4.anode;
        flow connection from diode3.cathode to acIn;
        flow connection from diode4.cathode to acIn;
    }

    part def SmoothingCapacitor {
        doc /* Large smoothing capacitor that charges on voltage peaks and discharges to fill in valleys, reducing ripple. */
        attribute capacitance : CapacitanceValue = 0.01;
        attribute maxRipple : RippleVoltage = 5;
        attribute esr : ResistanceValue = 0.1;
        port input : PulsatingDCPort;
        port output : SmoothDCPort;
    }

    part def LoadResistor {
        doc /* Represents the electronic device being powered by the converter. */
        attribute resistance : ResistanceValue = 1000;
        attribute powerRating : CurrentValue = 0.5;
        port input : SmoothDCPort;
    }

    part def VoltageMonitor {
        doc /* Continuously checks the output voltage to ensure it stays within a safe and acceptable range. */
        attribute minSafeVoltage : DCVoltage = 110;
        attribute maxSafeVoltage : DCVoltage = 130;
        attribute measuredVoltage : DCVoltage;
        attribute status : String = "OK";
        port input : SmoothDCPort;
        port monitorOut : MonitorPort;

        action def MeasureVoltage {
            in dcInput : SmoothDCPower;
            out reading : DCVoltage;
        }

        action def EvaluateRange {
            in reading : DCVoltage;
            in minV : DCVoltage;
            in maxV : DCVoltage;
            out result : String;
        }

        action def UpdateOutput {
            in reading : DCVoltage;
            in result : String;
            out measuredOut : DCVoltage;
            out statusOut : String;
        }

        perform measure : MeasureVoltage;
        perform evaluate : EvaluateRange;
        perform update : UpdateOutput;
    }

    part def ConverterController {
        attribute systemStatus : String = "Idle";
        port monitorIn : MonitorPort;

        state machine ConverterStates {
            state Idle {
                entry { systemStatus = "Idle"; }
            }
            state Initializing {
                entry { systemStatus = "Initializing"; }
            }
            state Operating {
                state Rectifying {
                    entry { systemStatus = "Rectifying"; }
                }
                state Filtering {
                    entry { systemStatus = "Filtering"; }
                }
                state Supplying {
                    entry { systemStatus = "Supplying"; }
                }

                transition from Rectifying to Filtering;
                transition from Filtering to Supplying;
                transition from Supplying to Rectifying;
            }
            state Fault {
                entry { systemStatus = "Fault"; }
            }

            transition from Idle to Initializing
                when { monitorIn.status == "PowerAvailable" }

            transition from Initializing to Operating
                when { monitorIn.status == "Ready" }

            transition from Operating to Fault
                when { monitorIn.measuredVoltage > 130 }
                do { systemStatus = "Fault: Overvoltage"; }

            transition from Operating to Fault
                when { monitorIn.measuredVoltage < 110 }
                do { systemStatus = "Fault: Undervoltage"; }

            transition from Fault to Idle
                when { monitorIn.status == "Reset" }
        }
    }

    part def ACtoDCConverter {
        satisfy PowerConversionRequirement;

        port acInput : ACPort;
        port dcOutput : SmoothDCPort;

        part acSource : ACSource;
        part rectifier : BridgeRectifier;
        part capacitor : SmoothingCapacitor;
        part load : LoadResistor;
        part monitor : VoltageMonitor;
        part controller : ConverterController;

        flow connection from acSource.acOut to rectifier.acIn;
        flow connection from rectifier.dcOut to capacitor.input;
        flow connection from capacitor.output to load.input;
        flow connection from capacitor.output to monitor.input;
        connection from monitor.monitorOut to controller.monitorIn;
        flow connection from capacitor.output to dcOutput;
    }
}
