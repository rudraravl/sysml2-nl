package SNSPD_System {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def TemperatureValue :> ISQ::thermodynamic_temperature;
    attribute def CurrentValue :> ISQ::electric_current;
    attribute def VoltageValue :> ISQ::electric_potential;
    attribute def TimeStampValue :> ScalarValues::Real;
    attribute def DurationValue :> ISQ::duration;
    attribute def GainValue :> ScalarValues::Real;
    
    item def Photon {
        attribute energy : ISQ::energy;
        attribute wavelength : ISQ::length;
    }
    
    item def DetectionPulse {
        attribute amplitude : VoltageValue;
        attribute timestamp : TimeStampValue;
    }
    
    item def DigitalPulse {
        attribute timestamp : TimeStampValue;
        attribute valid : ScalarValues::Boolean;
    }
    
    item def CryoCoolant;
    
    attribute def PhotonArrival;
    
    part def CryogenicRefrigerator {
        out item coolantFlow : CryoCoolant;
        attribute targetTemp : TemperatureValue := 2.5 [K];
        attribute achievedTemp : TemperatureValue;
    }
    
    part def BiasCurrentSource {
        out item biasCurrentOut : CurrentValue;
        attribute biasLevel : CurrentValue := 0.000015 [A];
        attribute thresholdCurrent : CurrentValue := 0.000018 [A];
    }
    
    part def SuperconductingNanowire {
        in item coolantIn : CryoCoolant;
        in item biasCurrentIn : CurrentValue;
        in item photonIn : Photon;
        out item pulseOut : DetectionPulse;
        
        attribute temperature : TemperatureValue;
        attribute isSuperconducting : ScalarValues::Boolean := true;
        attribute deadTime : DurationValue := 0.00000001 [s];
        attribute recoveryElapsed : DurationValue := 0 [s];
        
        action absorbPhoton {
            assign isSuperconducting := false;
        }
        
        action generatePulse {
            out pulse : DetectionPulse;
            assign pulse.amplitude := 0.001 [V];
        }
        
        action recover {
            assign isSuperconducting := true;
        }
        
        state def NanowireStates {
            in nanowire : SuperconductingNanowire;
            entry; then ready;
            accept PhotonArrival then hotspot;
            state hotspot {
                entry assign nanowire.isSuperconducting := false;
            }
            then recovering;
            state recovering {
                entry assign nanowire.recoveryElapsed := 0 [s];
                do assign nanowire.isSuperconducting := true;
            }
            then ready;
            state ready {
                entry assign nanowire.isSuperconducting := true;
            }
        }
        
        state nanowireBehavior : NanowireStates {
            in nanowire = this;
        }
    }
    
    part def ReadoutAmplifier {
        in item pulseIn : DetectionPulse;
        out item amplifiedOut : DetectionPulse;
        attribute gain : GainValue := 1000.0;
        
        action amplify {
            in input : DetectionPulse;
            out output : DetectionPulse;
            assign output.amplitude := input.amplitude * gain;
            assign output.timestamp := input.timestamp;
        }
    }
    
    part def PulseDiscriminator {
        in item signalIn : DetectionPulse;
        out item digitalOut : DigitalPulse;
        attribute threshold : VoltageValue := 0.00005 [V];
        
        action discriminate {
            in input : DetectionPulse;
            out output : DigitalPulse;
            assign output.timestamp := input.timestamp;
            assign output.valid := input.amplitude >= threshold;
        }
    }
    
    part def TimingModule {
        in item digitalIn : DigitalPulse;
        attribute recordedCount : ScalarValues::Integer := 0;
        attribute lastArrivalTime : TimeStampValue;
        attribute timingResolution : DurationValue := 0.00000000005 [s];
        
        action recordEvent {
            in pulse : DigitalPulse;
            assign recordedCount := recordedCount + 1;
            assign lastArrivalTime := pulse.timestamp;
        }
    }
    
    action def 'Absorb Photon' {
        in p : Photon;
    }
    action def 'Generate Pulse' {
        out pulse : DetectionPulse;
    }
    action def 'Amplify Pulse' {
        in pulse : DetectionPulse;
        out amplified : DetectionPulse;
    }
    action def 'Discriminate Pulse' {
        in amplified : DetectionPulse;
        out digital : DigitalPulse;
    }
    action def 'Record Timing' {
        in digital : DigitalPulse;
        out log : DigitalPulse;
    }
    action def DetectionAction {
        in photon : Photon;
        out log : DigitalPulse;
    }
    
    part def SNSPD {
        part cryo : CryogenicRefrigerator;
        part biasSource : BiasCurrentSource;
        part nanowire : SuperconductingNanowire;
        part amplifier : ReadoutAmplifier;
        part discriminator : PulseDiscriminator;
        part timing : TimingModule;
        
        in item photonInput : Photon;
        out item detectionLog : DigitalPulse;
        
        flow cryo.coolantFlow to nanowire.coolantIn;
        flow biasSource.biasCurrentOut to nanowire.biasCurrentIn;
        flow photonInput to nanowire.photonIn;
        flow nanowire.pulseOut to amplifier.pulseIn;
        flow amplifier.amplifiedOut to discriminator.signalIn;
        flow discriminator.digitalOut to timing.digitalIn;
        flow discriminator.digitalOut to detectionLog;
        
        action detectPhoton :> DetectionAction {
            in photon : Photon = photonInput;
            out log : DigitalPulse = detectionLog;
            
            action absorb : 'Absorb Photon' {
                in p : Photon = photon;
            }
            first absorb then generate;
            action generate : 'Generate Pulse' {
                out pulse : DetectionPulse;
            }
            first generate then amplify;
            action amplify : 'Amplify Pulse' {
                in pulse : DetectionPulse;
                out amplified : DetectionPulse;
            }
            first amplify then discriminate;
            action discriminate : 'Discriminate Pulse' {
                in amplified : DetectionPulse;
                out digital : DigitalPulse;
            }
            first discriminate then record;
            action record : 'Record Timing' {
                in digital : DigitalPulse;
                out log : DigitalPulse;
            }
        }
        
        satisfy CryogenicOperation by cryo;
        satisfy BiasBelowThreshold by biasSource;
        satisfy AmplifierGain by amplifier;
        satisfy TimingPrecision by timing;
        satisfy DetectionEfficiency by discriminator;
    }
    
    requirement def CryogenicOperation {
        subject fridge : CryogenicRefrigerator;
        require {
            fridge.targetTemp <= 2.5 [K];
        }
    }
    
    requirement def BiasBelowThreshold {
        subject src : BiasCurrentSource;
        require {
            src.biasLevel < src.thresholdCurrent;
        }
    }
    
    requirement def AmplifierGain {
        subject amp : ReadoutAmplifier;
        require {
            amp.gain >= 1000.0;
        }
    }
    
    requirement def TimingPrecision {
        subject tm : TimingModule;
        require {
            tm.timingResolution <= 0.0000000001 [s];
        }
    }
    
    requirement def DetectionEfficiency {
        subject disc : PulseDiscriminator;
        require {
            disc.threshold > 0 [V];
        }
    }
}
