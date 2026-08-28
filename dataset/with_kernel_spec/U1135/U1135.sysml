package MolecularAssemblerModel {

    private import ScalarValues::*;
    private import SI::*;

    package Definitions {

        attribute def Coordinate :> Real;
        attribute def EnergyValue :> Real;
        attribute def AccuracyValue :> Real;
        attribute def TemperatureValue :> Real;
        attribute def ProgressValue :> Real;
        attribute def ErrorCount :> Integer;

        item def Atom {
            attribute elementSymbol : String;
            attribute atomicNumber : Integer;
        }

        item def RawFeedstock {
            attribute atoms : Atom[0..*];
        }

        item def ProcessedFeedstock {
            attribute sortedAtoms : Atom[0..*];
            attribute purity : Real;
        }

        item def AssemblyStep {
            attribute stepId : Integer;
            attribute targetAtom : Atom;
            attribute targetPosition : Coordinate;
            attribute bondEnergy : EnergyValue;
        }

        item def MolecularBlueprint {
            attribute moleculeName : String;
            attribute targetAtomCount : Integer;
            attribute steps : AssemblyStep[0..*];
        }

        item def AssembledMolecule {
            attribute name : String;
            attribute atomCount : Integer;
            attribute qualityScore : Real;
        }

        item def QualityReport {
            attribute stepId : Integer;
            attribute defectDetected : Boolean;
            attribute defectDescription : String;
            attribute overallQuality : Real;
        }

        item def PlacementCommand {
            attribute stepId : Integer;
            attribute atom : Atom;
            attribute position : Coordinate;
        }

        item def BondingCommand {
            attribute stepId : Integer;
            attribute bondEnergy : EnergyValue;
        }

        item def ScanCommand {
            attribute stepId : Integer;
        }

        item def OperatorCommand {
            attribute commandType : String;
            attribute blueprint : MolecularBlueprint;
        }

        item def StatusReport {
            attribute currentStep : Integer;
            attribute totalSteps : Integer;
            attribute progress : ProgressValue;
            attribute errorCount : ErrorCount;
            attribute phase : String;
        }

        part def FeedstockProcessor;
        part def AssemblyController;
        part def AtomicManipulator;
        part def BondingUnit;
        part def VerificationScanner;
        part def Operator;
        part def MolecularAssembler;

        port def RawFeedstockPort {
            in rawFeedstock : RawFeedstock;
        }

        port def ProcessedFeedstockPort {
            out processedFeedstock : ProcessedFeedstock;
        }

        port def FeedstockRequestPort {
            in requestAtom : Atom;
            out suppliedAtom : Atom;
        }

        port def BlueprintPort {
            in operatorCommand : OperatorCommand;
            out statusReport : StatusReport;
        }

        port def PlacementCommandPort {
            out placementCommand : PlacementCommand;
        }

        port def PlacementResultPort {
            in placementResult : Boolean;
        }

        port def BondingCommandPort {
            out bondingCommand : BondingCommand;
        }

        port def BondingResultPort {
            in bondingResult : Boolean;
        }

        port def ScanCommandPort {
            out scanCommand : ScanCommand;
        }

        port def QualityReportPort {
            in qualityReport : QualityReport;
        }

        port def ProductEjectionPort {
            out assembledMolecule : AssembledMolecule;
        }
    }

    package Usages {

        part molecularAssembler : Definitions::MolecularAssembler {

            port blueprintPort : Definitions::BlueprintPort;
            port productEjectionPort : Definitions::ProductEjectionPort;
            port rawFeedstockPort : Definitions::RawFeedstockPort;

            part feedstockProcessor : Definitions::FeedstockProcessor {
                port rawFeedstockInPort : Definitions::RawFeedstockPort;
                port processedFeedstockOutPort : Definitions::ProcessedFeedstockPort;
                port feedstockRequestPort : Definitions::FeedstockRequestPort;

                attribute processedFeedstock : Definitions::ProcessedFeedstock;
                attribute temperature : Definitions::TemperatureValue = 300;

                perform action feedstockProcessingBehavior {
                    action receiveRawFeedstock accept Definitions::RawFeedstock via rawFeedstockInPort;
                    then action sortAtoms {
                        in raw : Definitions::RawFeedstock;
                        out sorted : Definitions::ProcessedFeedstock;
                    }
                    then action purifyAtoms {
                        in sorted : Definitions::ProcessedFeedstock;
                        out purified : Definitions::ProcessedFeedstock;
                    }
                    then action storeProcessedFeedstock {
                        in purified : Definitions::ProcessedFeedstock;
                        out stored : Definitions::ProcessedFeedstock;
                    }
                }

                state def FeedstockProcessorState {
                    entry; then Idle;
                    state Idle;
                    state Processing;
                    state Ready;
                    transition first Idle accept rawFeedstock : Definitions::RawFeedstock via rawFeedstockInPort then Processing;
                    transition first Processing do action sortAndPurify then Ready;
                    transition first Ready accept requestAtom : Definitions::Atom via feedstockRequestPort do action supplyRequestedAtom then Ready;
                }
                perform FeedstockProcessorState;
            }

            part assemblyController : Definitions::AssemblyController {
                port blueprintPort : Definitions::BlueprintPort;
                port placementCommandPort : Definitions::PlacementCommandPort;
                port placementResultPort : Definitions::PlacementResultPort;
                port bondingCommandPort : Definitions::BondingCommandPort;
                port bondingResultPort : Definitions::BondingResultPort;
                port scanCommandPort : Definitions::ScanCommandPort;
                port qualityReportPort : Definitions::QualityReportPort;
                port feedstockRequestPort : Definitions::FeedstockRequestPort;

                attribute currentBlueprint : Definitions::MolecularBlueprint;
                attribute currentStepIndex : Integer = 0;
                attribute errorCount : Definitions::ErrorCount = 0;
                attribute maxErrors : Definitions::ErrorCount = 5;
                attribute assemblyComplete : Boolean = false;

                perform action controllerBehavior {
                    action receiveOperatorCommand accept Definitions::OperatorCommand via blueprintPort;
                    then action readBlueprint {
                        in cmd : Definitions::OperatorCommand;
                        out blueprint : Definitions::MolecularBlueprint;
                    }
                    then action initializeAssembly;
                    then action assembleLoop {
                        iter {
                            action getNextStep {
                                in blueprint : Definitions::MolecularBlueprint;
                                out step : Definitions::AssemblyStep;
                            }
                            then action sendPlacementCommand {
                                in step : Definitions::AssemblyStep;
                                out cmd : Definitions::PlacementCommand;
                            }
                            then action receivePlacementResult accept Boolean via placementResultPort;
                            then action sendBondingCommand {
                                in step : Definitions::AssemblyStep;
                                out cmd : Definitions::BondingCommand;
                            }
                            then action receiveBondingResult accept Boolean via bondingResultPort;
                            then action sendScanCommand {
                                in step : Definitions::AssemblyStep;
                                out cmd : Definitions::ScanCommand;
                            }
                            then action receiveQualityReport accept Definitions::QualityReport via qualityReportPort;
                            then action evaluateQuality {
                                in report : Definitions::QualityReport;
                                out continue : Boolean;
                            }
                        }
                    }
                    then action finalVerification {
                        out scanCmd : Definitions::ScanCommand;
                    }
                    then action ejectProduct {
                        out molecule : Definitions::AssembledMolecule;
                    }
                }

                state def ControllerStateMachine {
                    entry; then Standby;
                    state Standby;
                    state Initializing;
                    state Assembling;
                    state FinalVerification;
                    state Complete;
                    state Aborted;

                    transition first Standby accept cmd : Definitions::OperatorCommand via blueprintPort do action loadBlueprint then Initializing;
                    transition first Initializing do action prepareAssembly then Assembling;

                    state Assembling {
                        state FetchingAtom;
                        state PlacingAtom;
                        state Bonding;
                        state Verifying;
                        transition first FetchingAtom then PlacingAtom;
                        transition first PlacingAtom then Bonding;
                        transition first Bonding then Verifying;
                        transition
                            first Verifying
                            accept report : Definitions::QualityReport via qualityReportPort
                            if not report.defectDetected
                            then FetchingAtom;
                        transition
                            first Verifying
                            accept report : Definitions::QualityReport via qualityReportPort
                            if report.defectDetected and errorCount < maxErrors
                            do action attemptCorrection
                            then FetchingAtom;
                        transition
                            first Verifying
                            accept report : Definitions::QualityReport via qualityReportPort
                            if report.defectDetected and errorCount >= maxErrors
                            then Aborted;
                        transition
                            first FetchingAtom
                            if currentStepIndex >= currentBlueprint.targetAtomCount
                            then FinalVerification;
                    }

                    transition first FinalVerification do action performFinalScan then Complete;
                    transition first Complete do action ejectMolecule then done;
                    transition first Aborted do action reportAbort then done;
                    transition first Complete accept cmd : Definitions::OperatorCommand via blueprintPort if cmd.commandType == "reset" then Standby;
                    transition first Aborted accept cmd : Definitions::OperatorCommand via blueprintPort if cmd.commandType == "reset" then Standby;
                }
                perform ControllerStateMachine;
            }

            part atomicManipulator : Definitions::AtomicManipulator {
                port placementCommandPort : Definitions::PlacementCommandPort;
                port placementResultPort : Definitions::PlacementResultPort;
                port feedstockRequestPort : Definitions::FeedstockRequestPort;

                attribute currentPosition : Definitions::Coordinate;
                attribute placementAccuracy : Definitions::AccuracyValue = 0.05;

                perform action manipulatorBehavior {
                    action receivePlacementCommand accept Definitions::PlacementCommand via placementCommandPort;
                    then action requestAtom {
                        in atomType : Definitions::Atom;
                        out request : Definitions::Atom;
                    }
                    then action receiveAtom accept Definitions::Atom via feedstockRequestPort;
                    then action moveToFeedstock;
                    then action pickAtom;
                    then action moveToTargetPosition {
                        in position : Definitions::Coordinate;
                    }
                    then action placeAtom;
                    then action sendPlacementResult send new Boolean(true) to assemblyController;
                }

                state def ManipulatorState {
                    entry; then Idle;
                    state Idle;
                    state Fetching;
                    state Moving;
                    state Placing;
                    transition first Idle accept cmd : Definitions::PlacementCommand via placementCommandPort then Fetching;
                    transition first Fetching do action fetchAtomFromFeedstock then Moving;
                    transition first Moving do action moveToTarget then Placing;
                    transition first Placing do action placeAtomAtTarget then Idle;
                }
                perform ManipulatorState;
            }

            part bondingUnit : Definitions::BondingUnit {
                port bondingCommandPort : Definitions::BondingCommandPort;
                port bondingResultPort : Definitions::BondingResultPort;

                attribute bondEnergy : Definitions::EnergyValue;
                attribute temperature : Definitions::TemperatureValue = 350;

                perform action bondingBehavior {
                    action receiveBondingCommand accept Definitions::BondingCommand via bondingCommandPort;
                    then action activateEnergySource {
                        in energy : Definitions::EnergyValue;
                    }
                    then action applyEnergyToBond {
                        in energy : Definitions::EnergyValue;
                    }
                    then action verifyBondFormation;
                    then action sendBondingResult send new Boolean(true) to assemblyController;
                }

                state def BondingState {
                    entry; then Idle;
                    state Idle;
                    state Activating;
                    state Bonding;
                    state Verifying;
                    transition first Idle accept cmd : Definitions::BondingCommand via bondingCommandPort then Activating;
                    transition first Activating do action activateEnergySource then Bonding;
                    transition first Bonding do action applyEnergy then Verifying;
                    transition first Verifying do action checkBond then Idle;
                }
                perform BondingState;
            }

            part verificationScanner : Definitions::VerificationScanner {
                port scanCommandPort : Definitions::ScanCommandPort;
                port qualityReportPort : Definitions::QualityReportPort;

                attribute scanResolution : Definitions::AccuracyValue = 0.01;
                attribute currentReport : Definitions::QualityReport;

                perform action scannerBehavior {
                    action receiveScanCommand accept Definitions::ScanCommand via scanCommandPort;
                    then action scanMolecule {
                        in stepId : Integer;
                    }
                    then action compareWithBlueprint {
                        in blueprint : Definitions::MolecularBlueprint;
                        out report : Definitions::QualityReport;
                    }
                    then action generateQualityReport {
                        in report : Definitions::QualityReport;
                    }
                    then action sendQualityReport send new Definitions::QualityReport() to assemblyController;
                }

                state def ScannerState {
                    entry; then Idle;
                    state Idle;
                    state Scanning;
                    state Comparing;
                    state Reporting;
                    transition first Idle accept cmd : Definitions::ScanCommand via scanCommandPort then Scanning;
                    transition first Scanning do action performScan then Comparing;
                    transition first Comparing do action compareScanToBlueprint then Reporting;
                    transition first Reporting do action sendReport then Idle;
                }
                perform ScannerState;
            }

            flow processedFeedstockFlow of Definitions::ProcessedFeedstock
                from feedstockProcessor.processedFeedstockOutPort.processedFeedstock
                to atomicManipulator.feedstockRequestPort;

            flow placementCommandFlow of Definitions::PlacementCommand
                from assemblyController.placementCommandPort.placementCommand
                to atomicManipulator.placementCommandPort.placementCommand;

            flow placementResultFlow of Boolean
                from atomicManipulator.placementResultPort.placementResult
                to assemblyController.placementResultPort.placementResult;

            flow bondingCommandFlow of Definitions::BondingCommand
                from assemblyController.bondingCommandPort.bondingCommand
                to bondingUnit.bondingCommandPort.bondingCommand;

            flow bondingResultFlow of Boolean
                from bondingUnit.bondingResultPort.bondingResult
                to assemblyController.bondingResultPort.bondingResult;

            flow scanCommandFlow of Definitions::ScanCommand
                from assemblyController.scanCommandPort.scanCommand
                to verificationScanner.scanCommandPort.scanCommand;

            flow qualityReportFlow of Definitions::QualityReport
                from verificationScanner.qualityReportPort.qualityReport
                to assemblyController.qualityReportPort.qualityReport;

            flow atomRequestFlow of Definitions::Atom
                from assemblyController.feedstockRequestPort.requestAtom
                to feedstockProcessor.feedstockRequestPort.requestAtom;

            flow atomSupplyFlow of Definitions::Atom
                from feedstockProcessor.feedstockRequestPort.suppliedAtom
                to assemblyController.feedstockRequestPort.suppliedAtom;

            flow operatorCommandFlow of Definitions::OperatorCommand
                from blueprintPort.operatorCommand
                to assemblyController.blueprintPort.operatorCommand;

            flow statusReportFlow of Definitions::StatusReport
                from assemblyController.blueprintPort.statusReport
                to blueprintPort.statusReport;

            flow rawFeedstockFlow of Definitions::RawFeedstock
                from rawFeedstockPort.rawFeedstock
                to feedstockProcessor.rawFeedstockInPort.rawFeedstock;

            flow productEjectionFlow of Definitions::AssembledMolecule
                from assemblyController to productEjectionPort.assembledMolecule;
        }

        part operator : Definitions::Operator {
            port blueprintPort : Definitions::BlueprintPort;

            perform action operatorBehavior {
                action loadBlueprint {
                    out cmd : Definitions::OperatorCommand;
                }
                then action startAssembly send new Definitions::OperatorCommand() to molecularAssembler;
                then action monitorStatus accept Definitions::StatusReport via blueprintPort;
            }
        }

        interface operatorInterface connect operator.blueprintPort to molecularAssembler.blueprintPort {
            flow operatorCommandFlow of Definitions::OperatorCommand
                from operator.blueprintPort.operatorCommand
                to molecularAssembler.blueprintPort.operatorCommand;
            flow statusReportFlow of Definitions::StatusReport
                from molecularAssembler.blueprintPort.statusReport
                to operator.blueprintPort.statusReport;
        }

        interface rawFeedstockInterface connect molecularAssembler.rawFeedstockPort to molecularAssembler.feedstockProcessor.rawFeedstockInPort {
            flow rawFeedstockFlow of Definitions::RawFeedstock
                from molecularAssembler.rawFeedstockPort.rawFeedstock
                to molecularAssembler.feedstockProcessor.rawFeedstockInPort.rawFeedstock;
        }
    }

    package Requirements {

        requirement def MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
        }

        requirement AtomicPrecisionAssembly :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The Molecular Assembler shall construct molecular structures
                 with atomic precision, placing each atom at its target position
                 with sub-nanometer accuracy. */
            constraint { assembler.atomicManipulator.placementAccuracy <= 0.1 }
        }

        requirement FeedstockProcessing :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The Feedstock Processor shall sort and purify raw atomic feedstock
                 to ensure correct atom types are available for assembly. */
            constraint { assembler.feedstockProcessor.processedFeedstock.purity >= 0.99 }
        }

        requirement BlueprintCoordination :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The Assembly Controller shall read the digital molecular blueprint
                 and coordinate all components to assemble the target molecule
                 atom by atom. */
            constraint { assembler.assemblyController.currentBlueprint.targetAtomCount > 0 }
        }

        requirement BondFormation :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The Bonding Unit shall create stable chemical bonds between
                 newly placed atoms and the existing structure using a precise
                 amount of energy. */
            constraint { assembler.bondingUnit.bondEnergy > 0 }
        }

        requirement QualityVerification :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The Verification Scanner shall continuously monitor the molecule
                 during assembly and detect defects including misplaced atoms
                 and failed bonds. */
            constraint { assembler.verificationScanner.scanResolution <= 0.05 }
        }

        requirement ErrorHandling :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The system shall attempt to correct detected errors and shall
                 abort the assembly process if the error count exceeds the
                 maximum threshold. */
            constraint { assembler.assemblyController.maxErrors == 5 }
        }

        requirement ProductEjection :> MolecularAssemblerRequirement {
            subject assembler : Definitions::MolecularAssembler;
            doc /* The system shall eject the completed molecular product only
                 after the entire structure is built and passes final quality
                 verification. */
            constraint { assembler.assemblyController.assemblyComplete == true }
        }
    }
}
