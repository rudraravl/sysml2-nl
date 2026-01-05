package SemiAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    doc /* This model describes a semi-automation system for manufacturing assembly operations.
           The system combines human operator oversight with automated execution to perform
           precision assembly tasks. The operator initiates tasks and monitors progress while
           the automated subsystem executes repetitive operations with high accuracy. */
    
    attribute def OperatorCommand;
    attribute def TaskIdentifier;
    attribute def QualityMetric;
    
    enum def OperationMode {
        manual;
        semiAuto;
        fullyAuto;
    }
    
    enum def TaskStatus {
        pending;
        inProgress;
        completed;
        failed;
        awaitingApproval;
    }
    
    item def WorkPiece {
        attribute pieceId : String;
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute qualityScore : Real;
    }
    
    item def AssemblyInstruction {
        attribute taskId : TaskIdentifier;
        attribute sequenceNumber : Integer;
        attribute torqueSpec : TorqueValue;
        attribute positionTolerance : LengthValue;
    }
    
    item def OperatorFeedback {
        attribute approvalStatus : Boolean;
        attribute comments : String;
        attribute timestamp : TimeValue;
    }
    
    item def ProcessData {
        attribute cycleTime : DurationValue;
        attribute forceApplied : ForceValue;
        attribute positionAchieved : LengthValue[3];
        attribute qualityCheck : Boolean;
    }
    
    port def OperatorInterfacePort {
        in item commands : OperatorCommand[*];
        out item status : TaskStatus[*];
        out item feedback : OperatorFeedback[*];
    }
    
    port def WorkpiecePort {
        in item rawPiece : WorkPiece;
        out item assembledPiece : WorkPiece;
    }
    
    port def ControlSignalPort {
        out attribute position : LengthValue[3];
        out attribute velocity : SpeedValue;
        out attribute force : ForceValue;
    }
    
    port def SensorDataPort {
        in attribute actualPosition : LengthValue[3];
        in attribute actualForce : ForceValue;
        in attribute temperature : ThermodynamicTemperatureValue;
    }
    
    part def OperatorStation {
        doc /* Human-machine interface for operator control and monitoring. */
        
        port operatorPort : ~OperatorInterfacePort;
        
        attribute currentMode : OperationMode;
        attribute operatorPresent : Boolean;
        
        action issueCommand {
            out command : OperatorCommand;
        }
        
        action reviewTask {
            in taskData : ProcessData;
            out feedback : OperatorFeedback;
        }
        
        action approveExecution {
            in instruction : AssemblyInstruction;
            out approved : Boolean;
        }
    }
    
    part def AutomatedController {
        doc /* Automated control system that executes assembly operations. */
        
        port controlPort : ControlSignalPort;
        port sensorPort : ~SensorDataPort;
        
        attribute controlGain : Real;
        attribute safetyLimits : ForceValue;
        
        action planMotion {
            in instruction : AssemblyInstruction;
            in currentPosition : LengthValue[3];
            out trajectory : LengthValue[*];
        }
        
        action executeMotion {
            in trajectory : LengthValue[*];
            out controlSignals : ControlSignalPort;
        }
        
        action monitorExecution {
            in sensorData : SensorDataPort;
            in targetSpec : AssemblyInstruction;
            out withinTolerance : Boolean;
        }
    }
    
    part def RoboticManipulator {
        doc /* Physical robotic arm that performs assembly operations. */
        
        port commandPort : ~ControlSignalPort;
        port feedbackPort : SensorDataPort;
        
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        attribute repeatability : LengthValue;
        
        action moveToPosition {
            in targetPosition : LengthValue[3];
            in targetVelocity : SpeedValue;
            out actualPosition : LengthValue[3];
        }
        
        action applyForce {
            in targetForce : ForceValue;
            out actualForce : ForceValue;
        }
    }
    
    part def QualityInspectionUnit {
        doc /* Automated inspection system for quality verification. */
        
        attribute inspectionCriteria : QualityMetric[*];
        
        action inspectAssembly {
            in assembledPiece : WorkPiece;
            in specification : AssemblyInstruction;
            out passedInspection : Boolean;
            out qualityData : ProcessData;
        }
    }
    
    part def TaskCoordinator {
        doc /* Coordinates workflow between operator and automated systems. */
        
        attribute taskQueue : AssemblyInstruction[*];
        attribute currentTask : AssemblyInstruction;
        
        action scheduleTask {
            in newInstruction : AssemblyInstruction;
            out scheduled : Boolean;
        }
        
        action arbitrateControl {
            in operatorCommand : OperatorCommand;
            in automationReady : Boolean;
            out executionMode : OperationMode;
        }
        
        action updateTaskStatus {
            in taskId : TaskIdentifier;
            in newStatus : TaskStatus;
        }
    }
    
    requirement def SemiAutomationRequirement {
        doc /* The system shall enable semi-automated assembly operations combining
               human oversight with automated precision execution. */
        
        require constraint operatorApproval {
            doc /* Critical assembly steps shall require explicit operator approval
                   before automated execution. */
        }
        
        require constraint safetyMonitoring {
            doc /* The system shall continuously monitor force and position to ensure
                   safe operation within defined limits. */
        }
        
        require constraint qualityAssurance {
            doc /* Each assembled piece shall undergo automated quality inspection
                   before completion. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The system shall meet specified performance criteria. */
        
        require constraint cycleTime {
            doc /* Assembly cycle time shall not exceed 120 seconds per piece. */
        }
        
        require constraint positionAccuracy {
            doc /* Positioning accuracy shall be within 0.1 mm of specified target. */
        }
        
        require constraint throughput {
            doc /* System shall achieve minimum throughput of 25 pieces per hour. */
        }
    }
    
    part def SemiAutomationCell {
        doc /* A semi-automation cell that combines human operator decision-making
               and oversight with automated robotic execution to perform precision
               assembly operations. The operator initiates tasks, approves critical
               steps, and intervenes when necessary, while the automated controller
               executes repetitive motions with high accuracy and consistency. */
    }
    
    part semiAutomationCell : SemiAutomationCell {
        doc /* Complete semi-automation cell integrating operator station with
               automated assembly equipment. */
        
        part operator : OperatorStation;
        part controller : AutomatedController;
        part manipulator : RoboticManipulator;
        part inspector : QualityInspectionUnit;
        part coordinator : TaskCoordinator;
        
        port workpieceInput : WorkpiecePort;
        port workpieceOutput : ~WorkpiecePort;
        port operatorInterface : OperatorInterfacePort;
        
        connect controller.controlPort to manipulator.commandPort;
        connect manipulator.feedbackPort to controller.sensorPort;
        connect operator.operatorPort to operatorInterface;
        
        perform action semiAutomatedAssembly {
            doc /* Primary function: Execute semi-automated assembly operations with
                   operator oversight and automated precision. */
            
            first start;
            then merge assemblyLoop;
            
            action loadWorkpiece {
                in rawPiece : WorkPiece;
                out loadedPiece : WorkPiece;
            }
            
            then action getInstruction : coordinator.scheduleTask {
                in newInstruction : AssemblyInstruction;
                out scheduled : Boolean;
            }
            
            then action requestApproval : operator.approveExecution {
                in instruction : AssemblyInstruction;
                out approved : Boolean;
            }
            
            then decide;
                if requestApproval.approved then executeAutomated;
                if not requestApproval.approved then manualIntervention;
            
            action executeAutomated {
                action plan : controller.planMotion {
                    in instruction : AssemblyInstruction;
                    in currentPosition : LengthValue[3];
                    out trajectory : LengthValue[*];
                }
                
                then action execute : controller.executeMotion {
                    in trajectory : LengthValue[*];
                    out controlSignals : ControlSignalPort;
                }
                
                then action move : manipulator.moveToPosition {
                    in targetPosition : LengthValue[3];
                    in targetVelocity : SpeedValue;
                    out actualPosition : LengthValue[3];
                }
                
                then action apply : manipulator.applyForce {
                    in targetForce : ForceValue;
                    out actualForce : ForceValue;
                }
                
                then action monitor : controller.monitorExecution {
                    in sensorData : SensorDataPort;
                    in targetSpec : AssemblyInstruction;
                    out withinTolerance : Boolean;
                }
                
                then decide;
                    if monitor.withinTolerance then merge proceedToInspection;
                    if not monitor.withinTolerance then retryOperation;
                
                action retryOperation {
                    then merge assemblyLoop;
                }
            }
            
            action manualIntervention {
                action operatorReview : operator.reviewTask {
                    in taskData : ProcessData;
                    out feedback : OperatorFeedback;
                }
                then merge assemblyLoop;
            }
            
            merge proceedToInspection;
            
            then action inspect : inspector.inspectAssembly {
                in assembledPiece : WorkPiece;
                in specification : AssemblyInstruction;
                out passedInspection : Boolean;
                out qualityData : ProcessData;
            }
            
            then decide;
                if inspect.passedInspection then completeTask;
                if not inspect.passedInspection then qualityFailure;
            
            action completeTask {
                action updateStatus : coordinator.updateTaskStatus {
                    in taskId : TaskIdentifier;
                    in newStatus : TaskStatus;
                }
                
                then action unloadWorkpiece {
                    in assembledPiece : WorkPiece;
                    out finalPiece : WorkPiece;
                }
                
                then assemblyLoop;
            }
            
            action qualityFailure {
                action markFailed : coordinator.updateTaskStatus {
                    in taskId : TaskIdentifier;
                    in newStatus : TaskStatus;
                }
                
                then action requestReview : operator.reviewTask {
                    in taskData : ProcessData;
                    out feedback : OperatorFeedback;
                }
                then assemblyLoop;
            }
            
            then done;
        }
        
        assert semiAutoReq : SemiAutomationRequirement;
        assert perfReq : PerformanceRequirement;
    }
}
