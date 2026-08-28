package LinearAcetylenicCarbonChain {

    import ScalarValues::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value type LengthValue :> Real { unit 'm'; }
    value type DiameterValue :> Real { unit 'm'; }
    value type ForceValue :> Real { unit 'N'; }
    value type StressValue :> Real { unit 'Pa'; }
    value type StrainValue :> Real { unit '1'; }
    value type StiffnessValue :> Real { unit 'N/m'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type CurrentValue :> Real { unit 'A'; }
    value type ResistanceValue :> Real { unit 'ohm'; }
    value type ConductivityValue :> Real { unit 'S/m'; }
    value type EnergyValue :> Real { unit 'J'; }
    value type WavelengthValue :> Real { unit 'm'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type MobilityValue :> Real { unit 'm2/(V s)'; }
    value type PhotonFluxValue :> Real { unit '1/s'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type TimeValue :> Real { unit 's'; }
    value type CrossSectionValue :> Real { unit 'm2'; }

    // ============================================================
    // Enumerations
    // ============================================================
    enum BondTypeEnum {
        single;
        triple;
    }

    // ============================================================
    // Part Definitions: Structural Components
    // ============================================================
    part def CarbonAtom {
        doc "An individual carbon atom within the linear chain.";
        attribute atomicNumber : Integer = 6;
        attribute index : Integer;
        attribute axialPosition : LengthValue;
    }

    part def CarbonBond {
        doc "A covalent bond between two adjacent carbon atoms, either single or triple.";
        ref atomA : CarbonAtom;
        ref atomB : CarbonAtom;
        attribute bondType : BondTypeEnum;
        attribute bondEnergy : EnergyValue;
    }

    // ============================================================
    // Item Definitions: Flowing Entities
    // ============================================================
    item def Photon {
        doc "A quantum of electromagnetic radiation incident on the chain.";
        attribute wavelength : WavelengthValue;
        attribute frequency : FrequencyValue;
        attribute energy : EnergyValue;
    }

    item def Electron {
        doc "A delocalized charge carrier within the pi-electron system of the chain.";
        attribute charge : Real = -1.602176634e-19;
        attribute mobility : MobilityValue;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def MechanicalEndPort {
        doc "Mechanical interface at a chain terminus for axial force application and strain measurement.";
        in appliedForce : ForceValue;
        out measuredStrain : StrainValue;
    }

    port def ElectricalTerminalPort {
        doc "Electrical interface at a chain terminus for voltage application and current conduction.";
        in appliedVoltage : VoltageValue;
        out flowingCurrent : CurrentValue;
    }

    port def OpticalReceptorPort {
        doc "Optical interface along the chain length for photon absorption.";
        in incomingPhoton : Photon;
        out absorbed : Boolean;
    }

    // ============================================================
    // Connection Definitions
    // ============================================================
    connection def BondConnection {
        doc "A structural connection between two adjacent carbon atoms representing a covalent bond.";
        end atomA : CarbonAtom;
        end atomB : CarbonAtom;
        attribute bondType : BondTypeEnum;
    }

    connection def ElectricalConductionPath {
        doc "An electrical conduction pathway between two terminal ports.";
        end sourceTerminal : ElectricalTerminalPort;
        end sinkTerminal : ElectricalTerminalPort;
        attribute conductionCurrent : CurrentValue;
    }

    connection def MechanicalLoadPath {
        doc "A mechanical load transmission path between two end ports.";
        end loadEnd : MechanicalEndPort;
        end reactionEnd : MechanicalEndPort;
        attribute transmittedForce : ForceValue;
    }

    connection def OpticalExposurePath {
        doc "An optical exposure pathway from an external source to the chain receptor.";
        end receptor : OpticalReceptorPort;
        ref photon : Photon;
    }

    // ============================================================
    // Attribute Record Definitions
    // ============================================================
    attribute def ChainGeometricAttributes {
        attribute chainLength : LengthValue;
        attribute chainDiameter : DiameterValue;
        attribute chainCrossSection : CrossSectionValue;
        attribute atomCount : Natural;
        attribute bondCount : Natural;
    }

    attribute def MechanicalAttributes {
        attribute youngsModulus : StressValue;
        attribute tensileStrength : StressValue;
        attribute axialStiffness : StiffnessValue;
        attribute currentStrain : StrainValue;
        attribute currentStress : StressValue;
    }

    attribute def ElectricalAttributes {
        attribute conductivity : ConductivityValue;
        attribute electronMobility : MobilityValue;
        attribute resistance : ResistanceValue;
        attribute currentDensity : CurrentValue;
    }

    attribute def OpticalAttributes {
        attribute peakAbsorptionWavelength : WavelengthValue;
        attribute absorptionEfficiency : Real;
        attribute excitedStateEnergy : EnergyValue;
        attribute bandgapEnergy : EnergyValue;
    }

    // ============================================================
    // Requirement Definitions
    // ============================================================
    requirement def MechanicalStrengthRequirement {
        doc "The chain shall exhibit exceptional axial stiffness and tensile strength, far exceeding diamond (200 GPa tensile strength).";
        subject carbonChain : LinearAcetylenicCarbonChain;
        attribute requiredTensileStrength : StressValue = 200e9;
        attribute requiredYoungsModulus : StressValue = 1000e9;
        assert carbonChain.mechanicalAttributes.tensileStrength >= requiredTensileStrength;
        assert carbonChain.mechanicalAttributes.youngsModulus >= requiredYoungsModulus;
    }

    requirement def ElectricalConductionRequirement {
        doc "The chain shall conduct electrical current with high electron mobility characteristic of a quantum wire, exceeding 1e5 m2/(V s).";
        subject carbonChain : LinearAcetylenicCarbonChain;
        attribute requiredMobility : MobilityValue = 1.0e5;
        assert carbonChain.electricalAttributes.electronMobility >= requiredMobility;
    }

    requirement def OpticalInteractionRequirement {
        doc "The chain shall absorb photons in the UV-visible spectrum (10 nm to 700 nm) and undergo electronic excitation.";
        subject carbonChain : LinearAcetylenicCarbonChain;
        attribute minWavelength : WavelengthValue = 10e-9;
        attribute maxWavelength : WavelengthValue = 700e-9;
        assert carbonChain.opticalAttributes.peakAbsorptionWavelength >= minWavelength;
        assert carbonChain.opticalAttributes.peakAbsorptionWavelength <= maxWavelength;
    }

    requirement def ThermalStabilityRequirement {
        doc "The chain shall remain in the Ground State at standard operating temperature of 300 K.";
        subject carbonChain : LinearAcetylenicCarbonChain;
        attribute maxOperatingTemperature : TemperatureValue = 500;
        assert carbonChain.operatingTemperature <= maxOperatingTemperature;
    }

    // ============================================================
    // Main Part Definition
    // ============================================================
    part def LinearAcetylenicCarbonChain {
        doc "A one-dimensional nanomaterial: a single, perfectly straight chain of carbon atoms linked by alternating single and triple bonds, with a continuous delocalized pi-electron system enabling simultaneous mechanical strength, electrical conduction, and optical interaction.";

        // ---- Geometric Attributes ----
        attribute geometricAttributes : ChainGeometricAttributes {
            attribute chainLength = 1.0e-6;
            attribute chainDiameter = 0.27e-9;
            attribute chainCrossSection = 5.7e-20;
            attribute atomCount = 3700;
            attribute bondCount = 3699;
        }
        attribute operatingTemperature : TemperatureValue = 300;

        // ---- Mechanical Attributes ----
        attribute mechanicalAttributes : MechanicalAttributes {
            attribute youngsModulus = 1500e9;
            attribute tensileStrength = 350e9;
            attribute axialStiffness = 1500;
            attribute currentStrain = 0.0;
            attribute currentStress = 0.0;
        }

        // ---- Electrical Attributes ----
        attribute electricalAttributes : ElectricalAttributes {
            attribute conductivity = 6.3e7;
            attribute electronMobility = 2.0e5;
            attribute resistance = 1.0e3;
            attribute currentDensity = 0.0;
        }

        // ---- Optical Attributes ----
        attribute opticalAttributes : OpticalAttributes {
            attribute peakAbsorptionWavelength = 220e-9;
            attribute absorptionEfficiency = 0.85;
            attribute excitedStateEnergy = 5.6e-19;
            attribute bandgapEnergy = 5.6e-19;
        }

        // ---- Internal State Flags ----
        attribute photonAbsorbed : Boolean = false;
        attribute voltageActive : Boolean = false;
        attribute loadActive : Boolean = false;
        attribute excitedStateActive : Boolean = false;
        attribute lastRelaxationTime : TimeValue = 0.0;

        // ---- Ports ----
        port mechanicalEndA : MechanicalEndPort;
        port mechanicalEndB : MechanicalEndPort;
        port electricalTerminalA : ElectricalTerminalPort;
        port electricalTerminalB : ElectricalTerminalPort;
        port opticalReceptor : OpticalReceptorPort;

        // ---- Sub-parts: Carbon Atoms ----
        part carbonAtoms : CarbonAtom[2..*] ordered;

        // ---- Sub-parts: Bonds (alternating single and triple) ----
        part bonds : CarbonBond[*];

        // ---- Delocalized electrons ----
        item delocalizedElectrons : Electron[*];

        // ---- State Machine: Operational Behavior ----
        state ChainBehavior {
            initial initialGround;

            state GroundState {
                doc "Stable equilibrium; delocalized electrons occupy lowest available energy states. This is the default operating state.";
                entry action { photonAbsorbed = false; excitedStateActive = false; }
                attribute stable : Boolean = true;
            }

            state OpticallyExcitedState {
                doc "Photons absorbed in the UV-visible spectrum; delocalized electrons promoted to higher energy states. The chain stores excitation energy until radiative or non-radiative relaxation.";
                entry action { excitedStateActive = true; }
                do action { /* maintain excited state until relaxation */ }
                attribute absorbedPhotonCount : Natural = 0;
                attribute excessEnergy : EnergyValue;
                attribute relaxationTime : TimeValue;
            }

            state ElectricallyActiveState {
                doc "Voltage applied across terminals; delocalized electrons drift along the chain, conducting current with high mobility. The chain behaves as a nanoscale quantum wire.";
                entry action { voltageActive = true; }
                do action { /* conduct current along chain */ }
                attribute conductionCurrent : CurrentValue;
                attribute driftMobility : MobilityValue;
            }

            state MechanicallyStressedState {
                doc "Axial load applied; the chain bears tensile stress within its elastic limit. Exceptional stiffness and strength prevent failure under normal operating loads.";
                entry action { loadActive = true; }
                do action { /* sustain axial stress elastically */ }
                attribute appliedLoad : ForceValue;
                attribute elasticStrain : StrainValue;
            }

            // Initial transition
            transition from initialGround to GroundState;

            // Optical excitation: Ground -> Optically Excited
            transition absorbPhoton
                from GroundState to OpticallyExcitedState
                when photonAbsorbed == true;

            // Radiative or non-radiative relaxation: Optically Excited -> Ground
            transition radiativeRelaxation
                from OpticallyExcitedState to GroundState
                when photonAbsorbed == false;

            // Electrical activation: Ground -> Electrically Active
            transition applyVoltage
                from GroundState to ElectricallyActiveState
                when voltageActive == true;

            // Deactivation: Electrically Active -> Ground
            transition removeVoltage
                from ElectricallyActiveState to GroundState
                when voltageActive == false;

            // Mechanical loading: Ground -> Mechanically Stressed
            transition applyLoad
                from GroundState to MechanicallyStressedState
                when loadActive == true;

            // Unloading: Mechanically Stressed -> Ground
            transition releaseLoad
                from MechanicallyStressedState to GroundState
                when loadActive == false;

            // Combined regime: stress while optically excited
            transition stressedWhileOpticallyExcited
                from OpticallyExcitedState to MechanicallyStressedState
                when loadActive == true;

            // Combined regime: stress while electrically active
            transition stressedWhileElectricallyActive
                from ElectricallyActiveState to MechanicallyStressedState
                when loadActive == true;

            // Return from stressed state to optically excited when load released
            transition returnToOpticalFromStressed
                from MechanicallyStressedState to OpticallyExcitedState
                when photonAbsorbed == true and loadActive == false;

            // Return from stressed state to electrically active when load released
            transition returnToConductingFromStressed
                from MechanicallyStressedState to ElectricallyActiveState
                when voltageActive == true and loadActive == false;
        }

        // ---- Satisfy Requirements ----
        satisfy MechanicalStrengthRequirement;
        satisfy ElectricalConductionRequirement;
        satisfy OpticalInteractionRequirement;
        satisfy ThermalStabilityRequirement;
    }

    // ============================================================
    // Composite Device Definition
    // ============================================================
    part def NanoElectronicDevice {
        doc "A next-generation nano-electronic device embedding a Linear Acetylenic Carbon Chain as a multifunctional element for nano-electronics, composite materials, and advanced sensors.";

        part carbonChain : LinearAcetylenicCarbonChain;

        // External interface ports
        port loadInputA : MechanicalEndPort;
        port loadInputB : MechanicalEndPort;
        port powerAnode : ElectricalTerminalPort;
        port powerCathode : ElectricalTerminalPort;
        port photonInlet : OpticalReceptorPort;

        // Connections routing external interfaces to the embedded chain
        connection : MechanicalLoadPath connect loadInputA to carbonChain.mechanicalEndA;
        connection : MechanicalLoadPath connect loadInputB to carbonChain.mechanicalEndB;
        connection : ElectricalConductionPath connect powerAnode to carbonChain.electricalTerminalA;
        connection : ElectricalConductionPath connect powerCathode to carbonChain.electricalTerminalB;
        connection : OpticalExposurePath connect photonInlet to carbonChain.opticalReceptor;
    }

    // ============================================================
    // Usage Instance
    // ============================================================
    part nanoDeviceInstance : NanoElectronicDevice {
        doc "A concrete instance of the nano-electronic device for deployment in an advanced sensor or composite reinforcement application.";
    }

}
