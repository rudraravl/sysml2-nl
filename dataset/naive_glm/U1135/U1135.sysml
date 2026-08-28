package MolecularAssemblerModel {
    import ScalarValues::*;
    import ISQ::*;

    value def LengthNm = Real { unit 'nm'; }
    value def EnergyEV = Real { unit 'eV'; }
    value def TemperatureK = Real { unit 'K'; }
    value def MassAmu = Real { unit 'amu'; }
    value def Probability = Real;
    value def ProgressPercent = Real;
    value def ScanRate = Integer { unit 'Hz'; }

    enum ElementTypes {
        H, He, Li, Be, B, C, N, O, F, Ne,
        Na, Mg, Al, Si, P, S, Cl, Ar,
        K, Ca, Sc, Ti, V, Cr, Mn, Fe, Co, Ni, Cu, Zn, Ga, Ge, As, Se, Br, Kr,
        Rb, Sr, Y, Zr, Nb, Mo, Tc, Ru, Rh, Pd, Ag, Cd, In, Sn, Sb, Te, I, Xe,
        Cs, Ba, La, Ce, Pr, Nd, Pm, Sm, Eu, Gd, Tb, Dy, Ho, Er, Tm, Yb, Lu,
        Hf, Ta, W, Re, Os, Ir, Pt, Au, Hg, Tl, Pb, Bi, Po, At, Rn,
        Fr, Ra, Ac, Th, Pa, U, Np, Pu, Am, Cm, Bk, Cf, Es, Fm, Md, No, Lr
    }

    enum BondType { Single, Double, Triple, Ionic, Covalent, PolarCovalent, Metallic, Hydrogen }
    enum AtomStatus { Raw, Sorted, Purified, Selected, InTransit, Placed, Bonded, Rejected }
    enum SystemState { Idle, Initialized, Running, Paused, ErrorRecovery, Aborted, Completed }
    enum CommandType { Initialize, Start, Pause, Resume, Fetch, Place, Bond, Scan, Correct, Abort, Eject }
    enum VerificationStatus { Pass, Fail, MisplacedAtom, MissingBond, ExtraAtom, StructuralDeviation, BondFailure }
    enum Severity { Info, Warning, Critical }

    item def Atom {
        attribute element : ElementTypes;
        attribute atomicNumber : Integer;
        attribute mass : MassAmu;
        attribute status : AtomStatus := AtomStatus::Raw;
        attribute position : LengthNm[3] := [0.0, 0.0, 0.0];
    }

    item def AtomPlacement {
        attribute stepIndex : Integer;
        attribute element : ElementTypes;
        attribute targetPosition : LengthNm[3];
        attribute tolerance : LengthNm;
    }

    item def BondSpec {
        attribute bondId : Integer;
        attribute bondType : BondType;
        attribute atomIndexA : Integer;
        attribute atomIndexB : Integer;
        attribute bondEnergy : EnergyEV;
    }

    item def MolecularBlueprint {
        attribute name : String;
        attribute description : String;
        attribute totalAtoms : Integer;
        attribute placements : AtomPlacement[0..*];
        attribute bonds : BondSpec[0..*];
    }

    item def Command {
        attribute type : CommandType;
        attribute stepIndex : Integer;
        attribute element : ElementTypes;
        attribute targetPosition : LengthNm[3];
        attribute bondType : BondType;
        attribute bondEnergy : EnergyEV;
    }

    item def StatusReport {
        attribute state : SystemState;
        attribute progress : ProgressPercent;
        attribute atomsPlaced : Integer;
        attribute atomsBonded : Integer;
        attribute errorsDetected : Integer;
        attribute message : String;
    }

    item def VerificationResult {
        attribute status : VerificationStatus;
        attribute stepIndex : Integer;
        attribute deviation : LengthNm;
        attribute severity : Severity;
        attribute description : String;
    }

    item def QualityReport {
        attribute overallStatus : VerificationStatus;
        attribute totalDefects : Integer;
        attribute passRate : Probability;
        attribute finalScanComplete : Boolean;
    }

    item def MolecularProduct {
        attribute name : String;
        attribute blueprintName : String;
        attribute atomCount : Integer;
        attribute bondCount : Integer;
        attribute quality : QualityReport;
    }

    item def FeedstockBatch {
        attribute batchId : String;
        attribute atoms : Atom[0..*];
        attribute totalAtoms : Integer;
    }

    port def RawFeedstockPort {
        in item batch : FeedstockBatch;
    }

    port def ProcessedAtomPort {
        out item atom : Atom;
    }

    port def CommandInputPort {
        in item cmd : Command;
    }

    port def StatusOutputPort {
        out item status : StatusReport;
    }

    port def PlacementOutputPort {
        out item placedAtom : Atom;
    }

    port def PlacementInputPort {
        in item placedAtom : Atom;
    }

    port def BondResultOutputPort {
        out item result : VerificationResult;
    }

    port def ScanResultOutputPort {
        out item result : VerificationResult;
    }

    port def ScanResultInputPort {
        in item result : VerificationResult;
    }

    port def BondResultInputPort {
        in item result : VerificationResult;
    }

    port def OperatorPort {
        in item blueprint : MolecularBlueprint;
        in item command : Command;
        out item status : StatusReport;
        out item quality : QualityReport;
    }

    port def ProductOutputPort {
        out item product : MolecularProduct;
    }

    part def FeedstockProcessor {
        port rawIn : RawFeedstockPort;
        port atomOut : ProcessedAtomPort;
        port cmdIn : CommandInputPort;
        port statusOut : StatusOutputPort;

        attribute capacity : Integer := 10000;
        attribute purityThreshold : Probability := 0.9999;
        attribute operatingTemperature : TemperatureK := 4.2;
        attribute currentBatch : FeedstockBatch;
        attribute sortedAtoms : Atom[0..*];
        attribute purifiedAtoms : Atom[0..*];
        attribute isReady : Boolean := false;

        state feedstockBehavior {
            entry; then Waiting;

            state Waiting {
                entry { isReady := false; }
            }
            state Receiving;
            state Sorting;
            state Purifying;
            state Dispensing;
            state ErrorState;

            transition Waiting to Receiving when rawIn.batch is received;
            transition Receiving to Sorting when currentBatch.totalAtoms > 0;
            transition Sorting to Purifying when sortedAtoms->size() >= currentBatch.totalAtoms * 0.95;
            transition Purifying to Dispensing when purifiedAtoms->size() > 0 and purityCheck();
            transition Dispensing to Waiting when purifiedAtoms->isEmpty();
            transition any to ErrorState when cmdIn.cmd.type == CommandType::Abort;
            transition ErrorState to Waiting when cmdIn.cmd.type == CommandType::Initialize;
        }

        private action purityCheck : Boolean {
            return purifiedAtoms->size() > 0;
        }

        action sortAtoms {
            in batch : FeedstockBatch;
            out sorted : Atom[0..*];
        }

        action purifyAtoms {
            in sorted : Atom[0..*];
            in threshold : Probability;
            out purified : Atom[0..*];
        }

        action dispenseAtom {
            in element : ElementTypes;
            out atom : Atom;
        }

        action generateStatus {
            out status : StatusReport;
        }
    }

    part def AssemblyController {
        port operator : OperatorPort;
        port feedstockCmdOut : CommandInputPort;
        port manipulatorCmdOut : CommandInputPort;
        port bondingCmdOut : CommandInputPort;
        port scannerCmdOut : CommandInputPort;
        port feedstockStatusIn : StatusOutputPort;
        port manipulatorStatusIn : StatusOutputPort;
        port bondingStatusIn : StatusOutputPort;
        port scannerStatusIn : StatusOutputPort;
        port bondResultIn : BondResultInputPort;
        port scanResultIn : ScanResultInputPort;
        port ejectionOut : ProductOutputPort;

        attribute currentBlueprint : MolecularBlueprint;
        attribute currentStep : Integer := 0;
        attribute totalSteps : Integer := 0;
        attribute errorCount : Integer := 0;
        attribute maxErrors : Integer := 10;
        attribute state : SystemState := SystemState::Idle;
        attribute progress : ProgressPercent := 0.0;
        attribute atomsPlaced : Integer := 0;
        attribute atomsBonded : Integer := 0;
        attribute lastVerification : VerificationResult;
        attribute qualityReport : QualityReport;

        state controllerBehavior {
            entry; then Idle;

            state Idle;
            state Initialized;
            state ReadingBlueprint;
            state FetchingAtom;
            state PlacingAtom;
            state Bonding;
            state Verifying;
            state Correcting;
            state ErrorRecovery;
            state Aborted;
            state Completed;
            state Ejecting;

            transition Idle to Initialized when operator.command.type == CommandType::Initialize;
            transition Initialized to ReadingBlueprint when operator.blueprint is received;
            transition ReadingBlueprint to FetchingAtom when totalSteps > 0;
            transition FetchingAtom to PlacingAtom when feedstockStatusIn.status.state == SystemState::Running;
            transition PlacingAtom to Bonding when manipulatorStatusIn.status.state == SystemState::Running;
            transition Bonding to Verifying when bondingStatusIn.status.state == SystemState::Running;
            transition Verifying to Correcting when scanResultIn.result.status != VerificationStatus::Pass and errorCount < maxErrors;
            transition Verifying to FetchingAtom when scanResultIn.result.status == VerificationStatus::Pass and currentStep < totalSteps;
            transition Correcting to FetchingAtom when correctionComplete();
            transition Verifying to ErrorRecovery when errorCount >= maxErrors;
            transition ErrorRecovery to Aborted when recoveryFailed();
            transition Verifying to Completed when scanResultIn.result.status == VerificationStatus::Pass and currentStep >= totalSteps;
            transition Completed to Ejecting when qualityReport.finalScanComplete == true;
            transition Ejecting to Idle when ejectionOut.product is sent;
            transition any to Aborted when operator.command.type == CommandType::Abort;
            transition Aborted to Idle when operator.command.type == CommandType::Initialize;
        }

        private action correctionComplete : Boolean {
            return true;
        }

        private action recoveryFailed : Boolean {
            return true;
        }

        action readBlueprint {
            in blueprint : MolecularBlueprint;
            out placements : AtomPlacement[0..*];
            out bonds : BondSpec[0..*];
            out totalSteps : Integer;
        }

        action issueCommand {
            in type : CommandType;
            in step : Integer;
            in element : ElementTypes;
            in targetPosition : LengthNm[3];
            in bondType : BondType;
            in bondEnergy : EnergyEV;
            out cmd : Command;
        }

        action trackProgress {
            in step : Integer;
            in total : Integer;
            out progress : ProgressPercent;
        }

        action handleError {
            in result : VerificationResult;
            out action : CommandType;
        }

        action generateQualityReport {
            in totalDefects : Integer;
            in totalAtoms : Integer;
            out report : QualityReport;
        }

        action ejectProduct {
            in blueprint : MolecularBlueprint;
            in quality : QualityReport;
            in atomCount : Integer;
            in bondCount : Integer;
            out product : MolecularProduct;
        }

        action generateStatus {
            out status : StatusReport;
        }
    }

    part def AtomicManipulator {
        port cmdIn : CommandInputPort;
        port atomIn : ProcessedAtomPort;
        port placementOut : PlacementOutputPort;
        port statusOut : StatusOutputPort;

        attribute currentPosition : LengthNm[3] := [0.0, 0.0, 0.0];
        attribute accuracy : LengthNm := 0.05;
        attribute maxRange : LengthNm := 1000.0;
        attribute moveSpeed : LengthNm := 100.0;
        attribute selectedAtom : Atom;
        attribute placedAtom : Atom;
        attribute isCalibrated : Boolean := true;

        state manipulatorBehavior {
            entry; then Ready;

            state Ready;
            state Selecting;
            state Moving;
            state Placing;
            state Returning;
            state ErrorState;

            transition Ready to Selecting when cmdIn.cmd.type == CommandType::Fetch;
            transition Selecting to Moving when atomIn.atom is received;
            transition Moving to Placing when currentPosition == cmdIn.cmd.targetPosition;
            transition Placing to Returning when placementOut.placedAtom is sent;
            transition Returning to Ready when currentPosition == [0.0, 0.0, 0.0];
            transition any to ErrorState when cmdIn.cmd.type == CommandType::Abort;
            transition ErrorState to Ready when cmdIn.cmd.type == CommandType::Initialize;
        }

        action selectAtom {
            in element : ElementTypes;
            in available : Atom;
            out selected : Atom;
        }

        action moveAtom {
            in atom : Atom;
            in target : LengthNm[3];
            in speed : LengthNm;
            out placed : Atom;
        }

        action calibratePosition {
            out position : LengthNm[3];
            out calibrated : Boolean;
        }

        action generateStatus {
            out status : StatusReport;
        }
    }

    part def BondingUnit {
        port cmdIn : CommandInputPort;
        port placementIn : PlacementInputPort;
        port resultOut : BondResultOutputPort;
        port statusOut : StatusOutputPort;

        attribute energyOutput : EnergyEV := 0.0;
        attribute maxEnergy : EnergyEV := 100.0;
        attribute energyPrecision : EnergyEV := 0.01;
        attribute operatingTemperature : TemperatureK := 300.0;
        attribute coolingTemperature : TemperatureK := 300.0;
        attribute lastBond : BondSpec;
        attribute lastResult : VerificationResult;

        state bondingBehavior {
            entry; then Standby;

            state Standby;
            state Charging;
            state Activating;
            state Bonding;
            state Cooling;
            state VerifyingBond;
            state ErrorState;

            transition Standby to Charging when cmdIn.cmd.type == CommandType::Bond;
            transition Charging to Activating when energyOutput >= cmdIn.cmd.bondEnergy;
            transition Activating to Bonding when placementIn.placedAtom is received;
            transition Bonding to Cooling when resultOut.result.status == VerificationStatus::Pass;
            transition Bonding to ErrorState when resultOut.result.status == VerificationStatus::BondFailure;
            transition Cooling to VerifyingBond when operatingTemperature <= coolingTemperature;
            transition VerifyingBond to Standby when resultOut.result is sent;
            transition any to ErrorState when cmdIn.cmd.type == CommandType::Abort;
            transition ErrorState to Standby when cmdIn.cmd.type == CommandType::Initialize;
        }

        action createBond {
            in atomA : Atom;
            in atomB : Atom;
            in bondType : BondType;
            in energy : EnergyEV;
            out result : VerificationResult;
        }

        action calibrateEnergy {
            in target : EnergyEV;
            out actual : EnergyEV;
        }

        action coolDown {
            in fromTemp : TemperatureK;
            in toTemp : TemperatureK;
            out finalTemp : TemperatureK;
        }

        action generateStatus {
            out status : StatusReport;
        }
    }

    part def VerificationScanner {
        port cmdIn : CommandInputPort;
        port resultOut : ScanResultOutputPort;
        port statusOut : StatusOutputPort;

        attribute resolution : LengthNm := 0.01;
        attribute scanRate : ScanRate := 1000;
        attribute currentBlueprint : MolecularBlueprint;
        attribute lastResult : VerificationResult;
        attribute defectHistory : VerificationResult[0..*];
        attribute totalDefects : Integer := 0;
        attribute isFinalScan : Boolean := false;

        state scannerBehavior {
            entry; then Idle;

            state Idle;
            state Scanning;
            state Comparing;
            state Reporting;
            state FinalScan;
            state ErrorState;

            transition Idle to Scanning when cmdIn.cmd.type == CommandType::Scan;
            transition Scanning to Comparing when scanComplete();
            transition Comparing to Reporting when comparisonDone();
            transition Reporting to Idle when resultOut.result is sent;
            transition Idle to FinalScan when cmdIn.cmd.type == CommandType::Eject;
            transition FinalScan to Idle when finalReportSent();
            transition any to ErrorState when cmdIn.cmd.type == CommandType::Abort;
            transition ErrorState to Idle when cmdIn.cmd.type == CommandType::Initialize;
        }

        private action scanComplete : Boolean { return true; }
        private action comparisonDone : Boolean { return true; }
        private action finalReportSent : Boolean { return true; }

        action scanStructure {
            in region : LengthNm[3];
            in resolution : LengthNm;
            out scanData : String;
        }

        action compareWithBlueprint {
            in scanData : String;
            in blueprint : MolecularBlueprint;
            in step : Integer;
            out result : VerificationResult;
        }

        action generateQualityReport {
            in defectHistory : VerificationResult[0..*];
            in totalAtoms : Integer;
            out report : QualityReport;
        }

        action generateStatus {
            out status : StatusReport;
        }
    }

    part def MolecularAssembler {
        port operatorInterface : OperatorPort;
        port feedstockIntake : RawFeedstockPort;
        port productOutput : ProductOutputPort;

        part feedstockProcessor : FeedstockProcessor {
            port rawIn : RawFeedstockPort;
            port atomOut : ProcessedAtomPort;
            port cmdIn : CommandInputPort;
            port statusOut : StatusOutputPort;
        }

        part assemblyController : AssemblyController {
            port operator : OperatorPort;
            port feedstockCmdOut : CommandInputPort;
            port manipulatorCmdOut : CommandInputPort;
            port bondingCmdOut : CommandInputPort;
            port scannerCmdOut : CommandInputPort;
            port feedstockStatusIn : StatusOutputPort;
            port manipulatorStatusIn : StatusOutputPort;
            port bondingStatusIn : StatusOutputPort;
            port scannerStatusIn : StatusOutputPort;
            port bondResultIn : BondResultInputPort;
            port scanResultIn : ScanResultInputPort;
            port ejectionOut : ProductOutputPort;
        }

        part atomicManipulator : AtomicManipulator {
            port cmdIn : CommandInputPort;
            port atomIn : ProcessedAtomPort;
            port placementOut : PlacementOutputPort;
            port statusOut : StatusOutputPort;
        }

        part bondingUnit : BondingUnit {
            port cmdIn : CommandInputPort;
            port placementIn : PlacementInputPort;
            port resultOut : BondResultOutputPort;
            port statusOut : StatusOutputPort;
        }

        part verificationScanner : VerificationScanner {
            port cmdIn : CommandInputPort;
            port resultOut : ScanResultOutputPort;
            port statusOut : StatusOutputPort;
        }

        connection operatorToController
            connect operatorInterface to assemblyController.operator;

        connection feedstockIntakeToProcessor
            connect feedstockIntake to feedstockProcessor.rawIn;

        connection controllerFeedstockCmd
            connect assemblyController.feedstockCmdOut to feedstockProcessor.cmdIn;

        connection feedstockStatusToController
            connect feedstockProcessor.statusOut to assemblyController.feedstockStatusIn;

        flow of Atom
            from feedstockProcessor.atomOut
            to atomicManipulator.atomIn;

        connection controllerManipulatorCmd
            connect assemblyController.manipulatorCmdOut to atomicManipulator.cmdIn;

        connection manipulatorStatusToController
            connect atomicManipulator.statusOut to assemblyController.manipulatorStatusIn;

        flow of Atom
            from atomicManipulator.placementOut
            to bondingUnit.placementIn;

        connection controllerBondingCmd
            connect assemblyController.bondingCmdOut to bondingUnit.cmdIn;

        connection bondingStatusToController
            connect bondingUnit.statusOut to assemblyController.bondingStatusIn;

        flow of VerificationResult
            from bondingUnit.resultOut
            to assemblyController.bondResultIn;

        connection controllerScannerCmd
            connect assemblyController.scannerCmdOut to verificationScanner.cmdIn;

        connection scannerStatusToController
            connect verificationScanner.statusOut to assemblyController.scannerStatusIn;

        flow of VerificationResult
            from verificationScanner.resultOut
            to assemblyController.scanResultIn;

        connection controllerEjection
            connect assemblyController.ejectionOut to productOutput;
    }

    requirement def MolecularAssemblerRequirements {
        subject assembler : MolecularAssembler;

        doc "The MolecularAssembler shall construct complex molecular structures with atomic precision from raw atomic feedstock and a digital blueprint."

        requirement def AtomicPrecisionRequirement {
            subject manipulator : AtomicManipulator;
            doc "The AtomicManipulator shall place atoms at target positions with sub-nanometer accuracy."
            attribute maxPlacementError : LengthNm = 0.1;
            constraint { manipulator.accuracy <= maxPlacementError }
        }

        requirement def FeedstockPurityRequirement {
            subject processor : FeedstockProcessor;
            doc "The FeedstockProcessor shall sort and purify raw feedstock to at least 99.99 percent purity before dispensing."
            attribute minPurity : Probability = 0.9999;
            constraint { processor.purityThreshold >= minPurity }
        }

        requirement def BondingEnergyPrecisionRequirement {
            subject bonding : BondingUnit;
            doc "The BondingUnit shall deliver bond energy with precision better than 0.05 eV."
            attribute maxEnergyDeviation : EnergyEV = 0.05;
            constraint { bonding.energyPrecision <= maxEnergyDeviation }
        }

        requirement def VerificationResolutionRequirement {
            subject scanner : VerificationScanner;
            doc "The VerificationScanner shall achieve spatial resolution sufficient to detect individual atom placement errors."
            attribute maxResolution : LengthNm = 0.05;
            constraint { scanner.resolution <= maxResolution }
        }

        requirement def ErrorHandlingRequirement {
            subject controller : AssemblyController;
            doc "The AssemblyController shall abort the assembly process when accumulated errors exceed the maximum allowable count."
            attribute maxAllowedErrors : Integer = 10;
            constraint { controller.maxErrors <= maxAllowedErrors }
        }

        requirement def ThroughputRequirement {
            subject assembler : MolecularAssembler;
            doc "The MolecularAssembler shall support assembly of molecules containing up to 10000 atoms."
            attribute maxSupportedAtoms : Integer = 10000;
            constraint { assembler.feedstockProcessor.capacity >= maxSupportedAtoms }
        }

        requirement def CoordinationRequirement {
            subject controller : AssemblyController;
            doc "The AssemblyController shall coordinate fetch, place, bond, and verify operations for each atom in the blueprint sequence."
            constraint { controller.currentStep >= 0 and controller.currentStep <= controller.totalSteps }
        }

        requirement def FinalVerificationRequirement {
            subject assembler : MolecularAssembler;
            doc "The MolecularAssembler shall perform a final quality verification scan before ejecting the completed product."
            constraint { assembler.productOutput.product.quality.finalScanComplete == true }
        }

        requirement def ProductEjectionRequirement {
            subject assembler : MolecularAssembler;
            doc "The MolecularAssembler shall eject the completed molecular product only after final verification passes."
            constraint { assembler.productOutput.product.quality.overallStatus == VerificationStatus::Pass }
        }

        requirement def OperatorInterfaceRequirement {
            subject controller : AssemblyController;
            doc "The AssemblyController shall provide an operator interface for blueprint upload, process start, status monitoring, and abort."
            constraint { controller.operator.isPortConnected() }
        }
    }

    part molecularAssemblerInstance : MolecularAssembler;

    satisfy atomicPrecisionSatisfaction
        by molecularAssemblerInstance.atomicManipulator
        satisfies MolecularAssemblerRequirements::AtomicPrecisionRequirement;

    satisfy feedstockPuritySatisfaction
        by molecularAssemblerInstance.feedstockProcessor
        satisfies MolecularAssemblerRequirements::FeedstockPurityRequirement;

    satisfy bondingPrecisionSatisfaction
        by molecularAssemblerInstance.bondingUnit
        satisfies MolecularAssemblerRequirements::BondingEnergyPrecisionRequirement;

    satisfy verificationResolutionSatisfaction
        by molecularAssemblerInstance.verificationScanner
        satisfies MolecularAssemblerRequirements::VerificationResolutionRequirement;

    satisfy errorHandlingSatisfaction
        by molecularAssemblerInstance.assemblyController
        satisfies MolecularAssemblerRequirements::ErrorHandlingRequirement;

    satisfy throughputSatisfaction
        by molecularAssemblerInstance
        satisfies MolecularAssemblerRequirements::ThroughputRequirement;

    satisfy coordinationSatisfaction
        by molecularAssemblerInstance.assemblyController
        satisfies MolecularAssemblerRequirements::CoordinationRequirement;

    satisfy finalVerificationSatisfaction
        by molecularAssemblerInstance
        satisfies MolecularAssemblerRequirements::FinalVerificationRequirement;

    satisfy productEjectionSatisfaction
        by molecularAssemblerInstance
        satisfies MolecularAssemblerRequirements::ProductEjectionRequirement;

    satisfy operatorInterfaceSatisfaction
        by molecularAssemblerInstance.assemblyController
        satisfies MolecularAssemblerRequirements::OperatorInterfaceRequirement;
}
