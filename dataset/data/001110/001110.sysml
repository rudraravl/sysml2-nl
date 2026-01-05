package KineticInductanceDetectorSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def PhotonEnergy :> ISQ::EnergyValue;
    attribute def CooperPairDensity :> ScalarValues::Real;
    attribute def KineticInductance :> ISQ::InductanceValue;
    attribute def ResonantFrequency :> ISQ::FrequencyValue;
    attribute def QualityFactor :> ScalarValues::Real;
    attribute def PhaseShift :> ScalarValues::Real;
    attribute def AmplitudeChange :> ScalarValues::Real;
    attribute def QuasiparticleCount :> ScalarValues::Real;
    
    item def Photon {
        attribute energy : PhotonEnergy;
        attribute wavelength : ISQ::LengthValue;
        attribute arrivalTime : ISQ::TimeValue;
    }
    
    item def MicrowaveProbe {
        attribute frequency : ResonantFrequency;
        attribute power : ISQ::PowerValue;
    }
    
    item def TransmissionSignal {
        attribute phaseShift : PhaseShift;
        attribute amplitudeChange : AmplitudeChange;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def DetectionEvent {
        attribute photonEnergy : PhotonEnergy;
        attribute detectionTime : ISQ::TimeValue;
        attribute confidence : ScalarValues::Real;
    }
    
    port def PhotonInputPort {
        in photon : Photon;
    }
    
    port def MicrowavePort {
        inout probe : MicrowaveProbe;
        out response : TransmissionSignal;
    }
    
    port def ThermalPort {
        in temperature : ISQ::ThermodynamicTemperatureValue;
        out heatDissipation : ISQ::PowerValue;
    }
    
    port def DataOutputPort {
        out detection : DetectionEvent;
    }
    
    part def SuperconductingResonator {
        attribute material : ScalarValues::String;
        attribute criticalTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute baselineInductance : KineticInductance;
        attribute baselineFrequency : ResonantFrequency;
        attribute qualityFactor : QualityFactor;
        attribute cooperPairDensity : CooperPairDensity;
        
        port photonIn : PhotonInputPort;
        port microwaveInterface : MicrowavePort;
        port thermal : ThermalPort;
    }
    
    part def CryogenicSystem {
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute coolingPower : ISQ::PowerValue;
        attribute temperatureStability : ISQ::ThermodynamicTemperatureValue;
        
        port thermalInterface : ThermalPort;
    }
    
    part def MicrowaveReadoutElectronics {
        attribute probeFrequency : ResonantFrequency;
        attribute probePower : ISQ::PowerValue;
        attribute amplifierGain : ScalarValues::Real;
        attribute noiseTemperature : ISQ::ThermodynamicTemperatureValue;
        
        port resonatorConnection : MicrowavePort;
        port signalOut {
            out transmissionData : TransmissionSignal;
        }
    }
    
    part def SignalProcessingUnit {
        attribute samplingRate : ISQ::FrequencyValue;
        attribute energyResolution : PhotonEnergy;
        attribute processingDelay : ISQ::TimeValue;
        
        port signalIn {
            in transmissionData : TransmissionSignal;
        }
        port dataOut : DataOutputPort;
    }
    
    action def AbsorbPhoton {
        in photon : Photon;
        in initialCooperPairs : CooperPairDensity;
        in temperature : ISQ::ThermodynamicTemperatureValue;
        out brokenPairs : CooperPairDensity;
        out quasiparticles : QuasiparticleCount;
        out heatGenerated : ISQ::PowerValue;
    }
    
    action def ModifyKineticInductance {
        in brokenPairs : CooperPairDensity;
        in baselineInductance : KineticInductance;
        in temperature : ISQ::ThermodynamicTemperatureValue;
        out modifiedInductance : KineticInductance;
        out inductanceChange : KineticInductance;
    }
    
    action def ShiftResonantFrequency {
        in modifiedInductance : KineticInductance;
        in baselineFrequency : ResonantFrequency;
        in qualityFactor : QualityFactor;
        out shiftedFrequency : ResonantFrequency;
        out frequencyShift : ResonantFrequency;
    }
    
    action def ProbeResonator {
        in probeSignal : MicrowaveProbe;
        in resonatorFrequency : ResonantFrequency;
        in qualityFactor : QualityFactor;
        out transmissionPhase : PhaseShift;
        out transmissionAmplitude : AmplitudeChange;
    }
    
    action def ReconstructPhotonEnergy {
        in phaseShift : PhaseShift;
        in amplitudeChange : AmplitudeChange;
        in calibrationFactor : ScalarValues::Real;
        in baselineFrequency : ResonantFrequency;
        out photonEnergy : PhotonEnergy;
        out confidence : ScalarValues::Real;
    }
    
    action def DetectSinglePhoton {
        in incidentPhoton : Photon;
        in operatingTemp : ISQ::ThermodynamicTemperatureValue;
        in probeSignal : MicrowaveProbe;
        in baselineInductance : KineticInductance;
        in baselineFrequency : ResonantFrequency;
        in qualityFactor : QualityFactor;
        out detectedEvent : DetectionEvent;
        
        first start;
        then action absorb : AbsorbPhoton {
            in photon = incidentPhoton;
            in initialCooperPairs;
            in temperature = operatingTemp;
            out brokenPairs;
            out quasiparticles;
            out heatGenerated;
        }
        then action modifyL : ModifyKineticInductance {
            in brokenPairs = absorb.brokenPairs;
            in baselineInductance = baselineInductance;
            in temperature = operatingTemp;
            out modifiedInductance;
            out inductanceChange;
        }
        then action shiftF : ShiftResonantFrequency {
            in modifiedInductance = modifyL.modifiedInductance;
            in baselineFrequency = baselineFrequency;
            in qualityFactor = qualityFactor;
            out shiftedFrequency;
            out frequencyShift;
        }
        then action probe : ProbeResonator {
            in probeSignal = probeSignal;
            in resonatorFrequency = shiftF.shiftedFrequency;
            in qualityFactor = qualityFactor;
            out transmissionPhase;
            out transmissionAmplitude;
        }
        then action reconstruct : ReconstructPhotonEnergy {
            in phaseShift = probe.transmissionPhase;
            in amplitudeChange = probe.transmissionAmplitude;
            in calibrationFactor;
            in baselineFrequency = baselineFrequency;
            out photonEnergy;
            out confidence;
        }
        then done;
    }
    
    part def KIDSystem {
        attribute systemOperatingTemp : ISQ::ThermodynamicTemperatureValue;
        attribute systemQuasiparticles : QuasiparticleCount;
    }
    
    part kineticInductanceDetector : KIDSystem {
        attribute systemOperatingTemp = 0.1 [K];
        attribute systemQuasiparticles = 0.0;
        
        part resonator : SuperconductingResonator {
            attribute material = "Titanium Nitride";
            attribute criticalTemperature = 5.0 [K];
            attribute operatingTemperature = 0.1 [K];
            attribute baselineInductance = 10.0e-9 [H];
            attribute baselineFrequency = 5.0e9 [Hz];
            attribute qualityFactor = 100000.0;
            attribute cooperPairDensity = 1.0e28;
        }
        
        part cryostat : CryogenicSystem {
            attribute targetTemperature = 0.1 [K];
            attribute coolingPower = 1.0e-3 [W];
            attribute temperatureStability = 0.001 [K];
        }
        
        part readoutElectronics : MicrowaveReadoutElectronics {
            attribute probeFrequency = 5.0e9 [Hz];
            attribute probePower = 1.0e-15 [W];
            attribute amplifierGain = 40.0;
            attribute noiseTemperature = 5.0 [K];
        }
        
        part processor : SignalProcessingUnit {
            attribute samplingRate = 1.0e6 [Hz];
            attribute energyResolution = 0.1 [eV];
            attribute processingDelay = 1.0e-6 [s];
        }
        
        connect cryostat.thermalInterface.temperature to resonator.thermal.temperature;
        connect resonator.thermal.heatDissipation to cryostat.thermalInterface.heatDissipation;
        connect resonator.microwaveInterface to readoutElectronics.resonatorConnection;
        connect readoutElectronics.signalOut.transmissionData to processor.signalIn.transmissionData;
        
        perform action detectPhotons[*] ordered references DetectSinglePhoton;
    }
    
    requirement def SensitivityRequirement {
        doc /* The detector shall achieve single-photon energy resolution better than 0.2 eV */
        require constraint {
            energyResolution <= 0.2 [eV]
        }
        attribute energyResolution : PhotonEnergy;
    }
    
    requirement def OperatingTemperatureRequirement {
        doc /* The resonator shall be maintained at cryogenic temperature below 0.15 K */
        require constraint {
            operatingTemperature <= 0.15 [K]
        }
        attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    requirement def QuantumEfficiencyRequirement {
        doc /* The detector shall maintain quantum efficiency above 80% for photons in the target energy range */
        require constraint {
            quantumEfficiency >= 0.8
        }
        attribute quantumEfficiency : ScalarValues::Real;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The detector shall respond to photon absorption within 1 microsecond */
        require constraint {
            responseTime <= 1.0e-6 [s]
        }
        attribute responseTime : ISQ::TimeValue;
    }
    
    requirement <'KID-REQ-001'> primaryFunctionRequirement {
        doc /* The Kinetic Inductance Detector system shall detect individual photons by measuring the change in superconducting resonator frequency caused by photon-induced Cooper pair breaking, enabling high-sensitivity photon counting and energy-resolved detection */
        
        subject kineticInductanceDetector;
        
        assume constraint {
            doc /* Incident photons have energy sufficient to break Cooper pairs */
            incidentPhotonEnergy >= 2.0 * superconductingGap
        }
        
        require sensitivityReq : SensitivityRequirement;
        require tempReq : OperatingTemperatureRequirement;
        require qeReq : QuantumEfficiencyRequirement;
        require responseReq : ResponseTimeRequirement;
        
        attribute incidentPhotonEnergy : PhotonEnergy;
        attribute superconductingGap : PhotonEnergy;
    }
    
    requirement <'KID-REQ-002'> detectionMechanismRequirement {
        doc /* The system shall convert photon absorption events into measurable microwave transmission changes through kinetic inductance modulation */
        
        subject kineticInductanceDetector.resonator;
        
        require constraint {
            doc /* Frequency shift must be detectable above noise floor */
            frequencyShift / baselineFrequency >= 1.0e-6
        }
        
        attribute frequencyShift : ResonantFrequency;
        attribute baselineFrequency : ResonantFrequency;
    }
}
