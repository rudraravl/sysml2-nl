package DigitalMicrophoneSystem {
    private import ISQ::FrequencyValue;
    private import ISQ::ElectricPotentialValue;
    private import SI::Hz;
    private import ScalarValues::*;
    
    item def SoundWave;
    item def MechanicalVibration;
    item def ElectricalSignal {
        attribute voltage : ElectricPotentialValue;
    }
    item def AnalogAudioSignal {
        attribute voltage : ElectricPotentialValue;
        attribute frequency : FrequencyValue;
    }
    item def DigitalAudioStream {
        attribute sampleRate : FrequencyValue;
        attribute bitDepth : Integer;
    }
    
    attribute def SoundDetected;
    attribute def AudioOutputComplete;
    
    action def CaptureSound { in item sound : SoundWave; out item vibration : MechanicalVibration; }
    action def TransduceSignal { in item vibration : MechanicalVibration; out item weakSignal : ElectricalSignal; }
    action def Preamplify { in item weakSignal : ElectricalSignal; out item amplifiedSignal : AnalogAudioSignal; }
    action def ConditionSignal { in item amplifiedSignal : AnalogAudioSignal; out item refinedSignal : AnalogAudioSignal; }
    action def ConvertToDigital { in item refinedSignal : AnalogAudioSignal; out item digitalStream : DigitalAudioStream; }
    
    action def ProcessAudio {
        in item sound : SoundWave;
        out item digitalStream : DigitalAudioStream;
        
        action captureSound : CaptureSound {
            in item sound = ProcessAudio::sound;
            out item vibration;
        }
        flow from captureSound.vibration to transduceSignal.vibration;
        
        action transduceSignal : TransduceSignal {
            in item vibration;
            out item weakSignal;
        }
        flow from transduceSignal.weakSignal to preamplify.weakSignal;
        
        action preamplify : Preamplify {
            in item weakSignal;
            out item amplifiedSignal;
        }
        flow from preamplify.amplifiedSignal to conditionSignal.amplifiedSignal;
        
        action conditionSignal : ConditionSignal {
            in item amplifiedSignal;
            out item refinedSignal;
        }
        flow from conditionSignal.refinedSignal to convertToDigital.refinedSignal;
        
        action convertToDigital : ConvertToDigital {
            in item refinedSignal;
            out item digitalStream = ProcessAudio::digitalStream;
        }
    }
    
    part def DiaphragmAssembly {
        in item sound : SoundWave;
        out item vibration : MechanicalVibration;
        perform action captureSound : CaptureSound {
            in item sound = DiaphragmAssembly::sound;
            out item vibration = DiaphragmAssembly::vibration;
        }
    }
    
    part def TransducerElement {
        in item vibration : MechanicalVibration;
        out item weakSignal : ElectricalSignal;
        perform action transduceSignal : TransduceSignal {
            in item vibration = TransducerElement::vibration;
            out item weakSignal = TransducerElement::weakSignal;
        }
    }
    
    part def PreamplifierCircuit {
        in item weakSignal : ElectricalSignal;
        out item amplifiedSignal : AnalogAudioSignal;
        perform action preamplify : Preamplify {
            in item weakSignal = PreamplifierCircuit::weakSignal;
            out item amplifiedSignal = PreamplifierCircuit::amplifiedSignal;
        }
    }
    
    part def SignalConditioner {
        in item amplifiedSignal : AnalogAudioSignal;
        out item refinedSignal : AnalogAudioSignal;
        perform action conditionSignal : ConditionSignal {
            in item amplifiedSignal = SignalConditioner::amplifiedSignal;
            out item refinedSignal = SignalConditioner::refinedSignal;
        }
    }
    
    part def AnalogToDigitalConverter {
        in item refinedSignal : AnalogAudioSignal;
        out item digitalStream : DigitalAudioStream;
        perform action convertToDigital : ConvertToDigital {
            in item refinedSignal = AnalogToDigitalConverter::refinedSignal;
            out item digitalStream = AnalogToDigitalConverter::digitalStream;
        }
    }
    
    state def MicrophoneStateMachine {
        state idle;
        state active;
        transition first idle accept soundDetected : SoundDetected then active;
        transition first active accept audioOutputComplete : AudioOutputComplete then idle;
    }
    
    part def DigitalMicrophone {
        in item sound : SoundWave;
        out item digitalStream : DigitalAudioStream;
        
        part diaphragm : DiaphragmAssembly {
            in item sound = DigitalMicrophone::sound;
            out item vibration;
        }
        part transducer : TransducerElement {
            in item vibration = diaphragm.vibration;
            out item weakSignal;
        }
        part preamplifier : PreamplifierCircuit {
            in item weakSignal = transducer.weakSignal;
            out item amplifiedSignal;
        }
        part conditioner : SignalConditioner {
            in item amplifiedSignal = preamplifier.amplifiedSignal;
            out item refinedSignal;
        }
        part adc : AnalogToDigitalConverter {
            in item refinedSignal = conditioner.refinedSignal;
            out item digitalStream = DigitalMicrophone::digitalStream;
        }
        
        state microphoneState : MicrophoneStateMachine;
    }
    
    requirement def WideFrequencyResponse {
        doc /* The microphone must capture frequencies within the human hearing range (20 Hz to 20,000 Hz). */
        attribute minFrequency : FrequencyValue = 20 [Hz];
        attribute maxFrequency : FrequencyValue = 20000 [Hz];
    }
    
    requirement def HighSensitivity {
        doc /* The microphone must have high sensitivity to capture weak sound waves. */
        attribute minSensitivity : Real = 10.0;
    }
    
    requirement def HighSignalToNoiseRatio {
        doc /* The microphone must maintain a high signal-to-noise ratio for clear recordings. */
        attribute minSNR : Real = 80.0;
    }
    
    requirement microphoneRequirements {
        subject digitalMicrophone : DigitalMicrophone;
        requirement wideFrequencyResponse : WideFrequencyResponse;
        requirement highSensitivity : HighSensitivity;
        requirement highSignalToNoiseRatio : HighSignalToNoiseRatio;
    }
}
