package DevelopmentalRoboticsSystem {
	private import ScalarValues::*;

	attribute def AngleValue :> ScalarValues::Real;
	attribute def AngularVelocityValue :> ScalarValues::Real;
	attribute def PressureValue :> ScalarValues::Real;
	attribute def Image;
	attribute def Texture;

	attribute def VisualData;
	attribute def ProprioceptiveData {
		attribute jointPosition : AngleValue;
		attribute jointVelocity : AngularVelocityValue;
	}
	attribute def TactileData {
		attribute pressure : PressureValue;
		attribute texture : Texture;
	}
	attribute def ActionCommand {
		attribute targetJointAngles : AngleValue[0..*];
	}
	attribute def Prediction {
		attribute predictedVisual : VisualData;
		attribute predictedProprio : ProprioceptiveData[4];
		attribute predictedTactile : TactileData;
	}
	attribute def PredictionError {
		attribute errorMagnitude : Real;
	}

	item def CompetenceAchieved;
	item def PatternsFormed;
	item def GoalsAchieved;

	action def MotorBabbling;
	action def FormPatterns;
	action def PlanForGoals;
	action def ExecuteTasks;

	part def Joint {
		port actionIn {
			in command : ActionCommand;
		}
		attribute currentAngle : AngleValue;
	}

	part def VisionSystem {
		port visualOut {
			out data : VisualData;
		}
	}

	part def ProprioceptiveSensors {
		port proprioOut {
			out data : ProprioceptiveData[4];
		}
	}

	part def TactileSensorArray {
		port tactileOut {
			out data : TactileData;
		}
	}

	part def SensorSuite {
		part vision : VisionSystem;
		part proprio : ProprioceptiveSensors;
		part tactile : TactileSensorArray;

		port visualOut {
			out data : VisualData;
		}
		port proprioOut {
			out data : ProprioceptiveData[4];
		}
		port tactileOut {
			out data : TactileData;
		}

		bind visualOut = vision.visualOut;
		bind proprioOut = proprio.proprioOut;
		bind tactileOut = tactile.tactileOut;
	}

	part def Arm {
		part joints : Joint[4];
		part sensors : SensorSuite;

		port actionIn {
			in command : ActionCommand;
		}
		port visualOut {
			out data : VisualData;
		}
		port proprioOut {
			out data : ProprioceptiveData[4];
		}
		port tactileOut {
			out data : TactileData;
		}

		bind visualOut = sensors.visualOut;
		bind proprioOut = sensors.proprioOut;
		bind tactileOut = sensors.tactileOut;

		flow actionFlow of ActionCommand from actionIn.command to joints.actionIn.command;
	}

	part def WorldModel {
		attribute bodySchema : String;
		attribute externalObjects : String;
		attribute causalRules : String;
	}

	part def PredictiveEngine {
		port visualIn {
			in data : VisualData;
		}
		port proprioIn {
			in data : ProprioceptiveData[4];
		}
		port tactileIn {
			in data : TactileData;
		}
		port actionIn {
			in command : ActionCommand;
		}
		port predictionOut {
			out pred : Prediction;
		}
		port errorIn {
			in error : PredictionError;
		}

		part worldModel : WorldModel;

		action predict {
			in visual : VisualData;
			in proprio : ProprioceptiveData[4];
			in tactile : TactileData;
			in action : ActionCommand;
			out prediction : Prediction;
		}
	}

	part def MotorPlanner {
		port predictionIn {
			in pred : Prediction;
		}
		port actionOut {
			out command : ActionCommand;
		}
		attribute explorationRate : Real;

		action plan {
			in prediction : Prediction;
			out action : ActionCommand;
		}
	}

	part def DevelopmentalLearningModule {
		port visualIn {
			in data : VisualData;
		}
		port proprioIn {
			in data : ProprioceptiveData[4];
		}
		port tactileIn {
			in data : TactileData;
		}
		port predictionIn {
			in pred : Prediction;
		}
		port errorOut {
			out error : PredictionError;
		}

		action computeError {
			in visual : VisualData;
			in proprio : ProprioceptiveData[4];
			in tactile : TactileData;
			in predicted : Prediction;
			out error : PredictionError;
		}
		action updateWorldModel {
			in error : PredictionError;
		}
	}

	part def ControlSystem {
		port visualIn {
			in data : VisualData;
		}
		port proprioIn {
			in data : ProprioceptiveData[4];
		}
		port tactileIn {
			in data : TactileData;
		}
		port actionOut {
			out command : ActionCommand;
		}

		part predictiveEngine : PredictiveEngine;
		part motorPlanner : MotorPlanner;
		part learningModule : DevelopmentalLearningModule;

		flow visualToPredictive of VisualData from visualIn.data to predictiveEngine.visualIn.data;
		flow proprioToPredictive of ProprioceptiveData from proprioIn.data to predictiveEngine.proprioIn.data;
		flow tactileToPredictive of TactileData from tactileIn.data to predictiveEngine.tactileIn.data;

		flow visualToLearning of VisualData from visualIn.data to learningModule.visualIn.data;
		flow proprioToLearning of ProprioceptiveData from proprioIn.data to learningModule.proprioIn.data;
		flow tactileToLearning of TactileData from tactileIn.data to learningModule.tactileIn.data;

		flow predictionToPlanner of Prediction from predictiveEngine.predictionOut.pred to motorPlanner.predictionIn.pred;
		flow predictionToLearning of Prediction from predictiveEngine.predictionOut.pred to learningModule.predictionIn.pred;

		flow actionToPredictive of ActionCommand from motorPlanner.actionOut.command to predictiveEngine.actionIn.command;
		flow actionToArm of ActionCommand from motorPlanner.actionOut.command to actionOut.command;

		flow errorToPredictive of PredictionError from learningModule.errorOut.error to predictiveEngine.errorIn.error;

		state developmentalPhases {
			entry; then reflexive;
			state reflexive {
				entry assign motorPlanner.explorationRate := 1.0;
				do action motorBabbling : MotorBabbling;
			}
			transition first reflexive accept CompetenceAchieved then coordinative;
			state coordinative {
				entry assign motorPlanner.explorationRate := 0.5;
				do action formPatterns : FormPatterns;
			}
			transition first coordinative accept PatternsFormed then goalDirected;
			state goalDirected {
				entry assign motorPlanner.explorationRate := 0.2;
				do action planForGoals : PlanForGoals;
			}
			transition first goalDirected accept GoalsAchieved then skilled;
			state skilled {
				entry assign motorPlanner.explorationRate := 0.1;
				do action executeTasks : ExecuteTasks;
			}
		}

		action intrinsicCycle {
			action sense;
			then action predict;
			then action plan;
			then action act;
			then action learn;
			then sense;
		}
	}

	part def Robot {
		part arm : Arm;
		part brain : ControlSystem;

		flow visualFlow of VisualData from arm.visualOut.data to brain.visualIn.data;
		flow proprioFlow of ProprioceptiveData from arm.proprioOut.data to brain.proprioIn.data;
		flow tactileFlow of TactileData from arm.tactileOut.data to brain.tactileIn.data;
		flow actionFlow of ActionCommand from brain.actionOut.command to arm.actionIn.command;
	}

	requirement def LearningThroughExplorationReq {
		doc /* The robot shall learn physical skills through self-exploration and interaction with its environment. */
	}

	requirement def SensorimotorPredictionReq {
		doc /* The Predictive Engine shall predict sensory consequences of potential actions using an internal World Model. */
	}

	requirement def DevelopmentalProgressionReq {
		doc /* The robot shall progress through reflexive, coordinative, goal-directed, and skilled developmental phases. */
	}

	requirement learningThroughExploration : LearningThroughExplorationReq;
	requirement sensorimotorPrediction : SensorimotorPredictionReq;
	requirement developmentalProgression : DevelopmentalProgressionReq;

	part autonomousRobot : Robot {
		satisfy learningThroughExploration;
		satisfy sensorimotorPrediction;
		satisfy developmentalProgression;
	}
}
