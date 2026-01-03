package SoundSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def FrequencyValue :> Real;
    attribute def AmplitudeValue :> Real;
    attribute def PhaseValue :> Real;
    
    enum def SoundState {
        silent;
        propagating;
        reflected;
        absorbed;
    }
    
    enum def MediumType {
        air;
        water;
        solid;
    }
    
    item def Medium {
        attribute mediumType : MediumType;
        attribute density : DensityValue;
        attribute temperature : TemperatureValue;
        attribute speedOfSound : SpeedValue;
    }
    
    item def SoundWave {
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
        attribute phase : PhaseValue;
        attribute wavelength : LengthValue;
        attribute intensity : PowerValue;
        attribute currentState : SoundState;
        
        ref item propagationMedium : Medium;
    }
    
    port def SoundPort {
        in wave : SoundWave;
    }
    
    port def SoundOutPort {
        out wave : SoundWave;
    }
    
    port def PowerPort {
        in power : PowerValue;
    }
    
    part def Microphone {
        attribute sensitivity : Real;
        attribute maxFrequency : FrequencyValue;
        
        port acousticInput : SoundPort;
        port electricalOutput {
            out signal : Real;
        }
        port power : PowerPort;
        
        action captureSound {
            in soundWave : SoundWave;
            out electricalSignal : Real;
            
            assert constraint {
                electricalSignal == soundWave.amplitude * sensitivity
            }
        }
    }
    
    part def Amplifier {
        attribute gain : Real;
        attribute maxPower : PowerValue;
        
        port signalInput {
            in signal : Real;
        }
        port signalOutput {
            out signal : Real;
        }
        port power : PowerPort;
        
        action amplifySignal {
            in inputSignal : Real;
            out outputSignal : Real;
            
            assert constraint {
                outputSignal == inputSignal * gain
            }
        }
    }
    
    part def Speaker {
        attribute efficiency : Real;
        attribute maxPower : PowerValue;
        attribute nominalImpedance : Real;
        
        port electricalInput {
            in signal : Real;
        }
        port acousticOutput : SoundOutPort;
        port power : PowerPort;
        
        action emitSound {
            in electricalSignal : Real;
            out soundWave : SoundWave;
            
            assert constraint {
                soundWave.amplitude == electricalSignal * efficiency
            }
        }
    }
    
    part def PowerSupply {
        attribute voltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute capacity : PowerValue;
        
        port powerOutput {
            out power : PowerValue;
        }
    }
    
    part def AcousticEnvironment {
        attribute ambientTemperature : TemperatureValue;
        attribute ambientPressure : PressureValue;
        attribute humidity : Real;
        
        part medium : Medium {
            attribute :>> mediumType = MediumType::air;
            attribute :>> density = 1.225 [kg/m^3];
            attribute :>> temperature = ambientTemperature;
            attribute :>> speedOfSound = 343.0 [m/s];
        }
    }
    
    action def GenerateSound {
        in sourceFrequency : FrequencyValue;
        in sourceAmplitude : AmplitudeValue;
        in sourcePhase : PhaseValue;
        out generatedWave : SoundWave;
    }
    
    action def PropagateSound {
        in wave : SoundWave;
        in medium : Medium;
        in distance : LengthValue;
        out propagatedWave : SoundWave;
        
        assert constraint attenuationLaw {
            propagatedWave.intensity == wave.intensity / (distance * distance)
        }
    }
    
    action def DetectSound {
        in incomingWave : SoundWave;
        in threshold : AmplitudeValue;
        out isDetected : Boolean;
        out detectedFrequency : FrequencyValue;
        out detectedAmplitude : AmplitudeValue;
    }
    
    action def ProcessAudioSignal {
        first start;
        then action capture : DetectSound {
            in incomingWave : SoundWave;
            in threshold : AmplitudeValue;
            out isDetected : Boolean;
            out detectedFrequency : FrequencyValue;
            out detectedAmplitude : AmplitudeValue;
        }
        then decide;
            if capture.isDetected then amplify;
            if !capture.isDetected then start;
        action amplify {
            in inputLevel : Real = capture.detectedAmplitude;
            out outputLevel : Real;
        }
        then action emit : GenerateSound {
            in sourceFrequency = capture.detectedFrequency;
            in sourceAmplitude = amplify.outputLevel;
            in sourcePhase : PhaseValue;
            out generatedWave : SoundWave;
        }
        then done;
    }
    
    state def SoundLifecycle {
        entry; then idle;
        
        state idle;
        
        transition idle_to_generating
            first idle
            accept at startTime
            then generating;
        
        state generating;
        
        transition generating_to_propagating
            first generating
            if amplitude > 0.0
            then propagating;
        
        state propagating;
        
        transition propagating_to_reflecting
            first propagating
            accept when encounterObstacle
            then reflecting;
        
        transition propagating_to_absorbing
            first propagating
            if amplitude < 0.01
            then absorbing;
        
        state reflecting;
        
        transition reflecting_to_propagating
            first reflecting
            then propagating;
        
        state absorbing;
        
        transition absorbing_to_idle
            first absorbing
            then idle;
    }
    
    part soundReproductionSystem {
        attribute operatingFrequency : FrequencyValue = 1000.0;
        attribute operatingAmplitude : AmplitudeValue = 1.0;
        attribute totalPowerConsumption : PowerValue = powerSupply.capacity;
        
        part microphone : Microphone {
            attribute :>> sensitivity = 0.02;
            attribute :>> maxFrequency = 20000.0;
            
            perform action :>> captureSound;
        }
        
        part amplifier : Amplifier {
            attribute :>> gain = 10.0;
            attribute :>> maxPower = 50.0 [W];
            
            perform action :>> amplifySignal;
        }
        
        part speaker : Speaker {
            attribute :>> efficiency = 0.85;
            attribute :>> maxPower = 100.0 [W];
            attribute :>> nominalImpedance = 8.0;
            
            perform action :>> emitSound;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> voltage = 12.0 [V];
            attribute :>> maxCurrent = 10.0 [A];
            attribute :>> capacity = 120.0 [W];
        }
        
        part environment : AcousticEnvironment {
            attribute :>> ambientTemperature = 293.15 [K];
            attribute :>> ambientPressure = 101325.0 [Pa];
            attribute :>> humidity = 0.5;
        }
        
        item inputSound : SoundWave {
            attribute :>> frequency = operatingFrequency;
            attribute :>> amplitude = operatingAmplitude;
            attribute :>> phase = 0.0;
            attribute :>> wavelength = environment.medium.speedOfSound / frequency;
            attribute :>> intensity = amplitude * amplitude [W];
            attribute :>> currentState = SoundState::propagating;
            
            ref item :>> propagationMedium = environment.medium;
            
            exhibit state lifecycle : SoundLifecycle;
        }
        
        item outputSound : SoundWave {
            attribute :>> frequency = inputSound.frequency;
            attribute :>> amplitude = inputSound.amplitude * amplifier.gain * speaker.efficiency;
            attribute :>> phase = inputSound.phase;
            attribute :>> wavelength = inputSound.wavelength;
            attribute :>> intensity = amplitude * amplitude [W];
            attribute :>> currentState = SoundState::propagating;
            
            ref item :>> propagationMedium = environment.medium;
        }
        
        connection micToAmp connect microphone.electricalOutput to amplifier.signalInput;
        connection ampToSpk connect amplifier.signalOutput to speaker.electricalInput;
        connection powerToMic connect powerSupply.powerOutput to microphone.power;
        connection powerToAmp connect powerSupply.powerOutput to amplifier.power;
        connection powerToSpk connect powerSupply.powerOutput to speaker.power;
        
        perform action processAudio : ProcessAudioSignal;
    }
    
    requirement <'REQ-001'> primaryFunction {
        doc /* The sound reproduction system shall capture acoustic sound waves 
             * from the environment, amplify the electrical signal representation, 
             * and reproduce the sound through a speaker with enhanced amplitude 
             * while maintaining frequency fidelity.
             */
        subject system :> soundReproductionSystem;
    }
    
    requirement <'REQ-002'> frequencyResponse {
        doc /* The system shall accurately reproduce sound frequencies 
             * in the range of 20 Hz to 20 kHz with less than 3 dB variation.
             */
        subject system :> soundReproductionSystem;
        
        require constraint {
            system.microphone.maxFrequency >= 20000.0 and
            system.operatingFrequency >= 20.0 and
            system.operatingFrequency <= 20000.0
        }
    }
    
    requirement <'REQ-003'> amplificationGain {
        doc /* The system shall provide a minimum amplification gain of 10x 
             * to ensure adequate sound reproduction levels.
             */
        subject amp :> soundReproductionSystem.amplifier;
        
        require constraint {
            amp.gain >= 10.0
        }
    }
    
    requirement <'REQ-004'> powerEfficiency {
        doc /* The system shall operate within the power supply capacity 
             * and the speaker shall maintain minimum 80% efficiency.
             */
        subject system :> soundReproductionSystem;
        
        require constraint {
            system.speaker.efficiency >= 0.80 and
            system.totalPowerConsumption <= system.powerSupply.capacity
        }
    }
    
    requirement <'REQ-005'> environmentalOperation {
        doc /* The system shall operate in standard atmospheric conditions 
             * with temperature range of 273-313 K and standard pressure.
             */
        subject env :> soundReproductionSystem.environment;
        
        require constraint {
            env.ambientTemperature >= 273.15 [K] and
            env.ambientTemperature <= 313.15 [K] and
            env.ambientPressure >= 95000.0 [Pa] and
            env.ambientPressure <= 105000.0 [Pa]
        }
    }
    
    satisfy primaryFunction by soundReproductionSystem;
    satisfy frequencyResponse by soundReproductionSystem.microphone;
    satisfy amplificationGain by soundReproductionSystem.amplifier;
    satisfy powerEfficiency by soundReproductionSystem.speaker;
    satisfy environmentalOperation by soundReproductionSystem.environment;
}
