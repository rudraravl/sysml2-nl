package FrequencyDomainSensingUnit {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Temperature :> Real { unit 'degC'; }
    value type Time :> Real { unit 's'; }
    value type Magnitude :> Real { unit 'V'; }
    value type Phase :> Real { unit 'rad'; }
    value type SNR :> Real { unit 'dB'; }
    value type SampleRate :> Real { unit 'Hz'; }
    value type BitRate :> Real { unit 'bit/s'; }
    value type Dimensionless :> Real { unit '1'; }

    // ===== Item Definitions =====
    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
        attribute timestamp : Time;
    }

    item def DigitalSample {
        attribute value : Real;
        attribute index : Integer;
    }

    item def SampleBlock {
        attribute samples : DigitalSample[0..*];
        attribute blockSize : Integer;
        attribute sampleRate : SampleRate;
    }

    item def SpectrumBin {
        attribute frequency : Frequency;
        attribute magnitude : Magnitude;
        attribute phase : Phase;
    }

    item def Spectrum {
        attribute bins : SpectrumBin[0..*];
        attribute size : Integer;
        attribute resolution : Frequency;
    }

    item def AnalysisResult {
        attribute dominantFrequency : Frequency;
        attribute totalPower : Power;
        attribute qualityMetric : SNR;
        attribute timestamp : Time;
    }

    // ===== Port Definitions =====
    port def AnalogInputPort {
        in signal : AnalogSignal;
    }

    port def DigitalStreamPort {
        out block : SampleBlock;
    }

    port def ResultPort {
        out result : AnalysisResult;
    }

    port def SPIPort {
        attribute clk : Boolean;
        attribute mosi : Boolean;
        attribute miso : Boolean;
        attribute cs : Boolean;
        out result : AnalysisResult;
    }

    port def PowerInputPort {
        in voltage : Voltage;
        in current : Current;
    }

    port def RegulatedPowerPort {
        out voltage : Voltage;
        out current : Current;
    }

    // ===== Analog Front End =====
    part def AnalogFrontEnd {
        port analogIn : AnalogInputPort;
        port digitalOut : DigitalStreamPort;
        port powerIn : ~RegulatedPowerPort;

        attribute gain : Real = 10.0;
        attribute sampleRate : SampleRate = 44100;
        attribute resolutionBits : Integer = 16;
        attribute blockSize : Integer = 1024;
        attribute bandwidth : Frequency = 20000;
        attribute inputImpedance : Real = 1000000;
        attribute noiseFloor : Voltage = 0.0001;

        action process {
            action amplify {
                in raw : AnalogSignal;
                out amplified : AnalogSignal;
            }
            action filter {
                in signal : AnalogSignal;
                out filtered : AnalogSignal;
            }
            action digitize {
                in signal : AnalogSignal;
                out block : SampleBlock;
            }

            flow amplify.raw <- analogIn.signal;
            flow amplify.amplified -> filter.signal;
            flow filter.filtered -> digitize.signal;
            flow digitize.block -> digitalOut.block;
        }
    }

    // ===== Digital Signal Processor =====
    part def DSP {
        port digitalIn : ~DigitalStreamPort;
        port resultOut : ResultPort;
        port powerIn : ~RegulatedPowerPort;

        attribute fftSize : Integer = 1024;
        attribute windowType : String = "Hann";
        attribute clockFrequency : Frequency = 100000000;
        attribute processingLatency : Time = 0.05;
        attribute overlapFactor : Real = 0.5;

        action analyze {
            action acquire {
                in block : SampleBlock;
                out acquiredBlock : SampleBlock;
            }
            action applyWindow {
                in block : SampleBlock;
                out windowedBlock : SampleBlock;
            }
            action computeFFT {
                in block : SampleBlock;
                out spectrum : Spectrum;
            }
            action extractFeatures {
                in spectrum : Spectrum;
                out result : AnalysisResult;
            }

            flow acquire.block <- digitalIn.block;
            flow acquire.acquiredBlock -> applyWindow.block;
            flow applyWindow.windowedBlock -> computeFFT.block;
            flow computeFFT.spectrum -> extractFeatures.spectrum;
            flow extractFeatures.result -> resultOut.result;
        }
    }

    // ===== Communication Interface =====
    part def CommunicationInterface {
        port resultIn : ~ResultPort;
        port spiOut : SPIPort;
        port powerIn : ~RegulatedPowerPort;

        attribute protocol : String = "SPI";
        attribute clockRate : Frequency = 1000000;
        attribute dataWidth : Integer = 8;
        attribute bufferSize : Integer = 256;
        attribute timeout : Time = 0.01;

        action communicate {
            action buffer {
                in result : AnalysisResult;
                out buffered : AnalysisResult;
            }
            action transmit {
                in result : AnalysisResult;
                out transmitted : AnalysisResult;
            }

            flow buffer.result <- resultIn.result;
            flow buffer.buffered -> transmit.result;
            flow transmit.transmitted -> spiOut.result;
        }
    }

    // ===== Power Management =====
    part def PowerManagement {
        port powerInput : PowerInputPort;
        port regulatedOutput : RegulatedPowerPort;

        attribute inputVoltageNominal : Voltage = 12.0;
        attribute outputVoltage : Voltage = 3.3;
        attribute outputCurrent : Current = 0.5;
        attribute efficiency : Real = 0.9;
        attribute ripple : Voltage = 0.01;
        attribute thermalShutdown : Temperature = 125;

        action manage {
            action regulate {
                in rawVoltage : Voltage;
                in rawCurrent : Current;
                out regulatedVoltage : Voltage;
                out regulatedCurrent : Current;
            }
            action monitor {
                in voltage : Voltage;
                out status : Boolean;
            }

            flow regulate.rawVoltage <- powerInput.voltage;
            flow regulate.rawCurrent <- powerInput.current;
            flow regulate.regulatedVoltage -> regulatedOutput.voltage;
            flow regulate.regulatedCurrent -> regulatedOutput.current;
            flow monitor.voltage <- regulate.regulatedVoltage;
        }
    }

    // ===== Controller =====
    part def Controller {
        port powerIn : ~RegulatedPowerPort;

        attribute currentState : String = "idle";
        attribute faultCount : Integer = 0;
        attribute maxRetries : Integer = 3;
        attribute watchdogTimeout : Time = 1.0;

        state machine operationStates {
            state idle;
            state ready;
            state acquiring;
            state processing;
            state outputting;
            state error;

            transition t1 first idle if powerOn then ready;
            transition t2 first ready if startAcquisition then acquiring;
            transition t3 first acquiring if acquisitionComplete then processing;
            transition t4 first processing if processingComplete then outputting;
            transition t5 first outputting if outputComplete then ready;
            transition t6 first idle if faultDetected then error;
            transition t7 first ready if faultDetected then error;
            transition t8 first acquiring if faultDetected then error;
            transition t9 first processing if faultDetected then error;
            transition t10 first outputting if faultDetected then error;
            transition t11 first error if resetCommand then idle;
        }
    }

    // ===== Top-level System =====
    part def FrequencyDomainSensingUnit {
        port analogInput : AnalogInputPort;
        port spiInterface : SPIPort;
        port powerInput : PowerInputPort;

        attribute operatingTemperature : Temperature;
        attribute powerConsumption : Power;
        attribute dominantFrequencyError : Frequency;
        attribute processingLatency : Time;

        part afe : AnalogFrontEnd;
        part dsp : DSP;
        part comm : CommunicationInterface;
        part power : PowerManagement;
        part controller : Controller;

        connection analogInput to afe.analogIn;
        connection afe.digitalOut to dsp.digitalIn;
        connection dsp.resultOut to comm.resultIn;
        connection comm.spiOut to spiInterface;
        connection powerInput to power.powerInput;
        connection power.regulatedOutput to afe.powerIn;
        connection power.regulatedOutput to dsp.powerIn;
        connection power.regulatedOutput to comm.powerIn;
        connection power.regulatedOutput to controller.powerIn;

        satisfy accReq : AccuracyRequirement;
        satisfy tempReq : OperatingTemperatureRequirement;
        satisfy powerReq : PowerConsumptionRequirement;
        satisfy latencyReq : ProcessingLatencyRequirement;
        satisfy resReq : ADCResolutionRequirement;
        satisfy fftReq : FFTSizeRequirement;
        satisfy commReq : CommunicationProtocolRequirement;
    }

    // ===== Requirements =====
    requirement def AccuracyRequirement {
        doc /* The FDSU shall determine the dominant frequency with an error not exceeding 1 Hz. */
        attribute maxFrequencyError : Frequency = 1.0;
    }

    requirement def OperatingTemperatureRequirement {
        doc /* The FDSU shall operate over a temperature range of -40 to +85 degrees Celsius. */
        attribute minOperatingTemp : Temperature = -40;
        attribute maxOperatingTemp : Temperature = 85;
    }

    requirement def PowerConsumptionRequirement {
        doc /* The FDSU shall consume no more than 1 W during normal operation. */
        attribute maxPowerConsumption : Power = 1.0;
    }

    requirement def ProcessingLatencyRequirement {
        doc /* The FDSU shall complete a full analysis cycle within 100 ms. */
        attribute maxLatency : Time = 0.1;
    }

    requirement def ADCResolutionRequirement {
        doc /* The FDSU shall digitize the analog signal with at least 16-bit resolution. */
        attribute minResolutionBits : Integer = 16;
    }

    requirement def FFTSizeRequirement {
        doc /* The FDSU shall compute an FFT of at least 1024 points. */
        attribute minFFTSize : Integer = 1024;
    }

    requirement def CommunicationProtocolRequirement {
        doc /* The FDSU shall transmit results via SPI protocol at a clock rate of at least 1 MHz. */
        attribute minClockRate : Frequency = 1000000;
    }
}
