package LagotekSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def Frequency {
        attribute value : Real;
        attribute unit : String default "Hz";
    }
    
    attribute def Bandwidth {
        attribute value : Real;
        attribute unit : String default "Hz";
    }
    
    attribute def SignalStrength {
        attribute value : Real;
        attribute unit : String default "dBm";
    }
    
    attribute def DataRate {
        attribute value : Real;
        attribute unit : String default "bps";
    }
    
    item def RFSignal {
        attribute frequency : Frequency;
        attribute strength : SignalStrength;
        attribute bandwidth : Bandwidth;
        attribute modulation : String;
    }
    
    item def DigitalData {
        attribute payload : String;
        attribute timestamp : Real;
        attribute errorRate : Real;
    }
    
    item def ControlCommand {
        attribute targetFrequency : Frequency;
        attribute gain : Real;
        attribute mode : String;
    }
    
    attribute def ConfigurationCommand;
    attribute def StopCommand;
    attribute def ShutdownCommand;
    
    port def RFInputPort {
        in item signal : RFSignal;
    }
    
    port def RFOutputPort {
        out item signal : RFSignal;
    }
    
    port def DataOutputPort {
        out item data : DigitalData;
    }
    
    port def ControlInputPort {
        in item command : ControlCommand;
    }
    
    port def PowerPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }
    
    part def AntennaArray {
        doc /* Multi-element antenna array for RF signal reception */
        
        port rfOut : RFOutputPort;
        
        attribute elementCount : Integer;
        attribute gain : Real;
        attribute beamwidth : Real;
        
        action captureSignal {
            in ambientRF : RFSignal;
            out capturedSignal : RFSignal;
        }
    }
    
    part def FrontEndReceiver {
        doc /* Low-noise amplifier and frequency conversion stage */
        
        port rfIn : RFInputPort;
        port rfOut : RFOutputPort;
        port control : ControlInputPort;
        port power : PowerPort;
        
        attribute noiseTemperature : Real;
        attribute conversionGain : Real;
        attribute currentFrequency : Frequency;
        
        action tuneFrequency {
            in targetFreq : Frequency;
            out tuned : Boolean;
        }
        
        action amplifySignal {
            in inputSignal : RFSignal;
            out amplifiedSignal : RFSignal;
        }
        
        action downconvert {
            in rfSignal : RFSignal;
            in localOscillator : Frequency;
            out ifSignal : RFSignal;
        }
    }
    
    part def DigitalSignalProcessor {
        doc /* High-speed digital processing and demodulation engine */
        
        port rfIn : RFInputPort;
        port dataOut : DataOutputPort;
        port control : ControlInputPort;
        port power : PowerPort;
        
        attribute samplingRate : DataRate;
        attribute processingMode : String;
        attribute fftSize : Integer;
        
        action digitizeSignal {
            in analogSignal : RFSignal;
            out digitalSamples : RFSignal;
        }
        
        action demodulate {
            in modulatedSignal : RFSignal;
            out basebandData : DigitalData;
        }
        
        action decodeData {
            in rawData : DigitalData;
            out decodedData : DigitalData;
        }
        
        action correctErrors {
            in noisyData : DigitalData;
            out correctedData : DigitalData;
        }
    }
    
    part def ControlProcessor {
        doc /* System control and configuration management */
        
        port controlOut : ~ControlInputPort;
        port dataIn : ~DataOutputPort;
        port power : PowerPort;
        
        attribute operatingMode : String;
        attribute configurationState : String;
        
        action generateControlCommand {
            in systemState : String;
            in targetParameters : ControlCommand;
            out command : ControlCommand;
        }
        
        action monitorPerformance {
            in receivedData : DigitalData;
            out performanceMetrics : Real;
        }
        
        action adaptParameters {
            in metrics : Real;
            out newCommand : ControlCommand;
        }
    }
    
    part def DataOutputInterface {
        doc /* External data interface and buffering */
        
        port dataIn : ~DataOutputPort;
        port power : PowerPort;
        
        attribute interfaceType : String;
        attribute bufferDepth : Integer;
        attribute outputRate : DataRate;
        
        action bufferData {
            in incomingData : DigitalData;
            out bufferedData : DigitalData;
        }
        
        action formatOutput {
            in processedData : DigitalData;
            out formattedData : DigitalData;
        }
        
        action transmitData {
            in data : DigitalData;
        }
    }
    
    action def ProcessRFReception {
        doc /* Complete RF signal reception and processing workflow */
        
        in rfInput : RFSignal;
        in controlParams : ControlCommand;
        out dataOutput : DigitalData;
        
        first start;
        then action configureFrontEnd {
            in params = controlParams;
            out configured : Boolean;
        }
        then action receiveSignal {
            in signal = rfInput;
            out receivedSignal : RFSignal;
        }
        then action amplify {
            in inputSignal = receiveSignal.receivedSignal;
            out amplifiedSignal : RFSignal;
        }
        then action convert {
            in rfSignal = amplify.amplifiedSignal;
            out ifSignal : RFSignal;
        }
        then action digitize {
            in analogSignal = convert.ifSignal;
            out digitalSamples : RFSignal;
        }
        then action demod {
            in modulatedSignal = digitize.digitalSamples;
            out basebandData : DigitalData;
        }
        then action decode {
            in rawData = demod.basebandData;
            out decodedData : DigitalData;
        }
        then action errorCorrect {
            in noisyData = decode.decodedData;
            out correctedData : DigitalData;
        }
        then action buffer {
            in incomingData = errorCorrect.correctedData;
            out bufferedData : DigitalData;
        }
        then action format {
            in processedData = buffer.bufferedData;
            out formattedData : DigitalData;
        }
        then assign dataOutput := format.formattedData;
        then done;
    }
    
    state def LagotekOperationalState {
        doc /* State machine governing Lagotek system operation */
        
        entry; then powerUp;
        
        state powerUp {
            entry action initializeSystem;
            attribute initializationComplete : Boolean;
        }
        transition powerUp_to_idle
            first powerUp
            if powerUp.initializationComplete
            then idle;
        
        state idle {
            entry action enterLowPowerMode;
        }
        transition idle_to_configuring
            first idle
            accept cmd : ConfigurationCommand
            then configuring;
        
        state configuring {
            entry action applyConfiguration;
            do action validateConfiguration;
            attribute configurationValid : Boolean;
        }
        transition configuring_to_acquiring
            first configuring
            if configuring.configurationValid
            then acquiring;
        
        state acquiring {
            entry action startAcquisition;
            do action searchForSignal;
            attribute signalDetected : Boolean;
        }
        transition acquiring_to_tracking
            first acquiring
            if acquiring.signalDetected
            then tracking;
        transition acquiring_to_idle
            first acquiring
            accept cmd : StopCommand
            then idle;
        
        state tracking {
            entry action lockOnSignal;
            do action maintainLock;
            attribute lockAchieved : Boolean;
            attribute lockLost : Boolean;
        }
        transition tracking_to_processing
            first tracking
            if tracking.lockAchieved
            then processing;
        transition tracking_to_acquiring
            first tracking
            if tracking.lockLost
            then acquiring;
        
        state processing {
            do action continuousProcessing;
            do action monitorQuality;
            attribute dataReady : Boolean;
            attribute qualityDegraded : Boolean;
        }
        transition processing_to_outputting
            first processing
            if processing.dataReady
            then outputting;
        transition processing_to_tracking
            first processing
            if processing.qualityDegraded
            then tracking;
        
        state outputting {
            entry action transmitOutput;
            do action streamData;
            attribute outputComplete : Boolean;
        }
        transition outputting_to_processing
            first outputting
            if outputting.outputComplete
            then processing;
        transition outputting_to_idle
            first outputting
            accept cmd : ShutdownCommand
            then idle;
    }
    
    part def LagotekReceiver {
        doc /* 
            The Lagotek is an advanced software-defined radio receiver system designed 
            for wideband RF signal acquisition, processing, and data extraction.
            
            Its primary function is to continuously monitor the electromagnetic spectrum,
            capture radio frequency signals of interest, perform real-time digital signal
            processing including demodulation and error correction, and deliver high-quality
            digital data to downstream applications.
            
            The system operates autonomously, adapting its reception parameters based on
            signal conditions and user requirements, providing reliable data extraction
            across a wide range of frequencies and modulation schemes.
        */
        
        part antenna : AntennaArray {
            attribute :>> elementCount = 8;
            attribute :>> gain = 15.0;
            attribute :>> beamwidth = 45.0;
        }
        
        part frontEnd : FrontEndReceiver {
            attribute :>> noiseTemperature = 290.0;
            attribute :>> conversionGain = 40.0;
            attribute :>> currentFrequency = Frequency {
                value = 1575.42e6;
                unit = "Hz";
            }
        }
        
        part dsp : DigitalSignalProcessor {
            attribute :>> samplingRate = DataRate {
                value = 100.0e6;
                unit = "bps";
            }
            attribute :>> processingMode = "coherent";
            attribute :>> fftSize = 4096;
        }
        
        part controller : ControlProcessor {
            attribute :>> operatingMode = "autonomous";
            attribute :>> configurationState = "nominal";
        }
        
        part dataInterface : DataOutputInterface {
            attribute :>> interfaceType = "gigabit_ethernet";
            attribute :>> bufferDepth = 8192;
            attribute :>> outputRate = DataRate {
                value = 1.0e9;
                unit = "bps";
            }
        }
        
        connection antennaToFrontEnd
            connect antenna.rfOut to frontEnd.rfIn;
        
        connection frontEndToDSP
            connect frontEnd.rfOut to dsp.rfIn;
        
        connection dspToInterface
            connect dsp.dataOut to dataInterface.dataIn;
        
        connection controllerToFrontEnd
            connect controller.controlOut to frontEnd.control;
        
        connection controllerToDSP
            connect controller.controlOut to dsp.control;
        
        connection dspToController
            connect dsp.dataOut to controller.dataIn;
        
        perform action operateLagotek : ProcessRFReception {
            in rfInput : RFSignal;
            in controlParams : ControlCommand;
            out dataOutput : DigitalData;
        }
        
        exhibit state systemState : LagotekOperationalState;
    }
    
    part lagotekSystem : LagotekReceiver;
    
    requirement def SystemRequirement;
    requirement def PerformanceRequirement :> SystemRequirement;
    requirement def FunctionalRequirement :> SystemRequirement;
    requirement def OperationalRequirement :> SystemRequirement;
    
    requirement <'REQ-LAG-001'> primaryMission : FunctionalRequirement {
        doc /* 
            The Lagotek system shall provide continuous wideband RF signal reception,
            real-time digital signal processing, and reliable data extraction across
            the frequency range of 100 MHz to 6 GHz.
        */
        
        subject lagotekSystem;
    }
    
    requirement <'REQ-LAG-002'> frequencyCoverage : PerformanceRequirement {
        doc /* 
            The Lagotek system shall tune to any frequency within the range of
            100 MHz to 6 GHz with a tuning accuracy of ±1 kHz.
        */
        
        subject lagotekSystem;
        
        require constraint {
            lagotekSystem.frontEnd.currentFrequency.value >= 100.0e6 and
            lagotekSystem.frontEnd.currentFrequency.value <= 6.0e9
        }
    }
    
    requirement <'REQ-LAG-003'> sensitivity : PerformanceRequirement {
        doc /* 
            The Lagotek system shall achieve a minimum sensitivity of -110 dBm
            for signals with bandwidth up to 20 MHz.
        */
        
        subject lagotekSystem;
    }
    
    requirement <'REQ-LAG-004'> processingLatency : PerformanceRequirement {
        doc /* 
            The Lagotek system shall process received signals and output decoded
            data with end-to-end latency not exceeding 50 milliseconds.
        */
        
        subject lagotekSystem;
    }
    
    requirement <'REQ-LAG-005'> dataIntegrity : PerformanceRequirement {
        doc /* 
            The Lagotek system shall maintain a bit error rate of less than
            1e-6 after error correction for signals at or above minimum sensitivity.
        */
        
        subject lagotekSystem;
    }
    
    requirement <'REQ-LAG-006'> autonomousOperation : OperationalRequirement {
        doc /* 
            The Lagotek system shall operate autonomously, automatically adapting
            reception parameters and maintaining signal lock without manual intervention.
        */
        
        subject lagotekSystem;
        
        assume constraint {
            lagotekSystem.controller.operatingMode == "autonomous"
        }
    }
    
    requirement <'REQ-LAG-007'> continuousOperation : OperationalRequirement {
        doc /* 
            The Lagotek system shall support continuous operation for periods
            exceeding 72 hours without degradation in performance.
        */
        
        subject lagotekSystem;
    }
    
    requirement systemGoal {
        doc /* 
            The Lagotek system shall fulfill its mission of providing reliable
            wideband RF signal reception and data extraction.
        */
        
        assume primaryMission;
        require frequencyCoverage;
        require sensitivity;
        require processingLatency;
        require dataIntegrity;
        require autonomousOperation;
        require continuousOperation;
    }
}
