package AutonomousHumanoidRobot {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    // --- Attribute Definitions ---
    attribute def TaskInstruction {
        attribute description : String;
        attribute priority : Integer;
    }

    attribute def EnvironmentalModel {
        attribute timestamp : Real;
        attribute objectCount : Integer;
        attribute confidenceLevel : Real;
    }

    attribute def MotionPlan {
        attribute stepCount : Integer;
        attribute estimatedDuration : TimeValue;
        attribute planId : Integer;
    }

    attribute def MotorCommand {
        attribute jointId : Integer;
        attribute targetAngle : PlaneAngleValue;
        attribute targetTorque : TorqueValue;
        attribute timestamp : Real;
    }

    attribute def JointFeedback {
        attribute jointId : Integer;
        attribute currentAngle : PlaneAngleValue;
        attribute currentTorque : TorqueValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    attribute def SafetyStatus {
        attribute collisionRisk : Boolean;
        attribute safeToProceed : Boolean;
        attribute warningLevel : Integer;
    }

    attribute def VisionData {
        attribute frameId : Integer;
        attribute resolution : String;
    }

    attribute def AudioData {
        attribute sampleRate : FrequencyValue;
        attribute duration : TimeValue;
    }

    attribute def TactileData {
        attribute sensorId : Integer;
        attribute pressure : PressureValue;
    }

    attribute def TrajectoryPoint {
        attribute position : LengthValue;
        attribute velocity : SpeedValue;
        attribute acceleration : AccelerationValue;
    }

    attribute def PowerSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    // --- Action Definitions ---
    action def PerceiveEnvironment {
        out environmentalModel : EnvironmentalModel;
    }

    action def PlanTask {
        in environmentalModel : EnvironmentalModel;
        in taskInstruction : TaskInstruction;
        out motionPlan : MotionPlan;
        out safetyStatus : SafetyStatus;
    }

    action def ExecuteMotion {
        in motionPlan : MotionPlan;
        in jointFeedback : JointFeedback;
        out motorCommand : MotorCommand;
    }

    action def MonitorBattery {
        out stateOfCharge : Real;
    }

    action def PerceivePlanActCycle {
        in taskInstruction : TaskInstruction;
        loop {
            action perceive : PerceiveEnvironment {
                out environmentalModel : EnvironmentalModel;
            }
            flow perceive.environmentalModel to plan.environmentalModel;
            action plan : PlanTask {
                in environmentalModel : EnvironmentalModel;
                in taskInstruction : TaskInstruction;
                out motionPlan : MotionPlan;
                out safetyStatus : SafetyStatus;
            }
            flow plan.motionPlan to execute.motionPlan;
            action execute : ExecuteMotion {
                in motionPlan : MotionPlan;
                in jointFeedback : JointFeedback;
                out motorCommand : MotorCommand;
            }
        }
    }

    // --- State Machine Definition ---
    state def RobotStateMachine {
        entry; then poweredOff;
        state poweredOff;
        state initializing;
        state idle;
        state perceiving;
        state planning;
        state executing;
        state charging;
        state emergencyStop;

        transition first poweredOff then initializing;
        transition first initializing then idle;
        transition first idle then perceiving;
        transition first perceiving then planning;
        transition first planning then executing;
        transition first executing then perceiving;
        transition first emergencyStop then idle;
        transition first charging then idle;
    }

    // --- Part Definitions ---
    part def Joint {
        attribute jointId : Integer;
        attribute maxTorque : TorqueValue;
        attribute maxAngle : PlaneAngleValue;
        port commandPort {
            in motorCommand : MotorCommand;
        }
        port feedbackPort {
            out jointFeedback : JointFeedback;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        attribute var currentState : String = "idle";
    }

    part def Gripper {
        attribute maxPayload : MassValue = 20 [kg];
        attribute maxGripForce : ForceValue;
        port commandPort {
            in gripCommand : MotorCommand;
        }
        port feedbackPort {
            out gripFeedback : JointFeedback;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        attribute var gripping : Boolean = false;
    }

    part def Arm {
        attribute armId : String;
        part shoulderJoint : Joint {
            :>> jointId = 1;
            :>> maxTorque = 80 [N*m];
        }
        part elbowJoint : Joint {
            :>> jointId = 2;
            :>> maxTorque = 60 [N*m];
        }
        part wristJoint : Joint {
            :>> jointId = 3;
            :>> maxTorque = 30 [N*m];
        }
        part gripper : Gripper {
            :>> maxGripForce = 150 [N];
        }
        port trajectoryPort {
            in armTrajectory : TrajectoryPoint;
        }
        port feedbackPort {
            out armFeedback : JointFeedback;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        connect shoulderJoint.feedbackPort to feedbackPort;
        connect elbowJoint.feedbackPort to feedbackPort;
        connect wristJoint.feedbackPort to feedbackPort;
        connect gripper.feedbackPort to feedbackPort;
    }

    part def Leg {
        attribute legId : String;
        part hipJoint : Joint {
            :>> jointId = 4;
            :>> maxTorque = 120 [N*m];
        }
        part kneeJoint : Joint {
            :>> jointId = 5;
            :>> maxTorque = 100 [N*m];
        }
        part ankleJoint : Joint {
            :>> jointId = 6;
            :>> maxTorque = 80 [N*m];
        }
        port trajectoryPort {
            in legTrajectory : TrajectoryPoint;
        }
        port feedbackPort {
            out legFeedback : JointFeedback;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        connect hipJoint.feedbackPort to feedbackPort;
        connect kneeJoint.feedbackPort to feedbackPort;
        connect ankleJoint.feedbackPort to feedbackPort;
    }

    part def BalanceController {
        port feedbackPort {
            in leftFeedback : JointFeedback;
            in rightFeedback : JointFeedback;
        }
        port balanceCommandPort {
            out balanceCorrection : MotorCommand;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def BipedalMobilitySystem {
        part leftLeg : Leg {
            :>> legId = "left";
        }
        part rightLeg : Leg {
            :>> legId = "right";
        }
        part balanceController : BalanceController;
        port commandPort {
            in mobilityCommand : MotorCommand;
        }
        port feedbackPort {
            out mobilityFeedback : JointFeedback;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        connect leftLeg.feedbackPort to balanceController.feedbackPort;
        connect rightLeg.feedbackPort to balanceController.feedbackPort;
        connect leftLeg.feedbackPort to feedbackPort;
        connect rightLeg.feedbackPort to feedbackPort;
    }

    part def BatterySystem {
        attribute capacity : ElectricChargeValue = 100 [A*h];
        attribute nominalVoltage : ElectricPotentialValue = 48 [V];
        attribute minOperatingTime : TimeValue = 4 [h];
        attribute internalResistance : ResistanceValue;
        attribute var stateOfCharge : Real = 1.0;
        attribute var currentDraw : ElectricCurrentValue;
        port powerPort {
            out power : PowerSignal;
        }
        port chargePort {
            in chargeCurrent : ElectricCurrentValue;
        }
        perform action monitorBattery : MonitorBattery;
    }

    part def VisionSensor {
        port dataPort {
            out visionData : VisionData;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def AudioSensor {
        port dataPort {
            out audioData : AudioData;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def TactileSensor {
        port dataPort {
            out tactileData : TactileData;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def SensorFusionModule {
        port visionIn {
            in visionData : VisionData;
        }
        port audioIn {
            in audioData : AudioData;
        }
        port tactileIn {
            in tactileData : TactileData;
        }
        port modelOut {
            out environmentalModel : EnvironmentalModel;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def PerceptionSystem {
        part visionSensor : VisionSensor;
        part audioSensor : AudioSensor;
        part tactileSensor : TactileSensor;
        part sensorFusionModule : SensorFusionModule;
        port perceptionOutputPort {
            out environmentalModel : EnvironmentalModel;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        connect visionSensor.dataPort to sensorFusionModule.visionIn;
        connect audioSensor.dataPort to sensorFusionModule.audioIn;
        connect tactileSensor.dataPort to sensorFusionModule.tactileIn;
        connect sensorFusionModule.modelOut to perceptionOutputPort;
        perform action perceiveEnvironment : PerceiveEnvironment;
    }

    part def AIDecisionEngine {
        port modelIn {
            in environmentalModel : EnvironmentalModel;
        }
        port taskIn {
            in taskInstruction : TaskInstruction;
        }
        port planOut {
            out motionPlan : MotionPlan;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def TaskPlanner {
        port planIn {
            in rawPlan : MotionPlan;
        }
        port planOut {
            out refinedPlan : MotionPlan;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def SafetyMonitor {
        port modelIn {
            in environmentalModel : EnvironmentalModel;
        }
        port planIn {
            in motionPlan : MotionPlan;
        }
        port statusOut {
            out safetyStatus : SafetyStatus;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def LearningModule {
        port experienceIn {
            in taskInstruction : TaskInstruction;
        }
        port modelOut {
            out learnedModel : String;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def CognitionSystem {
        part aiDecisionEngine : AIDecisionEngine;
        part taskPlanner : TaskPlanner;
        part safetyMonitor : SafetyMonitor;
        part learningModule : LearningModule;
        port perceptionInputPort {
            in environmentalModel : EnvironmentalModel;
        }
        port taskInputPort {
            in taskInstruction : TaskInstruction;
        }
        port motionPlanOutputPort {
            out motionPlan : MotionPlan;
        }
        port safetyOutputPort {
            out safetyStatus : SafetyStatus;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        connect perceptionInputPort to aiDecisionEngine.modelIn;
        connect taskInputPort to aiDecisionEngine.taskIn;
        connect aiDecisionEngine.planOut to taskPlanner.planIn;
        connect taskPlanner.planOut to safetyMonitor.planIn;
        connect perceptionInputPort to safetyMonitor.modelIn;
        connect taskInputPort to learningModule.experienceIn;
        connect safetyMonitor.statusOut to safetyOutputPort;
        connect taskPlanner.planOut to motionPlanOutputPort;
        perform action planTask : PlanTask;
    }

    part def TrajectoryGenerator {
        port planIn {
            in motionPlan : MotionPlan;
        }
        port leftArmTrajectoryOut {
            out leftArmTrajectory : TrajectoryPoint;
        }
        port rightArmTrajectoryOut {
            out rightArmTrajectory : TrajectoryPoint;
        }
        port leftLegTrajectoryOut {
            out leftLegTrajectory : TrajectoryPoint;
        }
        port rightLegTrajectoryOut {
            out rightLegTrajectory : TrajectoryPoint;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def MotorController {
        port trajectoryIn {
            in trajectory : TrajectoryPoint;
        }
        port feedbackIn {
            in jointFeedback : JointFeedback;
        }
        port commandOut {
            out motorCommand : MotorCommand;
        }
        port powerInPort {
            in power : PowerSignal;
        }
    }

    part def MotionControlSystem {
        part trajectoryGenerator : TrajectoryGenerator;
        part motorController : MotorController;
        port planInputPort {
            in motionPlan : MotionPlan;
        }
        port leftArmCommandPort {
            out leftArmCommand : MotorCommand;
        }
        port rightArmCommandPort {
            out rightArmCommand : MotorCommand;
        }
        port leftLegCommandPort {
            out leftLegCommand : MotorCommand;
        }
        port rightLegCommandPort {
            out rightLegCommand : MotorCommand;
        }
        port feedbackInputPort {
            in jointFeedback : JointFeedback;
        }
        port powerInPort {
            in power : PowerSignal;
        }
        connect planInputPort to trajectoryGenerator.planIn;
        connect trajectoryGenerator.leftArmTrajectoryOut to motorController.trajectoryIn;
        connect feedbackInputPort to motorController.feedbackIn;
        connect motorController.commandOut to leftArmCommandPort;
        perform action executeMotion : ExecuteMotion;
    }

    part def HumanoidRobot {
        attribute robotId : String;
        attribute maxPayload : MassValue = 20 [kg];
        attribute var operationalState : String = "poweredOff";
        attribute var collisionDetected : Boolean = false;

        part batterySystem : BatterySystem {
            :>> capacity = 100 [A*h];
            :>> nominalVoltage = 48 [V];
            :>> minOperatingTime = 4 [h];
        }

        part leftArm : Arm {
            :>> armId = "left";
        }
        part rightArm : Arm {
            :>> armId = "right";
        }

        part mobilitySystem : BipedalMobilitySystem;

        part perceptionSystem : PerceptionSystem;
        part cognitionSystem : CognitionSystem;
        part motionControlSystem : MotionControlSystem;

        connect perceptionSystem.perceptionOutputPort to cognitionSystem.perceptionInputPort;
        connect cognitionSystem.motionPlanOutputPort to motionControlSystem.planInputPort;

        connect motionControlSystem.leftArmCommandPort to leftArm.shoulderJoint.commandPort;
        connect motionControlSystem.rightArmCommandPort to rightArm.shoulderJoint.commandPort;
        connect motionControlSystem.leftLegCommandPort to mobilitySystem.leftLeg.hipJoint.commandPort;
        connect motionControlSystem.rightLegCommandPort to mobilitySystem.rightLeg.hipJoint.commandPort;

        connect leftArm.feedbackPort to motionControlSystem.feedbackInputPort;
        connect rightArm.feedbackPort to motionControlSystem.feedbackInputPort;
        connect mobilitySystem.feedbackPort to motionControlSystem.feedbackInputPort;

        connect mobilitySystem.leftLeg.feedbackPort to mobilitySystem.balanceController.feedbackPort;
        connect mobilitySystem.rightLeg.feedbackPort to mobilitySystem.balanceController.feedbackPort;
        connect mobilitySystem.balanceController.balanceCommandPort to mobilitySystem.leftLeg.hipJoint.commandPort;

        connect batterySystem.powerPort to perceptionSystem.powerInPort;
        connect batterySystem.powerPort to cognitionSystem.powerInPort;
        connect batterySystem.powerPort to motionControlSystem.powerInPort;
        connect batterySystem.powerPort to leftArm.powerInPort;
        connect batterySystem.powerPort to rightArm.powerInPort;
        connect batterySystem.powerPort to mobilitySystem.powerInPort;

        perform action cycle : PerceivePlanActCycle;
        state robotState : RobotStateMachine;
    }

    // --- Requirements ---
    requirement def PayloadRequirement {
        doc /* The robot shall be able to grasp and handle objects up to 20kg. */
        subject robot : HumanoidRobot;
        attribute actualPayload : MassValue;
        attribute requiredPayload : MassValue = 20 [kg];
        require constraint { actualPayload >= requiredPayload }
    }

    requirement def BatteryLifeRequirement {
        doc /* The robot shall operate continuously for at least 4 hours on a single charge. */
        subject robot : HumanoidRobot;
        attribute actualOperatingTime : TimeValue;
        attribute requiredOperatingTime : TimeValue = 4 [h];
        require constraint { actualOperatingTime >= requiredOperatingTime }
    }

    requirement def SafetyRequirement {
        doc /* The robot shall prevent collisions and ensure all actions are safe. */
        subject robot : HumanoidRobot;
        attribute collisionDetected : Boolean = false;
        require constraint { collisionDetected == false }
    }

    requirement def AutonomyRequirement {
        doc /* The robot shall operate autonomously with minimal human intervention. */
        subject robot : HumanoidRobot;
        attribute humanInterventionsPerHour : Real;
        attribute maxInterventions : Real = 1.0;
        require constraint { humanInterventionsPerHour <= maxInterventions }
    }

    requirement def PerceptionRequirement {
        doc /* The perception system shall fuse vision, audio, and tactile data into a real-time environmental model. */
        subject robot : HumanoidRobot;
        attribute fusionLatency : TimeValue;
        attribute maxLatency : TimeValue = 0.1 [s];
        require constraint { fusionLatency <= maxLatency }
    }

    requirement def BalanceRequirement {
        doc /* The bipedal mobility system shall maintain stable movement and walking via a balance controller. */
        subject robot : HumanoidRobot;
        attribute stableWalking : Boolean = true;
        require constraint { stableWalking == true }
    }

    // --- Verification ---
    part verificationContext {
        ref robotUnderTest : HumanoidRobot;
        satisfy requirement payloadReq : PayloadRequirement by robotUnderTest;
        satisfy requirement batteryLifeReq : BatteryLifeRequirement by robotUnderTest;
        satisfy requirement safetyReq : SafetyRequirement by robotUnderTest;
        satisfy requirement autonomyReq : AutonomyRequirement by robotUnderTest;
        satisfy requirement perceptionReq : PerceptionRequirement by robotUnderTest;
        satisfy requirement balanceReq : BalanceRequirement by robotUnderTest;
    }
}
