package AdaptiveRoboticSystem {
	private import ScalarValues::*;

	attribute def SuccessRate :> Real;
	attribute def PerformanceScore :> Real;
	attribute def ExecutionTime :> Real;
	attribute def QualityMetric :> Real;
	attribute def PowerLevel :> Real;
	attribute def ServiceYears :> Integer;

	item def Task {
		attribute description : String;
		attribute complexity : Real;
		attribute navigationRequired : Boolean;
		attribute manipulationRequired : Boolean;
	}
	item def TaskResult {
		attribute successRate : SuccessRate;
		attribute executionTime : ExecutionTime;
		attribute quality : QualityMetric;
	}
	item def Command {
		attribute commandId : String;
		attribute targetActuator : String;
	}
	item def SensorData {
		attribute sensorId : String;
		attribute reading : Real;
		attribute timestamp : String;
	}
	item def Strategy {
		attribute strategyName : String;
		attribute referenceRobot : String;
		attribute estimatedSuccess : SuccessRate;
	}

	attribute def TaskReceived;
	attribute def AnalysisComplete;
	attribute def ExecutionComplete;
	attribute def EvaluationComplete;
	attribute def RetryTask;
	attribute def UpdateHallOfFame;

	part def RobotProfile {
		attribute name : String;
		attribute primaryCapability : String;
		attribute yearsOfService : ServiceYears;
		attribute performanceScore : PerformanceScore;
	}

	part def HallOfFame {
		attribute profiles : RobotProfile[*];
		action def SelectStrategy {
			in task : Task;
			out strategy : Strategy;
		}
		action def UpdateRecord {
			in result : TaskResult;
			in strategy : Strategy;
		}
	}

	part def CentralProcessor {
		port commandOut : Command[*];
		port sensorDataIn : SensorData[*];
		attribute currentStrategy : Strategy;
		action def Analyze {
			in task : Task;
			in hallOfFame : HallOfFame;
			out strategy : Strategy;
		}
		action def GenerateCommands {
			in strategy : Strategy;
			out commands : Command[*];
		}
	}

	part def Actuator {
		attribute actuatorId : String;
		attribute active : Boolean := false;
		action def Actuate {
			in cmd : Command;
		}
	}

	part def ActuatorAssembly {
		part actuators : Actuator[2];
		port commandIn : Command[*];
		action def ExecuteCommands {
			in commands : Command[*];
		}
	}

	part def Sensor {
		attribute sensorId : String;
		attribute reading : Real := 0.0;
		action def Sense {
			out data : SensorData;
		}
	}

	part def SensorSuite {
		part sensors : Sensor[3];
		port sensorDataOut : SensorData[*];
		action def CollectData {
			out allData : SensorData[*];
		}
	}

	part def PerformanceMonitor {
		action def Evaluate {
			in sensorData : SensorData[*];
			in strategy : Strategy;
			out result : TaskResult;
		}
	}

	part def PowerSupply {
		attribute capacity : PowerLevel := 1000.0;
		attribute currentLevel : PowerLevel := 1000.0;
		action def Consume {
			in amount : PowerLevel;
		}
		action def Recharge {
		}
	}

	state def RoboticStates {
		entry; then idle;
		state idle;
		transition idle_to_analysis
			first idle
			accept TaskReceived
			then analysis;
		state analysis;
		transition analysis_to_execution
			first analysis
			accept AnalysisComplete
			then execution;
		state execution;
		transition execution_to_evaluation
			first execution
			accept ExecutionComplete
			then evaluation;
		state evaluation;
		transition evaluation_to_update
			first evaluation
			accept UpdateHallOfFame
			then updateHallOfFame;
		transition evaluation_to_retry
			first evaluation
			accept RetryTask
			then analysis;
		state updateHallOfFame;
		transition update_to_idle
			first updateHallOfFame
			accept EvaluationComplete
			then idle;
	}

	part def AdaptiveRobot {
		port taskIn : Task;
		port resultOut : TaskResult;
		part processor : CentralProcessor;
		part hallOfFame : HallOfFame;
		part actuatorAssembly : ActuatorAssembly;
		part sensorSuite : SensorSuite;
		part performanceMonitor : PerformanceMonitor;
		part powerSupply : PowerSupply;
		connect processor.commandOut to actuatorAssembly.commandIn;
		connect sensorSuite.sensorDataOut to processor.sensorDataIn;
		exhibit roboticStates : RoboticStates;
	}

	requirement def TaskExecutionRequirement {
		subject robot : AdaptiveRobot;
		objective {
			doc "The robot shall execute tasks using strategies learned from the Hall of Fame."
		}
	}

	requirement def HallOfFameRequirement {
		subject hof : HallOfFame;
		objective {
			doc "The Hall of Fame shall contain profiles of historically significant robots with capabilities, years of service, and performance scores."
		}
	}

	requirement def PerformanceEvaluationRequirement {
		subject monitor : PerformanceMonitor;
		objective {
			doc "The performance monitor shall evaluate task outcomes based on success rate, execution time, and quality."
		}
	}

	requirement def AdaptiveLearningRequirement {
		subject robot : AdaptiveRobot;
		objective {
			doc "If task success rate exceeds 90%, the robot shall update its Hall of Fame records. If below 90%, it shall re-analyze and retry."
		}
	}

	requirement def PowerRequirement {
		subject power : PowerSupply;
		objective {
			doc "The power supply shall provide energy to all subsystems including processor, sensors, and actuators."
		}
	}

	part adaptiveRobotInstance : AdaptiveRobot;
	part hallOfFameInstance : HallOfFame;
	part monitorInstance : PerformanceMonitor;
	part powerInstance : PowerSupply;

	requirement taskExecReq : TaskExecutionRequirement;
	requirement hofReq : HallOfFameRequirement;
	requirement perfEvalReq : PerformanceEvaluationRequirement;
	requirement adaptiveLearnReq : AdaptiveLearningRequirement;
	requirement powerReq : PowerRequirement;

	satisfy taskExecReq by adaptiveRobotInstance;
	satisfy adaptiveLearnReq by adaptiveRobotInstance;
	satisfy hofReq by hallOfFameInstance;
	satisfy perfEvalReq by monitorInstance;
	satisfy powerReq by powerInstance;
}
