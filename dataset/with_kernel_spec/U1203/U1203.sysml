package ManufacturingAssemblyCell {

    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    // ===== Value Types with Units =====
    attribute def TorqueValue :> ISQ::torque;
    attribute def ForceValue :> ISQ::force;
    attribute def LengthValue :> ISQ::length;

    // ===== Item Types =====
    item def Workpiece {
        attribute id : String;
        attribute rawMaterial : String;
        attribute assembled : Boolean = false;
        attribute inspected : Boolean = false;
        attribute passed : Boolean = false;
    }

    item def AssemblyInstruction {
        attribute name : String;
        attribute targetPosition : LengthValue;
        attribute requiredTorque : TorqueValue;
        attribute requiredForce : ForceValue;
        attribute tolerance : LengthValue;
    }

    // ===== Signal Definitions =====
    attribute def TaskApproval;
    attribute def TaskRequest;
    attribute def TaskStatus {
        attribute status : String;
        attribute detail : String;
    }
    attribute def QualityResult {
        attribute passed : Boolean;
        attribute defectDescription : String;
    }
    attribute def ErrorAlert {
        attribute errorCode : String;
        attribute description : String;
    }
    attribute def InterventionCommand {
        attribute command : String;
    }
    attribute def Trajectory {
        attribute waypoints : String;
    }
    attribute def SensorFeedback {
        attribute actualPosition : LengthValue;
        attribute actualForce : ForceValue;
        attribute actualTorque : TorqueValue;
    }

    // ===== Port Definitions =====
    port def OperatorPort {
        out taskApproval : TaskApproval;
        in taskRequest : TaskRequest;
        out intervention : InterventionCommand;
        in status : TaskStatus;
        in alert : ErrorAlert;
        in qualityResult : QualityResult;
    }

    port def CoordinatorPort {
        in taskApproval : TaskApproval;
        out taskRequest : TaskRequest;
        out status : TaskStatus;
        out alert : ErrorAlert;
        in intervention : InterventionCommand;
        in qualityResult : QualityResult;
        out instruction : AssemblyInstruction;
    }

    port def ControllerPort {
        in instruction : AssemblyInstruction;
        out trajectory : Trajectory;
        in feedback : SensorFeedback;
        out status : TaskStatus;
        out alert : ErrorAlert;
    }

    port def RobotPort {
        in trajectory : Trajectory;
        out feedback : SensorFeedback;
        in workpieceIn : Workpiece;
        out workpieceOut : Workpiece;
    }

    port def InspectionPort {
        in workpiece : Workpiece;
        out result : QualityResult;
    }

    // ===== Part Definitions =====
    part def OperatorStation {
        port opPort : OperatorPort;
        attribute operatorPresent : Boolean = true;

        action def MonitorProgress {
            in status : TaskStatus;
        }
        action def ReviewData {
            in result : QualityResult;
            in alert : ErrorAlert;
        }
        action ProvideApproval {
            out approval : TaskApproval;
        }
        action Intervene {
            out cmd : InterventionCommand;
        }
    }

    part def RoboticManipulator {
        port rPort : RobotPort;
        attribute maxReach : LengthValue = 1.5 [m];
        attribute maxForce : ForceValue = 500 [N];
        attribute maxTorque : TorqueValue = 50 [N*m];

        action def ExecuteTrajectory {
            in trajectory : Trajectory;
            out feedback : SensorFeedback;
        }
        action PerformAssembly {
            in trajectory : Trajectory;
            out feedback : SensorFeedback;
            in workpiece : Workpiece;
            out assembledWorkpiece : Workpiece;
            first executeTrajectory;
            action executeTrajectory : ExecuteTrajectory {
                in :>> trajectory;
                out :>> feedback;
            }
        }
    }

    part def AutomatedController {
        port cPort : ControllerPort;
        attribute taskComplete : Boolean = false;
        attribute errorDetected : Boolean = false;

        action def PlanTrajectory {
            in instruction : AssemblyInstruction;
            out trajectory : Trajectory;
        }
        action def MonitorSensors {
            in feedback : SensorFeedback;
            in instruction : AssemblyInstruction;
            out status : TaskStatus;
            out alert : ErrorAlert;
        }
        action CommandRobot {
            in instruction : AssemblyInstruction;
            out trajectory : Trajectory;
            in feedback : SensorFeedback;
            out status : TaskStatus;
            out alert : ErrorAlert;
            first planTrajectory;
            then monitorSensors;
            action planTrajectory : PlanTrajectory {
                in :>> instruction;
                out :>> trajectory;
            }
            action monitorSensors : MonitorSensors {
                in :>> feedback;
                in :>> instruction;
                out :>> status;
                out :>> alert;
            }
        }
    }

    part def TaskCoordinator {
        port tPort : CoordinatorPort;
        attribute mode : String = "semi-automated";
        attribute jobQueue : AssemblyInstruction[0..*];
        attribute hasPendingJobs : Boolean = false;
        attribute currentInstruction : AssemblyInstruction;
        attribute approvalReceived : Boolean = false;
        attribute interventionReceived : Boolean = false;

        action def ScheduleNextTask {
            out instruction : AssemblyInstruction;
            out request : TaskRequest;
        }
        action ManageWorkflow {
            in approval : TaskApproval;
            in intervention : InterventionCommand;
            in result : QualityResult;
            out instruction : AssemblyInstruction;
            out request : TaskRequest;
            out status : TaskStatus;
            out alert : ErrorAlert;
            first scheduleNextTask;
            action scheduleNextTask : ScheduleNextTask {
                out :>> instruction;
                out :>> request;
            }
        }
    }

    part def QualityInspectionUnit {
        port iPort : InspectionPort;
        attribute inspectionCriteria : String;
        attribute inspectionPassed : Boolean = false;
        attribute inspectionDone : Boolean = false;

        action def InspectPart {
            in workpiece : Workpiece;
            out result : QualityResult;
        }
        action PerformInspection {
            in workpiece : Workpiece;
            out result : QualityResult;
            first inspectPart;
            action inspectPart : InspectPart {
                in :>> workpiece;
                out :>> result;
            }
        }
    }

    // ===== Integrated Assembly Cell =====
    part def AssemblyCell {
        part operatorStation : OperatorStation {
            port :>> opPort;
        }
        part robot : RoboticManipulator {
            port :>> rPort;
        }
        part controller : AutomatedController {
            port :>> cPort;
        }
        part coordinator : TaskCoordinator {
            port :>> tPort;
        }
        part inspectionUnit : QualityInspectionUnit {
            port :>> iPort;
        }
        part currentWorkpiece : Workpiece[0..1];

        connection operatorApprovalToCoordinator connect operatorStation.opPort.taskApproval to coordinator.tPort.taskApproval;
        connection coordinatorRequestToOperator connect coordinator.tPort.taskRequest to operatorStation.opPort.taskRequest;
        connection coordinatorStatusToOperator connect coordinator.tPort.status to operatorStation.opPort.status;
        connection coordinatorAlertToOperator connect coordinator.tPort.alert to operatorStation.opPort.alert;
        connection operatorInterventionToCoordinator connect operatorStation.opPort.intervention to coordinator.tPort.intervention;

        connection coordinatorInstructionToController connect coordinator.tPort.instruction to controller.cPort.instruction;
        connection controllerStatusToCoordinator connect controller.cPort.status to coordinator.tPort.status;
        connection controllerAlertToCoordinator connect controller.cPort.alert to coordinator.tPort.alert;

        connection controllerTrajectoryToRobot connect controller.cPort.trajectory to robot.rPort.trajectory;
        connection robotFeedbackToController connect robot.rPort.feedback to controller.cPort.feedback;

        connection inspectionResultToCoordinator connect inspectionUnit.iPort.result to coordinator.tPort.qualityResult;
        connection inspectionResultToOperator connect inspectionUnit.iPort.result to operatorStation.opPort.qualityResult;

        flow robot.rPort.workpieceOut to inspectionUnit.iPort.workpiece;
    }

    // ===== Cell Behavior (State Machine) =====
    state def CellOperation {
        in cell : AssemblyCell;
        in workpiece : Workpiece;
        entry; then idle;

        state idle;
        accept when cell.coordinator.hasPendingJobs
            then scheduling;

        state scheduling {
            entry assign cell.coordinator.hasPendingJobs := false;
        }
        then awaitingApproval;

        state awaitingApproval {
            entry send new TaskRequest() to cell.operatorStation;
        }
        accept when cell.coordinator.approvalReceived
            then commanding;

        state commanding {
            entry send new TaskRequest() to cell.controller;
        }
        then executing;

        state executing {
            do action performRobotAssembly {
                in instruction = cell.coordinator.currentInstruction;
                in wp = workpiece;
            }
        }
        accept when cell.controller.taskComplete
            then inspecting;
        accept when cell.controller.errorDetected
            then errorHandling;

        state inspecting {
            do action runInspection {
                in wp = workpiece;
            }
        }
        accept when cell.inspectionUnit.inspectionDone and cell.inspectionUnit.inspectionPassed
            then complete;
        accept when cell.inspectionUnit.inspectionDone and not cell.inspectionUnit.inspectionPassed
            then errorHandling;

        state errorHandling {
            entry send new ErrorAlert() to cell.operatorStation;
        }
        accept when cell.coordinator.interventionReceived
            then idle;

        state complete {
            entry assign workpiece.passed := true;
        }
        accept after 5 [s]
            then idle;
    }

    // ===== Requirements =====
    requirement def RequiresOperatorApproval {
        subject cell : AssemblyCell;
        doc /* The system must require explicit operator approval before the robot begins critical assembly steps. */
    }

    requirement def RequiresQualityInspection {
        subject cell : AssemblyCell;
        doc /* All workpieces must pass quality inspection before being marked complete. */
    }

    requirement def ErrorHandlingProtocol {
        subject cell : AssemblyCell;
        doc /* The system must alert the operator and await intervention upon errors or quality failures. */
    }

    // ===== Verification =====
    verification def OperatorApprovalTest {
        subject cell : AssemblyCell;
        objective {
            doc /* Verify that the robot does not execute without operator approval. */
        }
    }

    verification def QualityInspectionTest {
        subject cell : AssemblyCell;
        objective {
            doc /* Verify that only passing parts are marked complete. */
        }
    }

    verification def ErrorHandlingTest {
        subject cell : AssemblyCell;
        objective {
            doc /* Verify that errors trigger operator alerts and interventions. */
        }
    }

    part testCellConfig : AssemblyCell;

    verification operatorApprovalTest : OperatorApprovalTest {
        subject testCell :> testCellConfig;
    }

    verification qualityInspectionTest : QualityInspectionTest {
        subject testCell :> testCellConfig;
    }

    verification errorHandlingTest : ErrorHandlingTest {
        subject testCell :> testCellConfig;
    }
}
