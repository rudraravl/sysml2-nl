package DSP_System {
    public import ISQ::*;
    public import ScalarValues::*;

    // ---- Value Types with Units ----
    item def Voltage :> Real {
        attribute unit : VoltageUnit[1] default V;
    }
    item def Current :> Real {
        attribute unit : CurrentUnit[1] default A;
    }
    item def Frequency :> Real {
        attribute unit : FrequencyUnit[1] default Hz;
    }
    item def Power :> Real {
        attribute unit : PowerUnit[1] default W;
    }
    item def DigitalSample :> Integer;
    item def AnalogSample :> Real;

    attribute def VoltageUnit :> Unit;
    attribute def CurrentUnit :> Unit;
    attribute def FrequencyUnit :> Unit;
    attribute def PowerUnit :> Unit;

    // ---- Port Definitions ----
    port def AnalogInputPort {
        attribute voltage : Voltage;
    }
    port def AnalogOutputPort {
        attribute voltage : Voltage;
    }
    port def DigitalPort {
        attribute data : DigitalSample;
    }
    port def PowerInputPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    port def PowerOutputPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ---- Flow Items ----
    item def RawAnalogSignal;
    item def AmplifiedAnalogSignal;
    item def FilteredAnalogSignal;
    item def DigitalData;
    item def ComputedDigitalData;
    item def ReconstructedAnalogSignal;
    item def BufferedAnalogSignal;

    // ---- Requirements ----
    requirement def PowerRequirement {
        subject powerSource : Voltage;
        requirement :> powerSource >= 9 [V] and powerSource <= 15 [V];
    }
    requirement def RegulatedSupplyRequirement {
        subject regulatedVoltage : Voltage;
        requirement :> regulatedVoltage == 5 [V];
    }
    requirement def SignalChainRequirement {
        subject inputSignal : RawAnalogSignal;
        subject outputSignal : BufferedAnalogSignal;
        requirement {
            doc "The system shall acquire, process, and regenerate an analog signal in real time."
        }
    }
    requirement def LatencyRequirement {
        attribute maxLatency : Time = 0.001 [s];
        requirement {
            doc "Processing latency shall not exceed 1 millisecond."
        }
    }
    requirement def PowerModeRequirement {
        requirement {
            doc "The system shall support standby, active, and shutdown modes."
        }
    }

    // ---- Component Part Definitions ----
    part def PowerRegulator {
        port powerIn : PowerInputPort;
        port powerOut : PowerOutputPort;
        attribute outputVoltage : Voltage = 5 [V];
        attribute efficiency : Real = 0.85;

        requirement powerReq : PowerRequirement {
            subject powerSource = powerIn.voltage;
        }
        requirement regReq : RegulatedSupplyRequirement {
            subject regulatedVoltage = outputVoltage;
        }

        action regulate {
            in inPower : PowerInputPort;
            out outPower : PowerOutputPort;
        }
    }

    part def Amplifier {
        port signalIn : AnalogInputPort;
        port signalOut : AnalogOutputPort;
        attribute gain : Real = 10.0;
        attribute bandwidth : Frequency = 100000 [Hz];

        action amplify {
            in raw : RawAnalogSignal;
            out amplified : AmplifiedAnalogSignal;
        }
    }

    part def Filter {
        port signalIn : AnalogInputPort;
        port signalOut : AnalogOutputPort;
        attribute cutoffFrequency : Frequency = 20000 [Hz];
        attribute order : Integer = 4;

        action filter {
            in amplified : AmplifiedAnalogSignal;
            out filtered : FilteredAnalogSignal;
        }
    }

    part def ADC {
        port analogIn : AnalogInputPort;
        port digitalOut : DigitalPort;
        attribute resolution : Integer = 12;
        attribute sampleRate : Frequency = 44000 [Hz];

        action convert {
            in filtered : FilteredAnalogSignal;
            out digital : DigitalData;
        }
    }

    part def Microcontroller {
        port dataIn : DigitalPort;
        port dataOut : DigitalPort;
        port powerIn : PowerInputPort;
        attribute clockSpeed : Frequency = 16000000 [Hz];
        attribute programMemory : Integer = 65536;

        action compute {
            in digital : DigitalData;
            out computed : ComputedDigitalData;
        }

        state machine ControllerBehavior {
            entry;
            state Initializing;
            state Standby;
            state Active;
            state Shutdown;
            transition init_to_standby
                first Initializing then Standby;
            transition standby_to_active
                first Standby then Active
                when dataIn.data > 0;
            transition active_to_standby
                first Active then Standby
                when idleTimeout;
            transition any_to_shutdown
                first {Standby, Active} then Shutdown
                when shutdownCommand;
        }
    }

    part def DAC {
        port digitalIn : DigitalPort;
        port analogOut : AnalogOutputPort;
        attribute resolution : Integer = 12;
        attribute updateRate : Frequency = 44000 [Hz];

        action reconstruct {
            in computed : ComputedDigitalData;
            out analog : ReconstructedAnalogSignal;
        }
    }

    part def OutputBuffer {
        port signalIn : AnalogOutputPort;
        port signalOut : AnalogOutputPort;
        attribute outputImpedance : Real = 50.0;
        attribute maxDriveCurrent : Current = 0.5 [A];

        action buffer {
            in analog : ReconstructedAnalogSignal;
            out buffered : BufferedAnalogSignal;
        }
    }

    // ---- Top-Level DSP System ----
    part def DSPSystem {
        port externalPower : PowerInputPort;
        port sensorInput : AnalogInputPort;
        port actuatorOutput : AnalogOutputPort;

        attribute supplyVoltage : Voltage = 5 [V];
        attribute idleTimeoutDuration : Time = 30 [s];

        part regulator : PowerRegulator {
            port powerIn : PowerInputPort;
            port powerOut : PowerOutputPort;
        }
        part amplifier : Amplifier {
            port signalIn : AnalogInputPort;
            port signalOut : AnalogOutputPort;
        }
        part filter : Filter {
            port signalIn : AnalogInputPort;
            port signalOut : AnalogOutputPort;
        }
        part adc : ADC {
            port analogIn : AnalogInputPort;
            port digitalOut : DigitalPort;
        }
        part controller : Microcontroller {
            port dataIn : DigitalPort;
            port dataOut : DigitalPort;
            port powerIn : PowerInputPort;
        }
        part dac : DAC {
            port digitalIn : DigitalPort;
            port analogOut : AnalogOutputPort;
        }
        part outputBuffer : OutputBuffer {
            port signalIn : AnalogOutputPort;
            port signalOut : AnalogOutputPort;
        }

        // Power distribution
        connection powerInToRegulator connect externalPower to regulator.powerIn;
        connection regulatorToController connect regulator.powerOut to controller.powerIn;

        // Signal chain
        connection sensorToAmplifier connect sensorInput to amplifier.signalIn;
        connection amplifierToFilter connect amplifier.signalOut to filter.signalIn;
        connection filterToADC connect filter.signalOut to adc.analogIn;
        connection adcToController connect adc.digitalOut to controller.dataIn;
        connection controllerToDAC connect controller.dataOut to dac.digitalIn;
        connection dacToBuffer connect dac.analogOut to outputBuffer.signalIn;
        connection bufferToActuator connect outputBuffer.signalOut to actuatorOutput;

        // Requirements satisfaction
        satisfy powerReq of PowerRequirement by regulator;
        satisfy signalReq of SignalChainRequirement by self;
        satisfy modeReq of PowerModeRequirement by self;
        satisfy latencyReq of LatencyRequirement by controller;

        // System-level state machine
        state machine SystemModes {
            entry;
            state PowerOn {
                entry action initializeSystem;
            }
            state Standby {
                entry action enterLowPower;
            }
            state Active {
                state Sampling;
                state Computing;
                state Transmitting;
                transition sample_to_compute
                    first Sampling then Computing;
                transition compute_to_transmit
                    first Computing then Transmitting;
                transition transmit_to_sample
                    first Transmitting then Sampling;
            }
            state Shutdown {
                entry action powerOff;
            }
            transition powerOn_to_standby
                first PowerOn then Standby;
            transition standby_to_active
                first Standby then Active
                when sensorInput.voltage > 0 [V];
            transition active_to_standby
                first Active then Standby
                when idleTimerExceeded;
            transition standby_to_shutdown
                first Standby then Shutdown
                when shutdownCommandReceived;
        }

        action initializeSystem {
            // Power up regulator, configure peripherals
        }
        action enterLowPower {
            // Reduce clock, disable unused blocks
        }
        action powerOff {
            // Disconnect power rails
        }
    }
}
