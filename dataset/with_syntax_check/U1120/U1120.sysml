package LinearAcetylenicCarbonSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CarbonAtomCount :> Natural;
    attribute def BondStrength :> Real;
    attribute def ConjugationDegree :> Real;
    
    attribute def ChainLengthValue :> LengthValue;
    attribute def ElectricalConductivityValue :> Real;
    attribute def MechanicalStiffnessValue :> Real;
    attribute def OpticalAbsorptionValue :> Real;
    attribute def ElectronMobilityValue :> Real;
    
    item def Photon {
        attribute wavelength : LengthValue;
        attribute energy : EnergyValue;
    }
    
    item def Electron {
        attribute mobility : ElectronMobilityValue;
        attribute energy : EnergyValue;
    }
    
    port def OpticalPort {
        in item incidentPhotons : Photon[*];
        out item transmittedPhotons : Photon[*];
        attribute absorptionCoefficient : OpticalAbsorptionValue;
    }
    
    port def ElectricalPort {
        in item inputElectrons : Electron[*];
        out item outputElectrons : Electron[*];
        attribute conductivity : ElectricalConductivityValue;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def MechanicalPort {
        attribute appliedStress : PressureValue;
        attribute resultingStrain : Real;
        attribute stiffness : MechanicalStiffnessValue;
    }
    
    part def CarbonAtom {
        attribute atomicNumber : CarbonAtomCount = 6;
        attribute hybridization : String = "sp";
        attribute bondingElectrons : Natural = 2;
    }
    
    part def TripleBond {
        attribute bondOrder : Real = 3.0;
        attribute bondLength : LengthValue = 0.120[nm];
        attribute bondEnergy : EnergyValue = 839[kJ/mol];
        ref part carbonAtom1 : CarbonAtom;
        ref part carbonAtom2 : CarbonAtom;
    }
    
    part def ConjugatedElectronSystem {
        attribute delocalizedElectronCount : Natural;
        attribute bandGap : EnergyValue;
        part piElectrons : Electron[*];
        
        action def TransportElectrons {
            in appliedField : ElectricPotentialValue;
            in electronCount : Natural;
            out current : ElectricCurrentValue;
            out mobility : ElectronMobilityValue;
        }
    }
    
    part def LinearAcetylenicCarbonChain {
        doc /* A one-dimensional carbon allotrope consisting of sp-hybridized carbon atoms 
             connected by alternating single and triple bonds, forming an extended conjugated 
             pi-electron system with exceptional mechanical, electrical, and optical properties. */
        
        attribute numberOfAtoms : CarbonAtomCount;
        attribute totalChainLength : ChainLengthValue;
        attribute mechanicalStiffness : MechanicalStiffnessValue;
        attribute electricalConductivity : ElectricalConductivityValue;
        
        part carbonAtoms : CarbonAtom[numberOfAtoms] ordered;
        part tripleBonds : TripleBond[numberOfAtoms] ordered;
        part conjugatedSystem : ConjugatedElectronSystem;
        
        port opticalInterface : OpticalPort;
        port electricalInterface : ElectricalPort;
        port mechanicalInterface : MechanicalPort;
    }
    
    action def AbsorbPhotonEnergy {
        in photon : Photon;
        in chain : LinearAcetylenicCarbonChain;
        out excitedElectrons : Electron[*];
        out absorptionEfficiency : Real;
        
        attribute transitionEnergy : EnergyValue;
    }
    
    action def ConductElectricalCurrent {
        in appliedVoltage : ElectricPotentialValue;
        in chainConductivity : ElectricalConductivityValue;
        in chainLength : ChainLengthValue;
        out current : ElectricCurrentValue;
        out powerDissipation : PowerValue;
    }
    
    action def TransferMechanicalLoad {
        in appliedForce : ForceValue;
        in chainStiffness : MechanicalStiffnessValue;
        out displacement : LengthValue;
        out internalStress : PressureValue;
    }
    
    attribute def EnergyRelaxationSignal;
    attribute def VoltageApplicationSignal;
    attribute def VoltageRemovalSignal;
    attribute def ForceApplicationSignal;
    attribute def ForceRemovalSignal;
    
    state def ChainOperationalState {
        entry action initializeChain;
        
        state GroundState {
            doc /* All electrons in lowest energy configuration */
            entry action stabilizeStructure;
        }
        
        state OpticallyExcited {
            doc /* Electrons promoted to higher energy states by photon absorption */
            entry action exciteElectrons;
            exit action relaxElectrons;
        }
        
        state ElectricallyActive {
            doc /* Electrons flowing through conjugated system under applied field */
            entry action enableConduction;
            exit action disableConduction;
        }
        
        state MechanicallyStressed {
            doc /* Chain under tensile or compressive load */
            entry action distributeStress;
            exit action releaseStress;
        }
        
        transition groundToOptical
            first GroundState
            accept photonAbsorption : Photon
            then OpticallyExcited;
        
        transition opticalToGround
            first OpticallyExcited
            accept energyRelaxation : EnergyRelaxationSignal
            then GroundState;
        
        transition groundToElectrical
            first GroundState
            accept voltageApplication : VoltageApplicationSignal
            then ElectricallyActive;
        
        transition electricalToGround
            first ElectricallyActive
            accept voltageRemoval : VoltageRemovalSignal
            then GroundState;
        
        transition groundToMechanical
            first GroundState
            accept forceApplication : ForceApplicationSignal
            then MechanicallyStressed;
        
        transition mechanicalToGround
            first MechanicallyStressed
            accept forceRemoval : ForceRemovalSignal
            then GroundState;
    }
    
    action def OperateLinearAcetylenicCarbonSystem {
        doc /* Primary system operation: exploit the extended conjugated pi-electron system 
             for simultaneous optical absorption, electrical conduction, and mechanical 
             load bearing through the one-dimensional carbon chain structure. */
        
        in opticalInput : Photon[*];
        in electricalVoltage : ElectricPotentialValue;
        in mechanicalForce : ForceValue;
        out opticalOutput : Photon[*];
        out electricalCurrent : ElectricCurrentValue;
        out mechanicalDisplacement : LengthValue;
        
        private attribute chainLength : ChainLengthValue;
        private attribute chainConductivity : ElectricalConductivityValue;
        private attribute chainStiffness : MechanicalStiffnessValue;
        private attribute configuredChain : LinearAcetylenicCarbonChain;
        
        first start;
        then merge operationCycle;
        
        then action initializeSystem {
            action createChain {
                out chain : LinearAcetylenicCarbonChain;
            }
            then action configureProperties {
                in chain = createChain.chain;
                out configuredChainOut : LinearAcetylenicCarbonChain;
            }
        }
        
        then assign configuredChain := initializeSystem.configureProperties.configuredChainOut;
        then assign chainLength := configuredChain.totalChainLength;
        then assign chainConductivity := configuredChain.electricalConductivity;
        then assign chainStiffness := configuredChain.mechanicalStiffness;
        
        then decide;
            if opticalInput->size() > 0 then handleOptical;
            if electricalVoltage > 0[V] then handleElectrical;
            if mechanicalForce > 0[N] then handleMechanical;
        
        action handleOptical : AbsorbPhotonEnergy {
            in photon = opticalInput->at(1);
            in chain = configuredChain;
            out excitedElectrons;
            out absorptionEfficiency;
        }
        then assign opticalOutput := opticalOutput->including(handleOptical.excitedElectrons->at(1));
        then operationCycle;
        
        action handleElectrical : ConductElectricalCurrent {
            in appliedVoltage = electricalVoltage;
            in chainConductivity = chainConductivity;
            in chainLength = chainLength;
            out current;
            out powerDissipation;
        }
        then assign electricalCurrent := handleElectrical.current;
        then operationCycle;
        
        action handleMechanical : TransferMechanicalLoad {
            in appliedForce = mechanicalForce;
            in chainStiffness = chainStiffness;
            out displacement;
            out internalStress;
        }
        then assign mechanicalDisplacement := handleMechanical.displacement;
        then operationCycle;
        
        then done;
    }
    
    part lacSystem : LinearAcetylenicCarbonChain {
        doc /* Linear acetylenic carbon system configured for multifunctional operation */
        
        attribute :>> numberOfAtoms = 50;
        attribute :>> totalChainLength = 6.0[nm];
        attribute :>> mechanicalStiffness = 1.0e12;
        attribute :>> electricalConductivity = 1.0e6;
        
        perform action systemOperation : OperateLinearAcetylenicCarbonSystem;
        exhibit state operationalBehavior : ChainOperationalState;
    }
    
    requirement def OpticalAbsorptionRequirement {
        doc /* The system shall absorb photons across UV-visible spectrum through 
             pi-to-pi-star electronic transitions in the conjugated system. */
        
        require constraint {
            lacSystem.opticalInterface.absorptionCoefficient > 0.5
        }
    }
    
    requirement def ElectricalConductionRequirement {
        doc /* The system shall conduct electrons along the chain axis with high 
             mobility due to delocalized pi-electrons. */
        
        require constraint {
            lacSystem.electricalInterface.conductivity > 1.0e5
        }
    }
    
    requirement def MechanicalStiffnessRequirement {
        doc /* The system shall exhibit ultra-high axial stiffness exceeding that 
             of diamond due to strong sp-hybridized triple bonds. */
        
        require constraint {
            lacSystem.mechanicalInterface.stiffness > 1.0e11
        }
    }
    
    requirement def StructuralStabilityRequirement {
        doc /* The carbon chain shall maintain linear geometry and conjugation 
             under operational conditions. */
        
        require constraint {
            lacSystem.totalChainLength > 0[nm] and 
            lacSystem.numberOfAtoms >= 10
        }
    }
    
    requirement <'LAC-001'> primaryFunctionRequirement {
        doc /* The linear acetylenic carbon system shall function as a one-dimensional 
             quantum wire and ultra-strong nanostructure by exploiting its extended 
             conjugated pi-electron system formed by sp-hybridized carbon atoms connected 
             through alternating triple bonds, enabling simultaneous optical energy 
             absorption, ballistic electron transport, and exceptional mechanical load 
             bearing along the chain axis. */
        
        subject lacSystem;
        
        require opticalFunction : OpticalAbsorptionRequirement;
        require electricalFunction : ElectricalConductionRequirement;
        require mechanicalFunction : MechanicalStiffnessRequirement;
        require structuralIntegrity : StructuralStabilityRequirement;
    }
}
