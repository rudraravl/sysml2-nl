package PhotomultiplierSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def QuantumEfficiency;
    attribute def GainValue;
    attribute def PhotonFlux;
    
    item def Photon {
        attribute wavelength : LengthValue;
        attribute energy : EnergyValue;
        attribute arrivalTime : TimeValue;
    }
    
    item def Photoelectron {
        attribute charge : ElectricChargeValue;
        attribute kineticEnergy : EnergyValue;
    }
    
    item def ElectronBurst {
        attribute electronCount : Real;
        attribute totalCharge : ElectricChargeValue;
    }
    
    item def OutputPulse {
        attribute amplitude : ElectricCurrentValue;
        attribute width : TimeValue;
        attribute riseTime : TimeValue;
    }
    
    port def OpticalPort {
        in item photons : Photon[*];
    }
    
    port def HighVoltagePort {
        in attribute voltage : ElectricPotentialValue;
    }
    
    port def SignalPort {
        out item pulses : OutputPulse[*];
    }
    
    part def Photocathode {
        attribute quantumEfficiency : QuantumEfficiency;
        attribute workFunction : EnergyValue;
        attribute activeMaterial : String;
        
        port opticalInput : OpticalPort;
        
        action emitPhotoelectron {
            in photon : Photon;
            out photoelectron : Photoelectron;
            
            doc /* Convert incident photon to photoelectron via photoelectric effect */
        }
    }
    
    part def Dynode {
        attribute secondaryEmissionCoefficient : Real;
        attribute surfaceCoating : String;
        attribute appliedVoltage : ElectricPotentialValue;
        
        action multiplyElectrons {
            in incident : Photoelectron;
            out secondary : Photoelectron[*];
            
            doc /* Generate secondary electrons through impact ionization */
        }
    }
    
    part def DynodeStage {
        attribute stageNumber : Integer;
        attribute stageGain : Real;
        attribute interDynodeVoltage : ElectricPotentialValue;
        
        part dynode : Dynode;
        
        action amplifyElectronBurst {
            in inputBurst : ElectronBurst;
            out outputBurst : ElectronBurst;
        }
    }
    
    part def MultiplicationChain {
        attribute numberOfStages : Integer;
        attribute totalGain : GainValue;
        
        part stage1 : DynodeStage { attribute stageNumber = 1; }
        part stage2 : DynodeStage { attribute stageNumber = 2; }
        part stage3 : DynodeStage { attribute stageNumber = 3; }
        part stage4 : DynodeStage { attribute stageNumber = 4; }
        part stage5 : DynodeStage { attribute stageNumber = 5; }
        part stage6 : DynodeStage { attribute stageNumber = 6; }
        part stage7 : DynodeStage { attribute stageNumber = 7; }
        part stage8 : DynodeStage { attribute stageNumber = 8; }
        
        connect stage1 to stage2;
        connect stage2 to stage3;
        connect stage3 to stage4;
        connect stage4 to stage5;
        connect stage5 to stage6;
        connect stage6 to stage7;
        connect stage7 to stage8;
        
        action cascadeAmplification {
            in initialElectron : Photoelectron;
            out amplifiedBurst : ElectronBurst;
            
            first start;
            then action s1 : DynodeStage::amplifyElectronBurst;
            flow s1.outputBurst to s2.inputBurst;
            then action s2 : DynodeStage::amplifyElectronBurst;
            flow s2.outputBurst to s3.inputBurst;
            then action s3 : DynodeStage::amplifyElectronBurst;
            flow s3.outputBurst to s4.inputBurst;
            then action s4 : DynodeStage::amplifyElectronBurst;
            flow s4.outputBurst to s5.inputBurst;
            then action s5 : DynodeStage::amplifyElectronBurst;
            flow s5.outputBurst to s6.inputBurst;
            then action s6 : DynodeStage::amplifyElectronBurst;
            flow s6.outputBurst to s7.inputBurst;
            then action s7 : DynodeStage::amplifyElectronBurst;
            flow s7.outputBurst to s8.inputBurst;
            then action s8 : DynodeStage::amplifyElectronBurst;
            then assign amplifiedBurst := s8.outputBurst;
            then done;
        }
    }
    
    part def Anode {
        attribute collectionEfficiency : Real;
        attribute capacitance : Real;
        
        port signalOutput : SignalPort;
        
        action collectAndConvert {
            in electronBurst : ElectronBurst;
            out outputPulse : OutputPulse;
            
            doc /* Collect electron burst and convert to measurable current pulse */
        }
    }
    
    part def VacuumEnvelope {
        attribute pressure : PressureValue;
        attribute windowMaterial : String;
        attribute envelopeType : String;
        
        doc /* Maintains high vacuum for unimpeded electron travel */
    }
    
    part def VoltageDividerNetwork {
        attribute totalResistance : Real;
        attribute numberOfTaps : Integer;
        
        action distributeVoltage {
            in supplyVoltage : ElectricPotentialValue;
            out dynodeVoltages : ElectricPotentialValue[8];
            
            doc /* Create voltage gradient across dynode chain */
        }
    }
    
    part def HighVoltageSupply {
        attribute nominalVoltage : ElectricPotentialValue;
        attribute stability : Real;
        attribute ripple : ElectricPotentialValue;
        
        port hvOutput : HighVoltagePort;
        
        action regulateVoltage {
            in setpoint : ElectricPotentialValue;
            out regulatedOutput : ElectricPotentialValue;
        }
    }
    
    part def PhotomultiplierTube {
        attribute overallGain : GainValue;
        attribute darkCurrent : ElectricCurrentValue;
        attribute transitTime : TimeValue;
        attribute spectralResponse : LengthValue[2];
        attribute activeArea : AreaValue;
        
        port opticalInput : OpticalPort;
        port hvInput : HighVoltagePort;
        port signalOutput : SignalPort;
        
        part photocathode : Photocathode {
            attribute quantumEfficiency = 0.25;
            attribute activeMaterial = "Bialkali";
        }
        
        part multiplicationChain : MultiplicationChain {
            attribute numberOfStages = 8;
            attribute totalGain = 1.0e6;
        }
        
        part anode : Anode {
            attribute collectionEfficiency = 0.95;
        }
        
        part envelope : VacuumEnvelope {
            attribute pressure = 1.0e-6 [SI::Pa];
            attribute windowMaterial = "Borosilicate";
        }
        
        part voltageDivider : VoltageDividerNetwork {
            attribute numberOfTaps = 9;
        }
        
        connect photocathode to multiplicationChain;
        connect multiplicationChain to anode;
        connect hvInput to voltageDivider;
        
        perform action detectPhoton {
            in incidentPhoton : Photon;
            out detectedPulse : OutputPulse;
            
            first start;
            then action photoconvert : Photocathode::emitPhotoelectron {
                in photon = incidentPhoton;
                out photoelectron;
            }
            flow photoconvert.photoelectron to amplify.initialElectron;
            
            then action amplify : MultiplicationChain::cascadeAmplification {
                in initialElectron;
                out amplifiedBurst;
            }
            flow amplify.amplifiedBurst to collect.electronBurst;
            
            then action collect : Anode::collectAndConvert {
                in electronBurst;
                out outputPulse;
            }
            
            then assign detectedPulse := collect.outputPulse;
            then done;
        }
    }
    
    part def PreAmplifier {
        attribute inputImpedance : Real;
        attribute bandwidth : FrequencyValue;
        attribute noiseLevel : ElectricCurrentValue;
        
        action amplifySignal {
            in inputPulse : OutputPulse;
            out amplifiedSignal : Real;
        }
    }
    
    part def Discriminator {
        attribute threshold : ElectricPotentialValue;
        
        action filterNoise {
            in signal : Real;
            out validPulse : Boolean;
        }
    }
    
    part photomultiplierSystem : PhotomultiplierTube {
        attribute overallGain = 1.0e6;
        attribute darkCurrent = 5.0e-9 [SI::A];
        attribute transitTime = 22.0e-9 [SI::s];
        attribute activeArea = 1.0e-4 [SI::'m²'];
        
        part hvSupply : HighVoltageSupply {
            attribute nominalVoltage = 1200.0 [SI::V];
            attribute stability = 0.005;
            attribute ripple = 0.1 [SI::V];
        }
        
        part preamp : PreAmplifier {
            attribute inputImpedance = 50.0;
            attribute bandwidth = 100.0e6 [SI::Hz];
            attribute noiseLevel = 1.0e-12 [SI::A];
        }
        
        part discriminator : Discriminator {
            attribute threshold = 0.05 [SI::V];
        }
        
        connect hvSupply.hvOutput to photomultiplierSystem.hvInput;
        connect photomultiplierSystem.signalOutput to preamp;
        connect preamp to discriminator;
    }
    
    requirement def SinglePhotonSensitivityReq {
        doc /* The photomultiplier shall detect individual photons with high efficiency */
        
        require constraint {
            photomultiplierSystem.photocathode.quantumEfficiency >= 0.20
        }
    }
    
    requirement def AmplificationPerformanceReq {
        doc /* The photomultiplier shall provide sufficient gain for single photon detection */
        
        require constraint {
            photomultiplierSystem.overallGain >= 1.0e5 and
            photomultiplierSystem.overallGain <= 1.0e7
        }
    }
    
    requirement def TemporalResolutionReq {
        doc /* The photomultiplier shall have fast response for timing measurements */
        
        require constraint {
            photomultiplierSystem.transitTime <= 30.0e-9 [SI::s]
        }
    }
    
    requirement def NoisePerformanceReq {
        doc /* The photomultiplier shall maintain low dark current for high signal-to-noise */
        
        require constraint {
            photomultiplierSystem.darkCurrent <= 1.0e-8 [SI::A]
        }
    }
    
    requirement def VoltageStabilityReq {
        doc /* The high voltage supply shall maintain stable output for consistent gain */
        
        require constraint {
            photomultiplierSystem.hvSupply.stability <= 0.01
        }
    }
    
    requirement systemRequirements {
        doc /* 
            The photomultiplier system shall convert extremely weak light signals,
            down to individual photons, into measurable electrical pulses through
            photoelectric conversion followed by electron multiplication cascade,
            enabling detection and measurement of low-level optical phenomena.
        */
        
        require SinglePhotonSensitivityReq;
        require AmplificationPerformanceReq;
        require TemporalResolutionReq;
        require NoisePerformanceReq;
        require VoltageStabilityReq;
    }
}
