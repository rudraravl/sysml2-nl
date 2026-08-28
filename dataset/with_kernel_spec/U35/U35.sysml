package AmmoniaphoneModel {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        attribute def StartCommand;
        attribute def StopCommand;
        
        item def AmmoniaGas;
        item def ElectricalSignal;
        item def SoundWave;
        
        part def AmmoniaReservoir {
            out port gasOut : AmmoniaGas;
        }
        
        part def ControlUnit {
            in port pitchIn : FrequencyValue;
            in port volumeIn : Real;
            out port signalOut : ElectricalSignal;
        }
        
        part def FlowRegulator {
            in port signalIn : ElectricalSignal;
            in port gasIn : AmmoniaGas;
            out port gasOut : AmmoniaGas;
        }
        
        part def HeatingChamber {
            in port gasIn : AmmoniaGas;
            out port gasOut : AmmoniaGas;
            attribute temperature : TemperatureValue;
            attribute targetTemperature : TemperatureValue = 350 [K];
        }
        
        part def ResonanceCavity {
            in port gasIn : AmmoniaGas;
            out port soundOut : SoundWave;
        }
        
        part def AmplificationBell {
            in port soundIn : SoundWave;
            out port soundOut : SoundWave;
        }
        
        action def PlayTone {
            in pitch : FrequencyValue;
            in volume : Real;
            in reservoirGas : AmmoniaGas;
            out sound : SoundWave;
        }
        
        requirement def SoundProductionRequirement {
            /* The Ammoniaphone shall produce audible tones with specified pitch and volume. */
        }
        
        part def AmmoniaphoneSystem {
            part ammoniaReservoir : AmmoniaReservoir;
            part controlUnit : ControlUnit;
            part flowRegulator : FlowRegulator;
            part heatingChamber : HeatingChamber;
            part resonanceCavity : ResonanceCavity;
            part amplificationBell : AmplificationBell;
            
            connect controlUnit.signalOut to flowRegulator.signalIn;
            connect ammoniaReservoir.gasOut to flowRegulator.gasIn;
            connect flowRegulator.gasOut to heatingChamber.gasIn;
            connect heatingChamber.gasOut to resonanceCavity.gasIn;
            connect resonanceCavity.soundOut to amplificationBell.soundIn;
            
            in port pitchIn : FrequencyValue;
            in port volumeIn : Real;
            in port startIn : StartCommand;
            in port stopIn : StopCommand;
            out port soundOut : SoundWave;
            
            connect pitchIn to controlUnit.pitchIn;
            connect volumeIn to controlUnit.volumeIn;
            connect amplificationBell.soundOut to soundOut;
            
            exhibit state operationalStates {
                entry; then idle;
                state idle;
                accept startIn then warming;
                state warming;
                accept when heatingChamber.temperature >= heatingChamber.targetTemperature then playing;
                state playing {
                    do action playTone : PlayTone;
                }
                accept stopIn then cooling;
                state cooling;
                accept when heatingChamber.temperature <= 293 [K] then idle;
            }
            
            satisfy SoundProductionRequirement;
        }
    }
    
    package Usages {
        private import Definitions::*;
        part ammoniaphone : AmmoniaphoneSystem;
    }
}
