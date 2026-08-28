package KID_System {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    value def Temperature :> Real { unit "K"; }
    value def Frequency :> Real { unit "GHz"; }
    value def Energy :> Real { unit "eV"; }
    value def Time :> Real { unit "ns"; }
    value def Phase :> Real { unit "rad"; }
    value def Amplitude :> Real { unit "V"; }
    value def Inductance :> Real { unit "nH"; }
    
    // Item Types
    item def Photon {
        attribute energy : Energy;
        attribute arrivalTime : Time;
    }
    
    item def MicrowaveSignal {
        attribute frequency : Frequency;
        attribute phase : Phase;
        attribute amplitude : Amplitude;
    }
    
    item def DetectionEvent {
        attribute photonEnergy : Energy;
        attribute detectionTime : Time;
        attribute phaseShift : Phase;
        attribute amplitudeShift : Amplitude;
    }
    
    // Ports
    port def OpticalPort {
        out item photons : Photon;
    }
    
    port def MicrowavePort {
        out item signal : MicrowaveSignal;
    }
    
    port def ThermalPort {
        out attribute temperature : Temperature;
    }
    
    port def DataPort {
        out item event : DetectionEvent;
    }
    
    // Requirements
    requirement def CryogenicCoolingRequirement {
        doc /* The cryogenic system must cool the resonator to 0.1 K */
        subject cryo : CryogenicSystem;
        objective {
            cryo.targetTemperature == 0.1 [K]
        }
    }
    
    requirement def PhotonDetectionRequirement {
        doc /* The resonator must detect individual photons and shift frequency */
        subject resonator : SuperconductingResonator;
        objective {
            resonator.absorbedPhoton != null
        }
    }
    
    requirement def SignalReadoutRequirement {
        doc /* The readout must capture phase and amplitude shifts */
        subject readout : MicrowaveReadoutElectronics;
        objective {
            readout.capturedSignal.phase != readout.probeSignal.phase
        }
    }
    
    requirement def EnergyCalculationRequirement {
        doc /* The processor must calculate photon energy from signal shifts */
        subject processor : SignalProcessingUnit;
        objective {
            processor.outputEvent.photonEnergy > 0 [eV]
        }
    }
    
    // Parts
    part def CryogenicSystem {
        attribute targetTemperature : Temperature = 0.1 [K];
        port thermalOut : ThermalPort;
        
        state def CoolingStates {
            entry; 
            state Off;
            state Cooling;
            state Cooled;
            transition off_to_cooling first Off to Cooling;
            transition cooling_to_cooled Cooling to Cooled when thermalOut.temperature <= targetTemperature;
        }
    }
    
    part def SuperconductingResonator {
        attribute material : String = "Titanium Nitride";
        attribute baseFrequency : Frequency = 4.0 [GHz];
        attribute kineticInductance : Inductance = 2.0 [nH];
        attribute currentTemperature : Temperature;
        
        port opticalIn : OpticalPort;
        port microwaveIn : MicrowavePort;
        port microwaveOut : MicrowavePort;
        port thermalIn : ThermalPort;
        
        attribute absorbedPhoton : Photon;
        attribute currentSignal : MicrowaveSignal;
        
        state def ResonatorStates {
            entry;
            state Idle {
                entry { currentSignal.frequency = baseFrequency; }
            }
            state PhotonAbsorbed {
                entry { 
                    absorbedPhoton = opticalIn.photons;
                    kineticInductance = kineticInductance + 0.1 [nH];
                }
            }
            state FrequencyShifted {
                entry {
                    currentSignal.frequency = baseFrequency - 0.001 [GHz];
                    currentSignal.phase = currentSignal.phase + 0.1 [rad];
                    currentSignal.amplitude = currentSignal.amplitude - 0.01 [V];
                }
            }
            state Recovering {
                entry {
                    kineticInductance = kineticInductance - 0.1 [nH];
                    currentSignal.frequency = baseFrequency;
                }
            }
            
            transition idle_to_absorbed first Idle to PhotonAbsorbed when opticalIn.photons != null;
            transition absorbed_to_shifted PhotonAbsorbed to FrequencyShifted;
            transition shifted_to_recovering FrequencyShifted to Recovering;
            transition recovering_to_idle Recovering to Idle;
        }
    }
    
    part def MicrowaveReadoutElectronics {
        attribute probeSignal : MicrowaveSignal;
        attribute capturedSignal : MicrowaveSignal;
        
        port microwaveOut : MicrowavePort;
        port microwaveIn : MicrowavePort;
        port dataOut : DataPort;
        
        state def ReadoutStates {
            entry;
            state Probing {
                entry { microwaveOut.signal = probeSignal; }
            }
            state SignalAltered {
                entry { capturedSignal = microwaveIn.signal; }
            }
            state Capturing {
                entry { 
                    dataOut.event.phaseShift = capturedSignal.phase - probeSignal.phase;
                    dataOut.event.amplitudeShift = capturedSignal.amplitude - probeSignal.amplitude;
                    dataOut.event.detectionTime = 0.0 [ns];
                }
            }
            
            transition probing_to_altered Probing to SignalAltered when microwaveIn.signal.phase != probeSignal.phase;
            transition altered_to_capturing SignalAltered to Capturing;
            transition capturing_to_probing Capturing to Probing;
        }
    }
    
    part def SignalProcessingUnit {
        attribute outputEvent : DetectionEvent;
        port dataIn : DataPort;
        port dataOut : DataPort;
        
        state def ProcessingStates {
            entry;
            state Waiting;
            state Processing {
                entry {
                    outputEvent.photonEnergy = dataIn.event.phaseShift * 10.0;
                    outputEvent.detectionTime = dataIn.event.detectionTime;
                    outputEvent.phaseShift = dataIn.event.phaseShift;
                    outputEvent.amplitudeShift = dataIn.event.amplitudeShift;
                }
            }
            state Outputting {
                entry { dataOut.event = outputEvent; }
            }
            
            transition waiting_to_processing Waiting to Processing when dataIn.event != null;
            transition processing_to_outputting Processing to Outputting;
            transition outputting_to_waiting Outputting to Waiting;
        }
    }
    
    part def KIDSystem {
        part cryo : CryogenicSystem {
            satisfies CryogenicCoolingRequirement;
        }
        part resonator : SuperconductingResonator {
            satisfies PhotonDetectionRequirement;
        }
        part readout : MicrowaveReadoutElectronics {
            satisfies SignalReadoutRequirement;
        }
        part processor : SignalProcessingUnit {
            satisfies EnergyCalculationRequirement;
        }
        
        connection cryo.thermalOut to resonator.thermalIn;
        connection readout.microwaveOut to resonator.microwaveIn;
        connection resonator.microwaveOut to readout.microwaveIn;
        connection readout.dataOut to processor.dataIn;
    }
}
