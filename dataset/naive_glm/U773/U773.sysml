package DigitalMicrophoneSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQFrequency::*;
    import ISQElectricity::*;
    import ISQTime::*;

    // ===== Value Types =====
    def attribute Pressure : Real { :>> unit = 'Pa'; }
    def attribute Voltage : Real { :>> unit = 'V'; }
    def attribute Current : Real { :>> unit = 'A'; }
    def attribute Power : Real { :>> unit = 'W'; }
    def attribute FrequencyValue : Real { :>> unit = 'Hz'; }
    def attribute SampleRate : Real { :>> unit = 'Hz'; }
    def attribute BitDepth : Integer;
    def attribute Decibel : Real { :>> unit = 'dB'; }
    def attribute Sensitivity : Real { :>> unit = 'mV/Pa'; }
    def attribute Displacement : Real { :>> unit = 'm'; }

    item def SoundWave {
        attribute soundPressure : Pressure;
        attribute frequency : FrequencyValue;
    }

    item def MechanicalVibration {
        attribute displacement : Displacement;
        attribute frequency : FrequencyValue;
    }

    item def AnalogSignal {
        attribute voltage : Voltage;
        attribute frequency : FrequencyValue;
    }

    item def DigitalAudioStream {
        attribute sampleRate : SampleRate;
        attribute bitDepth : BitDepth;
        attribute data : String;
    }

    // ===== Ports =====
    port def AcousticPort {
        out item soundWave : SoundWave;
    }

    port def MechanicalPort {
        out item vibration : MechanicalVibration;
    }

    port def AnalogSignalPort {
        out item signal : AnalogSignal;
    }

    port def DigitalAudioPort {
        out item audioStream : DigitalAudioStream;
    }

    // ===== Requirements =====
    requirement def FrequencyResponseRequirement {
        doc /* The microphone shall capture sound across the full human hearing range. */
        attribute minFrequency : FrequencyValue = 20.0 [Hz];
        attribute maxFrequency : FrequencyValue = 20000.0 [Hz];
        constraint { minFrequency >= 20.0 [Hz] and maxFrequency <= 20000.0 [Hz] }
    }

    requirement def SensitivityRequirement {
        doc /* The microphone shall have high sensitivity for professional-grade capture. */
        attribute minSensitivity : Sensitivity = 35.0 [mV/Pa];
        constraint { minSensitivity >= 35.0 [mV/Pa] }
    }

    requirement def SNRRequirement {
        doc /* The microphone shall achieve a high signal-to-noise ratio for clear recordings. */
        attribute minSNR : Decibel = 80.0 [dB];
        constraint { minSNR >= 80.0 [dB] }
    }

    requirement def SampleRateRequirement {
        doc /* The ADC shall sample at a rate sufficient for high-fidelity audio. */
        attribute minSampleRate : SampleRate = 48000.0 [Hz];
        constraint { minSampleRate >= 48000.0 [Hz] }
    }

    requirement def BitDepthRequirement {
        doc /* The ADC shall produce digital audio with professional bit depth. */
        attribute minBitDepth : BitDepth = 24;
        constraint { minBitDepth >= 24 }
    }

    requirement def DigitalMicrophoneRequirements {
        requirement freqResponse : FrequencyResponseRequirement;
        requirement sensitivity : SensitivityRequirement;
        requirement snr : SNRRequirement;
        requirement sampleRate : SampleRateRequirement;
        requirement bitDepth : BitDepthRequirement;
    }

    // ===== Parts =====
    part def DiaphragmAssembly {
        port in acousticInput : AcousticPort;
        port out mechanicalOutput : MechanicalPort;
        attribute resonanceFrequency : FrequencyValue = 20000.0 [Hz];
        attribute maxDisplacement : Displacement = 0.00001 [m];

        action def Vibrate {
            in sound : SoundWave;
            out vibration : MechanicalVibration;
        }

        action vibrate : Vibrate {
            in sound = acousticInput.soundWave;
            out vibration to mechanicalOutput.vibration;
        }
    }

    part def TransducerElement {
        port in mechanicalInput : MechanicalPort;
        port out electricalOutput : AnalogSignalPort;
        attribute sensitivity : Sensitivity = 40.0 [mV/Pa];
        attribute outputImpedance : Real = 200.0;

        action def Transduce {
            in vibration : MechanicalVibration;
            out signal : AnalogSignal;
        }

        action transduce : Transduce {
            in vibration = mechanicalInput.vibration;
            out signal to electricalOutput.signal;
        }
    }

    part def PreamplifierCircuit {
        port in signalInput : AnalogSignalPort;
        port out amplifiedOutput : AnalogSignalPort;
        attribute gain : Real = 100.0;
        attribute noiseFloor : Decibel = -120.0 [dB];
        attribute powerConsumption : Power = 0.005 [W];

        action def Amplify {
            in inputSignal : AnalogSignal;
            out amplifiedSignal : AnalogSignal;
        }

        action amplify : Amplify {
            in inputSignal = signalInput.signal;
            out amplifiedSignal to amplifiedOutput.signal;
        }
    }

    part def SignalConditioner {
        port in signalInput : AnalogSignalPort;
        port out filteredOutput : AnalogSignalPort;
        attribute lowCutoff : FrequencyValue = 20.0 [Hz];
        attribute highCutoff : FrequencyValue = 20000.0 [Hz];
        attribute filterOrder : Integer = 4;

        action def Filter {
            in inputSignal : AnalogSignal;
            out filteredSignal : AnalogSignal;
        }

        action filter : Filter {
            in inputSignal = signalInput.signal;
            out filteredSignal to filteredOutput.signal;
        }
    }

    part def AnalogToDigitalConverter {
        port in analogInput : AnalogSignalPort;
        port out digitalOutput : DigitalAudioPort;
        attribute sampleRate : SampleRate = 96000.0 [Hz];
        attribute bitDepth : BitDepth = 24;
        attribute dynamicRange : Decibel = 110.0 [dB];

        action def Convert {
            in analogSignal : AnalogSignal;
            out digitalStream : DigitalAudioStream;
        }

        action convert : Convert {
            in analogSignal = analogInput.signal;
            out digitalStream to digitalOutput.audioStream;
        }
    }

    // ===== State Machine =====
    state def MicrophoneStateMachine {
        entry; then Idle;

        state Idle {
            entry { /* Microphone is powered on and waiting for sound input. */ }
            do { /* Monitor acoustic input for incoming sound waves. */ }
        }

        transition from Idle to Active
            when acousticInput.soundWave.soundPressure > 0.001 [Pa]
            guard acousticInput.soundWave.soundPressure > 0.001 [Pa];

        state Active {
            entry { /* Begin capturing and processing audio signal. */ }
            do { /* Execute diaphragm vibration, transduction, amplification, filtering, and conversion. */ }
        }

        transition from Active to Idle
            when digitalOutput.audioStream.data != ""
            guard digitalOutput.audioStream.data != "";
    }

    // ===== Top-level System =====
    part def DigitalMicrophone {
        port in acousticInput : AcousticPort;
        port out digitalOutput : DigitalAudioPort;

        satisfy DigitalMicrophoneRequirements;

        part diaphragm : DiaphragmAssembly {
            port in acousticInput redefines acousticInput;
        }

        part transducer : TransducerElement;
        part preamplifier : PreamplifierCircuit;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter {
            port out digitalOutput redefines digitalOutput;
        }

        // Connections
        connection def MechanicalLink {
            end fromMechanical : MechanicalPort;
            end toMechanical : MechanicalPort;
        }

        connection def ElectricalLink {
            end fromAnalog : AnalogSignalPort;
            end toAnalog : AnalogSignalPort;
        }

        connection diaphragmToTransducer : MechanicalLink
            connect diaphragm.mechanicalOutput to transducer.mechanicalInput;

        connection transducerToPreamp : ElectricalLink
            connect transducer.electricalOutput to preamplifier.signalInput;

        connection preampToConditioner : ElectricalLink
            connect preamplifier.amplifiedOutput to conditioner.signalInput;

        connection conditionerToADC : ElectricalLink
            connect conditioner.filteredOutput to adc.analogInput;

        // Behavior
        exhibit state behavior : MicrophoneStateMachine;

        // Operational flow
        action def CaptureAndProcessAudio {
            in sound : SoundWave;
            out digitalAudio : DigitalAudioStream;

            action vibrate : DiaphragmAssembly::Vibrate {
                in sound;
            }

            action transduce : TransducerElement::Transduce {
                in vibration = vibrate.vibration;
            }

            action amplify : PreamplifierCircuit::Amplify {
                in inputSignal = transduce.signal;
            }

            action filter : SignalConditioner::Filter {
                in inputSignal = amplify.amplifiedSignal;
            }

            action convert : AnalogToDigitalConverter::Convert {
                in analogSignal = filter.filteredSignal;
                out digitalAudio;
            }
        }

        action captureProcess : CaptureAndProcessAudio {
            in sound = acousticInput.soundWave;
            out digitalAudio to digitalOutput.audioStream;
        }
    }
}
