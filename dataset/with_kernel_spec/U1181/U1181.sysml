package 'Ethical Robotic Manipulator' {
    private import ScalarValues::*;

    attribute def Length :> Real;
    attribute def Mass :> Real;
    attribute def Force :> Real;
    attribute def Torque :> Real;

    attribute def Position {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    enum def DecisionType { approve; deny; humanReview; }

    item def Task {
        attribute taskType : String;
        attribute targetPosition : Position;
        attribute requiredForce : Force;
    }

    item def MovementPlan {
        attribute jointAngles : Real[6];
        attribute gripperCommand : Boolean;
    }

    item def ProximityData {
        attribute distance : Length;
        attribute humanDetected : Boolean;
    }

    item def VisionData {
        attribute humanDetected : Boolean;
        attribute objectType : String;
    }

    item def ForceTorqueData {
        attribute force : Force;
        attribute torque : Torque;
    }

    item def EthicalDecision {
        attribute decision : DecisionType;
        attribute riskScore : Real[0..1];
        attribute justification : String;
    }

    item def HumanConfirmation {
        attribute confirmed : Boolean;
    }

    attribute def TaskReceived;
    attribute def ConfirmationReceived;

    port def TaskPort {
        in task : Task;
    }

    port def ProximityDataPort {
        out data : ProximityData;
    }

    port def VisionDataPort {
        out data : VisionData;
    }

    port def ForceTorqueDataPort {
        out data : ForceTorqueData;
    }

    port def DecisionPort {
        out decision : EthicalDecision;
    }

    port def MovementPlanPort {
        out plan : MovementPlan;
    }

    port def HumanRequestPort {
        out request : Boolean;
    }

    port def HumanResponsePort {
        in confirmation : HumanConfirmation;
    }

    requirement def PhysicalSpecs {
        doc /* The robot shall be a six-axis arm with 1.5m reach and 10kg payload. */
        attribute maxReach : Length = 1.5;
        attribute payloadCapacity : Mass = 10.0;
        attribute axisCount : Integer = 6;
    }

    requirement def SafetySpecs {
        doc /* The robot shall not cause harm to humans or delicate objects. */
        attribute maxProximityThreshold : Length = 1.0;
        attribute maxForceThreshold : Force = 50.0;
    }

    requirement def AutonomySpecs {
        doc /* The robot shall respect human autonomy by deferring to human judgment when ethical uncertainty exists. */
    }

    requirement def HumanInTheLoopSpecs {
        doc /* For tasks with potential risk, the robot shall request human confirmation before proceeding. */
    }

    part def ProximitySensor {
        attribute detectionRadius : Length = 3.0;
        port dataOut : ProximityDataPort;
    }

    part def VisionSystem {
        attribute resolution : Integer = 1080;
        port dataOut : VisionDataPort;
    }

    part def ForceTorqueSensor {
        port dataOut : ForceTorqueDataPort;
    }

    part def Gripper {
        attribute gripForce : Force = 5.0;
        attribute isOpen : Boolean default true;
    }

    part def SixAxisArm {
        attribute maxReach : Length = 1.5;
        attribute payloadCapacity : Mass = 10.0;
        attribute axisCount : Integer = 6;
        part gripper : Gripper;
    }

    part def SensorSuite {
        part proximitySensor1 : ProximitySensor;
        part proximitySensor2 : ProximitySensor;
        part proximitySensor3 : ProximitySensor;
        part proximitySensor4 : ProximitySensor;
        part visionSystem : VisionSystem;
        part forceTorqueSensor : ForceTorqueSensor;

        port proximityOut : ProximityDataPort;
        port visionOut : VisionDataPort;
        port forceTorqueOut : ForceTorqueDataPort;

        connect proximitySensor1.dataOut to proximityOut;
        connect proximitySensor2.dataOut to proximityOut;
        connect proximitySensor3.dataOut to proximityOut;
        connect proximitySensor4.dataOut to proximityOut;
        connect visionSystem.dataOut to visionOut;
        connect forceTorqueSensor.dataOut to forceTorqueOut;
    }

    part def EthicalReasoningUnit {
        port taskIn : TaskPort;
        port proximityIn : ProximityDataPort;
        port visionIn : VisionDataPort;
        port forceTorqueIn : ForceTorqueDataPort;
        port decisionOut : DecisionPort;
        port humanResponseIn : HumanResponsePort;

        action def EvaluateEthics {
            in task : Task;
            in proxData : ProximityData;
            in visData : VisionData;
            in ftData : ForceTorqueData;
            out decision : EthicalDecision;

            first start;
            then decide;
                if visData.humanDetected or proxData.humanDetected or proxData.distance < 1.0 then denyAction;
                else if task.requiredForce > 30.0 then reviewAction;
                else approveAction;

            action denyAction {
                assign decision.decision := DecisionType::deny;
                assign decision.riskScore := 0.9;
                assign decision.justification := "Human nearby with high force";
            }
            action reviewAction {
                assign decision.decision := DecisionType::humanReview;
                assign decision.riskScore := 0.5;
                assign decision.justification := "Potential risk requires human review";
            }
            action approveAction {
                assign decision.decision := DecisionType::approve;
                assign decision.riskScore := 0.1;
                assign decision.justification := "Task is safe and ethically sound";
            }
        }

        action evaluate : EvaluateEthics;
        bind evaluate.task = taskIn.task;
        bind evaluate.proxData = proximityIn.data;
        bind evaluate.visData = visionIn.data;
        bind evaluate.ftData = forceTorqueIn.data;
        bind decisionOut.decision = evaluate.decision;
    }

    part def ControlSystem {
        port taskIn : TaskPort;
        port decisionIn : DecisionPort;
        port movementOut : MovementPlanPort;
        port humanRequestOut : HumanRequestPort;
        ref arm : SixAxisArm;

        action def CalculateMovements {
            in task : Task;
            out plan : MovementPlan;
        }

        action def ExecuteMotion {
            in plan : MovementPlan;
            doc /* Drives the robotic arm and gripper according to the movement plan. */
        }

        action def RequestHumanReview {
            out request : Boolean;
            assign request := true;
        }

        action plan : CalculateMovements;
        action execute : ExecuteMotion;
        action request : RequestHumanReview;

        bind plan.task = taskIn.task;
        bind execute.plan = plan.plan;
        bind movementOut.plan = plan.plan;
        bind humanRequestOut.request = request.request;
    }

    part def HumanOperator {
        port requestIn : HumanRequestPort;
        port responseOut : HumanResponsePort;
    }

    part def EthicalRoboticManipulatorSystem {
        part arm : SixAxisArm;
        part sensors : SensorSuite;
        part ethicalUnit : EthicalReasoningUnit;
        part controller : ControlSystem;
        part human : HumanOperator;

        port systemTaskIn : TaskPort;
        port systemHumanRespIn : HumanResponsePort;

        connect systemTaskIn to ethicalUnit.taskIn;
        connect systemTaskIn to controller.taskIn;
        connect sensors.proximityOut to ethicalUnit.proximityIn;
        connect sensors.visionOut to ethicalUnit.visionIn;
        connect sensors.forceTorqueOut to ethicalUnit.forceTorqueIn;
        connect ethicalUnit.decisionOut to controller.decisionIn;
        connect controller.humanRequestOut to human.requestIn;
        connect human.responseOut to ethicalUnit.humanResponseIn;
        bind controller.arm = arm;

        state def Operation {
            entry assign arm.gripper.isOpen := true;
            then state idle;

            state idle;
            accept TaskReceived
                then evaluating;

            state evaluating {
                do ethicalUnit.evaluate;
            }
            then decide;
                if ethicalUnit.decisionOut.decision.decision == DecisionType::approve then planning;
                else if ethicalUnit.decisionOut.decision.decision == DecisionType::humanReview then waitingForHuman;
                else denied;

            state planning {
                do controller.plan;
            }
            then executing;

            state executing {
                do controller.execute;
            }
            then idle;

            state waitingForHuman {
                do controller.request;
            }
            accept ConfirmationReceived
                then decide;
                    if systemHumanRespIn.confirmation.confirmed == true then planning;
                    else denied;

            state denied;
            then idle;
        }
    }
}
