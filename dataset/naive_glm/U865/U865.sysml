package ScintillatorDetectionSystem {

    import ScalarValues::*;
    import ISQ::*;

    value type EnergyValue :> Real {
        unit 'eV';
    }

    value type LightIntensityValue :> Real {
        unit 'ph';
    }

    value type VoltageAmplitudeValue :> Real {
        unit 'V';
    }

    value type TimeStampValue :> Real {
        unit 's';
    }

    value type DurationValue :> Real {
        unit 's';
    }

    value type PhotonCountValue :> Integer;
    value type ElectronCountValue :> Integer;

    item def RadiationParticle {
        attribute energy : EnergyValue;
        attribute particleType : String;
    }

    item def LightFlash {
        attribute intensity : LightIntensityValue;
        attribute photonCount : PhotonCountValue;
        attribute duration : DurationValue;
    }

    item def ElectricalPulse {
        attribute amplitude : VoltageAmplitudeValue;
        attribute duration : DurationValue;
        attribute timestamp : TimeStampValue;
    }

    item def DetectionEvent {
        attribute energy : EnergyValue;
        attribute timestamp : TimeStampValue;
        attribute particleType : String;
    }

    port def RadiationInputPort {
        in item particle : RadiationParticle;
    }

    port def LightTransferPort {
        out item flash : LightFlash;
    }

    port def LightReceivePort {
        in item flash : LightFlash;
    }

    port def PulseTransferPort {
        out item pulse : ElectricalPulse;
    }

    port def PulseReceivePort {
        in item pulse : ElectricalPulse;
    }

    port def DataOutputPort {
        out item event : DetectionEvent;
    }

    part def ScintillatorCrystal {
        attribute material : String = "Sodium Iodide (NaI)";
        attribute lightYield : Real = 38000.0;
        attribute decayTime : DurationValue = 230e-9 [s];

        port radiationInput : RadiationInputPort;
        port lightOutput : LightTransferPort;

        attribute absorbedEnergy : EnergyValue;
        attribute emittedPhotons : PhotonCountValue;

        state machine crystalBehavior {
            entry;
            then Ready;

            state Ready {
                doc "Crystal is idle, awaiting an incoming radiation particle.";
            }

            transition readyToActive
                from Ready
                when radiationInput.particle.energy > 0 [eV]
                to Active;

            state Active {
                doc "Crystal is scintillating in response to absorbed radiation.";

                entry action {
                    absorbedEnergy := radiationInput.particle.energy;
                    emittedPhotons := PhotonCountValue(absorbedEnergy * lightYield);
                    lightOutput.flash.intensity := LightIntensityValue(emittedPhotons);
                    lightOutput.flash.photonCount := emittedPhotons;
                    lightOutput.flash.duration := decayTime;
                }

                do action {
                    send lightOutput.flash;
                }

                then DecayComplete;
            }

            state DecayComplete {
                doc "Light emission has decayed below detectable threshold.";
            }

            transition decayToReady
                from DecayComplete
                to Ready;
        }
    }

    part def PhotomultiplierTube {
        attribute quantumEfficiency : Real = 0.25;
        attribute dynodeGain : Real = 1.0e6;
        attribute stageCount : Integer = 10;
        attribute responseTime : DurationValue = 2e-9 [s];

        port lightInput : LightReceivePort;
        port pulseOutput : PulseTransferPort;

        attribute collectedPhotons : PhotonCountValue;
        attribute primaryElectrons : ElectronCountValue;
        attribute outputAmplitude : VoltageAmplitudeValue;

        state machine pmtBehavior {
            entry;
            then Ready;

            state Ready {
                doc "PMT is biased and ready to receive a light flash.";
            }

            transition readyToActive
                from Ready
                when lightInput.flash.photonCount > 0
                to Active;

            state Active {
                doc "PMT is converting and multiplying the photoelectric signal.";

                entry action {
                    collectedPhotons := lightInput.flash.photonCount;
                    primaryElectrons := ElectronCountValue(collectedPhotons * quantumEfficiency);
                    outputAmplitude := VoltageAmplitudeValue(Real(primaryElectrons) * dynodeGain * 1.0e-6);
                    pulseOutput.pulse.amplitude := outputAmplitude;
                    pulseOutput.pulse.duration := responseTime;
                    pulseOutput.pulse.timestamp := 0.0 [s];
                }

                do action {
                    send pulseOutput.pulse;
                }

                then PulseComplete;
            }

            state PulseComplete {
                doc "Output pulse has been delivered to the analyzer.";
            }

            transition completeToReady
                from PulseComplete
                to Ready;
        }
    }

    part def SignalAnalyzer {
        attribute calibrationFactor : Real = 1.0;
        attribute timeWindow : DurationValue = 10e-6 [s];
        attribute baselineNoise : VoltageAmplitudeValue = 1e-3 [V];

        port pulseInput : PulseReceivePort;
        port dataOutput : DataOutputPort;

        attribute measuredAmplitude : VoltageAmplitudeValue;
        attribute measuredDuration : DurationValue;
        attribute computedEnergy : EnergyValue;
        attribute eventTimestamp : TimeStampValue;

        state machine analyzerBehavior {
            entry;
            then Ready;

            state Ready {
                doc "Analyzer is armed and waiting for an incoming pulse.";
            }

            transition readyToActive
                from Ready
                when pulseInput.pulse.amplitude > baselineNoise
                to Active;

            state Active {
                doc "Analyzer is processing the incoming pulse within the time window.";

                entry action {
                    measuredAmplitude := pulseInput.pulse.amplitude;
                    measuredDuration := pulseInput.pulse.duration;
                    computedEnergy := EnergyValue(measuredAmplitude * calibrationFactor);
                    eventTimestamp := pulseInput.pulse.timestamp;
                    dataOutput.event.energy := computedEnergy;
                    dataOutput.event.timestamp := eventTimestamp;
                    dataOutput.event.particleType := "gamma";
                }

                do action {
                    send dataOutput.event;
                }

                then AnalysisComplete;
            }

            state AnalysisComplete {
                doc "Detection event has been packaged and emitted.";
            }

            transition completeToReady
                from AnalysisComplete
                to Ready;
        }
    }

    part def ScintillatorDetectionSystem {
        doc "A scientific instrument for detecting ionizing radiation particles and measuring their energy.";

        port radiationInput : RadiationInputPort;
        port dataOutput : DataOutputPort;

        part scintillatorCrystal : ScintillatorCrystal {
            port redefines radiationInput;
        }

        part photomultiplierTube : PhotomultiplierTube;

        part signalAnalyzer : SignalAnalyzer {
            port redefines dataOutput;
        }

        connection lightPath connect scintillatorCrystal.lightOutput to photomultiplierTube.lightInput;
        connection pulsePath connect photomultiplierTube.pulseOutput to signalAnalyzer.pulseInput;

        state machine systemBehavior {
            entry;
            then Ready;

            state Ready {
                doc "System is ready and awaiting a radiation event.";
            }

            transition readyToProcessing
                from Ready
                when radiationInput.particle.energy > 0 [eV]
                to Processing;

            state Processing {
                doc "System is processing a radiation event through scintillation, multiplication, and analysis.";
            }

            transition processingToReady
                from Processing
                when dataOutput.event.energy > 0 [eV]
                to Ready;
        }
    }

    requirement def DetectionRequirement {
        doc "The system shall detect individual particles of ionizing radiation.";
        subject detector : ScintillatorDetectionSystem;
        require detector.radiationInput.particle.energy > 0 [eV];
    }

    requirement def EnergyMeasurementRequirement {
        doc "The system shall measure the energy of each detected radiation particle.";
        subject detector : ScintillatorDetectionSystem;
        attribute requiredAccuracy : Real = 0.05;
        require detector.dataOutput.event.energy > 0 [eV];
    }

    requirement def CyclicOperationRequirement {
        doc "The system shall return to a ready state after processing each radiation event.";
        subject detector : ScintillatorDetectionSystem;
        require detector.systemBehavior::Ready.occurrence.isNotEmpty;
    }

    requirement def TimestampRequirement {
        doc "Each detection event shall include an energy value and a timestamp.";
        subject detector : ScintillatorDetectionSystem;
        require detector.dataOutput.event.timestamp >= 0 [s];
    }

    requirement def LinearityRequirement {
        doc "The output pulse amplitude shall be proportional to the intensity of the initial light flash.";
        subject detector : ScintillatorDetectionSystem;
        require detector.photomultiplierTube.outputAmplitude > 0 [V]
            implies detector.scintillatorCrystal.emittedPhotons > 0;
    }

}
