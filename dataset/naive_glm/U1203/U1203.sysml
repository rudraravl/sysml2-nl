package ManufacturingAssemblyCell {

    import SI::*;
    import ScalarValues::*;
    import ISQ::*;

    package Units {
        unit m = SI::Metre;
        unit s = SI::Second;
        unit N = SI::Newton;
        unit Nm = SI::Newton * SI::Metre;
        unit m_per_s = SI::Metre / SI::Second;
        unit kg = SI::Kilogram;
    }

    package ValueTypes {
        use Units::*;

        value type PositionCoordinate :> Real {
            unit m;
        }

        value type VelocityValue :> Real {
            unit m_per_s;
        }

        value type ForceValue :> Real {
            unit N;
        }

        value type TorqueValue :> Real {
            unit Nm;
        }

        value type ToleranceValue :> Real {
            unit m;
        }

        value type DurationValue :> Real {
            unit s;
        }

        value type MassValue :> Real {
            unit kg;
        }

        value type QualityScore :> Real;

        enum def InspectionResult {
            pass;
            fail;
        }

        enum def OperatingMode {
            idle;
            semiAutomatic;
            manual;
        }

        enum def TaskState {
            pending;
            awaitingApproval;
            approved;
            executing;
            inspecting;
            complete;
            error;
            failed;
        }

        enum def ApprovalStatus {
            notRequested;
            pending;
            approved;
            rejected;
        }

        enum def AlertType {
            info;
            warning;
            critical;
        }
    }

    package Items {
        use ValueTypes::*;

        item def Workpiece {
            attribute workpieceId: String;
            attribute jobId: String;
            attribute targetPosition: PositionCoordinate;
            attribute targetTorque: TorqueValue;
            attribute measuredPosition: PositionCoordinate;
            attribute measuredTorque: TorqueValue;
            attribute qualityScore: QualityScore;
            attribute finalInspection: InspectionResult;
            attribute isAssembled: Boolean;
            attribute isInspected: Boolean;
            attribute isLoaded: Boolean;
        }

        item def AssemblyJob {
            attribute jobId: String;
            attribute workpieceId: String;
            attribute targetPosition: PositionCoordinate;
            attribute targetTorque: TorqueValue;
            attribute requiredTolerance: ToleranceValue;
            attribute maxForceLimit: ForceValue;
            attribute isCritical: Boolean;
            attribute priority: Integer;
        }

        item def RobotMotionTrajectory {
            attribute waypoints: PositionCoordinate[0..*];
            attribute velocities: VelocityValue[0..*];
            attribute duration: DurationValue;
            attribute targetTorque: TorqueValue;
        }

        item def QualityReport {
            attribute workpieceId: String;
            attribute jobId: String;
            attribute result: InspectionResult;
            attribute qualityScore: QualityScore;
            attribute measuredTorque: TorqueValue;
            attribute measuredPosition: PositionCoordinate;
            attribute targetTorque: TorqueValue;
            attribute targetPosition: PositionCoordinate;
            attribute deviationFromSpec: ToleranceValue;
            attribute timestamp: DurationValue;
        }

        item def OperatorCommand {
            attribute commandId: String;
            attribute mode: OperatingMode;
            attribute instruction: String;
            attribute workpieceId: String;
        }

        item def TaskStatus {
            attribute jobId: String;
            attribute workpieceId: String;
            attribute state: TaskState;
            attribute completionPercentage: Real;
            attribute timestamp: DurationValue;
        }
    }

    package Ports {
        use ValueTypes::*;
        use Items::*;

        port def CoordinatorApprovalPort {
            out request: AssemblyJob;
            in response: ApprovalStatus;
        }

        port def OperatorApprovalPort {
            in request: AssemblyJob;
            out response: ApprovalStatus;
        }

        port def JobDispatchPort {
            out job: AssemblyJob;
            in jobAck: Boolean;
        }

        port def JobReceivePort {
            in job: AssemblyJob;
            out jobAck: Boolean;
        }

        port def MotionCommandPort {
            out trajectory: RobotMotionTrajectory;
            out torqueSetpoint: TorqueValue;
            in completionAck: Boolean;
            in withinTolerance: Boolean;
        }

        port def MotionExecutionPort {
            in trajectory: RobotMotionTrajectory;
            in torqueSetpoint: TorqueValue;
            out completionAck: Boolean;
            out withinTolerance: Boolean;
        }

        port def SensorFeedbackPort {
            out actualPosition: PositionCoordinate;
            out actualVelocity: VelocityValue;
            out appliedTorque: TorqueValue;
            out appliedForce: ForceValue;
            in sensorReadRequest: Boolean;
        }

        port def SensorReadPort {
            in actualPosition: PositionCoordinate;
            in actualVelocity: VelocityValue;
            in appliedTorque: TorqueValue;
            in appliedForce: ForceValue;
            out sensorReadRequest: Boolean;
        }

        port def TaskStatusOutPort {
            out status: TaskStatus;
        }

        port def TaskStatusInPort {
            in status: TaskStatus;
        }

        port def QualityReportOutPort {
            out report: QualityReport;
        }

        port def QualityReportInPort {
            in report: QualityReport;
        }

        port def WorkpieceFlowInPort {
            in workpiece: Workpiece;
        }

        port def WorkpieceFlowOutPort {
            out workpiece: Workpiece;
        }

        port def OperatorCommandOutPort {
            out command: OperatorCommand;
        }

        port def OperatorCommandInPort {
            in command: OperatorCommand;
        }

        port def AlertOutPort {
            out alertType: AlertType;
            out message: String;
            out workpieceId: String;
        }

        port def AlertInPort {
            in alertType: AlertType;
            in message: String;
            in workpieceId: String;
        }

        port def ModeOutPort {
            out mode: OperatingMode;
        }

        port def ModeInPort {
            in mode: OperatingMode;
        }

        port def JobInputPort {
            in job: AssemblyJob;
        }
    }

    package Parts {
        use ValueTypes::*;
        use Items::*;
        use Ports::*;

        part def OperatorStation {
            doc
                /* Human-machine interface where the operator supervises the cell,
                   monitors progress, approves critical tasks, and intervenes on errors. */
            attribute stationId: String;
            attribute currentMode: OperatingMode = OperatingMode::idle;
            attribute currentApproval: ApprovalStatus = ApprovalStatus::notRequested;
            attribute approvedJobId: String;
            attribute loggedAlerts: AlertType[0..*];
            attribute loggedStatusMessages: TaskStatus[0..*];
            attribute displayedStatus: TaskStatus;
            attribute criticalAlertActive: Boolean = false;

            port approvalPort: OperatorApprovalPort;
            port statusIn: TaskStatusInPort;
            port commandOut: OperatorCommandOutPort;
            port alertIn: AlertInPort;
            port modeOut: ModeOutPort;

            action def displayTaskStatus {
                in status: TaskStatus;
            }

            action def reviewQualityReport {
                in report: QualityReport;
            }

            action def captureOperatorApproval {
                in job: AssemblyJob;
                out status: ApprovalStatus;
            }

            action def generateInterventionCommand {
                in instruction: String;
                out command: OperatorCommand;
            }

            action def switchMode {
                in newMode: OperatingMode;
                out command: OperatorCommand;
            }

            state operatorStateMachine {
                entry {
                    currentApproval = ApprovalStatus::notRequested;
                    currentMode = OperatingMode::idle;
                }

                state idle;
                state monitoring;
                state awaitingDecision;
                state approving;
                state intervening;

                transition t_idle_to_monitoring
                    from idle to monitoring
                    when statusIn.status != null;

                transition t_monitoring_to_idle
                    from monitoring to idle
                    when statusIn.status.state == TaskState::complete;

                transition t_monitoring_to_awaiting
                    from monitoring to awaitingDecision
                    when approvalPort.request != null && approvalPort.request.isCritical == true;

                transition t_awaiting_to_approving
                    from awaitingDecision to approving
                    when currentApproval == ApprovalStatus::approved;

                transition t_awaiting_to_intervening
                    from awaitingDecision to intervening
                    when currentApproval == ApprovalStatus::rejected;

                transition t_approving_to_monitoring
                    from approving to monitoring
                    when currentApproval == ApprovalStatus::approved;

                transition t_monitoring_to_intervening
                    from monitoring to intervening
                    when criticalAlertActive == true;

                transition t_intervening_to_idle
                    from intervening to idle
                    when commandOut.command != null;
            }
        }

        part def RoboticManipulator {
            doc
                /* Physical robotic arm that performs precise assembly operations
                   under the command of the AutomatedController, with built-in
                   position and force/torque sensor feedback. */
            attribute armId: String;
            attribute currentEndEffectorPosition: PositionCoordinate;
            attribute currentAppliedTorque: TorqueValue;
            attribute currentAppliedForce: ForceValue;
            attribute currentVelocity: VelocityValue;
            attribute maxSafeTorque: TorqueValue = 60.0;
            attribute maxSafeForce: ForceValue = 600.0;
            attribute positionTolerance: ToleranceValue = 0.001;
            attribute withinTolerance: Boolean = true;
            attribute motionComplete: Boolean = false;
            attribute emergencyTriggered: Boolean = false;

            port motionIn: MotionExecutionPort;
            port sensorOut: SensorFeedbackPort;
            port workpieceOut: WorkpieceFlowOutPort;

            action def executeTrajectory {
                in trajectory: RobotMotionTrajectory;
                out position: PositionCoordinate;
                out torque: TorqueValue;
                out force: ForceValue;
                out complete: Boolean;
            }

            action def applyControlledTorque {
                in setpoint: TorqueValue;
                out measured: TorqueValue;
            }

            action def readSensorFeedback {
                out position: PositionCoordinate;
                out velocity: VelocityValue;
                out torque: TorqueValue;
                out force: ForceValue;
            }

            action def emergencyStop {
                out force: ForceValue;
                out torque: TorqueValue;
            }

            state manipulatorStateMachine {
                entry {
                    motionComplete = false;
                    withinTolerance = true;
                    emergencyTriggered = false;
                }

                state idle;
                state executing;
                state holding;
                state emergency;

                transition t_idle_to_executing
                    from idle to executing
                    when motionIn.trajectory != null;

                transition t_executing_to_holding
                    from executing to holding
                    when motionIn.completionAck == true;

                transition t_holding_to_idle
                    from holding to idle
                    when motionComplete == true;

                transition t_executing_to_emergency_force
                    from executing to emergency
                    when currentAppliedForce > maxSafeForce;

                transition t_executing_to_emergency_torque
                    from executing to emergency
                    when currentAppliedTorque > maxSafeTorque;

                transition t_holding_to_idle_after_unload
                    from holding to idle;
            }
        }

        part def AutomatedController {
            doc
                /* Translates high-level assembly instructions into a motion trajectory,
                   commands the RoboticManipulator, and continuously verifies that
                   sensor feedback remains within safety limits and tolerances. */
            attribute controllerId: String;
            attribute currentJob: AssemblyJob;
            attribute currentTrajectory: RobotMotionTrajectory;
            attribute targetTorque: TorqueValue;
            attribute maxAllowedTorque: TorqueValue = 50.0;
            attribute maxAllowedForce: ForceValue = 500.0;
            attribute positionTolerance: ToleranceValue = 0.001;
            attribute withinSafetyLimits: Boolean = true;
            attribute withinTolerance: Boolean = true;
            attribute motionComplete: Boolean = false;

            port jobIn: JobReceivePort;
            port motionOut: MotionCommandPort;
            port sensorIn: SensorReadPort;
            port statusOut: TaskStatusOutPort;

            action def generateTrajectory {
                in job: AssemblyJob;
                out trajectory: RobotMotionTrajectory;
            }

            action def sendMotionCommand {
                in trajectory: RobotMotionTrajectory;
                in torque: TorqueValue;
                out commandPort: MotionCommandPort;
            }

            action def monitorSensorFeedback {
                in position: PositionCoordinate;
                in torque: TorqueValue;
                in force: ForceValue;
                out withinSafety: Boolean;
                out withinTol: Boolean;
            }

            action def checkSafetyLimits {
                in torque: TorqueValue;
                in force: ForceValue;
                in maxTorque: TorqueValue;
                in maxForce: ForceValue;
                out safe: Boolean;
            }

            state controllerStateMachine {
                entry {
                    withinSafetyLimits = true;
                    withinTolerance = true;
                    motionComplete = false;
                }

                state idle;
                state planning;
                state commanding;
                state monitoringExecution;
                state completed;
                state safetyViolation;

                transition t_idle_to_planning
                    from idle to planning
                    when jobIn.job != null;

                transition t_planning_to_commanding
                    from planning to commanding;

                transition t_commanding_to_monitoring
                    from commanding to monitoringExecution;

                transition t_monitoring_to_completed
                    from monitoringExecution to completed
                    when motionOut.completionAck == true && motionOut.withinTolerance == true;

                transition t_monitoring_to_safety
                    from monitoringExecution to safetyViolation
                    when withinSafetyLimits == false;

                transition t_completed_to_idle
                    from completed to idle;

                transition t_safety_to_idle
                    from safetyViolation to idle;
            }
        }

        part def TaskCoordinator {
            doc
                /* Supervisor of the entire cell: maintains the job queue, requests
                   operator approval for critical jobs, dispatches approved jobs,
                   routes status and quality reports, and selects the operating mode. */
            attribute coordinatorId: String;
            attribute operatingMode: OperatingMode = OperatingMode::idle;
            attribute jobQueue: AssemblyJob[0..*];
            attribute currentJob: AssemblyJob;
            attribute currentTaskState: TaskState = TaskState::pending;
            attribute requiresApproval: Boolean = false;
            attribute maxConcurrentJobs: Integer = 1;
            attribute completedJobCount: Integer = 0;
            attribute failedJobCount: Integer = 0;
            attribute activeAlert: AlertType = AlertType::info;

            port jobInput: JobInputPort;
            port approvalOut: CoordinatorApprovalPort;
            port controllerJobOut: JobDispatchPort;
            port statusOut: TaskStatusOutPort;
            port controllerStatusIn: TaskStatusInPort;
            port qualityReportIn: QualityReportInPort;
            port commandIn: OperatorCommandInPort;
            port alertOut: AlertOutPort;
            port modeIn: ModeInPort;

            action def scheduleNextJob {
                in queue: AssemblyJob[0..*];
                out nextJob: AssemblyJob;
            }

            action def requestApproval {
                in job: AssemblyJob;
                out approvalPort: CoordinatorApprovalPort;
            }

            action def dispatchJob {
                in job: AssemblyJob;
                out dispatchPort: JobDispatchPort;
            }

            action def updateTaskStatus {
                in newState: TaskState;
                in jobId: String;
                out status: TaskStatus;
            }

            action def handleQualityResult {
                in report: QualityReport;
                out alert: AlertType;
            }

            state coordinatorStateMachine {
                entry {
                    operatingMode = OperatingMode::idle;
                    currentTaskState = TaskState::pending;
                }

                state idle;
                state scheduling;
                state awaitingApproval;
                state dispatching;
                state monitoring;
                state inspecting;
                state completing;
                state errorRecovery;

                transition t_idle_to_scheduling
                    from idle to scheduling
                    when jobInput.job != null;

                transition t_scheduling_to_awaiting
                    from scheduling to awaitingApproval
                    when currentJob.isCritical == true;

                transition t_scheduling_to_dispatching
                    from scheduling to dispatching
                    when currentJob.isCritical == false;

                transition t_awaiting_to_dispatching
                    from awaitingApproval to dispatching
                    when approvalOut.response == ApprovalStatus::approved;

                transition t_awaiting_to_error
                    from awaitingApproval to errorRecovery
                    when approvalOut.response == ApprovalStatus::rejected;

                transition t_dispatching_to_monitoring
                    from dispatching to monitoring;

                transition t_monitoring_to_inspecting
                    from monitoring to inspecting
                    when controllerStatusIn.status.state == TaskState::executing
                        && controllerStatusIn.status.completionPercentage >= 100.0;

                transition t_inspecting_to_completing
                    from inspecting to completing
                    when qualityReportIn.report.result == InspectionResult::pass;

                transition t_inspecting_to_error
                    from inspecting to errorRecovery
                    when qualityReportIn.report.result == InspectionResult::fail;

                transition t_completing_to_idle
                    from completing to idle;

                transition t_error_to_idle
                    from errorRecovery to idle
                    when commandIn.command.mode == OperatingMode::idle;
            }
        }

        part def QualityInspectionUnit {
            doc
                /* Automated post-assembly inspection unit that verifies each
                   workpiece against acceptance criteria and emits a pass/fail
                   QualityReport to the TaskCoordinator. */
            attribute unitId: String;
            attribute maxAllowedDeviation: ToleranceValue = 0.0005;
            attribute minRequiredQualityScore: QualityScore = 0.85;
            attribute lastReport: QualityReport;
            attribute passCount: Integer = 0;
            attribute failCount: Integer = 0;
            attribute inspectionInProgress: Boolean = false;

            port workpieceIn: WorkpieceFlowInPort;
            port reportOut: QualityReportOutPort;

            action def inspectWorkpiece {
                in workpiece: Workpiece;
                out report: QualityReport;
            }

            action def evaluateCriteria {
                in measuredTorque: TorqueValue;
                in measuredPosition: PositionCoordinate;
                in targetTorque: TorqueValue;
                in targetPosition: PositionCoordinate;
                in maxDeviation: ToleranceValue;
                out result: InspectionResult;
                out score: QualityScore;
            }

            action def generateQualityReport {
                in workpiece: Workpiece;
                in result: InspectionResult;
                in score: QualityScore;
                out report: QualityReport;
            }

            state inspectionStateMachine {
                state idle;
                state inspecting;
                state evaluating;
                state reporting;
                state passed;
                state failed;

                transition t_idle_to_inspecting
                    from idle to inspecting
                    when workpieceIn.workpiece != null && workpieceIn.workpiece.isAssembled == true;

                transition t_inspecting_to_evaluating
                    from inspecting to evaluating;

                transition t_evaluating_to_reporting
                    from evaluating to reporting;

                transition t_reporting_to_passed
                    from reporting to passed
                    when lastReport.result == InspectionResult::pass;

                transition t_reporting_to_failed
                    from reporting to failed
                    when lastReport.result == InspectionResult::fail;

                transition t_passed_to_idle
                    from passed to idle;

                transition t_failed_to_idle
                    from failed to idle;
            }
        }

        part def AssemblyCell {
            doc
                /* Integrated semi-automated manufacturing assembly cell that combines
                   human operator oversight with robotic precision. Composes the
                   OperatorStation, RoboticManipulator, AutomatedController,
                   TaskCoordinator, and QualityInspectionUnit and wires them together. */
            attribute cellId: String;
            attribute cellName: String;
            attribute maxConcurrentJobs: Integer = 1;
            attribute totalProcessedCount: Integer = 0;
            attribute totalPassCount: Integer = 0;
            attribute totalFailCount: Integer = 0;
            attribute currentMode: OperatingMode = OperatingMode::idle;

            part operatorStation: OperatorStation;
            part robotArm: RoboticManipulator;
            part controller: AutomatedController;
            part coordinator: TaskCoordinator;
            part inspection: QualityInspectionUnit;

            connect coordinator.approvalOut to operatorStation.approvalPort;
            connect coordinator.statusOut to operatorStation.statusIn;
            connect operatorStation.commandOut to coordinator.commandIn;
            connect operatorStation.modeOut to coordinator.modeIn;
            connect coordinator.alertOut to operatorStation.alertIn;
            connect coordinator.controllerJobOut to controller.jobIn;
            connect controller.motionOut to robotArm.motionIn;
            connect robotArm.sensorOut to controller.sensorIn;
            connect controller.statusOut to coordinator.controllerStatusIn;
            connect robotArm.workpieceOut to inspection.workpieceIn;
            connect inspection.reportOut to coordinator.qualityReportIn;

            state cellStateMachine {
                entry { currentMode = OperatingMode::idle; }

                state initializing;
                state ready;
                state processing;
                state inspecting;
                state completed;
                state errorHandling;

                transition t_init_to_ready
                    from initializing to ready;

                transition t_ready_to_processing
                    from ready to processing
                    when coordinator.currentTaskState == TaskState::executing;

                transition t_processing_to_inspecting
                    from processing to inspecting
                    when robotArm.motionComplete == true;

                transition t_inspecting_to_completed
                    from inspecting to completed
                    when inspection.lastReport.result == InspectionResult::pass;

                transition t_inspecting_to_error
                    from inspecting to errorHandling
                    when inspection.lastReport.result == InspectionResult::fail;

                transition t_completed_to_ready
                    from completed to ready;

                transition t_processing_to_error_safety
                    from processing to errorHandling
                    when controller.withinSafetyLimits == false;

                transition t_error_to_ready
                    from errorHandling to ready
                    when operatorStation.currentMode == OperatingMode::idle;
            }
        }
    }

    package Requirements {
        use ValueTypes::*;
        use Items::*;
        use Parts::*;
        use Ports::*;

        requirement def OperatorApprovalRequirement {
            doc
                /* Critical assembly steps require explicit operator approval before
                   the robot may begin the corresponding physical assembly operation. */
            subject cell: AssemblyCell;
            attribute approvalTimeout: DurationValue;
            objective {
                /* For every AssemblyJob with isCritical == true, the TaskCoordinator
                   shall not dispatch the job to the AutomatedController until
                   OperatorStation.approvalPort.response == ApprovalStatus::approved. */
            }
        }

        requirement def RobotPrecisionRequirement {
            doc
                /* The robotic manipulator shall achieve the target end-effector
                   position within the specified tolerance and shall apply the
                   specified torque within the specified torque error. */
            subject robot: RoboticManipulator;
            attribute maxPositionTolerance: ToleranceValue;
            attribute maxTorqueError: TorqueValue;
            objective {
                /* The RoboticManipulator shall position the end effector within
                   maxPositionTolerance of AssemblyJob.targetPosition and shall
                   apply torque within maxTorqueError of AssemblyJob.targetTorque. */
            }
        }

        requirement def SafetyLimitsRequirement {
            doc
                /* The Automated Controller shall continuously enforce force and
                   torque safety limits on the RoboticManipulator and shall
                   trigger an emergency stop on limit violation. */
            subject controller: AutomatedController;
            attribute maxAllowedForce: ForceValue;
            attribute maxAllowedTorque: TorqueValue;
            objective {
                /* The AutomatedController shall monitor sensor feedback from the
                   RoboticManipulator and shall command an emergency stop whenever
                   appliedForce exceeds maxAllowedForce or appliedTorque exceeds
                   maxAllowedTorque. */
            }
        }

        requirement def QualityInspectionRequirement {
            doc
                /* Every assembled workpiece shall be inspected by the Quality
                   Inspection Unit before being unloaded from the cell. */
            subject inspection: QualityInspectionUnit;
            attribute minRequiredQualityScore: QualityScore;
            objective {
                /* Each workpiece processed by the AssemblyCell shall receive a
                   quality inspection by the QualityInspectionUnit, and the
                   resulting QualityReport shall be forwarded to the
                   TaskCoordinator before the workpiece is unloaded. */
            }
        }

        requirement def TaskCoordinatorSynchronizationRequirement {
            doc
                /* The Task Coordinator shall synchronize the operator, controller,
                   and inspection subsystems and act as the central workflow hub. */
            subject coordinator: TaskCoordinator;
            objective {
                /* The TaskCoordinator shall maintain the job queue, request
                   operator approval for critical jobs, dispatch approved jobs
                   to the AutomatedController, propagate task status to the
                   OperatorStation, and route QualityReports to the appropriate
                   downstream behavior. */
            }
        }

        requirement def OperatorInterventionRequirement {
            doc
                /* The operator shall be able to intervene and provide further
                   instructions in case of errors or quality failures. */
            subject station: OperatorStation;
            objective {
                /* When the TaskCoordinator raises a critical alert or when the
                   QualityInspectionUnit reports a fail, the OperatorStation shall
                   allow the operator to issue an OperatorCommand to direct the
                   next course of action. */
            }
        }

        requirement operatorApprovalReq : OperatorApprovalRequirement {
            :>> subject cell = AssemblyCell;
            :>> approvalTimeout = 30.0;
        }

        requirement robotPrecisionReq : RobotPrecisionRequirement {
            :>> subject robot = RoboticManipulator;
            :>> maxPositionTolerance = 0.001;
            :>> maxTorqueError = 0.05;
        }

        requirement safetyLimitsReq : SafetyLimitsRequirement {
            :>> subject controller = AutomatedController;
            :>> maxAllowedForce = 500.0;
            :>> maxAllowedTorque = 50.0;
        }

        requirement qualityInspectionReq : QualityInspectionRequirement {
            :>> subject inspection = QualityInspectionUnit;
            :>> minRequiredQualityScore = 0.85;
        }

        requirement coordinatorSyncReq : TaskCoordinatorSynchronizationRequirement {
            :>> subject coordinator = TaskCoordinator;
        }

        requirement operatorInterventionReq : OperatorInterventionRequirement {
            :>> subject station = OperatorStation;
        }

        satisfy operatorApprovalReq
            by OperatorStation::operatorStateMachine;
        satisfy operatorApprovalReq
            by TaskCoordinator::coordinatorStateMachine;
        satisfy robotPrecisionReq
            by RoboticManipulator::manipulatorStateMachine;
        satisfy safetyLimitsReq
            by AutomatedController::controllerStateMachine;
        satisfy qualityInspectionReq
            by QualityInspectionUnit::inspectionStateMachine;
        satisfy coordinatorSyncReq
            by TaskCoordinator::coordinatorStateMachine;
        satisfy operatorInterventionReq
            by OperatorStation::operatorStateMachine;
    }
}
