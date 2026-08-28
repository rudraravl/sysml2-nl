package 'Molecular Assembly System' {
    private import ScalarValues::*;
    private import SI::m;
    private import SI::s;
    private import SI::J;
    private import SI::K;
    private import SI::Pa;

    package Definitions {
        attribute def Length :> ScalarValues::Real;
        attribute def Energy :> ScalarValues::Real;
        attribute def Duration :> ScalarValues::Real;
        attribute def Temperature :> ScalarValues::Real;
        attribute def Pressure :> ScalarValues::Real;

        attribute def StartSignal;
        attribute def StopSignal;
        attribute def InitCompleteSignal;
        attribute def ScanCompleteSignal;
        attribute def AtomPickedSignal;
        attribute def AtomPositionedSignal;
        attribute def BondCompleteSignal;
        attribute def MoleculeVerifiedSignal;
        attribute def MoleculeCompleteSignal;
        attribute def MoleculeTransportedSignal;

        attribute def AssemblyCommand {
            attribute designId: String;
            attribute priority: Integer;
        }
        attribute def MoleculeDesign {
            attribute designId: String;
            attribute targetAtomCount: Integer;
            attribute targetBondCount: Integer;
            attribute assemblySequence: String;
        }

        item def Atom {
            attribute elementSymbol: String;
            attribute atomicNumber: Integer;
            attribute valence: Integer;
        }
        item def Molecule {
            attribute designId: String;
            attribute atomCount: Integer;
            attribute bondCount: Integer;
            attribute structureValidated: Boolean;
        }
        item def DiagnosticReport {
            attribute moleculeId: String;
            attribute success: Boolean;
            attribute assemblyTime: Duration;
            attribute energyConsumed: Energy;
            attribute atomsPlaced: Integer;
            attribute bondsFormed: Integer;
        }

        port def AtomFlowPort {
            in atom: Atom;
        }
        port def MoleculeFlowPort {
            in molecule: Molecule;
        }
        port def CommandPort {
            in command: AssemblyCommand;
        }
        port def DiagnosticOutPort {
            out report: DiagnosticReport;
        }
        port def DesignOutPort {
            out design: MoleculeDesign;
        }

        action def ScanArea {
            in scanRequest: Boolean;
            out surfaceMap: String;
            out energyUsed: Energy;
        }
        action def PickAtom {
            in feedstockAtom: Atom;
            in surfaceMap: String;
            out pickedAtom: Atom;
            out energyUsed: Energy;
        }
        action def PositionAtom {
            in atom: Atom;
            in surfaceMap: String;
            in targetCoordinates: String;
            out positionedAtom: Atom;
            out energyUsed: Energy;
        }
        action def BondAtom {
            in atom: Atom;
            in quantumState: String;
            out bondFormed: Boolean;
            out energyUsed: Energy;
        }
        action def VerifyMolecule {
            in molecule: Molecule;
            in design: MoleculeDesign;
            out verified: Boolean;
            out energyUsed: Energy;
        }
        action def TransportToCollector {
            in molecule: Molecule;
            out delivered: Boolean;
            out energyUsed: Energy;
        }
        action def GenerateReport {
            in moleculeId: String;
            in success: Boolean;
            in assemblyTime: Duration;
            in energyConsumed: Energy;
            out report: DiagnosticReport;
        }
        action def AssembleMolecule {
            in command: AssemblyCommand;
            in design: MoleculeDesign;
            in feedstockAtom: Atom;
            out molecule: Molecule;
            out report: DiagnosticReport;
        }

        state def MolecularAssemblyStates {
            entry; then idle;
            state idle;
            accept StartSignal then initializing;
            state initializing;
            accept InitCompleteSignal then scanning;
            state scanning;
            accept ScanCompleteSignal then picking;
            state picking;
            accept AtomPickedSignal then positioning;
            state positioning;
            accept AtomPositionedSignal then bonding;
            state bonding;
            accept BondCompleteSignal then checkCompletion;
            state checkCompletion;
            accept MoleculeCompleteSignal then verifying;
            accept AtomPickedSignal then scanning;
            state verifying;
            accept MoleculeVerifiedSignal then transporting;
            state transporting;
            accept MoleculeTransportedSignal then reporting;
            state reporting;
            accept StopSignal then idle;
        }

        part def VacuumChamber {
            attribute pressure: Pressure;
            attribute temperature: Temperature;
        }
        part def AssemblyProcessor {
            port commandIn: CommandPort;
            port designOut: DesignOutPort;
            port moleculeOut: MoleculeFlowPort;
            port diagOut: DiagnosticOutPort;
            attribute currentDesign: MoleculeDesign;
        }
        part def MolecularManipulator {
            attribute precision: Length;
            attribute maxRange: Length;
            port atomIn: AtomFlowPort;
        }
        part def AtomicForceMicroscope {
            attribute resolution: Length;
            attribute scanRate: Duration;
        }
        part def QuantumController {
            attribute coherenceTime: Duration;
            attribute qubits: Integer;
        }
        part def FeedstockReservoir {
            attribute capacity: Integer;
            attribute remaining: Integer;
            port atomOut: AtomFlowPort;
        }
        part def ProductCollector {
            attribute capacity: Integer;
            attribute stored: Integer;
            port moleculeIn: MoleculeFlowPort;
        }
        part def PowerMonitor {
            attribute totalEnergy: Energy;
            port diagOut: DiagnosticOutPort;
        }
    }

    package Usages {
        private import Definitions::*;

        part 'molecular assembly system' {
            part vacuumChamber: VacuumChamber {
                attribute :>> pressure = 1e-9;
                attribute :>> temperature = 293;
            }
            part assemblyProcessor: AssemblyProcessor;
            part manipulator: MolecularManipulator {
                attribute :>> precision = 1e-10;
                attribute :>> maxRange = 1e-7;
            }
            part afm: AtomicForceMicroscope {
                attribute :>> resolution = 5e-11;
                attribute :>> scanRate = 1e-2;
            }
            part quantumController: QuantumController {
                attribute :>> coherenceTime = 1e-4;
                attribute :>> qubits = 16;
            }
            part feedstock: FeedstockReservoir {
                attribute :>> capacity = 100000;
                attribute :>> remaining = 100000;
            }
            part productCollector: ProductCollector {
                attribute :>> capacity = 10000;
                attribute :>> stored = 0;
            }
            part powerMonitor: PowerMonitor {
                attribute :>> totalEnergy = 1e6;
            }

            connect feedstock.atomOut to manipulator.atomIn;
            connect assemblyProcessor.moleculeOut to productCollector.moleculeIn;

            action 'assemble molecule': AssembleMolecule {
                in command: AssemblyCommand;
                in design: MoleculeDesign;
                in feedstockAtom: Atom;
                out molecule: Molecule;
                out report: DiagnosticReport;

                action 'scan area': ScanArea {
                    in scanRequest = true;
                    out surfaceMap: String;
                    out energyUsed: Energy;
                }
                then 'pick atom';
                flow 'scan area'.surfaceMap to 'pick atom'.surfaceMap;
                flow 'scan area'.surfaceMap to 'position atom'.surfaceMap;

                action 'pick atom': PickAtom {
                    in feedstockAtom = 'assemble molecule'::feedstockAtom;
                    in surfaceMap: String;
                    out pickedAtom: Atom;
                    out energyUsed: Energy;
                }
                then 'position atom';
                flow 'pick atom'.pickedAtom to 'position atom'.atom;

                action 'position atom': PositionAtom {
                    in atom: Atom;
                    in surfaceMap: String;
                    in targetCoordinates: String;
                    out positionedAtom: Atom;
                    out energyUsed: Energy;
                }
                then 'bond atom';
                flow 'position atom'.positionedAtom to 'bond atom'.atom;

                action 'bond atom': BondAtom {
                    in atom: Atom;
                    in quantumState: String;
                    out bondFormed: Boolean;
                    out energyUsed: Energy;
                }
                then 'verify molecule';

                action 'verify molecule': VerifyMolecule {
                    in molecule: Molecule;
                    in design = 'assemble molecule'::design;
                    out verified: Boolean;
                    out energyUsed: Energy;
                }
                then 'transport molecule';
                flow 'verify molecule'.verified to 'generate report'.success;

                action 'transport molecule': TransportToCollector {
                    in molecule: Molecule;
                    out delivered: Boolean;
                    out energyUsed: Energy;
                }
                then 'generate report';
                flow 'transport molecule'.delivered to 'generate report'.success;

                action 'generate report': GenerateReport {
                    in moleculeId: String;
                    in success: Boolean;
                    in assemblyTime: Duration;
                    in energyConsumed: Energy;
                    out report: DiagnosticReport;
                }
                flow 'generate report'.report to 'assemble molecule'.report;
            }

            state 'assembly states': MolecularAssemblyStates;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def VacuumIntegrityReq {
            doc /* The vacuum chamber must maintain ultra-high vacuum conditions to prevent contamination. */;
            attribute maxPressure: Pressure;
        }
        requirement def ManipulatorPrecisionReq {
            doc /* The molecular manipulator must achieve sub-nanometer positioning precision. */;
            attribute requiredPrecision: Length;
        }
        requirement def BondIntegrityReq {
            doc /* Each atom bond must be successfully formed and stable. */;
            attribute bondFormed: Boolean;
        }
        requirement def MoleculeVerificationReq {
            doc /* Each completed molecule must be verified against its design specification. */;
            attribute verified: Boolean;
        }
        requirement def DiagnosticReportingReq {
            doc /* Each assembly task must produce a diagnostic report with success, time, and energy consumed. */;
            attribute reportSuccess: Boolean;
            attribute reportTime: Duration;
            attribute reportEnergy: Energy;
        }
        requirement def AssemblyThroughputReq {
            doc /* The system shall complete a single molecule assembly within a reasonable time frame. */;
            attribute maxAssemblyTime: Duration;
        }
    }
}
