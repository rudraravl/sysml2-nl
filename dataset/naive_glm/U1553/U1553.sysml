package EngineeringDesignSystem {
    import ISQ::*;
    import ScalarValues::*;

    // 1. Value Types with Units
    value type MassValue :> Mass;
    value type StressValue :> Pressure;
    value type DisplacementValue :> Length;
    value type TemperatureValue :> ThermodynamicTemperature;

    // 2. Item Definitions
    item def RequirementSpec {
        attribute id : String;
        attribute functionalNeeds : String;
        attribute performanceCriteria : String;
        attribute constraints : String;
    }

    item def CADModel {
        attribute modelId : String;
        attribute softwareUsed : String = "CATIA";
        attribute geometryFile : String;
        attribute material : String;
        attribute estimatedMass : MassValue;
    }

    item def FEAReport {
        attribute reportId : String;
        attribute solverUsed : String = "NASTRAN";
        attribute maxStress : StressValue;
        attribute maxDisplacement : DisplacementValue;
        attribute maxTemperature : TemperatureValue;
        attribute isStructurallySound : Boolean;
    }

    item def ValidationReport {
        attribute reportId : String;
        attribute complianceStandard : String = "FAA Regulations";
        attribute testProtocol : String;
        attribute isCompliant : Boolean;
    }

    item def ApprovalCertificate {
        attribute certificateId : String;
        attribute approverName : String;
        attribute approverRole : String = "Chief Engineering Officer";
        attribute isApproved : Boolean;
    }

    // 3. Port Definitions
    port def SpecOutPort { out spec : RequirementSpec; }
    port def SpecInPort { in spec : RequirementSpec; }
    port def ModelOutPort { out model : CADModel; }
    port def ModelInPort { in model : CADModel; }
    port def ReportOutPort { out report : FEAReport; }
    port def ReportInPort { in report : FEAReport; }
    port def ValReportOutPort { out valReport : ValidationReport; }
    port def ValReportInPort { in valReport : ValidationReport; }
    port def ApprovalOutPort { out cert : ApprovalCertificate; }
    port def DataRepoPort { inout artifact : Any; }

    // 4. Part Definitions
    part def Reviewer {
        attribute role : String;
    }

    part def RequirementsManagementModule {
        port specOut : SpecOutPort;
        port repoConn : DataRepoPort;
        
        attribute capturedSpecs : RequirementSpec[0..*];
        
        action captureRequirements {
            in stakeholderInput : String;
            out generatedSpec : RequirementSpec;
        }
    }

    part def CADModelingModule {
        port specIn : SpecInPort;
        port modelOut : ModelOutPort;
        port repoConn : DataRepoPort;
        
        action createCADModel {
            in spec : RequirementSpec;
            out model : CADModel;
        }
    }

    part def FEAModule {
        port modelIn : ModelInPort;
        port reportOut : ReportOutPort;
        port repoConn : DataRepoPort;
        
        action performFEA {
            in model : CADModel;
            out report : FEAReport;
        }
    }

    part def OptimizationEngine {
        port reportIn : ReportInPort;
        port modelOut : ModelOutPort;
        port repoConn : DataRepoPort;
        
        action optimizeDesign {
            in report : FEAReport;
            in currentModel : CADModel;
            out optimizedModel : CADModel;
        }
    }

    part def DesignDataRepository {
        port reqDataPort : DataRepoPort;
        port cadDataPort : DataRepoPort;
        port feaDataPort : DataRepoPort;
        port optDataPort : DataRepoPort;
        port valDataPort : DataRepoPort;
        port appDataPort : DataRepoPort;
        
        attribute versionedArtifacts : Any[0..*];
        
        action storeArtifact {
            in artifact : Any;
            out storedRef : Any;
        }
    }

    part def ValidationTestingModule {
        port modelIn : ModelInPort;
        port reportIn : ReportInPort;
        port valReportOut : ValReportOutPort;
        port repoConn : DataRepoPort;
        
        action validateDesign {
            in model : CADModel;
            in report : FEAReport;
            out valReport : ValidationReport;
        }
    }

    part def ReviewApprovalBoard {
        part ceo : Reviewer {
            attribute role : String = "Chief Engineering Officer";
        }
        port valReportIn : ValReportInPort;
        port approvalOut : ApprovalOutPort;
        port repoConn : DataRepoPort;
        
        action reviewAndApprove {
            in valReport : ValidationReport;
            out cert : ApprovalCertificate;
        }
    }

    // 5. Requirements
    requirement def AerospaceWingDesignRequirements {
        doc "The system shall manage the lifecycle of an aerospace wing structure from requirements to production approval."
        subject wingDesignSystem : IntegratedEngineeringDesignSystem;
        
        requirement ReqMgmtRequirement {
            doc "The system shall capture and document all functional needs, performance criteria, and constraints for the wing structure."
        }
        
        requirement CADModelingRequirement {
            doc "The system shall generate a 3D digital model using CAD software."
        }
        
        requirement FEARequirement {
            doc "The system shall analyze the wing structure using FEA solvers for structural integrity, stress, and thermal performance."
        }
        
        requirement OptimizationRequirement {
            doc "The system shall iteratively refine geometry or materials based on FEA results to improve characteristics."
        }
        
        requirement ValidationRequirement {
            doc "The system shall validate the design against industry-specific compliance standards and test protocols."
        }
        
        requirement ApprovalRequirement {
            doc "The system shall submit the complete validation report to the Review and Approval Board for final sign-off."
        }
    }

    // 6. Main System Integration
    part def IntegratedEngineeringDesignSystem :> AerospaceWingDesignRequirements {
        part reqModule : RequirementsManagementModule;
        part cadModule : CADModelingModule;
        part feaModule : FEAModule;
        part optEngine : OptimizationEngine;
        part dataRepo : DesignDataRepository;
        part valModule : ValidationTestingModule;
        part appBoard : ReviewApprovalBoard;

        // Main process flow connections
        connection reqModule.specOut to cadModule.specIn;
        connection cadModule.modelOut to feaModule.modelIn;
        connection feaModule.reportOut to optEngine.reportIn;
        connection optEngine.modelOut to feaModule.modelIn; // Optimization feedback loop
        connection feaModule.reportOut to valModule.reportIn;
        connection cadModule.modelOut to valModule.modelIn;
        connection valModule.valReportOut to appBoard.valReportIn;
        connection appBoard.approvalOut to dataRepo.appDataPort;

        // Repository connections
        connection reqModule.repoConn to dataRepo.reqDataPort;
        connection cadModule.repoConn to dataRepo.cadDataPort;
        connection feaModule.repoConn to dataRepo.feaDataPort;
        connection optEngine.repoConn to dataRepo.optDataPort;
        connection valModule.repoConn to dataRepo.valDataPort;
        connection appBoard.repoConn to dataRepo.appDataPort;

        // Lifecycle Behavior
        state designLifecycle {
            initial -> Conceptual;
            
            state Conceptual {
                entry action { reqModule.captureRequirements(); }
            }
            
            state Detailed {
                entry action { cadModule.createCADModel(); }
            }
            
            state Analysis {
                entry action { feaModule.performFEA(); }
            }
            
            state Optimization {
                entry action { optEngine.optimizeDesign(); }
            }
            
            state Validation {
                entry action { valModule.validateDesign(); }
            }
            
            state Approval {
                entry action { appBoard.reviewAndApprove(); }
            }
            
            state Released;
            
            transition from Conceptual to Detailed;
            transition from Detailed to Analysis;
            
            transition from Analysis to Optimization 
                when feaModule.reportOut.report.isStructurallySound == false;
            
            transition from Optimization to Analysis;
            
            transition from Analysis to Validation 
                when feaModule.reportOut.report.isStructurallySound == true;
            
            transition from Validation to Approval;
            
            transition from Approval to Released 
                when appBoard.approvalOut.cert.isApproved == true;
        }
    }
}
