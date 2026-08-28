package 'Autonomous Industrial Robotic System' {
    private import ISQ::*;
    private import ScalarValues::*;

    package 'DataTypes' {
        item def EnvironmentData {
            attribute illuminance :> ISQ::illuminance;
            attribute temperature :> ISQ::thermodynamicTemperature;
            attribute obstaclePositions :> ISQ::length[*];
        }

        item def Task {
            attribute description : String;
            attribute taskType : TaskKind;
        }

        enum def TaskKind {
            pickAndPlace;
            assembly;
            inspection;
        }

        item def MotionCommand {
            attribute jointAngles : Real[*];
            attribute gripperAction : GripperAction;
        }

        enum def GripperAction {
            open;
            close;
            hold;
        }

        item def ToolChangeCommand {
            attribute toolID : String;
        }

        item def ToolSelection {
            attribute toolID : String;
            attribute toolType : String;
        }

        item def PerformanceRecord {
            attribute successRate : Real;
            attribute completionTime :> ISQ::time;
            attribute energyConsumed :> ISQ::energy;
        }

        item def MotionPlan {
            attribute feasible : Boolean;
            attribute commands : MotionCommand[*];
        }

        item def PredictionResult {
            attribute successProbability : Real;
            attribute advice : String;
        }
    }

    package 'Ports' {
        private import DataTypes::*;

        port def SensorOutPort {
            out item data : EnvironmentData;
        }

        port def SensorInPort {
            in item data : EnvironmentData;
        }

        port def TaskInPort {
            in item task : Task;
        }

        port def CommandOutPort {
            out item command : MotionCommand;
        }

        port def CommandInPort {
            in item command : MotionCommand;
        }

        port def ToolChangeOutPort {
            out item command : ToolChangeCommand;
        }

        port def ToolChangeInPort {
            in item command : ToolChangeCommand;
        }

        port def PerformanceOutPort {
            out item record : PerformanceRecord;
        }

        port def PerformanceInPort {
            in item record : PerformanceRecord;
        }

        port def PredictionOutPort {
            out item prediction : PredictionResult;
        }

        port def PredictionInPort {
            in item prediction : PredictionResult;
        }

        port def PowerOutPort {
            out item power :> ISQ::power;
        }

        port def PowerInPort {
            in item power :> ISQ::power;
        }
    }

    package 'Components' {
        private import DataTypes::*;
        private import Ports::*;

        part def ManipulatorArm {
            port commandIn : CommandInPort;
            port powerIn : PowerInPort;
            attribute jointCount : Integer = 6;
        }

        part def EndEffector {
            port commandIn : CommandInPort;
            port powerIn : PowerInPort;
        }

        part def ToolChanger {
            port commandIn : ToolChangeInPort;
        }

        part def VisionSystem {
            port dataOut : SensorOutPort;
        }

        part def ProximitySensor {
            port dataOut : SensorOutPort;
        }

        part def SensorSuite {
            part vision1 : VisionSystem;
            part vision2 : VisionSystem;
            part prox1 : ProximitySensor;
            part prox2 : ProximitySensor;
            part prox3 : ProximitySensor;
            part prox4 : ProximitySensor;
        }

        part def AdaptivePlanner {
            port taskIn : TaskInPort;
            port sensorIn : SensorInPort;
            port predictionIn : PredictionInPort;
            port armCmdOut : CommandOutPort;
            port gripperCmdOut : CommandOutPort;
            port toolCmdOut : ToolChangeOutPort;
            port performanceOut : PerformanceOutPort;
            port learningOut : PredictionOutPort;
        }

        part def LearningEngine {
            port performanceIn : PerformanceInPort;
            port predictionOut : PredictionOutPort;
            attribute history : PerformanceRecord[*];
        }

        part def PowerManagementUnit {
            port armPowerOut : PowerOutPort;
            port gripperPowerOut : PowerOutPort;
            attribute energyReserve :> ISQ::energy;
        }

        part def Robot {
            part arm : ManipulatorArm;
            part gripper : EndEffector;
            part toolChanger : ToolChanger;
            part sensorSuite : SensorSuite;
            part planner : AdaptivePlanner;
            part learningEngine : LearningEngine;
            part powerUnit : PowerManagementUnit;
        }
    }

    package 'Behaviors' {
        private import DataTypes::*;

        action def AnalyzeEnvironment {
            in envData : EnvironmentData;
            in task : Task;
            out feasible : Boolean;
        }

        action def GenerateMotionPlan {
            in task : Task;
            in envData : EnvironmentData;
            in feasible : Boolean;
            out plan : MotionPlan;
            out toolSelection : ToolSelection;
        }

        action def ExecuteTask {
            in plan : MotionPlan;
            in toolSelection : ToolSelection;
            out performance : PerformanceRecord;
        }

        action def RecordPerformance {
            in performance : PerformanceRecord;
            out history : PerformanceRecord[*];
        }

        action def PredictSuccess {
            in plan : MotionPlan;
            in history : PerformanceRecord[*];
            out prediction : PredictionResult;
        }

        action def AdaptStrategy {
            in prediction : PredictionResult;
            in envData : EnvironmentData;
            out adaptedPlan : MotionPlan;
        }

        state def RobotStateMachine {
            state idle;
            state analyzing;
            state planning;
            state executing;
            state adapting;
            state errorRecovery;
            state taskComplete;

            transition from idle to analyzing;
            transition from analyzing to planning;
            transition from planning to executing;
            transition from executing to taskComplete;
            transition from planning to adapting;
            transition from adapting to planning;
            transition from idle, analyzing, planning, executing, adapting to errorRecovery;
            transition from errorRecovery to idle;
        }
    }

    package 'Requirements' {
        requirement def AutonomousOperation {
            doc /* The system shall autonomously perform complex manipulation and assembly tasks in dynamic environments without manual intervention. */
        }

        requirement def ToolSwapping {
            doc /* The system shall automatically swap tools using the dedicated tool changer to adapt its physical configuration for diverse tasks. */
        }

        requirement def EnvironmentalAwareness {
            doc /* The system shall utilize two vision systems and four proximity sensors to monitor lighting, temperature, and obstacle locations. */
        }

        requirement def AdaptivePlanning {
            doc /* The Adaptive Planner shall analyze environmental data, determine task feasibility, generate motion plans, select tools, and command actuators. */
        }

        requirement def LearningImprovement {
            doc /* The Learning Engine shall record performance metrics, predict plan success, and optimize future task configurations. */
        }

        requirement def PowerManagement {
            doc /* The Power Management Unit shall monitor energy reserves and efficiently distribute power to the arm and gripper. */
        }

        requirement def RobustOperation {
            doc /* The robot shall operate through idle, analyzing, planning, executing, adapting, and error recovery states for reliable operation. */
        }
    }

    package 'System' {
        private import DataTypes::*;
        private import Ports::*;
        private import Components::*;
        private import Behaviors::*;
        private import Requirements::*;

        part robot : Robot {
            connect sensorSuite.vision1.dataOut to planner.sensorIn;
            connect sensorSuite.vision2.dataOut to planner.sensorIn;
            connect sensorSuite.prox1.dataOut to planner.sensorIn;
            connect sensorSuite.prox2.dataOut to planner.sensorIn;
            connect sensorSuite.prox3.dataOut to planner.sensorIn;
            connect sensorSuite.prox4.dataOut to planner.sensorIn;
            connect planner.armCmdOut to arm.commandIn;
            connect planner.gripperCmdOut to gripper.commandIn;
            connect planner.toolCmdOut to toolChanger.commandIn;
            connect planner.performanceOut to learningEngine.performanceIn;
            connect learningEngine.predictionOut to planner.predictionIn;
            connect powerUnit.armPowerOut to arm.powerIn;
            connect powerUnit.gripperPowerOut to gripper.powerIn;

            exhibit robotStates : RobotStateMachine {
            }

            satisfy AutonomousOperation by robot;
            satisfy ToolSwapping by robot.toolChanger;
            satisfy EnvironmentalAwareness by robot.sensorSuite;
            satisfy AdaptivePlanning by robot.planner;
            satisfy LearningImprovement by robot.learningEngine;
            satisfy PowerManagement by robot.powerUnit;
            satisfy RobustOperation by robot;
        }
    }
}
