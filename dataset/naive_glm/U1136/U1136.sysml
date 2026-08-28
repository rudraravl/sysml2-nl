package MolecularAssemblySystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value def Length_nm :> Real { unit 'nm'; }
    value def Energy_eV :> Real { unit 'eV'; }
    value def Pressure_Pa :> Real { unit 'Pa'; }
    value def Temperature_K :> Real {> Real { unit 'K'; }
    value def Time_s :> Real { unit 's'; }
    value def Power_W :> Real { unit 'W'; }
    value def Frequency_Hz :> Real { unit 'Hz'; }
    value def Mass_amu :> Real { unit 'amu'; }
    value def Charge_e :> Real { unit 'e'; }
    value def Probability :> Real;
    value def AtomCount :> Integer;
    value def BondCount :> Integer;

    // ===== Enumerations =====
    enum def AtomType {
        hydrogen = 1;
        carbon = 6;
        nitrogen = 7;
        oxygen = 8;
        fluorine = 9;
        phosphorus = 15;
        sulfur = 16;
        chlorine = 17;
    }

    enum def BondType {
        single;
        double;
        triple;
        ionic;
        metallic;
    }

    enum def AssemblyStatus {
        idle;
        initializing;
        scanning;
        picking;
        positioning;
        bonding;
        verifying;
        complete;
        failed;
    }

    enum def DefectType {
        none;
        missingAtom;
        misplacedAtom;
        wrongAtom;
        brokenBond;
        structuralDistortion;
    }

    // ===== Item Types =====
    item def Atom {
        attribute type : AtomType;
        attribute atomicNumber : Integer;
        attribute mass : Mass_amu;
        attribute charge : Charge_e := 0 [e];
        attribute positionX : Length_nm;
        attribute positionY : Length_nm;
        attribute positionZ : Length_nm;
    }

    item def MoleculeDesign {
        attribute designId : String;
        attribute targetAtoms : AtomCount;
        attribute targetBonds : BondCount;
        attribute atomList : Atom[*];
        attribute bondList : BondSpec[*];
    }

    item def BondSpec {
        attribute atomIndexA : Integer;
        attribute atomIndexB : Integer;
        attribute bondType : BondType;
        attribute bondEnergy : Energy_eV;
    }

    item def AssembledMolecule {
        attribute moleculeId : String;
        attribute designId : String;
        attribute atomCount : AtomCount;
        attribute bondCount : BondCount;
        attribute atoms : Atom[*];
        attribute defect : DefectType := DefectType::none;
    }

    item def DiagnosticReport {
        attribute reportId : String;
        attribute moleculeId : String;
        attribute success : Boolean;
        attribute assemblyTime : Time_s;
        attribute energyConsumed : Energy_eV;
        attribute defectType : DefectType;
        attribute timestamp : String;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetDesign : MoleculeDesign;
        attribute priority : Integer := 0;
    }

    item def ScanResult {
        attribute scanId : String;
        attribute surfaceMap : String;
        attribute resolution : Length_nm;
        attribute detectedAtoms : Atom[*];
    }

    item def QuantumState {
        attribute stateId : String;
        attribute coherenceTime : Time_s;
        attribute entanglementFidelity : Probability;
        attribute targetBondType : BondType;
    }

    // ===== Port Definitions =====
    port def ControlPort {
        in command : ControlCommand;
        out status : AssemblyStatus;
        out report : DiagnosticReport;
    }

    port def AtomSupplyPort {
        out atom : Atom;
    }

    port def AtomTransferPort {
        in atomIn : Atom;
        out atomOut : Atom;
    }

    port def ScanPort {
        out scanResult : ScanResult;
    }

    port def QuantumControlPort {
        in requestBond : BondSpec;
        out quantumState : QuantumState;
        out bondConfirmed : Boolean;
    }

    port def ProductPort {
        in molecule : AssembledMolecule;
    }

    port def PowerPort {
        in voltage : Real;
        in current : Real;
        out powerDraw : Power_W;
    }

    port def DiagnosticPort {
        out report : DiagnosticReport;
    }

    // ===== Interfaces =====
    interface def ControlInterface {
        end supplier : ControlPort;
        end consumer : ControlPort;
    }

    interface def AtomSupplyInterface {
        end supplier : AtomSupplyPort;
        end consumer : AtomSupplyPort;
    }

    interface def ScanInterface {
        end scanner : ScanPort;
        end receiver : ScanPort;
    }

    interface def QuantumInterface {
        end controller : QuantumControlPort;
        end manipulator : QuantumControlPort;
    }

    interface def ProductInterface {
        end producer : ProductPort;
        end collector : ProductPort;
    }

    interface def PowerInterface {
        end source : PowerPort;
        end load : PowerPort;
    }

    interface def DiagnosticInterface {
        end reporter : DiagnosticPort;
        end receiver : DiagnosticPort;
    }

    // ===== Requirements =====
    requirement def VacuumEnvironmentRequirement {
        doc "The assembly chamber must maintain ultra-high vacuum conditions."
        attribute maxPressure : Pressure_Pa := 1.0e-7 [Pa];
        attribute minTemperature : Temperature_K := 4.2 [K];
        subject chamber : VacuumChamber;
        require {
            chamber.pressure <= maxPressure and
            chamber.temperature >= minTemperature
        }
    }

    requirement def ManipulationAccuracyRequirement {
        doc "The molecular manipulator must achieve sub-nanometer placement accuracy."
        attribute maxPlacementError : Length_nm := 0.05 [nm];
        subject manipulator : MolecularManipulator;
        require { manipulator.placementAccuracy <= maxPlacementError }
    }

    requirement def AssemblyCompletenessRequirement {
        doc "Every atom in the target design must be placed and bonded."
        subject molecule : AssembledMolecule;
        subject design : MoleculeDesign;
        require {
            molecule.atomCount == design.targetAtoms and
            molecule.bondCount == design.targetBonds and
            molecule.defect == DefectType::none
        }
    }

    requirement def VerificationRequirement {
        doc "Assembled molecules must be verified against design specifications."
        subject molecule : AssembledMolecule;
        subject design : MoleculeDesign;
        require {
            molecule.designId == design.designId and
            molecule.defect == DefectType::none
        }
    }

    requirement def DiagnosticReportingRequirement {
        doc "Each assembly task must produce a diagnostic report with success, time, and energy."
        subject report : DiagnosticReport;
        require {
            report.assemblyTime > 0 [s] and
            report.energyConsumed > 0 [eV]
        }
    }

    requirement def QuantumCoherenceRequirement {
        doc "Quantum controller must maintain sufficient coherence for bond formation."
        attribute minFidelity : Probability := 0.99;
        subject quantumController : QuantumController;
        require { quantumController.entanglementFidelity >= minFidelity }
    }

    // ===== Part Definitions =====
    part def VacuumChamber {
        attribute pressure : Pressure_Pa;
        attribute temperature : Temperature_K;
        port controlIn : ControlPort;
        port powerIn : PowerPort;
        attribute vacuumPumpActive : Boolean := true;
        attribute cryoSystemActive : Boolean := true;
    }

    part def AssemblyProcessor {
        attribute processorId : String;
        attribute clockFrequency : Frequency_Hz;
        attribute currentDesign : MoleculeDesign;
        attribute currentStatus : AssemblyStatus := AssemblyStatus::idle;
        port commandPort : ControlPort;
        port diagnosticOut : DiagnosticPort;
        port powerIn : PowerPort;
        port manipulatorControl : ControlPort;
        port afmControl : ControlPort;
        port quantumControlLink : ControlPort;
        port reservoirControl : ControlPort;
        port collectorControl : ControlPort;

        attribute atomsPlaced : AtomCount := 0;
        attribute bondsFormed : BondCount := 0;
        attribute totalEnergyConsumed : Energy_eV := 0 [eV];
        attribute assemblyStartTime : Time_s;

        exhibit state AssemblyControlStateMachine {
            entry; then Idle;
            state Idle;
            accept command : ControlCommand via commandPort
            then Initializing;
            state Initializing {
                entry {
                    currentDesign := command.targetDesign;
                    currentStatus := AssemblyStatus::initializing;
                    atomsPlaced := 0;
                    bondsFormed := 0;
                    totalEnergyConsumed := 0 [eV];
                }
                then Scanning;
            }
            state Scanning {
                entry { currentStatus := AssemblyStatus::scanning; }
                then Picking;
            }
            state Picking {
                entry { currentStatus := AssemblyStatus::picking; }
                then Positioning;
            }
            state Positioning {
                entry { currentStatus := AssemblyStatus::positioning; }
                then Bonding;
            }
            state Bonding {
                entry { currentStatus := AssemblyStatus::bonding; }
                then CheckComplete;
            }
            state CheckComplete {
                if (atomsPlaced >= currentDesign.targetAtoms and
                    bondsFormed >= currentDesign.targetBonds)
                then Verifying
                else Scanning;
            }
            state Verifying {
                entry { currentStatus := AssemblyStatus::verifying; }
                then CheckVerification;
            }
            state CheckComplete2;
            state CheckVerification {
                if (verificationPassed)
                then Complete
                else Failed;
            }
            state Complete {
                entry {
                    currentStatus := AssemblyStatus::complete;
                    generateDiagnosticReport();
                }
                then Idle;
            }
            state Failed {
                entry {
                    currentStatus := AssemblyStatus::failed;
                    generateDiagnosticReport();
                }
                then Idle;
            }
        }

        private attribute verificationPassed : Boolean := true;

        private action generateDiagnosticReport {
            subject report : DiagnosticReport;
            assign report.reportId = "RPT-" + processorId;
            assign report.moleculeId = currentDesign.designId;
            assign report.success = (currentStatus == AssemblyStatus::complete);
            assign report.assemblyTime = 0.0 [s];
            assign report.energyConsumed = totalEnergyConsumed;
            assign report.defectType = DefectType::none;
        }
    }

    part def MolecularManipulator {
        attribute manipulatorId : String;
        attribute placementAccuracy : Length_nm := 0.02 [nm];
        attribute tipPositionX : Length_nm;
        attribute tipPositionY : Length_nm;
        attribute tipPositionZ : Length_nm;
        attribute heldAtom : Atom;
        attribute isHolding : Boolean := false;
        port controlIn : ControlPort;
        port atomSupply : AtomSupplyPort;
        port atomTransfer : AtomTransferPort;
        port quantumLink : QuantumControlPort;
        port powerIn : PowerPort;
        port diagnosticOut : DiagnosticPort;

        exhibit state ManipulatorStateMachine {
            entry; then Ready;
            state Ready;
            accept atom : Atom via atomSupply
            then Holding;
            state Holding {
                entry {
                    heldAtom := atom;
                    isHolding := true;
                }
                then Moving;
            }
            state Moving {
                entry {
                    tipPositionX := heldAtom.positionX;
                    tipPositionY := heldAtom.positionY;
                    tipPositionZ := heldAtom.positionZ;
                }
                then Placing;
            }
            state Placing {
                entry { isHolding := false; }
                then BondingRequest;
            }
            state BondingRequest {
                entry {
                    // Request quantum controller to form bond
                }
                then Ready;
            }
        }

        action pickAtom {
            in atom : Atom;
            out picked : Atom;
            assign picked = atom;
        }

        action positionAtom {
            in atom : Atom;
            in targetX : Length_nm;
            in targetY : Length_nm;
            in targetZ : Length_nm;
            out positioned : Atom;
            assign positioned.positionX = targetX;
            assign positioned.positionY = targetY;
            assign positioned.positionZ = targetZ;
        }

        action placeAtom {
            in atom : Atom;
            out placed : Atom;
            assign placed = atom;
        }
    }

    part def AtomicForceMicroscope {
        attribute afmId : String;
        attribute scanResolution : Length_nm := 0.01 [nm];
        attribute scanArea : Length_nm;
        attribute scanRate : Frequency_Hz;
        port controlIn : ControlPort;
        port scanOut : ScanPort;
        port powerIn : PowerPort;
        attribute lastScan : ScanResult;

        exhibit state AFMStateMachine {
            entry; then Standby;
            state Standby;
            accept command via controlIn
            then Scanning;
            state Scanning {
                entry { performScan(); }
                then Standby;
            }
        }

        action performScan {
            out result : ScanResult;
            assign result.scanId = "SCAN-" + afmId;
            assign result.resolution = scanResolution;
        }
    }

    part def QuantumController {
        attribute controllerId : String;
        attribute coherenceTime : Time_s := 100 [s];
        attribute entanglementFidelity : Probability := 0.999;
        attribute operatingTemperature : Temperature_K := 0.01 [K];
        port controlIn : ControlPort;
        port quantumOut : QuantumControlPort;
        port powerIn : PowerPort;
        attribute activeBond : BondSpec;

        exhibit state QuantumStateMachine {
            entry; then Calibrated;
            state Calibrated;
            accept bondSpec : BondSpec via quantumOut
            then Processing;
            state Processing {
                entry {
                    activeBond := bondSpec;
                    entanglementFidelity := stabilizeCoherence();
                }
                then FormingBond;
            }
            state FormingBond {
                entry { /* Apply quantum operations */ }
                then Calibrated;
            }
        }

        action stabilizeCoherence {
            out fidelity : Probability;
            assign fidelity = 0.999;
        }

        action formBond {
            in bondSpec : BondSpec;
            in atomA : Atom;
            in atomB : Atom;
            out success : Boolean;
            out energyReleased : Energy_eV;
            assign success = true;
            assign energyReleased = bondSpec.bondEnergy;
        }
    }

    part def FeedstockReservoir {
        attribute reservoirId : String;
        attribute capacity : AtomCount;
        attribute availableAtoms : Atom[*];
        attribute refillLevel : AtomCount;
        port controlIn : ControlPort;
        port atomOut : AtomSupplyPort;
        port powerIn : PowerPort;

        exhibit state ReservoirStateMachine {
            entry; then Available;
            state Available;
            accept request via controlIn
            then Dispensing;
            state Dispensing {
                entry { dispenseAtom(); }
                then CheckLevel;
            }
            state CheckLevel {
                if (availableAtoms.size() <= refillLevel)
                then LowStock
                else Available;
            }
            state LowStock {
                entry { /* Signal refill needed */ }
                then Available;
            }
        }

        action dispenseAtom {
            out atom : Atom;
            assign atom = availableAtoms->first();
        }
    }

    part def ProductCollector {
        attribute collectorId : String;
        attribute storageCapacity : AtomCount;
        attribute storedMolecules : AssembledMolecule[*];
        attribute currentCount : AtomCount := 0;
        port controlIn : ControlPort;
        port productIn : ProductPort;
        port powerIn : PowerPort;
        port diagnosticOut : DiagnosticPort;

        exhibit state CollectorStateMachine {
            entry; then Empty;
            state Empty;
            accept molecule : AssembledMolecule via productIn
            then Storing;
            state Storing {
                entry {
                    storedMolecules.append(molecule);
                    currentCount := currentCount + 1;
                }
                then CheckCapacity;
            }
            state CheckCapacity {
                if (currentCount >= storageCapacity)
                then Full
                else Empty;
            }
            state Full {
                entry { /* Signal storage full */ }
            }
        }
    }

    part def PowerSubsystem {
        attribute subsystemId : String;
        attribute totalPowerCapacity : Power_W;
        attribute currentDraw : Power_W;
        attribute efficiency : Real := 0.95;
        port powerOut : PowerPort;
        port diagnosticOut : DiagnosticPort;
        attribute active : Boolean := true;
    }

    part def DiagnosticSubsystem {
        attribute subsystemId : String;
        attribute reports : DiagnosticReport[*];
        attribute totalAssemblies : AtomCount := 0;
        attribute successfulAssemblies : AtomCount := 0;
        attribute failedAssemblies : AtomCount := 0;
        port diagnosticIn : DiagnosticPort;
        port diagnosticOut : DiagnosticPort;
        port powerIn : PowerPort;

        action logReport {
            in report : DiagnosticReport;
            then {
                reports.append(report);
                totalAssemblies := totalAssemblies + 1;
                if (report.success) {
                    successfulAssemblies := successfulAssemblies + 1;
                } else {
                    failedAssemblies := failedAssemblies + 1;
                }
            }
        }

        action generateSummary {
            out summary : String;
            assign summary = "Total: " + totalAssemblies.toString() +
                ", Success: " + successfulAssemblies.toString() +
                ", Failed: " + failedAssemblies.toString();
        }
    }

    // ===== Top-Level System =====
    part def MolecularAssemblyNanofactory {
        attribute systemId : String := "NANOFACTORY-001";
        attribute operationalStatus : AssemblyStatus := AssemblyStatus::idle;

        part vacuumChamber : VacuumChamber {
            attribute pressure := 1.0e-8 [Pa];
            attribute temperature := 4.2 [K];
        }

        part assemblyProcessor : AssemblyProcessor {
            attribute processorId := "PROC-001";
            attribute clockFrequency := 10.0e9 [Hz];
        }

        part molecularManipulator : MolecularManipulator {
            attribute manipulatorId := "MANIP-001";
            attribute placementAccuracy := 0.02 [nm];
        }

        part atomicForceMicroscope : AtomicForceMicroscope {
            attribute afmId := "AFM-001";
            attribute scanResolution := 0.01 [nm];
            attribute scanArea := 1000.0 [nm];
            attribute scanRate := 1000.0 [Hz];
        }

        part quantumController : QuantumController {
            attribute controllerId := "QC-001";
            attribute coherenceTime := 100.0 [s];
            attribute entanglementFidelity := 0.999;
        }

        part feedstockReservoir : FeedstockReservoir {
            attribute reservoirId := "RES-001";
            attribute capacity := 100000;
            attribute refillLevel := 1000;
        }

        part productCollector : ProductCollector {
            attribute collectorId := "COLL-001";
            attribute storageCapacity := 10000;
        }

        part powerSubsystem : PowerSubsystem {
            attribute subsystemId := "PWR-001";
            attribute totalPowerCapacity := 5000.0 [W];
            attribute currentDraw := 0.0 [W];
        }

        part diagnosticSubsystem : DiagnosticSubsystem {
            attribute subsystemId := "DIAG-001";
        }

        // ===== Connections =====
        connection : ControlInterface connect
            assemblyProcessor.commandPort to vacuumChamber.controlIn;

        connection : ControlInterface connect
            assemblyProcessor.manipulatorControl to molecularManipulator.controlIn;

        connection : ControlInterface connect
            assemblyProcessor.afmControl to atomicForceMicroscope.controlIn;

        connection : ControlInterface connect
            assemblyProcessor.quantumControlLink to quantumController.controlIn;

        connection : ControlInterface connect
            assemblyProcessor.reservoirControl to feedstockReservoir.controlIn;

        connection : ControlInterface connect
            assemblyProcessor.collectorControl to productCollector.controlIn;

        connection : AtomSupplyInterface connect
            feedstockReservoir.atomOut to molecularManipulator.atomSupply;

        connection : ScanInterface connect
            atomicForceMicroscope.scanOut to molecularManipulator.controlIn;

        connection : QuantumInterface connect
            quantumController.quantumOut to molecularManipulator.quantumLink;

        connection : ProductInterface connect
            molecularManipulator.atomTransfer to productCollector.productIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to vacuumChamber.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to assemblyProcessor.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to molecularManipulator.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to atomicForceMicroscope.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to quantumController.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to feedstockReservoir.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to productCollector.powerIn;

        connection : PowerInterface connect
            powerSubsystem.powerOut to diagnosticSubsystem.powerIn;

        connection : DiagnosticInterface connect
            assemblyProcessor.diagnosticOut to diagnosticSubsystem.diagnosticIn;

        connection : DiagnosticInterface connect
            molecularManipulator.diagnosticOut to diagnosticSubsystem.diagnosticIn;

        connection : DiagnosticInterface connect
            productCollector.diagnosticOut to diagnosticSubsystem.diagnosticIn;

        connection : DiagnosticInterface connect
            powerSubsystem.diagnosticOut to diagnosticSubsystem.diagnosticIn;

        // ===== Requirement Satisfaction =====
        satisfy VacuumEnvironmentRequirement by vacuumChamber;
        satisfy ManipulationAccuracyRequirement by molecularManipulator;
        satisfy AssemblyCompletenessRequirement by assemblyProcessor;
        satisfy VerificationRequirement by assemblyProcessor;
        satisfy DiagnosticReportingRequirement by diagnosticSubsystem;
        satisfy QuantumCoherenceRequirement by quantumController;

        // ===== System-Level Assembly Action =====
        action assembleMolecule {
            in design : MoleculeDesign;
            out molecule : AssembledMolecule;
            out report : DiagnosticReport;

            attribute startTime : Time_s;
            attribute endTime : Time_s;
            attribute totalEnergy : Energy_eV := 0 [eV];
            attribute atomsAssembled : AtomCount := 0;
            attribute bondsCreated : BondCount := 0;

            then Initialize;
            action Initialize {
                assign startTime = 0.0 [s];
            }
            then ScanWorkspace;
            action ScanWorkspace {
                out scanResult : ScanResult;
            }
            then AssemblyLoop;
            action AssemblyLoop {
                then PickAtom;
                action PickAtom {
                    in atom : Atom;
                    out picked : Atom;
                }
                then PositionAtom;
                action PositionAtom {
                    in atom : Atom;
                    in targetX : Length_nm;
                    in targetY : Length_nm;
                    in targetZ : Length_nm;
                    out positioned : Atom;
                }
                then BondAtom;
                action BondAtom {
                    in atom : Atom;
                    in bondSpec : BondSpec;
                    out bonded : Atom;
                    out energyUsed : Energy_eV;
                }
                then CheckLoop;
                action CheckLoop {
                    if (atomsAssembled < design.targetAtoms)
                    then PickAtom
                    else VerifyMolecule;
                }
            }
            then VerifyMolecule;
            action VerifyMolecule {
                in candidate : AssembledMolecule;
                out verified : AssembledMolecule;
                out defect : DefectType;
            }
            then GenerateReport;
            action GenerateReport {
                assign endTime = startTime + 0.0 [s];
                assign report.assemblyTime = endTime - startTime;
                assign report.energyConsumed = totalEnergy;
                assign report.success = (verified.defect == DefectType::none);
            }
        }
    }
}
