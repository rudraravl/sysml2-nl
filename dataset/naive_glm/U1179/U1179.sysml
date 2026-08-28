package AdaptiveRobotSystem {
	import ScalarValues::*;
	import ScalarFunctions::*;

	// ---- Value types with units ----
	attribute def Percent {
		ref value :> Real;
		private ref value_unit : String = "%";
	}
	attribute def Score {
		ref value :> Real;
		private ref value_unit : String = "score";
	}
	attribute def Duration_s {
		ref value :> Real;
		private ref value_unit : String = "s";
	}
	attribute def Power_W {
		ref value :> Real;
		private ref value_unit : String = "W";
	}
	attribute def Voltage_V {
		ref value :> Real;
		private ref value_unit : String = "V";
	}
	attribute def Year {
		ref value :> Integer;
		private ref value_unit : String = "year";
	}

	// ---- Enumerations ----
	enum def TaskType { navigation; manipulation; exploration; inspection; }
	enum def CapabilityKind { locomotion; manipulation; perception; endurance; autonomy; }
	enum def ExecutionStatus { pending; running; completed; failed; }

	// ---- Item types ----
	item def Task {
		ref name : String;
		ref taskType : TaskType;
		ref requiredCapabilities : CapabilityKind[1..*];
		ref difficulty : Percent; // 0..100
		ref deadline_s : Duration_s;
	}

	item def RobotProfile {
		ref robotName : String;
		ref introductionYear : Year;
		ref yearsOfService : Year;
		ref primaryCapabilities : CapabilityKind[1..*];
		ref performanceScore : Score; // 0..100
		ref description : String;
	}

	item def Strategy {
		ref strategyName : String;
		ref inspiredBy : String;
		ref targetCapabilities : CapabilityKind[1..*];
		ref expectedSuccess : Percent;
		ref commandSequence : String[1..*];
	}

	item def SensorReading {
		ref timestamp_s : Duration_s;
		ref readingType : String;
		ref value : Real;
		ref unit : String;
	}

	item def PerformanceReport {
		ref successRate : Percent;
		ref executionTime_s : Duration_s;
		ref qualityScore : Score;
		ref status : ExecutionStatus;
		ref notes : String;
	}

	item def Command {
		ref commandId : String;
		ref targetActuator : String;
		ref action : String;
		ref intensity : Real;
		ref duration_s : Duration_s;
	}

	// ---- Port definitions ----
	port def CommandPort {
		out commands : Command;
		in readings : SensorReading;
	}

	port def TaskPort {
		in task : Task;
		out report : PerformanceReport;
	}

	port def PowerPort {
		in voltage : Voltage_V;
		in power : Power_W;
	}

	port def DataPort {
		out profiles : RobotProfile;
		in updatedProfile : RobotProfile;
	}

	// ---- Parts ----

	part def PowerSupply {
		port powerOut : PowerPort;
		attribute ratedVoltage : Voltage_V = 24;
		attribute ratedPower : Power_W = 500;
		attribute batteryLevel : Percent = 100;

		action def supplyPower {
			in v : Voltage_V;
			in p : Power_W;
		}
	}

	part def HallOfFameDatabase {
		port dataPort : DataPort;
		ref profiles : RobotProfile[1..*] = {
			RobotProfile{robotName = "ASIMO", introductionYear = 2000, yearsOfService = 18, primaryCapabilities = {CapabilityKind::manipulation, CapabilityKind::locomotion}, performanceScore = 88, description = "Humanoid bipedal assistant robot."},
			RobotProfile{robotName = "Roomba", introductionYear = 2002, yearsOfService = 20, primaryCapabilities = {CapabilityKind::locomotion, CapabilityKind::perception}, performanceScore = 82, description = "Autonomous vacuum cleaning robot."},
			RobotProfile{robotName = "Mars Curiosity Rover", introductionYear = 2012, yearsOfService = 12, primaryCapabilities = {CapabilityKind::locomotion, CapabilityKind::autonomy, CapabilityKind::endurance}, performanceScore = 95, description = "Autonomous planetary exploration rover."}
		};

		action def retrieveProfiles {
			out result : RobotProfile[1..*];
		}

		action def updateProfile {
			in updated : RobotProfile;
		}
	}

	part def CentralProcessor {
		port cmdPort : CommandPort;
		port taskPort : TaskPort;
		port dbPort : DataPort;
		port powerIn : PowerPort;

		ref currentTask : Task;
		ref selectedStrategy : Strategy;
		ref lastReport : PerformanceReport;

		action def analyzeTask {
			in task : Task;
			in historicalProfiles : RobotProfile[1..*];
			out chosenStrategy : Strategy;
		}

		action def generateCommands {
			in strategy : Strategy;
			out commands : Command[1..*];
		}

		action def decideUpdate {
			in report : PerformanceReport;
			out shouldUpdate : Boolean;
			out updatedProfile : RobotProfile;
		}
	}

	part def ActuatorAssembly {
		port cmdPort : CommandPort;
		port powerIn : PowerPort;

		part leftDrive : DriveMotor;
		part rightDrive : DriveMotor;
		part manipulatorArm : Manipulator;

		action def executeCommands {
			in commands : Command[1..*];
			out readings : SensorReading[1..*];
		}
	}

	part def DriveMotor {
		port powerIn : PowerPort;
		ref speed_rpm : Real;
		ref torque_Nm : Real;
	}

	part def Manipulator {
		port powerIn : PowerPort;
		ref jointCount : Integer = 6;
		ref payload_kg : Real;
	}

	part def SensorSuite {
		port cmdPort : CommandPort;
		port powerIn : PowerPort;

		part lidar : LidarSensor;
		part camera : CameraSensor;
		part imu : IMUSensor;

		action def collectReadings {
			out readings : SensorReading[1..*];
		}
	}

	part def LidarSensor {
		port powerIn : PowerPort;
		ref range_m : Real = 10.0;
		ref resolution_deg : Real = 1.0;
	}

	part def CameraSensor {
		port powerIn : PowerPort;
		ref resolution_px : String = "1920x1080";
		ref frameRate_fps : Real = 30.0;
	}

	part def IMUSensor {
		port powerIn : PowerPort;
		ref sampleRate_Hz : Real = 200.0;
	}

	part def PerformanceMonitor {
		port cmdPort : CommandPort;
		port taskPort : TaskPort;
		port powerIn : PowerPort;

		ref latestReport : PerformanceReport;

		action def evaluateOutcome {
			in readings : SensorReading[1..*];
			in task : Task;
			out report : PerformanceReport;
		}
	}

	// ---- Composite robot ----
	part def AdaptiveRobot {
		port externalTaskPort : TaskPort;
		port powerIn : PowerPort;

		part powerSupply : PowerSupply;
		part processor : CentralProcessor;
		part hallOfFame : HallOfFameDatabase;
		part actuators : ActuatorAssembly;
		part sensors : SensorSuite;
		part monitor : PerformanceMonitor;

		// Power distribution
		connection powerToProcessor : PowerPort connect powerSupply.powerOut to processor.powerIn;
		connection powerToActuators : PowerPort connect powerSupply.powerOut to actuators.powerIn;
		connection powerToSensors : PowerPort connect powerSupply.powerOut to sensors.powerIn;
		connection powerToMonitor : PowerPort connect powerSupply.powerOut to monitor.powerIn;

		// Command/data connections
		connection processorToActuators : CommandPort connect processor.cmdPort to actuators.cmdPort;
		connection sensorsToProcessor : CommandPort connect sensors.cmdPort to processor.cmdPort;
		connection processorToDb : DataPort connect processor.dbPort to hallOfFame.dataPort;
		connection actuatorsToMonitor : CommandPort connect actuators.cmdPort to monitor.cmdPort;
		connection monitorToProcessor : TaskPort connect monitor.taskPort to processor.taskPort;
		connection externalTask : TaskPort connect externalTaskPort to processor.taskPort;

		// State machine behavior
		enum def RobotState { idle; analyzing; executing; evaluating; updating; retrying; }

		state def RobotStateMachine {
			state idle {
				entry action { /* wait for task */ }
			}
			state analyzing {
				entry action {
					// Consult Hall of Fame and select strategy
				}
			}
			state executing {
				entry action {
					// Send commands to actuators, collect sensor readings
				}
			}
			state evaluating {
				entry action {
					// Performance monitor evaluates outcome
				}
			}
			state updating {
				entry action {
					// Update Hall of Fame with new performance record
				}
			}
			state retrying {
				entry action {
					// Re-analyze and prepare another attempt
				}
			}

			transition idle_to_analyzing first idle if (currentTask != null) to analyzing;
			transition analyzing_to_executing first analyzing if (selectedStrategy != null) to executing;
			transition executing_to_evaluating first executing if (executionStatus == ExecutionStatus::completed) to evaluating;
			transition evaluating_to_updating first evaluating if (lastReport.successRate > 90) to updating;
			transition evaluating_to_retrying first evaluating if (lastReport.successRate < 50) to retrying;
			transition evaluating_to_idle first evaluating if (lastReport.successRate >= 50 && lastReport.successRate <= 90) to idle;
			transition updating_to_idle first updating to idle;
			transition retrying_to_analyzing first retrying to analyzing;
		}

		attribute currentTask : Task;
		attribute selectedStrategy : Strategy;
		attribute lastReport : PerformanceReport;
		attribute executionStatus : ExecutionStatus = ExecutionStatus::pending;

		exhibit stateMachine : RobotStateMachine;
	}

	// ---- Requirements ----
	requirement def HallOfFameLearningRequirement {
		doc /* The system shall consult the Hall of Fame database to select a strategy inspired by historical robots. */
		subject robot : AdaptiveRobot;
		objective {
			doc /* Strategy selection must reference at least one RobotProfile from the Hall of Fame. */
		}
	}

	requirement def PowerDistributionRequirement {
		doc /* The power supply shall provide power to processor, actuators, sensors, and monitor. */
		subject robot : AdaptiveRobot;
		objective {
			doc /* All subsystems receive rated voltage and power. */
		}
	}

	requirement def StateCycleRequirement {
		doc /* The robot shall cycle through idle, analyzing, executing, evaluating, and conditionally updating or retrying states. */
		subject robot : AdaptiveRobot;
		objective {
			doc /* State transitions follow defined success thresholds. */
		}
	}

	requirement def PerformanceEvaluationRequirement {
		doc /* The performance monitor shall evaluate success rate, execution time, and quality. */
		subject monitor : PerformanceMonitor;
		objective {
			doc /* A PerformanceReport is produced for every completed task. */
		}
	}

	requirement def HighSuccessUpdateRequirement {
		doc /* If success rate exceeds 90%, the system shall update the Hall of Fame performance records. */
		subject robot : AdaptiveRobot;
		objective {
			doc /* Knowledge is refined for future tasks. */
		}
	}

	requirement def PoorPerformanceRetryRequirement {
		doc /* If success rate is below 50%, the system shall re-analyze and retry the task. */
		subject robot : AdaptiveRobot;
		objective {
			doc /* The robot learns from failure and attempts again. */
		}
	}

	requirement hallOfFameLearning : HallOfFameLearningRequirement;
	requirement powerDistribution : PowerDistributionRequirement;
	requirement stateCycle : StateCycleRequirement;
	requirement performanceEvaluation : PerformanceEvaluationRequirement;
	requirement highSuccessUpdate : HighSuccessUpdateRequirement;
	requirement poorPerformanceRetry : PoorPerformanceRetryRequirement;

	// ---- Satisfactions ----
	satisfaction hallOfFameLearning satisfy hallOfFameLearningRequirement by AdaptiveRobot::processor;
	satisfaction powerDistribution satisfy PowerDistributionRequirement by AdaptiveRobot::powerSupply;
	satisfaction stateCycle satisfy StateCycleRequirement by AdaptiveRobot::stateMachine;
	satisfaction performanceEvaluation satisfy PerformanceEvaluationRequirement by AdaptiveRobot::monitor;
	satisfaction highSuccessUpdate satisfy HighSuccessUpdateRequirement by AdaptiveRobot::hallOfFame;
	satisfaction poorPerformanceRetry satisfy PoorPerformanceRetryRequirement by AdaptiveRobot::processor;
}
