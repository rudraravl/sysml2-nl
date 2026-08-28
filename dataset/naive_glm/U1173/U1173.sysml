package RFTransceiverSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value def Frequency :> Real { unit 'Hz'; }
    value def Power :> Real { unit 'W'; }
    value def PowerdBm :> Real { unit 'dBm'; }
    value def GaindB :> Real { unit 'dB'; }
    value def Temperature :> Real { unit 'K'; }
    value def TimeSeconds :> Real { unit 's'; }
    value def Ratio :> Real { unit '1'; }

    // ---- Item Definitions ----
    item def DigitalBasebandSignal {
        attribute dataRate : Frequency;
        attribute bitErrorRate : Ratio;
        attribute payload : String;
    }

    item def RFSignal {
        attribute frequency : Frequency;
        attribute power : Power;
        attribute snr : GaindB;
    }

    item def ModulatedSignal :> RFSignal {
        attribute modulationType : String;
        attribute symbolRate : Frequency;
    }

    item def LocalOscillatorSignal :> RFSignal {
        attribute phaseNoise : GaindB;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute targetFrequency : Frequency;
        attribute targetMode : String;
        attribute priority : Integer;
    }

    item def StatusReport {
        attribute componentId : String;
        attribute healthState : String;
        attribute measuredValue : Real;
    }

    // ---- Port Definitions ----
    port def DigitalInPort { in digitalSignal : DigitalBasebandSignal; }
    port def DigitalOutPort { out digitalSignal : DigitalBasebandSignal; }
    port def RFInPort { in rfSignal : RFSignal; }
    port def RFOutPort { out rfSignal : RFSignal; }
    port def LOInPort { in loSignal : LocalOscillatorSignal; }
    port def LOOutPort { out loSignal : LocalOscillatorSignal; }
    port def ControlInPort { in command : ControlCommand; }
    port def ControlOutPort { out command : ControlCommand; }
    port def StatusOutPort { out status : StatusReport; }
    port def StatusInPort { in status : StatusReport; }

    // ---- Component Part Definitions ----
    part def Modulator {
        port digitalIn : DigitalInPort;
        port modulatedOut : RFOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute modulationScheme : String = "QPSK";
        attribute carrierFrequency : Frequency = 2.4e9;
        attribute isActive : Boolean = false;

        action def modulate {
            in baseband : DigitalBasebandSignal;
            out modulated : ModulatedSignal;
            perform {
                /* Encode digital data onto carrier wave */
            }
        }
    }

    part def Demodulator {
        port rfIn : RFInPort;
        port digitalOut : DigitalOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute demodulationScheme : String = "QPSK";
        attribute isActive : Boolean = false;

        action def demodulate {
            in modulated : RFSignal;
            out baseband : DigitalBasebandSignal;
            perform {
                /* Extract digital baseband data from modulated signal */
            }
        }
    }

    part def Mixer {
        port rfIn : RFInPort;
        port loIn : LOInPort;
        port rfOut : RFOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute conversionGain : GaindB = -6.0;
        attribute portIsolation : GaindB = 40.0;
        attribute isActive : Boolean = false;

        action def mix {
            in input : RFSignal;
            in lo : LocalOscillatorSignal;
            out output : RFSignal;
            perform {
                /* Multiply input signal with LO to shift frequency */
            }
        }
    }

    part def LocalOscillator {
        port loOut : LOOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute centerFrequency : Frequency = 2.4e9;
        attribute frequencyStability : Ratio = 10.0e-6;
        attribute phaseNoise : GaindB = -110.0;
        attribute outputPower : Power = 0.001;
        attribute isActive : Boolean = false;

        action def generateLO {
            out loSignal : LocalOscillatorSignal;
            perform {
                /* Generate precise reference frequency signal */
            }
        }
    }

    part def BandpassFilter {
        port rfIn : RFInPort;
        port rfOut : RFOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute centerFrequency : Frequency = 2.4e9;
        attribute bandwidth : Frequency = 20.0e6;
        attribute insertionLoss : GaindB = -2.0;
        attribute stopbandAttenuation : GaindB = -40.0;
        attribute isActive : Boolean = false;

        action def filter {
            in input : RFSignal;
            out output : RFSignal;
            perform {
                /* Pass desired band, attenuate out-of-band signals */
            }
        }
    }

    part def Amplifier {
        port rfIn : RFInPort;
        port rfOut : RFOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute gain : GaindB = 20.0;
        attribute noiseFigure : GaindB = 3.0;
        attribute outputPower : Power = 0.1;
        attribute isPowerAmplifier : Boolean = false;
        attribute isActive : Boolean = false;

        action def amplify {
            in input : RFSignal;
            out output : RFSignal;
            perform {
                /* Increase signal power while minimizing added noise */
            }
        }
    }

    part def Antenna {
        port rfFromTx : RFInPort;
        port rfToRx : RFOutPort;
        port ctrlIn : ControlInPort;
        port statusOut : StatusOutPort;
        attribute gain : GaindB = 2.0;
        attribute impedance : Real = 50.0;
        attribute vswr : Ratio = 1.5;
        attribute isActive : Boolean = false;

        action def radiate {
            in rfSignal : RFSignal;
            perform {
                /* Convert electrical signal to electromagnetic wave */
            }
        }

        action def receive {
            out rfSignal : RFSignal;
            perform {
                /* Capture electromagnetic wave and convert to electrical signal */
            }
        }
    }

    part def SystemController {
        port ctrlOut : ControlOutPort;
        port statusIn : StatusInPort;
        port externalCmdIn : ControlInPort;
        attribute operatingMode : String = "Idle";
        attribute targetFrequency : Frequency = 2.4e9;
        attribute faultDetected : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute faultCleared : Boolean = false;

        action def issueCommand {
            out command : ControlCommand;
            perform {
                /* Generate control commands for subsystems */
            }
        }

        action def monitorStatus {
            in status : StatusReport;
            perform {
                /* Evaluate subsystem health and set fault flags */
            }
        }
    }

    // ---- State Machine Definition ----
    state def TransceiverStates {
        attribute currentCommand : String;
        attribute faultDetected : Boolean;
        attribute calibrationComplete : Boolean;
        attribute faultCleared : Boolean;

        state Idle {
            entry { /* Enter low-power standby; disable active signal paths */ }
            exit { /* Wake up subsystems as needed */ }
        }

        state Transmit {
            entry { /* Enable modulator, TX mixer, TX filter, TX amplifier, antenna TX path */ }
            do { /* Perform full transmission sequence */ }
            exit { /* Power down TX path components */ }
        }

        state Receive {
            entry { /* Enable antenna RX path, RX filter, LNA, RX mixer, demodulator */ }
            do { /* Perform full reception sequence */ }
            exit { /* Power down RX path components */ }
        }

        state Calibration {
            entry { /* Initiate self-tuning of LO frequency and filter bandwidth */ }
            do { /* Run optimization algorithms */ }
            exit { /* Store calibrated parameters */ }
        }

        state Fault {
            entry { /* Log error, disable active components, raise alert */ }
            do { /* Await fault clearance */ }
            exit { /* Restore safe operating conditions */ }
        }

        transition from Idle to Transmit when currentCommand == "transmit";
        transition from Idle to Receive when currentCommand == "receive";
        transition from Idle to Calibration when currentCommand == "calibrate";
        transition from Transmit to Idle when currentCommand == "idle";
        transition from Receive to Idle when currentCommand == "idle";
        transition from Calibration to Idle when calibrationComplete;
        transition from Idle to Fault when faultDetected;
        transition from Transmit to Fault when faultDetected;
        transition from Receive to Fault when faultDetected;
        transition from Calibration to Fault when faultDetected;
        transition from Fault to Idle when faultCleared;
    }

    // ---- Requirements ----
    requirement def OperatingFrequencyRequirement {
        doc /* The transceiver shall operate in the 2.4 GHz ISM band (2.400 - 2.4835 GHz). */
        subject transceiver : RFTransceiver;
        constraint { transceiver.localOscillator.centerFrequency >= 2.400e9 and transceiver.localOscillator.centerFrequency <= 2.4835e9 }
    }

    requirement def FrequencyStabilityRequirement {
        doc /* The local oscillator frequency stability shall be 10 ppm or better over the operating temperature range. */
        subject localOscillator : LocalOscillator;
        constraint { localOscillator.frequencyStability <= 10.0e-6 }
    }

    requirement def TransmitPowerRequirement {
        doc /* The transmit output power shall be at least 20 dBm (0.1 W) at the antenna port. */
        subject txAmplifier : Amplifier;
        constraint { txAmplifier.outputPower >= 0.1 }
    }

    requirement def ReceiverSensitivityRequirement {
        doc /* The receiver sensitivity shall be -90 dBm or better for a bit error rate of 1e-3. */
        subject rxAmplifier : Amplifier;
        constraint { rxAmplifier.noiseFigure <= 3.0 }
    }

    requirement def SpuriousEmissionRequirement {
        doc /* Spurious emissions outside the passband shall be attenuated by at least 40 dB. */
        subject txFilter : BandpassFilter;
        constraint { txFilter.stopbandAttenuation <= -40.0 }
    }

    requirement def PhaseNoiseRequirement {
        doc /* The local oscillator phase noise shall not exceed -110 dBc/Hz at 1 MHz offset. */
        subject localOscillator : LocalOscillator;
        constraint { localOscillator.phaseNoise <= -110.0 }
    }

    requirement def TransceiverSystemRequirements {
        doc /* The RF Transceiver system shall meet all performance requirements for reliable wireless communication. */
        subject transceiver : RFTransceiver;
        satisfy operatingFreqReq : OperatingFrequencyRequirement;
        satisfy freqStabilityReq : FrequencyStabilityRequirement;
        satisfy txPowerReq : TransmitPowerRequirement;
        satisfy rxSensitivityReq : ReceiverSensitivityRequirement;
        satisfy spuriousReq : SpuriousEmissionRequirement;
        satisfy phaseNoiseReq : PhaseNoiseRequirement;
    }

    // ---- Top-Level RF Transceiver Part ----
    part def RFTransceiver {
        port txDataIn : DigitalInPort;
        port rxDataOut : DigitalOutPort;
        port ctrlPort : ControlInPort;
        port statusReportOut : StatusOutPort;

        attribute systemIdentifier : String = "RF-TRX-2400";
        attribute operatingTemperatureMin : Temperature = 233.15;
        attribute operatingTemperatureMax : Temperature = 358.15;

        part modulator : Modulator {
            attribute modulationScheme = "QPSK";
        }
        part txMixer : Mixer {}
        part txFilter : BandpassFilter {
            attribute centerFrequency = 2.4e9;
            attribute bandwidth = 20.0e6;
        }
        part txAmplifier : Amplifier {
            attribute isPowerAmplifier = true;
            attribute gain = 30.0;
            attribute outputPower = 0.1;
        }
        part antenna : Antenna {}
        part rxFilter : BandpassFilter {
            attribute centerFrequency = 2.4e9;
            attribute bandwidth = 20.0e6;
        }
        part rxAmplifier : Amplifier {
            attribute isPowerAmplifier = false;
            attribute gain = 15.0;
            attribute noiseFigure = 2.0;
        }
        part rxMixer : Mixer {}
        part demodulator : Demodulator {
            attribute demodulationScheme = "QPSK";
        }
        part localOscillator : LocalOscillator {
            attribute centerFrequency = 2.4e9;
        }
        part controller : SystemController {}

        // Transmit path connections
        connect txDataIn to modulator.digitalIn;
        connect modulator.modulatedOut to txMixer.rfIn;
        connect localOscillator.loOut to txMixer.loIn;
        connect txMixer.rfOut to txFilter.rfIn;
        connect txFilter.rfOut to txAmplifier.rfIn;
        connect txAmplifier.rfOut to antenna.rfFromTx;

        // Receive path connections
        connect antenna.rfToRx to rxFilter.rfIn;
        connect rxFilter.rfOut to rxAmplifier.rfIn;
        connect rxAmplifier.rfOut to rxMixer.rfIn;
        connect localOscillator.loOut to rxMixer.loIn;
        connect rxMixer.rfOut to demodulator.rfIn;
        connect demodulator.digitalOut to rxDataOut;

        // Control distribution from controller
        connect ctrlPort to controller.externalCmdIn;
        connect controller.ctrlOut to modulator.ctrlIn;
        connect controller.ctrlOut to txMixer.ctrlIn;
        connect controller.ctrlOut to txFilter.ctrlIn;
        connect controller.ctrlOut to txAmplifier.ctrlIn;
        connect controller.ctrlOut to antenna.ctrlIn;
        connect controller.ctrlOut to rxFilter.ctrlIn;
        connect controller.ctrlOut to rxAmplifier.ctrlIn;
        connect controller.ctrlOut to rxMixer.ctrlIn;
        connect controller.ctrlOut to demodulator.ctrlIn;
        connect controller.ctrlOut to localOscillator.ctrlIn;

        // Status aggregation to controller
        connect modulator.statusOut to controller.statusIn;
        connect txMixer.statusOut to controller.statusIn;
        connect txFilter.statusOut to controller.statusIn;
        connect txAmplifier.statusOut to controller.statusIn;
        connect antenna.statusOut to controller.statusIn;
        connect rxFilter.statusOut to controller.statusIn;
        connect rxAmplifier.statusOut to controller.statusIn;
        connect rxMixer.statusOut to controller.statusIn;
        connect demodulator.statusOut to controller.statusIn;
        connect localOscillator.statusOut to controller.statusIn;

        // State machine behavior
        exhibit TransceiverStates;

        // Requirement satisfaction
        satisfy systemReqs : TransceiverSystemRequirements;
    }
}
