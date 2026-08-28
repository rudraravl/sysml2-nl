package AutonomousRoboticSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def LengthValue :> Real { unit 'm'; }
    value def AngleValue :> Real { unit 'rad'; }
    value def VelocityValue :> Real { unit 'm/s'; }
    value def AngularVelocityValue :> Real { unit 'rad/s'; }
    value def ForceValue :> Real { unit 'N'; }
    value def TorqueValue :> Real { unit 'N*m'; }
    value def MassValue :> Real { unit 'kg'; }
    value def EnergyValue :> Real { unit 'J'; }
    value def PowerValue :> Real { unit 'W'; }
    value def TemperatureValue :> Real { unit 'K'; }
    value def TimeValue :> Real { unit 's'; }
    value def ProbabilityValue :> Real;
    value def PercentageValue :> Real;
    value def IlluminanceValue :> Real { unit 'lx'; }

    // ===== Enumerations =====

    enum def TaskType { pick_and_place; assembly; inspection; }
    enum def ToolType { gripper; vacuum; probe; camera_module; welder; }
    enum def PlanStatus { feasible; infeasible; uncertain; }
    enum def ExecutionStatus { success; failure; partial; }
    enum def PowerMode { full; reduced; standby; critical; }

    // ===== Item Definitions =====

    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute illuminance : IlluminanceValue;
        attribute obstaclePresent : Boolean;
        attribute obstacleDistance : LengthValue;
        attribute obstacleBearing : AngleValue;
    }

    item def VisionData {
        attribute sceneImage : String;
        attribute detectedObjects : Integer;
        attribute confidence : ProbabilityValue;
        attribute timestamp : TimeValue;
    }

    item def ProximityData {
        attribute distance : LengthValue;
        attribute signalStrength : PercentageValue;
        attribute sensorId : Integer;
    }

    item def TaskRequest {
        attribute taskType : TaskType;
        attribute targetPosition : LengthValue[3];
        attribute priority : Integer;
        attribute deadline : TimeValue;
    }

    item def MotionPlan {
        attribute jointTrajectories : AngleValue[6][*];
        attribute duration : TimeValue;
        attribute estimatedEnergy : EnergyValue;
        attribute selectedTool : ToolType;
        attribute status : PlanStatus;
    }

    item def PerformanceRecord {
        attribute taskType : TaskType;
        attribute completionTime : TimeValue;
        attribute energyConsumed : EnergyValue;
        attribute status : ExecutionStatus;
        attribute toolUsed : ToolType;
        attribute timestamp : TimeValue;
    }

    item def LearningModel {
        attribute successRate : ProbabilityValue;
        attribute avgCompletionTime : TimeValue;
        attribute avgEnergyConsumption : EnergyValue;
        attribute recommendedTool : ToolType;
        attribute modelVersion : Integer;
    }

    item def PowerStatus {
        attribute reserveLevel : PercentageValue;
        attribute currentDraw : PowerValue;
        attribute mode : PowerMode;
    }

    item def CommandMessage {
        attribute commandId : Integer;
        attribute target : String;
        attribute parameters : String;
    }

    // ===== Port Definitions =====

    port def DataPort {
        out item data : EnvironmentalData;
    }

    port def VisionPort {
        out item visionData : VisionData;
    }

    port def ProximityPort {
        out item proximityData : ProximityData;
    }

    port def CommandPort {
        in item command : CommandMessage;
    }

    port def PlanPort {
        out item plan : MotionPlan;
    }

    port def TaskPort {
        in item task : TaskRequest;
    }

    port def PerformancePort {
        in item record : PerformanceRecord;
        out item model : LearningModel;
    }

    port def PowerPort {
        out item status : PowerStatus;
    }

    // ===== Part Definitions =====

    part def Joint {
        attribute jointId : Integer;
        attribute currentAngle : AngleValue;
        attribute maxTorque : TorqueValue;
        attribute maxVelocity : AngularVelocityValue;
        in port command : CommandPort;
        exhibit state JointBehavior {
            entry; then Idle;
            state Idle;
            state Moving;
            state Holding;
            transition Idle to Moving when command.command.commandId > 0;
            transition Moving to Holding when currentAngle == command.command.parameters::AngleValue;
            transition Holding to Idle when command.command.commandId == 0;
        }
    }

    part def ManipulatorArm {
        attribute maxReach : LengthValue = 1.5;
        attribute payloadCapacity : MassValue = 5.0;
        attribute numJoints : Integer = 6;
        part joints : Joint[6] {
            item joints[0].jointId = 1;
            item joints[1].jointId = 2;
            item joints[2].jointId = 3;
            item joints[3].jointId = 4;
            item joints[4].jointId = 5;
            item joints[5].jointId = 6;
        }
        in port command : CommandPort;
        in port power : PowerPort;
        out port feedback : DataPort;
        exhibit state ArmOperation {
            entry; then Idle;
            state Idle;
            state Moving;
            state Executing;
            state Error;
            transition Idle to Moving when command.command.commandId > 0;
            transition Moving to Executing when command.command.target == "arm";
            transition Executing to Idle when command.command.commandId == 0;
            transition any to Error when power.status.mode == PowerMode::critical;
            transition Error to Idle when command.command.commandId == -1;
        }
    }

    part def EndEffector {
        attribute gripForce : ForceValue;
        attribute isGrasping : Boolean = false;
        attribute currentTool : ToolType = ToolType::gripper;
        in port command : CommandPort;
        in port power : PowerPort;
        exhibit state GripperBehavior {
            entry; then Open;
            state Open;
            state Closed;
            state Error;
            transition Open to Closed when command.command.commandId == 1;
            transition Closed to Open when command.command.commandId == 0;
            transition any to Error when power.status.mode == PowerMode::critical;
            transition Error to Open when command.command.commandId == -1;
        }
    }

    part def ToolChanger {
        attribute availableTools : ToolType[5] = [ToolType::gripper, ToolType::vacuum, ToolType::probe, ToolType::camera_module, ToolType::welder];
        attribute currentTool : ToolType = ToolType::gripper;
        attribute swapTime : TimeValue = 3.0;
        in port command : CommandPort;
        in port power : PowerPort;
        exhibit state ToolChangerBehavior {
            entry; then Ready;
            state Ready;
            state Swapping;
            state Error;
            transition Ready to Swapping when command.command.commandId == 2;
            transition Swapping to Ready when command.command.parameters == currentTool.name;
            transition any to Error when power.status.mode == PowerMode::critical;
            transition Error to Ready when command.command.commandId == -1;
        }
    }

    part def VisionSystem {
        attribute sensorId : Integer;
        attribute resolution : Integer;
        attribute frameRate : Integer;
        attribute fieldOfView : AngleValue;
        out port visionOut : VisionPort;
        exhibit state VisionBehavior {
            entry; then Active;
            state Active;
            state Calibrating;
            state Error;
            transition Active to Calibrating when visionOut.visionData.confidence < 0.5;
            transition Calibrating to Active when visionOut.visionData.confidence >= 0.8;
            transition any to Error when visionOut.visionData.confidence < 0.1;
            transition Error to Active when visionOut.visionData.confidence >= 0.5;
        }
    }

    part def ProximitySensor {
        attribute sensorId : Integer;
        attribute maxRange : LengthValue = 0.5;
        attribute minRange : LengthValue = 0.01;
        attribute accuracy : LengthValue = 0.005;
        out port proximityOut : ProximityPort;
        exhibit state ProximityBehavior {
            entry; then Scanning;
            state Scanning;
            state Detected;
            state Error;
            transition Scanning to Detected when proximityOut.proximityData.distance < maxRange;
            transition Detected to Scanning when proximityOut.proximityData.distance >= maxRange;
            transition any to Error when proximityOut.proximityData.signalStrength < 10;
            transition Error to Scanning when proximityOut.proximityData.signalStrength >= 10;
        }
    }

    part def SensorSuite {
        part visionSystems : VisionSystem[2] {
            item visionSystems[0].sensorId = 1;
            item visionSystems[1].sensorId = 2;
        }
        part proximitySensors : ProximitySensor[4] {
            item proximitySensors[0].sensorId = 1;
            item proximitySensors[1].sensorId = 2;
            item proximitySensors[2].sensorId = 3;
            item proximitySensors[3].sensorId = 4;
        }
        out port environmentalData : DataPort;
        out port visionData : VisionPort;
        out port proximityData : ProximityPort;
        exhibit state SensorSuiteBehavior {
            entry; then Operational;
            state Operational;
            state Degraded;
            state Error;
            transition Operational to Degraded when visionData.visionData.confidence < 0.5;
            transition Degraded to Operational when visionData.visionData.confidence >= 0.8;
            transition any to Error when visionData.visionData.confidence < 0.1;
            transition Error to Operational when visionData.visionData.confidence >= 0.5;
        }
    }

    part def AdaptivePlanner {
        attribute planningHorizon : TimeValue = 10.0;
        attribute maxPlanRetries : Integer = 3;
        in port taskInput : TaskPort;
        in port sensorInput : DataPort;
        in port visionInput : VisionPort;
        in port proximityInput : ProximityPort;
        in port learningInput : PerformancePort;
        out port planOutput : PlanPort;
        out port armCommand : CommandPort;
        out port gripperCommand : CommandPort;
        out port toolChangerCommand : CommandPort;
        exhibit state PlannerBehavior {
            entry; then Idle;
            state Idle;
            state Analyzing {
                entry {
                    // Analyze environmental data and task feasibility
                }
            }
            state Planning {
                entry {
                    // Generate motion plan and select tool
                }
            }
            state Executing {
                entry {
                    // Send commands to arm, gripper, tool changer
                }
            }
            state Adapting {
                entry {
                    // Adapt strategy based on learning model
                }
            }
            state Recovering {
                entry {
                    // Error recovery procedures
                }
            }
            state Error;
            transition Idle to Analyzing when taskInput.task.taskType != null;
            transition Analyzing to Planning when planOutput.plan.status == PlanStatus::feasible;
            transition Analyzing to Error when planOutput.plan.status == PlanStatus::infeasible;
            transition Planning to Executing when planOutput.plan.selectedTool != null;
            transition Executing to Idle when armCommand.command.commandId == 0;
            transition Executing to Adapting when sensorInput.data.obstaclePresent == true;
            transition Adapting to Planning when learningInput.model.successRate > 0.7;
            transition Adapting to Recovering when learningInput.model.successRate <= 0.3;
            transition Recovering to Planning when armCommand.command.commandId == -1;
            transition any to Error when sensorInput.data.temperature > 350;
            transition Error to Idle when armCommand.command.commandId == -1;
        }
    }

    part def LearningEngine {
        attribute maxRecords : Integer = 10000;
        attribute learningRate : ProbabilityValue = 0.01;
        attribute records : PerformanceRecord[*];
        attribute currentModel : LearningModel;
        in port performanceInput : PerformancePort;
        out port modelOutput : PerformancePort;
        exhibit state LearningBehavior {
            entry; then Idle;
            state Idle;
            state Recording {
                entry {
                    // Record performance data
                }
            }
            state Training {
                entry {
                    // Update learning model
                }
            }
            state Predicting {
                entry {
                    // Predict success of proposed plan
                }
            }
            state Optimizing {
                entry {
                    // Optimize configuration for future tasks
                }
            }
            transition Idle to Recording when performanceInput.record.taskType != null;
            transition Recording to Training when records->size() > 100;
            transition Training to Predicting when currentModel.modelVersion > 0;
            transition Predicting to Optimizing when currentModel.successRate > 0.5;
            transition Optimizing to Idle when currentModel.recommendedTool != null;
        }
    }

    part def PowerManagementUnit {
        attribute totalCapacity : EnergyValue = 50000;
        attribute currentReserve : EnergyValue = 50000;
        attribute efficiency : PercentageValue = 92.0;
        attribute mode : PowerMode = PowerMode::full;
        out port armPower : PowerPort;
        out port gripperPower : PowerPort;
        out port toolChangerPower : PowerPort;
        out port sensorPower : PowerPort;
        out port plannerPower : PowerPort;
        exhibit state PowerBehavior {
            entry; then Normal;
            state Normal;
            state Reduced;
            state Standby;
            state Critical;
            transition Normal to Reduced when currentReserve < 0.5 * totalCapacity;
            transition Reduced to Standby when currentReserve < 0.2 * totalCapacity;
            transition Standby to Critical when currentReserve < 0.05 * totalCapacity;
            transition Reduced to Normal when currentReserve >= 0.7 * totalCapacity;
            transition Standby to Reduced when currentReserve >= 0.3 * totalCapacity;
            transition Critical to Standby when currentReserve >= 0.1 * totalCapacity;
        }
    }

    // ===== Top-Level System =====

    part def AutonomousRobot {
        attribute systemId : String = "ARS-001";
        attribute operational : Boolean = true;

        part arm : ManipulatorArm;
        part gripper : EndEffector;
        part toolChanger : ToolChanger;
        part sensorSuite : SensorSuite;
        part planner : AdaptivePlanner;
        part learningEngine : LearningEngine;
        part powerUnit : PowerManagementUnit;

        // Connections
        connection sensorToPlanner connect sensorSuite.environmentalData to planner.sensorInput;
        connection visionToPlanner connect sensorSuite.visionData to planner.visionInput;
        connection proximityToPlanner connect sensorSuite.proximityData to planner.proximityInput;
        connection plannerToArm connect planner.armCommand to arm.command;
        connection plannerToGripper connect planner.gripperCommand to gripper.command;
        connection plannerToToolChanger connect planner.toolChangerCommand to toolChanger.command;
        connection plannerToLearning connect planner.planOutput to learningEngine.performanceInput;
        connection learningToPlanner connect learningEngine.modelOutput to planner.learningInput;
        connection powerToArm connect powerUnit.armPower to arm.power;
        connection powerToGripper connect powerUnit.gripperPower to gripper.power;
        connection powerToToolChanger connect powerUnit.toolChangerPower to toolChanger.power;

        exhibit state SystemOperation {
            entry; then Idle;
            state Idle;
            state Analyzing;
            state Planning;
            state Executing;
            state Adapting;
            state Recovering;
            state Error;
            transition Idle to Analyzing when planner.taskInput.task.taskType != null;
            transition Analyzing to Planning when planner.planOutput.plan.status == PlanStatus::feasible;
            transition Analyzing to Error when planner.planOutput.plan.status == PlanStatus::infeasible;
            transition Planning to Executing when planner.planOutput.plan.selectedTool != null;
            transition Executing to Idle when planner.armCommand.command.commandId == 0;
            transition Executing to Adapting when sensorSuite.environmentalData.data.obstaclePresent == true;
            transition Adapting to Planning when learningEngine.currentModel.successRate > 0.7;
            transition Adapting to Recovering when learningEngine.currentModel.successRate <= 0.3;
            transition Recovering to Planning when planner.armCommand.command.commandId == -1;
            transition any to Error when powerUnit.mode == PowerMode::critical;
            transition Error to Idle when powerUnit.mode == PowerMode::full;
        }
    }

    // ===== Requirements =====

    requirement def ManipulationCapability {
        subject robot : AutonomousRobot;
        requirement {
            doc "The robot shall perform complex manipulation and assembly tasks in dynamic environments."
        }
    }

    requirement def ToolSwapping {
        subject toolChanger : ToolChanger;
        requirement {
            doc "The system shall automatically swap tools without manual intervention."
        }
        attribute maxSwapTime : TimeValue = 5.0;
    }

    requirement def SensorCoverage {
        subject sensorSuite : SensorSuite;
        requirement {
            doc "The sensor suite shall include two vision systems and four proximity sensors."
        }
        attribute visionCount : Integer = 2;
        attribute proximityCount : Integer = 4;
    }

    requirement def AutonomousPlanning {
        subject planner : AdaptivePlanner;
        requirement {
            doc "The planner shall analyze feasibility, generate motion plans, select tools, and send commands autonomously."
        }
    }

    requirement def LearningCapability {
        subject learningEngine : LearningEngine;
        requirement {
            doc "The learning engine shall record performance, predict success, and optimize future task execution."
        }
        attribute minSuccessRate : ProbabilityValue = 0.8;
    }

    requirement def PowerManagement {
        subject powerUnit : PowerManagementUnit;
        requirement {
            doc "The power management unit shall monitor reserves and distribute power to the arm and gripper."
        }
        attribute minOperationalReserve : PercentageValue = 5.0;
    }

    requirement def StateRobustness {
        subject robot : AutonomousRobot;
        requirement {
            doc "The robot shall operate through states: idle, analyzing, planning, executing, adapting, and recovering."
        }
    }

    requirement def EnvironmentalAwareness {
        subject sensorSuite : SensorSuite;
        requirement {
            doc "The sensor suite shall gather data on lighting, temperature, and obstacle presence and location."
        }
    }

    requirement def SystemRequirements {
        part robot : AutonomousRobot;
        satisfy ManipulationCapability by robot;
        satisfy ToolSwapping by robot.toolChanger;
        satisfy SensorCoverage by robot.sensorSuite;
        satisfy AutonomousPlanning by robot.planner;
        satisfy LearningCapability by robot.learningEngine;
        satisfy PowerManagement by robot.powerUnit;
        satisfy StateRobustness by robot;
        satisfy EnvironmentalAwareness by robot.sensorSuite;
    }

}
