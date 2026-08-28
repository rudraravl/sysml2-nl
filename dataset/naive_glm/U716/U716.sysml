package UnderwaterHydrophoneSystem {
    import ScalarValues::*;
    
    // ======================== Value Types with Units ========================
    
    value def PressureBar :> Real { unit 'bar'; }
    value def DepthMeters :> Real { unit 'm'; }
    value def FrequencyHertz :> Real { unit 'Hz'; }
    value def VoltageVolts :> Real { unit 'V'; }
    value def PowerWatts :> Real { unit 'W'; }
    value def CurrentAmps :> Real { unit 'A'; }
    value def DataRateBitsPerSec :> Real { unit 'bit/s'; }
    value def SampleRateKHz :> Real { unit 'kHz'; }
    value def DurationSeconds :> Real { unit 's'; }
    value def SoundPressureLevelDB :> Real { unit 'dB'; }
    value def StorageGB :> Real { unit 'GB'; }
    value def GainDB :> Real { unit 'dB'; }
    value def MilliampHours :> Real { unit 'mAh'; }
    value def TemperatureCelsius :> Real { unit '°C'; }
    value def Millimeters :> Real { unit 'mm'; }
    value def MegaHertz :> Real { unit 'MHz'; }
    value def MegaBytesPerSec :> Real { unit 'MB/s'; }
    
    // ======================== Item Definitions ========================
    
    item def AcousticPressureWave {
        attribute frequency : FrequencyHertz;
        attribute peakPressure : PressureBar;
        attribute soundPressureLevel : SoundPressureLevelDB;
        attribute waveDirection : Real;
    }
    
    item def AnalogElectricalSignal {
        attribute voltage : VoltageVolts;
        attribute frequency : FrequencyHertz;
        attribute signalToNoiseRatio : SoundPressureLevelDB;
        attribute impedanceOhms : Real;
    }
    
    item def DigitalAudioStream {
        attribute sampleRate : SampleRateKHz;
        attribute resolution : Integer;
        attribute dataRate : DataRateBitsPerSec;
        attribute channelCount : Integer = 1;
    }
    
    item def ProcessedDigitalAudio {
        attribute sampleRate : SampleRateKHz;
        attribute resolution : Integer;
        attribute filterMinFreq : FrequencyHertz;
        attribute filterMaxFreq : FrequencyHertz;
        attribute channelCount : Integer = 1;
        attribute timestamp : DurationSeconds;
    }
    
    item def ElectricPower {
        attribute voltage : VoltageVolts;
        attribute current : CurrentAmps;
        attribute power : PowerWatts;
    }
    
    item def ActivationCommand {
        attribute commandId : Integer;
        attribute timestamp : DurationSeconds;
    }
    
    item def DeactivationCommand {
        attribute commandId : Integer;
        attribute timestamp : DurationSeconds;
    }
    
    // ======================== Port Definitions ========================
    
    port def AcousticInPort {
        in item wave : AcousticPressureWave;
    }
    
    port def AnalogSignalInPort {
        in item signal : AnalogElectricalSignal;
    }
    
    port def AnalogSignalOutPort {
        out item signal : AnalogElectricalSignal;
    }
    
    port def DigitalAudioInPort {
        in item stream : DigitalAudioStream;
    }
    
    port def DigitalAudioOutPort {
        out item stream : DigitalAudioStream;
    }
    
    port def ProcessedAudioInPort {
        in item audio : ProcessedDigitalAudio;
    }
    
    port def ProcessedAudioOutPort {
        out item audio : ProcessedDigitalAudio;
    }
    
    port def RealTimeOutputPort {
        out item audio : ProcessedDigitalAudio;
    }
    
    port def PowerOutPort {
        out item power : ElectricPower;
    }
    
    port def PowerInPort {
        in item power : ElectricPower;
    }
    
    port def CommandInPort {
        in item activationCmd : ActivationCommand;
        in item deactivationCmd : DeactivationCommand;
    }
    
    // ======================== Component Part Definitions ========================
    
    part def TitaniumCasing {
        attribute material : String = "Titanium Grade 5 (Ti-6Al-4V)";
        attribute maxOperatingPressure : PressureBar = 1000;
        attribute maxOperatingDepth : DepthMeters = 10000;
        attribute waterResistanceRating : String = "IP68";
        attribute wallThickness : Millimeters = 15.0;
        attribute outerDiameter : Millimeters = 200.0;
        attribute length : Millimeters = 500.0;
        attribute operatingTempMin : TemperatureCelsius = -40;
        attribute operatingTempMax : TemperatureCelsius = 85;
        attribute corrosionResistance : String = "Seawater resistant";
        
        action sealEnclosure {
            out sealed : Boolean;
        }
    }
    
    part def PiezoelectricTransducer {
        port acousticInput : AcousticInPort;
        port electricalOutput : AnalogSignalOutPort;
        
        attribute minFrequency : FrequencyHertz = 1;
        attribute maxFrequency : FrequencyHertz = 100000;
        attribute sensitivity : SoundPressureLevelDB = -200;
        attribute piezoMaterial : String = "PZT-5A piezoceramic";
        attribute diaphragmDiameter : Millimeters = 50.0;
        attribute operatingTempMin : TemperatureCelsius = -40;
        attribute operatingTempMax : TemperatureCelsius = 85;
        
        action convertAcousticToElectric {
            in acousticWave : AcousticPressureWave;
            out electricSignal : AnalogElectricalSignal;
        }
    }
    
    part def Preamplifier {
        port analogInput : AnalogSignalInPort;
        port amplifiedOutput : AnalogSignalOutPort;
        port powerInput : PowerInPort;
        
        attribute gain : GainDB = 40;
        attribute noiseFigure : GainDB = 3;
        attribute bandwidth : FrequencyHertz = 100000;
        attribute inputImpedanceOhms : Real = 10000;
        attribute supplyVoltage : VoltageVolts = 12;
        attribute totalHarmonicDistortion : Real = 0.001;
        
        action amplifySignal {
            in inputSignal : AnalogElectricalSignal;
            out outputSignal : AnalogElectricalSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        port analogInput : AnalogSignalInPort;
        port digitalOutput : DigitalAudioOutPort;
        port powerInput : PowerInPort;
        
        attribute sampleRate : SampleRateKHz = 192;
        attribute resolution : Integer = 24;
        attribute dynamicRange : SoundPressureLevelDB = 120;
        attribute supplyVoltage : VoltageVolts = 5;
        attribute conversionMode : String = "Delta-Sigma";
        attribute oversamplingRatio : Integer = 128;
        
        action convertAnalogToDigital {
            in analogSignal : AnalogElectricalSignal;
            out digitalStream : DigitalAudioStream;
        }
    }
    
    part def SignalProcessor {
        port digitalInput : DigitalAudioInPort;
        port processedOutput : ProcessedAudioOutPort;
        port powerInput : PowerInPort;
        
        attribute bandpassFilterMin : FrequencyHertz = 20;
        attribute bandpassFilterMax : FrequencyHertz = 50000;
        attribute filterOrder : Integer = 8;
        attribute processingLatency : DurationSeconds = 0.001;
        attribute clockSpeed : MegaHertz = 200;
        attribute supplyVoltage : VoltageVolts = 3.3;
        attribute detectionThreshold : SoundPressureLevelDB = -80;
        
        action applyBandpassFilter {
            in digitalAudio : DigitalAudioStream;
            out processedAudio : ProcessedDigitalAudio;
        }
        
        action detectSignalLevel {
            in processedAudio : ProcessedDigitalAudio;
            out signalPresent : Boolean;
        }
    }
    
    part def DataRecorder {
        port processedInput : ProcessedAudioInPort;
        port powerInput : PowerInPort;
        
        attribute storageCapacity : StorageGB = 1000;
        attribute storageUsed : StorageGB = 0;
        attribute fileFormat : String = "WAV";
        attribute supplyVoltage : VoltageVolts = 3.3;
        attribute writeSpeed : MegaBytesPerSec = 50;
        attribute isRecording : Boolean = false;
        attribute currentRecordingDuration : DurationSeconds = 0;
        
        action storeAudio {
            in audioData : ProcessedDigitalAudio;
        }
        
        action finalizeRecording {
            out recordingComplete : Boolean;
        }
        
        action resetRecordingState {
            out readyForNewRecording : Boolean;
        }
    }
    
    part def RealTimeOutputModule {
        port processedInput : ProcessedAudioInPort;
        port outputPort : RealTimeOutputPort;
        port powerInput : PowerInPort;
        
        attribute outputLatency : DurationSeconds = 0.0005;
        attribute outputProtocol : String = "Ethernet";
        attribute supplyVoltage : VoltageVolts = 3.3;
        attribute bufferSize : Integer = 4096;
        
        action transmitAudio {
            in audio : ProcessedDigitalAudio;
        }
    }
    
    part def PowerSupply {
        port powerOutput : PowerOutPort;
        
        attribute nominalVoltage : VoltageVolts = 12;
        attribute capacity : MilliampHours = 50000;
        attribute estimatedRuntime : DurationSeconds = 259200;
        attribute batteryType : String = "Lithium-Ion";
        attribute maxDischargeCurrent : CurrentAmps = 5;
        attribute voltageRegulationPercent : Real = 1.0;
        attribute remainingChargePercent : Real = 100.0;
        attribute operatingTempMin : TemperatureCelsius = -20;
        attribute operatingTempMax : TemperatureCelsius = 60;
        
        action regulatePower {
            out regulatedPower : ElectricPower;
        }
        
        action monitorChargeLevel {
            out chargePercent : Real;
        }
    }
    
    // ======================== Main System Definition ========================
    
    part def HydrophoneSystem {
        // System-level attributes for state machine and operational control
        attribute activationSignal : Boolean = false;
        attribute deactivationSignal : Boolean = false;
        attribute signalDetected : Boolean = false;
        attribute recordingComplete : Boolean = false;
        attribute detectionThreshold : SoundPressureLevelDB = -80;
        attribute maxRecordingDuration : DurationSeconds = 60;
        attribute currentRecordingTime : DurationSeconds = 0;
        attribute systemInitialized : Boolean = false;
        attribute systemHealthStatus : String = "nominal";
        
        // Housing and structural components
        part casing : TitaniumCasing;
        
        // Core sensing and signal processing chain
        part transducer : PiezoelectricTransducer;
        part preamplifier : Preamplifier;
        part adc : AnalogToDigitalConverter;
        part signalProcessor : SignalProcessor;
        part dataRecorder : DataRecorder;
        part realTimeOutput : RealTimeOutputModule;
        part powerSupply : PowerSupply;
        
        // External interface ports
        port acousticInputPort : AcousticInPort;
        port realTimeOutputPort : RealTimeOutputPort;
        port commandInputPort : CommandInPort;
        
        // Signal path connections — acoustic to electrical conversion chain
        connect acousticInputPort to transducer.acousticInput;
        connect transducer.electricalOutput to preamplifier.analogInput;
        connect preamplifier.amplifiedOutput to adc.analogInput;
        connect adc.digitalOutput to signalProcessor.digitalInput;
        
        // Processed audio distribution — to both recorder and real-time output
        connect signalProcessor.processedOutput to dataRecorder.processedInput;
        connect signalProcessor.processedOutput to realTimeOutput.processedInput;
        connect realTimeOutput.outputPort to realTimeOutputPort;
        
        // Power distribution to all electronic components
        connect powerSupply.powerOutput to preamplifier.powerInput;
        connect powerSupply.powerOutput to adc.powerInput;
        connect powerSupply.powerOutput to signalProcessor.powerInput;
        connect powerSupply.powerOutput to dataRecorder.powerInput;
        connect powerSupply.powerOutput to realTimeOutput.powerInput;
        
        // State machine — operational modes
        state machine HydrophoneStateMachine {
            initial state standby {
                entry action {
                    // Enter low-power mode
                    // Disable preamplifier, ADC, signal processor, recorder, output
                    // Only command receiver and power supply remain active
                }
                
                do action {
                    // Wait for activation command
                    // Monitor command input port for activation signal
                }
                
                exit action {
                    // Prepare sensing chain for activation
                    // Power on preamplifier, ADC, signal processor
                }
            }
            
            state active {
                entry action {
                    // Enable transducer, preamplifier, ADC, signal processor
                    // Begin monitoring acoustic input for signals of interest
                }
                
                do action {
                    // Continuously monitor incoming acoustic signals
                    // Evaluate detected signal level against detection threshold
                    // Set signalDetected flag if signal exceeds threshold
                }
                
                exit action {
                    // Reset signal detection flag
                    // Prepare for next monitoring cycle or shutdown
                }
            }
            
            state recording {
                entry action {
                    // Start recording processed audio to data recorder
                    // Reset current recording time to zero
                    // Enable data recorder write mode
                }
                
                do action {
                    // Continuously store incoming processed audio samples
                    // Increment current recording time
                    // Check if current recording time exceeds max recording duration
                }
                
                exit action {
                    // Finalize and save current recording
                    // Reset recording complete flag
                    // Prepare data recorder for next recording session
                }
            }
            
            // State transitions
            transition from standby to active when activationSignal;
            transition from active to recording when signalDetected;
            transition from recording to active when recordingComplete;
            transition from active to standby when deactivationSignal;
        }
        
        // Requirement satisfaction
        satisfy UnderwaterHydrophoneReqDef by hydrophone;
        satisfy DeepSeaOperationReqDef by casing;
        satisfy AcousticDetectionReqDef by transducer;
        satisfy SignalAmplificationReqDef by preamplifier;
        satisfy DigitizationReqDef by adc;
        satisfy SignalProcessingReqDef by signalProcessor;
        satisfy DataRecordingReqDef by dataRecorder;
        satisfy RealTimeOutputReqDef by realTimeOutput;
        satisfy PowerSupplyReqDef by powerSupply;
        satisfy StateMachineReqDef by hydrophone;
    }
    
    // ======================== Requirement Definitions ========================
    
    requirement def UnderwaterHydrophoneReqDef {
        doc /* The system shall function as a comprehensive underwater sound detection and recording system (hydrophone) capable of capturing acoustic signals, processing them, and storing them as digital audio data for analysis. */
    }
    
    requirement def DeepSeaOperationReqDef {
        doc /* The system shall operate reliably in high-pressure, deep-sea environments housed within a durable, waterproof titanium casing designed to withstand significant underwater pressure. */
        attribute maxOperatingPressure : PressureBar = 1000;
        attribute maxOperatingDepth : DepthMeters = 10000;
        attribute housingMaterial : String = "Titanium";
        attribute waterproofRating : String = "IP68";
    }
    
    requirement def AcousticDetectionReqDef {
        doc /* The core component shall be a sensitive piezoelectric transducer acting as an underwater microphone, detecting acoustic pressure waves in water over a wide frequency range and converting them into a weak electrical signal. */
        attribute minDetectionFrequency : FrequencyHertz = 1;
        attribute maxDetectionFrequency : FrequencyHertz = 100000;
        attribute transducerType : String = "Piezoelectric";
        attribute minSensitivity : SoundPressureLevelDB = -200;
    }
    
    requirement def SignalAmplificationReqDef {
        doc /* The system shall include a preamplifier that receives the weak electrical signal from the transducer and immediately boosts its strength. */
        attribute minGain : GainDB = 40;
        attribute maxNoiseFigure : GainDB = 3;
    }
    
    requirement def DigitizationReqDef {
        doc /* The system shall include an analog-to-digital converter that transforms the amplified analog signal into a high-resolution, high-sample-rate digital audio stream. */
        attribute minSampleRate : SampleRateKHz = 192;
        attribute minResolution : Integer = 24;
        attribute minDynamicRange : SoundPressureLevelDB = 120;
    }
    
    requirement def SignalProcessingReqDef {
        doc /* The system shall include an onboard signal processor that applies a bandpass filter to remove unwanted noise and isolate the frequencies of interest from the digital audio stream. */
        attribute minFilterFrequency : FrequencyHertz = 20;
        attribute maxFilterFrequency : FrequencyHertz = 50000;
        attribute filterType : String = "Bandpass";
        attribute maxProcessingLatency : DurationSeconds = 0.001;
    }
    
    requirement def DataRecordingReqDef {
        doc /* The system shall store the cleaned, processed digital audio on a local data recorder for subsequent analysis. */
        attribute minStorageCapacity : StorageGB = 1000;
        attribute fileFormat : String = "WAV";
        attribute minWriteSpeed : MegaBytesPerSec = 50;
    }
    
    requirement def RealTimeOutputReqDef {
        doc /* The system shall output processed digital audio directly for real-time monitoring in addition to storing it on the local recorder. */
        attribute maxOutputLatency : DurationSeconds = 0.001;
        attribute outputProtocol : String = "Ethernet";
    }
    
    requirement def PowerSupplyReqDef {
        doc /* A dedicated internal power supply shall provide the necessary voltage and capacity to run all electronic components of the hydrophone system. */
        attribute nominalVoltage : VoltageVolts = 12;
        attribute minRuntime : DurationSeconds = 259200;
        attribute minCapacity : MilliampHours = 50000;
        attribute batteryType : String = "Lithium-Ion";
    }
    
    requirement def StateMachineReqDef {
        doc /* The hydrophone system shall operate in several states: standby (low-power), active (monitoring), and recording (capturing data). It shall automatically begin recording upon detecting a signal and return to active monitoring when recording is complete. A deactivation signal shall return the system to standby. */
        attribute standbyState : String = "Low-power idle mode";
        attribute activeState : String = "Active monitoring, listening for sounds";
        attribute recordingState : String = "Automatically recording detected data";
        attribute automaticRecording : Boolean = true;
        attribute returnToActiveAfterRecording : Boolean = true;
    }
    
    // ======================== Requirement Usages ========================
    
    requirement hydrophoneSystemReq : UnderwaterHydrophoneReqDef {
        doc /* Overall hydrophone system functional requirement. */
    }
    
    requirement deepSeaOperationReq : DeepSeaOperationReqDef {
        doc /* Deep-sea pressure and waterproofing requirement. */
    }
    
    requirement acousticDetectionReq : AcousticDetectionReqDef {
        doc /* Acoustic wave detection and transduction requirement. */
    }
    
    requirement signalAmplificationReq : SignalAmplificationReqDef {
        doc /* Signal amplification requirement. */
    }
    
    requirement digitizationReq : DigitizationReqDef {
        doc /* Analog-to-digital conversion requirement. */
    }
    
    requirement signalProcessingReq : SignalProcessingReqDef {
        doc /* Bandpass filtering and signal processing requirement. */
    }
    
    requirement dataRecordingReq : DataRecordingReqDef {
        doc /* Local data storage requirement. */
    }
    
    requirement realTimeOutputReq : RealTimeOutputReqDef {
        doc /* Real-time audio output requirement. */
    }
    
    requirement powerSupplyReq : PowerSupplyReqDef {
        doc /* Internal power supply requirement. */
    }
    
    requirement stateMachineReq : StateMachineReqDef {
        doc /* Operational state machine requirement. */
    }
    
    // ======================== System Instantiation ========================
    
    part hydrophone : HydrophoneSystem {
        doc /* Instance of the underwater hydrophone system for deployment in deep-sea environments. */
    }
    
    // ======================== Verification Definitions ========================
    
    verification def PressureTest {
        doc /* Verify the titanium casing withstands pressures up to 1000 bar without deformation or leakage. */
        subject casing : TitaniumCasing;
        objective {
            doc /* Confirm structural integrity at maximum operating depth. */
        }
    }
    
    verification def FrequencyResponseTest {
        doc /* Verify the piezoelectric transducer detects acoustic signals across the full frequency range from 1 Hz to 100 kHz. */
        subject transducer : PiezoelectricTransducer;
        objective {
            doc /* Confirm transducer sensitivity across specified frequency band. */
        }
    }
    
    verification def SignalChainTest {
        doc /* Verify end-to-end signal path from acoustic input to processed digital output maintains signal integrity. */
        subject hydrophone : HydrophoneSystem;
        objective {
            doc /* Confirm the full signal chain produces clean, high-resolution digital audio. */
        }
    }
    
    verification def StateMachineTest {
        doc /* Verify the hydrophone transitions correctly between standby, active, and recording states in response to activation, signal detection, recording completion, and deactivation events. */
        subject hydrophone : HydrophoneSystem;
        objective {
            doc /* Confirm state machine behavior matches specified operational model. */
        }
    }
    
    verification def PowerEnduranceTest {
        doc /* Verify the internal power supply sustains all electronic components for the minimum required runtime. */
        subject powerSupply : PowerSupply;
        objective {
            doc /* Confirm battery capacity and voltage regulation meet endurance requirements. */
        }
    }
}
