package 'Bose Active Noise Cancellation Headphone System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SoundPressureLevel :> ISQ::PressureValue {
        doc /* Acoustic pressure measured in pascals */
    }
    
    attribute def NoiseReductionLevel :> Real {
        doc /* Noise reduction capability measured in decibels */
    }
    
    attribute def AudioFrequency :> ISQ::FrequencyValue {
        doc /* Audio signal frequency in hertz */
    }
    
    attribute def BatteryCharge :> Real {
        doc /* Battery charge level as percentage 0-100 */
    }
    
    item def AcousticSignal {
        attribute pressure : SoundPressureLevel;
        attribute frequency : AudioFrequency;
        attribute amplitude : Real;
        attribute phase : Real;
    }
    
    item def ElectricalSignal {
        attribute voltage : ISQ::ElectricPotentialValue;
        attribute current : ISQ::ElectricCurrentValue;
    }
    
    port def AcousticInputPort {
        in item ambientSound : AcousticSignal;
    }
    
    port def AcousticOutputPort {
        out item outputSound : AcousticSignal;
    }
    
    port def ElectricalSignalPort {
        in item inputSignal : ElectricalSignal;
        out item outputSignal : ElectricalSignal;
    }
    
    port def PowerSupplyPort {
        out attribute voltage : ISQ::ElectricPotentialValue;
        out attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def FeedforwardMicrophone {
        doc /* External microphone that captures ambient noise before it reaches the user's ear */
        port acousticInput : AcousticInputPort;
        port electricalOutput : ElectricalSignalPort;
        attribute sensitivity : Real;
        
        action captureAmbientNoise {
            in ambientAcoustic : AcousticSignal;
            out electricalRepresentation : ElectricalSignal;
        }
    }
    
    part def FeedbackMicrophone {
        doc /* Internal microphone that monitors residual noise inside the ear cup */
        port acousticInput : AcousticInputPort;
        port electricalOutput : ElectricalSignalPort;
        attribute sensitivity : Real;
        
        action captureResidualNoise {
            in residualAcoustic : AcousticSignal;
            out electricalRepresentation : ElectricalSignal;
        }
    }
    
    part def DigitalSignalProcessor {
        doc /* DSP that analyzes noise and generates anti-phase cancellation signals */
        port feedforwardInput : ElectricalSignalPort;
        port feedbackInput : ElectricalSignalPort;
        port audioInput : ElectricalSignalPort;
        port processedOutput : ElectricalSignalPort;
        port power : PowerSupplyPort;
        
        attribute processingLatency : ISQ::TimeValue;
        attribute samplingRate : AudioFrequency;
        
        action analyzeNoiseCharacteristics {
            in noiseSignal : ElectricalSignal;
            out noiseProfile : AcousticSignal;
        }
        
        action generateAntiPhaseSignal {
            in noiseProfile : AcousticSignal;
            out antiNoiseSignal : ElectricalSignal;
        }
        
        action combineAudioStreams {
            in musicSignal : ElectricalSignal;
            in antiNoiseSignal : ElectricalSignal;
            in feedbackCorrection : ElectricalSignal;
            out finalSignal : ElectricalSignal;
        }
    }
    
    part def SpeakerDriver {
        doc /* Acoustic driver that reproduces music and anti-noise signals */
        port electricalInput : ElectricalSignalPort;
        port acousticOutput : AcousticOutputPort;
        
        attribute impedance : Real;
        attribute powerRating : ISQ::PowerValue;
        attribute frequencyResponse : AudioFrequency[2];
        
        action convertToAcoustic {
            in electricalSignal : ElectricalSignal;
            out acousticWave : AcousticSignal;
        }
    }
    
    part def LithiumIonBattery {
        doc /* Rechargeable battery providing power to active components */
        port powerOutput : PowerSupplyPort;
        
        attribute capacity : ISQ::EnergyValue;
        attribute chargeLevel : BatteryCharge;
        attribute voltage : ISQ::ElectricPotentialValue;
        
        action supplyPower {
            out powerDelivery : ElectricalSignal;
        }
        
        action monitorCharge {
            out currentCharge : BatteryCharge;
        }
    }
    
    part def BluetoothAudioReceiver {
        doc /* Wireless receiver for audio streaming from connected devices */
        port audioOutput : ElectricalSignalPort;
        port power : PowerSupplyPort;
        
        attribute codecSupport : String[*];
        attribute transmissionRange : ISQ::LengthValue;
        
        action receiveWirelessAudio {
            out audioStream : ElectricalSignal;
        }
    }
    
    part def BoseQuietComfortHeadphones {
        doc /* 
            Bose QuietComfort Active Noise Cancellation Headphones deliver 
            world-class audio experience by eliminating unwanted environmental noise.
            
            The system employs a sophisticated dual-microphone architecture combining 
            feedforward and feedback noise cancellation. External microphones capture 
            ambient noise before it reaches the ear, while internal microphones monitor 
            residual noise inside the ear cup. The digital signal processor analyzes 
            these inputs in real-time, generating precisely inverted anti-phase signals 
            that destructively interfere with incoming noise across a broad frequency 
            spectrum. Simultaneously, the system preserves and enhances the desired 
            audio content from wireless sources, delivering immersive sound quality 
            with minimal distortion. Advanced battery management ensures extended 
            operation, while multiple listening modes provide flexibility for different 
            environmental contexts.
        */
        
        attribute achievedNoiseReduction : NoiseReductionLevel;
        attribute totalHarmonicDistortion : Real;
        attribute continuousOperatingTime : Real;
        
        port externalAcousticEnvironment : AcousticInputPort;
        port userAcousticOutput : AcousticOutputPort;
        
        part externalMic : FeedforwardMicrophone {
            doc /* Captures ambient noise from external environment */
            :>> sensitivity = 0.95;
        }
        
        part internalMic : FeedbackMicrophone {
            doc /* Monitors residual noise inside ear cup for correction */
            :>> sensitivity = 0.92;
        }
        
        part processor : DigitalSignalProcessor {
            doc /* Core processing unit for noise analysis and cancellation */
            :>> processingLatency = 0.003[s];
            :>> samplingRate = 48000.0[Hz];
        }
        
        part driver : SpeakerDriver {
            doc /* High-fidelity acoustic driver */
            :>> impedance = 32.0;
            :>> powerRating = 0.5[W];
            :>> frequencyResponse = (20.0[Hz], 20000.0[Hz]);
        }
        
        part battery : LithiumIonBattery {
            doc /* Rechargeable power source */
            :>> capacity = 90000.0[J];
            :>> voltage = 3.7[V];
            :>> chargeLevel = 100.0;
        }
        
        part bluetoothReceiver : BluetoothAudioReceiver {
            doc /* Wireless audio input from paired devices */
            :>> codecSupport = ("AAC", "aptX", "SBC");
            :>> transmissionRange = 10.0[m];
        }
        
        connection feedforwardPath connect 
            externalMic.electricalOutput to processor.feedforwardInput;
        
        connection feedbackPath connect 
            internalMic.electricalOutput to processor.feedbackInput;
        
        connection audioInputPath connect 
            bluetoothReceiver.audioOutput to processor.audioInput;
        
        connection processorOutputPath connect 
            processor.processedOutput to driver.electricalInput;
        
        connection powerToDSP connect 
            battery.powerOutput to processor.power;
        
        connection powerToBluetooth connect 
            battery.powerOutput to bluetoothReceiver.power;
        
        exhibit state operatingModes {
            entry; then poweredOff;
            
            state poweredOff;
            accept powerButtonPressed;
            then poweredOn;
            
            state poweredOn {
                entry; then idle;
                
                state idle;
                accept ancEnabled;
                then activeNoiseCancellation;
                
                state activeNoiseCancellation {
                    entry; then passiveListening;
                    
                    state passiveListening;
                    accept audioStreamStarted;
                    then activeListening;
                    
                    state activeListening;
                    accept audioStreamStopped;
                    then passiveListening;
                }
                accept ancDisabled;
                then idle;
                
                accept transparencyEnabled;
                then transparencyMode;
                
                state transparencyMode;
                accept transparencyDisabled;
                then idle;
            }
            accept powerButtonLongPress;
            then poweredOff;
        }
        
        perform action activeNoiseCancellationCycle {
            doc /* Continuous noise cancellation processing loop */
            
            first start;
            then merge continueCancellation;
            
            then fork parallelCapture;
                action captureExternalNoise : externalMic.captureAmbientNoise {
                    in ambientAcoustic;
                    out externalNoiseSignal : ElectricalSignal;
                }
                
                action captureInternalNoise : internalMic.captureResidualNoise {
                    in residualAcoustic;
                    out internalNoiseSignal : ElectricalSignal;
                }
                
                action receiveAudioStream : bluetoothReceiver.receiveWirelessAudio {
                    out musicSignal : ElectricalSignal;
                }
            then join parallelCapture;
            
            then action processNoise {
                action analyzeFeedforward : processor.analyzeNoiseCharacteristics {
                    in noiseSignal = captureExternalNoise.externalNoiseSignal;
                    out feedforwardProfile : AcousticSignal;
                }
                
                then action generateFeedforwardAntiNoise : processor.generateAntiPhaseSignal {
                    in noiseProfile = analyzeFeedforward.feedforwardProfile;
                    out feedforwardAntiNoise : ElectricalSignal;
                }
                
                action analyzeFeedback : processor.analyzeNoiseCharacteristics {
                    in noiseSignal = captureInternalNoise.internalNoiseSignal;
                    out feedbackProfile : AcousticSignal;
                }
                
                then action generateFeedbackCorrection : processor.generateAntiPhaseSignal {
                    in noiseProfile = analyzeFeedback.feedbackProfile;
                    out feedbackCorrection : ElectricalSignal;
                }
                
                then action mixSignals : processor.combineAudioStreams {
                    in musicSignal = receiveAudioStream.musicSignal;
                    in antiNoiseSignal = generateFeedforwardAntiNoise.feedforwardAntiNoise;
                    in feedbackCorrection = generateFeedbackCorrection.feedbackCorrection;
                    out combinedSignal : ElectricalSignal;
                }
            }
            
            then action reproduceAudio : driver.convertToAcoustic {
                in electricalSignal = processNoise.mixSignals.combinedSignal;
                out finalAcousticOutput : AcousticSignal;
            }
            
            then continueCancellation;
        }
        
        perform action monitorBatteryStatus {
            doc /* Continuous battery monitoring for power management */
            
            loop {
                action checkCharge : battery.monitorCharge {
                    out currentCharge : BatteryCharge;
                }
                
                then decide;
                    if checkCharge.currentCharge < 10.0 then lowBatteryWarning;
                    if checkCharge.currentCharge >= 10.0 then continueOperation;
                
                action lowBatteryWarning {
                    doc /* Alert user of low battery condition */
                }
                
                action continueOperation {
                    doc /* Normal operation continues */
                }
            }
        }
    }
    
    requirement def NoiseReductionPerformance {
        doc /* The system shall achieve at least 30 dB noise reduction in the 50 Hz to 2000 Hz frequency range */
        subject headphones : BoseQuietComfortHeadphones;
        require constraint {
            headphones.achievedNoiseReduction >= 30.0
        }
    }
    
    requirement def AudioFidelityRequirement {
        doc /* The system shall maintain total harmonic distortion below 0.3% at nominal listening levels */
        subject headphones : BoseQuietComfortHeadphones;
        require constraint {
            headphones.totalHarmonicDistortion < 0.003
        }
    }
    
    requirement def BatteryOperatingTime {
        doc /* The system shall operate continuously for at least 24 hours on a single full charge */
        subject headphones : BoseQuietComfortHeadphones;
        require constraint {
            headphones.continuousOperatingTime >= 24.0
        }
    }
    
    requirement def ProcessingLatency {
        doc /* Signal processing latency shall not exceed 5 milliseconds to prevent audible artifacts */
        subject processor : DigitalSignalProcessor;
        require constraint {
            processor.processingLatency <= 0.005[s]
        }
    }
    
    part boseQC45 : BoseQuietComfortHeadphones {
        doc /* Specific instance of Bose QuietComfort 45 headphones */
        
        :>> achievedNoiseReduction = 32.0;
        :>> totalHarmonicDistortion = 0.002;
        :>> continuousOperatingTime = 24.0;
        
        satisfy noiseReq : NoiseReductionPerformance;
        satisfy audioReq : AudioFidelityRequirement;
        satisfy batteryReq : BatteryOperatingTime;
        satisfy latencyReq : ProcessingLatency by processor;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Bose Active Noise Cancellation Headphone System'::*;

    part testSubject : BoseQuietComfortHeadphones {
    // TODO(human): unsupported input type for ambientAcoustic: unknown (missing declared type)
    }
}
