package LinearAcetylenicCarbonChain {
    private import SI::*;
    
    part def CarbonAtom {
        attribute atomicNumber : ScalarValues::Integer = 6;
    }
    
    part def Bond {
        attribute bondType : ScalarValues::String;
        attribute length :> ISQ::length;
        attribute energy :> ISQ::energy;
    }
    
    attribute def Photon;
    attribute def Voltage;
    attribute def Force;
    
    action def maintainStability;
    action def exciteElectrons;
    action def emitPhoton;
    action def initiateCurrent;
    action def conductCharge;
    action def applyLoad;
    action def resistDeformation;
    
    port def MechanicalPort {
        attribute appliedForce :> ISQ::force;
        attribute resultingStrain : ScalarValues::Real;
    }
    
    port def ElectricalPort {
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }
    
    port def OpticalPort {
        attribute incidentWavelength :> ISQ::length;
        attribute absorbedEnergy :> ISQ::energy;
    }
    
    state def OperationalState {
        state Ground {
            do action maintainStability;
        }
        state OpticallyExcited {
            do action emitPhoton;
        }
        state ElectricallyActive {
            do action conductCharge;
        }
        state MechanicallyStressed {
            do action resistDeformation;
        }
        
        transition t1 first Ground 
            accept p : Photon 
            do action exciteElectrons 
            then OpticallyExcited;
        transition t2 first OpticallyExcited 
            accept r : Photon 
            then Ground;
        transition t3 first Ground 
            accept v : Voltage 
            do action initiateCurrent 
            then ElectricallyActive;
        transition t4 first ElectricallyActive 
            accept r : Voltage 
            then Ground;
        transition t5 first Ground 
            accept f : Force 
            do action applyLoad 
            then MechanicallyStressed;
        transition t6 first MechanicallyStressed 
            accept r : Force 
            then Ground;
    }
    
    part def LinearAcetylenicCarbonChain {
        attribute chainLength :> ISQ::length;
        attribute atomCount : ScalarValues::Integer;
        attribute bondLength :> ISQ::length;
        attribute tensileStrength :> ISQ::pressure;
        attribute electronMobility : ScalarValues::Real;
        attribute opticalBandgap :> ISQ::energy;
        
        part carbonAtoms : CarbonAtom[2..*];
        part bonds : Bond[1..*];
        
        port mechanicalInterface : MechanicalPort;
        port electricalInterface : ElectricalPort;
        port opticalInterface : OpticalPort;
        
        state operationalState : OperationalState;
    }
    
    requirement def MechanicalStrengthRequirement {
        subject chain : LinearAcetylenicCarbonChain;
        doc /* The chain must exhibit tensile strength exceeding that of diamond. */
        attribute requiredStrength :> ISQ::pressure;
        require constraint { chain.tensileStrength >= requiredStrength }
    }
    
    requirement def ElectricalConductionRequirement {
        subject chain : LinearAcetylenicCarbonChain;
        doc /* The chain must function as a high-mobility quantum wire. */
        attribute requiredMobility : ScalarValues::Real;
        require constraint { chain.electronMobility >= requiredMobility }
    }
    
    requirement def OpticalInteractionRequirement {
        subject chain : LinearAcetylenicCarbonChain;
        doc /* The chain must efficiently absorb UV-visible photons. */
        attribute minBandgap :> ISQ::energy;
        attribute maxBandgap :> ISQ::energy;
        require constraint { chain.opticalBandgap >= minBandgap and chain.opticalBandgap <= maxBandgap }
    }
    
    analysis def ChainPerformanceAnalysis {
        subject chain : LinearAcetylenicCarbonChain;
        requirement mechReq : MechanicalStrengthRequirement;
        requirement elecReq : ElectricalConductionRequirement;
        requirement optReq : OpticalInteractionRequirement;
    }
    
    part advancedNanowire : LinearAcetylenicCarbonChain {
        attribute redefines chainLength = 100e-9 * m;
        attribute redefines atomCount = 500;
        attribute redefines bondLength = 0.12e-9 * m;
        attribute redefines tensileStrength = 150e9 * Pa;
        attribute redefines electronMobility = 10000;
        attribute redefines opticalBandgap = 2.5 * 1.602176634e-19 * J;
        
        part redefines carbonAtoms[500];
        part redefines bonds[499] {
            attribute redefines bondType = "alternating_triple_single";
            attribute redefines length = 0.12e-9 * m;
            attribute redefines energy = 8.0 * 1.602176634e-19 * J;
        }
        
        satisfy requirement mechReq : MechanicalStrengthRequirement by advancedNanowire;
        satisfy requirement elecReq : ElectricalConductionRequirement by advancedNanowire;
        satisfy requirement optReq : OpticalInteractionRequirement by advancedNanowire;
    }
}
