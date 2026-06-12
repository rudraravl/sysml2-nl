package FullereneBasedSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Nanometer :> LengthUnit;
    attribute def ElectronVolt :> EnergyUnit;
    attribute def Kelvin :> TemperatureUnit;
    attribute def Mole :> AmountOfSubstanceUnit;

    value type Diameter :> Length {
        unit = Nanometer;
    }

    value type BindingEnergy :> Energy {
        unit = ElectronVolt;
    }

    value type MolecularTemperature :> Temperature {
        unit = Kelvin;
    }

    value type SubstanceAmount :> AmountOfSubstance {
        unit = Mole;
    }

    value type ElectronCount :> ScalarValues::Integer;
    value type CarbonAtomCount :> ScalarValues::Integer;
    value type ChargeState :> ScalarValues::Integer;
    value type TransferRate :> ScalarValues::Real;
    value type EncapsulationEfficiency :> ScalarValues::Real;

    item def Electron {
        attribute charge : ChargeState = -1;
    }

    item def Photon {
        attribute energy : BindingEnergy;
    }

    item def GuestMolecule {
        attribute molecularDiameter : Diameter;
        attribute netCharge : ChargeState;
        attribute bindingAffinity : BindingEnergy;
    }

    item def CarbonAtom {
        attribute valenceElectronCount : ElectronCount = 4;
    }

    item def StabilizedGuestComplex {
        attribute cageDiameter : Diameter;
        attribute guestDiameter : Diameter;
        attribute hostGuestBindingEnergy : BindingEnergy;
        attribute encapsulationEfficiency : EncapsulationEfficiency;
    }

    port def MolecularInputPort {
        in item guest : GuestMolecule;
    }

    port def MolecularOutputPort {
        out item complex : StabilizedGuestComplex;
    }

    port def ElectronAcceptorPort {
        in item excitedElectron : Electron;
        out item transferredElectron : Electron;
    }

    port def OpticalExcitationPort {
        in item incidentPhoton : Photon;
    }

    port def ThermalExchangePort {
        inout attribute localTemperature : MolecularTemperature;
    }

    part def FullereneCage {
        attribute carbonAtoms : CarbonAtomCount = 60;
        attribute cageDiameter : Diameter = 0.71 [Nanometer];
        attribute piElectronCount : ElectronCount = 60;
        attribute neutralCharge : ChargeState = 0;
        attribute electronAffinity : BindingEnergy = 2.68 [ElectronVolt];
        attribute structuralBindingEnergy : BindingEnergy = 7.4 [ElectronVolt];

        port guestIntake : MolecularInputPort;
        port guestRelease : MolecularOutputPort;
        port electronInterface : ElectronAcceptorPort;
        port thermalInterface : ThermalExchangePort;

        part carbonNetwork[60] : CarbonAtom;

        action stabilizeCage {
            in attribute ambientTemperature : MolecularTemperature;
            out attribute cageStable : Boolean;

            first start;
            then evaluateThermalLimit;
            then confirmStability;
            then done;

            action evaluateThermalLimit;
            action confirmStability;
        }

        action acceptElectron {
            in item incomingElectron : Electron;
            out item acceptedElectron : Electron;
            out attribute reducedCharge : ChargeState;

            first start;
            then delocalizeCharge;
            then updateChargeState;
            then done;

            action delocalizeCharge;
            action updateChargeState;
        }

        state machine cageOperationalState {
            state Unassembled;
            state StableNeutral;
            state ElectronExcited;
            state Reduced;
            state GuestBound;
            state Degraded;

            initial then Unassembled;

            transition assemble
                first Unassembled
                then StableNeutral;

            transition absorbExcitation
                first StableNeutral
                then ElectronExcited;

            transition captureElectron
                first ElectronExcited
                then Reduced;

            transition encapsulateGuest
                first StableNeutral
                then GuestBound;

            transition releaseGuest
                first GuestBound
                then StableNeutral;

            transition overheat
                first StableNeutral
                then Degraded;

            transition degradeFromReduced
                first Reduced
                then Degraded;
        }
    }

    part def GuestSelectionShell {
        attribute minimumGuestDiameter : Diameter = 0.20 [Nanometer];
        attribute maximumGuestDiameter : Diameter = 0.60 [Nanometer];
        attribute minimumBindingEnergy : BindingEnergy = 0.10 [ElectronVolt];

        port candidateInput : MolecularInputPort;
        port selectedOutput : MolecularInputPort;

        action screenGuestMolecule {
            in item candidate : GuestMolecule;
            out item acceptedGuest : GuestMolecule;
            out attribute accepted : Boolean;

            first start;
            then compareDiameter;
            then compareBindingAffinity;
            then emitDecision;
            then done;

            action compareDiameter;
            action compareBindingAffinity;
            action emitDecision;
        }
    }

    part def PhotoChargeActivationLayer {
        attribute excitationThreshold : BindingEnergy = 1.80 [ElectronVolt];
        attribute preferredPhotonEnergy : BindingEnergy = 2.33 [ElectronVolt];
        attribute nominalElectronTransferRate : TransferRate = 9.5e8;

        port opticalInput : OpticalExcitationPort;
        port electronOutput : ElectronAcceptorPort;

        action generateExcitedElectron {
            in item photon : Photon;
            out item excitedElectron : Electron;
            out attribute activationSuccessful : Boolean;

            first start;
            then absorbPhoton;
            then separateCharge;
            then emitExcitedElectron;
            then done;

            action absorbPhoton;
            action separateCharge;
            action emitExcitedElectron;
        }
    }

    part def EncapsulationController {
        attribute targetEfficiency : EncapsulationEfficiency = 0.92;
        attribute maximumOperatingTemperature : MolecularTemperature = 350 [Kelvin];

        port guestInput : MolecularInputPort;
        port complexOutput : MolecularOutputPort;
        port thermalMonitor : ThermalExchangePort;

        action coordinateEncapsulation {
            in item guest : GuestMolecule;
            out item complex : StabilizedGuestComplex;

            first start;
            then verifyTemperature;
            then positionGuestAtCageOpening;
            then formHostGuestComplex;
            then verifyComplexStability;
            then done;

            action verifyTemperature;
            action positionGuestAtCageOpening;
            action formHostGuestComplex;
            action verifyComplexStability;
        }

        state machine encapsulationState {
            state Idle;
            state ScreeningGuest;
            state AligningGuest;
            state BindingGuest;
            state ComplexStable;
            state RejectingGuest;

            initial then Idle;

            transition receiveGuest
                first Idle
                then ScreeningGuest;

            transition guestAccepted
                first ScreeningGuest
                then AligningGuest;

            transition guestRejected
                first ScreeningGuest
                then RejectingGuest;

            transition alignmentComplete
                first AligningGuest
                then BindingGuest;

            transition bindingComplete
                first BindingGuest
                then ComplexStable;

            transition resetAfterStable
                first ComplexStable
                then Idle;

            transition resetAfterReject
                first RejectingGuest
                then Idle;
        }
    }

    part def FullereneBasedMolecularCageSystem {
        attribute primaryFunction : String = "Use a C60 fullerene cage as a nanoscale host and electron-accepting structure to encapsulate compatible guest molecules and stabilize them as host-guest molecular complexes.";
        attribute nominalCageDiameter : Diameter = 0.71 [Nanometer];
        attribute nominalOperatingTemperature : MolecularTemperature = 298 [Kelvin];
        attribute requiredEncapsulationEfficiency : EncapsulationEfficiency = 0.90;

        port guestIn : MolecularInputPort;
        port stabilizedComplexOut : MolecularOutputPort;
        port lightIn : OpticalExcitationPort;
        port electronExchange : ElectronAcceptorPort;
        port heatExchange : ThermalExchangePort;

        part cage : FullereneCage;
        part selector : GuestSelectionShell;
        part activationLayer : PhotoChargeActivationLayer;
        part controller : EncapsulationController;

        connection guestSupply
            connect guestIn to selector.candidateInput;

        connection selectedGuestPath
            connect selector.selectedOutput to controller.guestInput;

        connection controllerToCage
            connect controller.guestInput to cage.guestIntake;

        connection cageComplexPath
            connect cage.guestRelease to controller.complexOutput;

        connection systemComplexOutput
            connect controller.complexOutput to stabilizedComplexOut;

        connection photonPath
            connect lightIn to activationLayer.opticalInput;

        connection electronActivationPath
            connect activationLayer.electronOutput to cage.electronInterface;

        connection systemElectronExchange
            connect cage.electronInterface to electronExchange;

        connection thermalControlPath
            connect heatExchange to controller.thermalMonitor;

        connection cageThermalPath
            connect controller.thermalMonitor to cage.thermalInterface;

        action performPrimaryFunction {
            in item candidateGuest : GuestMolecule;
            in item incidentPhoton : Photon;
            out item stabilizedComplex : StabilizedGuestComplex;

            first start;
            then screenCandidateGuest;
            then activateFullereneElectronAcceptance;
            then encapsulateGuestInCage;
            then stabilizeHostGuestComplex;
            then outputComplex;
            then done;

            action screenCandidateGuest;
            action activateFullereneElectronAcceptance;
            action encapsulateGuestInCage;
            action stabilizeHostGuestComplex;
            action outputComplex;
        }

        state machine systemLifecycle {
            state Standby;
            state GuestScreening;
            state FullereneActivated;
            state Encapsulating;
            state ComplexStabilized;
            state ComplexReleased;
            state Faulted;

            initial then Standby;

            transition guestReceived
                first Standby
                then GuestScreening;

            transition compatibleGuestDetected
                first GuestScreening
                then FullereneActivated;

            transition activationComplete
                first FullereneActivated
                then Encapsulating;

            transition encapsulationComplete
                first Encapsulating
                then ComplexStabilized;

            transition releaseComplete
                first ComplexStabilized
                then ComplexReleased;

            transition reset
                first ComplexReleased
                then Standby;

            transition incompatibleGuest
                first GuestScreening
                then Standby;

            transition excessiveTemperature
                first Standby
                then Faulted;

            transition bindingFailure
                first Encapsulating
                then Faulted;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : FullereneBasedMolecularCageSystem;

        doc /* The system shall use a fullerene molecular cage as its central structure to encapsulate a compatible guest molecule and produce a stabilized host-guest complex. */

        require constraint {
            system.requiredEncapsulationEfficiency >= 0.90
        }
    }

    requirement def FullereneStructureRequirement {
        subject cage : FullereneCage;

        doc /* The fullerene cage shall contain sixty carbon atoms arranged as a closed nanoscale cage with delocalized pi electrons. */

        require constraint {
            cage.carbonAtoms == 60 and
            cage.piElectronCount == 60 and
            cage.cageDiameter >= 0.65 [Nanometer] and
            cage.cageDiameter <= 0.80 [Nanometer]
        }
    }

    requirement def GuestCompatibilityRequirement {
        subject selector : GuestSelectionShell;

        doc /* The selector shall pass only guest molecules sized for encapsulation within the fullerene cage and having sufficient binding affinity for stable complex formation. */

        require constraint {
            selector.minimumGuestDiameter >= 0.20 [Nanometer] and
            selector.maximumGuestDiameter <= 0.60 [Nanometer] and
            selector.minimumBindingEnergy >= 0.10 [ElectronVolt]
        }
    }

    requirement def ElectronAcceptanceRequirement {
        subject cage : FullereneCage;

        doc /* The fullerene cage shall support electron acceptance through delocalization over the carbon network. */

        require constraint {
            cage.electronAffinity >= 2.50 [ElectronVolt]
        }
    }

    requirement def ThermalOperatingRequirement {
        subject system : FullereneBasedMolecularCageSystem;

        doc /* The system shall operate at molecular temperatures compatible with stable fullerene cage behavior and host-guest complex formation. */

        require constraint {
            system.nominalOperatingTemperature >= 250 [Kelvin] and
            system.nominalOperatingTemperature <= 350 [Kelvin]
        }
    }

    requirement def OpticalActivationRequirement {
        subject activationLayer : PhotoChargeActivationLayer;

        doc /* The photo-charge activation layer shall absorb photons above the excitation threshold and provide excited electrons to the fullerene cage interface. */

        require constraint {
            activationLayer.preferredPhotonEnergy >= activationLayer.excitationThreshold and
            activationLayer.nominalElectronTransferRate >= 1.0e8
        }
    }

    satisfy PrimaryFunctionRequirement by FullereneBasedMolecularCageSystem;
    satisfy FullereneStructureRequirement by FullereneCage;
    satisfy GuestCompatibilityRequirement by GuestSelectionShell;
    satisfy ElectronAcceptanceRequirement by FullereneCage;
    satisfy ThermalOperatingRequirement by FullereneBasedMolecularCageSystem;
    satisfy OpticalActivationRequirement by PhotoChargeActivationLayer;
}