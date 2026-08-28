package 'Sound Reproduction System' {
    private import ScalarValues::*;

    package Definitions {
        unit Hz;
        unit Pa;
        unit W_per_m2;
        unit V;
        unit A;
        unit W;
        unit K;
        unit kg_per_m3;
        unit V_per_Pa;

        value type FrequencyValue :> Real { unit Hz; }
        value type SoundPressureLevel :> Real { unit Pa; }
        value type SoundIntensity :> Real { unit W_per_m2; }
        value type VoltageValue :> Real { unit V; }
        value type CurrentValue :> Real { unit A; }
        value type PowerValue :> Real { unit W; }
        value type GainValue :> Real;
        value type TemperatureValue :> Real { unit K; }
        value type PressureValue :> Real { unit Pa; }
        value type DensityValue :> Real { unit kg_per_m3; }
        value type SensitivityValue :> Real { unit V_per_Pa; }

        item def SoundWave {
            attribute frequency : FrequencyValue;
            attribute amplitude : SoundPressureLevel;
            attribute intensity : SoundIntensity;
        }
        item def ElectricalSignal {
            attribute voltage : VoltageValue;
            attribute frequency : FrequencyValue;
        }
        item def ElectricalPower {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
        }

        port def SoundInPort {
            in sound : SoundWave;
        }
        port def SoundOutPort {
            out sound : SoundWave;
        }
        port def SignalInPort {
            in signal : ElectricalSignal;
        }
        port def SignalOutPort {
            out signal : ElectricalSignal;
        }
        port def PowerInPort {
            in power : ElectricalPower;
        }
        port def PowerOutPort {
            out power : ElectricalPower;
        }

        action def 'Capture Audio' {
            in sound : SoundWave;
            out signal : ElectricalSignal;
        }
        action def 'Amplify Signal' {
            in signalIn : ElectricalSignal;
            out signalOut : ElectricalSignal;
        }
        action def 'Playback Audio' {
            in signal : ElectricalSignal;
            out sound : SoundWave;
        }

        attribute def 'Obstacle Encountered';
        attribute def 'Absorption Complete';
        attribute def 'New Wave Generated';

        state def 'Sound Wave Lifecycle' {
            entry; then propagating;
            state propagating;
            accept 'Obstacle Encountered'
                then reflecting;
            state reflecting;
            accept 'Absorption Complete'
                then absorbed;
            state absorbed;
            accept 'New Wave Generated'
                then propagating;
        }

        part def Microphone {
            attribute sensitivity : SensitivityValue;
            attribute maxFrequency : FrequencyValue;
            port soundInPort : SoundInPort;
            port signalOutPort : SignalOutPort;
            port powerInPort : PowerInPort;
            perform action 'capture audio' : 'Capture Audio';
        }
        part def Amplifier {
            attribute gain : GainValue;
            port signalInPort : SignalInPort;
            port signalOutPort : SignalOutPort;
            port powerInPort : PowerInPort;
            perform action 'amplify signal' : 'Amplify Signal';
        }
        part def Speaker {
            port signalInPort : SignalInPort;
            port soundOutPort : SoundOutPort;
            port powerInPort : PowerInPort;
            perform action 'playback audio' : 'Playback Audio';
        }
        part def PowerSupply {
            attribute outputPower : PowerValue;
            port powerOutPort : PowerOutPort;
        }
        part def AcousticEnvironment {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute density : DensityValue;
            port soundInPort : SoundInPort;
            port soundOutPort : SoundOutPort;
            exhibit state 'sound wave lifecycle' : 'Sound Wave Lifecycle';
        }

        part def SoundSystem {
            part microphone : Microphone;
            part amplifier : Amplifier;
            part speaker : Speaker;
            part 'power supply' : PowerSupply;
            part 'acoustic environment' : AcousticEnvironment;

            flow 'incoming sound' of SoundWave
                from 'acoustic environment'.soundOutPort
                to microphone.soundInPort;

            flow 'weak signal' of ElectricalSignal
                from microphone.signalOutPort
                to amplifier.signalInPort;

            flow 'amplified signal' of ElectricalSignal
                from amplifier.signalOutPort
                to speaker.signalInPort;

            flow 'output sound' of SoundWave
                from speaker.soundOutPort
                to 'acoustic environment'.soundInPort;

            flow 'mic power' of ElectricalPower
                from 'power supply'.powerOutPort
                to microphone.powerInPort;
            flow 'amp power' of ElectricalPower
                from 'power supply'.powerOutPort
                to amplifier.powerInPort;
            flow 'speaker power' of ElectricalPower
                from 'power supply'.powerOutPort
                to speaker.powerInPort;

            perform action 'reproduce sound' {
                action 'capture audio' : 'Capture Audio' {
                    in sound : SoundWave;
                    out signal : ElectricalSignal;
                }
                flow 'capture audio'.signal to 'amplify signal'.signalIn;
                action 'amplify signal' : 'Amplify Signal' {
                    in signalIn : ElectricalSignal;
                    out signalOut : ElectricalSignal;
                }
                flow 'amplify signal'.signalOut to 'playback audio'.signal;
                action 'playback audio' : 'Playback Audio' {
                    in signal : ElectricalSignal;
                    out sound : SoundWave;
                }
            }
        }

        requirement def 'Amplification Requirement' {
            subject amplifier : Amplifier;
            text "The amplifier shall increase signal strength by the specified gain.";
        }
        requirement def 'Frequency Response Requirement' {
            subject microphone : Microphone;
            text "The microphone shall detect frequencies up to its maximum.";
        }
        requirement def 'Power Supply Requirement' {
            subject powerSupply : PowerSupply;
            text "The power supply shall provide sufficient electrical power to all components.";
        }
    }

    package Usages {
        private import Definitions::*;

        part 'sound system' : SoundSystem {
            requirement 'amp req' : 'Amplification Requirement' {
                subject = amplifier;
            }
            requirement 'freq req' : 'Frequency Response Requirement' {
                subject = microphone;
            }
            requirement 'power req' : 'Power Supply Requirement' {
                subject = 'power supply';
            }
        }
    }
}
