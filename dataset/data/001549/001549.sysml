package 'Robotic System with Ethics' {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    package EthicsFramework {
        enum def EthicalPrinciple {
            enum doNoHarm;
            enum respectAutonomy;
            enum beneficence;
            enum justice;
        }

        enum def EthicalDecision {
            enum approved;
            enum denied;
            enum requiresHumanReview;
        }

        enum def RiskLevel {
            enum low;
            enum medium;
            enum high;
            enum critical;
        }

        attribute def SafetyScore :> Real;
        attribute def HarmPotential :> Real;
        attribute def BenefitScore :> Real;

        attribute def ProximityDistance :> ISQ::length;
        attribute def ForceLimit :> ISQ::force;
    }

    package EnvironmentModel {
        private import EthicsFramework::*;

        item def Human {
            attribute id : String;
            attribute position : Real[3];
        }

        item def WorkObject {
            attribute mass : ISQ::mass;
            attribute fragility : Real;
        }

        attribute def EnvironmentalContext {
            attribute humanPresent : Boolean;
            attribute humanProximity : ProximityDistance;
            attribute obstacleCount : Integer;
            attribute ambientLight : Real;
            attribute temperature : ISQ::temperature;
        }

        attribute def TaskSpecification {
            attribute taskType : String;
            attribute priority : Integer;
            attribute requiredForce : ForceLimit;
            attribute estimatedDuration : ISQ::time;
            attribute targetObject : String;
        }
    }

    package SensorModel {
        private import EnvironmentModel::*;

        port def SensorDataPort {
            out environmentData : EnvironmentalContext;
        }

        part def ProximitySensor {
            attribute detectionRange : ISQ::length;
            attribute accuracy : Real;
            port dataOut : SensorDataPort;
        }

        part def VisionSensor {
            attribute resolution : Integer;
            attribute fieldOfView : Real;
            port dataOut : SensorDataPort;
        }

        part def ForceTorqueSensor {
            attribute maxForce : ISQ::force;
            attribute maxTorque : ISQ::torque;
            port dataOut : SensorDataPort;
        }

        part def SensorArray {
            part proximitySensors : ProximitySensor[4] {
                attribute redefines detectionRange = 3.0 [m];
                attribute redefines accuracy = 0.98;
            }
            part visionSystem : VisionSensor {
                attribute redefines resolution = 1920;
                attribute redefines fieldOfView = 120.0;
            }
            part forceSensor : ForceTorqueSensor {
                attribute redefines maxForce = 200.0 [N];
                attribute redefines maxTorque = 50.0 [N*m];
            }
        }
    }

    package EthicsEngine {
        private import EthicsFramework::*;
        private import EnvironmentModel::*;

        port def EthicsInputPort {
            in taskRequest : TaskSpecification;
            in environmentData : EnvironmentalContext;
        }

        port def EthicsOutputPort {
            out decision : EthicalDecision;
            out riskLevel : RiskLevel;
            out safetyScore : SafetyScore;
        }

        action def AssessHarmPotential {
            in task : TaskSpecification;
            in environment : EnvironmentalContext;
            out harmScore : HarmPotential;

            first start;
            then action calculateProximityRisk {
                out proximityRisk : Real;
            }
            then action calculateForceRisk {
                out forceRisk : Real;
            }
            then action aggregateHarm {
                in proxRisk : Real = calculateProximityRisk.proximityRisk;
                in frcRisk : Real = calculateForceRisk.forceRisk;
                out totalHarm : HarmPotential;
            }
            then done;
        }

        action def EvaluateBenefit {
            in task : TaskSpecification;
            out benefit : BenefitScore;

            first start;
            then action assessTaskValue {
                out taskValue : Real;
            }
            then action assessEfficiency {
                out efficiency : Real;
            }
            then action computeBenefit {
                in value : Real = assessTaskValue.taskValue;
                in eff : Real = assessEfficiency.efficiency;
                out totalBenefit : BenefitScore;
            }
            then done;
        }

        action def CheckAutonomy {
            in task : TaskSpecification;
            in environment : EnvironmentalContext;
            out autonomyRespected : Boolean;

            first start;
            then decide;
                if environment.humanPresent then violatesAutonomy;
                else respectsAutonomy;
            action violatesAutonomy;
            then done;
            action respectsAutonomy;
            then done;
        }

        action def SynthesizeEthicalDecision {
            in harmScore : HarmPotential;
            in benefitScore : BenefitScore;
            in autonomyRespected : Boolean;
            in safetyThreshold : Real;
            out finalDecision : EthicalDecision;
            out risk : RiskLevel;
            out safety : SafetyScore;

            first start;
            then action computeSafety {
                in harm : HarmPotential = harmScore;
                in benefit : BenefitScore = benefitScore;
                out safetyValue : SafetyScore;
            }
            then action determineRisk {
                in safetyValue : SafetyScore = computeSafety.safetyValue;
                out riskValue : RiskLevel;
            }
            then decide;
                if autonomyRespected then approve;
                else reviewRequired;
            action approve;
            then done;
            action reviewRequired;
            then done;
        }

        action def PerformEthicalEvaluation {
            in taskRequest : TaskSpecification;
            in environmentData : EnvironmentalContext;
            in safetyThreshold : Real;
            out decision : EthicalDecision;
            out riskLevel : RiskLevel;
            out safetyScore : SafetyScore;

            first start;
            then action assessHarm : AssessHarmPotential {
                in task = taskRequest;
                in environment = environmentData;
            }
            then action evaluateBenefit : EvaluateBenefit {
                in task = taskRequest;
            }
            then action checkAutonomy : CheckAutonomy {
                in task = taskRequest;
                in environment = environmentData;
            }
            then action synthesize : SynthesizeEthicalDecision {
                in harmScore = assessHarm.harmScore;
                in benefitScore = evaluateBenefit.benefit;
                in autonomyRespected = checkAutonomy.autonomyRespected;
                in safetyThreshold = safetyThreshold;
            }
            then done;
        }

        part def EthicalReasoningUnit {
            attribute activePrinciples : EthicalPrinciple[1..*];
            attribute safetyThreshold : Real = 0.85;

            port ethicsIn : EthicsInputPort;
            port ethicsOut : EthicsOutputPort;

            perform action evaluate : PerformEthicalEvaluation {
                in taskRequest = ethicsIn.taskRequest;
                in environmentData = ethicsIn.environmentData;
                in safetyThreshold = safetyThreshold;
            }
        }
    }

    package TaskExecutionModel {
        private import EthicsFramework::*;
        private import EnvironmentModel::*;

        port def TaskCommandPort {
            in command : TaskSpecification;
            in ethicalApproval : EthicalDecision;
        }

        port def TaskStatusPort {
            out status : String;
            out progress : Real;
            out completed : Boolean;
        }

        attribute def TaskResult {
            attribute success : Boolean;
            attribute completionTime : ISQ::time;
            attribute ethicsViolations : Integer;
            attribute errorMessage : String;
        }

        action def ExecutePrimaryTask {
            in taskSpec : TaskSpecification;
            in ethicalApproval : EthicalDecision;
            out result : TaskResult;

            first start;
            then action requestEthicalReview {
                out reviewRequest : TaskSpecification = taskSpec;
            }
            then action awaitEthicalDecision {
                in approval : EthicalDecision = ethicalApproval;
            }
            then decide ethicalGate;
                if awaitEthicalDecision.approval == EthicalDecision::approved then proceedWithTask;
                if awaitEthicalDecision.approval == EthicalDecision::denied then abortTask;
                if awaitEthicalDecision.approval == EthicalDecision::requiresHumanReview then requestHumanReview;
            
            action proceedWithTask {
                action approachTarget;
                then action performManipulation;
                then action verifyCompletion;
                then action returnToSafe;
            }
            then action recordSuccess;
            then done;

            action abortTask;
            then done;

            action requestHumanReview {
                action notifyOperator;
                then action awaitHumanDecision {
                    in humanApproval : Boolean;
                }
                then decide humanGate;
                    if awaitHumanDecision.humanApproval then proceedWithTask;
                    else abortTask;
            }

            action recordSuccess;
        }
    }

    package ActuatorModel {
        private import TaskExecutionModel::*;

        port def ActuatorCommandPort {
            in position : Real[6];
            in velocity : Real[6];
            in forceLimit : ForceLimit;
        }

        port def ActuatorStatusPort {
            out currentPosition : Real[6];
            out currentVelocity : Real[6];
            out appliedForce : ISQ::force;
        }

        part def Joint {
            attribute jointId : Integer;
            attribute maxTorque : ISQ::torque;
            port commandIn : ActuatorCommandPort;
            port statusOut : ActuatorStatusPort;
        }

        part def Gripper {
            attribute maxGripForce : ISQ::force;
            attribute openingWidth : ISQ::length;
            port commandIn : ActuatorCommandPort;
            port statusOut : ActuatorStatusPort;
        }

        part def ManipulatorArm {
            attribute degreesOfFreedom : Integer = 6;
            attribute maxReach : ISQ::length;
            attribute maxPayload : ISQ::mass;

            part joints : Joint[6] {
                attribute redefines maxTorque = 100.0 [N*m];
            }
            part endEffector : Gripper {
                attribute redefines maxGripForce = 150.0 [N];
                attribute redefines openingWidth = 0.15 [m];
            }

            port armControl : ActuatorCommandPort;
            port armStatus : ActuatorStatusPort;
        }
    }

    package ControlModel {
        private import EnvironmentModel::*;
        private import EthicsFramework::*;
        private import TaskExecutionModel::*;

        port def ControlInputPort {
            in sensorData : EnvironmentalContext;
            in ethicalGuidance : EthicalDecision;
            in taskCommand : TaskSpecification;
        }

        port def ControlOutputPort {
            out actuatorCommands : Real[6];
            out safetyOverride : Boolean;
            out emergencyStop : Boolean;
        }

        action def ControlCycle {
            in sensorData : EnvironmentalContext;
            in ethicalGuidance : EthicalDecision;
            in taskCommand : TaskSpecification;
            out actuatorCommands : Real[6];
            out safetyOverride : Boolean;

            first start;
            then merge continuousControl;
            
            action readSensors {
                out readings : EnvironmentalContext = sensorData;
            }
            then action planMotion {
                in environment : EnvironmentalContext = readSensors.readings;
                in task : TaskSpecification = taskCommand;
                out trajectory : Real[6];
            }
            then action validateSafety {
                in plannedTrajectory : Real[6] = planMotion.trajectory;
                in environment : EnvironmentalContext = readSensors.readings;
                in ethicsDecision : EthicalDecision = ethicalGuidance;
                out isSafe : Boolean;
            }
            then decide safetyCheck;
                if validateSafety.isSafe then executeMotion;
                else emergencyStop;

            action executeMotion {
                in trajectory : Real[6] = planMotion.trajectory;
                out commands : Real[6];
            }
            then continuousControl;

            action emergencyStop;
            then done;
        }

        part def ControlSystem {
            attribute controlFrequency : Real = 100.0;
            attribute safetyCheckEnabled : Boolean = true;

            port controlIn : ControlInputPort;
            port controlOut : ControlOutputPort;

            perform action controlLoop : ControlCycle {
                in sensorData = controlIn.sensorData;
                in ethicalGuidance = controlIn.ethicalGuidance;
                in taskCommand = controlIn.taskCommand;
            }
        }
    }

    package PhysicalRobotModel {
        private import SensorModel::*;
        private import EthicsEngine::*;
        private import ActuatorModel::*;
        private import ControlModel::*;
        private import EnvironmentModel::*;
        private import TaskExecutionModel::*;

        part def EthicalRobotSystem {
            attribute robotId : String;
            attribute operationalMode : String;
            attribute totalMass : ISQ::mass;

            ref item operator : Human;
            ref item workpiece : WorkObject;

            part ethicsUnit : EthicalReasoningUnit {
                attribute redefines activePrinciples = (
                    EthicalPrinciple::doNoHarm,
                    EthicalPrinciple::respectAutonomy,
                    EthicalPrinciple::beneficence,
                    EthicalPrinciple::justice
                );
                attribute redefines safetyThreshold = 0.90;
            }

            part controlUnit : ControlSystem {
                attribute redefines controlFrequency = 100.0;
                attribute redefines safetyCheckEnabled = true;
            }

            part manipulator : ManipulatorArm {
                attribute redefines degreesOfFreedom = 6;
                attribute redefines maxReach = 1.5 [m];
                attribute redefines maxPayload = 10.0 [kg];
            }

            part sensorSuite : SensorArray;

            connection sensorToControl connect 
                sensorSuite.proximitySensors.dataOut to controlUnit.controlIn;

            connection ethicsToControl connect 
                ethicsUnit.ethicsOut to controlUnit.controlIn;

            connection controlToManipulator connect 
                controlUnit.controlOut to manipulator.armControl;

            perform action robotOperation : ExecutePrimaryTask;
        }
    }

    package RequirementsModel {
        private import EthicsFramework::*;
        private import PhysicalRobotModel::*;

        requirement ethicalOperationRequirement {
            doc /* The robot shall evaluate all tasks using defined ethical 
                   principles before execution to ensure safe and responsible operation. */
            
            subject robot : EthicalRobotSystem;
            
            require constraint {
                robot.ethicsUnit.activePrinciples->includes(EthicalPrinciple::doNoHarm)
            }
        }

        requirement safetyThresholdRequirement {
            doc /* The robot shall not execute tasks with safety scores 
                   below the defined safety threshold. */
            
            subject robot : EthicalRobotSystem;
            
            require constraint {
                robot.ethicsUnit.safetyThreshold >= 0.85
            }
        }

        requirement forceConstraintRequirement {
            doc /* The robot shall limit applied force to prevent harm 
                   when operating near humans. */
            
            subject robot : EthicalRobotSystem;
            
            require constraint {
                robot.sensorSuite.forceSensor.maxForce <= 200.0 [N]
            }
        }

        requirement proximityDetectionRequirement {
            doc /* The robot shall detect human presence within 3 meters 
                   and adjust behavior to maintain safety. */
            
            subject robot : EthicalRobotSystem;
            
            require constraint {
                robot.sensorSuite.proximitySensors->forAll(s | 
                    s.detectionRange >= 3.0 [m]
                )
            }
        }

        requirement autonomyRespectRequirement {
            doc /* The robot shall respect human autonomy by requesting 
                   review when ethical decisions are uncertain. */
            
            subject robot : EthicalRobotSystem;
            
            require constraint {
                robot.ethicsUnit.activePrinciples->includes(EthicalPrinciple::respectAutonomy)
            }
        }
    }

    package LogicalArchitecture {
        private import EthicsEngine::*;
        private import TaskExecutionModel::*;

        part def LogicalElement;

        part def EthicalTaskExecutor :> LogicalElement {
            perform evaluateAndExecute : ExecutePrimaryTask;
            perform ethicsEvaluation : PerformEthicalEvaluation;
        }

        part ethicalTaskExecutor : EthicalTaskExecutor {
            perform evaluateAndExecute;
        }
    }

    package AllocationArchitecture {
        private import LogicalArchitecture::*;
        private import PhysicalRobotModel::*;
        private import RequirementsModel::*;

        allocation def LogicalToPhysical {
            end logical : LogicalElement;
            end physical : EthicalRobotSystem;
        }

        part robotInstance : EthicalRobotSystem {
            attribute redefines robotId = "ROBOT-001";
            attribute redefines operationalMode = "Autonomous";
            attribute redefines totalMass = 150.0 [kg];
        }

        allocation ethicalRobotAllocation : LogicalToPhysical
            allocate logical ::> ethicalTaskExecutor 
            to physical ::> robotInstance {
            
            allocate ethicalTaskExecutor.evaluateAndExecute 
                to robotInstance.robotOperation;
            
            allocate ethicalTaskExecutor.ethicsEvaluation 
                to robotInstance.ethicsUnit.evaluate;
        }

        satisfy ethicalOperationRequirement by ethicalTaskExecutor;
        satisfy safetyThresholdRequirement by ethicalTaskExecutor;
        satisfy forceConstraintRequirement by ethicalTaskExecutor;
        satisfy proximityDetectionRequirement by ethicalTaskExecutor;
        satisfy autonomyRespectRequirement by ethicalTaskExecutor;
    }
}
