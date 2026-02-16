package AdaptableRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TaskType {
        attribute taskId : String;
        attribute complexity : Real;
        attribute priority : Integer;
    }
    
    attribute def EnvironmentParameters {
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute lightLevel : LuminousIntensityValue;
        attribute obstacleCount : Integer;
    }
    
    attribute def RobotPose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }
    
    attribute def JointConfiguration {
        attribute joint1Angle : Real;
        attribute joint2Angle : Real;
        attribute joint3Angle : Real;
        attribute joint4Angle : Real;
        attribute joint5Angle : Real;
        attribute joint6Angle : Real;
    }
    
    attribute def GripperState {
        attribute isOpen : Boolean;
        attribute gripForce : ForceValue;
        attribute fingerPosition : LengthValue;
    }
    
    attribute def ToolConfiguration {
        attribute toolType : String;
        attribute toolMass : MassValue;
        attribute toolReach : LengthValue;
    }
    
    attribute def PerformanceData {
        attribute taskSuccessRate : Real;
        attribute averageCompletionTime : TimeValue;
        attribute energyConsumption : EnergyValue;
        attribute adaptationCount : Integer;
    }
    
    port def SensorDataPort {
        out item envData : EnvironmentParameters;
        out item poseData : RobotPose;
    }
    
    port def ControlCommandPort {
        in item targetPose : RobotPose;
        in item jointCmd : JointConfiguration;
        in item gripperCmd : GripperState;
    }
    
    port def PowerPort {
        out item voltage : ElectricPotentialValue;
        out item current : ElectricCurrentValue;
        in item powerDemand : PowerValue;
    }
    
    port def CommunicationPort {
        in item taskRequest : TaskType;
        out item statusReport : PerformanceData;
        out item diagnostics : String;
    }
    
    part def VisionSystem {
        port sensorOut : ~SensorDataPort;
        
        attribute cameraResolution : Integer;
        attribute frameRate : Real;
        
        action def CaptureScene {
            out sceneData : EnvironmentParameters;
        }
        
        action def DetectObjects {
            in sceneData : EnvironmentParameters;
            out objectList : Integer;
        }
    }
    
    part def ProximitySensor {
        port sensorOut : ~SensorDataPort;
        
        attribute detectionRange : LengthValue;
        attribute accuracy : LengthValue;
        
        action def MeasureDistance {
            out distance : LengthValue;
        }
    }
    
    part def AdaptivePlanner {
        port sensorIn : SensorDataPort;
        port controlOut : ~ControlCommandPort;
        port commPort : CommunicationPort;
        
        attribute currentStrategy : String;
        attribute planningHorizon : TimeValue;
        
        action def AnalyzeTask {
            in task : TaskType;
            in environment : EnvironmentParameters;
            out taskFeasibility : Real;
        }
        
        action def GenerateMotionPlan {
            in currentPose : RobotPose;
            in targetPose : RobotPose;
            in obstacles : Integer;
            out trajectory : JointConfiguration[*];
        }
        
        action def SelectTool {
            in task : TaskType;
            out selectedTool : ToolConfiguration;
        }
        
        action def AdaptStrategy {
            in performanceMetrics : PerformanceData;
            in environmentChanges : EnvironmentParameters;
            out newStrategy : String;
        }
    }
    
    part def ManipulatorArm {
        port controlIn : ControlCommandPort;
        port powerIn : PowerPort;
        
        attribute jointCount : Integer;
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        attribute currentConfig : JointConfiguration;
        
        action def MoveToPosition {
            in targetConfig : JointConfiguration;
            out actualConfig : JointConfiguration;
            out movementTime : TimeValue;
        }
        
        action def ApplyForce {
            in desiredForce : ForceValue;
            out actualForce : ForceValue;
        }
    }
    
    part def EndEffector {
        port controlIn : ControlCommandPort;
        port powerIn : PowerPort;
        
        attribute effectorType : String;
        attribute maxGripForce : ForceValue;
        attribute currentState : GripperState;
        
        action def Grasp {
            in targetForce : ForceValue;
            out graspSuccess : Boolean;
        }
        
        action def Release {
            out releaseComplete : Boolean;
        }
        
        action def AdjustGrip {
            in forceAdjustment : ForceValue;
            out newGripState : GripperState;
        }
    }
    
    part def ToolChanger {
        port controlIn : ControlCommandPort;
        
        attribute availableTools : ToolConfiguration[*];
        attribute currentTool : ToolConfiguration;
        attribute changeTime : TimeValue;
        
        action def SwapTool {
            in requestedTool : ToolConfiguration;
            out swapSuccess : Boolean;
            out swapDuration : TimeValue;
        }
    }
    
    part def LearningEngine {
        attribute experienceDatabase : PerformanceData[*];
        attribute learningRate : Real;
        attribute modelAccuracy : Real;
        
        action def RecordExperience {
            in taskOutcome : Real;
            in configurationUsed : JointConfiguration;
            in environmentConditions : EnvironmentParameters;
            out experienceId : Integer;
        }
        
        action def UpdateModel {
            in newExperience : PerformanceData;
            out modelImprovement : Real;
        }
        
        action def PredictPerformance {
            in proposedConfig : JointConfiguration;
            in expectedEnvironment : EnvironmentParameters;
            out predictedSuccess : Real;
        }
        
        action def OptimizeParameters {
            in historicalData : PerformanceData[*];
            out optimizedConfig : JointConfiguration;
        }
    }
    
    part def PowerManagement {
        port powerOut : ~PowerPort;
        
        attribute batteryCapacity : EnergyValue;
        attribute currentCharge : Real;
        attribute powerEfficiency : Real;
        
        action def MonitorPower {
            out remainingEnergy : EnergyValue;
            out estimatedRuntime : TimeValue;
        }
        
        action def AllocatePower {
            in subsystemDemands : PowerValue[*];
            out powerDistribution : PowerValue[*];
        }
    }
    
    part def AdaptableRobotSystem {
        doc /* An intelligent robotic system capable of autonomously adapting its behavior,
               configuration, and task execution strategies in response to changing environmental
               conditions, task requirements, and learned experience to optimize performance
               across diverse manipulation and assembly operations. */
        
        part visionSys : VisionSystem[2];
        part proximitySensors : ProximitySensor[4];
        part planner : AdaptivePlanner;
        part arm : ManipulatorArm;
        part gripper : EndEffector;
        part toolChanger : ToolChanger;
        part learningModule : LearningEngine;
        part powerSystem : PowerManagement;
        
        connect visionSys[1].sensorOut to planner.sensorIn;
        connect proximitySensors[1].sensorOut to planner.sensorIn;
        connect planner.controlOut to arm.controlIn;
        connect planner.controlOut to gripper.controlIn;
        connect planner.controlOut to toolChanger.controlIn;
        connect powerSystem.powerOut to arm.powerIn;
        connect powerSystem.powerOut to gripper.powerIn;
    }
    
    part adaptableRobot : AdaptableRobotSystem {
        perform action autonomousOperation : AutonomousAdaptiveOperation;
    }
    
    action def AutonomousAdaptiveOperation {
        first start;
        then merge operationLoop;
        
        then action receiveTask {
            in taskRequest : TaskType;
        }
        
        then action gatherEnvironmentData {
            out environmentState : EnvironmentParameters;
        }
        
        then action analyzeTaskFeasibility : AdaptivePlanner::AnalyzeTask {
            in task : TaskType;
            in environment : EnvironmentParameters;
            out taskFeasibility : Real;
        }
        
        then decide;
            if analyzeTaskFeasibility.taskFeasibility > 0.8 then proceedWithTask;
            if analyzeTaskFeasibility.taskFeasibility <= 0.8 then adaptAndRetry;
        
        action proceedWithTask {
            first action selectOptimalTool : AdaptivePlanner::SelectTool {
                in task : TaskType;
                out selectedTool : ToolConfiguration;
            }
            
            then action planMotion : AdaptivePlanner::GenerateMotionPlan {
                in currentPose : RobotPose;
                in targetPose : RobotPose;
                in obstacles : Integer;
                out trajectory : JointConfiguration[*];
            }
            
            then action executeMotion {
                out executionComplete : Boolean;
            }
            
            then action performGrasp : EndEffector::Grasp {
                in targetForce : ForceValue;
                out graspSuccess : Boolean;
            }
            
            then action recordPerformance : LearningEngine::RecordExperience {
                in taskOutcome : Real;
                in configurationUsed : JointConfiguration;
                in environmentConditions : EnvironmentParameters;
                out experienceId : Integer;
            }
        }
        
        action adaptAndRetry {
            first action predictOptimalConfig : LearningEngine::PredictPerformance {
                in proposedConfig : JointConfiguration;
                in expectedEnvironment : EnvironmentParameters;
                out predictedSuccess : Real;
            }
            
            then action adaptStrategy : AdaptivePlanner::AdaptStrategy {
                in performanceMetrics : PerformanceData;
                in environmentChanges : EnvironmentParameters;
                out newStrategy : String;
            }
            
            then action updateLearningModel : LearningEngine::UpdateModel {
                in newExperience : PerformanceData;
                out modelImprovement : Real;
            }
        }
        
        then merge evaluateAndContinue;
        
        then action evaluateAndContinue {
            action optimizeForFuture : LearningEngine::OptimizeParameters {
                in historicalData : PerformanceData[*];
                out optimizedConfig : JointConfiguration;
            }
        }
        
        then operationLoop;
    }
    
    state def RobotOperationalStates {
        entry; then idle;
        
        state idle;
        accept when TaskType then analyzing;
        
        state analyzing;
        if taskFeasible then planning;
        if taskInfeasible then adapting;
        
        state planning;
        accept when JointConfiguration then executing;
        
        state executing;
        if motionComplete then grasping;
        if errorDetected then recovering;
        
        state grasping;
        if graspSuccessful then completing;
        if graspFailed then recovering;
        
        state adapting;
        accept when String then planning;
        
        state recovering;
        if recoverySuccessful then planning;
        if recoveryFailed then idle;
        
        state completing;
        accept when PerformanceData then idle;
    }
    
    requirement def AdaptabilityRequirement {
        doc /* The robotic system shall demonstrate adaptive behavior by modifying its
               operational strategies in response to environmental changes and task variations. */
        
        require constraint adaptationSpeed {
            doc /* Strategy adaptation shall complete within 3.0 seconds of detecting
                   environmental change exceeding threshold. */
        }
        
        require constraint configurationFlexibility {
            doc /* System shall support minimum of 8 distinct operational configurations
                   for different task types. */
        }
        
        require constraint toolChangeCapability {
            doc /* Tool changing operation shall complete within 15.0 seconds. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The system shall maintain high task completion rates and efficiency
               across varying operational conditions. */
        
        require constraint nominalSuccessRate {
            doc /* Task success rate shall exceed 97% under nominal environmental conditions
                   with temperature 15-25°C and obstacle count less than 3. */
        }
        
        require constraint degradedSuccessRate {
            doc /* Task success rate shall exceed 85% under degraded conditions with
                   temperature -5 to 40°C and obstacle count up to 8. */
        }
        
        require constraint energyEfficiency {
            doc /* Energy consumption per task shall not exceed 500 kJ under nominal conditions. */
        }
    }
    
    requirement def LearningRequirement {
        doc /* The system shall continuously improve performance through experience-based
               learning and optimization. */
        
        require constraint performanceImprovement {
            doc /* Task completion time shall demonstrate measurable reduction of at least 10%
                   over 200 task cycles for repeated task types. */
        }
        
        require constraint modelAccuracy {
            doc /* Performance prediction model accuracy shall exceed 90% after 100 training cycles. */
        }
        
        require constraint knowledgeRetention {
            doc /* System shall retain and utilize learned strategies across power cycles
                   with less than 5% degradation. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall operate safely in human-collaborative environments. */
        
        require constraint collisionAvoidance {
            doc /* System shall detect and avoid collisions with obstacles within detection
                   range of 0.5 meters with 99.9% reliability. */
        }
        
        require constraint forceLimit {
            doc /* Maximum applied force shall not exceed 150 N during normal operations. */
        }
        
        require constraint emergencyStop {
            doc /* Emergency stop shall halt all motion within 0.2 seconds of trigger. */
        }
    }
    
    requirement <'SYS-ADAPT-001'> systemMissionRequirement {
        doc /* The adaptable robotics system shall autonomously perform complex manipulation
               and assembly tasks in dynamic, unstructured environments by continuously sensing
               environmental conditions, adapting physical configuration and control strategies,
               learning from operational experience, and optimizing performance to achieve
               high task success rates while maintaining safety and energy efficiency. */
        
        assume constraint operationalEnvironment {
            doc /* System operates in industrial environments with temperature range -10°C to 50°C,
                   variable lighting 100-1000 lux, and dynamic obstacle presence up to 10 objects
                   within workspace. */
        }
        
        assume constraint taskVariety {
            doc /* System handles tasks with complexity levels 1-10 and priorities 1-5,
                   including pick-and-place, assembly, inspection, and material handling. */
        }
        
        require adaptabilityReq : AdaptabilityRequirement;
        require performanceReq : PerformanceRequirement;
        require learningReq : LearningRequirement;
        require safetyReq : SafetyRequirement;
    }
}
