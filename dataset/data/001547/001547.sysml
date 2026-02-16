package 'Robotic System with Hall of Fame' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	
	package DataModel {
		attribute def PerformanceScore :> Real;
		attribute def InductionYear :> Integer;
		attribute def SuccessRate :> Real;
		
		item def RobotProfile {
			attribute robotName : String;
			attribute inductionYear : InductionYear;
			attribute performanceScore : PerformanceScore;
			attribute primaryCapability : String;
			attribute yearsActive : Integer;
		}
		
		item def TaskSpecification {
			attribute taskId : String;
			attribute taskType : String;
			attribute complexityLevel : Real;
			attribute requiredCapability : String;
		}
		
		item def TaskResult {
			attribute taskId : String;
			attribute success : Boolean;
			attribute executionTime : DurationValue;
			attribute qualityScore : Real;
		}
	}
	
	package LogicalModel {
		private import DataModel::*;
		
		action def AnalyzeHallOfFame {
			in profiles : RobotProfile[1..*];
			in taskSpec : TaskSpecification;
			out selectedProfile : RobotProfile;
			out strategy : String;
		}
		
		action def ExecuteTask {
			in strategy : String;
			in taskSpec : TaskSpecification;
			out result : TaskResult;
		}
		
		action def EvaluatePerformance {
			in results : TaskResult[1..*];
			out successRate : SuccessRate;
			out averageQuality : Real;
		}
		
		action def UpdateHallOfFame {
			in currentPerformance : PerformanceScore;
			in robotProfile : RobotProfile;
			out updated : Boolean;
		}
		
		part def HallOfFame {
			attribute inductedRobots : RobotProfile[5] = (
				RobotProfile(
					robotName = "Shakey",
					inductionYear = 2004,
					performanceScore = 0.92,
					primaryCapability = "Navigation",
					yearsActive = 6
				),
				RobotProfile(
					robotName = "ASIMO",
					inductionYear = 2000,
					performanceScore = 0.95,
					primaryCapability = "Humanoid Mobility",
					yearsActive = 18
				),
				RobotProfile(
					robotName = "Roomba",
					inductionYear = 2006,
					performanceScore = 0.88,
					primaryCapability = "Autonomous Cleaning",
					yearsActive = 20
				),
				RobotProfile(
					robotName = "Curiosity",
					inductionYear = 2012,
					performanceScore = 0.98,
					primaryCapability = "Planetary Exploration",
					yearsActive = 12
				),
				RobotProfile(
					robotName = "Spot",
					inductionYear = 2019,
					performanceScore = 0.94,
					primaryCapability = "Quadruped Locomotion",
					yearsActive = 5
				)
			);
			
			perform action analyzeProfiles : AnalyzeHallOfFame {
				in profiles = inductedRobots;
			}
			
			perform action updateRecords : UpdateHallOfFame;
		}
		
		part def TaskExecutor {
			perform action executeTask : ExecuteTask;
		}
		
		part def PerformanceMonitor {
			attribute taskHistory : TaskResult[0..*];
			perform action evaluatePerformance : EvaluatePerformance;
		}
		
		action roboticWorkflow {
			in taskSpec : TaskSpecification;
			out finalResult : TaskResult;
			
			first start;
			then action analyze : AnalyzeHallOfFame;
			then action execute : ExecuteTask {
				in strategy = analyze.strategy;
				in taskSpec = taskSpec;
			}
			then action evaluate : EvaluatePerformance;
			then decide;
				if evaluate.successRate >= 0.90 then updateSuccess;
				if evaluate.successRate < 0.90 then retryTask;
			action updateSuccess : UpdateHallOfFame {
				in currentPerformance = evaluate.averageQuality;
				in robotProfile = analyze.selectedProfile;
			}
			then assign finalResult := execute.result;
			then done;
			action retryTask;
			then analyze;
		}
		
		part def RoboticSystem {
			attribute overallSuccessRate : SuccessRate;
			
			part hallOfFame : HallOfFame;
			
			part taskExecutor : TaskExecutor {
				perform roboticWorkflow.execute;
			}
			
			part performanceMonitor : PerformanceMonitor {
				perform roboticWorkflow.evaluate;
			}
			
			perform action workflow : roboticWorkflow;
		}
		
		part roboticSystem : RoboticSystem;
	}
	
	package RequirementModel {
		private import DataModel::*;
		private import LogicalModel::*;
		
		requirement def HallOfFameRequirement {
			subject hallOfFame : HallOfFame;
			require constraint {
				hallOfFame.inductedRobots->size() >= 3
			}
		}
		
		requirement def TaskPerformanceRequirement {
			subject system : RoboticSystem;
			require constraint {
				system.overallSuccessRate >= 0.90
			}
		}
		
		requirement def StrategySelectionRequirement {
			subject system : RoboticSystem;
			require constraint {
				system.hallOfFame.inductedRobots->exists(r | r.performanceScore >= 0.85)
			}
		}
		
		requirement hallOfFameReq : HallOfFameRequirement;
		requirement taskPerformanceReq : TaskPerformanceRequirement;
		requirement strategySelectionReq : StrategySelectionRequirement;
		
		satisfy hallOfFameReq by LogicalModel::roboticSystem.hallOfFame;
		satisfy taskPerformanceReq by LogicalModel::roboticSystem;
		satisfy strategySelectionReq by LogicalModel::roboticSystem;
	}
	
	package PhysicalModel {
		private import LogicalModel::*;
		private import DataModel::*;
		
		port def DataPort {
			attribute data : RobotProfile[0..*];
		}
		
		port def ControlPort {
			attribute commands : String[0..*];
		}
		
		port def SensorPort {
			attribute measurements : Real[0..*];
		}
		
		port def PowerPort {
			attribute voltage :> ISQ::voltage;
			attribute current :> ISQ::electricCurrent;
		}
		
		part def ProcessingUnit {
			attribute processingPower : PowerValue;
			attribute memoryCapacity : Real;
			
			port dataInput : DataPort;
			port controlOutput : ControlPort;
			port power : PowerPort;
		}
		
		part def ActuatorAssembly {
			attribute maxForce : ForceValue;
			attribute responseTime : DurationValue;
			attribute numberOfActuators : Integer;
			
			port controlInput : ControlPort;
			port sensorFeedback : SensorPort;
			port power : PowerPort;
		}
		
		part def SensorArray {
			attribute sensorCount : Integer;
			attribute samplingRate : FrequencyValue;
			attribute accuracy : Real;
			
			port sensorOutput : SensorPort;
			port power : PowerPort;
		}
		
		part def DatabaseModule {
			attribute storageCapacity : Real;
			attribute accessSpeed : FrequencyValue;
			
			port dataAccess : DataPort;
			port power : PowerPort;
		}
		
		part def PowerSupply {
			attribute outputVoltage :> ISQ::voltage;
			attribute maxCurrent :> ISQ::electricCurrent;
			attribute efficiency : Real;
			
			port powerOut : PowerPort;
		}
		
		part def PhysicalRobot {
			attribute totalMass : MassValue;
			attribute operatingVoltage :> ISQ::voltage;
			attribute dimensions : LengthValue[3];
			
			part processor : ProcessingUnit {
				attribute :>> processingPower = 50.0 [W];
				attribute :>> memoryCapacity = 16.0;
			}
			
			part actuators : ActuatorAssembly {
				attribute :>> maxForce = 100.0 [N];
				attribute :>> responseTime = 0.05 [s];
				attribute :>> numberOfActuators = 6;
			}
			
			part sensors : SensorArray {
				attribute :>> sensorCount = 12;
				attribute :>> samplingRate = 100.0 [Hz];
				attribute :>> accuracy = 0.98;
			}
			
			part database : DatabaseModule {
				attribute :>> storageCapacity = 256.0;
				attribute :>> accessSpeed = 1000.0 [Hz];
			}
			
			part powerSupply : PowerSupply {
				attribute :>> outputVoltage = 24.0 [V];
				attribute :>> maxCurrent = 10.0 [A];
				attribute :>> efficiency = 0.92;
			}
			
			connection sensorFeedbackLink connect sensors.sensorOutput to actuators.sensorFeedback;
			connection controlLink connect processor.controlOutput to actuators.controlInput;
			connection dataLink connect database.dataAccess to processor.dataInput;
			connection powerProcessorLink connect powerSupply.powerOut to processor.power;
			connection powerActuatorLink connect powerSupply.powerOut to actuators.power;
			connection powerSensorLink connect powerSupply.powerOut to sensors.power;
			connection powerDatabaseLink connect powerSupply.powerOut to database.power;
			
			perform roboticWorkflow;
		}
		
		part physicalRobot : PhysicalRobot {
			attribute :>> totalMass = 45.0 [kg];
			attribute :>> operatingVoltage = 24.0 [V];
			attribute :>> dimensions = (0.8 [m], 0.6 [m], 1.2 [m]);
		}
	}
	
	package BehaviorModel {
		private import DataModel::*;
		private import LogicalModel::*;
		
		state def RobotOperationalStates {
			entry; 
			then idle;
			
			state idle;
			
			transition idle_to_analyzing
				first idle
				accept InitiateAnalysis
				then analyzing;
			
			state analyzing {
				do action analyzeHallOfFame : AnalyzeHallOfFame;
			}
			
			transition analyzing_to_executing
				first analyzing
				accept AnalysisComplete
				then executing;
			
			state executing {
				do action executeTask : ExecuteTask;
			}
			
			transition executing_to_evaluating
				first executing
				accept TaskComplete
				then evaluating;
			
			state evaluating {
				do action evaluatePerformance : EvaluatePerformance;
			}
			
			transition evaluating_to_updating
				first evaluating
				accept PerformanceGood
				then updating;
			
			transition evaluating_to_idle
				first evaluating
				accept PerformancePoor
				then idle;
			
			state updating {
				do action updateHallOfFame : UpdateHallOfFame;
			}
			
			transition updating_to_idle
				first updating
				accept UpdateComplete
				then idle;
		}
		
		part def StatefulRobot {
			attribute operationalState : String;
			state robotStates : RobotOperationalStates;
		}
	}
	
	allocation def LogicalToPhysical {
		end logical : LogicalModel::RoboticSystem;
		end physical : PhysicalModel::PhysicalRobot;
	}
	
	allocation systemAllocation : LogicalToPhysical
		allocate logical ::> LogicalModel::roboticSystem 
		to physical ::> PhysicalModel::physicalRobot {
		
		allocate LogicalModel::roboticSystem.hallOfFame 
			to PhysicalModel::physicalRobot.database;
		
		allocate LogicalModel::roboticSystem.taskExecutor 
			to PhysicalModel::physicalRobot.actuators;
		
		allocate LogicalModel::roboticSystem.performanceMonitor 
			to PhysicalModel::physicalRobot.sensors;
		
		allocate LogicalModel::roboticSystem.workflow 
			to PhysicalModel::physicalRobot.roboticWorkflow;
	}
}
