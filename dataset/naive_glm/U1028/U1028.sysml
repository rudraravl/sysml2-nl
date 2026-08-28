package AutonomousDevelopmentalRobotics {
    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value types with units ----------
    value type JointAngleValue :> TorqueValue; // reuses AngleValue
    value type AngularVelocityValue :> AngularVelocityValue;
    value type TorqueValue :> TorqueValue;
    value type PressureValue :> PressureValue;
    value type ForceValue :> ForceValue;
    value type PredictionErrorValue :> Real;
    value type RewardValue :> Real;
    value type ConfidenceValue :> Real [0..1];
    value type LearningRateValue :> Real [0..1];
    value type ExplorationRateValue :> Real [0..1];
    value type ImageDataValue :> Real;
    value type TextureDescriptorValue :> Real;

    // ---------- Item types ----------
    item def VisionSignal {
        attribute pixels : ImageDataValue[0..*];
        attribute depthMap : ImageDataValue[0..*];
        attribute frameIndex : Integer;
    }

    item def ProprioceptiveSignal {
        attribute jointPositions : JointAngleValue[1..*];
        attribute jointVelocities : AngularVelocityValue[1..*];
    }

    item def TactileSignal {
        attribute contactCells : Boolean[0..*];
        attribute pressures : PressureValue[0..*];
        attribute textureDescriptors : TextureDescriptorValue[0..*];
    }

    item def MotorCommand {
        attribute targetJointAngles : JointAngleValue[1..*];
        attribute targetJointTorques : TorqueValue[1..*];
        attribute explorationFlag : Boolean;
    }

    item def PredictedState {
        attribute predictedVisual : VisionSignal;
        attribute predictedProprio : ProprioceptiveSignal;
        attribute predictedTactile : TactileSignal;
        attribute confidence : ConfidenceValue;
    }

    item def SensorimotorExperience {
        attribute command : MotorCommand;
        attribute observedVisual : VisionSignal;
        attribute observedProprio : ProprioceptiveSignal;
        attribute observedTactile : TactileSignal;
        attribute prediction : PredictedState;
        attribute predictionError : PredictionErrorValue;
        attribute reward : RewardValue;
        attribute timestamp : TimeValue;
    }

    item def BodySchema {
        attribute segmentLengths : LengthValue[1..*];
        attribute jointLimitsLower : JointAngleValue[1..*];
        attribute jointLimitsUpper : JointAngleValue[1..*];
        attribute currentConfiguration : JointAngleValue[1..*];
    }

    item def CausalRule {
        attribute preconditionStateHash : Integer;
        attribute action : MotorCommand;
        attribute expectedEffectHash : Integer;
        attribute weight : ConfidenceValue;
        attribute observedCount : Integer;
    }

    item def Goal {
        attribute name : String;
        attribute desiredEffectHash : Integer;
        attribute priority : Real;
        attribute achieved : Boolean;
    }

    // ---------- Port definitions ----------
    port def SensorOutputPort {
        out visualSignal : VisionSignal;
        out proprioSignal : ProprioceptiveSignal;
        out tactileSignal : TactileSignal;
    }

    port def MotorCommandPort {
        in command : MotorCommand;
    }

    port def PredictedStatePort {
        out prediction : PredictedState;
    }

    port def ExperiencePort {
        out experience : SensorimotorExperience;
    }

    // ---------- Action definitions ----------
    action def SenseAction {
        in visualIn : VisionSignal;
        in proprioIn : ProprioceptiveSignal;
        in tactileIn : TactileSignal;
        out observation : SensorimotorExperience;
    }

    action def PredictAction {
        in observation : SensorimotorExperience;
        in candidateCommand : MotorCommand;
        out prediction : PredictedState;
    }

    action def ActAction {
        in command : MotorCommand;
        out actuationTorques : TorqueValue[1..*];
    }

    action def ComputePredictionErrorAction {
        in prediction : PredictedState;
        in observedVisual : VisionSignal;
        in observedProprio : ProprioceptiveSignal;
        in observedTactile : TactileSignal;
        in command : MotorCommand;
        out experience : SensorimotorExperience;
    }

    action def LearnAction {
        in experience : SensorimotorExperience;
        out updatedError : PredictionErrorValue;
    }

    action def MotorBabbleAction {
        in rngSeed : Integer;
        out command : MotorCommand;
    }

    action def PlanAction {
        in prediction : PredictedState;
        in activeGoals : Goal[0..*];
        in explorationRate : ExplorationRateValue;
        out command : MotorCommand;
    }

    // ---------- Sensor & actuator parts ----------
    part def VisionSensor {
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute frameRateHz : Real;
        out port visionOut : SensorOutputPort;
        action captureFrames {
            out visionOut.visualSignal : VisionSignal;
        }
    }

    part def ProprioceptiveSensor {
        attribute jointCount : Integer;
        attribute noiseStdDev : JointAngleValue;
        out port proprioOut : SensorOutputPort;
        action readJointStates {
            out proprioOut.proprioSignal : ProprioceptiveSignal;
        }
    }

    part def TactileSensorArray {
        attribute cellCount : Integer;
        attribute sensitivityPascals : PressureValue;
        out port tactileOut : SensorOutputPort;
        action detectContact {
            out tactileOut.tactileSignal : TactileSignal;
        }
    }

    part def JointActuator {
        attribute index : Integer;
        attribute minAngle : JointAngleValue;
        attribute maxAngle : JointAngleValue;
        attribute maxTorque : TorqueValue;
        in port commandIn : MotorCommandPort;
        action applyCommand {
            in commandIn.command : MotorCommand;
        }
    }

    // ---------- Manipulator ----------
    part def ManipulatorArm {
        attribute degreesOfFreedom : Integer;
        in port commandIn : MotorCommandPort;
        out port sensorOut : SensorOutputPort;

        part joints : JointActuator[1..*] {
            in port commandIn : MotorCommandPort;
        }
        part visionSystem : VisionSensor {
            out port visionOut : SensorOutputPort;
        }
        part proprioceptors : ProprioceptiveSensor {
            out port proprioOut : SensorOutputPort;
        }
        part skinArray : TactileSensorArray {
            out port tactileOut : SensorOutputPort;
        }

        action actuate {
            in commandIn.command : MotorCommand;
            out sensorOut.visualSignal : VisionSignal;
            out sensorOut.proprioSignal : ProprioceptiveSignal;
            out sensorOut.tactileSignal : TactileSignal;
        }
    }

    // ---------- World model ----------
    part def WorldModel {
        attribute bodySchema : BodySchema;
        attribute causalRules : CausalRule[0..*];
        attribute knownObjectIds : Integer[0..*];
        attribute lastUpdated : TimeValue;
        attribute accumulatedError : PredictionErrorValue;

        action update {
            in experience : SensorimotorExperience;
            out bodySchema := experience.observedProprio;
        }
        action simulate {
            in currentObservation : SensorimotorExperience;
            in candidateCommand : MotorCommand;
            out prediction : PredictedState;
        }
    }

    // ---------- Predictive Engine ----------
    part def PredictiveEngine {
        in port observationIn : SensorOutputPort;
        out port predictionOut : PredictedStatePort;
        part worldModel : WorldModel;
        attribute imaginationDepth : Integer;

        action predict {
            in observationIn.visualSignal : VisionSignal;
            in observationIn.proprioSignal : ProprioceptiveSignal;
            in observationIn.tactileSignal : TactileSignal;
            in candidateCommand : MotorCommand;
            out predictionOut.prediction : PredictedState;
        }
    }

    // ---------- Motor Planner ----------
    part def MotorPlanner {
        in port predictionIn : PredictedStatePort;
        out port commandOut : MotorCommandPort;
        attribute explorationRate : ExplorationRateValue;
        attribute exploitationRate : Real;
        attribute activeGoals : Goal[0..*];
        attribute planningHorizon : Integer;

        action decide {
            in predictionIn.prediction : PredictedState;
            out commandOut.command : MotorCommand;
        }
    }

    // ---------- Developmental Learning Module ----------
    part def DevelopmentalLearningModule {
        in port observationIn : SensorOutputPort;
        in port predictionIn : PredictedStatePort;
        in port commandIn : MotorCommandPort;
        out port experienceOut : ExperiencePort;
        attribute learningRate : LearningRateValue;
        attribute experiences : SensorimotorExperience[0..*];
        attribute totalError : PredictionErrorValue;

        action compareAndLearn {
            in observationIn.visualSignal : VisionSignal;
            in observationIn.proprioSignal : ProprioceptiveSignal;
            in observationIn.tactileSignal : TactileSignal;
            in predictionIn.prediction : PredictedState;
            in commandIn.command : MotorCommand;
            out experienceOut.experience : SensorimotorExperience;
        }
    }

    // ---------- Developmental state machine ----------
    state def DevelopmentalStateMachine {
        attribute currentPhase : String;

        state reflexive {
            attribute babblingRate : Real;
            entry action {
                DevelopmentalStateMachine.currentPhase := "reflexive";
            }
            do action motorBabbling {
                out command : MotorCommand;
            }
            transition to coordinative
                when totalError < 100.0 [PredictionErrorValue];
        }

        state coordinative {
            attribute patternStability : Real;
            entry action {
                DevelopmentalStateMachine.currentPhase := "coordinative";
            }
            do action formSensorimotorPatterns {
                in experiences : SensorimotorExperience[0..*];
            }
            transition to goalDirected
                when activeGoals.size > 0;
        }

        state goalDirected {
            attribute planningHorizon : Integer;
            entry action {
                DevelopmentalStateMachine.currentPhase := "goal-directed";
            }
            do action planForGoals {
                in goals : Goal[0..*];
            }
            transition to skilled
                when motorPlanner.exploitationRate > 0.8;
        }

        state skilled {
            attribute efficiencyMetric : Real;
            entry action {
                DevelopmentalStateMachine.currentPhase := "skilled";
            }
            do action executeTasks {
                in goals : Goal[0..*];
            }
        }
    }

    // ---------- Cognitive controller ----------
    part def CognitiveController {
        in port sensorInput : SensorOutputPort;
        out port motorOutput : MotorCommandPort;

        part predictiveEngine : PredictiveEngine {
            in port observationIn : SensorOutputPort;
            out port predictionOut : PredictedStatePort;
        }
        part motorPlanner : MotorPlanner {
            in port predictionIn : PredictedStatePort;
            out port commandOut : MotorCommandPort;
        }
        part learningModule : DevelopmentalLearningModule {
            in port observationIn : SensorOutputPort;
            in port predictionIn : PredictedStatePort;
            in port commandIn : MotorCommandPort;
            out port experienceOut : ExperiencePort;
        }

        attribute learningRate : LearningRateValue;
        attribute accumulatedError : PredictionErrorValue;
        attribute phaseName : String;

        part developmentalPhases : DevelopmentalStateMachine;

        action intrinsicCycle {
            in sensorInput.visualSignal : VisionSignal;
            in sensorInput.proprioSignal : ProprioceptiveSignal;
            in sensorInput.tactileSignal : TactileSignal;
            out motorOutput.command : MotorCommand;
            attribute totalError : PredictionErrorValue;
        }
    }

    // ---------- Top-level robot ----------
    part def DevelopmentalRobot {
        attribute name : String;
        attribute serialNumber : String;
        attribute operationalHours : TimeValue;

        part arm : ManipulatorArm {
            in port commandIn : MotorCommandPort;
            out port sensorOut : SensorOutputPort;
        }
        part brain : CognitiveController {
            in port sensorInput : SensorOutputPort;
            out port motorOutput : MotorCommandPort;
        }

        connection armSensorToBrain {
            arm.sensorOut to brain.sensorInput;
        }
        connection brainCommandToArm {
            brain.motorOutput to arm.commandIn;
        }
        connection armToPredictive {
            arm.sensorOut to brain.predictiveEngine.observationIn;
        }
        connection predictiveToPlanner {
            brain.predictiveEngine.predictionOut to brain.motorPlanner.predictionIn;
        }
        connection armToLearning {
            arm.sensorOut to brain.learningModule.observationIn;
        }
        connection predictiveToLearning {
            brain.predictiveEngine.predictionOut to brain.learningModule.predictionIn;
        }
        connection plannerToLearning {
            brain.motorPlanner.commandOut to brain.learningModule.commandIn;
        }
    }

    // ---------- Requirements ----------
    requirement def SkillDiscovery {
        subject robot : DevelopmentalRobot;
        objective {
            doc "The robot must discover and master physical skills through self-exploration without pre-programmed tasks."
        }
        require {
            robot.brain.developmentalPhases must start in state reflexive;
            robot.brain.developmentalPhases must terminate in state skilled;
        }
    }

    requirement def SensorSuiteIntegration {
        subject robot : DevelopmentalRobot;
        objective {
            doc "The robot must integrate visual, proprioceptive, and tactile sensing for self-perception."
        }
        require {
            robot.arm.sensorOut.visualSignal must be provided by VisionSensor;
            robot.arm.sensorOut.proprioSignal must be provided by ProprioceptiveSensor;
            robot.arm.sensorOut.tactileSignal must be provided by TactileSensorArray;
        }
    }

    requirement def PredictionErrorDrivenLearning {
        subject robot : DevelopmentalRobot;
        objective {
            doc "Differences between predicted and actual sensory feedback must refine the internal World Model."
        }
        require {
            robot.brain.learningModule.experiences must contain SensorimotorExperience;
            robot.brain.learningModule.totalError must monotonically decrease over learning cycles;
            robot.brain.predictiveEngine.worldModel.accumulatedError must drive updates to bodySchema;
        }
    }

    requirement def MotorPlannerBalance {
        subject robot : DevelopmentalRobot;
        objective {
            doc "The motor planner must balance exploitation of learned skills with exploration of novel actions."
        }
        require {
            robot.brain.motorPlanner.explorationRate + robot.brain.motorPlanner.exploitationRate must equal 1.0;
            robot.brain.motorPlanner.commandOut.command.explorationFlag must reflect explorationRate;
        }
    }

    requirement def DevelopmentalPhaseProgression {
        subject robot : DevelopmentalRobot;
        objective {
            doc "Learning must progress through reflexive, coordinative, goal-directed, and skilled phases."
        }
        require {
            robot.brain.developmentalPhases.reflexive must transition to coordinative when totalError < 100;
            robot.brain.developmentalPhases.coordinative must transition to goalDirected when goals are established;
            robot.brain.developmentalPhases.goalDirected must transition to skilled when exploitationRate > 0.8;
        }
    }

    requirement def IntrinsicCycleClosedLoop {
        subject robot : DevelopmentalRobot;
        objective {
            doc "The robot must operate a continuous cycle of sensing, predicting, acting, and learning."
        }
        require {
            robot.arm.sensorOut to robot.brain.sensorInput must form a sensing path;
            robot.brain.predictiveEngine.predictionOut to robot.brain.motorPlanner.predictionIn must form a prediction path;
            robot.brain.motorPlanner.commandOut to robot.arm.commandIn must form an acting path;
            robot.brain.learningModule.experienceOut must drive robot.brain.predictiveEngine.worldModel.update;
        }
    }
}
