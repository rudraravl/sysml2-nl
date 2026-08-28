package EthicalManipulatorArmModel {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types with Units ----------
    value type Length_mm :> Real { unit 'mm'; }
    value type Length_m :> Real { unit 'm'; }
    value type Mass_kg :> Real { unit 'kg'; }
    value type Force_N :> Real { unit 'N'; }
    value type Torque_Nm :> Real {> Real { unit 'Nm'; }
    value type Angle_deg :> Real { unit 'deg'; }
    value type Angle_rad :> Real { unit 'rad'; }
    value type Power_W :> Real { unit 'W'; }
    value type Frequency_Hz :> Real { unit 'Hz'; }
    value type Probability :> Real { unit '1'; }
    value type Distance_m :> Real { unit 'm'; }
    value type Confidence :> Real { unit '1'; min = 0; max = 1; }

    // ---------- Enumerations ----------
    enum def EthicalDecision {
        approve;
        deny;
        requestHumanReview;
    }

    enum def TaskStatus {
        pending;
        underEthicalEvaluation;
        approved;
        denied;
        awaitingHumanConfirmation;
        executing;
        completed;
        aborted;
    }

    enum def HarmLevel {
        none;
        low;
        moderate;
        high;
        severe;
    }

    enum def AutonomyRespectLevel {
        fullyRespected;
        partiallyRespected;
        notRespected;
    }

    enum def ObjectClass {
        human;
        delicateObject;
        rigidObject;
        unknown;
    }

    // ---------- Item Definitions ----------
    item def TaskRequest {
        attribute taskId : String;
        attribute description : String;
        attribute targetObject : String;
        attribute requestedForce : Force_N;
        attribute priority : Integer;
    }

    item def EnvironmentalContext {
        attribute humanProximity : Distance_m;
        attribute objectProximity : Distance_m;
        attribute detectedObjects : List<ObjectClass>;
        attribute workspaceClear : Boolean;
        attribute timestamp : String;
    }

    item def EthicalAssessment {
        attribute harmPotential : HarmLevel;
        autonomyRespect : AutonomyRespectLevel;
        attribute benefitScore : Confidence;
        attribute riskScore : Confidence;
        attribute decision : EthicalDecision;
        attribute rationale : String;
    }

    item def JointCommand {
        attribute jointId : Integer;
        attribute targetAngle : Angle_rad;
        attribute maxVelocity : Angle_rad;
    }

    item def GripperCommand {
        attribute open : Boolean;
        attribute gripForce : Force_N;
    }

    item def SensorReading {
        attribute sensorId : String;
        attribute distance : Distance_m;
        attribute confidence : Confidence;
        attribute timestamp : String;
    }

    item def VisionData {
        attribute detectedObjects : List<ObjectClass>;
        attribute objectPositions : List<Distance_m>;
        attribute confidence : Confidence;
    }

    item def ForceTorqueReading {
        attribute forceX : Force_N;
        attribute forceY : Force_N;
        attribute forceZ : Force_N;
        attribute torqueX : Torque_Nm;
        attribute torqueY : Torque_Nm;
        attribute torqueZ : Torque_Nm;
    }

    item def HumanOperatorFeedback {
        attribute taskId : String;
        attribute approved : Boolean;
        attribute comments : String;
    }

    // ---------- Port Definitions ----------
    port def SensorDataPort {
        out reading : SensorReading;
    }

    port def VisionDataPort {
        out data : VisionData;
    }

    port def ForceTorqueDataPort {
        out reading : ForceTorqueReading;
    }

    port def CommandPort {
        in command : JointCommand;
    }

    port def GripperCommandPort {
        in command : GripperCommand;
    }

    port def TaskRequestPort {
        in request : TaskRequest;
    }

    port def EthicalDecisionPort {
        out assessment : EthicalAssessment;
    }

    port def HumanFeedbackPort {
        in feedback : HumanOperatorFeedback;
        out requestReview : TaskRequest;
    }

    port def ContextDataPort {
        out context : EnvironmentalContext;
    }

    // ---------- Interfaces ----------
    interface def SensorToEthicsInterface {
        end supplier : SensorDataPort;
        end consumer : ContextDataPort;
    }

    interface def EthicsToControlInterface {
        end supplier : EthicalDecisionPort;
        end consumer : EthicalDecisionPort;
    }

    // ---------- Part Definitions: Sensors ----------
    part def ProximitySensor {
        attribute sensorId : String;
        attribute maxRange : Distance_m = 3.0;
        attribute detectionRadius : Distance_m = 3.0;
        attribute updateRate : Frequency_Hz = 50.0;
        port sensorOut : SensorDataPort;
    }

    part def VisionSystem {
        attribute resolution : String = "4096x2160";
        attribute frameRate : Frequency_Hz = 30.0;
        attribute fieldOfView : Angle_deg = 120.0;
        port visionOut : VisionDataPort;
    }

    part def ForceTorqueSensor {
        attribute maxForce : Force_N = 200.0;
        attribute maxTorque : Torque_Nm = 20.0;
        attribute updateRate : Frequency_Hz = 1000.0;
        port ftOut : ForceTorqueDataPort;
    }

    // ---------- Part Definitions: Arm Components ----------
    part def Joint {
        attribute jointId : Integer;
        attribute jointType : String;
        attribute minAngle : Angle_rad;
        attribute maxAngle : Angle_rad;
        attribute maxTorque : Torque_Nm;
        attribute currentAngle : Angle_rad;
        port cmdIn : CommandPort;
    }

    part def Gripper {
        attribute maxGripForce : Force_N = 50.0;
        attribute isOpen : Boolean = true;
        attribute currentGripForce : Force_N = 0.0;
        port gripperCmdIn : GripperCommandPort;
    }

    part def EndEffector {
        part gripper : Gripper;
        part forceTorqueSensor : ForceTorqueSensor;
    }

    part def RoboticArm {
        attribute maxReach : Length_m = 1.5;
        attribute payloadCapacity : Mass_kg = 10.0;
        attribute axisCount : Integer = 6;

        part joints : Joint[6] {
            part joint1 : Joint { :>> jointId = 1; :>> jointType = "base_rotation"; :>> minAngle = -3.14159; :>> maxAngle = 3.14159; :>> maxTorque = 150.0; }
            part joint2 : Joint { :>> jointId = 2; :>> jointType = "shoulder_pitch"; :>> minAngle = -1.5708; :>> maxAngle = 1.5708; :>> maxTorque = 200.0; }
            part joint3 : Joint { :>> jointId = 3; :>> jointType = "elbow_pitch"; :>> minAngle = -2.3562; :>> maxAngle = 2.3562; :>> maxTorque = 120.0; }
            part joint4 : Joint { :>> jointId = 4; :>> jointType = "wrist_roll"; :>> minAngle = -3.14159; :>> maxAngle = 3.14159; :>> maxTorque = 50.0; }
            part joint5 : Joint { :>> jointId = 5; :>> jointType = "wrist_pitch"; :>> minAngle = -1.5708; :>> maxAngle = 1.5708; :>> maxTorque = 40.0; }
            part joint6 : Joint { :>> jointId = 6; :>> jointType = "wrist_yaw"; :>> minAngle = -3.14159; :>> maxAngle = 3.14159; :>> maxTorque = 30.0; }
        }

        part endEffector : EndEffector;

        port jointCommandPorts : CommandPort[6];
        port gripperCommandPort : GripperCommandPort;
    }

    // ---------- Ethical Reasoning Unit ----------
    part def EthicalReasoningUnit {
        attribute corePrinciples : List<String> = ["do_no_harm", "respect_autonomy", "maximize_benefit", "minimize_risk"];
        attribute humanProximityThreshold : Distance_m = 1.0;
        attribute forceThreshold : Force_N = 20.0;
        attribute riskTolerance : Confidence = 0.3;

        port contextIn : ContextDataPort;
        port visionIn : VisionDataPort;
        port forceTorqueIn : ForceTorqueDataPort;
        port taskIn : TaskRequestPort;
        port decisionOut : EthicalDecisionPort;
        port humanFeedback : HumanFeedbackPort;

        attribute currentAssessment : EthicalAssessment;

        // State machine for ethical evaluation
        state def EthicalEvaluationStateMachine {
            entry; then Idle;

            state Idle {
                entry { /* waiting for task */ }
            }

            transition from Idle to GatheringContext
                when taskIn.request != null;

            state GatheringContext {
                entry { /* collect sensor data, vision data, force-torque data */ }
            }

            transition from GatheringContext to AssessingHarm
                when contextIn.context != null && visionIn.data != null;

            state AssessingHarm {
                entry { /* evaluate harm potential based on proximity and force */ }
            }

            transition from AssessingHarm to AssessingBenefit;

            state AssessingBenefit {
                entry { /* evaluate task benefit score */ }
            }

            transition from AssessingBenefit to AssessingAutonomy;

            state AssessingAutonomy {
                entry { /* evaluate whether action respects human autonomy */ }
            }

            transition from AssessingAutonomy to Decision;

            state Decision {
                entry { /* generate final ethical decision */ }
            }

            transition from Decision to Approved
                when currentAssessment.decision == EthicalDecision::approve;

            transition from Decision to Denied
                when currentAssessment.decision == EthicalDecision::deny;

            transition from Decision to AwaitingHumanReview
                when currentAssessment.decision == EthicalDecision::requestHumanReview;

            state Approved {
                entry { /* emit approval to control system */ }
            }

            state Denied {
                entry { /* emit denial, task aborted */ }
            }

            state AwaitingHumanReview {
                entry { /* send task to human operator for review */ }
            }

            transition from AwaitingHumanReview to Approved
                when humanFeedback.feedback.approved == true;

            transition from AwaitingHumanReview to Denied
                when humanFeedback.feedback.approved == false;

            transition from Approved to Idle;
            transition from Denied to Idle;
        }

        // Action to evaluate harm
        action def EvaluateHarmPotential {
            in context : EnvironmentalContext;
            in task : TaskRequest;
            in ftReading : ForceTorqueReading;
            out harmLevel : HarmLevel;

            // If human is within 1m and force exceeds threshold, harm is high
            if context.humanProximity <= 1.0 && task.requestedForce > 20.0 {
                harmLevel = HarmLevel::high;
            } else if context.humanProximity <= 2.0 {
                harmLevel = HarmLevel::moderate;
            } else if task.requestedForce > 50.0 {
                harmLevel = HarmLevel::moderate;
            } else {
                harmLevel = HarmLevel::low;
            }
        }

        // Action to evaluate autonomy respect
        action def EvaluateAutonomyRespect {
            in context : EnvironmentalContext;
            in task : TaskRequest;
            out autonomyLevel : AutonomyRespectLevel;

            if context.workspaceClear == true {
                autonomyLevel = AutonomyRespectLevel::fullyRespected;
            } else if context.humanProximity > 1.5 {
                autonomyLevel = AutonomyRespectLevel::partiallyRespected;
            } else {
                autonomyLevel = AutonomyRespectLevel::notRespected;
            }
        }

        // Action to generate final decision
        action def GenerateDecision {
            in harmLevel : HarmLevel;
            in autonomyLevel : AutonomyRespectLevel;
            in benefitScore : Confidence;
            in riskScore : Confidence;
            out assessment : EthicalAssessment;

            if harmLevel == HarmLevel::severe || harmLevel == HarmLevel::high {
                assessment.decision = EthicalDecision::deny;
                assessment.rationale = "Harm potential too high; action denied per do_no_harm principle.";
            } else if harmLevel == HarmLevel::moderate || autonomyLevel == AutonomyRespectLevel::notRespected {
                assessment.decision = EthicalDecision::requestHumanReview;
                assessment.rationale = "Moderate risk or autonomy concern; human review required.";
            } else {
                assessment.decision = EthicalDecision::approve;
                assessment.rationale = "Task is safe and ethically sound; approved for execution.";
            }
        }
    }

    // ---------- Main Control System ----------
    part def ControlSystem {
        attribute controlLoopRate : Frequency_Hz = 200.0;
        attribute currentTaskStatus : TaskStatus = TaskStatus::pending;

        port taskIn : TaskRequestPort;
        port ethicsDecisionIn : EthicalDecisionPort;
        port jointCommandOut : CommandPort[6];
        port gripperCommandOut : GripperCommandPort;

        state def ControlStateMachine {
            entry; then WaitingForTask;

            state WaitingForTask;

            transition from WaitingForTask to AwaitingEthicalApproval
                when taskIn.request != null;

            state AwaitingEthicalApproval {
                entry { /* task received, waiting for ethical engine decision */ }
            }

            transition from AwaitingEthicalApproval to PlanningMotion
                when ethicsDecisionIn.assessment.decision == EthicalDecision::approve;

            transition from AwaitingEthicalApproval to TaskAborted
                when ethicsDecisionIn.assessment.decision == EthicalDecision::deny;

            transition from AwaitingEthicalApproval to WaitingForHumanConfirmation
                when ethicsDecisionIn.assessment.decision == EthicalDecision::requestHumanReview;

            state WaitingForHumanConfirmation {
                entry { /* paused, awaiting human operator input */ }
            }

            transition from WaitingForHumanConfirmation to PlanningMotion
                when ethicsDecisionIn.assessment.decision == EthicalDecision::approve;

            transition from WaitingForHumanConfirmation to TaskAborted
                when ethicsDecisionIn.assessment.decision == EthicalDecision::deny;

            state PlanningMotion {
                entry { /* calculate inverse kinematics and trajectory for 6-axis arm */ }
            }

            transition from PlanningMotion to ExecutingMotion;

            state ExecutingMotion {
                entry { /* send joint commands and gripper commands */ }
            }

            transition from ExecutingMotion to TaskCompleted
                when currentTaskStatus == TaskStatus::completed;

            state TaskCompleted;

            transition from TaskCompleted to WaitingForTask;

            state TaskAborted;

            transition from TaskAborted to WaitingForTask;
        }

        // Action for trajectory planning
        action def PlanTrajectory {
            in task : TaskRequest;
            in armState : RoboticArm;
            out jointCommands : List<JointCommand>;
            out gripperCommand : GripperCommand;

            // Compute inverse kinematics for 6-axis arm
            // Generate joint angle targets within limits
            // Ensure smooth trajectory with velocity limits
        }

        // Action for executing motion
        action def ExecuteMotion {
            in jointCommands : List<JointCommand>;
            in gripperCommand : GripperCommand;
            out status : TaskStatus;

            // Send commands to joints and gripper
            // Monitor force-torque feedback for safety
        }
    }

    // ---------- Human Operator Interface ----------
    part def HumanOperatorInterface {
        attribute operatorId : String;
        port feedbackOut : HumanFeedbackPort;
        port reviewRequestIn : HumanFeedbackPort;

        action def ReviewTask {
            in task : TaskRequest;
            in assessment : EthicalAssessment;
            out feedback : HumanOperatorFeedback;
        }
    }

    // ---------- Sensor Suite ----------
    part def SensorSuite {
        attribute detectionRadius : Distance_m = 3.0;

        part proximitySensors : ProximitySensor[4] {
            part frontSensor : ProximitySensor { :>> sensorId = "prox_front"; }
            part leftSensor : ProximitySensor { :>> sensorId = "prox_left"; }
            part rightSensor : ProximitySensor { :>> sensorId = "prox_right"; }
            part rearSensor : ProximitySensor { :>> sensorId = "prox_rear"; }
        }

        part visionSystem : VisionSystem;
    }

    // ---------- Top-Level System ----------
    part def EthicalRoboticManipulator {
        attribute systemName : String = "EthicalManipulator_v1";
        attribute firmwareVersion : String = "1.0.0";

        part arm : RoboticArm;
        part sensorSuite : SensorSuite;
        part ethicalReasoningUnit : EthicalReasoningUnit;
        part controlSystem : ControlSystem;
        part humanOperatorInterface : HumanOperatorInterface;

        // Connect proximity sensors to ethical reasoning unit
        connection : SensorToEthicsInterface connect sensorSuite.proximitySensors.frontSensor.sensorOut to ethicalReasoningUnit.contextIn;
        connection : SensorToEthicsInterface connect sensorSuite.proximitySensors.leftSensor.sensorOut to ethicalReasoningUnit.contextIn;
        connection : SensorToEthicsInterface connect sensorSuite.proximitySensors.rightSensor.sensorOut to ethicalReasoningUnit.contextIn;
        connection : SensorToEthicsInterface connect sensorSuite.proximitySensors.rearSensor.sensorOut to ethicalReasoningUnit.contextIn;

        // Connect vision system to ethical reasoning unit
        flow from sensorSuite.visionSystem.visionOut.data to ethicalReasoningUnit.visionIn.data;

        // Connect force-torque sensor to ethical reasoning unit
        flow from arm.endEffector.forceTorqueSensor.ftOut.reading to ethicalReasoningUnit.forceTorqueIn.reading;

        // Connect ethical reasoning unit decision to control system
        flow from ethicalReasoningUnit.decisionOut.assessment to controlSystem.ethicsDecisionIn.assessment;

        // Connect task request to both ethical reasoning unit and control system
        flow to ethicalReasoningUnit.taskIn.request;
        flow to controlSystem.taskIn.request;

        // Connect control system to arm joints
        flow from controlSystem.jointCommandOut[1].command to arm.jointCommandPorts[1].command;
        flow from controlSystem.jointCommandOut[2].command to arm.jointCommandPorts[2].command;
        flow from controlSystem.jointCommandOut[3].command to arm.jointCommandPorts[3].command;
        flow from controlSystem.jointCommandOut[4].command to arm.jointCommandPorts[4].command;
        flow from controlSystem.jointCommandOut[5].command to arm.jointCommandPorts[5].command;
        flow from controlSystem.jointCommandOut[6].command to arm.jointCommandPorts[6].command;

        // Connect control system to gripper
        flow from controlSystem.gripperCommandOut.command to arm.gripperCommandPort.command;

        // Connect ethical reasoning unit to human operator interface for review
        flow from ethicalReasoningUnit.humanFeedback.requestReview to humanOperatorInterface.reviewRequestIn.requestReview;
        flow from humanOperatorInterface.feedbackOut.feedback to ethicalReasoningUnit.humanFeedback.feedback;
    }

    // ---------- Requirements ----------
    package Requirements {

        requirement def PhysicalSpecificationRequirement {
            doc /* The robotic arm shall be a six-axis arm with specified reach and payload. */
            attribute requiredAxes : Integer = 6;
            attribute requiredMaxReach : Length_m = 1.5;
            attribute requiredPayloadCapacity : Mass_kg = 10.0;
            require arm.axisCount == requiredAxes;
            require arm.maxReach <= requiredMaxReach;
            require arm.payloadCapacity >= requiredPayloadCapacity;
        }

        requirement def GripperRequirement {
            doc /* The system shall be equipped with a gripper for manipulating objects. */
            require arm.endEffector.gripper != null;
        }

        requirement def ProximitySensorRequirement {
            doc /* The system shall have four proximity sensors detecting objects and people within a 3-meter radius. */
            attribute requiredSensorCount : Integer = 4;
            attribute requiredDetectionRadius : Distance_m = 3.0;
            require sensorSuite.proximitySensors.size == requiredSensorCount;
            require sensorSuite.detectionRadius >= requiredDetectionRadius;
        }

        requirement def VisionSystemRequirement {
            doc /* The system shall include a high-resolution vision system for visual analysis. */
            require sensorSuite.visionSystem != null;
            require sensorSuite.visionSystem.resolution == "4096x2160";
        }

        requirement def ForceTorqueSensorRequirement {
            doc /* The end-effector shall include a force-torque sensor to measure physical forces. */
            require arm.endEffector.forceTorqueSensor != null;
        }

        requirement def EthicalReasoningRequirement {
            doc /* Before executing any command, the system shall perform a comprehensive ethical evaluation. */
            require ethicalReasoningUnit != null;
            require ethicalReasoningUnit.corePrinciples.contains("do_no_harm");
            require ethicalReasoningUnit.corePrinciples.contains("respect_autonomy");
        }

        requirement def HarmAssessmentRequirement {
            doc /* The ethical evaluation shall assess potential for harm considering proximity to humans and required force. */
            require ethicalReasoningUnit.humanProximityThreshold == 1.0;
            require ethicalReasoningUnit.forceThreshold == 20.0;
        }

        requirement def EthicalDecisionRequirement {
            doc /* The ethical engine shall generate a decision: approve, deny, or flag for human review. */
            require ethicalReasoningUnit.decisionOut.assessment.decision in {EthicalDecision::approve, EthicalDecision::deny, EthicalDecision::requestHumanReview};
        }

        requirement def HumanInLoopRequirement {
            doc /* For complex or potentially hazardous situations, the system shall request human confirmation. */
            require ethicalReasoningUnit.humanFeedback != null;
            require humanOperatorInterface != null;
        }

        requirement def AutonomousSafeOperationRequirement {
            doc /* The robot shall handle routine safe tasks independently and defer to human judgment when ethical questions arise. */
            require controlSystem.currentTaskStatus == TaskStatus::approved when ethicalReasoningUnit.decisionOut.assessment.decision == EthicalDecision::approve;
            require controlSystem.currentTaskStatus == TaskStatus::awaitingHumanConfirmation when ethicalReasoningUnit.decisionOut.assessment.decision == EthicalDecision::requestHumanReview;
        }

        requirement def NoImmediateMovementRequirement {
            doc /* Upon receiving a task, the robot shall not move until the ethical engine has assessed the situation. */
            require controlSystem.ControlStateMachine.AwaitingEthicalApproval.active == true when controlSystem.taskIn.request != null && ethicalReasoningUnit.decisionOut.assessment == null;
        }

        requirement def CollaborativeOperationRequirement {
            doc /* The system shall operate collaboratively, handling routine tasks independently while deferring to human judgment for ethical questions. */
            require ethicalReasoningUnit.EthicalEvaluationStateMachine.AwaitingHumanReview.active == true when ethicalReasoningUnit.currentAssessment.decision == EthicalDecision::requestHumanReview;
        }

        requirement physicalSpecReq : PhysicalSpecificationRequirement {
            subject arm : RoboticArm;
        }

        requirement gripperReq : GripperRequirement {
            subject arm : RoboticArm;
        }

        requirement proximityReq : ProximitySensorRequirement {
            subject sensorSuite : SensorSuite;
        }

        requirement visionReq : VisionSystemRequirement {
            subject sensorSuite : SensorSuite;
        }

        requirement forceTorqueReq : ForceTorqueSensorRequirement {
            subject arm : RoboticArm;
        }

        requirement ethicalReasoningReq : EthicalReasoningRequirement {
            subject ethicalReasoningUnit : EthicalReasoningUnit;
        }

        requirement harmAssessmentReq : HarmAssessmentRequirement {
            subject ethicalReasoningUnit : EthicalReasoningUnit;
        }

        requirement ethicalDecisionReq : EthicalDecisionRequirement {
            subject ethicalReasoningUnit : EthicalReasoningUnit;
        }

        requirement humanInLoopReq : HumanInLoopRequirement {
            subject ethicalReasoningUnit : EthicalReasoningUnit;
            subject humanOperatorInterface : HumanOperatorInterface;
        }

        requirement autonomousSafeOpReq : AutonomousSafeOperationRequirement {
            subject controlSystem : ControlSystem;
            subject ethicalReasoningUnit : EthicalReasoningUnit;
        }

        requirement noImmediateMovementReq : NoImmediateMovementRequirement {
            subject controlSystem : ControlSystem;
            subject ethicalReasoningUnit : EthicalReasoningUnit;
        }

        requirement collaborativeOpReq : CollaborativeOperationRequirement {
            subject ethicalReasoningUnit : EthicalReasoningUnit;
        }
    }

    // ---------- System-level requirement satisfaction ----------
    part systemInstance : EthicalRoboticManipulator {
        satisfy Requirements::physicalSpecReq by arm;
        satisfy Requirements::gripperReq by arm;
        satisfy Requirements::proximityReq by sensorSuite;
        satisfy Requirements::visionReq by sensorSuite;
        satisfy Requirements::forceTorqueReq by arm;
        satisfy Requirements::ethicalReasoningReq by ethicalReasoningUnit;
        satisfy Requirements::harmAssessmentReq by ethicalReasoningUnit;
        satisfy Requirements::ethicalDecisionReq by ethicalReasoningUnit;
        satisfy Requirements::humanInLoopReq by ethicalReasoningUnit;
        satisfy Requirements::autonomousSafeOpReq by controlSystem;
        satisfy Requirements::noImmediateMovementReq by controlSystem;
        satisfy Requirements::collaborativeOpReq by ethicalReasoningUnit;
    }

}
