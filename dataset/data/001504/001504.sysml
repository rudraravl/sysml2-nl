package MolecularNanotechnologySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Metaobjects::SemanticMetadata;
    private import ModelingMetadata::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;
    
    package ValueTypes {
        attribute def NanometerValue :> LengthValue {
            attribute :>> num : Real;
            attribute :>> mRef : LengthUnit = SI::nm;
        }
        
        attribute def PiconewtonValue :> ForceValue {
            attribute :>> num : Real;
            attribute :>> mRef : ForceUnit = SI::N;
        }
        
        attribute def FemtosecondValue :> DurationValue {
            attribute :>> num : Real;
            attribute :>> mRef : DurationUnit = SI::s;
        }
        
        attribute def AtomicMassValue :> MassValue {
            attribute :>> num : Real;
            attribute :>> mRef : MassUnit = SI::kg;
        }
        
        attribute def PicowattValue :> PowerValue {
            attribute :>> num : Real;
            attribute :>> mRef : PowerUnit = SI::W;
        }
        
        attribute def Position3D {
            attribute x : NanometerValue;
            attribute y : NanometerValue;
            attribute z : NanometerValue;
        }
        
        attribute def AtomicConfiguration {
            attribute atomType : String;
            attribute bondingState : String;
            attribute position : Position3D;
        }
        
        attribute def MolecularStructure {
            attribute atoms : AtomicConfiguration[1..*];
            attribute totalMass : AtomicMassValue;
            attribute structureId : String;
        }
    }
    
    package ItemTypes {
        private import ValueTypes::*;
        
        item def Atom {
            attribute element : String;
            attribute mass : AtomicMassValue;
            attribute position : Position3D;
            attribute bondedTo : Atom[0..*];
        }
        
        item def Molecule {
            attribute structure : MolecularStructure;
            attribute constituents : Atom[1..*];
            attribute stability : Real;
        }
        
        item def TargetProduct {
            attribute desiredStructure : MolecularStructure;
            attribute tolerances : Real;
            attribute priority : Integer;
        }
        
        item def AssemblyFeedstock {
            attribute availableAtoms : Atom[*];
            attribute purity : Real;
        }
        
        item def AssemblyReport {
            attribute producedMolecule : Molecule;
            attribute assemblyTime : FemtosecondValue;
            attribute energyConsumed : EnergyValue;
            attribute defectCount : Integer;
        }
    }
    
    package Signals {
        attribute def AssemblyCommandData {
            attribute target : ItemTypes::TargetProduct;
        }
        attribute def DisassemblyCommandData;
        attribute def PositionCommandData;
        attribute def ScanCommandData;
        attribute def CalibrationCommandData;
        attribute def EmergencyStopData;
    }
    
    package PortDefinitions {
        private import ValueTypes::*;
        private import ItemTypes::*;
        private import Signals::*;
        
        port def FeedstockPort {
            in feedstock : AssemblyFeedstock;
        }
        
        port def ProductPort {
            out product : Molecule;
        }
        
        port def ControlPort {
            in command : AssemblyCommandData;
            in stop : EmergencyStopData;
        }
        
        port def SensorPort {
            out atomicPosition : Position3D;
            out force : PiconewtonValue;
            out temperature : ThermodynamicTemperatureValue;
        }
        
        port def ManipulatorInterface {
            in targetPosition : Position3D;
            in targetForce : PiconewtonValue;
            out currentPosition : Position3D;
            out appliedForce : PiconewtonValue;
        }
        
        port def EnergyPort {
            in power : PicowattValue;
        }
        
        port def DiagnosticPort {
            out report : AssemblyReport;
            out status : String;
        }
    }
    
    package ComponentDefinitions {
        private import ValueTypes::*;
        private import ItemTypes::*;
        private import PortDefinitions::*;
        
        part def AtomicForceMicroscope {
            doc /* Scans and images atomic-scale surface topology */
            port sensor : SensorPort;
            port energy : EnergyPort;
            
            attribute resolution : NanometerValue;
            attribute scanRate : Real;
        }
        
        part def MolecularManipulator {
            doc /* Precisely positions and bonds individual atoms */
            port manipInterface : ManipulatorInterface;
            port energy : EnergyPort;
            
            attribute positionAccuracy : NanometerValue;
            attribute maxForce : PiconewtonValue;
            attribute tipAtom : Atom;
        }
        
        part def VacuumChamber {
            doc /* Maintains ultra-high vacuum environment */
            attribute pressure : PressureValue;
            attribute temperature : ThermodynamicTemperatureValue;
        }
        
        part def QuantumController {
            doc /* Controls quantum states during assembly */
            port control : ControlPort;
            port energy : EnergyPort;
            
            attribute coherenceTime : FemtosecondValue;
        }
        
        part def FeedstockReservoir {
            doc /* Stores and supplies atomic feedstock */
            port outlet : FeedstockPort;
            
            attribute capacity : AtomicMassValue;
            attribute currentInventory : AssemblyFeedstock;
        }
        
        part def ProductCollector {
            doc /* Collects and stores assembled molecules */
            port inlet : ProductPort;
            
            attribute storage : Molecule[*];
        }
        
        part def AssemblyProcessor {
            doc /* Coordinates assembly operations */
            port controlIn : ControlPort;
            port diagnosticOut : DiagnosticPort;
            
            attribute currentTarget : TargetProduct;
            attribute assemblyQueue : TargetProduct[*];
        }
    }
    
    package ActionDefinitions {
        private import ValueTypes::*;
        private import ItemTypes::*;
        
        action def ScanSurface {
            in scanArea : Position3D;
            in resolution : NanometerValue;
            out surfaceMap : AtomicConfiguration[*];
            out scanTime : FemtosecondValue;
        }
        
        action def PositionManipulator {
            in targetPos : Position3D;
            in currentPos : Position3D;
            out finalPos : Position3D;
            out movementTime : FemtosecondValue;
        }
        
        action def PickAtom {
            in atom : Atom;
            in tipForce : PiconewtonValue;
            out capturedAtom : Atom;
            out success : Boolean;
        }
        
        action def PlaceAtom {
            in atom : Atom;
            in targetPosition : Position3D;
            in bondingPartner : Atom;
            out bondedAtom : Atom;
            out bondStrength : EnergyValue;
        }
        
        action def FormBond {
            in atom1 : Atom;
            in atom2 : Atom;
            in bondType : String;
            out bondEnergy : EnergyValue;
            out success : Boolean;
        }
        
        action def VerifyStructure {
            in assembled : Molecule;
            in target : MolecularStructure;
            out conformance : Real;
            out defects : Integer;
        }
        
        action def AssembleMolecule {
            in target : TargetProduct;
            in feedstock : AssemblyFeedstock;
            out product : Molecule;
            out report : AssemblyReport;
            
            private attribute currentAtom : Atom;
            private attribute assemblyPosition : Position3D;
            private attribute partialStructure : Atom[*];
            
            first start;
            then action scan : ScanSurface {
                in scanArea;
                in resolution;
                out surfaceMap;
            }
            then merge assemblyLoop;
            
            then action assemblyLoop {
                first action selectAtom;
                action selectAtom {
                    assign currentAtom := feedstock.availableAtoms;
                }
                then action pick : PickAtom {
                    in atom = currentAtom;
                    in tipForce;
                    out capturedAtom;
                    out success;
                }
                then decide;
                    if pick.success then position;
                    if not pick.success then assemblyLoop;
                    
                action position : PositionManipulator {
                    in targetPos = assemblyPosition;
                    in currentPos;
                    out finalPos;
                }
                then action place : PlaceAtom {
                    in atom = pick.capturedAtom;
                    in targetPosition = position.finalPos;
                    in bondingPartner;
                    out bondedAtom;
                }
                then action bond : FormBond {
                    in atom1 = place.bondedAtom;
                    in atom2 = bondingPartner;
                    in bondType;
                    out bondEnergy;
                    out success;
                }
                then assign partialStructure := partialStructure;
                then decide;
                    if true then verify;
            }
            
            action verify : VerifyStructure {
                in assembled;
                in target = target.desiredStructure;
                out conformance;
                out defects;
            }
            then done;
        }
    }
    
    package BehaviorDefinitions {
        private import ValueTypes::*;
        private import ItemTypes::*;
        private import ActionDefinitions::*;
        private import Signals::*;
        
        state machine def AssemblerStateMachine {
            doc /* Controls the operational states of the molecular assembler */
            
            attribute currentProduct : TargetProduct;
            attribute assemblyInProgress : Boolean;
            
            initial state Initialization {
                doc /* System startup and calibration */
                transition to Idle;
            }
            
            state Idle {
                doc /* Ready to receive assembly commands */
                transition to PreparingAssembly;
            }
            
            state PreparingAssembly {
                doc /* Loading feedstock and configuring workspace */
                transition to Scanning;
            }
            
            state Scanning {
                doc /* Scanning assembly surface */
                entry perform action scan : ScanSurface;
                transition to Assembling;
            }
            
            state Assembling {
                doc /* Active molecular assembly in progress */
                entry perform action assemble : AssembleMolecule {
                    in target = currentProduct;
                    out product;
                    out report;
                }
                
                transition to Verifying;
            }
            
            state Verifying {
                doc /* Quality verification of assembled product */
                entry perform action verify : VerifyStructure;
                
                transition to ProductRelease;
            }
            
            state Disassembly {
                doc /* Disassembling defective product */
                transition to Idle;
            }
            
            state ProductRelease {
                doc /* Releasing completed product */
                transition to Idle;
            }
            
            state Emergency {
                doc /* Emergency stop state */
                transition to Idle;
            }
            
            state Shutdown {
                doc /* System shutdown */
            }
        }
    }
    
    package SystemDefinition {
        private import ValueTypes::*;
        private import ItemTypes::*;
        private import PortDefinitions::*;
        private import ComponentDefinitions::*;
        private import ActionDefinitions::*;
        private import BehaviorDefinitions::*;
        private import Signals::*;
        
        part def MolecularAssemblySystem {
            doc /* 
                A molecular nanotechnology system capable of precise atomic-scale 
                manipulation and assembly. The system positions individual atoms 
                with sub-nanometer accuracy to construct custom molecular structures 
                according to programmed specifications.
            */
            
            port feedstockInput : FeedstockPort;
            port productOutput : ProductPort;
            port systemControl : ControlPort;
            port systemDiagnostics : DiagnosticPort;
            port mainPower : EnergyPort;
            
            part afm : AtomicForceMicroscope {
                port sensor;
                port energy;
            }
            
            part manipulator : MolecularManipulator {
                port manipInterface;
                port energy;
            }
            
            part chamber : VacuumChamber;
            
            part controller : QuantumController {
                port control;
                port energy;
            }
            
            part reservoir : FeedstockReservoir {
                port outlet;
            }
            
            part collector : ProductCollector {
                port inlet;
            }
            
            part processor : AssemblyProcessor {
                port controlIn;
                port diagnosticOut;
            }
            
            connect systemControl to processor.controlIn;
            connect processor.diagnosticOut to systemDiagnostics;
            connect feedstockInput to reservoir.outlet;
            connect collector.inlet to productOutput;
            connect mainPower to afm.energy;
            connect mainPower to manipulator.energy;
            connect mainPower to controller.energy;
            
            perform action primaryOperation : AssembleMolecule[*] ordered;
            
            state machine operation : AssemblerStateMachine;
        }
    }
    
    package Requirements {
        private import ValueTypes::*;
        
        requirement def FunctionalRequirement;
        requirement def PerformanceRequirement;
        requirement def AccuracyRequirement;
        requirement def SafetyRequirement;
        
        metadata def functional :> SemanticMetadata {
            :>> baseType = functionalReqs meta SysML::RequirementUsage;
        }
        
        metadata def performance :> SemanticMetadata {
            :>> baseType = performanceReqs meta SysML::RequirementUsage;
        }
        
        requirement functionalReqs : FunctionalRequirement[*] nonunique;
        requirement performanceReqs : PerformanceRequirement[*] nonunique;
        
        #functional requirement <'REQ-001'> PrimaryFunction : FunctionalRequirement {
            doc /* 
                The Molecular Assembly System shall construct custom molecular 
                structures by precisely positioning and bonding individual atoms 
                according to programmed target specifications.
            */
            @StatusInfo {
                status = StatusKind::required;
                risk {
                    totalRisk = high;
                    technicalRisk = high;
                    scheduleRisk = medium;
                    costRisk = high;
                }
                originator = "Dr. Chen";
                owner = "Nanotech Division";
            }
        }
        
        #performance requirement <'REQ-002'> PositioningAccuracy : AccuracyRequirement {
            doc /* 
                The system shall position atoms with an accuracy of 0.1 nanometers 
                or better in all three spatial dimensions.
            */
            @StatusInfo {
                status = StatusKind::required;
                risk {
                    totalRisk = high;
                    technicalRisk = high;
                    scheduleRisk = low;
                    costRisk = medium;
                }
                owner = "Precision Engineering";
            }
        }
        
        #performance requirement <'REQ-003'> AssemblyThroughput : PerformanceRequirement {
            doc /* 
                The system shall assemble at least 100 molecules per hour under 
                continuous operation with feedstock availability.
            */
        }
        
        #functional requirement <'REQ-004'> StructureVerification : FunctionalRequirement {
            doc /* 
                The system shall verify each assembled molecular structure against 
                target specifications with at least 95% conformance accuracy.
            */
        }
        
        requirement <'REQ-005'> VacuumEnvironment : SafetyRequirement {
            doc /* 
                The assembly chamber shall maintain ultra-high vacuum conditions 
                below 10^-9 Torr during all assembly operations.
            */
        }
        
        requirement <'REQ-006'> DefectRate : PerformanceRequirement {
            doc /* 
                The system shall produce molecular structures with fewer than 
                5% defects per assembled molecule.
            */
        }
        
        requirement SystemRequirements {
            require #functional PrimaryFunction;
            require PositioningAccuracy;
            require AssemblyThroughput;
            require StructureVerification;
            require VacuumEnvironment;
            require DefectRate;
        }
    }
}
