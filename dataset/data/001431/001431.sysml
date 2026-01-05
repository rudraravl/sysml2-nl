package FullereneBasedSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def MolecularGeometry;
    attribute def ElectronicState;
    attribute def PhotonWavelength;
    attribute def QuantumYield;
    
    value def CarbonCount :> Integer;
    value def ElectronCount :> Integer;
    value def PhotonEnergy :> ISQ::EnergyValue;
    
    item def CarbonAtom {
        attribute atomicNumber : Integer = 6;
        attribute hybridization : String = "sp2";
        attribute bondCount : Integer = 3;
    }
    
    item def PhotonPacket {
        attribute wavelength : ISQ::LengthValue;
        attribute energy : ISQ::EnergyValue;
        attribute frequency : ISQ::FrequencyValue;
    }
    
    item def ReactiveOxygenSpecies {
        attribute concentration : Real;
        attribute reactivity : Real;
    }
    
    item def TherapeuticAgent {
        attribute molecularWeight : ISQ::MassValue;
        attribute dosage : ISQ::MassValue;
    }
    
    port def OpticalInputPort {
        in item photon : PhotonPacket;
        out attribute absorptionConfirmed : Boolean;
    }
    
    port def PayloadReleasePort {
        out item therapeutic : TherapeuticAgent;
        in attribute releaseTriggered : Boolean;
    }
    
    port def OxygenInteractionPort {
        in item oxygen;
        out item ros : ReactiveOxygenSpecies;
    }
    
    part def FullereneCage {
        attribute carbonAtomCount : CarbonCount = 60;
        attribute cageDiameter : ISQ::LengthValue = 0.71e-9 [SI::m];
        attribute pentagonCount : Integer = 12;
        attribute hexagonCount : Integer = 20;
        attribute structuralStability : Real;
        
        part carbonAtoms : CarbonAtom[60];
        
        assert constraint eulerPolyhedronFormula {
            pentagonCount == 12 and
            hexagonCount == 20 and
            carbonAtomCount == 60
        }
    }
    
    part def PhotosensitizingLayer {
        attribute absorptionPeak : ISQ::LengthValue = 532e-9 [SI::m];
        attribute quantumEfficiency : QuantumYield;
        attribute excitedStateLifetime : ISQ::TimeValue;
    }
    
    part def PayloadChamber {
        attribute capacity : ISQ::VolumeValue = 0.18e-27 [SI::m^3];
        attribute loadedMass : ISQ::MassValue;
        attribute encapsulationEfficiency : Real;
        
        part cargo : TherapeuticAgent[0..1];
    }
    
    part def FunctionalCoating {
        attribute ligandDensity : Real;
        attribute targetingSpecificity : Real;
        attribute biocompatibility : Real;
    }
    
    action def AbsorbPhotonEnergy {
        in photonInput : PhotonPacket;
        in absorptionPeak : ISQ::LengthValue;
        out excitedState : ElectronicState;
        out absorbedEnergy : ISQ::EnergyValue;
        
        first start;
        then action checkWavelength {
            in wavelength = photonInput.wavelength;
            in targetWavelength = absorptionPeak;
            out matchQuality : Real;
        }
        then decide;
            if checkWavelength.matchQuality >= 0.8 then absorbPhoton;
            if checkWavelength.matchQuality < 0.8 then rejectPhoton;
        action absorbPhoton {
            out energy = photonInput.energy;
        }
        then done;
        action rejectPhoton;
        then done;
    }
    
    action def GenerateReactiveSpecies {
        in excitedEnergy : ISQ::EnergyValue;
        in oxygenPresent : Boolean;
        out rosProduced : ReactiveOxygenSpecies;
        
        first start;
        then decide;
            if oxygenPresent and excitedEnergy > 1.5e-19 [SI::J] then produceROS;
            if not oxygenPresent or excitedEnergy <= 1.5e-19 [SI::J] then noReaction;
        action produceROS {
            out species : ReactiveOxygenSpecies;
        }
        then done;
        action noReaction;
        then done;
    }
    
    action def ReleaseTherapeuticPayload {
        in triggerSignal : ReactiveOxygenSpecies;
        in payloadAvailable : Boolean;
        out releasedAgent : TherapeuticAgent;
        
        first start;
        then decide;
            if payloadAvailable and triggerSignal.concentration > 0.5 then releasePayload;
            if not payloadAvailable or triggerSignal.concentration <= 0.5 then holdPayload;
        action releasePayload {
            out agent : TherapeuticAgent;
        }
        then done;
        action holdPayload;
        then done;
    }
    
    action def PerformPhotodynamicTherapy {
        in photonFlux : PhotonPacket[*];
        in oxygenAvailability : Boolean;
        in initialPayload : TherapeuticAgent;
        out therapeuticEffect : Real;
        out rosGenerated : ReactiveOxygenSpecies[*] := ( );
        
        private attribute payloadReleased : Boolean := false;
        private attribute totalROS : Real := 0.0;
        
        first start;
        then merge continueTreatment;
        for photon in photonFlux {
            action absorb : AbsorbPhotonEnergy {
                in photonInput = photon;
                in absorptionPeak = 532e-9 [SI::m];
                out excitedState;
                out absorbedEnergy;
            }
            then action generateROS : GenerateReactiveSpecies {
                in excitedEnergy = absorb.absorbedEnergy;
                in oxygenPresent = oxygenAvailability;
                out rosProduced;
            }
            then assign rosGenerated := rosGenerated->including(generateROS.rosProduced);
            then assign totalROS := totalROS + generateROS.rosProduced.concentration;
            then action releasePayload : ReleaseTherapeuticPayload {
                in triggerSignal = generateROS.rosProduced;
                in payloadAvailable = not payloadReleased;
                out releasedAgent;
            }
            then decide;
                if releasePayload.releasedAgent != null then markReleased;
                if releasePayload.releasedAgent == null then continueTreatment;
            action markReleased;
            then assign payloadReleased := true;
            then continueTreatment;
        }
        then assign therapeuticEffect := totalROS * 1.5;
        then done;
    }
    
    state def FullereneOperationalStates {
        entry; then dormant;
        
        state dormant {
            doc /* Fullerene system is inactive, awaiting optical activation. */
        }
        
        accept photonExposure
        then dormant to activated;
        
        state activated {
            entry action absorbEnergy : AbsorbPhotonEnergy;
            doc /* Fullerene cage absorbs photon energy and enters excited state. */
        }
        
        if absorbEnergy.absorbedEnergy > 1.5e-19 [SI::J]
        then activated to generating;
        
        state generating {
            entry action produceROS : GenerateReactiveSpecies;
            doc /* Excited fullerene generates reactive oxygen species. */
        }
        
        if produceROS.rosProduced.concentration > 0.5
        then generating to releasing;
        
        state releasing {
            entry action deliverPayload : ReleaseTherapeuticPayload;
            doc /* Triggered release of encapsulated therapeutic agent. */
        }
        
        then releasing to completed;
        
        state completed {
            doc /* Therapeutic delivery cycle completed. */
        }
        
        accept reset
        then completed to dormant;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The fullerene-based system shall perform photodynamic therapy by 
               absorbing optical energy, generating reactive oxygen species, and 
               releasing therapeutic payload in a controlled manner. */
    }
    
    requirement def StructuralStabilityRequirement {
        doc /* The fullerene cage shall maintain structural integrity with 60 
               carbon atoms arranged in 12 pentagonal and 20 hexagonal rings. */
        
        require constraint {
            carbonAtomCount == 60 and
            pentagonCount == 12 and
            hexagonCount == 20
        }
    }
    
    requirement def PhotoabsorptionRequirement {
        doc /* The system shall absorb photons at wavelengths between 400-700 nm 
               with quantum efficiency greater than 0.6. */
        
        require constraint {
            absorptionPeak >= 400e-9 [SI::m] and
            absorptionPeak <= 700e-9 [SI::m] and
            quantumEfficiency > 0.6
        }
    }
    
    requirement def PayloadCapacityRequirement {
        doc /* The payload chamber shall encapsulate therapeutic agents with 
               molecular weight up to 500 Da with efficiency above 70%. */
        
        require constraint {
            encapsulationEfficiency > 0.7 and
            capacity >= 0.15e-27 [SI::m^3]
        }
    }
    
    requirement def ROSGenerationRequirement {
        doc /* Upon activation, the system shall generate reactive oxygen species 
               with concentration sufficient to trigger payload release. */
        
        require constraint {
            rosConcentration > 0.5
        }
    }
    
    part fullereneTherapeuticSystem : FullereneCage {
        doc /* A fullerene-based photodynamic therapeutic delivery system that 
               combines photosensitization, reactive oxygen generation, and 
               controlled drug release for targeted cancer treatment. */
        
        attribute carbonAtomCount = 60;
        attribute cageDiameter = 0.71e-9 [SI::m];
        attribute structuralStability = 0.95;
        
        part photosensitizer : PhotosensitizingLayer {
            attribute absorptionPeak = 532e-9 [SI::m];
            attribute quantumEfficiency = 0.75;
            attribute excitedStateLifetime = 1.2e-6 [SI::s];
        }
        
        part payloadStorage : PayloadChamber {
            attribute capacity = 0.18e-27 [SI::m^3];
            attribute loadedMass = 8.3e-22 [SI::kg];
            attribute encapsulationEfficiency = 0.82;
        }
        
        part surfaceModification : FunctionalCoating {
            attribute ligandDensity = 2.5;
            attribute targetingSpecificity = 0.88;
            attribute biocompatibility = 0.92;
        }
        
        port opticalInput : OpticalInputPort;
        port payloadOutput : PayloadReleasePort;
        port oxygenInterface : OxygenInteractionPort;
        
        perform action therapeuticFunction : PerformPhotodynamicTherapy {
            in oxygenAvailability = true;
        }
        
        exhibit state operationalCycle : FullereneOperationalStates;
    }
    
    requirement <'FULL-SYS-001'> fullereneSystemMission {
        doc /* The fullerene-based system shall serve as a multifunctional 
               nanoplatform for photodynamic therapy, integrating light-activated 
               reactive oxygen species generation with controlled therapeutic 
               agent delivery to enable targeted treatment of diseased cells while 
               minimizing damage to healthy tissue. */
        
        subject fullereneTherapeuticSystem;
        
        require primaryFunction : PrimaryFunctionRequirement;
        require structuralStability : StructuralStabilityRequirement;
        require photoabsorption : PhotoabsorptionRequirement;
        require payloadCapacity : PayloadCapacityRequirement;
        require rosGeneration : ROSGenerationRequirement;
    }
}
