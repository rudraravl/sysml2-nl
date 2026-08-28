package SoundReproductionSystem {

    package Definitions {

        value type Frequency :> Real { unit 'Hz'; }
        value type SoundPressure :> Real { unit 'Pa'; }
        value type SoundIntensity :> Real { unit 'W/m^2'; }
        value type Temperature :> Real { unit 'K'; }
        value type Pressure :> Real { unit 'Pa'; }
        value type Density :> Real { unit 'kg/m^3'; }
        value type Voltage :> Real { unit 'V'; }
        value type Gain :> Real { unit 'dB'; }
        value type Sensitivity :> Real { unit 'mV/Pa'; }
        value type Power :> Real { unit 'W'; }
        value type Amplitude :> Real { unit 'Pa'; }
        value type Length :> Real { unit 'm'; }
        value type Speed :> Real { unit 'm/s'; }

        item def SoundWave {
            attribute frequency : Frequency;
            attribute amplitude : Amplitude;
            attribute intensity : SoundIntensity;
            attribute wavelength : Length;
        }

        item def ElectricalSignal {
            attribute voltage : Voltage;
            attribute frequency : Frequency;
        }

        item def ElectricalPower {
            attribute voltage : Voltage;
            attribute power : Power;
        }

        port def AcousticPort {
            out item sound : SoundWave;
        }

        port def SignalPort {
            out item signal : ElectricalSignal;
        }

        port def PowerPort {
            out item power : ElectricalPower;
        }

        state def SoundWaveLifecycle {
            entry; then Propagating;

            state Propagating {
                entry; 
                transition Propagating -> Reflected 
                    when (obstacleEncountered == true);
                transition Propagating -> Absorbed 
                    when (absorbed == true);
            }

            state Reflected {
                entry;
                transition Reflected -> Propagating 
                    when (reflected == true);
                transition Reflected -> Absorbed 
                    when (absorbed == true);
            }

            state Absorbed {
                entry;
            }
        }
    }

    package Components {

        part def Microphone {
            attribute sensitivity : Sensitivity;
            attribute maxFrequency : Frequency;
            attribute operatingPower : Power;

            port acousticIn : AcousticPort;
            port signalOut : SignalPort;
            port powerIn : PowerPort;

            action def ConvertAcousticToElectric {
                in incomingSound : SoundWave;
                out outgoingSignal : ElectricalSignal;
            }

            perform action convert : ConvertAcousticToElectric {
                in incomingSound = acousticIn.sound;
                out outgoingSignal = signalOut.signal;
            }
        }

        part def Amplifier {
            attribute gain : Gain;
            attribute operatingPower : Power;

            port signalIn : SignalPort;
            port signalOut : SignalPort;
            port powerIn : PowerPort;

            action def AmplifySignal {
                in incomingSignal : ElectricalSignal;
                in gainValue : Gain;
                out outgoingSignal : ElectricalSignal;
            }

            perform action amplify : AmplifySignal {
                in incomingSignal = signalIn.signal;
                in gainValue = gain;
                out outgoingSignal = signalOut.signal;
            }
        }

        part def Speaker {
            attribute maxPower : Power;
            attribute efficiency : Real;
            attribute operatingPower : Power;

            port signalIn : SignalPort;
            port acousticOut : AcousticPort;
            port powerIn : PowerPort;

            action def ConvertElectricToAcoustic {
                in incomingSignal : ElectricalSignal;
                out outgoingSound : SoundWave;
            }

            perform action convert : ConvertElectricToAcoustic {
                in incomingSignal = signalIn.signal;
                out outgoingSound = acousticOut.sound;
            }
        }

        part def PowerSupply {
            attribute outputVoltage : Voltage;
            attribute maxPower : Power;

            port micPowerOut : PowerPort;
            port ampPowerOut : PowerPort;
            port speakerPowerOut : PowerPort;

            action def SupplyPower {
                out micPower : ElectricalPower;
                out ampPower : ElectricalPower;
                out speakerPower : ElectricalPower;
            }

            perform action supply : SupplyPower {
                out micPower = micPowerOut.power;
                out ampPower = ampPowerOut.power;
                out speakerPower = speakerPowerOut.power;
            }
        }

        part def AcousticEnvironment {
            attribute temperature : Temperature;
            attribute pressure : Pressure;
            attribute density : Density;
            attribute soundSpeed : Speed;

            port ambientAcoustic : AcousticPort;

            exhibit state lifecycle : SoundWaveLifecycle {
                attribute obstacleEncountered : Boolean;
                attribute absorbed : Boolean;
                attribute reflected : Boolean;
            }

            action def PropagateSound {
                in sound : SoundWave;
                in mediumTemp : Temperature;
                in mediumPressure : Pressure;
                in mediumDensity : Density;
                out propagatedSound : SoundWave;
            }

            perform action propagate : PropagateSound {
                in sound = ambientAcoustic.sound;
                in mediumTemp = temperature;
                in mediumPressure = pressure;
                in mediumDensity = density;
                out propagatedSound = ambientAcoustic.sound;
            }
        }
    }

    package System {

        part def SoundReproductionSystem {
            part microphone : Components::Microphone {
                attribute sensitivity = 20 [mV/Pa];
                attribute maxFrequency = 20000 [Hz];
                attribute operatingPower = 0.5 [W];
            }

            part amplifier : Components::Amplifier {
                attribute gain = 40 [dB];
                attribute operatingPower = 50 [W];
            }

            part speaker : Components::Speaker {
                attribute maxPower = 100 [W];
                attribute efficiency = 0.85;
                attribute operatingPower = 10 [W];
            }

            part powerSupply : Components::PowerSupply {
                attribute outputVoltage = 12 [V];
                attribute maxPower = 200 [W];
            }

            part environment : Components::AcousticEnvironment {
                attribute temperature = 293.15 [K];
                attribute pressure = 101325 [Pa];
                attribute density = 1.225 [kg/m^3];
                attribute soundSpeed = 343 [m/s];
            }

            connection powerToMic : PowerPort connect powerSupply.micPowerOut to microphone.powerIn;
            connection powerToAmp : PowerPort connect powerSupply.ampPowerOut to amplifier.powerIn;
            connection powerToSpeaker : PowerPort connect powerSupply.speakerPowerOut to speaker.powerIn;

            connection envToMic : AcousticPort connect environment.ambientAcoustic to microphone.acousticIn;
            connection micToAmp : SignalPort connect microphone.signalOut to amplifier.signalIn;
            connection ampToSpeaker : SignalPort connect amplifier.signalOut to speaker.signalIn;
            connection speakerToEnv : AcousticPort connect speaker.acousticOut to environment.ambientAcoustic;
        }
    }

    package Requirements {

        requirement def AmplificationRequirement {
            attribute minGain : Gain = 30 [dB];
            attribute maxGain : Gain = 60 [dB];
            doc /The amplifier shall boost the signal by at least minGain and at most maxGain./
        }

        requirement def FrequencyResponseRequirement {
            attribute minFrequency : Frequency = 20 [Hz];
            attribute maxFrequency : Frequency = 20000 [Hz];
            doc /The system shall accurately reproduce frequencies between minFrequency and maxFrequency./
        }

        requirement def PowerSupplyRequirement {
            attribute requiredVoltage : Voltage = 12 [V];
            attribute requiredMaxPower : Power = 200 [W];
            doc /The power supply shall provide requiredVoltage and support up to requiredMaxPower./
        }

        requirement def AcousticEnvironmentRequirement {
            attribute minTemp : Temperature = 273.15 [K];
            attribute maxTemp : Temperature = 313.15 [K];
            attribute nominalPressure : Pressure = 101325 [Pa];
            doc /The system shall operate in air between minTemp and maxTemp at nominalPressure./
        }

        requirement def SoundReproductionSystemRequirement {
            doc /The sound reproduction system shall capture environmental sound, amplify it, and reproduce it at higher volume./

            subject system : System::SoundReproductionSystem;

            satisfy amplificationReq : AmplificationRequirement {
                subject system.amplifier;
            }

            satisfy frequencyResponseReq : FrequencyResponseRequirement {
                subject system.microphone;
            }

            satisfy powerSupplyReq : PowerSupplyRequirement {
                subject system.powerSupply;
            }

            satisfy acousticEnvReq : AcousticEnvironmentRequirement {
                subject system.environment;
            }
        }
    }
}
