package PLCSystem {

    import ScalarValues::*;

    doc /*
     * Power-Line Communication (PLC) System
     *
     * Transmits digital network data over standard electrical wiring,
     * turning any power outlet into a network port.  Supports bidirectional
     * communication without interfering with normal electricity delivery.
     */

    // ===== Units =====
    unit def volt;
    unit def megahertz;
    unit def megabit_per_second;
    unit def meter;
    unit def dBm;

    // ===== Value Types =====
    value def Voltage :> Real { unit = volt; }
    value def Frequency :> Real { unit = megahertz; }
    value def DataRate :> Real { unit = megabit_per_second; }
    value def Distance :> Real { unit = meter; }
    value def SignalPower :> Real { unit = dBm; }

    // ===== Item Types =====
    item def DataPacket {
        doc "Standard digital network data packet from a computer or router.";
        attribute size : Integer;
        attribute payload : String;
    }

    item def AnalogSignal {
        doc "High-frequency analog carrier signal for power-line transmission.";
        attribute carrierFreq : Frequency;
        attribute amplitude : Voltage;
    }

    // ===== Port Definitions =====
    port def DigitalDataPort {
        out item txPacket : DataPacket;
        in item rxPacket : DataPacket;
    }

    port def AnalogSignalPort {
        out item txSignal : AnalogSignal;
        in item rxSignal : AnalogSignal;
    }

    port def PowerLinePort {
        in out item signal : AnalogSignal;
    }

    // ===== Requirements =====
    requirement def PLCSystemRequirement {
        subject plcSystem : PLCSystem;
        doc "The PLC system shall transmit digital network data over standard electrical wiring, turning any power outlet into a network port.";

        requirement bidirectionalComm {
            doc "The system shall support bidirectional communication, sending and receiving data without interfering with the normal delivery of electricity.";
        }

        requirement noPowerInterference {
            doc "The system shall not interfere with the standard 50/60 Hz electrical current delivery.";
        }
    }

    requirement def ModemRequirement {
        subject modem : PLCModem;
        doc "Requirements for the PLC Modem digital processing core.";

        requirement frequencyRange {
            doc "The modem shall operate in the 2-30 MHz frequency range to avoid interfering with 50/60 Hz electrical current.";
            constraint { modem.operatingFreq >= 2.0 and modem.operatingFreq <= 30.0 }
        }

        requirement dataRateSupport {
            doc "The modem shall support data rates up to 200 Mbps.";
            constraint { modem.maxDataRate <= 200.0 }
        }

        requirement modulationCapability {
            doc "The modem shall modulate digital data packets into high-frequency analog signals suitable for transmission over power lines.";
        }

        requirement demodulationCapability {
            doc "The modem shall demodulate incoming analog signals back into digital data packets.";
        }
    }

    requirement def AFERequirement {
        subject afe : AnalogFrontEnd;
        doc "Requirements for the Analog Front End physical interface.";

        requirement voltageIsolation {
            doc "The AFE shall isolate the modem from line voltage up to 1000 V.";
            constraint { afe.maxIsolationVoltage >= 1000.0 }
        }

        requirement signalCoupling {
            doc "The AFE shall safely inject data signals onto the live power wire via a signal coupler.";
        }

        requirement noiseFiltering {
            doc "The AFE shall filter signals so only the 2-30 MHz communication frequencies pass through while blocking electrical noise.";
            constraint { afe.filter.lowCutoffFreq >= 2.0 and afe.filter.highCutoffFreq <= 30.0 }
        }

        requirement lineLengthSupport {
            doc "The AFE shall support transmission over wiring up to 300 meters.";
            constraint { afe.maxLineLength >= 300.0 }
        }
    }

    // ===== Sub-Components of the AFE =====
    part def SignalCoupler {
        doc "Safely injects the data signal onto the live power wire and isolates the modem from dangerous line voltage.";
        attribute maxIsolationVoltage : Voltage = 1000.0;
        port modemPort : AnalogSignalPort;
        port linePort : PowerLinePort;

        action coupleToLine {
            in signal : AnalogSignal;
            out lineSignal : AnalogSignal;
        }

        action extractFromLine {
            in lineSignal : AnalogSignal;
            out signal : AnalogSignal;
        }
    }

    part def BandPassFilter {
        doc "Cleans the signal, ensuring only the desired 2-30 MHz communication frequencies pass through while blocking electrical noise.";
        attribute lowCutoffFreq : Frequency = 2.0;
        attribute highCutoffFreq : Frequency = 30.0;
        port port1 : AnalogSignalPort;
        port port2 : AnalogSignalPort;

        action filterSignal {
            in signal : AnalogSignal;
            out filtered : AnalogSignal;
            constraint { filtered.carrierFreq >= lowCutoffFreq and filtered.carrierFreq <= highCutoffFreq }
        }
    }

    part def LineDriver {
        doc "Amplifies the signal with enough power to travel effectively along the wiring.";
        attribute gain : SignalPower = 10.0;
        port inPort : AnalogSignalPort;
        port outPort : AnalogSignalPort;

        action amplify {
            in signal : AnalogSignal;
            out amplified : AnalogSignal;
        }
    }

    // ===== PLC Modem =====
    part def PLCModem {
        doc "Core of the PLC system: performs digital processing, modulation, and demodulation.";
        attribute operatingFreq : Frequency = 14.0;
        attribute maxDataRate : DataRate = 200.0;
        port digital : DigitalDataPort;
        port analog : AnalogSignalPort;

        action modulate {
            doc "Converts a standard data packet into a high-frequency analog signal.";
            in packet : DataPacket;
            out signal : AnalogSignal;
            constraint { signal.carrierFreq >= 2.0 and signal.carrierFreq <= 30.0 }
        }

        action demodulate {
            doc "Converts an incoming analog signal back into a digital data packet.";
            in signal : AnalogSignal;
            out packet : DataPacket;
        }

        state machine ModemStates {
            state Idle;
            state Modulating;
            state Demodulating;

            transition first -> Idle;
            transition Idle -> Modulating accept DataPacket;
            transition Modulating -> Idle accept AnalogSignal;
            transition Idle -> Demodulating accept AnalogSignal;
            transition Demodulating -> Idle accept DataPacket;
        }
    }

    // ===== Analog Front End =====
    part def AnalogFrontEnd {
        doc "Physical interface between the low-voltage modem and the high-voltage power line.";
        attribute maxIsolationVoltage : Voltage = 1000.0;
        attribute maxLineLength : Distance = 300.0;
        port modemSide : AnalogSignalPort;
        port lineSide : PowerLinePort;

        part coupler : SignalCoupler;
        part filter : BandPassFilter;
        part driver : LineDriver;

        connection connectModemToFilter connect modemSide to filter.port1;
        connection connectFilterToDriver connect filter.port2 to driver.inPort;
        connection connectDriverToCoupler connect driver.outPort to coupler.modemPort;
        connection connectCouplerToLine connect coupler.linePort to lineSide;
    }

    // ===== Power Line Channel =====
    part def PowerLineChannel {
        doc "The building's existing power lines acting as the communication channel.";
        attribute length : Distance = 300.0;
        attribute lineVoltage : Voltage = 230.0;
        attribute lineFrequency : Frequency = 0.00005; // 50 Hz expressed in MHz
        port end1 : PowerLinePort;
        port end2 : PowerLinePort;

        action propagate {
            doc "Signal travels through the wiring with attenuation.";
            in signal : AnalogSignal;
            out attenuated : AnalogSignal;
        }
    }

    // ===== PLC Unit (Transmitter or Receiver) =====
    part def PLCUnit {
        doc "A PLC unit containing a modem and an analog front end.";
        port digital : DigitalDataPort;
        port line : PowerLinePort;

        part modem : PLCModem;
        part afe : AnalogFrontEnd;

        connection connectModemToAFE connect modem.analog to afe.modemSide;
        connection connectAFEToLine connect afe.lineSide to line;
    }

    // ===== PLC System =====
    part def PLCSystem {
        doc "Complete PLC system with transmitter, receiver, and power line channel.";

        part transmitter : PLCUnit;
        part receiver : PLCUnit;
        part powerLine : PowerLineChannel;

        requirement systemReq : PLCSystemRequirement;
        requirement txModemReq : ModemRequirement;
        requirement rxModemReq : ModemRequirement;
        requirement txAFEReq : AFERequirement;
        requirement rxAFEReq : AFERequirement;

        satisfy systemReq by self;
        satisfy txModemReq by transmitter.modem;
        satisfy rxModemReq by receiver.modem;
        satisfy txAFEReq by transmitter.afe;
        satisfy rxAFEReq by receiver.afe;

        connection connectTxToLine connect transmitter.line to powerLine.end1;
        connection connectLineToRx connect powerLine.end2 to receiver.line;
    }
}
