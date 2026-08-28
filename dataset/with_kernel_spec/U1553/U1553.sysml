package 'Integrated Engineering Design System' {
    private import ScalarValues::*;
    
    package 'Item Definitions' {
        private import ScalarValues::*;
        
        item def 'StakeholderRequirement' {
            attribute id : String;
            attribute text : String;
        }
        
        item def 'PerformanceSpec' {
            attribute maxStress : Real;
            attribute maxDeflection : Real;
            attribute maxWeight : Real;
            attribute thermalLimit : Real;
        }
        
        item def 'DesignConstraint' {
            attribute envelope : String;
            attribute regulatoryStandard : String;
        }
        
        item def 'CADModel' {
            attribute modelId : String;
            attribute version : String;
        }
        
        item def 'OptimizedModel' :> 'CADModel';
        
        item def 'FEAResult' {
            attribute maxVonMisesStress : Real;
            attribute thermalLoad : Real;
            attribute marginOfSafety : Real;
        }
        
        item def 'ValidationReport' {
            attribute reportId : String;
            attribute compliant : Boolean;
            attribute findings : String;
        }
        
        item def 'ApprovalRecord' {
            attribute decision : String;
            attribute approver : String;
            attribute date : String;
        }
    }
    
    package 'Requirements' {
        requirement def 'DesignCaptureRequirement' {
            doc /* The system shall capture all stakeholder requirements for the product. */
        }
        requirement def 'CADModelingRequirement' {
            doc /* The system shall produce a 3D CAD model of the design. */
        }
        requirement def 'FEAAnalysisRequirement' {
            doc /* The system shall simulate structural and thermal performance via FEA. */
        }
        requirement def 'OptimizationRequirement' {
            doc /* The system shall refine the design when analysis indicates performance gaps. */
        }
        requirement def 'DataRepositoryRequirement' {
            doc /* The system shall maintain a versioned design data repository. */
        }
        requirement def 'ValidationRequirement' {
            doc /* The system shall validate designs against compliance standards. */
        }
        requirement def 'ApprovalRequirement' {
            doc /* The system shall route final designs through a review board for approval. */
        }
        
        requirement designCaptureReq : 'DesignCaptureRequirement';
        requirement cadModelingReq : 'CADModelingRequirement';
        requirement feaAnalysisReq : 'FEAAnalysisRequirement';
        requirement optimizationReq : 'OptimizationRequirement';
        requirement dataRepositoryReq : 'DataRepositoryRequirement';
        requirement validationReq : 'ValidationRequirement';
        requirement approvalReq : 'ApprovalRequirement';
    }
    
    package 'Module Definitions' {
        private import 'Item Definitions'::*;
        
        part def 'RequirementsManagementModule' {
            port reqInPort { in stakeholderReq : 'StakeholderRequirement'; }
            port specOutPort { 
                out perfSpec : 'PerformanceSpec'; 
                out designConstraint : 'DesignConstraint'; 
            }
        }
        
        part def 'CADModelingModule' {
            port specInPort { 
                in perfSpec : 'PerformanceSpec'; 
                in designConstraint : 'DesignConstraint'; 
            }
            port modelOutPort { out cadModel : 'CADModel'; }
        }
        
        part def 'FEAModule' {
            port modelInPort { in cadModel : 'CADModel'; }
            port resultOutPort { out feaResult : 'FEAResult'; }
        }
        
        part def 'OptimizationEngine' {
            port currentModelInPort { in cadModel : 'CADModel'; }
            port resultInPort { in feaResult : 'FEAResult'; }
            port refinedModelOutPort { out optimizedModel : 'OptimizedModel'; }
        }
        
        part def 'DesignDataRepository' {
            port storeModelInPort { in cadModel : 'CADModel'; }
            port storeResultInPort { in feaResult : 'FEAResult'; }
            port storeReportInPort { in report : 'ValidationReport'; }
            port retrieveModelOutPort { out cadModel : 'CADModel'; }
            port retrieveResultOutPort { out feaResult : 'FEAResult'; }
        }
        
        part def 'ValidationTestingModule' {
            port modelInPort { in cadModel : 'CADModel'; }
            port resultInPort { in feaResult : 'FEAResult'; }
            port reportOutPort { out report : 'ValidationReport'; }
        }
        
        part def 'ChiefEngineeringOfficer';
        
        part def 'ReviewApprovalBoard' {
            port reportInPort { in report : 'ValidationReport'; }
            port decisionOutPort { out approval : 'ApprovalRecord'; }
            part ceo : 'ChiefEngineeringOfficer';
        }
    }
    
    package 'System Integration' {
        private import 'Module Definitions'::*;
        private import 'Item Definitions'::*;
        private import 'Requirements'::*;
        
        part def 'IntegratedEngineeringDesignPlatform' {
            port stakeholderInput { in stakeholderReq : 'StakeholderRequirement'; }
            port approvalOutput { out approval : 'ApprovalRecord'; }
            
            part reqMgmt : 'RequirementsManagementModule';
            part cadMod : 'CADModelingModule';
            part feaMod : 'FEAModule';
            part optEngine : 'OptimizationEngine';
            part dataRepo : 'DesignDataRepository';
            part valMod : 'ValidationTestingModule';
            part apprBoard : 'ReviewApprovalBoard';
            
            interface reqToCAD connect reqMgmt.specOutPort to cadMod.specInPort {
                flow perfSpecFlow of 'PerformanceSpec' 
                    from reqMgmt.specOutPort.perfSpec to cadMod.specInPort.perfSpec;
                flow constraintFlow of 'DesignConstraint' 
                    from reqMgmt.specOutPort.designConstraint to cadMod.specInPort.designConstraint;
            }
            
            interface cadToFEA connect cadMod.modelOutPort to feaMod.modelInPort {
                flow cadModelFlow1 of 'CADModel' 
                    from cadMod.modelOutPort.cadModel to feaMod.modelInPort.cadModel;
            }
            
            interface feaToOpt connect feaMod.resultOutPort to optEngine.resultInPort {
                flow feaResultFlow1 of 'FEAResult' 
                    from feaMod.resultOutPort.feaResult to optEngine.resultInPort.feaResult;
            }
            
            interface cadToOpt connect cadMod.modelOutPort to optEngine.currentModelInPort {
                flow cadModelFlow2 of 'CADModel' 
                    from cadMod.modelOutPort.cadModel to optEngine.currentModelInPort.cadModel;
            }
            
            interface optToFEA connect optEngine.refinedModelOutPort to feaMod.modelInPort {
                flow refinedModelFlow of 'OptimizedModel' 
                    from optEngine.refinedModelOutPort.optimizedModel to feaMod.modelInPort.cadModel;
            }
            
            interface feaToVal connect feaMod.resultOutPort to valMod.resultInPort {
                flow feaResultFlow2 of 'FEAResult' 
                    from feaMod.resultOutPort.feaResult to valMod.resultInPort.feaResult;
            }
            
            interface optToVal connect optEngine.refinedModelOutPort to valMod.modelInPort {
                flow optimizedModelValFlow of 'OptimizedModel' 
                    from optEngine.refinedModelOutPort.optimizedModel to valMod.modelInPort.cadModel;
            }
            
            interface valToBoard connect valMod.reportOutPort to apprBoard.reportInPort {
                flow validationReportFlow of 'ValidationReport' 
                    from valMod.reportOutPort.report to apprBoard.reportInPort.report;
            }
            
            interface boardToOutput connect apprBoard.decisionOutPort to approvalOutput {
                flow approvalFlow of 'ApprovalRecord' 
                    from apprBoard.decisionOutPort.approval to approvalOutput.approval;
            }
            
            perform action 'DesignLifecycle' {
                action 'captureRequirements' {
                    in item 'stakeholderReq' : 'StakeholderRequirement';
                    out item 'perfSpec' : 'PerformanceSpec';
                    out item 'designConstraint' : 'DesignConstraint';
                }
                action 'createModel' {
                    in item 'perfSpec' : 'PerformanceSpec';
                    in item 'designConstraint' : 'DesignConstraint';
                    out item 'cadModel' : 'CADModel';
                }
                action 'runAnalysis' {
                    in item 'cadModel' : 'CADModel';
                    out item 'feaResult' : 'FEAResult';
                }
                action 'optimizeDesign' {
                    in item 'cadModel' : 'CADModel';
                    in item 'feaResult' : 'FEAResult';
                    out item 'optimizedModel' : 'OptimizedModel';
                }
                action 'runComplianceCheck' {
                    in item 'cadModel' : 'CADModel';
                    in item 'feaResult' : 'FEAResult';
                    out item 'report' : 'ValidationReport';
                }
                action 'reviewAndApprove' {
                    in item 'report' : 'ValidationReport';
                    out item 'approval' : 'ApprovalRecord';
                }
                
                flow 'perfSpecFlow' of 'PerformanceSpec' 
                    from 'captureRequirements'.'perfSpec' to 'createModel'.'perfSpec';
                flow 'constraintFlow' of 'DesignConstraint' 
                    from 'captureRequirements'.'designConstraint' to 'createModel'.'designConstraint';
                flow 'cadModelFlow' of 'CADModel' 
                    from 'createModel'.'cadModel' to 'runAnalysis'.'cadModel';
                flow 'cadModelOptFlow' of 'CADModel' 
                    from 'createModel'.'cadModel' to 'optimizeDesign'.'cadModel';
                flow 'feaResultFlow1' of 'FEAResult' 
                    from 'runAnalysis'.'feaResult' to 'optimizeDesign'.'feaResult';
                flow 'optimizedModelFlow' of 'OptimizedModel' 
                    from 'optimizeDesign'.'optimizedModel' to 'runAnalysis'.'cadModel';
                flow 'feaResultFlow2' of 'FEAResult' 
                    from 'runAnalysis'.'feaResult' to 'runComplianceCheck'.'feaResult';
                flow 'optimizedModelValFlow' of 'OptimizedModel' 
                    from 'optimizeDesign'.'optimizedModel' to 'runComplianceCheck'.'cadModel';
                flow 'reportFlow' of 'ValidationReport' 
                    from 'runComplianceCheck'.'report' to 'reviewAndApprove'.'report';
            }
            
            state machine lifecycleStates {
                state 'RequirementsCapture';
                state 'ConceptualDesign';
                state 'Analyzing';
                state 'Optimizing';
                state 'Validation';
                state 'Approval';
                state 'Released';
                
                transition from initial to 'RequirementsCapture';
                transition from 'RequirementsCapture' to 'ConceptualDesign';
                transition from 'ConceptualDesign' to 'Analyzing';
                transition from 'Analyzing' to 'Optimizing';
                transition from 'Optimizing' to 'Analyzing';
                transition from 'Optimizing' to 'Validation';
                transition from 'Validation' to 'Approval';
                transition from 'Approval' to 'Released';
            }
        }
        
        part designPlatform : 'IntegratedEngineeringDesignPlatform' {
            satisfy designCaptureReq by reqMgmt;
            satisfy cadModelingReq by cadMod;
            satisfy feaAnalysisReq by feaMod;
            satisfy optimizationReq by optEngine;
            satisfy dataRepositoryReq by dataRepo;
            satisfy validationReq by valMod;
            satisfy approvalReq by apprBoard;
        }
    }
}
